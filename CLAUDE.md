# agent-fleet

This repo is tooling only: deterministic scripts that provision and reconcile
Discord-connected Claude Code agents. Fleet data (recipes, registries, tokens)
lives outside the repo, under `$FLEETS_ROOT` (default `/root/projects/fleets/`).

- **Read [CONTEXT.md](CONTEXT.md) first.** Every term (Agent, Fleet, Registry,
  Drift, Lifecycle script, …) has exactly one meaning there. Don't reuse a
  term loosely — check the glossary before assuming what "agent" or "fleet"
  means in a given sentence.
- **Skills are the entry points.** `/create-agent`, `/list-agent`,
  `/update-agent`, `/delete-agent` wrap the lifecycle scripts with interviews
  and confirmations. Prefer them over running `scripts/*.sh` freehand — they
  exist so nothing gets skipped.
- **Never hand-edit a fleet's `fleet.yaml`.** It's written only by
  `scripts/fleet-registry.py`, invoked from the lifecycle scripts. Same for a
  rendered agent `CLAUDE.md` — it's regenerated from `agent.yaml`, not edited
  in place.
- **A script owns a state change; a skill never does one directly.** If a
  skill's instructions describe something the scripts don't already do, that
  belongs in a script, not inline shell run from the skill.
