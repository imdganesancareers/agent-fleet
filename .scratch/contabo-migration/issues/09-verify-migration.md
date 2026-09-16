# 09 — Verify the migration end to end

Type: task
Status: open
Blocked by: 06, 08

## Question

On the new VM: `sudo ./scripts/list-agent.sh aruvii` shows all 4 agents
active and drift-free; mention each bot in its Discord channel and confirm
it answers from the new VM; hit both app-proxied hostnames over HTTPS and
confirm they serve the live app, not the offline page. This is the map's
destination done-condition.
