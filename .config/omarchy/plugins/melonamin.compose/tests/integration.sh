#!/bin/bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

if [[ ${1:-} == "--check" ]]; then
  for command in jq git omarchy omarchy-shell hyprctl wl-copy wtype systemctl sha256sum foot zenity; do command -v "$command" >/dev/null || { echo "missing prerequisite: $command" >&2; exit 1; }; done
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { echo "Hyprland session is unavailable" >&2; exit 1; }
  omarchy-shell shell ping >/dev/null
  hyprctl -i 0 version >/dev/null
  systemctl --user is-active --quiet omarchy-fcitx5.service
  echo "integration prerequisites: ok"
  exit 0
fi

cat <<'HELP'
Live integration is intentionally explicit because it temporarily replaces the
real user Compose file and installs the plugin into the running Omarchy shell.
Run it with:

  tests/integration.sh --live

The original file and shell plugin setting are restored by traps.
HELP

[[ ${1:-} == "--live" ]] || exit 2

for command in jq git omarchy omarchy-shell hyprctl wl-copy wtype systemctl sha256sum foot zenity; do command -v "$command" >/dev/null || { echo "missing prerequisite: $command" >&2; exit 1; }; done
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { echo "Hyprland session is unavailable" >&2; exit 1; }
omarchy-shell shell ping >/dev/null
hyprctl -i 0 version >/dev/null
systemctl --user is-active --quiet omarchy-fcitx5.service

scratch=$(mktemp -d /tmp/omarchy-compose-integration.XXXXXX)
compose_target=${XCOMPOSEFILE:-$HOME/.XCompose}
plugin_target="$HOME/.config/omarchy/plugins/melonamin.compose"
shell_config="$HOME/.config/omarchy/shell.json"
before_compose="$scratch/XCompose.before"
before_shell="$scratch/shell.before.json"
had_compose=false
had_plugin=false
before_compose_mode=""
before_plugin_link=""
terminal_pid=""
gui_pid=""

[[ -e $compose_target || -L $compose_target ]] && { had_compose=true; before_compose_mode=$(stat -Lc '%a' -- "$compose_target"); cp -a --dereference -- "$compose_target" "$before_compose"; }
cp -- "$shell_config" "$before_shell"
if [[ -e $plugin_target || -L $plugin_target ]]; then
  had_plugin=true
  [[ -L $plugin_target && $(readlink -f -- "$plugin_target") == "$repo" ]] || {
    echo "melonamin.compose is installed from another source; refusing to replace it" >&2
    exit 1
  }
  before_plugin_link=$(readlink -- "$plugin_target")
fi

restore() {
  set +e
  [[ -z $terminal_pid ]] || kill "$terminal_pid" >/dev/null 2>&1
  [[ -z $gui_pid ]] || kill "$gui_pid" >/dev/null 2>&1
  omarchy-shell compose close >/dev/null 2>&1
  if [[ $had_plugin == false && ( -e $plugin_target || -L $plugin_target ) ]]; then
    remove_plugin >/dev/null 2>&1
  elif [[ $had_plugin == true ]]; then
    current_plugin=""
    [[ ! -L $plugin_target ]] || current_plugin=$(readlink -f -- "$plugin_target")
    if [[ $current_plugin != "$repo" ]]; then
      if [[ -e $plugin_target || -L $plugin_target ]]; then remove_plugin >/dev/null 2>&1; fi
      [[ ! -e $plugin_target && ! -L $plugin_target ]] || unlink "$plugin_target"
      ln -s -- "$before_plugin_link" "$plugin_target"
    fi
  fi
  cp -- "$before_shell" "$shell_config"
  omarchy-shell shell reloadConfig >/dev/null 2>&1
  omarchy-shell shell rescanPlugins >/dev/null 2>&1
  if [[ $had_compose == true ]]; then
    temp_restore=$(mktemp --tmpdir="$(dirname -- "$compose_target")" .compose-integration-restore.XXXXXX)
    cp -- "$before_compose" "$temp_restore"
    chmod "$before_compose_mode" -- "$temp_restore"
    if [[ -L $compose_target ]]; then mv -fT -- "$temp_restore" "$(readlink -f -- "$compose_target")"
    else mv -fT -- "$temp_restore" "$compose_target"
    fi
  elif [[ -e $compose_target && ! -L $compose_target ]]; then unlink "$compose_target"
  fi
  omarchy restart xcompose >/dev/null 2>&1
  find "$scratch" -depth -delete
}
trap restore EXIT INT TERM

wait_for_status() {
  local filter=$1 status
  for _ in {1..100}; do
    if status=$(omarchy-shell compose status 2>/dev/null) && jq -e "$filter" <<< "$status" >/dev/null; then return 0; fi
    sleep 0.1
  done
  echo "Compose status did not reach: $filter" >&2
  return 1
}

remove_plugin() {
  for _ in {1..50}; do
    if omarchy plugin remove melonamin.compose --yes >/dev/null 2>&1; then return 0; fi
    if [[ ! -e $plugin_target && ! -L $plugin_target ]]; then
      for _ in {1..50}; do
        if omarchy-shell shell ping >/dev/null 2>&1; then omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true; return 0; fi
        sleep 0.1
      done
    fi
    sleep 0.1
  done
  echo "could not remove melonamin.compose" >&2
  return 1
}

if [[ $had_plugin == true ]]; then remove_plugin; fi

# Clone a committed snapshot of the current worktree through the same git path
# used by a real plugin install; this includes uncommitted implementation work.
snapshot="$scratch/plugin-source"
mkdir -p "$snapshot"
git -C "$repo" ls-files --cached --others --exclude-standard -z | while IFS= read -r -d '' path; do
  mkdir -p "$snapshot/$(dirname -- "$path")"
  cp -- "$repo/$path" "$snapshot/$path"
done
git -C "$snapshot" init -q
git -C "$snapshot" add .
git -C "$snapshot" -c user.name=Integration -c user.email=integration@example.invalid commit -qm snapshot

omarchy plugin add "file://$snapshot" --enable --yes >/dev/null
wait_for_status '.open == false and .requestedShortcut == "SUPER + CTRL + SEMICOLON"'

cat > "$scratch/XCompose.test" <<'COMPOSE'
include "%L"

# Omarchy Compose integration fixture
<Multi_key> <space> <t> : "compose-e2e-token" # integration token
COMPOSE
temp_target=$(mktemp --tmpdir="$(dirname -- "$compose_target")" .compose-integration.XXXXXX)
cp -- "$scratch/XCompose.test" "$temp_target"
if [[ -L $compose_target ]]; then mv -fT -- "$temp_target" "$(readlink -f -- "$compose_target")"
else mv -fT -- "$temp_target" "$compose_target"
fi
omarchy restart xcompose >/dev/null
systemctl --user is-active --quiet omarchy-fcitx5.service

omarchy-shell compose quick >/dev/null
wait_for_status '.open and .mode == "quick"'
omarchy-shell compose manage >/dev/null
wait_for_status '.open and .mode == "studio" and .ruleCount > 0 and .sourceCount > 0'

hyprctl -i 0 binds | grep -F 'Compose: Quick picker' >/dev/null
omarchy-shell compose close >/dev/null
sleep 0.2

# Exercise transaction apply and Undo against the real target with full restore.
helper="$plugin_target/scripts/compose-file"
revision=$($helper --file "$compose_target" revision | jq -r '.revision')
printf '%s\n' '<Multi_key> <space> <u> : "undo-token"' | "$helper" --file "$compose_target" apply "$revision" >/dev/null
grep -F 'undo-token' "$compose_target" >/dev/null
revision=$($helper --file "$compose_target" revision | jq -r '.revision')
"$helper" --file "$compose_target" undo "$revision" >/dev/null
cmp -s "$compose_target" "$scratch/XCompose.test"

# Prove that the standard-input insertion path reaches both a terminal PTY and
# an ordinary GUI text field. The helper never receives either token in argv.
insert_helper="$plugin_target/scripts/compose-insert"
terminal_capture="$scratch/terminal-insert.txt"
COMPOSE_CAPTURE_FILE="$terminal_capture" foot \
  --app-id omarchy-compose-integration-terminal \
  --title "Compose terminal integration" \
  bash -c 'IFS= read -r value; printf "%s" "$value" > "$COMPOSE_CAPTURE_FILE"' &
terminal_pid=$!
for _ in {1..50}; do
  hyprctl -i 0 clients -j | jq -e 'any(.[]; .class == "omarchy-compose-integration-terminal")' >/dev/null && break
  sleep 0.1
done
hyprctl -i 0 dispatch 'hl.dsp.focus({ window = "class:^(omarchy-compose-integration-terminal)$" })' >/dev/null
printf '%s' 'compose-terminal-token' | "$insert_helper" --insert >/dev/null
hyprctl -i 0 dispatch 'hl.dsp.focus({ window = "class:^(omarchy-compose-integration-terminal)$" })' >/dev/null
wtype -k Return
for _ in {1..50}; do [[ -e $terminal_capture ]] && break; sleep 0.1; done
[[ -e $terminal_capture ]] || { echo "terminal insertion target did not submit" >&2; exit 1; }
wait "$terminal_pid"
terminal_pid=""
[[ $(<"$terminal_capture") == 'compose-terminal-token' ]]

gui_capture="$scratch/gui-insert.txt"
zenity --entry --title "Compose insertion integration" --text "Compose insertion target" > "$gui_capture" &
gui_pid=$!
for _ in {1..50}; do
  hyprctl -i 0 clients -j | jq -e 'any(.[]; .title == "Compose insertion integration")' >/dev/null && break
  sleep 0.1
done
hyprctl -i 0 dispatch 'hl.dsp.focus({ window = "title:^(Compose insertion integration)$" })' >/dev/null
printf '%s' 'compose-gui-token' | "$insert_helper" --insert >/dev/null
hyprctl -i 0 dispatch 'hl.dsp.focus({ window = "title:^(Compose insertion integration)$" })' >/dev/null
wtype -k Return
for _ in {1..50}; do ! kill -0 "$gui_pid" 2>/dev/null && break; sleep 0.1; done
! kill -0 "$gui_pid" 2>/dev/null || { echo "GUI insertion target did not submit" >&2; exit 1; }
wait "$gui_pid"
gui_pid=""
[[ $(<"$gui_capture") == 'compose-gui-token' ]]

# Removal must unregister the runtime bind and never touch Hyprland config.
hypr_before=$(sha256sum "$HOME/.config/hypr/hyprland.lua" | awk '{print $1}')
remove_plugin
for _ in {1..50}; do
  if ! hyprctl -i 0 binds | grep -F 'Compose: Quick picker' >/dev/null; then break; fi
  sleep 0.1
done
! hyprctl -i 0 binds | grep -F 'Compose: Quick picker' >/dev/null
hypr_after=$(sha256sum "$HOME/.config/hypr/hyprland.lua" | awk '{print $1}')
[[ $hypr_before == "$hypr_after" ]]

# Reinstall once through the documented lifecycle and leave cleanup to trap.
omarchy plugin add "file://$snapshot" --enable --yes >/dev/null
wait_for_status '.open == false'
omarchy-shell compose quick >/dev/null
wait_for_status '.open and .mode == "quick"'

echo "live integration tests: ok"
