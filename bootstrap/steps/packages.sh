#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

require_command pacman
require_command omarchy

install_manifest() {
  local label="$1" manifest="$2" installer="$3" package
  local missing=()

  while IFS= read -r package; do
    pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
  done < <(manifest_lines "$manifest")

  if (( ${#missing[@]} == 0 )); then
    note "ok: $label packages"
  elif ! is_apply; then
    note "missing $label (${#missing[@]}): ${missing[*]}"
  else
    note "installing $label (${#missing[@]}): ${missing[*]}"
    if [[ $installer == arch ]]; then
      omarchy pkg add "${missing[@]}"
    else
      omarchy pkg aur add "${missing[@]}"
    fi
  fi
}

install_manifest "repository" "$BOOTSTRAP_DIR/packages-arch.txt" arch
install_manifest "AUR" "$BOOTSTRAP_DIR/packages-aur.txt" aur
