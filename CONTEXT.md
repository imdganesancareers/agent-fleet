# CONTEXT

Glossary for the agent-fleet repo. One term, one meaning; scripts, skills, and
docs use these words exactly.

## Terms

- **Agent** — one Discord-connected Claude instance on this VM: unix user
  `agent-<name>`, tmux session `<name>`, workspace under its home. Defined
  entirely by its agent.yaml. Agent **names are VM-global**: unix users and
  tmux sessions know nothing of fleets, so no two fleets may claim the same
  name — `create-agent.sh` enforces this.
- **Fleet** — one named, self-contained directory holding a group of agents
  and everything about them: `agents/` (recipes), `docs/` (that fleet's
  refinement documents), `fleet.yaml` (its registry), `secrets/claude-token`
  (its Claude token). Lives **outside this repo** — under `$FLEETS_ROOT` when
  addressed by bare name, or anywhere when addressed by path. A fleet dir is
  portable and backupable as one folder.
- **Fleets root** — `$FLEETS_ROOT`, default `/root/projects/fleets/`: where
  bare fleet names resolve. Every lifecycle script takes the fleet as its
  first argument (a name, or a path containing `/`), or from the `FLEET`
  env var.
- **Registry** — `<fleet>/fleet.yaml`: the record of that fleet. Written only
  by the lifecycle scripts, never by hand. Holds per agent: `name`, `status`,
  `created`, `purpose`, and `retired` (date, retired only).
- **Agent folder** — `<fleet>/agents/<name>/`: the agent's recipe
  (`agent.yaml`) and script-written artifacts (`invite-url.txt`). Contains
  secrets; lives in the fleet dir, never in this repo or git.
- **Lifecycle script** — one of the four deterministic root-run scripts:
  `create-agent.sh`, `list-agent.sh`, `update-agent.sh`, `delete-agent.sh`.
  Each takes the **fleet first, then the agent name**. Skills wrap scripts;
  logic a script could own never lives in a skill.
- **Active / Retired** — registry statuses. Retiring destroys the unix user,
  home, and session but keeps the agent folder (the recipe) and the registry
  entry; the folder never moves.
- **Fleet token** — `<fleet>/secrets/claude-token`: that fleet's Claude OAuth
  token (a Max subscription, ~1-year lifetime) minted by
  `setup-claude-token.sh <fleet>` and injected into each of its agents'
  sessions as `CLAUDE_CODE_OAUTH_TOKEN`. Per fleet — different fleets may
  bill different Claude accounts; agents never hold their own Claude login.
- **Drift** — any disagreement between a fleet's registry and reality (unix
  users, tmux sessions, agent folders). `list-agent.sh <fleet>` reports
  drift; it never hides or repairs it silently. An `agent-*` user registered
  by a *different* fleet under `$FLEETS_ROOT` is noted, not drift.
- **Operator** — the root human driving this repo's sessions. Only root
  operators use this repo.
- **Agent skill** — a fleet-authored Claude Code skill granted to an agent in
  its agent.yaml; part of the agent's identity alongside persona, soul, and
  guardrails. Authored once in this repo (`skills/` — tooling, shared by all
  fleets), rendered into each granted agent.
- **Enforced guardrail** — an agent.yaml `enforced` rule compiled into the
  machine-wide fleet-guard policy: violating it is impossible, not merely
  discouraged, in every session of that agent's unix user. Prose guardrails
  guide judgment; enforced guardrails deny. Sources in `enforcement/`
  (tooling, machine-wide — not per fleet).
- **Fleet docs** — `<fleet>/docs/`: the grilling, wayfinder, and refinement
  documents about that fleet's agents and their workflow. Efforts about a
  fleet chart there; only efforts about this repo's tooling use the repo's
  `.scratch/`.
- **Project knowledge** — what an agent has learned about building and running
  a repo (how it builds, how it runs, its quirks). Agent-private, lives in the
  agent's home, survives sessions, dies with retirement.
