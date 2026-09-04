#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

if command -v mise >/dev/null 2>&1; then
  if is_apply; then
    mise trust "$HOME/.config/mise/config.toml"
    mise -C "$HOME" install -y
    note "installed: mise toolchain"
  else
    if missing_mise=$(MISE_CONFIG_FILE="$HOME/.config/mise/config.toml" mise ls --missing 2>/dev/null) &&
        [[ -z $missing_mise ]]; then
      note "ok: mise toolchain"
    else
      note "diff: mise tools are missing or the config needs trust"
    fi
  fi
else
  warn "mise is unavailable; finish the base Omarchy install first"
fi

if command -v rustup >/dev/null 2>&1; then
  if [[ -f $HOME/.rustup/settings.toml ]] &&
      rustup show active-toolchain >/dev/null 2>&1; then
    note "ok: Rust toolchain"
  elif is_apply; then
    rustup default stable
  else
    note "missing: stable Rust toolchain"
  fi

  while IFS= read -r crate; do
    binary="$crate"
    [[ $crate == flowscope-cli ]] && binary=flowscope
    if command -v "$binary" >/dev/null 2>&1; then
      note "ok: cargo tool $crate"
    elif is_apply; then
      cargo install "$crate"
    else
      note "missing: cargo tool $crate"
    fi
  done < <(manifest_lines "$BOOTSTRAP_DIR/cargo-tools.txt")
else
  warn "rustup is unavailable; cargo tools cannot be checked"
fi

if command -v code >/dev/null 2>&1; then
  installed_extensions=$(mktemp)
  trap 'rm -f "$installed_extensions"' EXIT
  code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u > "$installed_extensions"
  while read -r _ extension _; do
    [[ -n ${extension:-} ]] || continue
    if grep -Fqx "${extension,,}" "$installed_extensions"; then
      continue
    elif is_apply; then
      code --install-extension "$extension" --force
    else
      note "missing: VS Code extension $extension"
    fi
  done < <(grep '^code --install-extension ' "$DOTFILES_ROOT/.vscode-extensions.sh")
else
  note "skip: VS Code extensions (VS Code is not installed)"
fi

if command -v fish >/dev/null 2>&1; then
  if [[ -f $HOME/.config/fish/functions/tide.fish &&
        -f $HOME/.config/fish/functions/_autopair_insert_left.fish ]]; then
    note "ok: Fish plugins"
  elif is_apply; then
    fish -lc 'fisher update'
    note "installed: Fish plugins"
  else
    note "missing: installed Fish plugin files"
  fi
fi
