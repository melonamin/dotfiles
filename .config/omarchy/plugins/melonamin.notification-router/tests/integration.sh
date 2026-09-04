#!/usr/bin/env bash
# End-to-end check against a running install: the service is attached to the
# notification daemon, a silenced notification never maps a Wayland surface,
# an unmatched one still does, dots accumulate, and silenced notifications
# still land in omarchy's history.
#
# Borrows the user's rules file for the duration and puts it back on exit.
# Sends a handful of notifications; changes no settings.
#
# Usage: tests/integration.sh
set -euo pipefail

fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$1"; exit 1; }
pass() { printf '\033[1;32mok\033[0m   %s\n' "$1"; }
skip() { printf '\033[1;33mskip\033[0m %s\n' "$1"; }

command -v omarchy-shell >/dev/null || fail "omarchy-shell not found"
command -v hyprctl >/dev/null || fail "hyprctl not found"
command -v notify-send >/dev/null || fail "notify-send not found"
command -v socat >/dev/null || fail "socat not found"

RULES_DIR="$HOME/.config/omarchy/notification-router"
RULES="$RULES_DIR/rules.json"
BACKUP="$(mktemp)"
EVENTS="$(mktemp)"
LISTENER=""

cleanup() {
  [[ -n $LISTENER ]] && kill "$LISTENER" 2>/dev/null || true
  if [[ -s $BACKUP ]]; then cp "$BACKUP" "$RULES"; else rm -f "$RULES"; fi
  rm -f "$BACKUP" "$EVENTS"
  omarchy-shell notification-router clear >/dev/null 2>&1 || true
  omarchy-shell notifications dismissAll >/dev/null 2>&1 || true
}
trap cleanup EXIT

status() { omarchy-shell notification-router status 2>/dev/null; }
field() { status | python3 -c "import sys,json;print(json.load(sys.stdin)$1)"; }
dots() { omarchy-shell notification-router pending 2>/dev/null | python3 -c "import sys,json;print(len(json.load(sys.stdin)))"; }

# --- service ----------------------------------------------------------------

[[ -n $(status) ]] || fail "the router service is not answering (is the plugin enabled?)"
pass "service responds"

[[ $(field "['attached']") == True ]] || fail "the router did not attach to omarchy.notifications"
pass "attached to the notification service"

# --- install a known ruleset ------------------------------------------------

mkdir -p "$RULES_DIR"
[[ -f $RULES ]] && cp "$RULES" "$BACKUP"
cat > "$RULES" <<'JSON'
{
  "rules": [
    { "name": "e2e silence", "match": { "summary": "/^E2E-SILENCE/" },
      "then": [ { "silence": true } ] },
    { "name": "e2e dot", "match": { "summary": "/^E2E-DOT/" },
      "then": [ { "silence": true }, { "dot": "#e5c07b" } ] }
  ]
}
JSON
sleep 2
[[ $(field "['rules']") == 2 ]] || fail "test rules did not load (got $(field "['rules']"))"
[[ $(field "['errors']") == "[]" ]] || fail "test rules reported errors: $(field "['errors']")"
pass "rules hot-reloaded from disk"

# --- dry-run verdict --------------------------------------------------------

verdict=$(omarchy-shell notification-router explain "any" "E2E-SILENCE hypothetical" "body" 2>/dev/null)
echo "$verdict" | python3 -c "
import sys,json
v=json.load(sys.stdin)
assert v['silence'] is True, v
assert v['matched']==['e2e silence'], v
" || fail "explain returned the wrong verdict: $verdict"
pass "explain reports what a rule would do"

# --- compositor-level proof -------------------------------------------------

if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hypr_dir=$(find "${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)
  [[ -n $hypr_dir ]] && export HYPRLAND_INSTANCE_SIGNATURE=${hypr_dir##*/}
fi
SOCK="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
[[ -S $SOCK ]] || fail "cannot reach the Hyprland event socket at $SOCK"

# Start from a closed notification layer, or a toast left over from before
# would keep the surface mapped and mask a silencing failure.
omarchy-shell notifications dismissAll >/dev/null 2>&1
omarchy-shell notification-router clear >/dev/null 2>&1
sleep 2

socat -U - "UNIX-CONNECT:$SOCK" 2>/dev/null | grep --line-buffered "layer" > "$EVENTS" &
LISTENER=$!
sleep 1

for i in 1 2 3; do notify-send "E2E-SILENCE $i" "must never be shown"; sleep 0.3; done
sleep 2
opened=$(grep -c "openlayer>>omarchy-notifications" "$EVENTS" || true)
[[ $opened -eq 0 ]] || fail "a silenced notification mapped the notification layer $opened time(s)"
pass "silenced notifications never map a surface"

[[ $(dots) -eq 0 ]] || fail "a silence-only rule should leave no dot"
pass "a silence-only rule leaves no dot"

for i in 1 2; do notify-send "E2E-DOT $i" "silenced but dotted"; sleep 0.3; done
sleep 2
opened=$(grep -c "openlayer>>omarchy-notifications" "$EVENTS" || true)
[[ $opened -eq 0 ]] || fail "a dot rule with silence still showed a toast"
[[ $(dots) -eq 2 ]] || fail "expected 2 dots, got $(dots)"
pass "dot rules record a dot without showing a toast"

notify-send "E2E-PASSTHROUGH" "no rule matches this"
sleep 2
opened=$(grep -c "openlayer>>omarchy-notifications" "$EVENTS" || true)
[[ $opened -ge 1 ]] || fail "an unmatched notification did not reach the screen — the router is over-matching"
pass "unmatched notifications still reach the screen"

kill "$LISTENER" 2>/dev/null || true
LISTENER=""

# --- silenced is not lost ---------------------------------------------------

HISTORY="$HOME/.local/state/omarchy/notifications/history"
if [[ -d $HISTORY ]]; then
  found=$(grep -l "E2E-SILENCE" "$HISTORY"/*.json 2>/dev/null | wc -l)
  [[ $found -ge 1 ]] || fail "silenced notifications did not reach omarchy's history"
  pass "silenced notifications are still recorded in history"
else
  skip "history directory not present"
fi

# --- rules that fail to compile ---------------------------------------------

cat > "$RULES" <<'JSON'
{ "rules": [
  { "name": "broken", "match": { "app": "/([unclosed/" }, "then": [ { "silence": true } ] }
] }
JSON
sleep 2
[[ $(field "['rules']") == 0 ]] || fail "a rule with a broken regex was loaded anyway"
[[ $(field "['errors']") != "[]" ]] || fail "a broken rule was dropped without reporting why"
pass "a broken regex is dropped and reported, never widened"

notify-send "E2E-UNAFFECTED" "must still be shown while rules are broken"
sleep 1
[[ $(omarchy-shell notification-router ping) == "ok" ]] || fail "the service died on a broken rules file"
pass "the service survives an unparseable rules file"

printf '\n\033[1;32mAll integration checks passed.\033[0m\n'
