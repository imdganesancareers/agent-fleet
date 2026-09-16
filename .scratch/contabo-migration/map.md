# Map: Contabo migration — move the fleet to the new VM

Label: wayfinder:map
Charted: 2026-09-16

## Destination

The aruvii fleet (all 4 agents: aruvi-spec-reviewer, aruvii-analyst,
aruvii-developer, aruvii-qa) running live on the new, larger Contabo VM —
provisioned there via this repo's own scripts (not a disk clone), verified
answering in Discord and, for the two app-proxied agents, reachable over
HTTPS — and this old VM decommissioned after a soak period. Done when
`list-agent.sh aruvii` is healthy and drift-free on the new box and every
agent has answered a live Discord mention from there.

## Notes

- **This map carries execution** (operator's explicit choice, matches the
  precedent set by the `create-agent` and `agent-fleet-reorg` maps): tickets
  here are `task` tickets that *do*, not just decide.
- **Clean re-provision, not a disk clone** (operator's explicit steer): the
  new VM gets a fresh `git clone` of this repo and fresh `create-agent.sh`
  runs per agent — only `<fleet>/` (recipes + secrets + registry) is copied
  data; everything else is rebuilt by the scripts, which already
  self-install their own dependencies (tmux, git, podman stack, etc.) and
  self-invoke `install-enforcement.sh`.
- **Tooling stays single-VM-per-checkout** (settled at charting) — no code
  changes to the scripts to make them multi-VM aware; see Out of scope.
- Tracker: local markdown, this directory (`issues/NN-<slug>.md`).
- Skills per ticket type: `/grilling` + `/domain-modeling` for grilling
  tickets, `/research` for research tickets (none of that type needed here
  besides [Claude token portability](issues/04-research-claude-token-portability.md)).

### Facts gathered at charting (2026-09-16)

- Old VM: 4 vCPU / 8GB RAM / 96GB disk (42% used), Ubuntu 24.04.4. This
  repo's remote: `github.com/imdganesancareers/agent-fleet` (trivially
  re-clonable). New VM is the same shape plus ~24GB more RAM.
- `<fleet>/` (`/root/projects/fleets/aruvii`, 476K) lives outside this repo,
  is **not** in git, and holds secrets (Claude OAuth token, per-agent
  GitLab PATs, Discord bot tokens) — it is the one thing that must move by
  hand.
- `create-agent.sh` self-installs missing OS packages and self-invokes
  `install-enforcement.sh` (idempotent) — the new VM needs no manual
  dependency bootstrap beyond root SSH access and the repo clone.
- `setup-proxy.sh` (Caddy reverse proxy) is **not** auto-invoked by
  `create-agent.sh` — it's a separate manual run, needed only because two
  agents (`aruvii-developer`, `aruvii-qa`) declare an `app:` block with DNS
  pointed at this VM's IP.
- `aruvii-developer`'s workspace has one untracked file
  (`docker-compose-dev.yaml`) and is 5 commits behind its own remote; the
  other 3 agent workspaces are clean. Since the new VM gets a fresh clone,
  this needs resolving on the old VM first or it's lost.
- Discord bot tokens can hold only one active gateway session at a time —
  old and new can't run the same agent simultaneously, so cutover per agent
  is a stop-old-then-start-new swap, not a long parallel run.
- No memory ceiling exists on any agent's containers today, and it already
  caused a real incident: `journalctl -k` shows a container process under
  `aruvii-developer` got OOM-killed on 2026-08-29, with the OOM killer's
  reach extending to `systemd-journald` globally — the unix-user boundary
  controls access, not resource consumption. See [Resource
  governance](issues/12-resource-governance.md).

### Settled at charting (2026-09-16)

- Full cutover: everything moves, old VM decommissioned after verification
  (not a permanent two-VM split, not "new VM idle for later").
- Secrets/fleet-data transfer: direct SSH rsync between the two boxes.
- Agent workspaces: fresh `git clone` via `create-agent.sh` on the new VM,
  not an rsync of the actual workspace directories.
- DNS for the two app-proxied agents: operator controls it and will repoint
  it as part of cutover.
- Downtime: short (minutes–ish) is acceptable — provision as much as
  possible on the new VM ahead of the actual per-agent swap.
- The migration itself is scripted, not hand-run (operator's explicit
  call, 2026-09-16) — matches `CLAUDE.md`'s "a script owns a state change"
  rule. Scoped as a **throwaway helper for this move only**
  (`.scratch/contabo-migration/migrate.sh`), not a permanent addition to
  `scripts/` — keeps the earlier single-VM tooling-scope decision intact.
  See [Write the migration script](issues/13-write-migration-script.md).

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Research: Claude token portability](issues/04-research-claude-token-portability.md) — portable as-is, bearer credential not bound to the issuing machine/IP; rsync it, no re-minting needed (findings on branch `research/claude-token-portability`)

## Not yet specified

- Whether this VM hosts anything besides the aruvii fleet and this repo
  checkout that also needs a decision before it's safe to cancel — unclear
  until [Decommission the old VM](issues/10-decommission-old-vm.md) is
  actually reached.
- The operator's further plans for the new VM beyond this migration (they
  mentioned this is "first") — not part of this destination; likely a
  separate future effort once this one closes.

## Out of scope

- Making the tooling multi-VM aware (e.g. a `host:` field on registry
  entries, remote-exec support in the scripts) — ruled out at charting.
  Migration is achieved by re-provisioning on the new box with the existing
  single-VM scripts, not by generalizing them.
