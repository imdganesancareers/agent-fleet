# Prerequisites checklist — one pass per new agent

What the operator must create or look up before `agent.yaml` can be completed.
Sources: the official discord plugin README/ACCESS.md and the plugin source
(verified 2026-08-15; details in `.scratch/create-agent/research/01-discord-plugin-surface.md`).

## Discord — portal work (manual; Discord has no API for this)

In the [Developer Portal](https://discord.com/developers/applications), per agent:

1. **New Application** — name it after the agent.
2. **Bot tab** → set the bot's username.
3. **Enable "Message Content Intent"** (privileged intents section). Skipping this
   produces a bot that connects and ignores every message.
4. Turn **off "Public Bot"** — on by default; leaving it on lets anyone install your
   agent's bot into their own server.
5. **Reset Token** → copy it — shown exactly once. → `discord.bot_token`
6. **General Information** → copy the **Application ID**. → `discord.application_id`
7. Invite the bot to the server by opening (with the application id substituted):
   `https://discord.com/api/oauth2/authorize?client_id=<APP_ID>&scope=bot&permissions=274878008384`
   (encodes: View Channels, Send Messages, Send Messages in Threads, Read Message
   History, Attach Files, Add Reactions.)

Snowflake IDs (needs Discord **Developer Mode**: User Settings → Advanced):

- Right-click the server → Copy Server ID → `discord.guild_id`
- Right-click the agent's channel → Copy Channel ID → `discord.channels[].id`
- Right-click your own avatar → Copy User ID → `discord.operator_user_id`
  (only you will be allowed to DM/command the agent)

## GitLab

- The project's **SSH clone URL** (`git@gitlab.com:group/project.git`) → `gitlab.repo`
- A **Personal Access Token** for the agent's GitLab account:
  gitlab.com → Preferences → Access tokens → scopes **`api` + `write_repository`**
  → `gitlab.token`. The script feeds it to `glab auth login --with-token` and uses it
  to register the agent's SSH key.
- Git author identity for the agent's commits → `git.author_name`, `git.author_email`

## Claude

Nothing to collect per agent. Auth is the **fleet token** at
`<fleet>/secrets/claude-token` (per fleet — fleets may bill different Claude
accounts; ~1-year, injected as `CLAUDE_CODE_OAUTH_TOKEN` at launch — see
`docs/adr/0001`). If the file is missing, the operator mints it once in their own
terminal: `! sudo ./scripts/setup-claude-token.sh <fleet>` (interactive browser
authorize). No API key, no token in the YAML.
