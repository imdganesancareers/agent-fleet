---
name: list-agent
description: Show the agent fleet — run scripts/list-agent.sh, relay the table, and explain any drift it flags.
disable-model-invocation: true
---

Run one fleet's read-only health check yourself and relay what it says (ask
which fleet if it isn't obvious; fleets live under `$FLEETS_ROOT`, default
`/root/projects/fleets/`):

```bash
sudo ./scripts/list-agent.sh <fleet>
```

Show the operator the table (name · status · created · session · purpose). Exit
0 means drift-free — say so and stop.

Exit 1 means drift: the fleet's registry (`<fleet>/fleet.yaml`) and reality
disagree. Relay each flag with its fix, and let the operator choose — the fix
is never applied silently:

- **active, but unix user missing** → `sudo ./scripts/create-agent.sh <fleet>
  <name>` reprovisions it, or `/delete-agent` retires it for good.
- **retired, but unix user still exists** → `sudo ./scripts/delete-agent.sh
  <fleet> <name>` destroys the leftover user.
- **recipe `<fleet>/agents/<name>/agent.yaml` missing** → restore it from the
  root-owned archive at `/home/agent-<name>/agent.yaml`, `chmod 600`.
- **unix `agent-*` user with no registry entry in any fleet** → it was
  provisioned outside the scripts; give it a recipe and run create-agent.sh, or
  remove the user. (Users belonging to *other* fleets are noted, not drift.)

Done when the table is shown and every drift flag (if any) has been relayed with
its fix.
