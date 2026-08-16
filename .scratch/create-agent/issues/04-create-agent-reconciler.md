# create-agent.sh reconciler

Type: task
Status: resolved
Blocked by: 01, 02, 03

## Question

Write `create-agent.sh`: root-run, takes `agent.yaml`, idempotent/reconciling —
rerun amends changed config, always kills and relaunches the agent's tmux session.

Step sequence (adapted from spec 100's create sequence, GitLab-only, no systemd):
preflight + install host deps (tmux, git, curl) → useradd `agent-<name>` no-sudo (skip
if exists) → skel + rendered `.bashrc` → claude native installer as agent → **bun
installer as agent** (the discord plugin's MCP server runs on Bun — verified on the
reference user) → `glab` tarball to `~/.local/bin` → `glab auth login --with-token`
(PAT from YAML via stdin) →
`ssh-keygen` + `ssh-keyscan gitlab.com` + `glab ssh-key add` → `git config` author
from YAML → clone `repo:` to `~/projects/<repo>` → render CLAUDE.md (root 0444) →
discord plugin install + `.env` + `access.json` per the
[Discord plugin surface](01-discord-plugin-surface.md) findings → archive YAML to
`~/agent.yaml` (root 0400) → kill existing tmux session → launch
`tmux new-session -d -s <name> -c ~/projects/<repo> 'claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official'`
as the agent user → print the attach command for first-time OAuth.

Settle inside this ticket: yq vs python3 YAML parsing; per-step "already done" checks;
which amends a rerun applies (tokens, rendered files) vs. leaves alone (clone, keys).

Launch-cwd invariant (from the reference user, which launches from `~/projects` — the
plugin's projectPath — not from inside a repo): the plugin install dir, the
`hasTrustDialogAccepted` entry, the `.claude/settings.json` enabledPlugins, and
`tmux -c` must all point at the SAME directory (`~/projects/<repo>` in our design), or
the agent starts but is deaf on Discord.

## Answer

Built: `create-agent.sh` at the repo root (bash, `set -euo pipefail`, ~250 lines).
Settled in-ticket: **python3 + PyYAML** for parsing (present on host; no yq); a single
embedded python stage parses, validates (required fields, `REPLACE_` placeholders,
name regex), and renders all config content (env vars shell-quoted, `access.json`,
`settings.json`, `discord.env`, `CLAUDE.md`) into a mktemp stage dir; bash owns users,
installs, ownership, tmux. Rerun semantics: user/toolchain/ssh/clone steps skip when
present; rendered files, glab auth, trust, and the YAML archive re-apply every run;
tmux session always killed + relaunched. Secrets go via stdin (glab) and 0600 files —
never argv. Plugin install tolerates pre-OAuth failure with an explicit "rerun after
login" warning. Launch honors the cwd invariant: trust + plugin scope + `tmux -c` all
target `~/projects/<repo>`; PATH set via a marker block in `.profile`/`.bashrc`;
`DISCORD_ACCESS_MODE=static` in both `.env` and the launch env.
Verified: `bash -n` clean; parse/validate/render stage exercised against a sample
YAML (hostile token quoting, placeholder abort, missing-field abort all pass).
Unverified until [First agent on the VM](05-first-agent-on-the-vm.md): the live path
(useradd, installers, glab against gitlab.com, plugin install, gateway connect).
