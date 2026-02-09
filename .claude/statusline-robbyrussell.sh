#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current directory from JSON
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# Get just the directory name (like %c in zsh)
dir_name=$(basename "$current_dir")

# Check if we're in a git repository and get branch info
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check if working directory is clean
        if git -C "$current_dir" diff-index --quiet HEAD -- 2>/dev/null; then
            git_info=" git:($branch)"
        else
            git_info=" git:($branch) ✗"
        fi
    else
        git_info=""
    fi
else
    git_info=""
fi

# Build the prompt (without colors for terminal compatibility, but keeping the structure)
printf "➜ %s%s" "$dir_name" "$git_info"