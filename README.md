# agent-fleet

Provision and manage a fleet of autonomous, Discord-connected [Claude Code](https://claude.com/claude-code)
agents on a single Linux VM — each one an isolated unix user running Claude Code
in tmux, talking to its operator only through a Discord channel, working in its
own clone of a GitLab repo.

You describe an agent once in a small YAML recipe (identity, purpose, soul,
guardrails, tokens); a deterministic shell script turns that recipe into a
running agent and keeps it reconciled. Skills (slash commands for Claude Code)
wrap the scripts with interviews and checklists, but every state change goes
through a script — reruns are safe and reality stays reproducible.

## How it works

One agent is:

| Piece | What |
|---|---|
| unix user `agent-<name>` | isolation boundary: no sudo, own home, own toolchain (claude, bun, glab) |
| tmux session `<name>` | runs `claude --dangerously-skip-permissions --channels plugin:discord` |
| `agents/<name>/agent.yaml` | the **recipe** — the single self-contained definition (identity + secrets) |
| `~/projects/<repo>` | the agent's workspace, cloned from GitLab over its own ssh key |
| an entry in `fleet.yaml` | the **registry of record**: name, status (active/retired), created, purpose |

The agent's identity (persona, purpose, soul, guardrails) is rendered from the
recipe into a **root-owned, read-only** `CLAUDE.md` in its home — the agent
cannot rewrite who it is. Discord access is equally locked down: the allowlist
(`access.json`, root-owned) is snapshotted at boot (`DISCORD_ACCESS_MODE=static`),
so an agent cannot grant itself new interlocutors. Its operator reads Discord,
never the terminal; the agent posts progress, questions, and results to its home
channel and reacts only when mentioned.

## Repo layout

```
agents/<name>/agent.yaml     # per-agent recipe (secrets — gitignored, chmod 600)
agents/<name>/invite-url.txt # the bot's Discord invite URL, written by create
fleet.yaml                   # registry of record — written only by the scripts
secrets/claude-token         # fleet-shared Claude OAuth token (gitignored)
scripts/                     # the deterministic lifecycle scripts (below)
.claude/skills/              # create/list/update/delete-agent skills wrapping them
CONTEXT.md                   # the glossary — one term, one meaning
docs/adr/                    # decisions worth remembering
```

## Lifecycle scripts

All root-run, all name-based (they resolve the repo root from their own
location), all deterministic:

| Script | Does |
|---|---|
| `sudo ./scripts/create-agent.sh <name>` | provisions or **reconciles** an agent from its recipe: user, toolchain, GitLab auth + ssh key, repo clone, rendered config, Discord plugin, tmux relaunch, registry upsert. Rerunnable — keeps what already succeeded. |
| `sudo ./scripts/list-agent.sh` | prints the fleet table and reports **drift** (registry vs reality: missing users, dead recipes, unregistered `agent-*` users). Exit 1 on drift — doubles as a health check. |
| `sudo ./scripts/update-agent.sh <name>` | applies identity-only edits (soul/persona) from the recipe: re-renders `CLAUDE.md`, refreshes the registry purpose, relaunches the session. |
| `sudo ./scripts/delete-agent.sh <name>` | retires an agent: destroys session, user, and home after a type-the-name confirmation (`--yes` to skip). The recipe and registry entry survive, so recreation is one command. |
| `sudo ./scripts/setup-claude-token.sh` | one-time (yearly): mints the fleet's shared Claude OAuth token interactively and stores it at `secrets/claude-token`. |

`scripts/fleet-registry.py` is the only code that writes `fleet.yaml` — never
edit the registry by hand.

## Authentication model

- **Claude**: one account-wide OAuth token (operator's Max subscription,
  ~1-year) shared by the whole fleet, injected as `CLAUDE_CODE_OAUTH_TOKEN` at
  session launch. Agents never hold their own Claude login; rotating = remint +
  relaunch. Rationale in [ADR 0001](docs/adr/0001-fleet-shared-claude-oauth-token.md).
- **GitLab**: per-recipe PAT (`glab auth login --stdin`, token never on argv)
  plus a per-agent ssh key the script generates and registers.
- **Discord**: per-agent bot token in the recipe, rendered into an agent-owned
  `.env`; DMs allowlisted to the operator's user id only.

Secrets live in exactly two gitignored places — `agents/*/agent.yaml` and
`secrets/` — and never in the registry, the skills, or git history.

## Quick start

Prerequisites: a Linux VM you root, a Discord application (bot token,
application/guild/channel ids), a GitLab PAT (`api` + `write_repository`).

```bash
sudo ./scripts/setup-claude-token.sh        # once per fleet (~yearly): browser authorize
# author agents/<name>/agent.yaml           # easiest via the /create-agent skill's interview
sudo ./scripts/create-agent.sh <name>       # provision; prints the bot invite URL
# open agents/<name>/invite-url.txt, invite the bot to your server
# mention the bot in its channel — it reacts, reads, and replies
```

Operating day to day happens through the skills in a root Claude Code session
opened in this repo: `/create-agent` interviews you into a recipe and runs the
script; `/list-agent` shows fleet health; `/update-agent` grills identity
changes; `/delete-agent` retires deliberately.

## Vocabulary

Fleet, recipe, registry, drift, retired, fleet token — every term is defined
once in [CONTEXT.md](CONTEXT.md); scripts, skills, and docs use them exactly.
