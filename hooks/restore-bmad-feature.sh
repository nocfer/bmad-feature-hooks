#!/bin/bash
# Claude Code PostToolUse hook: reminds Claude to clear the BMad feature
# context when a BMAD artifact-producing skill completes.
#
# This does NOT auto-clear — that would break multi-skill flows.
# Instead it emits a reminder so Claude clears at the end of the flow.

set -uo pipefail

INPUT=$(cat)

SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')
if [ -z "$SKILL" ]; then
  exit 0
fi

# Only act on gated BMad skills
case "$SKILL" in
  bmad-create-prd|bmad-create-architecture|bmad-create-epics-and-stories|\
  bmad-create-ux-design|bmad-check-implementation-readiness|\
  bmad-validate-prd|bmad-edit-prd|bmad-correct-course|\
  bmad-product-brief|bmad-create-story|bmad-dev-story|\
  bmad-sprint-planning|bmad-sprint-status|\
  bmad-qa-generate-e2e-tests|bmad-retrospective|bmad-quick-dev)
    ;; # gated — continue
  *)
    exit 0 ;;
esac

# Find project root and config
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
PROJECT_DIR="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

CONFIG=""
for f in $(find "$PROJECT_DIR/_bmad" -name "config.yaml" -maxdepth 2 2>/dev/null); do
  if grep -q '^planning_artifacts:' "$f" 2>/dev/null; then
    CONFIG="$f"
    break
  fi
done

if [ -z "$CONFIG" ]; then
  exit 0
fi

# Resolve path to bmad-set-feature.sh relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SET_FEATURE_CMD="$SCRIPT_DIR/bmad-set-feature.sh"

# Check if a feature is currently set
PLANNING=$(grep '^planning_artifacts:' "$CONFIG" | head -1)
if echo "$PLANNING" | grep -q '/features/'; then
  FEATURE=$(echo "$PLANNING" | sed 's|.*features/\([^/]*\)/.*|\1|')
  cat >&2 <<HOOK_MSG
BMAD_FEATURE_REMINDER: Skill "$SKILL" completed with feature context "$FEATURE".
If this was the last BMad skill in the current flow, restore default paths by running:
  $SET_FEATURE_CMD --clear
If more BMad skills will follow, keep the feature set — the PreToolUse hook will allow them through.
HOOK_MSG
fi

exit 0
