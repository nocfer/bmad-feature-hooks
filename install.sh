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

# Build hook entry using absolute path
CHECK_HOOK="$HOOKS_DIR/check-bmad-feature.sh"

if [ ! -f "$CHECK_HOOK" ]; then
  echo "Error: Hook script not found: $CHECK_HOOK" >&2
  exit 1
fi

# Add .active-feature to project .gitignore if not already present
GITIGNORE="$PROJECT_DIR/.gitignore"
ACTIVE_PATTERN="_bmad-output/.active-feature"
if [ -f "$GITIGNORE" ]; then
  if ! grep -qF "$ACTIVE_PATTERN" "$GITIGNORE"; then
    echo "" >> "$GITIGNORE"
    echo "# BMad feature hooks session state" >> "$GITIGNORE"
    echo "$ACTIVE_PATTERN" >> "$GITIGNORE"
  fi
else
  echo "# BMad feature hooks session state" > "$GITIGNORE"
  echo "$ACTIVE_PATTERN" >> "$GITIGNORE"
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
  jq --arg check "$CHECK_HOOK" '
    .hooks.PreToolUse = [
      ((.hooks.PreToolUse // []) | map(select(.matcher != "Skill")))[],
      {"matcher": "Skill", "hooks": [{"type": "command", "command": $check}]}
    ]
  ' "$SETTINGS_FILE" > "$TEMP" && mv "$TEMP" "$SETTINGS_FILE"
else
  cat > "$SETTINGS_FILE" <<'SETTINGS_EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "BMAD_CHECK_HOOK_PLACEHOLDER"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
  # Replace placeholder with actual path (handles spaces safely)
  TEMP=$(mktemp)
  jq --arg check "$CHECK_HOOK" '
    .hooks.PreToolUse[0].hooks[0].command = $check
  ' "$SETTINGS_FILE" > "$TEMP" && mv "$TEMP" "$SETTINGS_FILE"
fi

echo ""
echo "BMad feature hooks installed successfully!"
echo ""
echo "  PreToolUse -> $CHECK_HOOK"
echo ""
echo "Settings written to: $SETTINGS_FILE"
