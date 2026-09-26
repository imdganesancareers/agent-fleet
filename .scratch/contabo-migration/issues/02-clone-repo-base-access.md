# 02 — Clone the repo and confirm base access on the new VM

Type: task
Status: resolved
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

## Answer

Ran `migrate.sh setup`, twice — the first run surfaced two real bugs, both fixed before the second:

1. **`migrate.sh` never created `$FLEET_DIR`'s parent on the remote** before rsyncing —
   `/root/projects/fleets` didn't exist on the new VM, so rsync failed with "No such file or
   directory". Fixed by adding `remote "mkdir -p '$FLEET_DIR'"` before the rsync call.
2. **Bigger catch: this local `agent-fleet` checkout's `origin` was misconfigured** — pointing at
   `gitlab.com/ai-agent-build-platform/agent-platform` (a different repo entirely) instead of
   `github.com/imdganesancareers/agent-fleet`. Local `main` was 8 commits ahead of the real GitHub
   `main`, unpushed — critically including `cd97dcc` (the SOUL.md-split mechanism from the
   `soul-md-split` map). Since the new VM clones fresh from GitHub, it would have gotten the *old*
   `create-agent.sh` that still expects `soul:` inside `agent.yaml` — but the synced `agent.yaml`
   files no longer have that field. That combination would have broken provisioning on the new VM the
   moment cutover tried to run `create-agent.sh` there. Fixed by pointing `origin` at
   `git@github.com:imdganesancareers/agent-fleet.git` (SSH — no HTTPS credential helper configured
   here) and pushing (fast-forward, confirmed safe first). Re-ran `setup`, which pulled the fix.

Verified on the new VM after the second run: Ubuntu 24.04.5 LTS, root SSH fine, repo at `cd97dcc`
(current), `create-agent.sh` has the SOUL.md-aware code (`grep -c SOUL_MD` → 4), all 4 `SOUL.md` files
present under the synced fleet directory, `secrets/` at `700`, all 4 `agent.yaml` at `600`. Headroom:
290G disk (2% used), 23Gi RAM (23Gi free) — comfortable.
