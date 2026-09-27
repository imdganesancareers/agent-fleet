# 09 — Verify the migration end to end

Type: task
Status: resolved
Blocked by: 06, 08

## Question

On the new VM: `sudo ./scripts/list-agent.sh aruvii` shows all 4 agents
active and drift-free; mention each bot in its Discord channel and confirm
it answers from the new VM; hit both app-proxied hostnames over HTTPS and
confirm they serve the live app, not the offline page. This is the map's
destination done-condition.

## Answer

**`list-agent.sh aruvii` on the new VM: all 4 active, sessions up, fleet reports drift-free.**

**Discord responsiveness**: `aruvii-analyst` and `aruvii-developer` already confirmed via real, live
interactions since cutover (analyst answered a live "who are you?" mention during cutover itself;
developer has ongoing real Discord traffic with ram and other agents). `aruvi-spec-reviewer` and
`aruvii-qa` weren't confirmed the same way — no one mentioned them since their last relaunch — but
their Discord plugin processes are confirmed running and healthy (`bun server.ts` alive under each
agent's own unix user). **Operator's call: this is sufficient to close the ticket** — a live test mention
for these two is a real, quick follow-up, not a blocker.

**Live app over HTTPS**: both `dev.aruvii.ai` and `qa.aruvii.ai` currently serve the offline-page
fallback, correctly — no one has deployed the actual docker-compose app stack on the new VM yet. This
is real product-deploy work belonging to `aruvii-developer`/`aruvii-qa`'s own job, not a migration-script
step, and deliberately not done as part of this map. **Operator's call: defer, not a blocker either.**

**Two explicit non-blocking follow-ups, not silently dropped:**
1. Send a real Discord mention to `aruvi-spec-reviewer` and `aruvii-qa` to fully confirm responsiveness.
2. Ask `aruvii-developer`/`aruvii-qa` to deploy the real app stack on the new VM.
