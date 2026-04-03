#!/bin/bash
# Install bmad-feature-hooks into the current project's .claude/settings.json
#
# Usage:
#   ./install.sh                  # Install using absolute paths to this repo
#   ./install.sh /path/to/project # Install into a specific project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
PROJECT_DIR="${1:-$(pwd)}"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Project directory does not exist: $PROJECT_DIR" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR/.claude"

# Build hook entries using absolute paths
CHECK_HOOK="$HOOKS_DIR/check-bmad-feature.sh"
RESTORE_HOOK="$HOOKS_DIR/restore-bmad-feature.sh"

if [ ! -f "$CHECK_HOOK" ] || [ ! -f "$RESTORE_HOOK" ]; then
  echo "Error: Hook scripts not found in $HOOKS_DIR" >&2
  exit 1
fi

if [ -f "$SETTINGS_FILE" ]; then
  echo "Existing settings.json found at $SETTINGS_FILE"
  echo "Merging BMad feature hooks..."

  # Use jq to merge hooks into existing settings
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required for merging into existing settings.json" >&2
    echo "Install it with: brew install jq (macOS) or apt install jq (Linux)" >&2
    exit 1
  fi

  TEMP=$(mktemp)
  jq --arg check "$CHECK_HOOK" --arg restore "$RESTORE_HOOK" '
    .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{
      "matcher": "Skill",
      "hooks": [{"type": "command", "command": $check}]
    }] | unique_by(.matcher + (.hooks | tostring)))
    |
    .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
      "matcher": "Skill",
      "hooks": [{"type": "command", "command": $restore}]
    }] | unique_by(.matcher + (.hooks | tostring)))
  ' "$SETTINGS_FILE" > "$TEMP" && mv "$TEMP" "$SETTINGS_FILE"
else
  cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "$CHECK_HOOK"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "$RESTORE_HOOK"
          }
        ]
      }
    ]
  }
}
EOF
fi

echo ""
echo "BMad feature hooks installed successfully!"
echo ""
echo "  PreToolUse  -> $CHECK_HOOK"
echo "  PostToolUse -> $RESTORE_HOOK"
echo ""
echo "Settings written to: $SETTINGS_FILE"
