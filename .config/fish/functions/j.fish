# Quick directory bookmarks
# Usage:
#   j add <name>     - bookmark current directory as <name>
#   j rm <name>      - remove bookmark <name>
#   j list           - list all bookmarks
#   j <name>         - jump to bookmarked directory

function j --description "Quick directory bookmarks"
    set -l bookmarks_file ~/.config/fish/bookmarks

    # Ensure bookmarks file exists
    touch $bookmarks_file

    switch $argv[1]
        case add
            if test -z "$argv[2]"
                echo "Usage: j add <name>"
                return 1
            end
            # Remove existing bookmark with same name
            if test -f $bookmarks_file
                grep -v "^$argv[2]=" $bookmarks_file > $bookmarks_file.tmp
                mv $bookmarks_file.tmp $bookmarks_file
            end
            echo "$argv[2]=$PWD" >> $bookmarks_file
            echo "Bookmarked $PWD as '$argv[2]'"

        case rm
            if test -z "$argv[2]"
                echo "Usage: j rm <name>"
                return 1
            end
            grep -v "^$argv[2]=" $bookmarks_file > $bookmarks_file.tmp
            mv $bookmarks_file.tmp $bookmarks_file
            echo "Removed bookmark '$argv[2]'"

        case list ls
            if test -s $bookmarks_file
                echo "Bookmarks:"
                cat $bookmarks_file | while read line
                    set -l name (string split -m1 "=" $line)[1]
                    set -l path (string split -m1 "=" $line)[2]
                    printf "  %-15s -> %s\n" $name $path
                end
            else
                echo "No bookmarks yet. Use 'j add <name>' to create one."
            end

        case ''
            j list

        case '*'
            set -l target (grep "^$argv[1]=" $bookmarks_file | head -1 | string split -m1 "=")[2]
            if test -n "$target"
                cd "$target"
            else
                echo "Bookmark '$argv[1]' not found. Use 'j list' to see available bookmarks."
                return 1
            end
    end
end

# Completions for j command
complete -c j -f
complete -c j -n "__fish_is_first_arg" -a "add" -d "Bookmark current directory"
complete -c j -n "__fish_is_first_arg" -a "rm" -d "Remove a bookmark"
complete -c j -n "__fish_is_first_arg" -a "list" -d "List all bookmarks"
complete -c j -n "__fish_is_first_arg" -a "(cat ~/.config/fish/bookmarks 2>/dev/null | string replace -r '=.*' '')" -d "Jump to bookmark"
