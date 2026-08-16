---
name: dockerize-and-verify
description: Use when the operator asks you to dockerize, run, or verify the project (or check that it still runs) — containerize the repo in your workspace, run it locally with the rootless container runtime, verify it with a headless browser, report to Discord, and persist what you learned.
---

# Dockerize and verify

You have a rootless container runtime (Podman behind the `docker` CLI). It
needs no sudo and never touches root: images and containers live in your own
home, and you are "root" only inside your own user namespace. `docker build`,
`docker run`, `docker ps`, `docker logs` all work as you expect;
`podman-compose` (or `docker compose`) handles compose files.

## Workflow

1. **Consult your project knowledge first.** Read
   `~/.claude/knowledge/<repo-dir>.md` if it exists — it is your own record of
   how this project builds and runs. Start from it; don't rediscover.
2. **Understand the project.** Read the repo's README, build files, and any
   existing Dockerfile/compose file. Prefer what the repo already ships; write
   your own `Dockerfile`/`compose.yaml` in the workspace only when the repo has
   none. These are local working files — never commit or push them unless your
   guardrails allow repo writes and the operator asked.
3. **Build and run.** `docker build`, then run with the service port published
   to localhost (`-p 127.0.0.1:<port>:<port>`). Check `docker logs` until the
   app is actually listening — a running container is not a working app.
4. **Verify with a headless browser.** Run Playwright from its official
   container so nothing is installed on the host:

   ```bash
   docker run --rm --network host mcr.microsoft.com/playwright:v1.49.0-noble \
     npx -y playwright screenshot --wait-for-timeout=3000 \
     http://127.0.0.1:<port>/ /tmp/check.png
   ```

   `--network host` lets it reach your published localhost port. For more than
   a screenshot (assertions, flows), mount a small test script and run it with
   `npx playwright test`. First pull is large (~2 GB) — say so in Discord
   before a long silence.
5. **Report to Discord.** Status, what you ran, what the browser saw, and any
   failures with the relevant log lines. Attach or describe the screenshot.
6. **Persist what you learned.** Create or update
   `~/.claude/knowledge/<repo-dir>.md`: how it builds, how it runs, ports,
   startup time, quirks, what verification passed. Keep it current — next
   time starts warm.
7. **Clean up.** `docker rm -f` your containers when done; keep images (cache)
   unless disk pressure says otherwise.

## Quirks worth knowing

- Compose: use `podman-compose` if `docker compose` is unavailable.
- Small base images can surprise you (e.g. alpine's busybox has no `httpd`
  applet); check a binary exists before blaming the build.
- Long-running services survive your logout (lingering is enabled), but tie
  container lifetime to the task — this VM is small (4 CPU / 8 GB shared by
  the whole fleet), so don't leave services running after verification.
