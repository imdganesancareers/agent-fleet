---
name: update-agent
description: List the agents provisioned on this VM (unix users agent-*) and update one's identity — soul and persona for now — by editing its agent.yaml and applying it with update-agent.sh.
disable-model-invocation: true
---

Every agent on this VM is one unix user `agent-<name>`, one tmux session `<name>`,
and one `<name>.agent.yaml`. This skill updates an agent's **identity — soul and
persona, for now** — by editing that YAML and running `update-agent.sh`, which
re-renders the agent's `CLAUDE.md` and restarts its session, touching nothing
else. Only root operators work in this session, so you run the script yourself.
Any other field (tokens, Discord access, repo, git identity) is `create-agent.sh`
territory — say so and stop.

## 1 · List

Enumerate `agent-*` users and show one line per agent:

```bash
getent passwd | grep '^agent-'                                  # who exists
runuser -u agent-<name> -- tmux -f /dev/null ls 2>/dev/null     # session up?
ls *.agent.yaml                                                 # editable YAML in repo root
```

Report: name · tmux session running or down · YAML present in repo root or only
archived. If the operator only asked for the list, stop here.

Done when every `agent-*` user appears in the table with all three columns filled.

## 2 · Locate the YAML

Edit the repo-root `<name>.agent.yaml`. If it is missing, recover the archive the
script keeps at `/home/agent-<name>/agent.yaml` (root-owned 0400): copy it to the
repo root, `chmod 600`, and continue from the copy — it is the exact file the
running agent was provisioned from.

## 3 · Interview the change

Ask which agent and what should change in its soul or persona. Schema:
[`../create-agent/agent-yaml.md`](../create-agent/agent-yaml.md). The
create-agent interview bar still applies: a soul stays multi-paragraph (role,
process, tone, ownership). Grill until the operator confirms the revised text
reads right, then edit only those fields in the YAML.

One field is never an update: **`name`** keys everything — a new name provisions
a second agent and leaves the old user, session, and home behind. Renaming =
create the new agent, then retire the old one deliberately.

## 4 · Apply

Run it yourself and drive it to green:

```bash
sudo ./update-agent.sh <name>.agent.yaml
```

It re-renders `CLAUDE.md` from the YAML, refreshes the archived copy, and
**kills and relaunches** the tmux session — in-flight work in the session dies
with it; the OAuth login survives. On failure, fix the cause here and rerun.

Done when the script prints its summary line. Close with the test: mention the
bot in its Discord channel and confirm the new identity shows in its reply.
