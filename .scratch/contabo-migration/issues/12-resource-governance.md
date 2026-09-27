# 12 — Resource governance: memory ceiling + scheduled disk pruning per agent

Type: task
Status: resolved

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

## Answer

Implemented in `create-agent.sh` as a new optional `resources:` block in `agent.yaml`
(`resources.memory_max`, `resources.shared_images`), applied and verified live on all 4 agents on
**this VM** (operator's call — fix the box that's actually running production today, not just the new
one; the script itself reaches the new VM automatically via the next `git pull`).

**Memory ceiling**: systemd user-slice `MemoryMax=` drop-in at
`/etc/systemd/system/user-<uid>.slice.d/50-memory-max.conf`, applied right after `loginctl
enable-linger` (needs the unix user to exist first). Sized tiered, not flat: `aruvii-developer` /
`aruvii-qa` at 6G (docker builds + compose stacks), `aruvii-analyst` / `aruvi-spec-reviewer` at 3G
(read/text work, no builds). Verified live via `systemctl show user-<uid>.slice -p MemoryMax` on all 4.

**Disk pruning**: a `systemd --user` timer (`podman-prune.timer`, daily) running
`podman container prune -f` + `podman image prune -f` (dangling only, safe mid-build) on every agent,
enabled unconditionally (harmless on agents that don't build). **A third step was added mid-ticket that
turned out to be the actual fix that mattered**: `podman container prune -f` does **not** remove
buildah's own leftover "working containers" from an interrupted or failed build — confirmed by testing
live on `aruvii-developer`, which had **48 of these**, none touched by the normal prune, pinning their
image layers in place. `buildah rm --all` is what actually cleared them. Added as a third `ExecStart`,
guarded by `pgrep -f "buildah|podman.*build"` first so a daily timer can't rip out a container mid-build.

**Real numbers, this VM, verified before/after**: `aruvii-developer`'s podman store dropped from
**7.6G → 488M** the moment the 48 buildah containers were removed and the now-unpinned dangling layers
(including the stale `maven` image below) were pruned. `aruvii-qa` is at 962M post-cleanup.

**Shared base-image store — implemented, then removed the same day (2026-09-27).** Initially wired via
podman's `additionalimagestores` (a root-populated, read-only store at `/var/lib/podman-shared-images`)
for `aruvii-developer` and `aruvii-qa`, populated with 8 images, 1.5G total. Discovered live on the new
VM: `aruvii-developer` hit a real buildah failure building a multi-stage Dockerfile — chown denied on a
layer from the read-only shared store (root:root 755) — and self-disabled it defensively. Investigating
further (isolated throwaway test user, not live agent data) found the problem is **not narrow to
buildah**: a plain `podman run` using an image sourced only from the shared store fails with the exact
same `resolv.conf` OCI error described below, while the identical image pulled into the agent's own
local store runs fine. This is a fundamental incompatibility with running anything from a read-only
additionalimagestore in this environment, not an edge case. **Removed entirely** — `resources.shared_images`
dropped from both agents' `agent.yaml`, the whole mechanism removed from `create-agent.sh`. Every agent
just pulls its own copy now; ~1.5GB duplicated between dev/qa is a fine trade for something that works.

**A second, unrelated but more serious podman bug found and fixed the same day**: a fresh agent's
`storage.conf` has no explicit `driver`, and podman's own auto-pick fails every container with a
`crun: open .../etc/resolv.conf: No such file or directory` OCI error — reproduced on a clean isolated
test user AND independently on `aruvii-qa`. `aruvii-developer` had already hit this too and "fixed" it
by adding `mount_program = "/usr/bin/fuse-overlayfs"`, but an isolated test with only `driver = "overlay"`
set (no mount_program) ran a real container successfully — the fuse-overlayfs detour was unnecessary,
and is the confirmed cause of `aruvii-developer`'s slower Testcontainers runs (fuse-overlayfs routes
storage I/O through userspace FUSE instead of the kernel). Fixed properly in `create-agent.sh`: every
agent's `storage.conf` now gets `driver = "overlay"` written explicitly. Applied and verified live on
`aruvii-qa` (wiped its negligible 188K local store, reinitialized, confirmed a real `podman run` works).
`aruvii-developer` is left on `fuse-overlayfs` for now — switching an already-initialized store's driver
needs a wipe, which isn't safe to do against its real cached data without a deliberate, separate
maintenance step; it works today, just slower.

**A real bug caught mid-implementation, not from the ticket's own investigation**: the ticket's original
image list (copied into the first draft of `shared_images`) included `maven:3.9.16-eclipse-temurin-25`.
Checked the actual repo instead of trusting that list — the project is 100% Gradle now
(`build.gradle.kts`, no `pom.xml` anywhere); a Makefile comment confirms the last Maven usage
(a Checkstyle-via-throwaway-POM workaround) was removed in #440. The image was a genuine stale leftover.
Corrected `shared_images` to the real, currently-referenced base images, verified directly against
`Dockerfile`, `docker-compose.yml`, and the Testcontainers IT setup: `eclipse-temurin:25-jdk` /
`25-jre-jammy`, `node:22-alpine`, `nginx:1.27-alpine`, `curlimages/curl:8.11.0`, `redis:7-alpine`,
`pgvector/pgvector:pg16`, `testcontainers/ryuk:0.14.0`. Removed the stale `maven` image from
`aruvii-developer`'s own store directly as part of the same cleanup.
