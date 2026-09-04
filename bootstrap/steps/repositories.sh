#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

while IFS=$'\t' read -r mode url rel post_install; do
  target="$HOME/$rel"

  case "$mode" in
    clone)
      if [[ -d $target/.git ]]; then
        actual=$(git_origin "$target")
        if [[ $actual == "$url" ]]; then
          note "ok: $rel"
        else
          warn "$rel exists with origin '$actual', expected '$url'"
        fi
      elif [[ -e $target ]]; then
        warn "$rel exists but is not a Git checkout"
      elif is_apply; then
        mkdir -p "$(dirname "$target")"
        git clone -- "$url" "$target"
        if [[ $post_install != - ]]; then
          (cd "$target" && bash -lc "$post_install")
        fi
        note "cloned: $rel"
      else
        note "missing: $rel"
      fi
      ;;
    local-only)
      if [[ -d $target ]]; then
        note "local-only present: $rel"
      else
        warn "local-only project cannot be restored: $rel"
      fi
      ;;
    *) die "unknown repository mode: $mode" ;;
  esac
done < <(read_tsv "$BOOTSTRAP_DIR/repositories.tsv")
