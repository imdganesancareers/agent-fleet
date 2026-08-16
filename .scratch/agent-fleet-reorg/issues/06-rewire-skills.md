# 06 — Rewire the four skills onto the scripts

Type: task
Status: open
Blocked by: 02, 03, 04, 05

## Question

Make each skill a thin wrapper over its script (invoke
`mattpocock-skills:writing-for-agents` first):

- **create-agent**: §3 Write now writes `agents/<name>/agent.yaml` (creating
  the folder, chmod 600); §4 Run becomes `sudo ./create-agent.sh <name>`;
  mention the invite URL lands in `agents/<name>/invite-url.txt`. Update
  `agent-yaml.md` / `prerequisites.md` wherever they name repo-root paths.
- **update-agent**: §1 List is replaced by "run `sudo ./list-agent.sh`" (drop
  the ad-hoc getent/tmux commands); §2 Locate points at
  `agents/<name>/agent.yaml` with the same archive-recovery fallback; §4 Apply
  becomes `sudo ./update-agent.sh <name>`.
- **list-agent** (new): tiny skill — run `sudo ./list-agent.sh`, relay the
  table, explain any drift flags and which script fixes each. Mark
  `disable-model-invocation: true` like the others.
- **delete-agent** (new): confirm the operator really means it and which agent,
  restate what is destroyed vs kept (recipe + registry entry survive), then
  run `sudo ./delete-agent.sh <name>` and relay the manual-cleanup checklist.

Done when the four SKILL.md files reference only name-based script calls and
no skill contains shell logic a script owns.
