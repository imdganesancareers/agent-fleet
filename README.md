# agent-fleet

Provision and manage fleets of autonomous, Discord-connected [Claude Code](https://claude.com/claude-code)
agents on a single Linux VM — each agent an isolated unix user running Claude
Code in tmux, talking to its operator only through a Discord channel, working
in its own clone of a GitLab repo.

You describe an agent once in a small YAML recipe (identity, purpose, soul,
guardrails, tokens); a deterministic shell script turns that recipe into a
running agent and keeps it reconciled. Skills (slash commands for Claude Code)
wrap the scripts with interviews and checklists, but every state change goes
through a script — reruns are safe and reality stays reproducible.

This repo is **tooling only**. Fleet data — recipes, registries, tokens, and
each fleet's refinement docs — lives in self-contained **fleet directories**
outside the repo, under `$FLEETS_ROOT` (default `/root/projects/fleets/`).
Every script takes the fleet first: a bare name resolves under `$FLEETS_ROOT`,
anything containing `/` is used as a path; `FLEET=<fleet>` works as an env
alternative. Agent names stay unique across all fleets (unix users are
VM-global).

## How it works

One agent is:

| Piece | What |
|---|---|
| unix user `agent-<name>` | isolation boundary: no sudo, own home, own toolchain (claude, bun, glab) |
| tmux session `<name>` | runs `claude --dangerously-skip-permissions --channels plugin:discord` |
| `<fleet>/agents/<name>/agent.yaml` | the **recipe** — the single self-contained definition (identity + secrets) |
| `~/projects/<repo>` | the agent's workspace, cloned from GitLab over its own ssh key |
| an entry in `<fleet>/fleet.yaml` | the fleet's **registry of record**: name, status (active/retired), created, purpose |

The agent's identity (persona, purpose, soul, guardrails) is rendered from the
recipe into a **root-owned, read-only** `CLAUDE.md` in its home — the agent
cannot rewrite who it is. Discord access is equally locked down: the allowlist
(`access.json`, root-owned) is snapshotted at boot (`DISCORD_ACCESS_MODE=static`),
so an agent cannot grant itself new interlocutors. Its operator reads Discord,
never the terminal; the agent posts progress, questions, and results to its home
channel and reacts only when mentioned.

## Layout

A fleet directory (outside this repo, e.g. `/root/projects/fleets/aruvii/`):

```
<fleet>/agents/<name>/agent.yaml     # per-agent recipe (secrets — chmod 600)
<fleet>/agents/<name>/invite-url.txt # the bot's Discord invite URL, written by create
<fleet>/fleet.yaml                   # the fleet's registry — written only by the scripts
<fleet>/secrets/claude-token         # the fleet's Claude OAuth token (0600)
<fleet>/docs/                        # that fleet's grilling/refinement documents
```

This repo (tooling only):

```
scripts/          # the deterministic lifecycle scripts (below) + fleet-lib.sh resolver
skills/           # fleet skills rendered into granted agents (all fleets share them)
enforcement/      # machine-wide fleet-guard hook sources
.claude/skills/   # create/list/update/delete-agent skills wrapping the scripts
CONTEXT.md        # the glossary — one term, one meaning
docs/adr/         # decisions worth remembering
```

## Lifecycle scripts

All root-run, all fleet-then-name based, all deterministic. The fleet is a
bare name under `$FLEETS_ROOT` or a path containing `/`; `create-agent.sh`
skeleton-creates a new fleet dir on first use.

| Script | Does |
|---|---|
| `sudo ./scripts/create-agent.sh <fleet> <name>` | provisions or **reconciles** an agent from its recipe: user, toolchain, GitLab auth + ssh key, repo clone, rendered config, Discord plugin, tmux relaunch, registry upsert. Rerunnable — keeps what already succeeded. Refuses a name any other fleet holds. |
| `sudo ./scripts/list-agent.sh <fleet>` | prints the fleet's table and reports **drift** (registry vs reality: missing users, dead recipes, `agent-*` users no fleet registers). Exit 1 on drift — doubles as a health check. |
| `sudo ./scripts/update-agent.sh <fleet> <name>` | applies identity-only edits (soul/persona) from the recipe: re-renders `CLAUDE.md`, refreshes the registry purpose, relaunches the session. |
| `sudo ./scripts/delete-agent.sh <fleet> <name>` | retires an agent: destroys session, user, and home after a type-the-name confirmation (`--yes` to skip). The recipe and registry entry survive, so recreation is one command. |
| `sudo ./scripts/setup-claude-token.sh <fleet>` | one-time per fleet (yearly): mints that fleet's Claude OAuth token interactively and stores it at `<fleet>/secrets/claude-token`. |

`scripts/fleet-lib.sh` is the shared resolver every script sources.

`scripts/fleet-registry.py` is the only code that writes a fleet's `fleet.yaml`
— never edit a registry by hand.

## Authentication model

- **Claude**: one OAuth token per fleet (a Max subscription, ~1-year) shared by
  that fleet's agents, injected as `CLAUDE_CODE_OAUTH_TOKEN` at session launch —
  different fleets may bill different Claude accounts. Agents never hold their
  own Claude login; rotating = remint + relaunch. Rationale in
  [ADR 0001](docs/adr/0001-fleet-shared-claude-oauth-token.md).
- **GitLab**: per-recipe PAT (`glab auth login --stdin`, token never on argv)
  plus a per-agent ssh key the script generates and registers.
- **Discord**: per-agent bot token in the recipe, rendered into an agent-owned
  `.env`; DMs allowlisted to the operator's user id only.

Secrets live only inside fleet directories — `<fleet>/agents/*/agent.yaml` and
`<fleet>/secrets/` — outside this repo entirely, and never in a registry, the
skills, or git history. (The repo's `.gitignore` still blocks `agents/`,
`secrets/`, and `*.agent.yaml` as belt-and-braces should a recipe ever be
created here by mistake.)

## Quick start

Prerequisites: a Linux VM you root, a Discord application (bot token,
application/guild/channel ids), a GitLab PAT (`api` + `write_repository`).

```bash
sudo ./scripts/setup-claude-token.sh myfleet    # once per fleet (~yearly): browser authorize
# author <fleet>/agents/<name>/agent.yaml       # easiest via the /create-agent skill's interview
sudo ./scripts/create-agent.sh myfleet <name>   # provision; prints the bot invite URL
# open <fleet>/agents/<name>/invite-url.txt, invite the bot to your server
# mention the bot in its channel — it reacts, reads, and replies
```

Operating day to day happens through the skills in a root Claude Code session
opened in this repo: `/create-agent` interviews you into a recipe and runs the
script; `/list-agent` shows fleet health; `/update-agent` grills identity
changes; `/delete-agent` retires deliberately.

## Vocabulary

Fleet, recipe, registry, drift, retired, fleet token — every term is defined
once in [CONTEXT.md](CONTEXT.md); scripts, skills, and docs use them exactly.
