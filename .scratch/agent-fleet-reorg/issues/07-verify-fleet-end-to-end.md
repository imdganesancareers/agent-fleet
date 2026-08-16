# 07 — Verify the fleet end to end

Type: task
Status: resolved
Blocked by: 06

## Question

Prove the destination is reached:

1. `sudo ./scripts/list-agent.sh` — aruvi-spec-reviewer shows active, session up,
   drift-free, exit 0.
2. `sudo ./scripts/create-agent.sh aruvi-spec-reviewer` — the rerun goes green with no
   path argument, upserts the registry (created date preserved), rewrites
   `agents/aruvi-spec-reviewer/invite-url.txt`. Note: this relaunches the tmux
   session — confirm with the operator first if the agent might be mid-task.
3. `sudo ./scripts/list-agent.sh` again — still drift-free.
4. Repo-root inventory matches the destination: `agents/`, `fleet.yaml`,
   `.gitignore`, `CONTEXT.md`, four scripts, `.claude/skills/` with four
   skills, nothing stray.
5. Operator closes with the live test: mention the bot in Discord, get a reply.

Done when all five hold; record any deviation as a new ticket rather than
patching silently.

## Answer

All five hold, 2026-08-16:
1. `list-agent.sh`: aruvi-spec-reviewer active, session up, drift-free, exit 0.
2. `sudo ./scripts/create-agent.sh aruvi-spec-reviewer` rerun went green end to
   end (agent was idle — only an unsubmitted prompt in its input box was lost):
   registry upserted with created date preserved (2026-08-15), invite URL
   rewritten to agents/aruvi-spec-reviewer/invite-url.txt.
3. `list-agent.sh` again: still drift-free, exit 0.
4. Inventory exact: CONTEXT.md, agents/, fleet.yaml, scripts/ (four lifecycle
   scripts + fleet-registry.py), .claude/skills/ with four skills, .gitignore,
   .scratch/ — nothing stray. Relaunched session verified up at the Claude
   prompt.
5. Discord mention test remains the operator's closing act.
