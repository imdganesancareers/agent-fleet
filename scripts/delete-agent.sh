#!/usr/bin/env bash
# delete-agent.sh — retire an agent: destroy its tmux session, unix user, and
# home directory. The recipe folder <fleet>/agents/<name>/ and the fleet.yaml
# entry survive (entry flips to status: retired), so the agent can be recreated
# any time with create-agent.sh.
#
#   sudo ./scripts/delete-agent.sh <fleet> <name> [--yes]
#   FLEET=<fleet> sudo ./scripts/delete-agent.sh <name> [--yes]
#
# Interactive by default: you must type the agent name to confirm. --yes skips
# the prompt for non-interactive use.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mfail\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
source "$SCRIPT_DIR/fleet-lib.sh"

USAGE="usage: sudo $0 <fleet> <name> [--yes]   (or FLEET=<fleet> sudo $0 <name> [--yes])"

YES=false
positional=()
for arg in "$@"; do
  case $arg in
    --yes) YES=true ;;
    -*)    die "unknown flag: $arg" ;;
    *)     positional+=("$arg") ;;
  esac
done
fleet_args 1 "${positional[@]}"
CLI_NAME=${REST[0]:-}
[[ $CLI_NAME ]] || die "$USAGE"
[[ $EUID -eq 0 ]] || die "must run as root"
[[ -f $REGISTRY ]] || die "no registry at $REGISTRY — wrong fleet?"

AGENT="agent-$CLI_NAME"
id -u "$AGENT" >/dev/null 2>&1 || die "no unix user $AGENT — nothing to destroy (drift? see list-agent.sh)"
status=$(python3 "$SCRIPT_DIR/fleet-registry.py" "$REGISTRY" get "$CLI_NAME" status 2>/dev/null) \
  || die "no fleet.yaml entry for $CLI_NAME in fleet $FLEET_NAME — that's drift; see list-agent.sh"
[[ $status == active ]] \
  || log "registry already says retired — destroying the leftover user (drift repair)"

echo "This will DESTROY:"
echo "  - tmux session '$CLI_NAME' (in-flight work dies with it)"
echo "  - unix user $AGENT and all of /home/$AGENT (workspace clone, Claude OAuth login, ssh key)"
echo "This will KEEP:"
echo "  - the recipe $FLEET_DIR/agents/$CLI_NAME/ — recreate any time with: sudo $SCRIPT_DIR/create-agent.sh $FLEET_SPEC $CLI_NAME"
echo "  - the fleet.yaml entry, marked retired"
if ! $YES; then
  read -rp "type the agent name to confirm: " answer
  [[ $answer == "$CLI_NAME" ]] || die "confirmation mismatch — nothing destroyed"
fi

log "destroying $AGENT"
runuser -u "$AGENT" -- tmux -f /dev/null kill-server 2>/dev/null || true
# rootless containers die with the user's processes; linger + fleet policy are
# host-side state the userdel below does not touch
loginctl disable-linger "$AGENT" 2>/dev/null || true
rm -f "/etc/claude-code/fleet-policy/$AGENT.json"
pkill -u "$AGENT" 2>/dev/null || true
sleep 1
pkill -9 -u "$AGENT" 2>/dev/null || true
userdel -r "$AGENT" 2>&1 | grep -v 'mail spool' || true   # spool warning is noise
id -u "$AGENT" >/dev/null 2>&1 && die "userdel failed — $AGENT still exists"
ok " user, home, session, containers, linger, and fleet policy gone"

if [[ $status == active ]]; then
  python3 "$SCRIPT_DIR/fleet-registry.py" "$REGISTRY" retire "$CLI_NAME"
  ok " fleet.yaml entry marked retired"
fi

echo
log "$CLI_NAME retired. Manual cleanup this script cannot do:"
cat <<EOF
  - GitLab: remove the agent's ssh key (titled '$AGENT') from the account's keys,
    and revoke the PAT in $FLEET_DIR/agents/$CLI_NAME/agent.yaml if it was minted for this agent alone
  - Discord: delete or reset the bot application in the developer portal
    (application id is in $FLEET_DIR/agents/$CLI_NAME/agent.yaml)
EOF
