#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_ROOT="$ROOT"
export BOOTSTRAP_MODE=check
export BOOTSTRAP_RUN_ID="$(date +%Y%m%d%H%M%S)"
source "$ROOT/bootstrap/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./bootstrap/capture.sh --check | --apply

  --check  Compare this workstation with the reproducible manifests.
  --apply  Refresh only the Arch and AUR package manifests after review.
USAGE
}

case "${1:-}" in
  --check) capture_mode=check ;;
  --apply) capture_mode=apply ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
BOOTSTRAP_MODE="$capture_mode"
export BOOTSTRAP_MODE

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat /usr/share/omarchy/install/omarchy-base.packages \
    /usr/share/omarchy/install/omarchy-other.packages |
  sed -E 's/[[:space:]]*#.*$//' | awk 'NF { print $1 }' | sort -u > "$tmp/omarchy-names"

while IFS= read -r package; do
  pacman -Qq "$package" 2>/dev/null || true
done < "$tmp/omarchy-names" | sort -u > "$tmp/omarchy-installed"

pacman -Qqe | sort -u |
  comm -23 - "$tmp/omarchy-installed" |
  comm -23 - <(sort -u "$ROOT/bootstrap/package-excludes.txt") > "$tmp/extra-all"
pacman -Qqm | sort -u > "$tmp/foreign"
comm -12 "$tmp/extra-all" "$tmp/foreign" > "$tmp/aur"
comm -23 "$tmp/extra-all" "$tmp/foreign" > "$tmp/arch"

write_package_manifest() {
  local target="$1" source="$2" description="$3"
  {
    printf '# %s\n' "$description"
    cat "$source"
  } > "$target"
}

compare_manifest() {
  local label="$1" manifest="$2" captured="$3"
  manifest_lines "$manifest" | sort -u > "$tmp/manifest"
  if cmp -s "$tmp/manifest" "$captured"; then
    note "ok: $label package manifest"
  else
    note "drift: $label package manifest"
    comm -13 "$tmp/manifest" "$captured" | sed 's/^/    add:    /'
    comm -23 "$tmp/manifest" "$captured" | sed 's/^/    remove: /'
  fi
}

if [[ $capture_mode == apply ]]; then
  write_package_manifest "$ROOT/bootstrap/packages-arch.txt" "$tmp/arch" \
    "Explicit packages beyond a fresh Omarchy install; versions follow current repositories."
  write_package_manifest "$ROOT/bootstrap/packages-aur.txt" "$tmp/aur" \
    "User-selected AUR packages beyond a fresh Omarchy install."
  note "refreshed: bootstrap/packages-{arch,aur}.txt"
else
  compare_manifest Arch "$ROOT/bootstrap/packages-arch.txt" "$tmp/arch"
  compare_manifest AUR "$ROOT/bootstrap/packages-aur.txt" "$tmp/aur"
fi

while IFS=$'\t' read -r _ id _ _; do
  manifest="$HOME/.config/omarchy/plugins/$id/manifest.json"
  if [[ -f $manifest && $(jq -r '.id // empty' "$manifest") == "$id" ]]; then
    :
  else
    warn "plugin not present on source workstation: $id"
  fi
done < <(read_tsv "$ROOT/bootstrap/plugins.tsv")
note "checked: plugin inventory"

while IFS=$'\t' read -r _ name _; do
  [[ -d $HOME/.config/omarchy/themes/$name ]] || warn "theme not present on source workstation: $name"
done < <(read_tsv "$ROOT/bootstrap/themes.tsv")
note "checked: theme inventory"

actual_theme=$(omarchy theme current 2>/dev/null || true)
expected_theme=$(awk -F '\t' '$1 == "theme" { print $2 }' "$ROOT/bootstrap/defaults.tsv")
if [[ $actual_theme == "$expected_theme" ]]; then
  note "ok: active theme $actual_theme"
else
  warn "active theme is '$actual_theme', manifest expects '$expected_theme'"
fi

status=$(git -C "$ROOT" status --short --untracked-files=all)
if [[ -n $status ]]; then
  note "repository has uncommitted changes; review them before capture/commit"
  sed 's/^/    /' <<<"$status"
else
  note "ok: repository clean"
fi
