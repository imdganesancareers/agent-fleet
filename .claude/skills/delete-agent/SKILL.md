---
name: delete-agent
description: Retire an agent — confirm the target in chat, run scripts/delete-agent.sh, and relay the manual cleanup checklist.
disable-model-invocation: true
---

Retiring destroys the agent's tmux session, unix user, and entire home
(workspace clone, Claude OAuth login, ssh key). It keeps the recipe
`agents/<name>/` and the `fleet.yaml` entry (marked retired), so
`scripts/create-agent.sh <name>` can resurrect the agent any time — but the
OAuth login and ssh-key registration would need redoing.

## 1 · Confirm the target

Run `sudo ./scripts/list-agent.sh`, show the target's row, and restate the
destroy/keep split above. Get the operator's explicit confirmation naming the
agent — the script's own type-the-name prompt cannot be answered from this
session, so this chat confirmation stands in for it.

## 2 · Retire

```bash
sudo ./scripts/delete-agent.sh <name> --yes
```

`--yes` is justified only by the confirmation you just collected. On failure
(missing user or registry entry), that's drift — run `/list-agent` and follow
its fixes instead.

## 3 · Hand off the manual cleanup

Relay the script's closing checklist verbatim: the GitLab ssh key (titled
`agent-<name>`) and any agent-specific PAT, and the Discord bot application —
external resources only the operator's accounts can remove.

Done when the script has printed "retired" and the checklist has been relayed.
