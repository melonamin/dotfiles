#!/usr/bin/env bash

set -uo pipefail
umask 077

bb_app_bin=${BB_APP_BIN:-bb-app}
bb_bin=${BB_BIN:-bb}
systemctl_bin=${SYSTEMCTL_BIN:-systemctl}
bb_data_dir=${BB_DATA_DIR:-/mnt/bulk/bb}
skip_restart=${BB_SWITCH_SKIP_RESTART:-0}

claude_id=${1:-}
codex_id=${2:-}
mode=${3:-apply}

case "$claude_id" in
    claude-1) claude_home=$HOME/.claude ;;
    claude-2) claude_home=$HOME/.claude2 ;;
    *)
        jq -cn --arg error "Unknown Claude profile" '{ok:false,error:$error}'
        exit 2
        ;;
esac

case "$codex_id" in
    codex-1) codex_home=$HOME/.codex ;;
    codex-2) codex_home=$HOME/.codex2 ;;
    codex-3) codex_home=$HOME/.codex3 ;;
    *)
        jq -cn --arg error "Unknown Codex profile" '{ok:false,error:$error}'
        exit 2
        ;;
esac

if [[ "$mode" == --check ]]; then
    jq -cn \
        --arg claudeId "$claude_id" \
        --arg codexId "$codex_id" \
        --arg claudeHome "$claude_home" \
        --arg codexHome "$codex_home" \
        '{ok:true,claudeId:$claudeId,codexId:$codexId,claudeHome:$claudeHome,codexHome:$codexHome}'
    exit 0
fi

if [[ "$mode" != apply ]]; then
    jq -cn --arg error "Unknown switch mode" '{ok:false,error:$error}'
    exit 2
fi

mkdir -p "$bb_data_dir"
env_file=$bb_data_dir/env.json
backup=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/bb-env.XXXXXX") || exit 1
had_env_file=0
if [[ -f "$env_file" ]]; then
    cp -p -- "$env_file" "$backup"
    had_env_file=1
fi

restore_environment() {
    if (( had_env_file )); then
        cp -p -- "$backup" "$env_file"
        "$bb_app_bin" --data-dir "$bb_data_dir" config refresh >/dev/null 2>&1 || true
    else
        rm -f -- "$env_file"
    fi
}

cleanup() {
    rm -f -- "$backup"
}
trap cleanup EXIT

if ! "$bb_app_bin" --data-dir "$bb_data_dir" env set CLAUDE_CONFIG_DIR "$claude_home" >/dev/null 2>&1; then
    restore_environment
    jq -cn --arg error "Could not set the Claude profile" '{ok:false,error:$error}'
    exit 1
fi

if ! "$bb_app_bin" --data-dir "$bb_data_dir" env set CODEX_HOME "$codex_home" >/dev/null 2>&1; then
    restore_environment
    jq -cn --arg error "Could not set the Codex profile" '{ok:false,error:$error}'
    exit 1
fi

if [[ "$skip_restart" == 1 ]]; then
    jq -cn --arg claudeId "$claude_id" --arg codexId "$codex_id" \
        '{ok:true,restarted:false,claudeId:$claudeId,codexId:$codexId}'
    exit 0
fi

if ! "$systemctl_bin" --user restart bb.service >/dev/null 2>&1; then
    jq -cn --arg error "Profiles saved, but bb.service could not restart" \
        '{ok:false,saved:true,error:$error}'
    exit 1
fi

version=""
for _ in $(seq 1 30); do
    if version_json=$(timeout 2s "$bb_bin" settings version --json 2>/dev/null); then
        version=$(jq -r '.currentVersion // empty' <<<"$version_json" 2>/dev/null || true)
        jq -cn \
            --arg claudeId "$claude_id" \
            --arg codexId "$codex_id" \
            --arg version "$version" \
            '{ok:true,restarted:true,claudeId:$claudeId,codexId:$codexId,version:$version}'
        exit 0
    fi
    sleep 1
done

jq -cn --arg error "Profiles saved, but BB did not become ready" \
    '{ok:false,saved:true,error:$error}'
exit 1
