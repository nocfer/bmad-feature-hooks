# bmad-feature-hooks

Claude Code hooks that enforce feature-based directory isolation for [BMad Method](https://github.com/bmadcode/bmad-method) artifact output.

## Problem

When running BMad skills (PRD creation, architecture design, sprint planning, etc.), all artifacts land in a flat default output directory. This makes it hard to organize work across multiple features or epics.

## Solution

These hooks intercept BMad skill invocations via Claude Code's hook system:

- **PreToolUse** (`check-bmad-feature.sh`): Before an artifact-producing BMad skill runs, checks if a feature context is set. If not, blocks the skill and prompts Claude to ask the user for a feature name.
- **PostToolUse** (`restore-bmad-feature.sh`): After a BMad skill completes, reminds Claude to clear the feature context when the flow is done.
- **Utility** (`bmad-set-feature.sh`): Sets, shows, or clears the active feature. Updates `planning_artifacts` and `implementation_artifacts` paths in the BMad config.

### Directory structure with a feature set

```
_bmad-output/
  features/
    my-feature/
      planning/        # PRDs, architecture docs, epics
      implementation/  # Stories, generated code
    another-feature/
      planning/
      implementation/
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI or IDE extension
- [BMad Method](https://github.com/bmadcode/bmad-method) installed in your project (`_bmad/` directory with `config.yaml`)
- `jq` (for the install script and hook input parsing)
- `bash` 4+

## Installation

### Automatic (recommended)

Clone this repo somewhere persistent, then run the install script pointing at your project:

```bash
git clone https://github.com/nocfer/bmad-feature-hooks.git ~/bmad-feature-hooks

# Install into your project
~/bmad-feature-hooks/install.sh /path/to/your/project
```

This creates or merges into your project's `.claude/settings.json` with absolute paths to the hooks.

### Manual

1. Clone this repo:
   ```bash
   git clone https://github.com/nocfer/bmad-feature-hooks.git ~/bmad-feature-hooks
   ```

2. Add to your project's `.claude/settings.json` (see `settings.example.json` for the full structure):
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Skill",
           "hooks": [
             {
               "type": "command",
               "command": "~/bmad-feature-hooks/hooks/check-bmad-feature.sh"
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
               "command": "~/bmad-feature-hooks/hooks/restore-bmad-feature.sh"
             }
           ]
         }
       ]
     }
   }
   ```

## Usage

The hooks work automatically once installed. When you invoke a gated BMad skill (e.g., `bmad-create-prd`), Claude will:

1. Be blocked by the PreToolUse hook if no feature is set
2. Ask you to pick a feature name (suggesting one from your git branch)
3. Set the feature context
4. Retry the skill — artifacts now go to `_bmad-output/features/<name>/`

You can also manage the feature context manually:

```bash
# Show current feature
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh

# Set a feature
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh my-feature

# Clear (restore defaults)
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh --clear
```

### Gated skills

The following BMad skills are gated (require a feature context):

- `bmad-create-prd`, `bmad-edit-prd`, `bmad-validate-prd`
- `bmad-create-architecture`
- `bmad-create-epics-and-stories`, `bmad-create-story`
- `bmad-create-ux-design`
- `bmad-check-implementation-readiness`
- `bmad-product-brief`, `bmad-correct-course`
- `bmad-dev-story`, `bmad-quick-dev`
- `bmad-sprint-planning`, `bmad-sprint-status`
- `bmad-qa-generate-e2e-tests`
- `bmad-retrospective`

All other BMad skills (research, brainstorming, agent conversations, reviews, etc.) run without requiring a feature context.

## How it works

The hooks read the BMad `config.yaml` in your project's `_bmad/` directory. When a feature is set, the `planning_artifacts` and `implementation_artifacts` paths are rewritten to point at `_bmad-output/features/<name>/planning` and `_bmad-output/features/<name>/implementation` respectively.

The hooks are codebase-agnostic — they auto-discover the config by searching for `config.yaml` files under `_bmad/` that contain a `planning_artifacts:` key.

## License

MIT
