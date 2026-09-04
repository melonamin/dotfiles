#!/bin/bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
scratch=$(mktemp -d /tmp/omarchy-compose-insert.XXXXXX)
trap 'find "$scratch" -depth -delete' EXIT
mkdir -p "$scratch/bin" "$scratch/runtime"

cat > "$scratch/bin/wl-copy" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" > "$WL_COPY_ARGS"
cat > "$WL_COPY_CAPTURE"
printf '%s\n' "$$" > "$WL_COPY_PID"
while true; do sleep 0.05; done
STUB

cat > "$scratch/bin/wtype" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" > "$WTYPE_ARGS"
STUB

chmod +x "$scratch/bin/wl-copy" "$scratch/bin/wtype"
export PATH="$scratch/bin:$PATH"
export XDG_RUNTIME_DIR="$scratch/runtime"
export WL_COPY_ARGS="$scratch/wl-copy.args"
export WL_COPY_CAPTURE="$scratch/copied"
export WL_COPY_PID="$scratch/wl-copy.pid"
export WTYPE_ARGS="$scratch/wtype.args"

started=$(date +%s%N)
result=$(printf '%s' 'Unicode α 🙂' | "$repo/scripts/compose-insert" --insert)
elapsed_ms=$(( ($(date +%s%N) - started) / 1000000 ))

jq -e '.ok and .mode == "insert"' <<< "$result" >/dev/null
[[ $(<"$WL_COPY_CAPTURE") == 'Unicode α 🙂' ]]
grep -F -- '--foreground' "$WL_COPY_ARGS" >/dev/null
! grep -F -- '--paste-once' "$WL_COPY_ARGS" >/dev/null
grep -F -- '-M shift -k Insert -m shift' "$WTYPE_ARGS" >/dev/null
! kill -0 "$(<"$WL_COPY_PID")" 2>/dev/null
(( elapsed_ms >= 300 && elapsed_ms < 2000 ))

printf '%s\n' 'insert tests: ok'
