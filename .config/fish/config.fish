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


# pnpm
set -gx PNPM_HOME "/Users/alex/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
/opt/homebrew/bin/mise activate fish | source

function manz
    man $argv | col -b | zed -
end
