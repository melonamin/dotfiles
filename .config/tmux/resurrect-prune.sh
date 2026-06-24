#!/usr/bin/env bash
# Remove the per-session scratch terminals (scratch-*) and the global jot pad
# from the most recent tmux-resurrect save, so they are not restored on boot
# and do not accumulate over time. Invoked via @resurrect-hook-post-save-all.
#
# Only "pane" and "window" records materialize sessions on restore, so dropping
# those records (matched on the session-name field) is enough to keep these
# sessions out of the restore without disturbing anything else.

dir="$HOME/.tmux/resurrect"
[ -d "$dir" ] || dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
last="$dir/last"
[ -e "$last" ] || exit 0
file="$(readlink -f "$last")"
[ -f "$file" ] || exit 0

tmp="$(mktemp)" || exit 0
if awk -F'\t' '
  ($1 == "pane" || $1 == "window") && ($2 == "jot" || $2 ~ /^scratch-/) { next }
  { print }
' "$file" > "$tmp"; then
  mv "$tmp" "$file"
else
  rm -f "$tmp"
fi
