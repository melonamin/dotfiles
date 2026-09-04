#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT is required}"
: "${BOOTSTRAP_MODE:?BOOTSTRAP_MODE is required}"
: "${BOOTSTRAP_RUN_ID:?BOOTSTRAP_RUN_ID is required}"

BOOTSTRAP_DIR="$DOTFILES_ROOT/bootstrap"

is_apply() {
  [[ $BOOTSTRAP_MODE == apply ]]
}

note() {
  printf '  %s\n' "$*"
}

warn() {
  printf '  WARN: %s\n' "$*" >&2
}

die() {
  printf '  ERROR: %s\n' "$*" >&2
  exit 1
}

manifest_lines() {
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1"
}

backup_path() {
  local target="$1"
  printf '%s.bootstrap-%s.bak\n' "$target" "$BOOTSTRAP_RUN_ID"
}

files_equal() {
  local source="$1" target="$2"
  [[ -f $source && -f $target ]] || return 1

  if grep -Iq . "$source" 2>/dev/null; then
    diff -q <(sed "s|/home/sasha|$HOME|g" "$source") "$target" >/dev/null
  else
    cmp -s "$source" "$target"
  fi
}

copy_file() {
  local source="$1" target="$2" backup

  if files_equal "$source" "$target"; then
    note "ok: ${target#$HOME/}"
    return 0
  fi

  if ! is_apply; then
    note "diff: ${target#$HOME/}"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -e $target || -L $target ]]; then
    backup=$(backup_path "$target")
    mv -- "$target" "$backup"
    note "backup: ${backup#$HOME/}"
  fi

  cp -a -- "$source" "$target"

  # Configs occasionally contain the source machine's absolute home. Make the
  # restored copy portable without changing the archived repository version.
  if [[ -f $target && ! -L $target ]] && grep -Iq . "$target" 2>/dev/null; then
    sed -i "s|/home/sasha|$HOME|g" "$target"
  fi
  note "copied: ${target#$HOME/}"
}

copy_tracked_path() {
  local rel="$1" tracked source target backup relative all_equal
  source="$DOTFILES_ROOT/$rel"
  target="$HOME/$rel"

  if [[ -f $source || -L $source ]]; then
    copy_file "$source" "$target"
    return 0
  fi

  [[ -d $source ]] || {
    warn "repository path is missing: $rel"
    return 0
  }

  # A source checkout may currently be linked as a plugin. Leave a compatible
  # link alone, but replace a divergent link as a unit instead of writing into
  # the external checkout through it.
  if [[ -L $target ]]; then
    all_equal=true
    while IFS= read -r -d '' tracked; do
      relative=${tracked#"$rel"/}
      if ! files_equal "$DOTFILES_ROOT/$tracked" "$target/$relative"; then
        all_equal=false
        break
      fi
    done < <(git -C "$DOTFILES_ROOT" ls-files -z -- "$rel")

    if [[ $all_equal == true ]]; then
      note "ok: $rel (compatible link)"
      return 0
    elif is_apply; then
      backup=$(backup_path "$target")
      mv -- "$target" "$backup"
      mkdir -p "$target"
      note "backup: ${backup#$HOME/}"
    fi
  fi

  while IFS= read -r -d '' tracked; do
    source="$DOTFILES_ROOT/$tracked"
    target="$HOME/$tracked"
    copy_file "$source" "$target"
  done < <(git -C "$DOTFILES_ROOT" ls-files -z -- "$rel")
}

read_tsv() {
  local file="$1"
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$file"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

git_origin() {
  git -C "$1" remote get-url origin 2>/dev/null || true
}
