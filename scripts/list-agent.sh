#!/usr/bin/env bash
# list-agent.sh — print one fleet's table from its fleet.yaml and report drift
# between the registry and reality (unix users, tmux sessions, recipe folders).
#
#   sudo ./scripts/list-agent.sh <fleet>
#   FLEET=<fleet> sudo ./scripts/list-agent.sh
#
# Read-only: never repairs anything. Exits 0 when drift-free, 1 when drift is
# found — usable as a health check. An agent-* unix user registered by another
# fleet under $FLEETS_ROOT is noted, not flagged as drift.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mdrift\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mfail\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
source "$SCRIPT_DIR/fleet-lib.sh"

USAGE="usage: sudo $0 <fleet>   (or FLEET=<fleet> sudo $0)"

fleet_args 0 "$@"
[[ $EUID -eq 0 ]] || die "must run as root"
[[ -f $REGISTRY ]] || die "no fleet.yaml at $REGISTRY — provision an agent with create-agent.sh first"

log "fleet: $FLEET_NAME ($FLEET_DIR)"
rows=$(python3 - "$REGISTRY" <<'PY'
import sys, yaml
for a in (yaml.safe_load(open(sys.argv[1])) or {}).get('agents') or []:
    print('\t'.join(str(a.get(k) or '') for k in ('name', 'status', 'created', 'purpose')))
PY
)

declare -A registered=()
drift=()

printf '%-22s %-8s %-11s %-8s %s\n' NAME STATUS CREATED SESSION PURPOSE
while IFS=$'\t' read -r name status created purpose; do
  [[ $name ]] || continue
  registered[$name]=1
  user="agent-$name"
  user_exists=false
  id -u "$user" >/dev/null 2>&1 && user_exists=true
  session='-'
  if $user_exists; then
    if runuser -u "$user" -- tmux -f /dev/null has-session -t "$name" 2>/dev/null; then
      session=up
    else
      session=down
    fi
  fi
  printf '%-22s %-8s %-11s %-8s %s\n' "$name" "$status" "$created" "$session" "$purpose"

  if [[ $status == active ]] && ! $user_exists; then
    drift+=("$name is active in the registry but unix user $user is missing — rerun create-agent.sh $FLEET_SPEC $name or delete-agent.sh $FLEET_SPEC $name")
  fi
  if [[ $status == retired ]] && $user_exists; then
    drift+=("$name is retired in the registry but unix user $user still exists — run delete-agent.sh $FLEET_SPEC $name to destroy the leftover user")
  fi
  [[ -f $FLEET_DIR/agents/$name/agent.yaml ]] \
    || drift+=("$name has no recipe at $FLEET_DIR/agents/$name/agent.yaml — restore it from /home/$user/agent.yaml")
done <<<"$rows"

# reality no fleet's registry knows about: check the other fleets under
# $FLEETS_ROOT before calling an agent-* user an orphan
while read -r user; do
  name=${user#agent-}
  [[ ${registered[$name]:-} ]] && continue
  owner=''
  for reg in "$FLEETS_ROOT"/*/fleet.yaml; do
    [[ -f $reg && $(readlink -m "$reg") != "$(readlink -m "$REGISTRY")" ]] || continue
    if python3 "$SCRIPT_DIR/fleet-registry.py" "$reg" get "$name" status >/dev/null 2>&1; then
      owner=$(basename "$(dirname "$reg")"); break
    fi
  done
  if [[ $owner ]]; then
    log "note: unix user $user belongs to fleet '$owner'"
  else
    drift+=("unix user $user exists with no registry entry in any fleet under $FLEETS_ROOT — hand-provisioned? scripts are fleet.yaml's only writers")
  fi
done < <(getent passwd | awk -F: '$1 ~ /^agent-/ {print $1}')

echo
if ((${#drift[@]})); then
  for d in "${drift[@]}"; do warn "$d"; done
  exit 1
fi
log "fleet is drift-free"
