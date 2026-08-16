# 01 — Lay down the fleet layout and migrate aruvi-spec-reviewer

Type: task
Status: open

## Question

Create the new on-disk layout and move the one existing agent into it:

1. `mkdir -p agents/aruvi-spec-reviewer`
2. `mv aruvi-spec-reviewer.agent.yaml agents/aruvi-spec-reviewer/agent.yaml`
   (keep mode 600) and
   `mv aruvi-spec-reviewer.invite-url.txt agents/aruvi-spec-reviewer/invite-url.txt`.
   Inside the folder the `<name>.` prefix is redundant — plain filenames.
3. Create `fleet.yaml` at the repo root with the single entry:
   `name: aruvi-spec-reviewer`, `status: active`, `created: 2026-08-15`,
   `purpose:` one line distilled from the agent.yaml's purpose.
4. ~~Create `.gitignore`~~ — already done during git-ification (2026-08-16):
   it ignores `agents/`, `*.agent.yaml`, `*.invite-url.txt`; `.scratch/` is
   committed (it is the issue tracker and holds no secrets). Just confirm
   `git status` stays clean of agent data after the moves.

Nothing else references the old paths (the running agent uses the root-owned
archive at `/home/agent-aruvi-spec-reviewer/agent.yaml`), so the move is safe
while the agent runs. Done when the four items exist and the repo root holds no
stray per-agent files.
