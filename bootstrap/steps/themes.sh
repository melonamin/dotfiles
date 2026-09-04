#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

themes_dir="$HOME/.config/omarchy/themes"
is_apply && mkdir -p "$themes_dir"

install_wallhaven_theme() {
  local name="$1" wall_id="$2" target="$themes_dir/$name"
  local metadata image_url extension image tmp

  is_apply && mkdir -p "$target/backgrounds"
  copy_file "$BOOTSTRAP_DIR/themes/$name/colors.toml" "$target/colors.toml"
  copy_file "$BOOTSTRAP_DIR/themes/$name/icons.theme" "$target/icons.theme"

  if [[ -d $target/backgrounds ]] &&
      find "$target/backgrounds" -maxdepth 1 -type f | grep -q .; then
    note "ok: theme $name background"
  elif ! is_apply; then
    note "missing: theme $name background (Wallhaven $wall_id)"
  else
    metadata=$(curl -fsSL "https://wallhaven.cc/api/v1/w/$wall_id")
    image_url=$(jq -r '.data.path // empty' <<<"$metadata")
    [[ -n $image_url ]] || die "Wallhaven did not return image $wall_id"
    extension=${image_url##*.}
    extension=${extension%%\?*}
    image="$target/backgrounds/wallhaven-$wall_id.$extension"
    tmp="$image.part"
    curl -fL "$image_url" -o "$tmp"
    mv "$tmp" "$image"
    note "downloaded: theme $name background"
  fi
}

while IFS=$'\t' read -r mode name source; do
  target="$themes_dir/$name"
  case "$mode" in
    git)
      if [[ -d $target/.git ]]; then
        actual=$(git_origin "$target")
        if [[ $actual == "$source" ]]; then
          note "ok: theme $name"
        else
          warn "theme $name has origin '$actual', expected '$source'"
        fi
      elif [[ -d $target ]]; then
        warn "theme $name exists but is not a Git checkout"
      elif is_apply; then
        omarchy theme install "$source"
      else
        note "missing: theme $name"
      fi
      ;;
    wallhaven) install_wallhaven_theme "$name" "$source" ;;
    *) die "unknown theme mode: $mode" ;;
  esac
done < <(read_tsv "$BOOTSTRAP_DIR/themes.tsv")
