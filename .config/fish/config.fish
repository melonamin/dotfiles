 # Start Hyprland on first TTY if not already running
if test -z "$DISPLAY"; and test (tty) = "/dev/tty1"
    exec Hyprland
end

if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}
    [ -r "$file" ] && [ -f "$file" ] && source "$file"
end

starship init fish | source
atuin init fish | source

~/.local/bin/mise activate fish | source

function manz
    man $argv | col -b | zed -
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

atuin init fish | source
zoxide init --cmd cd fish | source
~/.local/bin/mise activate fish | source

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :


# opencode
fish_add_path /Users/alex/.opencode/bin

source ~/Developer/.bin/dev-helpers.fish
