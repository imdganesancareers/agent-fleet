# 07 — Verify the fleet end to end

Type: task
Status: open
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
