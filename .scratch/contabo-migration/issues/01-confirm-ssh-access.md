# 01 — Confirm root SSH access to the new Contabo VM

Type: task
Status: resolved

## Question

Confirm (or establish) root SSH access from this VM to the new Contabo VM:
public key in place, port/firewall reachable, IP address recorded. Everything
downstream — the repo clone, the fleet-secrets rsync, and every lifecycle
script run on the new box — happens over this connection, so this is the
one thing that blocks the whole rest of the map.

## Answer (2026-09-26)

- **IP**: `13.140.190.206`, hostname `vmi3573588`, Ubuntu 24.04.5 LTS.
- Operator ran `ssh-copy-id root@13.140.190.206` from this VM (password
  used once, interactively, never shared with the agent) to install this
  VM's public key into the new box's `authorized_keys`.
- Verified key-based access from this VM: `ssh root@13.140.190.206` — no
  password, connects clean.
- **Real specs, corrected from the map's earlier estimate**: 8 vCPU / 23GB
  RAM / 290GB disk (2.9GB used) — bigger across the board than "old VM plus
  ~24GB RAM" suggested (old VM: 4 vCPU / 8GB / 96GB).

Unblocks: [Clone repo + base access](02-clone-repo-base-access.md), [Transfer
fleet secrets](05-transfer-fleet-secrets.md) (both also still blocked by
[Write the migration script](13-write-migration-script.md)).
