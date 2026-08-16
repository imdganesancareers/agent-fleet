#!/usr/bin/env python3
"""fleet-guard.py — machine-wide PreToolUse hook for the agent fleet.

Installed at /etc/claude-code/hooks/fleet-guard.py by install-enforcement.sh
and wired via /etc/claude-code/managed-settings.json, so it runs for EVERY
Claude Code session on this VM in every permission mode — including
--dangerously-skip-permissions, subagents, and `claude -p` (per the hooks
docs, PreToolUse deny fires before any permission-mode check).

Per-agent policy lives at /etc/claude-code/fleet-policy/<unix-user>.json,
rendered root-owned from the agent.yaml `enforced:` section by the lifecycle
scripts. No policy file (operator sessions, unknown users) => no-op, so this
hook is invisible outside the fleet.

Policy format: {"rules": [{"tools": ["Bash", ...] or ["*"],
                            "pattern": "<regex>",
                            "reason": "<shown to the model>"}]}
The pattern is matched (re.search) against the JSON-serialized tool_input,
and rules apply when the tool name matches (or tools is ["*"]).

Fail-open by design: a broken policy file must not brick every session on
the VM; errors go to stderr where the transcript records them.
"""
import json
import os
import pwd
import re
import sys

POLICY_DIR = "/etc/claude-code/fleet-policy"


def main():
    try:
        user = pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        return
    if not user.startswith("agent-"):
        return

    policy_path = os.path.join(POLICY_DIR, user + ".json")
    if not os.path.isfile(policy_path):
        return

    try:
        event = json.load(sys.stdin)
        with open(policy_path) as f:
            policy = json.load(f)
    except Exception as e:  # fail-open, but leave a trace
        print(f"fleet-guard: unreadable event/policy: {e}", file=sys.stderr)
        return

    tool = event.get("tool_name") or ""
    haystack = tool + " " + json.dumps(event.get("tool_input") or {})

    for rule in policy.get("rules", []):
        tools = rule.get("tools") or ["*"]
        if "*" not in tools and tool not in tools:
            continue
        try:
            if not re.search(rule.get("pattern", ""), haystack):
                continue
        except re.error as e:
            print(f"fleet-guard: bad pattern {rule.get('pattern')!r}: {e}",
                  file=sys.stderr)
            continue
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "[fleet-guard] " + rule.get("reason", "denied by fleet policy")
                ),
            }
        }))
        return


if __name__ == "__main__":
    main()
