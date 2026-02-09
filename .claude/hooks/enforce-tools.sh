#!/bin/bash
# PreToolUse hook for Bash tool: blocks disallowed tools and suggests alternatives.
# Reads tool input JSON from stdin.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block pip/pip3/poetry → suggest uv
if echo "$COMMAND" | grep -qE '(^|\s|/)(pip3?|poetry)(\s|$)'; then
  echo "BLOCKED: Do not use pip or poetry. Use uv instead."
  echo "  pip install X    → uv add X"
  echo "  pip freeze       → uv pip freeze"
  echo "  python -m venv   → uv venv"
  echo "  poetry add X     → uv add X"
  exit 2
fi

# Block python -m pip / python -m venv
if echo "$COMMAND" | grep -qE 'python3?\s+-m\s+(pip|venv)'; then
  echo "BLOCKED: Do not use python -m pip/venv. Use uv instead."
  exit 2
fi

# Block make → suggest just
if echo "$COMMAND" | grep -qE '(^|\s)make(\s|$)'; then
  echo "BLOCKED: Do not use make. Use just instead."
  echo "  make build → just build"
  echo "  make test  → just test"
  exit 2
fi

exit 0
