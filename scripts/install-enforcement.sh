#!/usr/bin/env bash
# install-enforcement.sh — install/refresh the fleet's machine-wide Claude Code
# enforcement layer from enforcement/ into /etc/claude-code:
#
#   managed-settings.json  -> the only settings scope nothing can override;
#                             wires the two hooks below into EVERY session
#   hooks/fleet-guard.py   -> PreToolUse: denies tool calls matching the
#                             per-agent policy, even under
#                             --dangerously-skip-permissions
#   hooks/fleet-identity.sh-> SessionStart(compact): re-injects the agent's
#                             CLAUDE.md after every compaction
#   fleet-policy/          -> per-agent policy JSONs, rendered by
#                             create-agent.sh / update-agent.sh
#
# Idempotent; called by create-agent.sh and update-agent.sh, safe standalone:
#   sudo ./scripts/install-enforcement.sh

set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SRC="$(dirname "$SCRIPT_DIR")/enforcement"

# refuse to clobber a managed-settings.json this repo does not own
if [[ -f /etc/claude-code/managed-settings.json ]] \
   && ! grep -q fleet-guard /etc/claude-code/managed-settings.json; then
  echo "fail: /etc/claude-code/managed-settings.json exists and is not fleet-managed — merge by hand" >&2
  exit 1
fi

install -d -m 0755 /etc/claude-code /etc/claude-code/hooks /etc/claude-code/fleet-policy
install -o root -g root -m 0644 "$SRC/managed-settings.json" /etc/claude-code/managed-settings.json
install -o root -g root -m 0755 "$SRC/fleet-guard.py"        /etc/claude-code/hooks/fleet-guard.py
install -o root -g root -m 0755 "$SRC/fleet-identity.sh"     /etc/claude-code/hooks/fleet-identity.sh
python3 -c 'import json; json.load(open("/etc/claude-code/managed-settings.json"))'
echo "enforcement layer installed (/etc/claude-code)"
