#!/usr/bin/env python3
"""patch-discord-plugin.py — fleet-bot bridge for the discord plugin.

Upstream drops every bot-authored message (`if (msg.author.bot) return`), which
makes agent-to-agent handover mentions impossible. This patch lets messages from
allowlisted fleet peers (env DISCORD_ALLOWED_BOT_IDS, comma-separated bot user
ids, injected by the lifecycle scripts at launch) reach the normal gate — where
requireMention still applies, so an agent only wakes when explicitly mentioned.
Its own messages are always dropped, and a rate cap bounds a runaway
mention-loop between agents.

usage: patch-discord-plugin.py <path-to-server.ts>
Idempotent: exit 0 if patched (now or already), exit 1 if the upstream code no
longer matches (bot-to-bot stays disabled — the caller warns).
"""
import sys

MARKER = ">>> fleet-bot-bridge >>>"

ORIGINAL = """client.on('messageCreate', msg => {
  if (msg.author.bot) return
  handleInbound(msg).catch(e => process.stderr.write(`discord: handleInbound failed: ${e}\\n`))
})"""

PATCHED = """// >>> fleet-bot-bridge >>> applied by agent-fleet scripts/patch-discord-plugin.py
// Allowlisted fleet peers may wake this agent; the gate below still requires an
// explicit mention. Own messages never come back; a rate cap bounds any loop.
const fleetBots = new Set((process.env.DISCORD_ALLOWED_BOT_IDS ?? '').split(',').filter(Boolean))
const fleetBotSeen: number[] = []
client.on('messageCreate', msg => {
  if (msg.author.bot) {
    if (msg.author.id === client.user?.id) return
    if (!fleetBots.has(msg.author.id)) return
    const now = Date.now()
    while (fleetBotSeen.length && now - fleetBotSeen[0] > 3_600_000) fleetBotSeen.shift()
    if (fleetBotSeen.length >= 120) {
      process.stderr.write('discord: fleet-bot-bridge rate cap hit — dropping bot message\\n')
      return
    }
    fleetBotSeen.push(now)
  }
  handleInbound(msg).catch(e => process.stderr.write(`discord: handleInbound failed: ${e}\\n`))
})
// <<< fleet-bot-bridge <<<"""


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip())
    path = sys.argv[1]
    src = open(path).read()
    if MARKER in src:
        print("fleet-bot bridge already applied")
        return
    if ORIGINAL not in src:
        sys.exit(f"{path}: upstream messageCreate handler not found — plugin changed; not patched")
    open(path, "w").write(src.replace(ORIGINAL, PATCHED, 1))
    print("fleet-bot bridge applied")


if __name__ == "__main__":
    main()
