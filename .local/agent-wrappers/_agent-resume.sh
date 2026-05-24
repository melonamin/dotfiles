#!/usr/bin/env bash
# Shared helpers for tmux-resurrect-aware AI agent wrappers (clx, cx, pi).
# Sourced — not executed.
#
# State lives in $STATE_DIR keyed by tmux session:window.pane (which is what
# tmux-resurrect preserves across restarts). Each state file holds the cwd the
# agent was launched from and the agent's session UUID. On the next launch in
# the same pane+cwd, the wrapper resumes that UUID; if cwd has changed, the
# wrapper starts fresh (no cross-cwd resume).

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-agent-sessions"
mkdir -p "$STATE_DIR"

# Stable per-pane key. Inside tmux we use session:window.pane indices because
# tmux-resurrect restores those exactly. Outside tmux we hash $PWD as a
# best-effort fallback.
agent_pane_key() {
    if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
        local raw
        raw=$(tmux display -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)
        if [[ -n "$raw" ]]; then
            echo "${raw//[^a-zA-Z0-9_:.-]/_}"
            return
        fi
    fi
    printf '%s' "$PWD" | sha1sum | awk '{print "cwd_"$1}'
}

# Echo saved session id only when saved cwd == $PWD; otherwise empty.
agent_read_resume_id() {
    local state_file="$1"
    [[ -f "$state_file" ]] || return 0
    local saved_cwd saved_id
    saved_cwd=$(sed -n 's/^cwd=//p' "$state_file" | head -1)
    saved_id=$(sed -n 's/^id=//p' "$state_file" | head -1)
    if [[ "$saved_cwd" == "$PWD" && -n "$saved_id" ]]; then
        printf '%s' "$saved_id"
    fi
}

# Write state. No-op when id is empty so a failed capture preserves the
# previous id.
agent_write_state() {
    local state_file="$1" id="$2"
    [[ -z "$id" ]] && return 0
    printf 'cwd=%s\nid=%s\n' "$PWD" "$id" > "$state_file"
}

# Newest .jsonl in $1 with mtime >= launch_ts ($2). Empty if none.
agent_newest_after() {
    local dir="$1" launch_ts="$2"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -type f -name '*.jsonl' -newermt "@$launch_ts" \
         -printf '%T@ %p\n' 2>/dev/null \
        | sort -n | tail -1 | sed 's/^[^ ]* //'
}

# Pull a UUID from a session filename. Works for all three agents:
#   claude: <uuid>.jsonl
#   codex:  rollout-<ts>-<uuid>.jsonl
#   pi:     <ts>_<uuid>.jsonl
agent_extract_uuid() {
    local fname
    fname=$(basename "$1")
    if [[ "$fname" =~ ([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

# claude project dir: replace / with - (e.g. /tmp -> -tmp)
agent_claude_project_dir() {
    echo "$HOME/.claude/projects/${1//\//-}"
}

# pi sessions dir: --<cwd-with-leading-/-stripped, /->->--
# e.g. /home/sasha -> --home-sasha--
agent_pi_sessions_dir() {
    local cwd="${1#/}"
    echo "$HOME/.pi/agent/sessions/--${cwd//\//-}--"
}

agent_capture_claude() {
    local launch_ts="$1"
    local f
    f=$(agent_newest_after "$(agent_claude_project_dir "$PWD")" "$launch_ts")
    [[ -n "$f" ]] && agent_extract_uuid "$f"
}

agent_capture_pi() {
    local launch_ts="$1"
    local f
    f=$(agent_newest_after "$(agent_pi_sessions_dir "$PWD")" "$launch_ts")
    [[ -n "$f" ]] && agent_extract_uuid "$f"
}

# codex rollouts aren't segregated by cwd, so we read each candidate's
# session_meta line and only accept the newest one whose payload.cwd == $PWD.
agent_capture_codex() {
    local launch_ts="$1"
    local base="$HOME/.codex/sessions"
    [[ -d "$base" ]] || return 0
    local today yest
    today=$(date -u +%Y/%m/%d)
    yest=$(date -u -d 'yesterday' +%Y/%m/%d 2>/dev/null \
           || date -u -v-1d +%Y/%m/%d 2>/dev/null)
    local search=()
    [[ -d "$base/$today" ]] && search+=("$base/$today")
    [[ -n "$yest" && -d "$base/$yest" ]] && search+=("$base/$yest")
    [[ ${#search[@]} -eq 0 ]] && return 0

    local f best="" meta_cwd
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        meta_cwd=$(head -c 4096 "$f" 2>/dev/null \
                   | grep -oP '"cwd"\s*:\s*"\K[^"]+' | head -1)
        [[ "$meta_cwd" == "$PWD" ]] && best="$f"
    done < <(find "${search[@]}" -maxdepth 1 -type f -name 'rollout-*.jsonl' \
                  -newermt "@$launch_ts" -printf '%T@ %p\n' 2>/dev/null \
             | sort -n | sed 's/^[^ ]* //')
    [[ -n "$best" ]] && agent_extract_uuid "$best"
}
