# Skim (sk) configuration for fish shell

# Skim options
set -gx SKIM_DEFAULT_OPTIONS '--height 40% --layout=reverse --border'
set -gx SKIM_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'

# Ctrl-T: Insert file path
function __skim_file_widget
    set -l result (fd --type f --hidden --exclude .git 2>/dev/null | sk)
    if test -n "$result"
        commandline -i -- (string escape -- $result)
    end
    commandline -f repaint
end

# Alt-C: cd into directory
function __skim_cd_widget
    set -l result (fd --type d --hidden --exclude .git 2>/dev/null | sk)
    if test -n "$result"
        cd -- $result
    end
    commandline -f repaint
end

# Bind keys in interactive mode
if status is-interactive
    bind \ct __skim_file_widget
    bind \ec __skim_cd_widget
end
