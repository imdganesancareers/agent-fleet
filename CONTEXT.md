# CONTEXT

Glossary for the agent-fleet repo (currently the `agentcreator` directory). One
term, one meaning; scripts, skills, and docs use these words exactly.

## Terms

- **Agent** — one Discord-connected Claude instance on this VM: unix user
  `agent-<name>`, tmux session `<name>`, workspace under its home. Defined
  entirely by its agent.yaml.
- **Fleet** — the set of all agents ever provisioned on this VM, active and
  retired.
- **Registry** — `fleet.yaml` at the repo root: the record of the fleet.
  Written only by the lifecycle scripts, never by hand. Holds per agent:
  `name`, `status`, `created`, `purpose`, and `retired` (date, retired only).
- **Agent folder** — `agents/<name>/`: the agent's recipe (`agent.yaml`) and
  script-written artifacts (`invite-url.txt`). Contains secrets; never
  committed to git.
- **Lifecycle script** — one of the four deterministic root-run scripts:
  `create-agent.sh`, `list-agent.sh`, `update-agent.sh`, `delete-agent.sh`.
  Each takes an agent **name**, never a path. Skills wrap scripts; logic a
  script could own never lives in a skill.
- **Active / Retired** — registry statuses. Retiring destroys the unix user,
  home, and session but keeps the agent folder (the recipe) and the registry
  entry; the folder never moves.
- **Drift** — any disagreement between the registry and reality (unix users,
  tmux sessions, agent folders). `list-agent.sh` reports drift; it never hides
  or repairs it silently.
- **Operator** — the root human driving this repo's sessions. Only root
  operators use this repo.
