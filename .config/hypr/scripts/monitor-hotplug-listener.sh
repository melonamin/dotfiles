#!/bin/bash
# Listen for monitor hot-plug events and run phantom cleanup.
# The Apple Studio Display over Thunderbolt registers two DP ports with the same
# serial. On hot-plug, both appear in quick succession. We wait briefly to let
# both ports register, then disable the phantom (fewer modes) and re-apply the
# monitor config so the real port gets enabled at the correct resolution.

PHANTOM_SCRIPT="$HOME/.config/hypr/scripts/disable-phantom-monitors.sh"
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
DEBOUNCE_PID=""

handle_monitor_added() {
    # Kill any pending debounce so we restart the timer on each event
    if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null
    fi

    # Wait for all ports to register, then clean up phantoms and reload config
    (
        sleep 2
        "$PHANTOM_SCRIPT"
        hyprctl reload
    ) &
    DEBOUNCE_PID=$!
}

nc -U "$SOCKET" |
    while IFS= read -r line; do
        case "$line" in
            monitoraddedv2\>*|monitoradded\>*)
                handle_monitor_added
                ;;
        esac
    done
