# Map: agent-fleet reorg

Label: wayfinder:map

## Destination

The repo reorganized **live and git-ready**: every agent in `agents/<name>/`
(`agent.yaml` + `invite-url.txt`), `fleet.yaml` as registry-of-record, four
name-based lifecycle scripts (`create` / `list` / `update` / `delete`), four
thin skills wrapping them, aruvi-spec-reviewer migrated, `.gitignore` keeping
agent data out of the future `agent-fleet` git repo. Done when `sudo
./list-agent.sh` shows a healthy, drift-free fleet under the new layout.

## Notes

- Execution is carried into the map (operator's explicit choice): tickets here
  are `task` tickets that *do*, not just decide.
- Vocabulary lives in `CONTEXT.md` at the repo root — use it exactly.
- When editing any SKILL.md, invoke `mattpocock-skills:writing-for-agents`.
- Design decisions locked in the charting grill (2026-08-16):
  - `fleet.yaml` is registry-of-record; scripts are its only writers;
    `list-agent.sh` cross-checks it against reality and flags drift.
  - Entry fields: `name`, `status` (`active`|`retired`), `created`, `purpose`
    (one line), `retired` (date, only when retired). Nothing else — no tokens,
    channels, or repo URLs (those live in agent.yaml).
  - All four scripts take the agent **name**; repo root resolved from the
    script's own location (`dirname "$(readlink -f "$0")"`). Path-based
    invocation drops entirely.
  - Retirement = `status: retired` in the registry; folder stays at
    `agents/<name>/`, never moves. Delete destroys user/home/session only,
    keeps the recipe, prints a manual checklist for GitLab SSH key / Discord
    bot cleanup.
  - `delete-agent.sh` requires typing the agent name to confirm; `--yes`
    skips for non-interactive use.
  - `agents/<name>/` holds exactly `agent.yaml` + `invite-url.txt` for now.
  - `list-agent.sh` prints a plain table only (no `--json` yet).
  - `update-agent.sh` stays identity-only (soul/persona).
- Future git repo name: **agent-fleet**.

## Decisions so far

<!-- one line per closed ticket -->

## Not yet specified

- Nothing — the way is fully charted; only execution remains.

## Out of scope

- Git-ification — done outside the map on the operator's ask (2026-08-16):
  directory renamed to `/root/projects/agent-fleet` (compat symlink
  `agentcreator` left for the live session), git init on `main`, remote
  `git@github.com:imdganesancareers/agent-fleet.git`, `.gitignore` excludes
  `agents/` + `*.agent.yaml` + `*.invite-url.txt`; `.scratch/` is committed.
- Extending `update-agent.sh` beyond soul/persona — explicitly deferred by the
  operator ("later may be extend to other settings").
- Moving secrets out of agent.yaml — a future effort; would balloon this reorg.
- Automated deletion of external resources (GitLab SSH key, Discord bot) via
  API — ruled out in the grill; manual checklist instead.
