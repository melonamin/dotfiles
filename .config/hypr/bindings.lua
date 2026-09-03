-- Personal keybinding overrides.
--
-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Perplexity search.
o.bind("SUPER + A", "Perplexity search", { launch = "omarchy-cmd-perplexity" })

-- Activity monitor. Omarchy also binds this to SUPER + CTRL + T by default.
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })

-- OCR a screen region to the clipboard. Omarchy also binds this to
-- SUPER + CTRL + PRINT, which this keyboard has no key for.
o.bind("CTRL + SHIFT + code:11", "Extract text (OCR)", "omarchy-capture-text")

-- Screenshots and screen recording on the macOS-style CTRL/ALT + SHIFT + digit
-- combos, alongside Omarchy's own PRINT bindings.
o.bind("CTRL + SHIFT + code:12", "Screenshot (fullscreen)", "omarchy-capture-screenshot fullscreen")
o.bind("CTRL + SHIFT + code:13", "Screenshot (region)", "omarchy-capture-screenshot region")
o.bind("CTRL + SHIFT + code:14", "Screenshot (window)", "omarchy-capture-screenshot windows")
o.bind("ALT + SHIFT + code:12", "Screenrecording", "omarchy-capture-screenrecording")
o.bind("ALT + SHIFT + code:13", "Screenrecording", "omarchy-capture-screenrecording")

-- Push-to-talk dictation. Omarchy's defaults put this on SUPER + CTRL + X and
-- F9; these keep the SUPER + R muscle memory.
o.bind("SUPER + R", "Start dictation", "voxtype record start")
o.bind("SUPER + R", "Stop dictation", "voxtype record stop", { release = true })

o.bind("SUPER + E", "Toggle transcription", "/usr/bin/handy --toggle-transcription")

-- SUPER + F stays on Omarchy's default full screen.

-- The default togglesplit message only exists in the dwindle layout. Guard it
-- so scrolling workspaces get a useful explanation instead of a Lua error.
hl.unbind("SUPER + J")
o.bind("SUPER + J", "Toggle window split (dwindle only)", "hyprland-layout-toggle-split")

-- The unbind drops the default tiled-fullscreen on SUPER + CTRL + F so the
-- pane zooms without the window also changing.
hl.unbind("SUPER + CTRL + F")
o.bind("SUPER + CTRL + F", "Toggle herdr pane zoom", "herdr pane zoom --current --toggle")

-- Volume controls for 65% keyboard (no media keys). code:20 is minus and
-- code:21 is equal; Omarchy binds horizontal window resize to both by keycode,
-- so the unbinds have to use the keycode form to match.
hl.unbind("SUPER + code:20")
hl.unbind("SUPER + code:21")
hl.unbind("SUPER + ALT + code:20")
hl.unbind("SUPER + ALT + code:21")
o.bind("SUPER + code:21", "Volume up", "omarchy-audio-output-volume raise", { locked = true, repeating = true })
o.bind("SUPER + code:20", "Volume down", "omarchy-audio-output-volume lower", { locked = true, repeating = true })
o.bind("SUPER + M", "Mute toggle", "omarchy-audio-output-volume mute-toggle", { locked = true })
o.bind("SUPER + ALT + code:21", "Volume up precise", "omarchy-audio-output-volume +1", { locked = true, repeating = true })
o.bind("SUPER + ALT + code:20", "Volume down precise", "omarchy-audio-output-volume -1", { locked = true, repeating = true })

-- Media playback controls for 65% keyboard.
-- These use the shell's own MPRIS service, which tracks the active player.
-- The old ~/.local/bin/media-key wrapper hand-rolled that on top of playerctl,
-- which Omarchy no longer installs.
o.bind("SUPER + bracketleft", "Previous track", "omarchy-shell media previous", { locked = true })
o.bind("SUPER + backslash", "Play/pause", "omarchy-shell media playPause", { locked = true })
o.bind("SUPER + bracketright", "Next track", "omarchy-shell media next", { locked = true })

-- Lumarchy dry run: hold, draw without clicking, then release.
o.bind("SUPER + Z", "Test Lumarchy gesture", "'/home/sasha/Developer/github.com/melonamin/lumarchy/build/release/lumarchy' test")
o.bind("SUPER + Z", "Release Lumarchy test", "'/home/sasha/Developer/github.com/melonamin/lumarchy/build/release/lumarchy' end", { release = true })


-- BEGIN melonamin.omarchy-leader managed binding
o.bind("SUPER + semicolon", "Leader shortcuts", "omarchy-shell shell toggle melonamin.omarchy-leader '{}'")
-- END melonamin.omarchy-leader managed binding
