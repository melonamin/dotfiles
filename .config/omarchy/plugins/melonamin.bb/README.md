# BB Control

An Omarchy bar widget for BB activity and credential-profile selection.

The bar shows unread BB errors first, then active thread count. The panel
contains Herdr-style activity totals, a prioritized list of threads updated
within the last 24 hours, and fixed selectors for the local Claude and Codex
profiles used by `bb.service`.

## Profiles

| Profile | Config home | Launcher |
|---|---|---|
| Claude 1 | `~/.claude` | `clx` |
| Claude 2 | `~/.claude2` | `clx2` |
| Codex 1 | `~/.codex` | `cx` |
| Codex 2 | `~/.codex2` | `cx2` |
| Codex 3 | `~/.codex3` | `cx3` |

The plugin stores only `CLAUDE_CONFIG_DIR` and `CODEX_HOME` in BB's
`env.json`. It does not read or display credential files, OAuth tokens, or
API keys. Applying a pair restarts the `bb.service` user unit and waits for
the BB API to become ready.

When BB has active turns, applying a new pair requires a second click within
five seconds.

## Controls

- Left click: open or close the panel.
- Right click: refresh immediately.
- `R` or Enter: refresh.
- Escape: close.

Validate after changes with:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/melonamin.bb
```
