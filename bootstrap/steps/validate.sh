#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

problems=0

problem() {
  warn "$*"
  problems=$((problems + 1))
}

for manifest in packages-arch.txt packages-aur.txt; do
  while IFS= read -r package; do
    pacman -Q "$package" >/dev/null 2>&1 || problem "package missing: $package"
  done < <(manifest_lines "$BOOTSTRAP_DIR/$manifest")
done

for command in agterm-linux agtermctl fish mise rustup; do
  command -v "$command" >/dev/null 2>&1 || problem "command missing: $command"
done

while IFS= read -r crate; do
  binary="$crate"
  [[ $crate == flowscope-cli ]] && binary=flowscope
  command -v "$binary" >/dev/null 2>&1 || problem "cargo tool missing: $crate"
done < <(manifest_lines "$BOOTSTRAP_DIR/cargo-tools.txt")

while IFS=$'\t' read -r name _; do
  [[ -f $HOME/.local/share/applications/$name.desktop ]] || problem "web app missing: $name"
done < <(read_tsv "$BOOTSTRAP_DIR/webapps.tsv")

while IFS=$'\t' read -r mode _ rel _; do
  [[ $mode != clone ]] || [[ -d $HOME/$rel/.git ]] || problem "repository missing: $rel"
done < <(read_tsv "$BOOTSTRAP_DIR/repositories.tsv")

while IFS=$'\t' read -r _ id _ _; do
  target="$HOME/.config/omarchy/plugins/$id"
  if [[ ! -f $target/manifest.json ]]; then
    problem "plugin missing: $id"
  elif ! omarchy plugin validate "$(readlink -f "$target")" >/dev/null 2>&1; then
    problem "plugin validation failed: $id"
  fi
done < <(read_tsv "$BOOTSTRAP_DIR/plugins.tsv")

while IFS=$'\t' read -r _ name _; do
  [[ -d $HOME/.config/omarchy/themes/$name ]] || problem "theme missing: $name"
done < <(read_tsv "$BOOTSTRAP_DIR/themes.tsv")

jq empty "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1 || problem "shell.json is invalid"
cmp -s "$DOTFILES_ROOT/.config/keyd/system-default.conf" /etc/keyd/default.conf 2>/dev/null || problem "keyd default.conf differs"
cmp -s "$DOTFILES_ROOT/.config/keyd/app.conf" /etc/keyd/app.conf 2>/dev/null || problem "keyd app.conf differs"
systemctl is-enabled keyd.service >/dev/null 2>&1 || problem "keyd.service is disabled"

declare -A expected
while IFS=$'\t' read -r key value; do expected["$key"]="$value"; done \
  < <(read_tsv "$BOOTSTRAP_DIR/defaults.tsv")

[[ $(omarchy theme current 2>/dev/null || true) == "${expected[theme]}" ]] || problem "active theme differs"
[[ $(omarchy font current 2>/dev/null || true) == "${expected[font]}" ]] || problem "active font differs"
[[ $(omarchy default terminal 2>/dev/null || true) == "${expected[terminal]}" ]] || problem "default terminal differs"
[[ $(omarchy default browser 2>/dev/null || true) == "${expected[browser]}" ]] || problem "default browser differs"
[[ $(omarchy default editor 2>/dev/null || true) == "${expected[editor]}" ]] || problem "default editor differs"
[[ $(omarchy default agent 2>/dev/null || true) == "${expected[agent]}" ]] || problem "default agent differs"
[[ $(getent passwd "$USER" | cut -d: -f7) == "${expected[shell]}" ]] || problem "login shell differs"
current_background=$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)
[[ ${current_background##*/} == ${expected[background]##*/} ]] || problem "active background differs"

if (( problems == 0 )); then
  note "all reproducible workstation checks passed"
elif is_apply; then
  die "$problems validation check(s) failed"
else
  note "$problems difference(s) found; --check made no changes"
fi
