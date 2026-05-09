#!/usr/bin/env bash
# SessionStart hook: remind Claude of project rules defined in rules/*.md

set -euo pipefail

escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RULES_DIR="$SCRIPT_DIR/../rules"

reminder=""
for f in "$RULES_DIR"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    reminder+="## ${name}

$(cat "$f")

"
done

reminder_escaped=$(escape_for_json "$reminder")

if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "additional_context": "%s"\n}\n' "$reminder_escaped"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$reminder_escaped"
else
    # Claude Code invokes user-level hooks without CLAUDE_PLUGIN_ROOT set,
    # so fall through to the nested form it expects.
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$reminder_escaped"
fi

exit 0
