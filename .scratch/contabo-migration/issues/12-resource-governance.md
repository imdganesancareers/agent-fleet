# 12 — Resource governance: memory ceiling + scheduled disk pruning per agent

Type: task
Status: open

## Question

Found while sizing the new VM (2026-09-16): there's currently **no memory
ceiling** on any agent's containers, and it already caused a real incident —
on 2026-08-29, `journalctl -k` shows a container process (`llama-server`,
under `aruvii-developer`'s rootless podman) got OOM-killed twice, and the
OOM killer's reach wasn't scoped to that container: it also targeted
`systemd-journald` globally. The unix-user isolation boundary (no sudo)
controls *access*, but nothing today controls *resource consumption* — one
agent's workload can starve the whole VM, other agents included. Separately,
disk grows unbounded because nothing ever prunes podman's image/layer store
(`~/.local/share/containers`) after a build — normal for the job
(`aruvii-qa`/`aruvii-developer` build and run compose stacks as part of
their actual work), but currently has no ceiling either (this VM:
`aruvii-developer` alone is 20G, mostly image layers).

Decide and implement, before [Cutover swap per
agent](06-cutover-swap-per-agent.md) runs on the new VM (so the new VM
starts governed, not carrying the same gap forward):

- **Memory ceiling**: per-agent cap, likely via a `MemoryMax=` drop-in on
  that agent's systemd user slice (`user-<uid>.slice`) — caps everything
  the agent runs, container or not, using cgroup v2, and fits the existing
  lingering-session setup `create-agent.sh` already relies on for rootless
  podman. Alternative: per-container `--memory` limits threaded through
  podman-compose/docker-compose invocations, but that only bounds
  containers, not the agent's own processes, and depends on every compose
  file setting it consistently. Pick one, size it (headroom for build
  tooling — this VM's agents run 400-570MB RSS normally, but the OOM'd
  workload spiked well past that).
- **Disk pruning — the dominant fix, evidence-backed**: `aruvii-developer`'s
  image store is 15 images, 12 of them `<none>:<none>` dangling layers at
  1.66-1.74GB each (~19GB) — almost certainly repeated rebuilds of the same
  app image during dev iteration, never cleaned up. Only 4 are real tagged
  base images (`redis:7-alpine`, `pgvector/pgvector:pg16`,
  `maven:3.9.16-eclipse-temurin-25`, `testcontainers/ryuk`), totaling under
  1GB combined. Pruning dangling images alone reclaims ~19 of this agent's
  20G. Decide: a scheduled `systemctl --user` timer per agent running
  `podman image prune -f` (dangling only, safe mid-build) or `podman system
  prune -af` (more aggressive, needs an idle window), and the cadence.
- **Shared base-image store — a real but secondary lever**: podman supports
  `additionalimagestores` in `storage.conf` — a shared, typically read-only
  image store multiple rootless users can reference instead of each keeping
  a full separate copy of the same upstream images (a fit for
  `aruvii-developer` and `aruvii-qa`, who build/run the same
  `agent-platform` compose stack). Checked the actual numbers first: right
  now this would save under 1GB per agent (the tagged base images are small
  relative to the dangling-layer waste above), and it adds real complexity
  — something has to own/populate the shared store, and it's normally
  read-only, so it doesn't touch each agent's own iterative rebuild layers.
  Worth deciding, but pruning is what actually moves the needle here; don't
  let this be the thing that delays cutover.
- Where this lands: probably a new step in `create-agent.sh` (so every
  agent gets it by default, on both VMs, not just the new one) rather than
  a one-off manual VM setting — confirm that's the right home before
  implementing.
