---
name: update-agent
description: Update one agent's identity — soul and persona for now — by editing agents/<name>/agent.yaml and applying it with scripts/update-agent.sh.
disable-model-invocation: true
---

This skill updates an agent's **identity — soul and persona, for now** — by
editing its recipe `agents/<name>/agent.yaml` and running
`scripts/update-agent.sh`, which re-renders the agent's `CLAUDE.md`, refreshes
its registry purpose line, and restarts its session, touching nothing else.
Only root operators work in this session, so you run the script yourself. Any
other field (tokens, Discord access, repo, git identity) is `create-agent.sh`
territory — say so and stop.

## 1 · Pick the agent

Run `sudo ./scripts/list-agent.sh` and show the operator the fleet table; the
target must be an `active` agent. The recipe is `agents/<name>/agent.yaml`; if
it is missing (list-agent flags this as drift), recover the archive the script
keeps at `/home/agent-<name>/agent.yaml` (root-owned 0400): copy it back to
`agents/<name>/agent.yaml`, `chmod 600`, and continue — it is the exact file
the running agent was provisioned from.

## 2 · Interview the change

Ask what should change in the soul or persona. Schema:
[`../create-agent/agent-yaml.md`](../create-agent/agent-yaml.md). The
create-agent interview bar still applies: a soul stays multi-paragraph (role,
process, tone, ownership). Grill until the operator confirms the revised text
reads right, then edit only those fields in the YAML.

One field is never an update: **`name`** keys everything — a new name provisions
a second agent and leaves the old user, session, and home behind. Renaming =
create the new agent, then retire the old one with `/delete-agent`.

## 3 · Apply

Run it yourself and drive it to green:

```bash
sudo ./scripts/update-agent.sh <name>
```

It re-renders `CLAUDE.md` from the YAML, refreshes the archived copy and the
`fleet.yaml` purpose line, and **kills and relaunches** the tmux session —
in-flight work in the session dies with it; the fleet token is re-injected at
launch. On failure, fix the cause here and rerun.

Done when the script prints its summary line. Close with the test: mention the
bot in its Discord channel and confirm the new identity shows in its reply.
