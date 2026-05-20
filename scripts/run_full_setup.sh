#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_ansible_playbook() {
  if [[ -n "${ANSIBLE_PLAYBOOK:-}" ]]; then
    printf '%s\n' "$ANSIBLE_PLAYBOOK"
    return 0
  fi

  if [[ -x "$ROOT_DIR/.venv/bin/ansible-playbook" ]]; then
    printf '%s\n' "$ROOT_DIR/.venv/bin/ansible-playbook"
    return 0
  fi

  command -v ansible-playbook || true
}

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="${3:-}"
  local reply

  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt_text [$default_value]: " reply
    printf -v "$var_name" '%s' "${reply:-$default_value}"
  else
    while true; do
      read -r -p "$prompt_text: " reply
      if [[ -n "$reply" ]]; then
        printf -v "$var_name" '%s' "$reply"
        break
      fi
    done
  fi
}

prompt_optional() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="${3:-}"
  local reply

  read -r -p "$prompt_text${default_value:+ [$default_value]}: " reply
  if [[ -n "$reply" ]]; then
    printf -v "$var_name" '%s' "$reply"
  else
    printf -v "$var_name" '%s' "$default_value"
  fi
}

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"
  local reply

  while true; do
    read -r -s -p "$prompt_text: " reply
    printf '\n'
    if [[ -n "$reply" ]]; then
      printf -v "$var_name" '%s' "$reply"
      break
    fi
  done
}

run_playbook() {
  local playbook_path="$1"
  shift
  "$ANSIBLE_BIN" -i "$INVENTORY_PATH" "$playbook_path" "$@"
}

ANSIBLE_BIN="$(find_ansible_playbook)"
if [[ -z "$ANSIBLE_BIN" ]]; then
  echo "ansible-playbook was not found. Set ANSIBLE_PLAYBOOK or install Ansible." >&2
  exit 1
fi

prompt_default INVENTORY_PATH "Inventory file path" "$ROOT_DIR/inventory/inventory.ini"

if [[ ! -f "$INVENTORY_PATH" ]]; then
  echo "Inventory file not found: $INVENTORY_PATH" >&2
  exit 1
fi

prompt_default SSH_PRIVATE_KEY_PATH "SSH private key path for the Dune VM" "${DUNE_SSH_PRIVATE_KEY_PATH:-$HOME/.ssh/id_ed25519}"
prompt_default SSH_PUBLIC_KEY_PATH "SSH public key path for VM creation" "${DUNE_SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}"

export DUNE_SSH_PRIVATE_KEY_PATH="$SSH_PRIVATE_KEY_PATH"
export DUNE_SSH_PUBLIC_KEY_PATH="$SSH_PUBLIC_KEY_PATH"

prompt_default TEMPLATE_VMID "Ubuntu cloud-init template VMID" "200"
prompt_default TEMPLATE_NAME "Template name" "ubuntu-2404-cloudinit"
prompt_default DUNE_VMID "New Dune VMID" "201"
prompt_default DUNE_VM_NAME "New Dune VM name" "Dune-Server"
prompt_default PROXMOX_STORAGE "Proxmox storage" "local-lvm"
prompt_default PROXMOX_BRIDGE "Proxmox bridge" "vmbr0"
prompt_default CPU_CORES "CPU cores" "6"
prompt_default RAM_GB "RAM in GB" "40"
prompt_default DISK_GB "Disk size in GB" "110"
prompt_default VM_IP_CIDR "VM internal IP/CIDR" "192.168.1.200/24"
prompt_default VM_GATEWAY "VM gateway IP" "192.168.1.1"
prompt_default VM_IP "Dune VM IP address" "${VM_IP_CIDR%%/*}"
prompt_optional DUNE_PACKAGE_SOURCE "Linux package source URL or local archive path (blank for SteamCMD)" ""
prompt_default STEAM_APP_ID "Dune self-host server Steam app ID" "4754530"
prompt_optional PLAYER_IP_OVERRIDE "Player-facing IP override (blank to auto-detect)" ""
prompt_default WORLD_NAME "World/server name" ""
prompt_default WORLD_REGION_CHOICE "World region: 1=Asia, 2=Europe, 3=North America, 4=Oceania, 5=South America" "3"
prompt_secret SELF_HOST_TOKEN "Self-host service token"

COMMON_ARGS=(
  -e "template_vmid=$TEMPLATE_VMID"
  -e "template_name=$TEMPLATE_NAME"
  -e "dune_vmid=$DUNE_VMID"
  -e "dune_vm_name=$DUNE_VM_NAME"
  -e "proxmox_storage=$PROXMOX_STORAGE"
  -e "proxmox_bridge=$PROXMOX_BRIDGE"
  -e "cpu_cores=$CPU_CORES"
  -e "ram_gb=$RAM_GB"
  -e "disk_gb=$DISK_GB"
  -e "vm_ip_cidr=$VM_IP_CIDR"
  -e "vm_gateway=$VM_GATEWAY"
  -e "ssh_public_key_path=$SSH_PUBLIC_KEY_PATH"
  -e "vm_ip=$VM_IP"
  -e "dune_package_source=$DUNE_PACKAGE_SOURCE"
  -e "steam_app_id=$STEAM_APP_ID"
  -e "player_ip_override=$PLAYER_IP_OVERRIDE"
  -e "world_name=$WORLD_NAME"
  -e "world_region_choice=$WORLD_REGION_CHOICE"
  -e "self_host_token=$SELF_HOST_TOKEN"
)

run_playbook "$ROOT_DIR/playbooks/01_build_template.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/02_create_vm.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/03_bootstrap_vm.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/04_install_steamcmd.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/05_install_dune_server.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/06_install_k3s.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/07_bootstrap_kubernetes.yml" "${COMMON_ARGS[@]}"
run_playbook "$ROOT_DIR/playbooks/10_run_vendor_setup.yml" "${COMMON_ARGS[@]}"

echo
echo "Setup completed."
echo "VM IP: $VM_IP"
