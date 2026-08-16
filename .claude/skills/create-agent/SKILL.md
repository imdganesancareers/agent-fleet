---
name: create-agent
description: Interview the operator and produce a ready-to-run agent.yaml for create-agent.sh, walking them through the Discord and GitLab prerequisites first.
disable-model-invocation: true
---

Produce one `<name>.agent.yaml` — the single self-contained file `create-agent.sh`
turns into a running, Discord-connected Claude agent on this VM — then run the
script yourself and drive it to green. Only root operators work in this session,
so provisioning is yours end to end; the operator's own hands are needed just
twice: filling placeholders, and the OAuth login inside tmux (interactive — a
terminal you cannot attach).

## 1 · Prerequisites

Walk the operator through [`prerequisites.md`](prerequisites.md) item by item and
collect the non-secret values (repo URL, guild/channel/user/application IDs, git
author). For each secret (GitLab PAT, Discord bot token) offer the choice: paste it
now, or take a named placeholder (`REPLACE_GITLAB_TOKEN`, `REPLACE_DISCORD_BOT_TOKEN`)
to fill into the file by hand afterwards — placeholders keep tokens out of the
conversation log.

Claude authentication needs nothing collected: it is a one-time OAuth login the
operator performs by attaching to the agent's tmux session after the script runs —
say so when they ask where the "claude token" goes.

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

Done when the frontier is empty and the operator confirms the identity reads right.

## 3 · Write

Write `<name>.agent.yaml` in the repo root following the schema and example in
[`agent-yaml.md`](agent-yaml.md), then `chmod 600` it. Verify every schema field is
present and list any placeholders still unfilled.

## 4 · Run

Once every placeholder is filled (ask the operator to fill any that remain first),
run the script yourself:

```bash
sudo ./create-agent.sh <name>.agent.yaml
```

When it fails, fix the cause here — a missing host package, a bad field, a network
hiccup — and rerun; the script is rerunnable and keeps what already succeeded. If
the fix belongs to every future agent (a prerequisite the script should install
itself), patch `create-agent.sh`, not just the host.

Done when the script prints its summary block.

## 5 · Hand off

Two acts remain the operator's; close by printing them concretely:

1. The first-run login: `sudo -u agent-<name> tmux attach -t <name>`, complete the
   Claude OAuth prompt inside the session, detach with `Ctrl-b d`. If the script
   warned that the plugin install was skipped, rerun it after the login.
2. The test: mention the bot in its Discord channel and get an answer. Peek at the
   session with `sudo -u agent-<name> tmux capture-pane -pt <name> | tail -20`.
