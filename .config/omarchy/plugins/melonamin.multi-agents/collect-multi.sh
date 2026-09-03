#!/usr/bin/env bash

set -uo pipefail

plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
usage_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/multi-agents/usage"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/multi-agents"
mkdir -p "$usage_dir" "$cache_dir"

force=0
collector_flags=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            force=1
            collector_flags+=("--force")
            ;;
        --limits-only)
            collector_flags+=("--limits-only")
            ;;
        --except)
            shift
            ;;
    esac
    shift
done

write_record() {
    local account_id="$1" record="$2" temporary
    jq -e 'type == "object" and (.id | type == "string")' >/dev/null 2>&1 <<<"$record" || return 1
    temporary=$(mktemp "$usage_dir/.${account_id}.XXXXXX") || return 1
    printf '%s\n' "$record" >"$temporary"
    mv "$temporary" "$usage_dir/$account_id.json"
}

account_email() {
    local provider="$1" account_home="$2" metadata_file email
    email=""
    if [[ "$provider" == claude ]]; then
        metadata_file="$account_home/.claude.json"
        if [[ ! -f "$metadata_file" && "$account_home" == "$HOME/.claude" ]]; then
            metadata_file="$HOME/.claude.json"
        fi
        if [[ -f "$metadata_file" ]]; then
            email=$(jq -r '.oauthAccount.emailAddress // empty' "$metadata_file" 2>/dev/null || true)
        fi
    elif [[ -f "$account_home/auth.json" ]]; then
        email=$(
            jq -r '.tokens.id_token // empty' "$account_home/auth.json" 2>/dev/null \
                | awk -F. '{ value=$2; gsub(/-/, "+", value); gsub(/_/, "/", value); while (length(value) % 4) value=value "="; print value }' \
                | base64 -d 2>/dev/null \
                | jq -r '.email // empty' 2>/dev/null \
                || true
        )
    fi
    [[ "$email" == *@* && "$email" != *$'\n'* ]] || email=""
    printf '%s' "$email"
}

write_primary_account() {
    local provider="$1" source_file="$2" account_home="$3" account_id name sort_order launch_command email record
    if [[ "$provider" == "claude" ]]; then
        account_id=claude-1
        name="Claude 1"
        sort_order=10
        launch_command=clx
    else
        account_id=codex-1
        name="Codex 1"
        sort_order=40
        launch_command=cx
    fi
    email=$(account_email "$provider" "$account_home")
    record=$(jq -c \
        --arg account_id "$account_id" \
        --arg name "$name" \
        --arg provider "$provider" \
        --arg launch_command "$launch_command" \
        --arg email "$email" \
        --argjson sort_order "$sort_order" '
        .id = $account_id
        | .name = $name
        | .providerKind = $provider
        | .iconId = $provider
        | .selectorLabel = $name
        | .viewKind = "account"
        | .sortOrder = $sort_order
        | .launchCommand = $launch_command
        | .email = $email
        | .ready = true
        | .hasLocalStats = false
        | .hasPromptStats = false
        | .recentDays = []
        | .modelUsage = {}
        | del(
            .todayPrompts,
            .todaySessions,
            .todayTotalTokens,
            .todayTokensByModel,
            .totalPrompts,
            .totalSessions,
            .activeDays,
            .activeDates
        )
    ' "$source_file") || return 1
    write_record "$account_id" "$record"
}

collect_account() {
    local provider="$1" account_id="$2" name="$3" selector="$4" account_home="$5"
    local sort_order="$6" launch_command="$7" login_hint="$8" email record
    local command=(
        uv run "$plugin_dir/collect-account-limits.py"
        --provider "$provider"
        --account-id "$account_id"
        --name "$name"
        --selector-label "$selector"
        --home "$account_home"
        --sort-order "$sort_order"
        --launch-command "$launch_command"
        --login-hint "$login_hint"
        --cache-dir "$cache_dir"
    )
    (( force )) && command+=(--force)
    if ! record=$("${command[@]}"); then
        echo "multi-agents: failed to collect $name" >&2
        return 1
    fi
    email=$(account_email "$provider" "$account_home")
    record=$(jq -c --arg email "$email" '.email = $email' <<<"$record") || return 1
    if write_record "$account_id" "$record"; then
        return 0
    fi
    echo "multi-agents: failed to collect $name" >&2
    return 1
}

job_ids=()
collect_account claude claude-2 "Claude 2" "Claude 2" "$HOME/.claude2" 20 clx2 \
    'Run `CLAUDE_CONFIG_DIR=~/.claude2 claude auth login` to authenticate Claude 2.' &
job_ids+=("$!")
collect_account codex codex-2 "Codex 2" "Codex 2" "$HOME/.codex2" 50 cx2 \
    'Run `CODEX_HOME=~/.codex2 codex login` to authenticate Codex 2.' &
job_ids+=("$!")
collect_account codex codex-3 "Codex 3" "Codex 3" "$HOME/.codex3" 60 cx3 \
    'Run `CODEX_HOME=~/.codex3 codex login` to authenticate Codex 3.' &
job_ids+=("$!")

temporary_dir=$(mktemp -d)
trap 'rm -rf -- "$temporary_dir"' EXIT
claude_output="$temporary_dir/claude.json"
codex_output="$temporary_dir/codex.json"
claude_error="$temporary_dir/claude.err"
codex_error="$temporary_dir/codex.err"

claude_collector=$(command -v omarchy-agent-usage-claude || true)
codex_collector=$(command -v omarchy-agent-usage-codex || true)
codex_binary=$(command -v codex || true)
combined_jobs=()
if [[ -n "$claude_collector" ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.claude" "$claude_collector" "${collector_flags[@]}" \
        >"$claude_output" 2>"$claude_error" &
    combined_jobs+=("$!:claude")
fi
if [[ -n "$codex_collector" && -n "$codex_binary" ]]; then
    CODEX_REAL_BIN="$codex_binary" PATH="$plugin_dir/compat-bin:$PATH" \
        CODEX_HOME="$HOME/.codex" "$codex_collector" "${collector_flags[@]}" \
        >"$codex_output" 2>"$codex_error" &
    combined_jobs+=("$!:codex")
fi

status=0
for job_id in "${job_ids[@]}"; do
    wait "$job_id" || status=1
done

combined_inputs=()
for job in "${combined_jobs[@]}"; do
    job_id=${job%%:*}
    provider=${job#*:}
    if wait "$job_id"; then
        output_file="$temporary_dir/$provider.json"
        if jq -e 'type == "object"' "$output_file" >/dev/null 2>&1; then
            combined_inputs+=("$output_file")
            primary_home="$HOME/.codex"
            [[ "$provider" == claude ]] && primary_home="$HOME/.claude"
            write_primary_account "$provider" "$output_file" "$primary_home" || status=1
        fi
    else
        error_file="$temporary_dir/$provider.err"
        [[ ! -s "$error_file" ]] || sed "s/^/multi-agents ($provider): /" "$error_file" >&2
        status=1
    fi
done

if (( ${#combined_inputs[@]} > 0 )); then
    combined=$(jq -s '
        def n: tonumber? // 0;
        def add_object_numbers($objects):
            reduce ($objects | to_entries[]) as $entry ({};
                .[$entry.key] = ((.[$entry.key] // 0) + ($entry.value | n))
            );
        def token_bucket($objects):
            reduce ($objects | to_entries[]) as $entry ({};
                .[$entry.key] = (
                    .[$entry.key] // {
                        inputTokens: 0,
                        outputTokens: 0,
                        cacheReadInputTokens: 0,
                        cacheCreationInputTokens: 0
                    }
                    | .inputTokens += ($entry.value.inputTokens | n)
                    | .outputTokens += ($entry.value.outputTokens | n)
                    | .cacheReadInputTokens += ($entry.value.cacheReadInputTokens | n)
                    | .cacheCreationInputTokens += ($entry.value.cacheCreationInputTokens | n)
                )
            );
        . as $records
        | ([ $records[].activeDates[]? ] | unique | sort) as $active_dates
        | {
            schemaVersion: 1,
            id: "combined",
            name: "Combined Usage",
            providerKind: "combined",
            iconId: "",
            selectorLabel: "Usage",
            viewKind: "usage",
            sortOrder: 30,
            launchCommand: "",
            updatedAt: (now | todateiso8601),
            ready: true,
            tierLabel: "Shared local history",
            usageStatusText: "",
            authHelpText: "",
            limits: [],
            hasLocalStats: true,
            hasPromptStats: true,
            todayPrompts: ([ $records[].todayPrompts | n ] | add // 0),
            todaySessions: ([ $records[].todaySessions | n ] | add // 0),
            todayTotalTokens: ([ $records[].todayTotalTokens | n ] | add // 0),
            todayTokensByModel: add_object_numbers([ $records[].todayTokensByModel // {} ] | add),
            recentDays: (
                [ $records[].recentDays[]? ]
                | group_by(.date)
                | map({date: .[0].date, messageCount: ([ .[].messageCount | n ] | add // 0)})
                | sort_by(.date)
            ),
            totalPrompts: ([ $records[].totalPrompts | n ] | add // 0),
            totalSessions: ([ $records[].totalSessions | n ] | add // 0),
            activeDates: $active_dates,
            activeDays: ($active_dates | length),
            modelUsage: token_bucket([ $records[].modelUsage // {} ] | add)
        }
    ' "${combined_inputs[@]}")
    write_record combined "$combined" || status=1
fi

exit "$status"
