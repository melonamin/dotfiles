#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

export XDG_CONFIG_HOME="$test_dir/config"
export FAKE_BINDINGS="$test_dir/binds.json"
export FAKE_CONFIG_ERRORS="$test_dir/configerrors"
export OMARCHY_LEADER_HYPRCTL="$test_dir/hyprctl"

printf '[]\n' >"$FAKE_BINDINGS"
: >"$FAKE_CONFIG_ERRORS"

cat >"$OMARCHY_LEADER_HYPRCTL" <<'SCRIPT'
#!/bin/bash
case "${1:-}" in
  binds) cat "$FAKE_BINDINGS" ;;
  reload) exit 0 ;;
  configerrors) cat "$FAKE_CONFIG_ERRORS" ;;
  *) exit 1 ;;
esac
SCRIPT
chmod +x "$OMARCHY_LEADER_HYPRCTL"

helper="$repo_dir/scripts/binding-helper"
plugin_id='melonamin.omarchy-leader'

status=$($helper status "$plugin_id")
jq -e '.candidates[] | select(.binding == "SUPER + semicolon" and .available)' <<<"$status" >/dev/null
hash=$(jq -r '.fileHash' <<<"$status")

$helper apply 'SUPER + semicolon' "$hash" "$plugin_id" >/dev/null
bindings_file="$XDG_CONFIG_HOME/hypr/bindings.lua"
[[ $(grep -Fc -- '-- BEGIN melonamin.omarchy-leader managed binding' "$bindings_file") -eq 1 ]]
grep -Fq 'SUPER + semicolon' "$bindings_file"

printf '[{"modmask":64,"key":"SEMICOLON","description":"Leader shortcuts","dispatcher":"__lua","arg":"220"}]\n' >"$FAKE_BINDINGS"
status=$($helper status "$plugin_id")
jq -e '.candidates[] | select(.binding == "SUPER + semicolon" and .available and .description == "Leader shortcuts (current)")' <<<"$status" >/dev/null
hash=$(jq -r '.fileHash' <<<"$status")
$helper apply 'SUPER + semicolon' "$hash" "$plugin_id" >/dev/null
[[ $(grep -Fc -- '-- BEGIN melonamin.omarchy-leader managed binding' "$bindings_file") -eq 1 ]]

status=$($helper status "$plugin_id")
stale_hash=$(jq -r '.fileHash' <<<"$status")
printf '\n-- concurrent user edit\n' >>"$bindings_file"
if $helper apply 'SUPER + apostrophe' "$stale_hash" "$plugin_id" >/dev/null 2>&1; then
  echo 'expected concurrent-edit protection to fail' >&2
  exit 1
fi

status=$($helper status "$plugin_id")
hash=$(jq -r '.fileHash' <<<"$status")
before=$(sha256sum "$bindings_file" | awk '{print $1}')
printf 'fake config error\n' >"$FAKE_CONFIG_ERRORS"
if $helper apply 'SUPER + apostrophe' "$hash" "$plugin_id" >/dev/null 2>&1; then
  echo 'expected config-error rollback to fail' >&2
  exit 1
fi
after=$(sha256sum "$bindings_file" | awk '{print $1}')
[[ $before == "$after" ]]

printf 'binding helper tests passed\n'
