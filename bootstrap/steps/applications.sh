#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

while IFS=$'\t' read -r name url; do
  desktop="$HOME/.local/share/applications/$name.desktop"
  if [[ -f $desktop ]]; then
    note "ok: web app $name"
  elif is_apply; then
    omarchy webapp install "$name" "$url" "" "" ""
    note "installed: web app $name"
  else
    note "missing: web app $name"
  fi
done < <(read_tsv "$BOOTSTRAP_DIR/webapps.tsv")

install_agterm() {
  local api release tag asset tmp extracted destination desktop
  api=https://api.github.com/repos/melonamin/agterm/releases/latest

  if command -v agterm-linux >/dev/null 2>&1 && command -v agtermctl >/dev/null 2>&1; then
    note "ok: agterm"
    return
  elif ! is_apply; then
    note "missing: agterm"
    return
  fi

  require_command curl
  require_command jq
  release=$(curl -fsSL "$api")
  tag=$(jq -r '.tag_name' <<<"$release")
  asset=$(jq -r '.assets[] | select(.name | test("x86_64\\.tar\\.gz$")) | .browser_download_url' <<<"$release" | head -1)
  [[ -n $tag && $tag != null && -n $asset ]] || die "could not find the current agterm Linux archive"

  tmp=$(mktemp -d)
  curl -fL "$asset" -o "$tmp/agterm.tar.gz"
  tar -xzf "$tmp/agterm.tar.gz" -C "$tmp"
  extracted=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
  [[ -n $extracted ]] || die "agterm archive did not contain a directory"

  destination="$HOME/.local/opt/agterm-$tag"
  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" "$HOME/.local/share/applications"
  if [[ ! -d $destination ]]; then
    mv "$extracted" "$destination"
  fi
  ln -nsf "$destination/bin/agterm-linux" "$HOME/.local/bin/agterm-linux"
  ln -nsf "$destination/bin/agtermctl" "$HOME/.local/bin/agtermctl"

  desktop=$(find "$destination" -maxdepth 1 -type f -name '*.desktop' | head -1)
  if [[ -n $desktop ]]; then
    cp "$desktop" "$HOME/.local/share/applications/$(basename "$desktop")"
    sed -i "s|^Exec=.*|Exec=$HOME/.local/bin/agterm-linux|" \
      "$HOME/.local/share/applications/$(basename "$desktop")"
  fi
  if [[ -d $destination/share/icons ]]; then
    mkdir -p "$HOME/.local/share/icons"
    cp -a "$destination/share/icons/." "$HOME/.local/share/icons/"
  fi
  rm -rf "$tmp"
  note "installed: agterm $tag"
}

install_agterm
