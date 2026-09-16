# 06 — Cutover: swap each agent from old VM to new VM

Type: task
Status: open
Blocked by: 02, 03, 04, 05, 11, 12

## Question

Blocked on [Resource governance](12-resource-governance.md) landing first
(operator's explicit call, 2026-09-16): the new VM should start with memory
ceilings and scheduled disk pruning in place, not carry forward the
ungoverned model this VM currently runs.

A Discord bot token holds only one active gateway session at a time — the
old and new VM can't run the same agent simultaneously — so this is a
stop-old-then-start-new swap per agent, not a parallel run. For each of the
4 aruvii agents, in quick succession: stop the agent's tmux session on this
VM, then immediately run `sudo ./scripts/create-agent.sh aruvii <name>` on
the new VM to reconcile it there (user, toolchain, GitLab auth + clone,
rendered `CLAUDE.md`, Discord plugin, tmux relaunch, registry upsert). If
[Claude token portability](04-research-claude-token-portability.md) found
the token needs re-minting, do that (`setup-claude-token.sh` on the new VM)
before running `create-agent.sh` for the first agent. If [Architecture
reconsideration](11-container-runtime-choice.md) changed anything about how
`create-agent.sh` provisions containers, that change must be live in the
new VM's checkout before this ticket runs.
