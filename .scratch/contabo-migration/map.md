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

- **Depends on `soul-md-split`** (a separate map, `.scratch/soul-md-split/map.md`) for the sequencing
  already decided: agent.yaml/persona wiring gets sorted out and verified on the *current* machine
  before the migration's own cutover (ticket 06) runs, so a machine move and an identity change aren't
  both happening at once. Check that map's status before starting ticket 06.

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
  re-clonable). **New VM confirmed 2026-09-26** (`13.140.190.206`,
  hostname `vmi3573588`, Ubuntu 24.04.5): 8 vCPU / 23GB RAM / 290GB disk —
  bigger across the board, not just +24GB RAM as first estimated. Root SSH
  from the old VM confirmed working, key-based.
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
- Secrets/fleet-data transfer: direct SSH rsync between the two boxes for
  non-secret data and Discord credentials — **refined 2026-09-26**: Claude
  token is re-issued fresh on the new VM instead of rsynced; Discord (bot
  tokens, application_id, guild_id, operator_user_id) stays as-is. **Refined
  again, same day**: the 4 GitLab PATs are *also* kept as-is (rsynced), not
  re-issued — minting fresh service-account PATs needs group-Owner
  permission the operator doesn't have today (see
  [gitlab-token-rotation.md](../gitlab-token-rotation.md)), and a PAT isn't
  machine-bound anyway. See [Transfer fleet secrets](issues/05-transfer-fleet-secrets.md).
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
- [Architecture reconsideration: industry patterns for multi-agent fleets](issues/11-container-runtime-choice.md) — no change on any axis (isolation, runtime, orchestration, session model), now grounded in verified industry comparison rather than first-principles assumption; unblocks [Cutover swap per agent](issues/06-cutover-swap-per-agent.md) with no provisioning changes needed (findings on branch `research/fleet-architecture-industry-patterns`)
- [Confirm root SSH access](issues/01-confirm-ssh-access.md) — new VM is `13.140.190.206` (`vmi3573588`), key-based root access verified working, real specs confirmed (8 vCPU / 23GB RAM / 290GB disk, bigger than first estimated)
- [Write the migration script](issues/13-write-migration-script.md) — `migrate.sh setup`/`cutover <name>` written, refuses to cut over until a fresh Claude token and re-issued GitLab PATs are actually on the new VM (tested live: correctly refused pre-token-setup); `setup` itself not yet run for real
- [Clone repo and confirm base access](issues/02-clone-repo-base-access.md) — `migrate.sh setup` run for real (twice — fixed a missing-`mkdir` bug, and caught that this local checkout's `origin` was pointed at the wrong repo entirely, meaning 8 commits including the SOUL.md-split mechanism hadn't reached GitHub; pushed before re-running). New VM verified: Ubuntu 24.04.5, repo at current `main`, `SOUL.md`-aware scripts, 290G/23Gi headroom.
- [Clean up aruvii-developer's workspace](issues/03-clean-up-aruvii-developer-workspace.md) — deleted the
  unused `docker-compose-dev.yaml`; being behind on `master` needs no fix (fresh clone handles it). Found
  a real risk beyond the ticket's original scope — the `refactor/285-usercontroller-ragdocument-it`
  worktree had an unpushed commit plus a deliberately-held-back file (blocked on #304) — **operator's
  final call: delete the whole thing**, including the never-pushed commit. Worktree, branch, and file
  all gone; workspace now clean (just `master` + the already-pushed `fix/481` worktree).
- [Transfer fleet secrets](issues/05-transfer-fleet-secrets.md) — Claude token minted for real on the new
  VM (operator ran `setup-claude-token.sh` interactively, verified present/`0600`/correct prefix). GitLab
  tokens: plan changed mid-ticket — reused as-is instead of re-issued (see Notes); `migrate.sh cutover`'s
  "must differ" check downgraded from a hard fail to a warning to match.
- [Resource governance](issues/12-resource-governance.md) — new `resources:` block in `agent.yaml`
  (`memory_max`, `shared_images`), implemented in `create-agent.sh`, applied and verified live on all 4
  agents on **this** VM (fixes the box actually running today; the script itself reaches the new VM on
  the next pull). Tiered memory ceiling (6G dev/qa, 3G analyst/spec-reviewer) via a systemd user-slice
  drop-in; a daily prune timer that turned out to need a third step beyond the ticket's plan — buildah's
  own leftover working containers survive a normal `podman container prune`, and 48 of them were found
  pinning ~7GB on `aruvii-developer` alone (7.6G → 488M after cleanup); a shared read-only base-image
  store for dev+qa. Also caught: the ticket's own image list had a stale `maven` image left over from
  before the Gradle migration (#440) — corrected against the real Dockerfile/compose/Testcontainers refs.

- **This local `agent-fleet` checkout's `origin` remote was found misconfigured** (pointed at
  `gitlab.com/ai-agent-build-platform/agent-platform` instead of
  `github.com/imdganesancareers/agent-fleet`) — fixed to the SSH form
  (`git@github.com:imdganesancareers/agent-fleet.git`; no HTTPS credential helper is configured here).
  Worth a sanity check (`git remote -v`) before any future push from this checkout, since it's easy for
  this to silently drift again while working across two different GitLab/GitHub repos in the same
  session.

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
