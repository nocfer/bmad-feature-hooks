#!/bin/bash
# BMad feature context manager — codebase agnostic.
# Finds the BMad config that owns planning_artifacts automatically.
#
# Called by Claude automatically via hooks. Can also be used manually:
#   ! /path/to/bmad-set-feature.sh <feature-name>   # Set active feature
#   ! /path/to/bmad-set-feature.sh                   # Show current feature
#   ! /path/to/bmad-set-feature.sh --clear            # Reset to defaults

set -uo pipefail

# Resolve project root: use CLAUDE_PROJECT_DIR if available, otherwise cwd
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Find the config that owns planning_artifacts
CONFIG=""
for f in $(find "$PROJECT_ROOT/_bmad" -name "config.yaml" -maxdepth 2 2>/dev/null); do
  if grep -q '^planning_artifacts:' "$f" 2>/dev/null; then
    CONFIG="$f"
    break
  fi
done

if [ -z "$CONFIG" ]; then
  echo "Error: No BMad config.yaml with planning_artifacts found under _bmad/" >&2
  exit 1
fi

if [ -z "${1:-}" ]; then
  # No args: show current feature
  PLANNING=$(grep '^planning_artifacts:' "$CONFIG")
  if echo "$PLANNING" | grep -q '/features/'; then
    FEATURE=$(echo "$PLANNING" | sed 's|.*features/\([^/]*\)/.*|\1|')
    echo "Active feature: $FEATURE"
  else
    echo "No feature set (using default paths)"
  fi
  exit 0
fi

FEATURE="$1"

if [ "$FEATURE" = "--clear" ]; then
  # Cross-platform sed: detect GNU vs BSD
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i \
      -e 's|planning_artifacts:.*|planning_artifacts: "{project-root}/_bmad-output/planning-artifacts"|' \
      -e 's|implementation_artifacts:.*|implementation_artifacts: "{project-root}/_bmad-output/implementation-artifacts"|' \
      "$CONFIG"
  else
    sed -i '' \
      -e 's|planning_artifacts:.*|planning_artifacts: "{project-root}/_bmad-output/planning-artifacts"|' \
      -e 's|implementation_artifacts:.*|implementation_artifacts: "{project-root}/_bmad-output/implementation-artifacts"|' \
      "$CONFIG"
  fi
  echo "BMad feature cleared. Using default output paths."
  exit 0
fi

# Validate feature name
if ! echo "$FEATURE" | grep -qE '^[a-zA-Z0-9_-]+$'; then
  echo "Error: Feature name must contain only letters, numbers, hyphens, and underscores" >&2
  exit 1
fi

# Cross-platform sed
if sed --version 2>/dev/null | grep -q GNU; then
  sed -i \
    -e "s|planning_artifacts:.*|planning_artifacts: \"{project-root}/_bmad-output/features/${FEATURE}/planning\"|" \
    -e "s|implementation_artifacts:.*|implementation_artifacts: \"{project-root}/_bmad-output/features/${FEATURE}/implementation\"|" \
    "$CONFIG"
else
  sed -i '' \
    -e "s|planning_artifacts:.*|planning_artifacts: \"{project-root}/_bmad-output/features/${FEATURE}/planning\"|" \
    -e "s|implementation_artifacts:.*|implementation_artifacts: \"{project-root}/_bmad-output/features/${FEATURE}/implementation\"|" \
    "$CONFIG"
fi

echo "BMad feature set to: $FEATURE"
echo "  Planning:       _bmad-output/features/$FEATURE/planning/"
echo "  Implementation: _bmad-output/features/$FEATURE/implementation/"
