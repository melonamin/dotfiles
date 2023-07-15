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

direnv hook fish | source
. /opt/homebrew/opt/asdf/libexec/asdf.fish
