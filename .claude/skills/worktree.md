---
description: Manage git worktrees using gt utility for parallel feature development
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Git Worktree Management with gt

You help the user manage git worktrees for parallel feature development using the `gt` utility.

## Context

The user wants to work on multiple features in parallel within the same repository. Each feature gets its own worktree (a separate working directory with its own branch), avoiding the need to stash/switch branches.

## gt Utility Commands

```bash
gt <name>              # Create worktree from current branch
gt <name> <branch>     # Create worktree from specified branch (usually main)
gt <name> -x claude    # Create worktree and start Claude Code in it
```

## Typical Workflows

### Starting a New Feature

1. Ask user for the feature name (or infer from context)
2. Create worktree from main: `gt <feature-name> main`
3. The user is now in a new directory with a fresh branch

### Finishing a Feature (merge back to main)

When user wants to merge a feature back:

1. Confirm current worktree/branch with `git branch --show-current` and `pwd`
2. Check for uncommitted changes: `git status`
3. If clean, switch to main worktree: `cd` to main worktree path (find via `git worktree list`)
4. Merge the feature branch: `git merge <feature-branch>`
5. Push if requested: `git push`
6. Optionally remove the worktree: `git worktree remove <path>` or use `gt` interactive mode

### Listing Worktrees

```bash
git worktree list      # Show all worktrees
```

## Important Notes

- Always check `git status` before switching or merging
- Worktrees share the same .git directory, so commits are immediately visible across worktrees
- Each worktree has its own branch - never have two worktrees on the same branch
- The main worktree is typically in the original clone location

## When User Asks To...

- "work on feature X" / "start feature X" → Create worktree: `gt <feature-name> main`
- "finish this feature" / "merge back" → Guide through merge workflow
- "switch to feature X" → Help navigate to that worktree
- "clean up" / "delete worktree" → Remove completed worktrees
