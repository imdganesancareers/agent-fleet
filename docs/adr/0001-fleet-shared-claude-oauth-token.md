# One shared Claude OAuth token for the whole fleet

Claude Code's OAuth authorize URL is minted per attempt (PKCE), so a
Discord-invite-style static URL per agent is impossible, and per-agent OAuth
meant attaching to each agent's tmux session by hand. We instead mint one
~1-year token with `claude setup-token` (root runs it; the operator approves
the grant in the browser), store it at `secrets/claude-token`, and have
create/update-agent.sh inject it as `CLAUDE_CODE_OAUTH_TOKEN` at session
launch — the only supported path; scripts refuse to launch without it.

## Consequences

- Every agent runs as the operator's Max account and shares its rate limits;
  revoking or rotating the token affects the whole fleet at once (rotate =
  rerun `setup-claude-token.sh`, then relaunch each agent).
- The token allows model requests only (no Remote Control) — sufficient for
  agents.
- Rejected: copying `~/.claude/.credentials.json` between unix users
  (unsupported, refresh-rotation risk) and per-agent OAuth logins (manual,
  N× yearly). Per-agent Claude accounts remain a possible future effort if
  isolation or attribution is ever needed.

## Amendment (2026-08-17)

With multi-fleet directories, the token became per fleet: it lives at
`<fleet>/secrets/claude-token` and is minted with
`setup-claude-token.sh <fleet>`. "Whole fleet" above now means that one fleet's
agents — different fleets may bill different Claude accounts. The mechanism is
unchanged.
