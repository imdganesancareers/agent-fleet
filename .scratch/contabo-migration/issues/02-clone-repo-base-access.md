# 02 — Clone the repo and confirm base access on the new VM

Type: task
Status: open
Blocked by: 01, 13

## Question

Satisfied by running `.scratch/contabo-migration/migrate.sh setup` (see
[Write the migration script](13-write-migration-script.md)) rather than
manual commands. On the new VM: confirm root shell access and OS (Ubuntu
24.04 or compatible), then clone
`git@github.com:imdganesancareers/agent-fleet.git` to the same layout used
on this VM. No manual dependency pre-install is needed beyond that — `create-agent.sh` installs its own missing packages
(tmux, git, curl, unzip, python3-yaml, the podman rootless stack,
podman-compose, docker-compose v2 shim) and self-invokes
`install-enforcement.sh` on first run per agent. Confirm the new VM has
headroom for 4 agents plus podman build workloads (this VM runs them today
at 40G/96G disk, 2.9G/7.8G RAM idle) — the new VM being ~24GB bigger in RAM
should be comfortable either way.
