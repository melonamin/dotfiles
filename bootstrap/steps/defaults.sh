#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

current_value() {
  case "$1" in
    theme) omarchy theme current 2>/dev/null || true ;;
    background) readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true ;;
    font) omarchy font current 2>/dev/null || true ;;
    terminal) omarchy default terminal 2>/dev/null || true ;;
    browser) omarchy default browser 2>/dev/null || true ;;
    editor) omarchy default editor 2>/dev/null || true ;;
    agent) omarchy default agent 2>/dev/null || true ;;
    shell) getent passwd "$USER" | cut -d: -f7 ;;
  esac
}

apply_value() {
  local key="$1" value="$2"
  case "$key" in
    theme) omarchy theme set "$value" ;;
    background)
      [[ -f $value ]] || die "background is unavailable: $value"
      omarchy theme bg set "$value"
      ;;
    font) omarchy font set "$value" ;;
    terminal) omarchy default terminal "$value" ;;
    browser) omarchy default browser "$value" ;;
    editor) omarchy default editor "$value" ;;
    agent)
      mkdir -p "$HOME/.config/omarchy/defaults"
      printf '%s\n' "$value" > "$HOME/.config/omarchy/defaults/agent"
      ;;
    shell) sudo chsh -s "$value" "$USER" ;;
    *) die "unknown default: $key" ;;
  esac
}

# Theme must be applied before its exact background; keep manifest order.
while IFS=$'\t' read -r key value; do
  current=$(current_value "$key")
  if [[ $current == "$value" ]] ||
      [[ $key == background && ${current##*/} == ${value##*/} ]]; then
    note "ok: $key = $value"
  elif is_apply; then
    note "setting: $key = $value (was '${current:-unset}')"
    apply_value "$key" "$value"
  else
    note "diff: $key = '${current:-unset}', expected '$value'"
  fi
done < <(read_tsv "$BOOTSTRAP_DIR/defaults.tsv")
