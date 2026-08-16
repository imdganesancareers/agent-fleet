# 02 — Rework create-agent.sh: name-based CLI + registry writes

Type: task
Status: resolved
Blocked by: 01

## Question

Convert `create-agent.sh` to the fleet conventions:

- CLI becomes `sudo ./create-agent.sh <name>`. Resolve the repo root from the
  script's own location (`ROOT=$(dirname "$(readlink -f "$0")")`) and load
  `$ROOT/agents/<name>/agent.yaml`; die with a clear message if the folder or
  YAML is missing. Path arguments are no longer accepted.
- Sanity-check that the YAML's `name:` field equals the CLI name; die on
  mismatch.
- Write the invite URL to `$ROOT/agents/<name>/invite-url.txt` (replacing the
  old `<name>.invite-url.txt`-beside-the-YAML behavior).
- On success, **upsert** the agent's entry in `$ROOT/fleet.yaml`: set
  `status: active`, keep an existing `created` date on rerun (set today's date
  only for a new entry), refresh `purpose` from the YAML, drop any `retired`
  date. Use a small python3 block for the YAML edit — the script already
  depends on python3+yaml. Scripts are the registry's only writers.
- Keep everything else (rerun semantics, provisioning steps) untouched.

Verify with `bash -n` and by rereading the summary-block paths. Done when a
rerun against aruvi-spec-reviewer would need no path arguments and would
upsert its registry entry.

## Answer

Done 2026-08-16. CLI is `sudo ./scripts/create-agent.sh <name>`; repo root
resolves as the parent of the script's directory. Name validated in bash and
cross-checked against the recipe's `name:` field in the python stage. Invite
URL now lands in `agents/<name>/invite-url.txt`. On success the script calls
`fleet-registry.py upsert` (status active, created kept on rerun, purpose
refreshed, retired dropped). Verified: `bash -n` clean; missing-recipe and
bad-name paths die with clear messages. Full rerun deferred to ticket 07 (it
restarts the live session).
