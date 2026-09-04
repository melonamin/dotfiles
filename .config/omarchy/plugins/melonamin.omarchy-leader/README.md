# Omarchy Leader

Mnemonic leader-key shortcuts for Omarchy, rendered inside the long-running
`omarchy-shell` process.

Omarchy Leader is intentionally not another searchable app launcher. Press one
conflict-free leader shortcut, release its modifiers, then follow a short key
sequence. The interface starts as a small trail HUD and progressively reveals
more context when you pause or make a mistake.

## Current status

This repository contains the first working plugin implementation. It includes:

- conflict-aware leader-key setup;
- JSONC configuration with live reload and validation;
- mnemonic nested shortcuts;
- adaptive Trail, Board, and Corner interfaces;
- commands, shell actions, desktop apps, URLs, Omarchy commands, workflows,
  sticky actions, notifications, and dynamic providers;
- a versioned, visual-only interface extension API.

## Install

Once the repository is available through Git, install it with Omarchy's native
plugin manager:

```bash
omarchy plugin add https://github.com/melonamin/omarchy-leader.git --enable
omarchy-shell shell summon melonamin.omarchy-leader '{"setup":true}'
```

The setup screen reads the live Hyprland bindings and only offers candidates
that are currently free. It never silently unbinds an Omarchy shortcut. Before
writing, it previews against a content hash, creates a timestamped backup, and
rolls back if `hyprctl configerrors` reports a problem.

Open the leader directly at any time:

```bash
omarchy-shell shell summon melonamin.omarchy-leader '{}'
```

Reload configuration and discover newly installed interfaces:

```bash
omarchy-shell shell call melonamin.omarchy-leader refresh ''
```

## Configuration

The plugin creates its mutable configuration at:

```text
~/.config/omarchy/leader/config.jsonc
```

The installed checkout remains untouched, so plugin updates do not overwrite
user shortcuts. The complete JSON Schema is in
[`schema/config.schema.json`](schema/config.schema.json).

Items use dotted IDs to express hierarchy:

```jsonc
{
  "version": 1,
  "ui": {
    "start": "trail",
    "onPause": "board",
    "onError": "board",
    "sticky": "corner",
    "expandAfterMs": 700,
    "sequenceTimeoutMs": 0,
  },
  "items": {
    "dev": {
      "key": "d",
      "label": "Development",
      "icon": "󰅩",
    },
    "dev.git": {
      "key": "g",
      "label": "Git",
    },
    "dev.git.status": {
      "key": "s",
      "label": "Status",
      "action": {
        "type": "command",
        "argv": ["git", "status"],
        "cwd": "~/Developer/project",
      },
      "notify": "on-error",
    },
  },
}
```

`sequenceTimeoutMs: 0` keeps the leader open until `Escape`, an outside click,
or the leader hotkey closes it. Set a value of at least `250` to opt back into
automatic sequence timeout behavior.

Sibling keys must be unique. Keys are case-insensitive, printable, unmodified
characters. `Escape` closes, `Backspace` goes up one level, and `?` reveals the
Board interface.

## Actions

### Desktop application

```jsonc
"action": { "type": "launch", "desktop": "org.mozilla.firefox" }
```

### URL, file, or directory

```jsonc
"action": { "type": "open", "target": "https://omarchy.org" }
```

### Argument-safe command

```jsonc
"action": {
  "type": "command",
  "argv": ["git", "pull", "--ff-only"],
  "cwd": "~/Developer/project",
  "timeoutMs": 10000
}
```

### Explicit shell

```jsonc
"action": {
  "type": "shell",
  "command": "journalctl --user -n 20 | wl-copy"
}
```

Shell actions are trusted code. Use `command` when shell expansion and pipelines
are unnecessary.

### Omarchy command

```jsonc
"action": {
  "type": "omarchy",
  "args": ["toggle", "nightlight"]
}
```

### Sequential workflow

Workflow steps may contain action objects or reference another item by dotted
ID:

```jsonc
"action": {
  "type": "workflow",
  "steps": [
    { "type": "omarchy", "args": ["toggle", "notification", "silencing"] },
    "system.nightlight"
  ]
}
```

### Dynamic provider

A provider prints one JSON array to stdout. Each row uses the same `key`,
`label`, `icon`, `action`, `sticky`, and `notify` fields as a configured item:

```jsonc
"recent": {
  "key": "r",
  "label": "Recent projects",
  "action": {
    "type": "provider",
    "argv": ["~/.local/bin/leader-recent-projects"]
  }
}
```

```json
[
  {
    "key": "a",
    "label": "App",
    "action": { "type": "open", "target": "~/Developer/app" }
  }
]
```

Providers default to a 2.5-second timeout. Duplicate or invalid returned keys
are ignored.

## Visual interfaces

Trail, Board, and Corner are renderers over the same engine state. External
interfaces are visual-only and can be selected in any adaptive UI slot. See
[`docs/interfaces.md`](docs/interfaces.md) for the version-one contract.

External QML runs as unsandboxed code inside `omarchy-shell`. Install only
interfaces you trust.

## Recovery

The managed binding is the only edit outside the plugin configuration:

```lua
-- BEGIN melonamin.omarchy-leader managed binding
o.bind(
  "SUPER + semicolon",
  "Leader shortcuts",
  "omarchy-shell shell toggle melonamin.omarchy-leader '{}'"
)
-- END melonamin.omarchy-leader managed binding
```

If the plugin is unavailable, remove that marked block from
`~/.config/hypr/bindings.lua`, then run:

```bash
hyprctl reload
hyprctl configerrors
```

The setup helper leaves timestamped `bindings.lua.bak.*` backups beside the
original file.

## Development

Validate the manifest and QML:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Leader.qml engine/*.qml ui/*.qml setup/*.qml
```

Run the engine, parser, and transactional binding tests:

```bash
QT_QPA_PLATFORM=offscreen qmltestrunner -input tests -import . -o -,txt
tests/test-actionrunner.sh
tests/test-binding-helper.sh
tests/test-renderers.sh
```
