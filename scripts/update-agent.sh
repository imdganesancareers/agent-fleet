#!/usr/bin/env bash
# update-agent.sh — apply identity-only changes from agents/<name>/agent.yaml to
# an already-provisioned agent: re-render CLAUDE.md (persona, purpose, soul,
# guardrails), refresh the archived YAML and the registry's purpose line,
# restart the tmux session.
#
#   sudo ./scripts/update-agent.sh <name>
#
# Deliberately narrow for now: tokens, Discord access config, git identity,
# repo and installs are create-agent.sh's job — rerun that for those fields.
# The CLAUDE.md template and the launch line are kept in sync with
# create-agent.sh; change them there first.

set -euo pipefail

PLUGIN="discord@claude-plugins-official"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mfail\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
FLEET="$ROOT/fleet.yaml"

CLI_NAME=${1:-}
[[ $CLI_NAME ]] || die "usage: sudo $0 <name>   (reads $ROOT/agents/<name>/agent.yaml)"
[[ $EUID -eq 0 ]] || die "must run as root"
YAML="$ROOT/agents/$CLI_NAME/agent.yaml"
[[ -f $YAML ]] || die "no recipe at $YAML — run create-agent.sh first"

# ---------- parse identity fields, render CLAUDE.md ----------
STAGE=$(mktemp -d); chmod 700 "$STAGE"; trap 'rm -rf "$STAGE"' EXIT

python3 - "$YAML" "$STAGE" "$CLI_NAME" <<'PY' || die "agent.yaml invalid"
import re, sys, yaml

path, stage, cli_name = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = yaml.safe_load(open(path))

def get(d, dotted, req=True):
    cur = d
    for k in dotted.split('.'):
        cur = (cur or {}).get(k)
    if req and (cur is None or cur == ''):
        sys.exit(f"missing required field: {dotted}")
    return cur

name = get(cfg, 'name')
if not re.fullmatch(r'[a-z][a-z0-9-]{0,19}', name):
    sys.exit("name must be lowercase [a-z][a-z0-9-], max 20 chars")
if name != cli_name:
    sys.exit(f"agent.yaml name '{name}' does not match folder agents/{cli_name}/")

# identity fields must be real text, not placeholders
for f in ('persona.display_name', 'purpose', 'soul', 'guardrails'):
    if str(get(cfg, f)).strip().startswith('REPLACE_'):
        sys.exit(f"unfilled placeholder in identity field: {f}")

repo = get(cfg, 'gitlab.repo')
repo_dir = re.sub(r'\.git$', '', repo.rsplit('/', 1)[-1])
channels = get(cfg, 'discord.channels')
if not isinstance(channels, list) or not channels or not channels[0].get('id'):
    sys.exit("discord.channels must be a non-empty list with ids")

def shq(s):
    return "'" + str(s).replace("'", "'\\''") + "'"

with open(f"{stage}/env.sh", 'w') as f:
    for k, v in {'NAME': name, 'REPO_DIR': repo_dir,
                 'DISPLAY_NAME': get(cfg, 'persona.display_name')}.items():
        f.write(f"{k}={shq(v)}\n")

# --- CLAUDE.md template: keep in sync with create-agent.sh ---
disp = get(cfg, 'persona.display_name')
pron = get(cfg, 'persona.pronouns', req=False) or 'they/them'
emoji = get(cfg, 'persona.emoji', req=False) or ''
home_chat = str(channels[0]['id'])
open(f"{stage}/CLAUDE.md", 'w').write(f"""# {disp} {emoji} — agent-{name}

You are {disp} ({pron}), an autonomous Claude agent running as unix user
`agent-{name}` on this VM. Your workspace is `~/projects/{repo_dir}`.

## Discord is your only interface

Your operator reads Discord, never this terminal — text you print in the session
is invisible to them. Everything you want a human to see goes through the discord
`reply` tool. Your home channel is chat_id `{home_chat}`: post there when you
start a task, when you finish, when you are blocked, and whenever you need an
answer or a go-ahead. If you have been working silently for more than a few
minutes, post a progress update there.

## Purpose

{get(cfg, 'purpose').strip()}

{get(cfg, 'soul').strip()}

{get(cfg, 'guardrails').strip()}
""")
PY
source "$STAGE/env.sh"

AGENT="agent-$NAME"
HOME_DIR="/home/$AGENT"
REPO_PATH="$HOME_DIR/projects/$REPO_DIR"
as_agent() { runuser -l "$AGENT" -c "$1"; }

id -u "$AGENT" >/dev/null 2>&1 || die "no such agent: $AGENT — run create-agent.sh first"
[[ -d $REPO_PATH ]] || die "workspace $REPO_PATH missing — gitlab.repo changed? that's create-agent.sh's job"
# fail fast: the relaunch is impossible without the fleet's shared Claude token
CLAUDE_TOKEN_FILE="$ROOT/secrets/claude-token"
[[ -s $CLAUDE_TOKEN_FILE ]] \
  || die "no fleet Claude token at secrets/claude-token — mint it once with: sudo $SCRIPT_DIR/setup-claude-token.sh"

# ---------- apply identity, refresh archive ----------
install -o root -g root -m 0444 "$STAGE/CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"
install -o root -g root -m 0400 "$YAML"            "$HOME_DIR/agent.yaml"
python3 "$SCRIPT_DIR/fleet-registry.py" "$FLEET" set-purpose "$NAME" --purpose-from "$YAML"
ok " identity applied (CLAUDE.md re-rendered, archive + registry purpose refreshed)"

# ---------- relaunch so the new identity loads ----------
install -o "$AGENT" -g "$AGENT" -m 0400 "$CLAUDE_TOKEN_FILE" "$HOME_DIR/.claude/claude-token"

log "restarting tmux session '$NAME'"
as_agent "tmux kill-session -t '$NAME' 2>/dev/null" || true
as_agent "cd '$REPO_PATH' && tmux new-session -d -s '$NAME' 'CLAUDE_CODE_OAUTH_TOKEN=\$(cat ~/.claude/claude-token) DISCORD_ACCESS_MODE=static claude --dangerously-skip-permissions --channels plugin:$PLUGIN'"
ok " session '$NAME' relaunched"

echo
log "$DISPLAY_NAME updated."
echo "  test: mention the bot in its Discord channel and confirm the new identity."
