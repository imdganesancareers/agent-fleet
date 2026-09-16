# 04 — Research: does the Claude OAuth token survive a move to a new machine?

Type: research
Status: resolved

## Question

Does the fleet's Claude OAuth token (`<fleet>/secrets/claude-token`, minted
via `setup-claude-token.sh` — a Max-subscription, browser-authorized,
~1-year token) stay valid when the file is copied and reused from a
different machine (different IP, different device)? Or does Anthropic's
OAuth flow bind the token to the originating device/session, forcing
re-authentication on reuse elsewhere? Find primary-source evidence (the
Claude Code / Anthropic OAuth documentation and behavior) rather than
assuming either way. This determines whether [Cutover swap per
agent](06-cutover-swap-per-agent.md) can just rsync-and-reuse the token, or
must re-mint it (`setup-claude-token.sh`, an interactive browser step) on
the new VM first.

## Answer

**Portable as-is** — the token is a bearer credential, not bound to the
issuing machine/IP. Official Claude Code docs and real-world remote-server
usage confirm it's designed to be copied and reused elsewhere unmodified;
source-IP binding is only a requested feature
([anthropics/claude-code#38031](https://github.com/anthropics/claude-code/issues/38031)),
proving it isn't implemented today. Briefly having the token file on both
VMs during the rsync/cutover window is safe — no anomaly detection or
revocation risk. Lifetime is ~1 year regardless of machine; re-mint only if
it's ever rejected with a "login expired" error.

Full findings + citations:
[.scratch/contabo-migration/research/04-claude-token-portability.md](../research/04-claude-token-portability.md)
(branch `research/claude-token-portability`, commit `872bdcd`).

**Effect on [Cutover swap per agent](06-cutover-swap-per-agent.md):** no
re-minting step needed — rsync the token as part of [Transfer fleet
secrets](05-transfer-fleet-secrets.md) and use it as-is.
