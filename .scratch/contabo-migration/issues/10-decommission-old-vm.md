# 10 — Decommission the old VM

Type: task
Status: open
Blocked by: 09

## Question

After a soak period on the new VM (decide how long — e.g. a few days of
normal use with no issues), decommission this VM: confirm the 4 agents here
are stopped (they were stopped during [Cutover swap per
agent](06-cutover-swap-per-agent.md)), and cancel or release the old
Contabo VM itself. Confirm nothing besides the aruvii fleet and this repo
checkout depends on this machine before cancelling it — see [Not yet
specified](../map.md) on the map.
