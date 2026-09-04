#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

while IFS= read -r rel; do
  copy_tracked_path "$rel"
done < <(manifest_lines "$BOOTSTRAP_DIR/copy-paths.txt")

install_keyd_file() {
  local source="$1" target="$2" backup

  if cmp -s "$source" "$target" 2>/dev/null; then
    note "ok: $target"
    return
  fi

  if ! is_apply; then
    note "diff: $target"
    return
  fi

  if sudo test -e "$target"; then
    backup="$(backup_path "$target")"
    sudo cp -a -- "$target" "$backup"
    note "backup: $backup"
  fi
  sudo install -Dm644 -- "$source" "$target"
  note "copied: $target"
}

install_keyd_file "$DOTFILES_ROOT/.config/keyd/system-default.conf" /etc/keyd/default.conf
install_keyd_file "$DOTFILES_ROOT/.config/keyd/app.conf" /etc/keyd/app.conf

if systemctl is-enabled keyd.service >/dev/null 2>&1; then
  note "ok: keyd.service enabled"
elif is_apply; then
  sudo systemctl enable --now keyd.service
  note "enabled: keyd.service"
else
  note "disabled: keyd.service"
fi
