#!/bin/bash
# Claude Code PreToolUse hook: ensures a BMad feature context is set
# before artifact-producing skills run.
#
# Reads feature state from _bmad-output/.active-feature (never modifies config.yaml).
# Supports three enforcement modes via feature_hooks_mode in config:
#   strict   — blocks (exit 2) when no feature is set
#   advisory — allows but suggests setting a feature
#   off      — silent pass-through
#
# Auto-sets feature when git branch matches an existing feature folder.

set -uo pipefail

INPUT=$(cat)

SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')
if [ -z "$SKILL" ]; then
  exit 0
fi

# Only gate BMad skills that produce planning/implementation artifacts
case "$SKILL" in
  bmad-create-prd|bmad-create-architecture|bmad-create-epics-and-stories|\
  bmad-create-ux-design|bmad-check-implementation-readiness|\
  bmad-validate-prd|bmad-edit-prd|bmad-correct-course|\
  bmad-product-brief|bmad-create-story|bmad-dev-story|\
  bmad-sprint-planning|bmad-sprint-status|\
  bmad-qa-generate-e2e-tests|bmad-retrospective|bmad-quick-dev)
    ;; # gated — continue checking
  *)
    exit 0 ;; # not gated — allow
esac

# Find project root
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
PROJECT_DIR="${CWD:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

OUTPUT_DIR="$PROJECT_DIR/_bmad-output"
ACTIVE_FILE="$OUTPUT_DIR/.active-feature"
FEATURES_DIR="$OUTPUT_DIR/features"

# Resolve path to bmad-set-feature.sh relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SET_FEATURE_CMD="$SCRIPT_DIR/bmad-set-feature.sh"

# Read enforcement mode from config (default: strict)
MODE="strict"
for f in $(find "$PROJECT_DIR/_bmad" -name "config.yaml" -maxdepth 2 2>/dev/null); do
  MODE_LINE=$(grep '^feature_hooks_mode:' "$f" 2>/dev/null | head -1)
  if [ -n "$MODE_LINE" ]; then
    MODE=$(echo "$MODE_LINE" | sed 's/^feature_hooks_mode:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/[[:space:]]*$//')
    break
  fi
done

# Validate mode value
case "$MODE" in
  strict|advisory|off) ;;
  *)
    echo "Warning: Unrecognized feature_hooks_mode '$MODE', defaulting to strict" >&2
    MODE="strict"
    ;;
esac

# Off mode: silent pass-through
if [ "$MODE" = "off" ]; then
  exit 0
fi

# Check if a feature is already set
ACTIVE=""
if [ -f "$ACTIVE_FILE" ]; then
  ACTIVE=$(head -1 "$ACTIVE_FILE")
fi

# Feature is set — happy path
if [ -n "$ACTIVE" ]; then
  cat >&2 <<HOOK_MSG
BMAD_FEATURE_ACTIVE
feature: $ACTIVE
planning_path: _bmad-output/features/$ACTIVE/planning
implementation_path: _bmad-output/features/$ACTIVE/implementation
HOOK_MSG
  exit 0
fi

# No feature set — gather context
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Derive suggestion from branch name (last segment after any slash)
SUGGESTION=""
if [ "$BRANCH" != "unknown" ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ] && [ "$BRANCH" != "develop" ]; then
  SUGGESTION=$(echo "$BRANCH" | sed 's|.*/||')
fi

# List existing features
EXISTING=""
if [ -d "$FEATURES_DIR" ]; then
  EXISTING=$(ls -1 "$FEATURES_DIR" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
fi

# Auto-set if branch suggestion matches an existing feature folder
BRANCH_MATCH="none"
if [ -n "$SUGGESTION" ] && echo "$SUGGESTION" | grep -qE '^[a-z0-9_-]+$' && [ -d "$FEATURES_DIR/$SUGGESTION" ]; then
  BRANCH_MATCH="exact"
  # Auto-set the feature
  mkdir -p "$OUTPUT_DIR"
  echo "$SUGGESTION" > "$ACTIVE_FILE"
  cat >&2 <<HOOK_MSG
BMAD_FEATURE_ACTIVE
feature: $SUGGESTION
planning_path: _bmad-output/features/$SUGGESTION/planning
implementation_path: _bmad-output/features/$SUGGESTION/implementation
HOOK_MSG
  exit 0
fi

# No auto-match — prompt based on mode
if [ "$MODE" = "advisory" ]; then
  cat >&2 <<HOOK_MSG
BMAD_FEATURE_SUGGESTED
mode: advisory
existing_features: ${EXISTING:-"(none)"}
branch_suggestion: ${SUGGESTION:-"(none)"}
HOOK_MSG
  exit 0
fi

# Strict mode — block
cat >&2 <<HOOK_MSG
BMAD_FEATURE_REQUIRED
mode: strict
existing_features: ${EXISTING:-"(none)"}
branch: $BRANCH
branch_suggestion: ${SUGGESTION:-"(none)"}
branch_match: $BRANCH_MATCH
set_command: $SET_FEATURE_CMD
HOOK_MSG

exit 2
