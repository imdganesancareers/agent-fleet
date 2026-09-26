# 05 — Transfer fleet secrets/data to the new VM

Type: task
Status: resolved
Blocked by: 01, 13

## Question

Satisfied by running `.scratch/contabo-migration/migrate.sh setup` (see
[Write the migration script](13-write-migration-script.md)) rather than a
manual command.

**Not a wholesale rsync — per-secret handling, decided with the operator
(2026-09-26), refining the original "just rsync everything" charting note.**
`agent.yaml` holds both kinds of field in one file, so the script must
touch it selectively rather than copy it verbatim:

| Secret | Handling |
|---|---|
| `discord.bot_token`, `discord.application_id`, `discord.guild_id`, `discord.operator_user_id` | **Unchanged — carried over as-is.** Not machine-bound; no reason to re-issue. |
| `gitlab.token` (per agent, 4 distinct PATs) | **Re-issued.** Operator mints 4 new PATs; the script writes each into its agent's `agent.yaml` on the new VM rather than copying the old value. |
| `secrets/claude-token` (one, shared across all 4 agents — confirmed identical by hash) | **Re-issued, not rsynced.** Operator sets up a fresh Claude credential on the new VM; it lands at the same path and gets distributed to the 4 agent homes the same way `create-agent.sh` already does today. The old token stays valid until explicitly revoked after the new VM is verified (housekeeping, not urgent). |
| `fleet.yaml`, `invite-url.txt`, `git.author_name`/`author_email` | Unchanged — not secret, carried over as-is. |

So: rsync `fleet.yaml` and the 4 `agent.yaml` recipes as the base (Discord
fields correct as landed), then overwrite each `gitlab.token` with its new
PAT, and separately mint the new Claude credential rather than rsyncing
`secrets/claude-token`. Confirm on the new VM: the directory lands at the
same path, permissions stay tight (recipes and `secrets/` should not end
up world-readable), and nothing needed `$FLEETS_ROOT` to already exist
(create it if `create-agent.sh` hasn't run there yet).

## Answer

**The GitLab-token row changed (2026-09-26, superseding the row above).** Minting 4 fresh
service-account PATs turned out to need group-Owner permission on `ai-agent-build-platform` (see
[gitlab-token-rotation.md](../../gitlab-token-rotation.md), from the `soul-md-split` map) — not
available to the operator today. **Operator's call: reuse the existing tokens as-is on the new VM
rather than wait on that** — same reasoning as the Claude token, a GitLab PAT is a bearer credential,
not bound to the issuing machine. `migrate.sh setup` already rsyncs `agent.yaml` verbatim, so this
needed no extra action — the tokens were already correct and working before this ticket even started.

Updated `migrate.sh`'s `cutover` subcommand to match: the "old and new GitLab token must differ" check
was written for the original re-issue plan and would have hard-failed on every agent under the new
plan. Changed from `die` to a `warn` — a match is now expected, not a sign of a skipped step. Also
updated `setup`'s closing guidance to drop the now-stale "replace with a freshly issued PAT" instruction.

**Claude token**: minted for real. Ran `setup-claude-token.sh` on the new VM (interactive — browser
authorize + paste, so the operator ran it directly, not this session). Verified: `secrets/claude-token`
present, `0600`, correct `sk-ant-oat01-…` prefix, 109 bytes.

Both secret types are now in place on the new VM. `fleet.yaml`, `invite-url.txt`, and git identity
fields were already confirmed correct in ticket 02's verification.
