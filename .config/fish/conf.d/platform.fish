# Platform-specific configuration for macOS and Linux

switch (uname)
    case Darwin
        # macOS PATH (Apple Silicon)
        fish_add_path -g /opt/homebrew/bin
        fish_add_path -g /opt/homebrew/sbin
        fish_add_path -g /opt/homebrew/opt/openjdk/bin

        # macOS system updates
        alias update='sudo softwareupdate -i -a; brew update; brew upgrade; brew cleanup'

        # macOS networking
        alias localip='ipconfig getifaddr en0'
        alias flush='dscacheutil -flushcache && killall -HUP mDNSResponder'
        alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"

        # macOS clipboard
        alias c="tr -d '\n' | pbcopy"

        # macOS Finder
        alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
        alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"
        alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
        alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

        # macOS trash and cleanup
        alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl; sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"
        alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"

        # macOS Spotlight
        alias spotoff="sudo mdutil -a -i off"
        alias spoton="sudo mdutil -a -i on"

        # macOS-specific tools
        alias plistbuddy="/usr/libexec/PlistBuddy"

    case Linux
        # Linux Homebrew PATH (if installed)
        if test -d /home/linuxbrew/.linuxbrew
            fish_add_path -g /home/linuxbrew/.linuxbrew/bin
            fish_add_path -g /home/linuxbrew/.linuxbrew/sbin
        end

        # Linux system updates (detect package manager)
        if type -q apt
            alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'
        else if type -q pacman
            alias update='sudo pacman -Syu'
        else if type -q dnf
            alias update='sudo dnf upgrade -y'
        else if type -q zypper
            alias update='sudo zypper update'
        end

        # Linux networking
        alias localip="hostname -I | awk '{print \$1}'"
        if type -q systemd-resolve
            alias flush='sudo systemd-resolve --flush-caches'
        else if type -q resolvectl
            alias flush='sudo resolvectl flush-caches'
        end
        alias ifactive="ip link show | grep 'state UP'"

        # Linux clipboard (Wayland vs X11)
        if test -n "$WAYLAND_DISPLAY"
            alias c="tr -d '\n' | wl-copy"
        else if test -n "$DISPLAY"
            alias c="tr -d '\n' | xclip -selection clipboard"
        end

        # Linux trash
        alias emptytrash="rm -rf ~/.local/share/Trash/*"
end

# Cross-platform clipboard command (use 'clip' for portability)
if type -q pbcopy
    alias clip='pbcopy'
else if type -q wl-copy
    alias clip='wl-copy'
else if type -q xclip
    alias clip='xclip -selection clipboard'
end
