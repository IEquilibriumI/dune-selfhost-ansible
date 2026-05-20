# Dune Self-Host Ansible

Provision a fresh Ubuntu VM on Proxmox and deploy a working **Dune: Awakening** self-hosted world on Linux using Ansible.

This repo is built around the current live self-host flow and the public Steam app:

- Steam App ID: `4754530`
- Linux install path: SteamCMD anonymous download, or a direct archive if you have one

The main entrypoint is a single wrapper script:

```bash
./scripts/run_full_setup.sh
```

It prompts for the required values, runs the playbooks in the correct order, and completes the full setup from Proxmox template creation through battlegroup startup.

## What This Automates

- Builds an Ubuntu 24.04 cloud-init template on Proxmox
- Clones a Dune VM from that template
- Bootstraps the guest with the required packages
- Installs SteamCMD
- Downloads the live Linux dedicated server files
- Installs `k3s`
- Loads the Funcom operator and battlegroup images
- Creates the world with your self-host token
- Patches the generated battlegroup with the correct public IP and unique datacenter ID
- Waits for the battlegroup to become healthy and for the core maps to start

## Supported Controller Setup

The repo can be cloned anywhere on the Ansible controller. No controller-side absolute path is required.

Tested controller patterns:

- WSL Ubuntu on Windows
- Native Ubuntu or Debian
- Any Linux host with SSH access to Proxmox

## Prerequisites

### Proxmox

- A reachable Proxmox host
- Permission to create, clone, configure, start, stop, and destroy VMs
- Storage available for:
  - an Ubuntu 24.04 template
  - a Dune VM with at least `110G` disk
- A working bridge for the Dune VM network
- Hardware resources that can support the VM

Recommended VM sizing for this repo:

- CPU: `6` cores minimum for the provided defaults
- RAM: `40G`
- Disk: `110G`

Hard validation currently enforced by playbooks:

- CPU: at least `4`
- RAM: at least `20G`
- Disk: at least `100G`

### Network

- A static LAN IP planned for the Dune VM
- A gateway for that subnet
- Internet access from the Dune VM
- Port forwarding from your router/firewall to the Dune VM if you want outside players to reach it
- If you use a host firewall on the Dune VM, plan the required allow rules before enabling it

Typical forwarding for this setup:

- UDP `7777-7890` -> Dune VM
- TCP `31982` -> Dune VM

Recommended host firewall approach:

- Use `ufw` on the Ubuntu Dune VM if you want a simple host firewall
- Allow SSH before enabling it
- Allow the same public Dune ports on the VM itself:
  - `22/tcp`
  - `31982/tcp`
  - `7777:7890/udp`

Example:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 31982/tcp
sudo ufw allow 7777:7890/udp
sudo ufw enable
```

This repo does not configure UFW automatically.

### Dune / Funcom

- A valid self-host token from the Dune account page
- A public IP reachable by players, or a manual override value if auto-detection is not correct

### Ansible Controller

Required tools:

- `git`
- `bash`
- `ssh`
- `python3`
- `python3-venv`
- `ansible-playbook`

You also need an SSH keypair that can be injected into the Dune VM during cloud-init.

Recommended:

- Use a dedicated SSH keypair for this Dune VM instead of your normal personal key
- Use the same keypair for both cloud-init injection and later SSH access to the guest
- Guest SSH password authentication is not part of this workflow; the Ubuntu VM is expected to be accessed with the injected keypair

Default paths used by the wrapper:

- private key: `~/.ssh/id_ed25519`
- public key: `~/.ssh/id_ed25519.pub`

If you leave the defaults unchanged, the wrapper will try those standard SSH key paths. That is convenient, but a dedicated Dune-specific keypair is the safer recommendation.

## Quick Start on WSL Ubuntu

Example controller setup on a clean WSL Ubuntu install:

```bash
sudo apt update
sudo apt install -y git python3 python3-venv openssh-client
git clone https://github.com/IEquilibriumI/dune-selfhost-ansible.git
cd dune-selfhost-ansible
python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install ansible
ssh-keygen -t ed25519 -f ~/.ssh/dune_vm_ed25519
```

If you install Ansible into a local virtualenv instead of system-wide, either activate the venv first or run:

```bash
ANSIBLE_PLAYBOOK=/path/to/venv/bin/ansible-playbook ./scripts/run_full_setup.sh
```

For a dedicated project keypair on this example setup, you would typically use:

- private key: `~/.ssh/dune_vm_ed25519`
- public key: `~/.ssh/dune_vm_ed25519.pub`

## Inventory Setup

Use `inventory/inventory.ini` as the public sample:

```ini
[proxmox]
pve ansible_host=YOUR_PROXMOX_IP ansible_user=YOUR_PROXMOX_USER
```

Replace:

- `YOUR_PROXMOX_IP` with your Proxmox host IP or DNS name
- `YOUR_PROXMOX_USER` with the SSH user Ansible should use on Proxmox

## Running the Full Setup

From the repo root:

```bash
./scripts/run_full_setup.sh
```

If `ansible-playbook` is not on `PATH`:

```bash
ANSIBLE_PLAYBOOK=/path/to/ansible-playbook ./scripts/run_full_setup.sh
```

## Prompt Reference

The wrapper prompts for the following values:

| Prompt | Meaning |
|---|---|
| `Inventory file path` | Inventory containing the Proxmox host |
| `SSH private key path for the Dune VM` | Private key used to SSH into the Ubuntu guest; a dedicated Dune-specific key is recommended |
| `SSH public key path for VM creation` | Public key injected into the guest by cloud-init; should match the private key above |
| `Ubuntu cloud-init template VMID` | Proxmox VMID for the Ubuntu template |
| `Template name` | Template VM name |
| `New Dune VMID` | Proxmox VMID for the Dune server VM |
| `New Dune VM name` | Name of the Dune VM in Proxmox |
| `Proxmox storage` | Proxmox storage target such as `local-lvm` |
| `Proxmox bridge` | VM bridge such as `vmbr0` or `vmbr2` |
| `CPU cores` | Guest CPU allocation |
| `RAM in GB` | Guest memory allocation |
| `Disk size in GB` | Guest disk size |
| `VM internal IP/CIDR` | Static IP and subnet for the guest |
| `VM gateway IP` | Default gateway for that subnet |
| `Dune VM IP address` | Same VM IP without CIDR suffix |
| `Linux package source URL or local archive path` | Optional direct package source; leave blank for SteamCMD |
| `Dune self-host server Steam app ID` | Defaults to live App ID `4754530` |
| `Player-facing IP override` | Optional public IP override; blank uses auto-detection |
| `World/server name` | Name shown to players |
| `World region` | `1=Asia`, `2=Europe`, `3=North America`, `4=Oceania`, `5=South America` |
| `Self-host service token` | Funcom self-host JWT token |

## Example Values

Example answers for a typical home lab:

| Prompt | Example |
|---|---|
| Template VMID | `200` |
| Template name | `ubuntu-2404-cloudinit` |
| Dune VMID | `201` |
| Dune VM name | `Dune-Server` |
| Proxmox storage | `local-lvm` |
| Proxmox bridge | `vmbr0` |
| CPU cores | `6` |
| RAM in GB | `40` |
| Disk size in GB | `110` |
| VM internal IP/CIDR | `192.168.1.200/24` |
| VM gateway IP | `192.168.1.1` |
| Dune VM IP address | `192.168.1.200` |
| Linux package source | blank |
| Steam app ID | `4754530` |
| Player-facing IP override | blank |
| World region | `4` for Oceania, if applicable |

## How the Public IP and Datacenter ID Are Handled

This repo intentionally avoids hardcoding these values.

- `HOST_DATACENTER_IP_ADDRESS`
  - defaults to your detected public IP
  - can be overridden manually at the prompt
- `HOST_DATACENTER_ID`
  - is derived from the generated battlegroup ID
  - remains unique per created world

## Validation After Setup

Expected successful end state:

- the wrapper prints `Setup completed.`
- the Dune VM is reachable by SSH
- battlegroup status reports `Healthy`
- `Overmap` and `Survival_1` both report `Running true`

Useful checks on the Dune VM:

```bash
kubectl get pods -A
/home/dune/.dune/download/scripts/battlegroup.sh status
```

SSH example:

```bash
ssh dune@YOUR_DUNE_VM_IP
```

## Troubleshooting

### `ansible-playbook was not found`

Install Ansible or point the wrapper at it explicitly:

```bash
ANSIBLE_PLAYBOOK=/path/to/ansible-playbook ./scripts/run_full_setup.sh
```

### SSH fails after rebuilding the VM at the same IP

The playbooks already use relaxed host-key handling for the rebuilt guest. If you are manually SSHing and see host key mismatch warnings, remove the old entry from your local `known_hosts`.

### The wrapper asks for SSH key paths, but you normally use passwords

That is intentional. This repo provisions a fresh Ubuntu guest and injects an SSH public key through cloud-init. Later playbooks connect to that guest with the matching private key. Password-based SSH to the Dune VM is not implemented in the public workflow.

### SteamCMD returns `Missing configuration`

The install playbook already retries the live app download automatically. This is expected behavior on some first attempts.

### Battlegroup creation stalls on a fresh world

This repo preloads the live battlegroup images and seeds local `0-0-shipping` compatibility tags before `world.sh` runs. That avoids the vendor first-start schema race seen on clean hosts.

### `battlegroup.sh status` says `Reconciling` but the maps are already `Running true`

This can happen after a manual vendor `battlegroup.sh update`. In the validated setup, the game server pods, gateway, and director can all be healthy while the operator still reports a stale top-level `Reconciling` phase. Treat the individual map states and pod health as the stronger signal.

### Public IP detection is wrong

Use the `Player-facing IP override` prompt and enter the IP that players should connect through.

### You need a direct Linux package source instead of SteamCMD

Provide either:

- a direct URL to the Linux package archive
- a local archive path on the controller

If left blank, the repo uses SteamCMD with App ID `4754530`.

## Manual Playbook Order

If you do not want to use the wrapper, the validated manual flow is:

1. `playbooks/01_build_template.yml`
2. `playbooks/02_create_vm.yml`
3. `playbooks/03_bootstrap_vm.yml`
4. `playbooks/04_install_steamcmd.yml`
5. `playbooks/05_install_dune_server.yml`
6. `playbooks/06_install_k3s.yml`
7. `playbooks/07_bootstrap_kubernetes.yml`
8. `playbooks/10_run_vendor_setup.yml`

Optional helpers:

- `playbooks/08_run_dune_setup.yml`
- `playbooks/09_customize_world_template.yml`

## Notes

- No real inventory, tokens, hostnames, or public IPs are stored in this repo.
- Do not share raw `kubectl get battlegroup -o yaml` output publicly; it can include live self-host tokens and generated database credentials.
- The target Dune VM intentionally uses `/home/dune/...` paths because that matches the vendor script layout.

## License

This project is licensed under the GNU General Public License v3.0.
