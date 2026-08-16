#!/usr/bin/env bash
# fleet-identity.sh — machine-wide SessionStart(compact) hook for the fleet.
#
# The docs only guarantee project-root CLAUDE.md and auto memory are
# re-injected after compaction; user-level ~/.claude/CLAUDE.md (where each
# agent's persona/soul/guardrails live) is not explicitly covered. This hook
# closes that gap: after every manual/auto compaction its stdout is added to
# context, so the agent's identity provably survives long-lived sessions.
# No-op for non-agent users (the operator's own sessions).

case "$(id -un)" in
  agent-*)
    if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
      echo "<!-- fleet-identity: persona re-injected after compaction -->"
      cat "$HOME/.claude/CLAUDE.md"
    fi
    ;;
esac
exit 0
