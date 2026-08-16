# 04 — Rework update-agent.sh: name-based CLI

Type: task
Status: resolved
Blocked by: 01

## Question

Align `update-agent.sh` with the fleet conventions:

- CLI becomes `sudo ./update-agent.sh <name>`; resolve
  `$ROOT/agents/<name>/agent.yaml` from the script's own location, exactly as
  create-agent.sh does (ticket 02). Check YAML `name:` matches the CLI name.
- Scope unchanged: identity only (re-render CLAUDE.md, refresh the home
  archive, restart tmux). It does **not** touch `fleet.yaml` — identity lives
  in agent.yaml; the registry holds nothing an identity edit changes except
  `purpose`, and refreshing `purpose` stays create-agent.sh's job on its next
  run... unless the one-line purpose changed, in which case update SHOULD
  refresh the registry `purpose` field too (same python3 upsert helper as
  ticket 02, touching only `purpose`).
- Keep the CLAUDE.md template in sync with create-agent.sh (comment already
  says so).

Verify with `bash -n`. Done when `sudo ./update-agent.sh aruvi-spec-reviewer`
is the documented invocation.

## Answer

Done 2026-08-16. CLI is `sudo ./scripts/update-agent.sh <name>`; same root
resolution and name cross-check as create. After rendering CLAUDE.md and
refreshing the home archive it calls `fleet-registry.py set-purpose` so the
registry's one-line purpose follows identity edits. `bash -n` clean;
missing-recipe path verified. Live run deferred (restarts the session).
