# Quick Panels for Omarchy

Quick Panels is a mouse-activated application and folder dock for the Omarchy
desktop. Move the pointer to the center of the bottom screen edge and the dock
slides into view. It uses Omarchy's Quickshell host, application library,
active theme, and multi-monitor model.

## Features

- Theme-native floating dock on every selected monitor
- Delayed edge reveal and forgiving delayed close
- Desktop-entry icons, names, launching, and running indicators
- Click a running application to focus it
- Ctrl-click or middle-click to launch another application instance
- Folder shortcuts opened through the desktop's default file manager
- Disabled placeholders for missing applications and folders
- Watched, atomically written configuration
- IPC for keyboard shortcuts and automation

## Requirements

- Omarchy 4 with the plugin-based `omarchy-shell`
- Quickshell 0.3 or newer

## Install

Once this repository is published, install and enable it with:

```sh
omarchy plugin add https://github.com/melonamin/omarchy-quick-panels --enable
```

The first start creates `~/.config/omarchy/quick-panels.json`. Quick Panels
selects at most one installed terminal, browser, file manager, and editor, then
adds Home and Downloads folder shortcuts. The generated file is user-owned and
is never replaced during plugin updates.

## Configure

Items are displayed in file order:

```json
{
  "version": 1,
  "edge": "bottom",
  "screens": ["*"],
  "openDelay": 45,
  "closeDelay": 380,
  "layer": "top",
  "iconSize": 40,
  "activationWidth": 360,
  "closeOnLaunch": true,
  "items": [
    { "type": "app", "desktopId": "com.mitchellh.ghostty" },
    { "type": "app", "desktopId": "firefox" },
    { "type": "separator" },
    { "type": "folder", "name": "Home", "path": "~" },
    { "type": "folder", "name": "Downloads", "path": "~/Downloads" }
  ]
}
```

Use `screens: ["*"]` for every monitor or list output names such as
`["eDP-1", "DP-2"]`. Find output names with `hyprctl monitors`.

Set `layer` to `overlay` if the dock should appear over fullscreen windows.
The default `top` layer stays below fullscreen content. `activationWidth`
controls the width of the invisible bottom-edge target in pixels.

Application IDs are desktop file names without the `.desktop` suffix. List
likely IDs with:

```sh
find /usr/share/applications ~/.local/share/applications -name '*.desktop' -printf '%f\n' 2>/dev/null | sort -u
```

Configuration reloads when the file changes. A malformed reload retains the
last valid layout and shows a warning item without overwriting the broken file.

## IPC and keybindings

```sh
omarchy-shell melonamin.quick-panels open
omarchy-shell melonamin.quick-panels close
omarchy-shell melonamin.quick-panels toggle
omarchy-shell melonamin.quick-panels reload
omarchy-shell melonamin.quick-panels status | jq
```

These commands can be called from any Hyprland binding. The direct hover
interaction does not require a binding.

## Development

Run the full local validation suite:

```sh
tests/integration.sh
```

The plugin is intentionally limited to launchers, separators, and folder
shortcuts in version 0.1. Drop actions and an in-dock configuration editor are
future work.

## License

MIT
