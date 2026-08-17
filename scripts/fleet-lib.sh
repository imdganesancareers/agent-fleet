# fleet-lib.sh — sourced by the lifecycle scripts; not executable on its own.
#
# A fleet is one self-contained directory: agents/<name>/agent.yaml recipes,
# docs/ (that fleet's refinement documents), fleet.yaml (its registry), and
# secrets/claude-token (its shared Claude OAuth token). Fleets live under
# $FLEETS_ROOT by default; a spec containing '/' is used as a path verbatim.
#
# Every script takes the fleet first: `script <fleet> <agent>`, or exports
# FLEET=<fleet> and omits the positional. Agent names stay VM-global (unix
# users and tmux sessions are), whatever fleet they belong to.

FLEETS_ROOT=${FLEETS_ROOT:-/root/projects/fleets}

# resolve_fleet <spec> — sets FLEET_SPEC, FLEET_DIR, FLEET_NAME, REGISTRY
resolve_fleet() {
  FLEET_SPEC=$1
  if [[ $FLEET_SPEC == */* ]]; then
    FLEET_DIR=$(readlink -m "$FLEET_SPEC")
  else
    [[ $FLEET_SPEC =~ ^[a-z][a-z0-9-]*$ ]] \
      || die "fleet name must be lowercase [a-z][a-z0-9-] (or pass a path containing '/')"
    FLEET_DIR="$FLEETS_ROOT/$FLEET_SPEC"
  fi
  FLEET_NAME=$(basename "$FLEET_DIR")
  REGISTRY="$FLEET_DIR/fleet.yaml"
}

# fleet_args <expected-agent-args> "$@" — resolves the fleet from $1 or $FLEET,
# leaves the remaining args in REST (bash array). Dies with usage on mismatch.
fleet_args() {
  local want=$1; shift
  if [[ ${1:-} && ( $# -gt $want || -z ${FLEET:-} ) ]]; then
    resolve_fleet "$1"; shift
  elif [[ -n ${FLEET:-} ]]; then
    resolve_fleet "$FLEET"
  else
    die "$USAGE"
  fi
  REST=("$@")
}
