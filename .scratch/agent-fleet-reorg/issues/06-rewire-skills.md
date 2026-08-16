# 06 — Rewire the four skills onto the scripts

Type: task
Status: resolved
Blocked by: 02, 03, 04, 05

## Question

Make each skill a thin wrapper over its script (invoke
`mattpocock-skills:writing-for-agents` first):

- **create-agent**: §3 Write now writes `agents/<name>/agent.yaml` (creating
  the folder, chmod 600); §4 Run becomes `sudo ./scripts/create-agent.sh <name>`;
  mention the invite URL lands in `agents/<name>/invite-url.txt`. Update
  `agent-yaml.md` / `prerequisites.md` wherever they name repo-root paths.
- **update-agent**: §1 List is replaced by "run `sudo ./scripts/list-agent.sh`" (drop
  the ad-hoc getent/tmux commands); §2 Locate points at
  `agents/<name>/agent.yaml` with the same archive-recovery fallback; §4 Apply
  becomes `sudo ./scripts/update-agent.sh <name>`.
- **list-agent** (new): tiny skill — run `sudo ./scripts/list-agent.sh`, relay the
  table, explain any drift flags and which script fixes each. Mark
  `disable-model-invocation: true` like the others.
- **delete-agent** (new): confirm the operator really means it and which agent,
  restate what is destroyed vs kept (recipe + registry entry survive), then
  run `sudo ./scripts/delete-agent.sh <name>` and relay the manual-cleanup checklist.

Done when the four SKILL.md files reference only name-based script calls and
no skill contains shell logic a script owns.

## Answer

Done 2026-08-16. create-agent SKILL.md now writes `agents/<name>/agent.yaml`
and runs `sudo ./scripts/create-agent.sh <name>` (§4 also points at the
registry upsert and `agents/<name>/invite-url.txt`); update-agent SKILL.md
rewritten — §1 picks the agent via `sudo ./scripts/list-agent.sh` (ad-hoc
getent/tmux commands gone), recipe path and apply command updated; new
list-agent and delete-agent skills created, both `disable-model-invocation:
true`, both thin wrappers (delete uses `--yes` backed by an explicit chat
confirmation, since the script's interactive prompt can't be answered from a
session). agent-yaml.md's invite-URL row points at the new file location.
Deviation found and fixed while mapping drift flags to fixes: delete-agent.sh
refused the retired-but-user-exists drift case — it now destroys the leftover
user (drift repair), and list-agent.sh's flag names that fix.
