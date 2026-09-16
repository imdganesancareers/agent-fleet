# 05 — Transfer fleet secrets/data to the new VM

Type: task
Status: open
Blocked by: 01, 13

## Question

Satisfied by running `.scratch/contabo-migration/migrate.sh setup` (see
[Write the migration script](13-write-migration-script.md)) rather than a
manual command.
`rsync -avz -e ssh /root/projects/fleets/aruvii/ root@<new-vm>:/root/projects/fleets/aruvii/`
— moves `fleet.yaml`, all 4 `agents/<name>/agent.yaml` recipes (inline
secrets: GitLab PAT, Discord bot token) and `secrets/claude-token` in one
shot, secrets never touching an intermediate store. Confirm on the new VM:
the directory lands at the same path, permissions stay tight (recipes and
`secrets/` should not end up world-readable), and nothing needed
`$FLEETS_ROOT` to already exist (create it if `create-agent.sh` hasn't run
there yet).
