#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

themes_dir="$HOME/.config/omarchy/themes"
is_apply && mkdir -p "$themes_dir"

install_wallhaven_theme() {
  local name="$1" wall_id="$2" target="$themes_dir/$name"
  local metadata image_url extension image tmp shard downloaded=false bundled

  is_apply && mkdir -p "$target/backgrounds"
  copy_file "$BOOTSTRAP_DIR/themes/$name/colors.toml" "$target/colors.toml"
  copy_file "$BOOTSTRAP_DIR/themes/$name/icons.theme" "$target/icons.theme"

  while IFS= read -r -d '' bundled; do
    copy_file "$bundled" "$target/backgrounds/$(basename "$bundled")"
  done < <(find "$BOOTSTRAP_DIR/themes/$name/backgrounds" -maxdepth 1 -type f -print0 2>/dev/null)

  if [[ -d $target/backgrounds ]] &&
      find "$target/backgrounds" -maxdepth 1 -type f | grep -q .; then
    note "ok: theme $name background"
  elif ! is_apply; then
    note "missing: theme $name background (Wallhaven $wall_id)"
  else
    metadata=$(curl -fsSL "https://wallhaven.cc/api/v1/w/$wall_id" 2>/dev/null || true)
    image_url=$(jq -r '.data.path // empty' <<<"$metadata" 2>/dev/null || true)

    if [[ -n $image_url ]]; then
      extension=${image_url##*.}
      extension=${extension%%\?*}
      image="$target/backgrounds/wallhaven-$wall_id.$extension"
      tmp="$image.part"
      curl -fL "$image_url" -o "$tmp"
      downloaded=true
    else
      # Removed/unlisted images can remain available on Wallhaven's CDN after
      # their API stops returning metadata. Try its deterministic asset path.
      shard=${wall_id:0:2}
      for extension in jpg png jpeg webp; do
        image="$target/backgrounds/wallhaven-$wall_id.$extension"
        tmp="$image.part"
        if curl -fL "https://w.wallhaven.cc/full/$shard/wallhaven-$wall_id.$extension" -o "$tmp"; then
          downloaded=true
          break
        fi
      done
    fi

    [[ $downloaded == true ]] || die "Wallhaven image $wall_id is unavailable"
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
