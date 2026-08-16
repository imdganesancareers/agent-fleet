# Research findings: Discord plugin surface (`discord@claude-plugins-official`)

Resolves: [issues/01-discord-plugin-surface.md](../issues/01-discord-plugin-surface.md)
Date: 2026-08-15

Primary sources used (no secondary write-ups):

- Official README: <https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/discord/README.md>
  (verified byte-equivalent-in-content with the locally installed copy at
  `/home/claude/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/README.md`)
- Official access doc: `/home/claude/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/ACCESS.md`
  (same file in repo: `external_plugins/discord/ACCESS.md`)
- Plugin server source: `/home/claude/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/server.ts` (v0.0.4, 912 lines)
- Skill sources: `.../0.0.4/skills/configure/SKILL.md`, `.../0.0.4/skills/access/SKILL.md`
- Live installation state: `/home/claude/.claude/plugins/*`, `/home/claude/.claude/channels/discord/*`,
  `/home/claude/.claude.json`, `/home/claude/projects/.claude/settings.json`
- CLI surface: `claude plugin --help`, `claude plugin install --help`, `claude plugin marketplace --help` (claude at `/root/.local/bin/claude`)

---

## Q1 — Install mechanics: is `--channels plugin:...` alone sufficient?

**No. The flag only activates an already-installed, enabled plugin as a channel; the plugin must be installed first.**

README Quick Setup is explicit (steps 4 and 6, `README.md`): step 4 "Install the plugin: `/plugin install
discord@claude-plugins-official`" precedes step 6 "Relaunch with the channel flag ... The server won't connect
without this — exit your session and start a new one: `claude --channels plugin:discord@claude-plugins-official`".
The plugin's `.mcp.json` launches the server via `bun run --cwd ${CLAUDE_PLUGIN_ROOT} ... start`
(`.../0.0.4/.mcp.json`) — `${CLAUDE_PLUGIN_ROOT}` resolves to the install cache path, so without an install there
is nothing to launch.

**Non-interactive install exists** (`claude plugin install --help`):

```
claude plugin install discord@claude-plugins-official --scope project   # scopes: user, project, local (default user)
```

Marketplace prerequisite: the official marketplace is auto-installed by Claude Code
(`/home/claude/.claude.json` keys `officialMarketplaceAutoInstallAttempted: true`,
`officialMarketplaceAutoInstalled: true`; clone recorded in
`/home/claude/.claude/plugins/known_marketplaces.json` → `installLocation:
/home/claude/.claude/plugins/marketplaces/claude-plugins-official`, source github
`anthropics/claude-plugins-official`). A script should not rely on the auto-install having run for a fresh unix
user; `claude plugin marketplace add anthropics/claude-plugins-official` is the explicit, scriptable step
(`claude plugin marketplace --help`).

### What "project scope" means concretely (observed on the live install)

Three artifacts, two files keyed to the project path:

1. **Registry** — `/home/claude/.claude/plugins/installed_plugins.json`:

   ```json
   { "version": 2, "plugins": { "discord@claude-plugins-official": [ {
       "scope": "project",
       "installPath": "/home/claude/.claude/plugins/cache/claude-plugins-official/discord/0.0.4",
       "version": "0.0.4",
       "projectPath": "/home/claude/projects" } ] } }
   ```

   The install is keyed to `projectPath` — the cwd from which `claude` is launched. Launching from any other cwd
   means the plugin is not active there ("wrong cwd = deaf agent" is confirmed by this mechanism).

2. **Enablement** — `<projectPath>/.claude/settings.json`, i.e. `/home/claude/projects/.claude/settings.json`:

   ```json
   { "enabledPlugins": { "discord@claude-plugins-official": true } }
   ```

3. **Plugin code cache** — `/home/claude/.claude/plugins/cache/claude-plugins-official/discord/<version>/`
   (populated by the install; includes vendored `node_modules`).

Nothing plugin-scope-related lands in the per-project entries of `~/.claude.json` — the
`projects["/home/claude/projects"]` object holds only trust/telemetry keys (`hasTrustDialogAccepted: true` is the
one the script cares about; without trust acceptance an interactive prompt blocks startup). The
marketplace/plugin names that appear elsewhere in `/home/claude/.claude.json` (`tengu_harbor_ledger`) are a
feature-flag cache, not install state.

**Rerun/reconcile must amend:** if the agent's project dir changes, either re-run
`claude plugin install --scope project` from the new cwd or ensure both (a) the `projectPath` entry in
`~/.claude/plugins/installed_plugins.json` and (b) `enabledPlugins` in `<newProject>/.claude/settings.json`
match the launch cwd. The cache dir and marketplace clone are project-independent and survive as-is.

**Runtime prerequisite:** the MCP server runs on Bun (`README.md` Prerequisites: "Bun — the MCP server runs on
Bun. Install with `curl -fsSL https://bun.sh/install | bash`"). Present on the live box at
`/home/claude/.bun/bin/bun` — the script must install Bun per agent user (or make a shared bun visible on PATH).

## Q2 — Full config contract

All state lives in `~/.claude/channels/discord/` — or, per instance, `$DISCORD_STATE_DIR`
(`server.ts:37`: `const STATE_DIR = process.env.DISCORD_STATE_DIR ?? join(homedir(), '.claude', 'channels', 'discord')`).
README step 5 note: "To run multiple bots on one machine (different tokens, separate allowlists), point
`DISCORD_STATE_DIR` at a different directory per instance."

### `.env` (`$STATE_DIR/.env`)

- Single required key: `DISCORD_BOT_TOKEN` (observed key name in `/home/claude/.claude/channels/discord/.env`;
  required check at `server.ts:53-63`). Missing token → server writes an error and `process.exit(1)`.
- Real environment wins over the file (`server.ts:42-51`: values only set `if (process.env[m[1]] === undefined)`).
- **Ownership constraint (source-verified):** at boot the server runs `chmodSync(ENV_FILE, 0o600)` as the *first*
  statement inside the try block that also parses the file (`server.ts:44-51`). `chmod` on a file the process
  does not own throws `EPERM`, which aborts the whole try — the token is then never read from the file. So
  `.env` **must be owned by the agent user** (the script should create it agent-owned 0600), or the token must be
  exported in the real environment instead.

### `access.json` (`$STATE_DIR/access.json`) — full schema

From `ACCESS.md` ("Config file" section) cross-checked against the reader `readAccessFile()` (`server.ts:151-171`)
and the live file `/home/claude/.claude/channels/discord/access.json`:

```jsonc
{
  "dmPolicy": "pairing",            // "pairing" (default) | "allowlist" | "disabled"
  "allowFrom": ["<userSnowflake>"], // user snowflakes allowed to DM
  "groups": {                        // guild channels the bot is active in; empty = DM-only
    "<channelSnowflake>": {          // keyed on CHANNEL id, not guild id; threads inherit parent
      "requireMention": true,        // default true: respond only to @mention/reply/mentionPatterns
      "allowFrom": []                // empty = any member may trigger (subject to requireMention)
    }
  },
  "pending": {                       // in-flight pairings, written by the server
    "<6-hex-code>": { "senderId": "...", "chatId": "<dmChannelId>",
                       "createdAt": 0, "expiresAt": 0, "replies": 1 }   // 1h expiry, server.ts:258-266
  },
  "mentionPatterns": ["^hey claude\\b"], // optional; case-insensitive regexes counting as a mention
  "ackReaction": "👀",               // optional; reaction on receipt, "" disables
  "replyToMode": "first",            // optional; first | all | off — threading of chunked replies
  "textChunkLimit": 2000,            // optional; split threshold, Discord hard cap 2000
  "chunkMode": "newline"             // optional; length | newline
}
```

- Absent file = defaults: `{dmPolicy:"pairing", allowFrom:[], groups:{}, pending:{}}` (`ACCESS.md:108`,
  `server.ts` `defaultAccess()` fallback on ENOENT).
- Corrupt file is renamed aside to `access.json.corrupt-<ts>` and defaults used (`server.ts:166-170`).
- In dynamic (default) mode the server **re-reads access.json on every inbound message** — edits take effect
  without restart (`ACCESS.md:9`; `gate()` calls `loadAccess()` per message, `server.ts:238`).
- Writes: the server itself writes it for pairing state (`saveAccess()`, atomic tmp+rename, file mode 0600,
  `mkdirSync(STATE_DIR, {mode: 0o700})`, `server.ts:196-202`); the `/discord:access` skill edits it from the
  Claude session (`skills/access/SKILL.md`).
- dmPolicy semantics (`ACCESS.md` table): `pairing` = reply with code, drop message; `allowlist` = drop silently;
  `disabled` = drop everything including allowlisted users **and guild channels** (`server.ts:243`).

### `approved/` directory

Pairing handshake channel between the skill and the server (`server.ts:320-326` comment and `checkApprovals()`;
`skills/access/SKILL.md` "pair" step 7): when the operator runs `/discord:access pair <code>`, the skill adds
the sender to `allowFrom`, deletes the pending entry, and writes `$STATE_DIR/approved/<senderId>` whose *file
contents* are the DM channel id. The server polls the directory, sends "Paired! Say hi to Claude." to that
channel, and deletes the marker. Empty on the live box (`/home/claude/.claude/channels/discord/approved/`) —
it is transient. A script that pre-populates `allowFrom` never needs it, but the directory's parent must allow
the skill to `mkdir -p` it if pairing is ever used.

### Other files in the state dir

- `inbox/` — attachment downloads land here (`server.ts:440-441`, README "Attachments"). Created lazily with
  `mkdirSync(INBOX_DIR, {recursive:true})` — **the agent user needs write access to the state dir** (or a
  pre-created agent-owned `inbox/`) even when access.json is locked.

## Q3 — Static/locked access mode: confirmed in source

**Yes. `DISCORD_ACCESS_MODE=static` exists and makes a root-owned 0444 `access.json` viable.** Verified in
`server.ts`, not just docs:

- `server.ts:54`: `const STATIC = process.env.DISCORD_ACCESS_MODE === 'static'`
- `server.ts:174-190`: in static mode access is snapshotted at boot into `BOOT_ACCESS` and "never re-read or
  written" (source comment). If the on-disk `dmPolicy` is `pairing` it is **downgraded to `allowlist`** with a
  stderr warning ("static mode — dmPolicy 'pairing' downgraded to 'allowlist'"), and `pending` is cleared —
  "Pairing requires runtime mutation".
- `server.ts:197`: `function saveAccess(a) { if (STATIC) return; ... }` — every write path is a no-op.
- Docs agree: `ACCESS.md:9` "Set `DISCORD_ACCESS_MODE=static` to pin config to what was on disk at boot (pairing
  is unavailable in static mode since it requires runtime writes)."

Consequences for `create-agent.sh`:

- `access.json` root:root **0444 works** in static mode: the server only needs read permission; the
  `mkdirSync(STATE_DIR, 0o700)` that would fail on a root-owned dir lives inside the skipped `saveAccess`.
- Config changes require a server restart (relaunch the tmux session) — acceptable for a reconciling script that
  rewrites the file and relaunches anyway.
- Set the variable in the launch environment of the `claude` process (e.g.
  `DISCORD_ACCESS_MODE=static claude --channels ...` inside tmux) **or** as a line in the agent-owned `.env`
  (the loader imports every `KEY=value` line, not just the token — `server.ts:47-50`). Since spec locks
  access.json but keeps `.env` agent-writable, prefer the launch environment so the agent cannot flip itself
  back to dynamic... noting the agent owns its tmux session anyway, so this is a guardrail, not a hard boundary.
- With pairing unavailable, `allowFrom` (and any group `allowFrom`) must be fully rendered from `agent.yaml` —
  operator snowflakes captured up front (Developer Mode → right-click → Copy User ID, `ACCESS.md:38`).
- Keep the state **dir** and `inbox/` agent-writable (attachment downloads, Q2), and `.env` agent-owned 0600
  (chmod-on-boot constraint, Q2).

## Q4 — Discord Developer Portal prerequisites (per bot, by hand)

Verbatim-condensed from `README.md` Quick Setup steps 1–3 (same text on GitHub), plus `ACCESS.md:5`; gateway
intents cross-checked against `server.ts:83-86` (`DirectMessages`, `Guilds`, `GuildMessages`, `MessageContent`):

1. **Create the application/bot** — <https://discord.com/developers/applications> → **New Application** → name
   it. Sidebar **Bot** → set the bot's username.
2. **Enable the privileged intent** — Bot page → scroll to **Privileged Gateway Intents** → enable
   **Message Content Intent**. "Without this the bot receives messages with empty content." (The other three
   intents the server uses are non-privileged; no portal action needed.)
3. **Public Bot toggle** (recommended lockdown, `ACCESS.md:5`) — Bot tab, **Public Bot** is on by default and
   "controls who can add the bot to new servers. Turn it off and only your own account can install it."
4. **Generate the token** — Bot page → **Token** → **Reset Token**. "Copy the token — it's only shown once."
   This is the value for `DISCORD_BOT_TOKEN` / the `agent.yaml` secret.
5. **Invite the bot to a server** — "Discord won't let you DM a bot unless you share a server with it."
   **OAuth2 → URL Generator** → select scope `bot` → under **Bot Permissions** enable:
   - View Channels
   - Send Messages
   - Send Messages in Threads
   - Read Message History
   - Attach Files
   - Add Reactions

   Integration type: **Guild Install**. Copy the **Generated URL**, open it, add the bot to a server you're in.
   ("For DM-only use you technically need zero permissions — but enabling them now saves a trip back.")
6. **Collect snowflakes for the YAML** — enable **User Settings → Advanced → Developer Mode**; right-click a
   user → **Copy User ID** (allowlist), right-click a channel → **Copy Channel ID** (groups). Group keys are
   channel snowflakes, not guild ids; threads inherit the parent channel (`ACCESS.md:17,47`).

## What create-agent.sh must do

Per agent user `agent-<name>` with home `$H` and launch cwd `$H/projects/<repo>`:

1. Ensure Bun for the agent user (`curl -fsSL https://bun.sh/install | bash` as the agent, or shared bun on PATH).
2. As the agent user: `claude plugin marketplace add anthropics/claude-plugins-official` (idempotent; don't rely
   on auto-install for a fresh user).
3. As the agent user, from the launch cwd: `claude plugin install discord@claude-plugins-official --scope project`
   — lands the cache under `$H/.claude/plugins/cache/...`, the registry entry (scope project,
   `projectPath = launch cwd`) in `$H/.claude/plugins/installed_plugins.json`, and
   `enabledPlugins` in `<launch-cwd>/.claude/settings.json`. On rerun with a changed repo/cwd, redo this step
   from the new cwd (or amend those two files directly).
4. Ensure `$H/.claude.json` has `projects["<launch-cwd>"].hasTrustDialogAccepted: true` (otherwise first launch
   blocks on the trust prompt).
5. Create `$H/.claude/channels/discord/` (agent-owned, 0700) with agent-owned `inbox/`; write `.env`
   agent-owned 0600 containing `DISCORD_BOT_TOKEN=<from agent.yaml>` (must be agent-owned — server chmods it at
   boot and aborts token load on EPERM).
6. Render `access.json` from `agent.yaml` (`dmPolicy: "allowlist"`, operator snowflakes in `allowFrom`, channel
   snowflakes in `groups` with per-channel `requireMention`; `pending: {}`) and lock it root:root 0444.
7. Launch with static access mode from the project cwd:
   `tmux new-session -d -s <agent-name> ... env DISCORD_ACCESS_MODE=static claude --dangerously-skip-permissions --channels plugin:discord@claude-plugins-official`.
8. Rerun/reconcile: rewrite `.env` + `access.json` from the YAML, fix the two project-scope files if the cwd
   changed, kill the tmux session, relaunch (static mode never picks up file edits without restart).
9. Operator docs carry the Q4 portal checklist (Message Content Intent, Public Bot off, Reset Token, the
   six-permission `bot`-scope invite URL, Developer Mode snowflake capture).
