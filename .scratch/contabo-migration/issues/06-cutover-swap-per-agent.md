# 06 — Cutover: swap each agent from old VM to new VM

Type: task
Status: resolved
Blocked by: 02, 03, 04, 05, 11, 12, 13

## Question

Satisfied by running `.scratch/contabo-migration/migrate.sh cutover <name>`
per agent (see [Write the migration script](13-write-migration-script.md))
rather than the manual commands below.

Blocked on [Resource governance](12-resource-governance.md) landing first
(operator's explicit call, 2026-09-16): the new VM should start with memory
ceilings and scheduled disk pruning in place, not carry forward the
ungoverned model this VM currently runs.

A Discord bot token holds only one active gateway session at a time — the
old and new VM can't run the same agent simultaneously — so this is a
stop-old-then-start-new swap per agent, not a parallel run. For each of the
4 aruvii agents, in quick succession: stop the agent's tmux session on this
VM, then immediately run `sudo ./scripts/create-agent.sh aruvii <name>` on
the new VM to reconcile it there (user, toolchain, GitLab auth + clone,
rendered `CLAUDE.md`, Discord plugin, tmux relaunch, registry upsert). If
[Claude token portability](04-research-claude-token-portability.md) found
the token needs re-minting, do that (`setup-claude-token.sh` on the new VM)
before running `create-agent.sh` for the first agent. If [Architecture
reconsideration](11-container-runtime-choice.md) changed anything about how
`create-agent.sh` provisions containers, that change must be live in the
new VM's checkout before this ticket runs.

## Answer

All 4 agents cut over, one at a time, `aruvii-analyst` → `aruvi-spec-reviewer` → `aruvii-qa` →
`aruvii-developer`. Verified clean on both sides: no tmux session remains for any agent on the old VM,
all 4 have a live session on the new VM. `aruvii-analyst` was confirmed working live — it answered a
real Discord mention ("who are you?") from the new VM during cutover. `aruvii-developer` correctly
logged in as its own `aruvii-developer-agent` GitLab identity (never touched by the chiyanram stopgap),
confirming per-agent credentials stayed correctly scoped throughout.

**Two real bugs found and fixed along the way, both specific to a genuinely first-time user creation**
(never surfaced across extensive earlier testing on the old VM's already-existing agents):

1. `migrate.sh`'s `remote()` helper didn't redirect stdin from `/dev/null` — the cutover confirmation
   prompt (`read -r -p "Type the agent name to confirm:"`) got EOF because an earlier `ssh` call in the
   same script consumed the piped input first. Fixed.
2. A brand-new unix user's systemd `--user` session (D-Bus) isn't up immediately after
   `loginctl enable-linger` — every `systemctl --user` call (the new prune-timer step, and the
   pre-existing `podman.socket` enable) failed with "Failed to connect to bus". Fixed with a short poll
   for `/run/user/<uid>/bus` right after enabling linger.

**A third, unrelated but serious finding**: the new VM's `agent-fleet` checkout had its `origin`
silently repointed at `chiyanram/agent-fleet` (a personal fork, with a correctly-pointing `upstream`
alongside it) — meaning `migrate.sh setup` had been reporting "already up to date" while actually
several commits behind the real repo. Fixed by resetting `origin` back to `imdganesancareers/agent-fleet`
and fast-forwarding. See the map's Notes for the general lesson (sanity-check `git remote -v` before
trusting any sync).

Also installed mid-ticket, unplanned but directly relevant: `show-me` and `i-have-adhd` turned out to be
real, published Claude Code plugins (not fleet-authored as assumed) — switched from file-copying them
into this repo to installing them as real plugins (`claude plugin marketplace add` + `install`) per
agent, verified working on all 4. See `scripts/create-agent.sh`'s `plugin_skills` mechanism.
