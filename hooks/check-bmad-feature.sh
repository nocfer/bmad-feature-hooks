#!/bin/bash
# Claude Code PreToolUse hook: ensures a BMad feature context is set
# before artifact-producing skills run.
#
# If no feature is set, blocks with exit 2 and instructs Claude to:
#   1. Ask the user for a feature name (with suggestions based on branch/context)
#   2. Set it via: bmad-set-feature.sh <name>
#   3. Retry the skill
#
# If a feature is already set (via manual override or prior prompt), allows through.

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

# Check if a feature is already set
PLANNING=$(grep '^planning_artifacts:' "$CONFIG" | head -1)
if echo "$PLANNING" | grep -q '/features/'; then
  FEATURE=$(echo "$PLANNING" | sed 's|.*features/\([^/]*\)/.*|\1|')
  echo "BMad feature active: $FEATURE" >&2
  exit 0
fi

# No feature set — gather context for Claude and block
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Derive a suggestion from the branch name (last segment after any slash)
SUGGESTION=""
if [ "$BRANCH" != "unknown" ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ] && [ "$BRANCH" != "develop" ]; then
  SUGGESTION=$(echo "$BRANCH" | sed 's|.*/||')
fi

# Resolve path to bmad-set-feature.sh relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SET_FEATURE_CMD="$SCRIPT_DIR/bmad-set-feature.sh"

cat >&2 <<HOOK_MSG
BMAD_FEATURE_REQUIRED: No feature context is set. Artifacts would write to the flat default directory.

ACTION REQUIRED — Ask the user to choose a feature name for this BMad session.
Suggest names based on the current context:
  - Git branch: $BRANCH
  - Branch-derived suggestion: ${SUGGESTION:-"(none — protected or unrecognized branch)"}
  - Also suggest names based on the conversation topic if relevant.

Feature names must be lowercase alphanumeric with hyphens or underscores only.

Once the user picks a name, run this command to set it:
  $SET_FEATURE_CMD <chosen-name>

Then retry the BMad skill that was just blocked.

IMPORTANT: When the BMad planning/implementation flow is complete, restore default paths by running:
  $SET_FEATURE_CMD --clear
HOOK_MSG

exit 2
