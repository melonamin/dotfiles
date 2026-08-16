#!/usr/bin/env bash

set -uo pipefail

bb_bin=${BB_BIN:-bb}
systemctl_bin=${SYSTEMCTL_BIN:-systemctl}
bb_data_dir=${BB_DATA_DIR:-/mnt/bulk/bb}
env_file="$bb_data_dir/env.json"

claude_home=${HOME}/.claude
codex_home=${HOME}/.codex
if [[ -f "$env_file" ]]; then
    claude_home=$(jq -r '.env.CLAUDE_CONFIG_DIR // empty' "$env_file" 2>/dev/null || true)
    codex_home=$(jq -r '.env.CODEX_HOME // empty' "$env_file" 2>/dev/null || true)
    [[ -n "$claude_home" ]] || claude_home=${HOME}/.claude
    [[ -n "$codex_home" ]] || codex_home=${HOME}/.codex
fi

expand_home() {
    local value=$1
    value=${value/#\~/$HOME}
    value=${value/#\$HOME/$HOME}
    printf '%s' "$value"
}

profile_id() {
    local provider=$1 value
    value=$(expand_home "$2")
    case "$provider:$value" in
        "claude:$HOME/.claude") printf 'claude-1' ;;
        "claude:$HOME/.claude2") printf 'claude-2' ;;
        "codex:$HOME/.codex") printf 'codex-1' ;;
        "codex:$HOME/.codex2") printf 'codex-2' ;;
        "codex:$HOME/.codex3") printf 'codex-3' ;;
        *) printf 'custom' ;;
    esac
}

active_claude_id=$(profile_id claude "$claude_home")
active_codex_id=$(profile_id codex "$codex_home")
service_status=$($systemctl_bin --user is-active bb.service 2>/dev/null || true)

profiles='{
  "claude": [
    {"id":"claude-1","label":"Claude 1","launcher":"clx"},
    {"id":"claude-2","label":"Claude 2","launcher":"clx2"}
  ],
  "codex": [
    {"id":"codex-1","label":"Codex 1","launcher":"cx"},
    {"id":"codex-2","label":"Codex 2","launcher":"cx2"},
    {"id":"codex-3","label":"Codex 3","launcher":"cx3"}
  ]
}'

offline_state() {
    jq -cn \
        --arg serviceStatus "${service_status:-unknown}" \
        --arg activeClaudeId "$active_claude_id" \
        --arg activeCodexId "$active_codex_id" \
        --argjson profiles "$profiles" \
        '{
          online: false,
          serviceStatus: $serviceStatus,
          version: "",
          total: 0,
          working: 0,
          blocked: 0,
          errors: 0,
          idle: 0,
          threads: [],
          profiles: $profiles,
          activeClaudeId: $activeClaudeId,
          activeCodexId: $activeCodexId
        }'
}

if [[ "$service_status" != active ]]; then
    offline_state
    exit 0
fi

if ! version_json=$(timeout 3s "$bb_bin" settings version --json 2>/dev/null); then
    offline_state
    exit 0
fi

if ! threads_json=$(timeout 3s "$bb_bin" thread list --json 2>/dev/null); then
    offline_state
    exit 0
fi

if ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$threads_json"; then
    offline_state
    exit 0
fi

version=$(jq -r '.currentVersion // empty' <<<"$version_json" 2>/dev/null || true)

jq -c \
    --arg serviceStatus "$service_status" \
    --arg version "$version" \
    --arg activeClaudeId "$active_claude_id" \
    --arg activeCodexId "$active_codex_id" \
    --argjson profiles "$profiles" '
    def unread_attention:
      ((.latestAttentionAt // 0) | tonumber) > ((.lastReadAt // 0) | tonumber);
    def is_working: (.status == "active" or .status == "starting" or .status == "working");
    def is_error: (.status == "error" or .status == "blocked");
    def normalized_status:
      if is_working then "working"
      elif is_error and unread_attention then "blocked"
      elif is_error then "error"
      else "idle"
      end;
    def rank:
      if is_working then 0
      elif is_error and unread_attention then 1
      elif is_error then 2
      else 3
      end;
    . as $threads |
    {
      online: true,
      serviceStatus: $serviceStatus,
      version: $version,
      total: ($threads | length),
      working: ($threads | map(select(is_working)) | length),
      blocked: ($threads | map(select(is_error and unread_attention)) | length),
      errors: ($threads | map(select(is_error)) | length),
      idle: ($threads | map(select(.status == "idle")) | length),
      threads: (
        $threads
        | sort_by([rank, -((.updatedAt // 0) | tonumber)])
        | map({
            id: (.id // ""),
            name: (.title // .titleFallback // .id // "BB thread"),
            status: normalized_status,
            provider: (.providerId // ""),
            updatedAt: (.updatedAt // 0),
            unread: unread_attention
          })
      ),
      profiles: $profiles,
      activeClaudeId: $activeClaudeId,
      activeCodexId: $activeCodexId
    }
' <<<"$threads_json"
