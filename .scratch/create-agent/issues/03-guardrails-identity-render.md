# Guardrails & identity render

Type: prototype
Status: open
Blocked by: —

## Question

What does the rendered `~/.claude/CLAUDE.md` (root:root 0444) look like — the template
that combines persona, purpose, soul, and guardrails from `agent.yaml`?

Also covers the rendered `~/.claude/settings.json` (root:root 0444): must include
`"skipDangerousModePermissionPrompt": true` (verified on the reference user — without
it the first tmux launch blocks on the dangerous-mode confirmation prompt).

The guardrails block must include the standing red lines (adapt
`/root/projects/AgentFleetManager/souls/_shared/rules.md` and `souls/_starter.md`) plus
the charting decision: **the agent runs `--dangerously-skip-permissions`, so it must be
instructed to ask permission in its Discord channel before doing anything disruptive**
(deletes, force-pushes, service restarts, installs outside $HOME, spending money).
Draft the template, render one example, and let the operator react.

**Prototype artifacts ready for reaction**: the default guardrails block lives in
`.claude/skills/create-agent/agent-yaml.md` § Guardrails; the CLAUDE.md/settings.json
render template is embedded in `create-agent.sh` (python stage). Operator review
closes this ticket.
