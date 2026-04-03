# bmad-feature-hooks

Claude Code hooks that enforce feature-based directory isolation for [BMad Method](https://github.com/bmadcode/bmad-method) artifact output.

## Problem

When running BMad skills (PRD creation, architecture design, sprint planning, etc.), all artifacts land in a flat default output directory. This makes it hard to organize work across multiple features or epics.

## Solution

A PreToolUse hook intercepts artifact-producing BMad skill invocations and ensures a feature context is set. Feature state is stored in a local `.active-feature` file — never by modifying `config.yaml`.

- **PreToolUse** (`check-bmad-feature.sh`): Before a gated BMad skill runs, checks for an active feature. Auto-sets it when the git branch matches an existing feature folder. Outputs structured data so Claude can ask the user naturally when needed.
- **Utility** (`bmad-set-feature.sh`): Sets, shows, lists, or clears the active feature.

### Directory structure with a feature set

```
_bmad-output/
  .active-feature          # Current feature name (gitignored)
  features/
    my-feature/
      planning/            # PRDs, architecture docs, epics
      implementation/      # Stories, generated code
    another-feature/
      planning/
      implementation/
```

## Enforcement Modes

The hook supports three enforcement modes, configured per-project in `_bmad/bmm/config.yaml`:

```yaml
feature_hooks_mode: strict    # strict | advisory | off
```

| Mode | Behaviour |
|------|-----------|
| **strict** (default) | Blocks the skill (exit 2) until a feature is set |
| **advisory** | Allows the skill but suggests setting a feature |
| **off** | Silent pass-through, hooks installed but inactive |

The mode is version-controlled with your project — the whole team shares the same behaviour.

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

This creates or merges into your project's `.claude/settings.json` and adds `.active-feature` to `.gitignore`.

### Manual

1. Clone this repo:
   ```bash
   git clone https://github.com/nocfer/bmad-feature-hooks.git ~/bmad-feature-hooks
   ```

2. Add to your project's `.claude/settings.json` (see `settings.example.json`):
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
       ]
     }
   }
   ```

3. Add `_bmad-output/.active-feature` to your project's `.gitignore`.

## Usage

The hooks work automatically once installed. When you invoke a gated BMad skill (e.g., `bmad-create-prd`):

1. If your git branch matches an existing feature folder — **auto-sets the feature, no prompt**
2. If no match but features exist — Claude asks: "Which feature? (existing: x, y) Or new name."
3. If no features exist — Claude suggests a name from your branch
4. In advisory mode — Claude suggests but doesn't block

You can also manage the feature context manually:

```bash
# Show current feature
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh

# Set a feature
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh my-feature

# List existing features
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh --list

# Clear active feature
! /path/to/bmad-feature-hooks/hooks/bmad-set-feature.sh --clear
```

### Gated skills

The following BMad skills require a feature context:

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

The PreToolUse hook reads feature state from `_bmad-output/.active-feature` (a single-line file containing the feature name). When a feature is active, the hook tells Claude the artifact paths via structured stderr output. Claude uses these paths when running the skill. `config.yaml` is never modified.

The hook auto-discovers the enforcement mode by reading `feature_hooks_mode` from `config.yaml` files under `_bmad/`.

## License

MIT
