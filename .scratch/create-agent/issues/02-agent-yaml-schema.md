# agent.yaml schema

Type: prototype
Status: open
Blocked by: 01

## Question

What exactly does `agent.yaml` contain — field by field?

Produce `agent.example.yaml` + a short schema doc for the operator to react to.
Known at charting: self-contained single file; `name` (→ unix user `agent-<name>`,
tmux session name); persona scalars (display name, pronouns, emoji); `purpose`;
`soul: |` and `guardrails: |` block scalars; `repo:` (gitlab ssh URL); git author
name/email; `gitlab: token:` inline; `discord:` bot token inline + guild/channel ids
with per-channel `requireMention` + operator's user id for `allowFrom`. The discord
block's final shape depends on [Discord plugin surface](01-discord-plugin-surface.md).
Resolve with the operator reviewing the example, then lock the schema.

**Prototype artifact ready for reaction**: `.claude/skills/create-agent/agent-yaml.md`
(schema table + full example + default guardrails), produced while building the
[create-agent skill](07-create-agent-skill.md). Operator review closes this ticket.
