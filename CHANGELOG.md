# Changelog

## v0.2.0

First public release of the Dune self-host Ansible workflow.

### Highlights

- Adds a single-entry wrapper script: `./scripts/run_full_setup.sh`
- Automates the full Proxmox -> Ubuntu -> SteamCMD -> k3s -> Dune world setup flow
- Supports the live Dune self-host Steam app `4754530`
- Supports direct Linux package archives as an alternative to SteamCMD
- Automatically patches the player-facing public IP into the generated battlegroup
- Derives a unique `HOST_DATACENTER_ID` from the generated battlegroup ID
- Works around the fresh-world `0-0-shipping` image race by preloading compatibility tags before `world.sh`
- Includes a public GitHub-style README with prerequisites, WSL setup, networking, validation, and troubleshooting guidance
- Licensed under `GPL-3.0`

### Notes

- This release is built around Proxmox and Ubuntu 24.04 guests
- Port forwarding is still required for outside players
- A valid Funcom self-host token is required
