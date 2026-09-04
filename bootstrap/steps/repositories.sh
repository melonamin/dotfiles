#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

clone_repository() {
  local url="$1" target="$2" post_install="$3" backup stage

  mkdir -p "$(dirname "$target")"
  if [[ -d $target ]]; then
    backup=$(backup_path "$target")
    stage="${target}.bootstrap-clone-$BOOTSTRAP_RUN_ID"
    cp -a -- "$target" "$backup"
    note "backup: ${backup#$HOME/}"
    git clone -- "$url" "$stage"
    cp -a -- "$stage/." "$target/"
    rm -rf -- "$stage"
  else
    if [[ -e $target || -L $target ]]; then
      backup=$(backup_path "$target")
      mv -- "$target" "$backup"
      note "backup: ${backup#$HOME/}"
    fi
    git clone -- "$url" "$target"
  fi

  if [[ $post_install != - ]]; then
    (cd "$target" && bash -lc "$post_install")
  fi
}

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
        if is_apply; then
          clone_repository "$url" "$target" "$post_install"
          note "merged checkout: $rel"
        else
          warn "$rel exists but is not a Git checkout"
        fi
      elif is_apply; then
        clone_repository "$url" "$target" "$post_install"
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
