#!/usr/bin/env bash
# End-to-end check against the running Omarchy shell: the widget must be
# installed (symlinked into ~/.config/omarchy/plugins and present in the bar
# layout) for its IPC surface to answer.
set -euo pipefail

if ! omarchy-shell shell ping >/dev/null 2>&1; then
  echo "omarchy-shell is not running; e2e requires a live shell" >&2
  exit 1
fi

status=$(omarchy-shell melonamin.scribe status)
if [[ -z $status ]]; then
  echo "widget IPC returned an empty status" >&2
  exit 1
fi

echo "e2e ok: widget loaded, status: $status"
