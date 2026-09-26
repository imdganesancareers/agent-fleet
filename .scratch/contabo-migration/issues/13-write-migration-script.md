# 13 — Write the migration script

Type: task
Status: resolved

## Question

Operator's explicit call (2026-09-16): don't hand-run the migration as a
sequence of manual commands — write it as one deterministic script, the
same way every other state change in this repo goes through a script, not
inline shell (`CLAUDE.md`: "A script owns a state change"). Scoped as a
**throwaway helper for this move only** — `.scratch/contabo-migration/migrate.sh`
— not a permanent addition to `scripts/`; it doesn't make the core lifecycle
scripts multi-VM aware, keeping [the earlier tooling-scope
decision](../map.md) intact.

Write `.scratch/contabo-migration/migrate.sh`, callable in phases so it
isn't all-or-nothing:

- **`setup`** (idempotent, non-disruptive — safe to run repeatedly ahead of
  cutover): SSH connectivity check against the new VM; `git clone` this repo
  there if not already present; `rsync -avz -e ssh` the fleet directory
  (`/root/projects/fleets/aruvii/`) across — covers what [Clone repo + base
  access](02-clone-repo-base-access.md) and [Transfer fleet
  secrets](05-transfer-fleet-secrets.md) currently describe as manual steps.
- **`cutover <agent-name>`**: stop that agent's tmux session on this VM,
  then SSH to the new VM and run `create-agent.sh aruvii <agent-name>`
  there — covers [Cutover swap per agent](06-cutover-swap-per-agent.md).
  Takes one agent at a time deliberately (Discord's single-gateway-session
  constraint plus wanting to verify each agent before moving to the next),
  not a loop-all-four.
- Fail loudly and stop on any error — no partial-state cleanup magic, this
  is a one-time script, not a reconciler.

Drafting doesn't need the new VM to exist yet, but real testing does — full
verification is blocked on [Confirm root SSH
access](01-confirm-ssh-access.md).

## Answer (2026-09-26)

Written at `.scratch/contabo-migration/migrate.sh`. Matches agent-fleet's own
script conventions (`log`/`ok`/`warn`/`die`, `create-agent.sh`'s exact
invocation shape). Refined beyond the original spec per the secrets decision
on [Transfer fleet secrets](05-transfer-fleet-secrets.md):

- `setup` excludes `secrets/claude-token` from the rsync (fresh token minted
  on the new VM instead) and prints the two manual follow-ups needed before
  any cutover: run `setup-claude-token.sh` there, and replace each
  `agent.yaml`'s `gitlab.token` with a freshly issued PAT.
- `cutover <name>` **refuses to run** if the new VM has no Claude token yet,
  or if its copy of `gitlab.token` still matches the old VM's value byte for
  byte (i.e. wasn't actually replaced) — tested for real against the live
  new VM (`13.140.190.206`): correctly refused with no Claude token present
  yet, no state touched.
- Requires typing the agent's name to confirm before stopping anything, and
  fails loudly (never partially) if `create-agent.sh` fails on the new VM.

Not yet run for real (`setup` hasn't been executed against the new VM —
only the read-only guard checks have). Usage/argument-validation paths
tested clean.

## Effect on other tickets

[Clone repo + base access](02-clone-repo-base-access.md) and [Transfer
fleet secrets](05-transfer-fleet-secrets.md) are now satisfied by running
`migrate.sh setup`, not manual commands — both now also blocked by this
ticket. [Cutover swap per agent](06-cutover-swap-per-agent.md) is satisfied
by running `migrate.sh cutover <name>` per agent, four times — also now
blocked by this ticket.
