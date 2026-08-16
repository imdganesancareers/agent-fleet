#!/usr/bin/env bash
# setup-claude-token.sh — mint the fleet's shared Claude OAuth token (Max
# subscription, ~1-year lifetime) and store it at secrets/claude-token.
# create-agent.sh and update-agent.sh install that file per agent and inject it
# as CLAUDE_CODE_OAUTH_TOKEN at session launch, so agents need no OAuth login
# of their own. One account serves the whole fleet — see
# docs/adr/0001-fleet-shared-claude-oauth-token.md.
#
# Interactive (browser authorize + paste) — run it in YOUR terminal:
#   sudo ./scripts/setup-claude-token.sh
#
# The token lasts about a year; rerun this script when auth starts failing,
# then relaunch each agent (create-agent.sh <name>) to pick up the new token.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ok \033[0m%s\n' "$*"; }
die()  { printf '\033[1;31mfail\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
SECRETS="$ROOT/secrets"
TOKEN_FILE="$SECRETS/claude-token"

[[ $EUID -eq 0 ]] || die "must run as root"
# sudo's secure_path drops root's ~/.local/bin, where the native installer puts claude
export PATH="/root/.local/bin:$PATH"
command -v claude >/dev/null \
  || die "claude CLI not found for root — install it: curl -fsSL https://claude.ai/install.sh | bash"
[[ -t 0 ]] || die "needs an interactive terminal (browser authorize + paste-code)"

mkdir -p "$SECRETS"
chmod 700 "$SECRETS"
[[ -s $TOKEN_FILE ]] \
  && log "a fleet token already exists — the new one replaces it for future (re)launches"

log "running 'claude setup-token': open the URL it prints, approve the grant in"
log "your browser (you are the account), and paste the code back when prompted"
echo
claude setup-token || die "claude setup-token failed"
echo
log "the token is the long sk-ant-oat… string printed above — not the browser code"
TOKEN=""
for _attempt in 1 2 3; do
  # visible on purpose: setup-token already printed the token in plaintext
  # above, and a hidden prompt gives no feedback that the paste landed
  read -rp "paste the minted token here (sk-ant-oat…): " RAW
  # pastes arrive messy: strip whitespace/CR, quotes, and any copied label
  # like "Token: " by keeping everything from sk-ant-oat onward
  CLEAN=$(printf '%s' "$RAW" | tr -d '[:space:]"'\''')
  if [[ $CLEAN == *sk-ant-oat* ]]; then
    TOKEN="sk-ant-oat${CLEAN#*sk-ant-oat}"
    break
  fi
  printf '\033[1;31mfail\033[0m got %d chars starting %.8s… — no sk-ant-oat prefix found, try again\n' \
    "${#CLEAN}" "$CLEAN" >&2
done
[[ -n $TOKEN ]] || die "no valid token after 3 attempts — nothing stored"

umask 077
printf '%s\n' "$TOKEN" > "$TOKEN_FILE"
ok " fleet token stored at secrets/claude-token (0600, gitignored)"

echo
log "apply it by relaunching each agent:"
echo "      sudo $SCRIPT_DIR/create-agent.sh <name>"
