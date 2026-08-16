---
name: create-agent
description: Interview the operator and produce a ready-to-run agents/<name>/agent.yaml for scripts/create-agent.sh, walking them through the Discord and GitLab prerequisites first.
disable-model-invocation: true
---

Produce one `agents/<name>/agent.yaml` — the single self-contained recipe
`scripts/create-agent.sh` turns into a running, Discord-connected Claude agent on
this VM — then run the script yourself and drive it to green. Only root operators work in this session,
so provisioning is yours end to end; the operator's own hands are needed only
for filling placeholders — and, if the fleet token is missing, one interactive
`setup-claude-token.sh` run in their own terminal.

## 1 · Prerequisites

Walk the operator through [`prerequisites.md`](prerequisites.md) item by item and
collect the non-secret values (repo URL, guild/channel/user/application IDs, git
author). For each secret (GitLab PAT, Discord bot token) offer the choice: paste it
now, or take a named placeholder (`REPLACE_GITLAB_TOKEN`, `REPLACE_DISCORD_BOT_TOKEN`)
to fill into the file by hand afterwards — placeholders keep tokens out of the
conversation log.

Claude authentication needs nothing collected per agent: the script injects the
fleet token from `secrets/claude-token` at launch. Check the file exists; if not,
the operator mints it once with `! sudo ./scripts/setup-claude-token.sh` (see
§ Claude in prerequisites.md) — say so when they ask where the "claude token" goes.

Done when every checklist item has either a value or a named placeholder.

## 2 · Interview

Invoke the `mattpocock-skills:grilling` and `mattpocock-skills:domain-modeling`
skills, then grill the agent's identity: `name` (≤ 20 chars, lowercase; becomes unix
user `agent-<name>` and the tmux session name), persona scalars (display name,
pronouns, emoji), `purpose`, `soul`, `guardrails`.

The soul is multi-paragraph markdown — role, working process, tone, what it owns and
what it never touches. Keep grilling until it holds all four; a one-line soul is an
unfinished interview. Seed guardrails from the defaults in
[`agent-yaml.md`](agent-yaml.md) § Guardrails and grill for agent-specific additions;
the ask-in-Discord-before-disruptive rule is non-negotiable and stays in verbatim.

Then two more interview stops, always asked:

- **Fleet skills** — list the dirs under `skills/` in this repo and ask which
  this agent is granted (e.g. does it need to dockerize/run/verify apps? →
  `dockerize-and-verify`). Granted names go in the `skills:` list; none is a
  fine answer.
- **Enforced guardrails** — walk the prose guardrails just written and ask
  which must be *impossible*, not just discouraged (git pushes for a read-only
  agent, MR approval, sudo). Author them as `enforced:` entries per
  [`agent-yaml.md`](agent-yaml.md) § Enforced guardrails.

Done when the frontier is empty and the operator confirms the identity reads right.

## 3 · Write

Write `agents/<name>/agent.yaml` (create the folder) following the schema and
example in [`agent-yaml.md`](agent-yaml.md), then `chmod 600` it. Verify every
schema field is present and list any placeholders still unfilled.

## 4 · Run

Once every placeholder is filled (ask the operator to fill any that remain first),
run the script yourself:

```bash
sudo ./scripts/create-agent.sh <name>
```

When it fails, fix the cause here — a missing host package, a bad field, a network
hiccup — and rerun; the script is rerunnable and keeps what already succeeded. If
the fix belongs to every future agent (a prerequisite the script should install
itself), patch `create-agent.sh`, not just the host.

Done when the script prints its summary block. On success it has also upserted
the agent's `fleet.yaml` entry and saved the bot invite URL to
`agents/<name>/invite-url.txt` — point the operator there.

## 5 · Hand off

One act remains the operator's; close by printing it concretely: mention the bot
in its Discord channel and get an answer. Peek at the session yourself with
`sudo -u agent-<name> tmux capture-pane -pt <name> | tail -20` to confirm it came
up authenticated (no login prompt).
