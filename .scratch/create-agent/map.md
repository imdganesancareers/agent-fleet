# Map: create-agent — one-shot agent provisioning script

Label: wayfinder:map
Charted: 2026-08-15

## Destination

A working, verified deliverable in this repo: `create-agent.sh` — a rerunnable
(reconciling) shell script that takes one self-contained `agent.yaml` and provisions a
Discord-connected Claude Code agent on this VM as a locked-down unix user — plus the
documented YAML schema and operator flow (author the YAML via `/grill-with-docs`, run
the script as root, attach once for OAuth). Done when a real agent provisioned this
way answers in its Discord channel.

## Notes

- **This map carries execution** (overrides wayfinder's plan-only default, settled at
  charting): task tickets build the deliverable in place.
- Source material: `/root/projects/AgentFleetManager/specs/100-unix-user-mvp.md`
  (the full 23-step create sequence, recovered from the reference agent's history) and
  the live reference user `claude` on this VM (`/home/claude`), whose working launch is
  `tmux new-session -d -s aruvii-developer claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official`
  run from cwd `/home/claude/projects`.
- Skills per ticket type: `/grilling` + `/domain-modeling` for grilling tickets,
  `/prototype` for prototype tickets, `/research` for research tickets.
- Tracker: local markdown, this directory (`issues/NN-<slug>.md`).

### Settled at charting (2026-08-15)

- **Deliverable, not a spec** — working script + schema + docs, tested on this VM.
- **One agent per YAML**; the script runs once per agent. **GitLab only** (`glab`).
- **YAML is self-contained**: soul and guardrails as block scalars; secrets (GitLab
  PAT, Discord bot token) inline in the YAML. The script copies each secret to where
  its consumer reads it (discord token → `~/.claude/channels/discord/.env` 0600;
  PAT → `glab auth login --with-token`), and archives the full YAML at
  `~agent-<name>/agent.yaml` root:root **0400**.
- **Repo clone in scope**: `repo:` field → `~/projects/<repo>`, which is also the
  launch cwd (the discord plugin is project-scoped — wrong cwd = deaf agent).
- **Claude auth is manual, once per agent**: the script launches the tmux session and
  prints the attach command; the operator attaches and completes OAuth inside it.
  Everything else — including all Discord configuration — happens during the script run.
- **Unix user `agent-<name>`, no sudo.** Identity files (`~/.claude/CLAUDE.md` render,
  `~/agent.yaml` archive) are root-owned 0444/0400 — the agent cannot edit who it is.
  Separate uids already give separate default tmux sockets, so plain
  `tmux new-session -s <agent-name>` as the agent user is isolated without extra flags.
- **`--dangerously-skip-permissions` kept** (matches the working reference). The
  disruptive-action boundary is behavioral: the rendered guardrails MUST instruct the
  agent to ask permission in its Discord channel before doing anything disruptive.
- **Rerun = reconcile**: user exists → amend configs only; always kill the agent's
  tmux session and relaunch with the new details. First run creates; reruns update.
- **`access.json` rendered from YAML** (operator's Discord user id in `allowFrom`,
  channel ids with per-channel `requireMention`); locked root:root 0444 if the plugin
  supports a static access mode, else agent-owned 0600 like the reference — pending
  [Discord plugin surface](issues/01-discord-plugin-surface.md).
- **Host**: this Debian/Ubuntu VM only, systemd present, script runs as root,
  fail-fast preflight (tmux, git, curl installed by the script if missing).
- ~~**YAML authoring**: `/grill-with-docs` in this repo, closing deliverable a valid
  `agent.yaml`.~~ *(superseded 2026-08-15: the operator asked for a dedicated repo
  skill — see [create-agent skill](issues/07-create-agent-skill.md).)*

## Decisions so far

<!-- one line per closed ticket: gist + link -->
- [Discord plugin surface](issues/01-discord-plugin-surface.md) — install is scriptable (`claude plugin marketplace add` + `claude plugin install --scope project` from the launch cwd, which writes `installed_plugins.json` + `<cwd>/.claude/settings.json` enabledPlugins); `DISCORD_ACCESS_MODE=static` is real in server.ts, so `access.json` can be rendered from YAML and locked root:root 0444 (pairing auto-downgrades to allowlist), while `.env` must stay agent-owned 0600 (server chmods it at boot) and the state dir agent-writable for `inbox/`.
- [create-agent skill](issues/07-create-agent-skill.md) — `/create-agent` repo skill
  built: prerequisites walkthrough → grilling interview → emits `<name>.agent.yaml`
  (schema + default guardrails in `.claude/skills/create-agent/agent-yaml.md`).
- [create-agent.sh reconciler](issues/04-create-agent-reconciler.md) — script built at
  repo root: python3+PyYAML parse/validate/render stage + bash reconciler; skip-if-done
  provisioning, re-render every run, tmux session always restarted; parse stage tested,
  live path awaits [First agent on the VM](issues/05-first-agent-on-the-vm.md).

## Not yet specified

- Rerun "amend" edge semantics: changed `repo:` (re-clone or leave?), renamed agent,
  rotated tokens — sharpen once the reconciler script is drafted.
- Whether this repo gets `git init` (+ remote) so the script, schema and findings live
  in history — decide by the time the operator docs are written.
- YAML parsing dependency for the script (`yq` binary vs python3-yaml) — settle inside
  the script ticket.
- An agent `remove`/archive counterpart — only if wanted after the first real agent runs.
- **Discord permission relay instead of dangerous mode**: the plugin declares a
  `claude/channel/permission` capability — permission prompts become Discord DMs with
  Allow/Deny buttons to everyone in `allowFrom` (server.ts, verified locally). Running
  WITHOUT `--dangerously-skip-permissions` + a settings.json allowlist for routine
  tools would turn "ask in Discord before disruptive" from an instruction into an
  enforced boundary. Decide after the first live run shows how noisy it is.

## Out of scope

- GitHub / forge detection — GitLab only (charting Q3).
- systemd units, slices, agentd-style supervision — plain tmux on an always-on VM (Q7).
- Fleet roster (multi-agent YAML) and portability beyond this VM (Q2, Q10).
- Automated Claude OAuth (setup-token pane scraping) — manual first-attach by choice (Q6/Q17).
