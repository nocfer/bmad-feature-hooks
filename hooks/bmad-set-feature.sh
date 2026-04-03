#!/bin/bash
# BMad feature context manager — codebase agnostic.
# Manages feature state via a local .active-feature file.
# Never modifies config.yaml.
#
# Usage:
#   bmad-set-feature.sh                  # Show current feature
#   bmad-set-feature.sh <feature-name>   # Set active feature
#   bmad-set-feature.sh --clear          # Clear active feature
#   bmad-set-feature.sh --list           # List existing features

set -uo pipefail

# Resolve project root
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OUTPUT_DIR="$PROJECT_ROOT/_bmad-output"
ACTIVE_FILE="$OUTPUT_DIR/.active-feature"
FEATURES_DIR="$OUTPUT_DIR/features"

# Get current active feature (empty string if none)
get_active() {
  if [ -f "$ACTIVE_FILE" ]; then
    head -1 "$ACTIVE_FILE"
  fi
}

if [ -z "${1:-}" ]; then
  # No args: show current feature
  ACTIVE=$(get_active)
  if [ -n "$ACTIVE" ]; then
    echo "Active feature: $ACTIVE"
  else
    echo "No feature set (using default paths)"
  fi
  exit 0
fi

case "$1" in
  --clear)
    if [ -f "$ACTIVE_FILE" ]; then
      if ! rm "$ACTIVE_FILE"; then
        echo "Error: Failed to remove $ACTIVE_FILE" >&2
        exit 1
      fi
    fi
    echo "BMad feature cleared. Using default output paths."
    exit 0
    ;;

  --list)
    ACTIVE=$(get_active)
    if [ ! -d "$FEATURES_DIR" ] || [ -z "$(ls -A "$FEATURES_DIR" 2>/dev/null)" ]; then
      echo "No features found."
      exit 0
    fi
    for dir in "$FEATURES_DIR"/*/; do
      [ -d "$dir" ] || continue
      NAME=$(basename "$dir")
      if [ "$NAME" = "$ACTIVE" ]; then
        echo "* $NAME        (active)"
      else
        echo "  $NAME"
      fi
    done
    exit 0
    ;;

  --*)
    echo "Error: Unknown option '$1'" >&2
    echo "Usage: bmad-set-feature.sh [<feature-name> | --clear | --list]" >&2
    exit 1
    ;;

  *)
    FEATURE="$1"

    # Validate feature name (lowercase alphanumeric, hyphens, underscores only)
    if ! echo "$FEATURE" | grep -qE '^[a-z0-9_-]+$'; then
      echo "Error: Feature name must contain only lowercase letters, numbers, hyphens, and underscores" >&2
      exit 1
    fi

    # Ensure output directory exists
    if ! mkdir -p "$OUTPUT_DIR"; then
      echo "Error: Failed to create output directory $OUTPUT_DIR" >&2
      exit 1
    fi

    # Write feature to state file
    echo "$FEATURE" > "$ACTIVE_FILE"

    echo "BMad feature set to: $FEATURE"
    echo "  Planning:       _bmad-output/features/$FEATURE/planning/"
    echo "  Implementation: _bmad-output/features/$FEATURE/implementation/"
    exit 0
    ;;
esac
