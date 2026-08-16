# 03 — Write list-agent.sh: fleet table + drift doctor

Type: task
Status: resolved
Blocked by: 01

## Question

New script `list-agent.sh` (root-run, no arguments):

- Read `fleet.yaml` and print one plain-table row per entry: name, status,
  created, tmux session up/down (`runuser -u agent-<name> -- tmux -f /dev/null
  ls`), purpose.
- After the table, report **drift** — never hide or repair it:
  - registry entry `active` but unix user `agent-<name>` missing
  - unix user `agent-*` exists with no registry entry
  - registry entry whose `agents/<name>/` folder or `agent.yaml` is missing
  - `retired` entry whose unix user still exists
- Exit 0 when drift-free, non-zero when drift is found (so it doubles as a
  health check).
- Plain table only — no `--json`.

Done when `sudo ./list-agent.sh` shows aruvi-spec-reviewer healthy and exits 0.

## Answer

Done and verified live 2026-08-16. `sudo ./scripts/list-agent.sh` prints the
table (NAME STATUS CREATED SESSION PURPOSE) and reports all four drift kinds,
including unix `agent-*` users unknown to the registry; exits 1 on drift.
Live run: aruvi-spec-reviewer active, session up, "fleet is drift-free",
exit 0.
