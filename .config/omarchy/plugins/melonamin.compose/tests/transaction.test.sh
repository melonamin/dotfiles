#!/bin/bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$repo/scripts/compose-file"
scratch=$(mktemp -d /tmp/omarchy-compose-transactions.XXXXXX)
trap 'find "$scratch" -depth -delete' EXIT

mkdir -p "$scratch/bin" "$scratch/home" "$scratch/state"

cat > "$scratch/bin/omarchy" <<'STUB'
#!/bin/bash
if [[ -n ${OMARCHY_FAIL_ONCE:-} && -e ${OMARCHY_FAIL_ONCE:-} ]]; then
  [[ -z ${OMARCHY_FAIL_DELAY:-} ]] || sleep "$OMARCHY_FAIL_DELAY"
  unlink "$OMARCHY_FAIL_ONCE"
  exit 1
fi
[[ -z ${OMARCHY_SUCCESS_DELAY:-} ]] || sleep "$OMARCHY_SUCCESS_DELAY"
exit 0
STUB

cat > "$scratch/bin/systemctl" <<'STUB'
#!/bin/bash
[[ ! -e ${SYSTEMCTL_FAIL_FILE:-/nonexistent} ]]
STUB

chmod +x "$scratch/bin/omarchy" "$scratch/bin/systemctl"
export PATH="$scratch/bin:$PATH"
export HOME="$scratch/home"
export XDG_STATE_HOME="$scratch/state"

revision() {
  "$helper" --file "$1" revision | jq -er '.revision'
}

apply_text() {
  local target=$1 expected=$2 content=$3
  printf '%s' "$content" | "$helper" --file "$target" apply "$expected"
}

assert_eq() {
  [[ $1 == "$2" ]] || { printf 'expected <%s>, got <%s>\n' "$2" "$1" >&2; exit 1; }
}

# Creation uses a guarded atomic write and restrictive mode.
target="$scratch/home/new.compose"
initial=$("$helper" --file "$target" revision)
jq -e '.ok and (.exists | not) and (.digest == "missing") and (.symlink | not)' <<< "$initial" >/dev/null
rev=$(jq -r '.revision' <<< "$initial")
created=$(apply_text "$target" "$rev" $'<Multi_key> <a> : "α"\n')
jq -e '.ok and .activated and .fcitx5Healthy' <<< "$created" >/dev/null
assert_eq "$(<"$target")" '<Multi_key> <a> : "α"'
assert_eq "$(stat -c '%a' "$target")" '600'
[[ -z $(find "$(dirname "$target")" -maxdepth 1 -name '.omarchy-compose.*' -print -quit) ]]

# Existing permissions survive, and stale revisions never write.
chmod 640 "$target"
rev=$(revision "$target")
apply_text "$target" "$rev" $'<Multi_key> <b> : "β"\n' >/dev/null
assert_eq "$(stat -c '%a' "$target")" '640'

# Atomic replacement depends on the parent directory, not the target inode.
chmod 400 "$target"
jq -e '.writable' <<< "$("$helper" --file "$target" revision)" >/dev/null
chmod 600 "$target"
chmod 500 "$(dirname "$target")"
jq -e '.writable == false' <<< "$("$helper" --file "$target" revision)" >/dev/null
chmod 700 "$(dirname "$target")"
chmod 640 "$target"
set +e
stale=$(apply_text "$target" "$rev" 'stale' 2>/dev/null)
stale_code=$?
set -e
assert_eq "$stale_code" '3'
jq -e '.ok == false and .error == "stale revision"' <<< "$stale" >/dev/null
assert_eq "$(<"$target")" '<Multi_key> <b> : "β"'

# A file edit while apply is still reading stdin is caught before rename.
rev=$(revision "$target")
set +e
({ sleep 0.2; printf '%s' 'late candidate'; } | "$helper" --file "$target" apply "$rev" > "$scratch/race-result") &
race_pid=$!
sleep 0.05
printf '%s' 'external edit' > "$target"
wait "$race_pid"
race_code=$?
set -e
assert_eq "$race_code" '3'
jq -e '.error == "stale revision"' < "$scratch/race-result" >/dev/null
assert_eq "$(<"$target")" 'external edit'

# Two writers starting from the same revision cannot both replace the target.
rev=$(revision "$target")
export OMARCHY_SUCCESS_DELAY=0.2
set +e
(apply_text "$target" "$rev" 'first concurrent candidate' > "$scratch/first-writer-result") &
first_writer_pid=$!
(apply_text "$target" "$rev" 'second concurrent candidate' > "$scratch/second-writer-result") &
second_writer_pid=$!
wait "$first_writer_pid"
first_writer_code=$?
wait "$second_writer_pid"
second_writer_code=$?
set -e
unset OMARCHY_SUCCESS_DELAY
if [[ $first_writer_code == 0 ]]; then
  assert_eq "$second_writer_code" '3'
  assert_eq "$(<"$target")" 'first concurrent candidate'
  jq -e '.ok' < "$scratch/first-writer-result" >/dev/null
  jq -e '.error == "stale revision"' < "$scratch/second-writer-result" >/dev/null
else
  assert_eq "$first_writer_code" '3'
  assert_eq "$second_writer_code" '0'
  assert_eq "$(<"$target")" 'second concurrent candidate'
  jq -e '.error == "stale revision"' < "$scratch/first-writer-result" >/dev/null
  jq -e '.ok' < "$scratch/second-writer-result" >/dev/null
fi

# Undo restores the saved permissions for the exact result it is reversing.
mode_target="$scratch/home/mode.compose"
printf '%s' 'mode before' > "$mode_target"
chmod 640 "$mode_target"
rev=$(revision "$mode_target")
apply_text "$mode_target" "$rev" 'mode after' >/dev/null
rev=$(revision "$mode_target")
"$helper" --file "$mode_target" undo "$rev" >/dev/null
assert_eq "$(<"$mode_target")" 'mode before'
assert_eq "$(stat -c '%a' "$mode_target")" '640'

# Reloading an external edit does not make an unrelated backup eligible for Undo.
undo_guard_target="$scratch/home/undo-guard.compose"
printf '%s' 'before guarded save' > "$undo_guard_target"
rev=$(revision "$undo_guard_target")
apply_text "$undo_guard_target" "$rev" 'saved result' >/dev/null
printf '%s' 'external edit after reload' > "$undo_guard_target"
rev=$(revision "$undo_guard_target")
set +e
undo_guard_result=$("$helper" --file "$undo_guard_target" undo "$rev")
undo_guard_code=$?
set -e
assert_eq "$undo_guard_code" '5'
jq -e '.ok == false and (.error | contains("does not match an undoable saved result"))' <<< "$undo_guard_result" >/dev/null
assert_eq "$(<"$undo_guard_target")" 'external edit after reload'

# Backups are bounded even across repeated successful writes.
for index in {1..12}; do
  rev=$(revision "$target")
  apply_text "$target" "$rev" "<Multi_key> <$index> : \"$index\""$'\n' >/dev/null
done
target_key=$(printf '%s' "$target" | sha256sum | awk '{print $1}')
backup_root="$scratch/state/omarchy-compose/backups/$target_key"
assert_eq "$(find "$backup_root" -maxdepth 1 -name '*.meta' | wc -l)" '10'

# Activation failure retains the candidate and restores the previous bytes.
before=$(<"$target")
backups_before_failure=$(find "$backup_root" -maxdepth 1 -name '*.meta' | wc -l)
touch "$scratch/fail-once"
export OMARCHY_FAIL_ONCE="$scratch/fail-once"
rev=$(revision "$target")
set +e
failed=$(apply_text "$target" "$rev" $'<Multi_key> <f> : "failed"\n')
failed_code=$?
set -e
unset OMARCHY_FAIL_ONCE
assert_eq "$failed_code" '4'
jq -e '.ok == false and .rolledBack and .fcitx5Healthy' <<< "$failed" >/dev/null
assert_eq "$(<"$target")" "$before"
rejected=$(jq -r '.rejectedCandidate' <<< "$failed")
[[ -f $rejected ]]
assert_eq "$(<"$rejected")" '<Multi_key> <f> : "failed"'
assert_eq "$(find "$backup_root" -maxdepth 1 -name '*.meta' | wc -l)" "$backups_before_failure"

# A rolled-back apply is not a no-op Undo entry, and consumed backups vanish.
rev=$(revision "$target")
"$helper" --file "$target" undo "$rev" >/dev/null
[[ $(<"$target") != "$before" ]]
[[ -z $(find "$backup_root" -maxdepth 1 -name '*.used' -print -quit) ]]
assert_eq "$(find "$backup_root" -maxdepth 1 -name '*.compose' | wc -l)" "$(find "$backup_root" -maxdepth 1 -name '*.meta' | wc -l)"

# Activation rollback never overwrites an edit made after the candidate rename.
concurrent_target="$scratch/home/concurrent.compose"
printf '%s' 'before concurrent apply' > "$concurrent_target"
touch "$scratch/fail-concurrent"
export OMARCHY_FAIL_ONCE="$scratch/fail-concurrent"
export OMARCHY_FAIL_DELAY=0.5
rev=$(revision "$concurrent_target")
set +e
(apply_text "$concurrent_target" "$rev" 'candidate awaiting activation' > "$scratch/concurrent-result") &
concurrent_pid=$!
observed_candidate=false
for _ in {1..500}; do
  if [[ $(<"$concurrent_target") == 'candidate awaiting activation' ]]; then observed_candidate=true; break; fi
  sleep 0.01
done
[[ $observed_candidate == true ]]
printf '%s' 'external edit during activation' > "$concurrent_target"
wait "$concurrent_pid"
concurrent_code=$?
set -e
unset OMARCHY_FAIL_ONCE OMARCHY_FAIL_DELAY
assert_eq "$concurrent_code" '7'
jq -e '.concurrentChange and (.rolledBack | not)' < "$scratch/concurrent-result" >/dev/null
assert_eq "$(<"$concurrent_target")" 'external edit during activation'

# A successful activation still rejects a target changed before it completes.
success_race_target="$scratch/home/success-race.compose"
printf '%s' 'before success race' > "$success_race_target"
export OMARCHY_SUCCESS_DELAY=0.5
rev=$(revision "$success_race_target")
set +e
(apply_text "$success_race_target" "$rev" 'candidate during successful activation' > "$scratch/success-race-result") &
success_race_pid=$!
observed_candidate=false
for _ in {1..500}; do
  if [[ $(<"$success_race_target") == 'candidate during successful activation' ]]; then observed_candidate=true; break; fi
  sleep 0.01
done
[[ $observed_candidate == true ]]
printf '%s' 'external edit during successful activation' > "$success_race_target"
wait "$success_race_pid"
success_race_code=$?
set -e
unset OMARCHY_SUCCESS_DELAY
assert_eq "$success_race_code" '7'
jq -e '.concurrentChange and (.rolledBack | not) and .fcitx5Healthy' < "$scratch/success-race-result" >/dev/null
assert_eq "$(<"$success_race_target")" 'external edit during successful activation'

# Missing-file Undo also retains its backup when a file appears during activation.
missing_undo_target="$scratch/home/missing-undo-race.compose"
rev=$(revision "$missing_undo_target")
apply_text "$missing_undo_target" "$rev" 'created for missing undo race' >/dev/null
rev=$(revision "$missing_undo_target")
export OMARCHY_SUCCESS_DELAY=0.5
set +e
("$helper" --file "$missing_undo_target" undo "$rev" > "$scratch/missing-undo-race-result") &
missing_undo_pid=$!
observed_missing=false
for _ in {1..500}; do
  if [[ ! -e $missing_undo_target ]]; then observed_missing=true; break; fi
  sleep 0.01
done
[[ $observed_missing == true ]]
printf '%s' 'external file during successful undo activation' > "$missing_undo_target"
wait "$missing_undo_pid"
missing_undo_code=$?
set -e
unset OMARCHY_SUCCESS_DELAY
assert_eq "$missing_undo_code" '7'
jq -e '.operation == "undo" and .concurrentChange and (.rolledBack | not) and .fcitx5Healthy' < "$scratch/missing-undo-race-result" >/dev/null
assert_eq "$(<"$missing_undo_target")" 'external file during successful undo activation'

# If a missing-file Undo cannot restore after activation fails, its snapshot is retained.
rollback_failure_target="$scratch/home/missing-undo-rollback-failure.compose"
rev=$(revision "$rollback_failure_target")
apply_text "$rollback_failure_target" "$rev" 'created before failed missing undo' >/dev/null
rev=$(revision "$rollback_failure_target")
mkdir -p "$scratch/rollback-fail-bin"
cat > "$scratch/rollback-fail-bin/mv" <<'STUB'
#!/bin/bash
if [[ $* == *'.omarchy-compose.rollback.'* ]]; then exit 9; fi
exec /usr/bin/mv "$@"
STUB
chmod +x "$scratch/rollback-fail-bin/mv"
touch "$scratch/fail-missing-undo-rollback"
export OMARCHY_FAIL_ONCE="$scratch/fail-missing-undo-rollback"
set +e
rollback_failure=$(PATH="$scratch/rollback-fail-bin:$PATH" "$helper" --file "$rollback_failure_target" undo "$rev")
rollback_failure_code=$?
set -e
unset OMARCHY_FAIL_ONCE
assert_eq "$rollback_failure_code" '7'
jq -e '.operation == "undo" and (.rolledBack | not) and .recoveryRetained' <<< "$rollback_failure" >/dev/null
recovery_snapshot=$(jq -r '.recoverySnapshot' <<< "$rollback_failure")
[[ -f $recovery_snapshot ]]
assert_eq "$(<"$recovery_snapshot")" 'created before failed missing undo'
[[ ! -e $rollback_failure_target ]]

# Applying and undoing through a symlink changes the referent, not the link.
referent="$scratch/home/dotfiles/XCompose"
link="$scratch/home/.XCompose"
mkdir -p "$(dirname "$referent")"
printf '%s\n' '<Multi_key> <o> : "old"' > "$referent"
ln -s "dotfiles/XCompose" "$link"
rev=$(revision "$link")
symlink_apply=$(apply_text "$link" "$rev" $'<Multi_key> <n> : "new"\n')
jq -e '.ok' <<< "$symlink_apply" >/dev/null
[[ -L $link ]]
assert_eq "$(readlink "$link")" 'dotfiles/XCompose'
assert_eq "$(<"$referent")" '<Multi_key> <n> : "new"'
rev=$(revision "$link")
undone=$("$helper" --file "$link" undo "$rev")
jq -e '.ok and .operation == "undo"' <<< "$undone" >/dev/null
[[ -L $link ]]
assert_eq "$(<"$referent")" '<Multi_key> <o> : "old"'

# Retargeting after revision and broken links are rejected safely.
other="$scratch/home/dotfiles/OtherCompose"
printf '%s\n' '<Multi_key> <x> : "other"' > "$other"
rev=$(revision "$link")
ln -sfn "dotfiles/OtherCompose" "$link"
set +e
retargeted=$(apply_text "$link" "$rev" 'must not write' 2>/dev/null)
retargeted_code=$?
set -e
assert_eq "$retargeted_code" '3'
jq -e '.error == "stale revision"' <<< "$retargeted" >/dev/null
assert_eq "$(<"$other")" '<Multi_key> <x> : "other"'

# Undo skips newer backups for another referent and finds the newest match.
ln -sfn 'dotfiles/XCompose' "$link"
rev=$(revision "$link")
apply_text "$link" "$rev" 'referent A changed' >/dev/null
ln -sfn 'dotfiles/OtherCompose' "$link"
rev=$(revision "$link")
apply_text "$link" "$rev" 'referent B changed' >/dev/null
ln -sfn 'dotfiles/XCompose' "$link"
rev=$(revision "$link")
"$helper" --file "$link" undo "$rev" >/dev/null
assert_eq "$(<"$referent")" '<Multi_key> <o> : "old"'

# A failed atomic rename is reported and never claims activation success.
mkdir -p "$scratch/fail-bin"
cat > "$scratch/fail-bin/mv" <<'STUB'
#!/bin/bash
exit 9
STUB
chmod +x "$scratch/fail-bin/mv"
fault_target="$scratch/home/fault.compose"
printf '%s' 'unchanged' > "$fault_target"
rev=$(revision "$fault_target")
set +e
rename_failure=$(printf '%s' 'replacement' | PATH="$scratch/fail-bin:$PATH" "$helper" --file "$fault_target" apply "$rev")
rename_code=$?
set -e
assert_eq "$rename_code" '6'
jq -e '.ok == false and (.error | contains("rename failed"))' <<< "$rename_failure" >/dev/null
assert_eq "$(<"$fault_target")" 'unchanged'

ln -sfn 'dotfiles/missing' "$link"
set +e
broken=$("$helper" --file "$link" revision 2>/dev/null)
broken_code=$?
set -e
assert_eq "$broken_code" '2'
jq -e '.error | contains("broken or cyclic")' <<< "$broken" >/dev/null

printf '%s\n' 'transaction tests: ok'
