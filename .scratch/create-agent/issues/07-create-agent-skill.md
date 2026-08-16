# create-agent skill

Type: task
Status: resolved
Blocked by: 01

## Question

Add a repo skill `/create-agent` that wraps the YAML-authoring flow: guide the
operator through the prerequisites (Discord portal, GitLab PAT, repo, IDs, the
manual Claude OAuth), run the grill-with-docs-style interview (grilling +
domain-modeling) for identity, and emit a valid `<name>.agent.yaml`. Supersedes the
charting decision to merely document a bare `/grill-with-docs` invocation.

## Answer

Built, directly requested by the operator (2026-08-15):

- `.claude/skills/create-agent/SKILL.md` — user-invoked (zero context load); four
  steps: prerequisites → interview (invokes grilling + domain-modeling) → write
  YAML (chmod 600) → hand-off (script command, first-attach OAuth, Discord test).
  Secrets may be left as named placeholders so tokens stay out of chat logs.
- `.claude/skills/create-agent/prerequisites.md` — operator checklist, portal steps
  verbatim from the [Discord plugin surface](01-discord-plugin-surface.md) findings.
- `.claude/skills/create-agent/agent-yaml.md` — the schema, a full example, and the
  default guardrails block (ask-in-Discord-before-disruptive first). This file is
  also the prototype artifact for [agent.yaml schema](02-agent-yaml-schema.md).
