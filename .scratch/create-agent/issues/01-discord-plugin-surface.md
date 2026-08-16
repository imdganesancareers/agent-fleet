# Discord plugin surface

Type: research
Status: resolved
Blocked by: —

## Question

What is the exact, scriptable configuration surface of the official Discord plugin
(`discord@claude-plugins-official`), so `create-agent.sh` can install and configure it
non-interactively during the shell run?

Specifically:

1. Install: is `--channels plugin:discord@claude-plugins-official` on the launch
   command sufficient, or must the script run an install step first (marketplace add /
   `claude plugin install`)? What does "project scope" mean concretely — what lands in
   `~/.claude.json` or elsewhere keyed to `~/projects`, and what must the reconciler
   amend on rerun?
2. Config contract: full schema of `~/.claude/channels/discord/access.json`
   (`dmPolicy`, `groups`, `allowFrom`, `pending`), the `.env` keys, and the role of the
   `approved/` directory.
3. Is there a static/locked access mode (spec 100 claims `DISCORD_ACCESS_MODE=static`)
   that makes a root-owned 0444 `access.json` viable — or does the plugin need to write
   it (pairing), forcing agent-owned 0600?
4. Discord developer-portal prerequisites per bot (intents, permissions, invite) the
   operator must click by hand — needed verbatim for the operator docs.

Primary sources: https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/discord/README.md
plus the working local installation: `/home/claude/.claude/plugins/`,
`/home/claude/.claude/channels/discord/`, `/home/claude/.claude.json` (project-scope
entries; do NOT quote token values).

## Answer

Full findings: [research/01-discord-plugin-surface.md](../research/01-discord-plugin-surface.md)

1. **Install**: `--channels plugin:discord@claude-plugins-official` only *activates* an
   installed plugin — an install step is required first, and it is scriptable:
   `claude plugin marketplace add anthropics/claude-plugins-official` then
   `claude plugin install discord@claude-plugins-official --scope project` run from the
   launch cwd. Project scope concretely = (a) a registry entry in
   `~/.claude/plugins/installed_plugins.json` with `"scope": "project"` and
   `"projectPath"` = launch cwd, (b) `"enabledPlugins": {"discord@claude-plugins-official": true}`
   in `<launch-cwd>/.claude/settings.json`, (c) plugin code cached under
   `~/.claude/plugins/cache/claude-plugins-official/discord/<ver>/`. Rerun with a changed
   repo/cwd must redo the install from the new cwd (or amend (a)+(b)). Also needed:
   `hasTrustDialogAccepted: true` for the cwd in `~/.claude.json`, and Bun on the agent's PATH.
2. **Config contract**: state dir `~/.claude/channels/discord/` (overridable via
   `DISCORD_STATE_DIR`). `.env` holds one key, `DISCORD_BOT_TOKEN` (real env wins; file
   MUST be agent-owned — the server chmods it 0600 at boot and an EPERM aborts token
   loading). `access.json`: `dmPolicy` (`pairing`|`allowlist`|`disabled`), `allowFrom`
   (user snowflakes), `groups` keyed by *channel* snowflake with `requireMention` +
   per-group `allowFrom`, `pending` (server-written pairing codes, 1h expiry), plus
   optional `mentionPatterns`, `ackReaction`, `replyToMode`, `textChunkLimit`,
   `chunkMode`. Re-read per message in dynamic mode. `approved/<senderId>` is a transient
   skill→server handshake file (contents = DM channel id) used only by pairing.
3. **Static mode exists, source-verified**: `server.ts:54`
   `DISCORD_ACCESS_MODE === 'static'` snapshots access at boot, makes `saveAccess()` a
   no-op, and downgrades `dmPolicy: pairing` → `allowlist`. Root-owned 0444
   `access.json` is viable; changes then require relaunch. Keep the state dir + `inbox/`
   agent-writable and `.env` agent-owned 0600.
4. **Portal prerequisites per bot**: New Application → Bot; enable privileged
   **Message Content Intent**; optionally disable **Public Bot**; **Reset Token** (shown
   once); OAuth2 URL Generator with scope `bot` + permissions View Channels, Send
   Messages, Send Messages in Threads, Read Message History, Attach Files, Add
   Reactions, integration type Guild Install; open the URL to invite the bot to a shared
   server; capture snowflakes via Developer Mode → Copy User/Channel ID.
