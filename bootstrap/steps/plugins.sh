#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

plugins_dir="$HOME/.config/omarchy/plugins"
is_apply && mkdir -p "$plugins_dir"

plugin_is_valid() {
  local target="$1" id="$2"
  [[ -f $target/manifest.json ]] &&
    [[ $(jq -r '.id // empty' "$target/manifest.json" 2>/dev/null) == "$id" ]]
}

while IFS=$'\t' read -r mode id url checkout; do
  target="$plugins_dir/$id"

  case "$mode" in
    git)
      if plugin_is_valid "$target" "$id"; then
        note "ok: plugin $id"
      elif [[ -e $target || -L $target ]]; then
        warn "plugin path exists but has the wrong manifest: $id"
      elif is_apply; then
        omarchy plugin add "$url" --yes
      else
        note "missing: plugin $id"
      fi
      ;;
    repo-link)
      repo="$HOME/$checkout"
      if [[ ! -d $repo/.git ]]; then
        if is_apply && [[ ! -e $repo ]]; then
          mkdir -p "$(dirname "$repo")"
          git clone -- "$url" "$repo"
        else
          note "missing: plugin checkout $checkout"
          continue
        fi
      fi

      if [[ -L $target && $(readlink -f "$target") == $(readlink -f "$repo") ]]; then
        note "ok: plugin $id"
      elif is_apply; then
        if [[ -e $target || -L $target ]]; then
          backup=$(backup_path "$target")
          mv -- "$target" "$backup"
          note "backup: ${backup#$HOME/}"
        fi
        ln -s "$repo" "$target"
        note "linked: plugin $id"
      else
        note "diff: plugin link $id"
      fi
      ;;
    vendored)
      if plugin_is_valid "$target" "$id"; then
        note "ok: plugin $id"
      else
        warn "vendored plugin is missing or invalid: $id"
      fi
      ;;
    *) die "unknown plugin mode: $mode" ;;
  esac
done < <(read_tsv "$BOOTSTRAP_DIR/plugins.tsv")

if is_apply && command -v omarchy-shell >/dev/null 2>&1; then
  timeout 3 omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi
