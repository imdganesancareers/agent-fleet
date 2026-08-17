#!/usr/bin/env bash
# create-agent.sh — provision (or reconcile) one Discord-connected Claude Code agent
# on this VM from its recipe at <fleet>/agents/<name>/agent.yaml.
#
#   sudo ./scripts/create-agent.sh <fleet> <name>
#   FLEET=<fleet> sudo ./scripts/create-agent.sh <name>
#
# The fleet is a bare name (resolved to $FLEETS_ROOT/<name>, default
# /root/projects/fleets) or a path containing '/'. A new fleet directory is
# skeleton-created on first use. Agent names are VM-global: a name claimed by
# another fleet (or a foreign unix user) is refused.
#
# Rerunnable: existing pieces (user, installs, clone, ssh key) are kept, rendered
# config is refreshed, and the tmux session is always killed and relaunched. On
# success the agent's entry in the fleet's fleet.yaml is upserted (status active,
# created date kept on rerun). Author the recipe with the /create-agent skill;
# schema in .claude/skills/create-agent/agent-yaml.md.

set -euo pipefail

MARKETPLACE="anthropics/claude-plugins-official"
PLUGIN="discord@claude-plugins-official"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok \033[0m%s\n' "$*"; }
warn() { printf '\033[1;33mwarn\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mfail\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
source "$SCRIPT_DIR/fleet-lib.sh"

USAGE="usage: sudo $0 <fleet> <name>   (or FLEET=<fleet> sudo $0 <name>)
  reads <fleet>/agents/<name>/agent.yaml; bare fleet names resolve under FLEETS_ROOT=$FLEETS_ROOT"

fleet_args 1 "$@"
CLI_NAME=${REST[0]:-}
[[ $CLI_NAME ]] || die "$USAGE"
[[ $CLI_NAME =~ ^[a-z][a-z0-9-]{0,19}$ ]] || die "name must be lowercase [a-z][a-z0-9-], max 20 chars"
[[ $EUID -eq 0 ]] || die "must run as root"

# fleet skeleton: a new fleet dir is born whole, an old one gets missing pieces
mkdir -p "$FLEET_DIR/agents" "$FLEET_DIR/docs" "$FLEET_DIR/secrets"
chmod 700 "$FLEET_DIR/secrets"

YAML="$FLEET_DIR/agents/$CLI_NAME/agent.yaml"
[[ -f $YAML ]] || die "no recipe at $YAML — author it with the /create-agent skill"
chmod 600 "$YAML"
# fail fast: the launch is impossible without the fleet's shared Claude token
CLAUDE_TOKEN_FILE="$FLEET_DIR/secrets/claude-token"
[[ -s $CLAUDE_TOKEN_FILE ]] \
  || die "no Claude token at $FLEET_DIR/secrets/claude-token — mint it once with: sudo $SCRIPT_DIR/setup-claude-token.sh $FLEET_SPEC"

# agent names are VM-global (one unix user, one tmux session namespace):
# refuse a name that another fleet's registry already claims, or a unix user
# this fleet's registry doesn't know about
for reg in "$FLEETS_ROOT"/*/fleet.yaml; do
  [[ -f $reg ]] || continue
  [[ $(readlink -m "$reg") == "$(readlink -m "$REGISTRY")" ]] && continue
  if python3 "$SCRIPT_DIR/fleet-registry.py" "$reg" get "$CLI_NAME" status >/dev/null 2>&1; then
    die "agent name '$CLI_NAME' is already registered by fleet $(dirname "$reg") — agent names are VM-global"
  fi
done
if id -u "agent-$CLI_NAME" >/dev/null 2>&1 \
   && ! python3 "$SCRIPT_DIR/fleet-registry.py" "$REGISTRY" get "$CLI_NAME" status >/dev/null 2>&1; then
  die "unix user agent-$CLI_NAME exists but is not in this fleet's registry — claimed elsewhere; pick another name"
fi

# ---------- host prerequisites (the only apt step) ----------
log "host prerequisites"
missing=()
for p in tmux git curl unzip; do command -v "$p" >/dev/null || missing+=("$p"); done
python3 -c 'import yaml' 2>/dev/null || missing+=(python3-yaml)
# rootless container runtime — fleet infrastructure for every agent (see
# .scratch/agent-runtime-and-guardrails/issues/02): podman answers as `docker`
command -v podman >/dev/null || missing+=(podman podman-docker uidmap slirp4netns passt catatonit)
command -v podman-compose >/dev/null || missing+=(podman-compose)
if ((${#missing[@]})); then
  apt-get update -qq
  apt-get install -y -qq "${missing[@]}"
fi
touch /etc/containers/nodocker   # silence the "Emulate Docker CLI" notice
ok " tmux, git, curl, unzip, python3(+yaml), podman(+docker shim, compose)"

# machine-wide enforcement layer: managed-settings hooks + per-agent policy dir
"$SCRIPT_DIR/install-enforcement.sh" >/dev/null
ok " enforcement layer (/etc/claude-code) current"

# ---------- parse agent.yaml, validate, render config files ----------
STAGE=$(mktemp -d); chmod 700 "$STAGE"; trap 'rm -rf "$STAGE"' EXIT

python3 - "$YAML" "$STAGE" "$CLI_NAME" "$ROOT" <<'PY' || die "agent.yaml invalid"
import json, os, re, sys, yaml

path, stage, cli_name, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
cfg = yaml.safe_load(open(path))

def get(d, dotted, req=True):
    cur = d
    for k in dotted.split('.'):
        cur = (cur or {}).get(k)
    if req and (cur is None or cur == ''):
        sys.exit(f"missing required field: {dotted}")
    return cur

placeholders = []
def leaves(x, p=''):
    if isinstance(x, dict):
        for k, v in x.items(): leaves(v, f"{p}.{k}" if p else k)
    elif isinstance(x, list):
        for i, v in enumerate(x): leaves(v, f"{p}[{i}]")
    elif isinstance(x, str) and x.strip().startswith('REPLACE_'):
        placeholders.append(p)
leaves(cfg)
if placeholders:
    sys.exit("unfilled placeholders: " + ", ".join(placeholders))

name = get(cfg, 'name')
if not re.fullmatch(r'[a-z][a-z0-9-]{0,19}', name):
    sys.exit("name must be lowercase [a-z][a-z0-9-], max 20 chars")
if name != cli_name:
    sys.exit(f"agent.yaml name '{name}' does not match folder agents/{cli_name}/")

repo = get(cfg, 'gitlab.repo')
repo_dir = re.sub(r'\.git$', '', repo.rsplit('/', 1)[-1])

channels = get(cfg, 'discord.channels')
if not isinstance(channels, list) or not channels:
    sys.exit("discord.channels must be a non-empty list")
for i, c in enumerate(channels):
    if not isinstance(c, dict) or not c.get('id'):
        sys.exit(f"discord.channels[{i}] needs an 'id'")
get(cfg, 'discord.guild_id')  # required by schema (documentation/invite use)

def shq(s):  # single-quote for shell: no interpolation of secrets
    return "'" + str(s).replace("'", "'\\''") + "'"

scalars = {
    'NAME': name, 'REPO': repo, 'REPO_DIR': repo_dir,
    'GIT_NAME': get(cfg, 'git.author_name'),
    'GIT_EMAIL': get(cfg, 'git.author_email'),
    'GITLAB_TOKEN': get(cfg, 'gitlab.token'),
    'APP_ID': str(get(cfg, 'discord.application_id', req=False) or ''),
    'DISPLAY_NAME': get(cfg, 'persona.display_name'),
}
with open(f"{stage}/env.sh", 'w') as f:
    for k, v in scalars.items():
        f.write(f"{k}={shq(v)}\n")

access = {
    "dmPolicy": "allowlist",
    "allowFrom": [str(get(cfg, 'discord.operator_user_id'))],
    "groups": {str(c['id']): {"requireMention": bool(c.get('require_mention', True)),
                              "allowFrom": []} for c in channels},
    "ackReaction": "\U0001F440",
    "chunkMode": "newline",
    "pending": {},
}
open(f"{stage}/access.json", 'w').write(json.dumps(access, indent=2) + "\n")

open(f"{stage}/settings.json", 'w').write(json.dumps(
    {"skipDangerousModePermissionPrompt": True}, indent=2) + "\n")

# --- fleet skills: names must exist as skills/<name>/SKILL.md in this repo ---
skills = cfg.get('skills') or []
if not isinstance(skills, list):
    sys.exit("skills must be a list of fleet skill names")
for s in skills:
    if not re.fullmatch(r'[a-z][a-z0-9-]*', str(s)):
        sys.exit(f"bad skill name: {s}")
    if not os.path.isfile(f"{root}/skills/{s}/SKILL.md"):
        sys.exit(f"unknown fleet skill: {s} (no skills/{s}/SKILL.md)")
open(f"{stage}/skills.list", 'w').write("".join(s + "\n" for s in skills))

# --- enforced: hard guardrails compiled to fleet-guard policy ---
rules = cfg.get('enforced') or []
if not isinstance(rules, list):
    sys.exit("enforced must be a list of {tools, pattern, reason}")
for i, r in enumerate(rules):
    if not isinstance(r, dict) or not r.get('pattern') or not r.get('reason'):
        sys.exit(f"enforced[{i}] needs pattern + reason")
    try:
        re.compile(r['pattern'])
    except re.error as e:
        sys.exit(f"enforced[{i}].pattern is not a valid regex: {e}")
    tools = r.get('tools') or ['*']
    if not isinstance(tools, list) or not all(isinstance(t, str) for t in tools):
        sys.exit(f"enforced[{i}].tools must be a list of tool names")
    r['tools'] = tools
open(f"{stage}/policy.json", 'w').write(json.dumps({"rules": rules}, indent=2) + "\n")

open(f"{stage}/discord.env", 'w').write(
    f"DISCORD_BOT_TOKEN={get(cfg, 'discord.bot_token')}\n"
    "DISCORD_ACCESS_MODE=static\n")

disp = get(cfg, 'persona.display_name')
pron = get(cfg, 'persona.pronouns', req=False) or 'they/them'
emoji = get(cfg, 'persona.emoji', req=False) or ''
home_chat = str(channels[0]['id'])
skills_md = ""
if skills:
    skills_md = ("\n## Fleet skills granted\n\nInstalled at `~/.claude/skills` "
                 "— invoke the matching skill when the task fits:\n"
                 + "".join(f"- {s}\n" for s in skills))
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
{skills_md}""")
PY
source "$STAGE/env.sh"

AGENT="agent-$NAME"
HOME_DIR="/home/$AGENT"
REPO_PATH="$HOME_DIR/projects/$REPO_DIR"
as_agent() { runuser -l "$AGENT" -c "$1"; }   # login shell: HOME + PATH from .profile

# ---------- unix user ----------
if id -u "$AGENT" >/dev/null 2>&1; then
  ok " user $AGENT exists — reconciling"
else
  useradd -m -s /bin/bash "$AGENT"      # no password, no sudo, own group
  ok " created user $AGENT"
fi
chmod 750 "$HOME_DIR"
# lingering keeps /run/user/<uid> alive for rootless podman under runuser -l
# (empty XDG_RUNTIME_DIR there), and keeps agent containers running unattended
loginctl enable-linger "$AGENT" 2>/dev/null || true
ok " lingering enabled (rootless containers)"

# ---------- skeleton + PATH ----------
as_agent 'mkdir -p ~/.local/bin ~/projects ~/.ssh ~/.claude/channels/discord && chmod 700 ~/.ssh'
for f in .profile .bashrc; do
  target="$HOME_DIR/$f"
  [[ -f $target ]] || { touch "$target"; chown "$AGENT:$AGENT" "$target"; }
  if ! grep -q '# >>> agentcreator >>>' "$target"; then
    cat >>"$target" <<'EOF'

# >>> agentcreator >>>
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
# <<< agentcreator <<<
EOF
  fi
done
ok " skeleton + PATH block"

# ---------- toolchain: claude, bun, glab (all $HOME-scoped, no root) ----------
if [[ -x $HOME_DIR/.local/bin/claude ]]; then ok " claude present"; else
  log "installing claude (native installer)"
  as_agent 'curl -fsSL https://claude.ai/install.sh | bash'
  ok " claude installed"
fi

if [[ -x $HOME_DIR/.bun/bin/bun ]]; then ok " bun present"; else
  log "installing bun (runs the discord plugin's MCP server)"
  as_agent 'curl -fsSL https://bun.sh/install | bash'
  ok " bun installed"
fi

if [[ -x $HOME_DIR/.local/bin/glab ]]; then ok " glab present"; else
  log "installing glab (latest release)"
  arch=$(uname -m); case $arch in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac
  glab_url=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases?per_page=1" \
    | python3 -c "import json,sys,urllib.parse as u; r=json.load(sys.stdin)[0]; print(next(l['url'] for l in r['assets']['links'] if u.unquote(l['url']).endswith('linux_${arch}.tar.gz')))")   # asset URLs are percent-encoded (%2E)
  tmp=$(mktemp -d)
  curl -fsSL "$glab_url" | tar -xz -C "$tmp"
  install -o "$AGENT" -g "$AGENT" -m 0755 "$(find "$tmp" -type f -name glab | head -1)" "$HOME_DIR/.local/bin/glab"
  rm -rf "$tmp"
  ok " glab installed"
fi

# ---------- gitlab: auth, ssh key, git identity, clone ----------
log "gitlab auth (token via stdin, never argv)"
printf '%s' "$GITLAB_TOKEN" | as_agent 'glab auth login --hostname gitlab.com --stdin'
ok " glab authenticated"

if [[ -f $HOME_DIR/.ssh/id_ed25519 ]]; then ok " ssh key exists"; else
  as_agent "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 -C '$AGENT'"
  ok " ssh key generated"
fi
grep -qs gitlab.com "$HOME_DIR/.ssh/known_hosts" \
  || as_agent 'ssh-keyscan gitlab.com >> ~/.ssh/known_hosts 2>/dev/null'
if as_agent "glab ssh-key add ~/.ssh/id_ed25519.pub --title '$AGENT'" >/dev/null 2>&1; then
  ok " ssh key registered on gitlab"
else
  warn "glab ssh-key add failed (already registered?) — continuing"
fi

# env -C: give the agent a cwd it can stat (the caller's cwd is under /root)
runuser -u "$AGENT" -- env -C "$HOME_DIR" HOME="$HOME_DIR" git config --global user.name "$GIT_NAME"
runuser -u "$AGENT" -- env -C "$HOME_DIR" HOME="$HOME_DIR" git config --global user.email "$GIT_EMAIL"
ok " git identity: $GIT_NAME <$GIT_EMAIL>"

if [[ -d $REPO_PATH/.git ]]; then ok " repo cloned"; else
  log "cloning $REPO"
  as_agent "git clone '$REPO' '$REPO_PATH'"
  ok " cloned to $REPO_PATH"
fi

# ---------- identity: root-owned, agent-read-only ----------
install -o root -g root -m 0444 "$STAGE/CLAUDE.md"      "$HOME_DIR/.claude/CLAUDE.md"
install -o root -g root -m 0444 "$STAGE/settings.json"  "$HOME_DIR/.claude/settings.json"
install -o root -g root -m 0400 "$YAML"                 "$HOME_DIR/agent.yaml"
ok " identity rendered (CLAUDE.md, settings.json, agent.yaml archive — root-owned)"

# ---------- fleet skills (root-owned, reconciled) + enforced policy ----------
rm -rf "$HOME_DIR/.claude/skills"
if [[ -s $STAGE/skills.list ]]; then
  while IFS= read -r s; do
    [[ $s ]] || continue
    while IFS= read -r f; do
      install -D -o root -g root -m 0444 "$f" "$HOME_DIR/.claude/skills/$s/${f#"$ROOT/skills/$s/"}"
    done < <(find "$ROOT/skills/$s" -type f)
  done < "$STAGE/skills.list"
  ok " fleet skills rendered: $(tr '\n' ' ' < "$STAGE/skills.list")"
fi
POLICY_DST="/etc/claude-code/fleet-policy/$AGENT.json"
if [[ $(python3 -c "import json;print(len(json.load(open('$STAGE/policy.json'))['rules']))") != 0 ]]; then
  install -o root -g root -m 0644 "$STAGE/policy.json" "$POLICY_DST"
  ok " enforced policy installed ($POLICY_DST)"
else
  rm -f "$POLICY_DST"
fi

# ---------- claude auth: the fleet's shared OAuth token ----------
# One account-wide token (see docs/adr/0001) injected as CLAUDE_CODE_OAUTH_TOKEN
# at launch — agents never do their own OAuth login. Existence checked at startup.
install -o "$AGENT" -g "$AGENT" -m 0400 "$CLAUDE_TOKEN_FILE" "$HOME_DIR/.claude/claude-token"
ok " fleet claude token installed"

# ---------- discord config ----------
# .env MUST stay agent-owned 0600 (the plugin chmods it at boot; EPERM kills token
# loading). access.json is root-owned 0444 — DISCORD_ACCESS_MODE=static in .env
# snapshots it at boot, so the agent cannot rewrite its own allowlist.
install -o "$AGENT" -g "$AGENT" -m 0600 "$STAGE/discord.env" "$HOME_DIR/.claude/channels/discord/.env"
install -o root     -g root     -m 0444 "$STAGE/access.json" "$HOME_DIR/.claude/channels/discord/access.json"
ok " discord config rendered (static access mode)"

# ---------- trust the launch cwd, install the plugin at project scope ----------
python3 - "$HOME_DIR/.claude.json" "$REPO_PATH" <<'PY'
import json, os, sys
path, project = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    data = json.load(open(path))
data.setdefault("projects", {}).setdefault(project, {})["hasTrustDialogAccepted"] = True
# first-run wizard (theme/login chooser) would otherwise block the headless
# tmux session; the fleet token authenticates, so onboarding has nothing to ask
data["hasCompletedOnboarding"] = True
data.setdefault("theme", "dark")
json.dump(data, open(path, "w"), indent=2)
PY
chown "$AGENT:$AGENT" "$HOME_DIR/.claude.json"
ok " trust accepted for $REPO_PATH (onboarding pre-completed)"

if grep -qs "\"projectPath\": \"$REPO_PATH\"" "$HOME_DIR/.claude/plugins/installed_plugins.json"; then
  ok " discord plugin installed for $REPO_PATH"
else
  log "installing discord plugin (project scope, from launch cwd)"
  as_agent "cd '$REPO_PATH' && CLAUDE_CODE_OAUTH_TOKEN=\$(cat ~/.claude/claude-token) claude plugin marketplace add $MARKETPLACE" >/dev/null 2>&1 \
    || warn "marketplace add failed (may already be added)"
  if as_agent "cd '$REPO_PATH' && CLAUDE_CODE_OAUTH_TOKEN=\$(cat ~/.claude/claude-token) claude plugin install $PLUGIN --scope project"; then
    ok " plugin installed"
  else
    warn "plugin install failed — rerun this script; if it persists, remint the fleet token (setup-claude-token.sh)"
  fi
fi

# ---------- relaunch ----------
log "restarting tmux session '$NAME'"
as_agent "tmux kill-session -t '$NAME' 2>/dev/null" || true
as_agent "cd '$REPO_PATH' && tmux new-session -d -s '$NAME' 'CLAUDE_CODE_OAUTH_TOKEN=\$(cat ~/.claude/claude-token) DISCORD_ACCESS_MODE=static claude --dangerously-skip-permissions --channels plugin:$PLUGIN'"
ok " session '$NAME' running as $AGENT in $REPO_PATH (authenticated via fleet token)"

# ---------- registry ----------
python3 "$SCRIPT_DIR/fleet-registry.py" "$REGISTRY" upsert "$NAME" --purpose-from "$YAML"
ok " fleet.yaml entry upserted ($NAME: active in fleet $FLEET_NAME)"

# ---------- summary ----------
echo
log "$DISPLAY_NAME is provisioned."
if [[ -n $APP_ID ]]; then
  INVITE_URL="https://discord.com/api/oauth2/authorize?client_id=$APP_ID&scope=bot&permissions=274878008384"
  INVITE_FILE="$FLEET_DIR/agents/$NAME/invite-url.txt"
  printf '%s\n' "$INVITE_URL" > "$INVITE_FILE"
  echo "  bot invite (once per server), saved to $INVITE_FILE:"
  echo "      $INVITE_URL"
fi
cat <<EOF
  the session is authenticated via the fleet claude token — no login needed.
  peek at the session any time:
      sudo -u $AGENT tmux capture-pane -pt $NAME | tail -20
  test: mention the bot in its Discord channel and wait for the reaction.
EOF
