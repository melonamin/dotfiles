# Notify after long-running commands complete
# Sends a notification when a command takes longer than threshold

set -g __notify_threshold 30  # seconds

function __notify_on_finish --on-event fish_postexec
    set -l last_status $status
    set -l duration (math $CMD_DURATION / 1000)

    if test $duration -gt $__notify_threshold
        set -l title "Command finished"
        set -l message "$argv[1] (took $duration seconds)"

        if test $last_status -ne 0
            set title "Command failed"
            set message "$argv[1] (exit $last_status after $duration seconds)"
        end

        # Cross-platform notification
        switch (uname)
            case Darwin
                osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
            case Linux
                if type -q notify-send
                    notify-send "$title" "$message" 2>/dev/null
                end
        end
    end
end
