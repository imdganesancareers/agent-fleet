# 05 — Write delete-agent.sh: retire an agent

Type: task
Status: resolved
Blocked by: 01

## Question

New script `delete-agent.sh <name>` (root-run):

- Safety catch: print what will be destroyed, then require the operator to
  type the agent name to proceed; `--yes` skips the prompt for non-interactive
  use.
- Destroy: kill tmux session `<name>`, then `userdel -r agent-<name>`
  (tolerate the harmless mail-spool warning).
- Keep the recipe: `agents/<name>/` stays exactly where it is.
- Registry: set the entry to `status: retired` and stamp `retired: <today>`
  (python3 helper shared in spirit with ticket 02). Die early if the entry is
  already retired or missing (that's drift — point at list-agent.sh).
- Print the manual-cleanup checklist the script cannot do itself: remove the
  agent's SSH key from the GitLab account, delete or reset the Discord
  bot/application in the developer portal, revoke the GitLab PAT if it was
  minted for this agent alone.

Verify with `bash -n`; do NOT run it against aruvi-spec-reviewer. Done when
the script exists, is executable, and its dry logic reads correct.

## Answer

Done 2026-08-16. `sudo ./scripts/delete-agent.sh <name> [--yes]` prints the
destroy/keep contract, requires typing the name (verified: a wrong name aborts
with nothing destroyed), kills the agent's tmux server and processes, runs
`userdel -r` (mail-spool noise filtered, success re-verified via `id`), then
`fleet-registry.py retire` stamps status/date. Ends with the manual checklist
(GitLab ssh key + PAT, Discord application). Refuses when the user is missing,
the registry entry is missing, or already retired — pointing at list-agent.sh.
