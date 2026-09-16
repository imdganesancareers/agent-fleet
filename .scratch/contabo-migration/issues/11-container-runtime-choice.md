# 11 — Architecture reconsideration: industry patterns for multi-agent fleets

Type: grilling
Status: open

## Question

Widened from the original, narrower "container runtime choice" question
(operator's explicit ask, 2026-09-16): this setup — unix-user-per-agent for
isolation, tmux for session persistence, rootless podman per agent for
containers, a fleet-shared Claude OAuth token, Discord as the sole
operator interface — was arrived at experimentally over several earlier
maps (`agent-runtime-and-guardrails`, `agent-runtime-reassessment`,
`create-agent`), not benchmarked against how the industry actually runs
comparable fleets of autonomous coding agents.

Reconsider it on its merits, informed by what's actually out there, not
just first-principles reasoning:

- **Isolation boundary**: is a no-sudo unix user + rootless podman
  (current) the right unit, or do comparable systems favor microVMs
  (Firecracker), full container-per-agent (with an orchestrator), or
  something else — and why?
- **Container runtime**: keep podman, or is there a reason (tooling
  ecosystem, performance, maintenance burden) another rootless-capable
  runtime would serve better?
- **Orchestration**: this fleet is scripts + a hand-maintained registry
  (`fleet.yaml`) + tmux. Do comparable systems (open-source multi-agent
  frameworks, internal tools at companies running fleets of coding agents)
  use something categorically different, and would adopting a pattern from
  them actually reduce operational burden here, or just add complexity for
  a 4-agent fleet?
- **Session/interface model**: Discord-as-control-plane + tmux-as-runtime
  is unusual. Is there a more standard pattern worth adopting, or is this
  a deliberate, still-good fit for this operator's workflow?

This is a **research-then-grill** ticket: dispatch research first (industry
practice, primary sources — not blog-post speculation) to inform the
conversation, then grill to a decision. The decision is not itself an
implementation — any change here needs its own follow-on task ticket(s) to
alter `create-agent.sh`'s provisioning before [Cutover swap per
agent](06-cutover-swap-per-agent.md) can run for real on the new VM. Keeping
podman/the current architecture as-is, with reasons recorded, is a valid
outcome of this ticket — this is a check against the industry, not a
mandate to change.

## Research findings (2026-09-16)

Research half done — this ticket is still **open**, the grilling half (the
actual decision, with the operator) hasn't happened yet. Full findings with
citations: `.scratch/contabo-migration/research/11-industry-patterns.md` on
branch `research/fleet-architecture-industry-patterns` (commit `a34682e`,
not merged to `main`).

Headline findings, all from primary/vendor sources:

1. **Isolation**: no universal default. Vendors defending against
   *untrusted, multi-tenant* code (E2B, fly.io, OpenAI's cloud Codex)
   default to Firecracker microVMs, or gVisor (Modal); Daytona is the
   outlier defaulting to plain Docker/namespaces. Anthropic's own docs
   publish a 4-tier tradeoff table (OS-sandbox → containers → gVisor →
   Firecracker VM) with hard numbers, and explicitly treat "containers" as
   a legitimate middle tier — Claude Code's own default sandbox skips
   containers entirely for cost reasons.
2. **Orchestration**: nobody examined runs Kubernetes/Nomad/a queue as the
   entry-level pattern for a small fleet. Anthropic's own self-hosted-agent
   docs recommend either one always-on polling worker or a poll-and-`docker
   run` spawn script — close in spirit to this repo's scripts+registry.
   Heavier bespoke control planes only appear at many-tenants-times-many-
   sandboxes scale, a different problem than 4 named long-lived agents.
3. **Session/interface model — the sharpest fork**: Anthropic's own
   "channels" docs name and describe *this repo's exact pattern* — a
   persistent session bridged to Discord/Telegram/iMessage — as one of
   several first-party-supported patterns, explicitly contrasted against
   ephemeral-per-mention and ephemeral-webhook-triggered patterns used by
   Copilot, Codex, Cursor, and Devin. Channels is labeled a research-preview
   feature — worth weighing as a maturity signal, not a warning sign.

The research stayed neutral by design (mapped against this fleet's actual
constraints — 4 agents, one VM, no sudo, cost-conscious — without
recommending a change). Next step is grilling this with the operator.
