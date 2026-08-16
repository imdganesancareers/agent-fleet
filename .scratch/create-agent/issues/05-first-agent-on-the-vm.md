# First agent on the VM

Type: task
Status: open
Blocked by: 04

## Question

Provision one real agent end-to-end on this VM and verify the destination is reached:
author its `agent.yaml` via `/grill-with-docs`, run `create-agent.sh`, operator
attaches once for OAuth, and the agent answers in its Discord channel. Then rerun the
script with a small YAML change and confirm the reconcile path (configs amended, tmux
session restarted, nothing re-created). HITL — needs the operator's tokens, portal
clicks, and OAuth login. Record what broke and fix or ticket it.
