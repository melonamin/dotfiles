#!/usr/bin/env bash
# Symlink tracked dotfiles from this repo into $HOME.
# Idempotent: rerun any time. Existing regular files are moved to
# <path>.bak before the symlink is created; existing correct symlinks are
# left alone.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Manifest of tracked paths, relative to both $REPO and $HOME.
# Add new paths as you decide to track them.
PATHS=(
    .aliases
    .local/agent-wrappers
    # TODO(sasha): decide which of the following you want live-linked vs
    # kept as archive-only in the repo (see install.sh conversation).
    # .exports
    # .path
    # .gitconfig
    # .vscode-extensions.sh
    # .mackup.cfg
)

link_path() {
    local rel="$1"
    local src="$REPO/$rel"
    local dst="$HOME/$rel"

    if [[ ! -e "$src" ]]; then
        echo "skip: $rel (missing in repo)" >&2
        return 0
    fi

    # Already the correct symlink — nothing to do.
    if [[ -L "$dst" && "$(readlink -- "$dst")" == "$src" ]]; then
        echo "ok:   $rel"
        return 0
    fi

    mkdir -p "$(dirname -- "$dst")"

    # Something else lives there — back it up, refusing to clobber a prior backup.
    if [[ -e "$dst" || -L "$dst" ]]; then
        if [[ -e "$dst.bak" || -L "$dst.bak" ]]; then
            echo "FAIL: $rel — $dst exists and $dst.bak already taken; resolve manually" >&2
            return 1
        fi
        mv -- "$dst" "$dst.bak"
        echo "back: $rel -> $rel.bak"
    fi

    ln -s -- "$src" "$dst"
    echo "link: $rel"
}

for p in "${PATHS[@]}"; do
    link_path "$p"
done
