# omarchy-scribe

SecondScribe meeting capture for the Omarchy bar. Wraps the
`secondscribe-capture` CLI: shows capture status, lists likely calendar
meetings, and starts, pauses, resumes, and stops captures.

## Bar icon

- `󰍬` idle — daemon up, nothing recording
- `󰑊` recording (urgent color; also used for audio-only fallback)
- `󰏤` paused
- `󰍭` dimmed — CLI missing or daemon not running

Left click toggles the panel, right click stops an active capture, middle
click refreshes.

## Panel

- Hero with the active meeting title, status, and elapsed time
- Likely calendar meetings — click one to start capturing it
- Ad-hoc title field for captures without a calendar meeting
- Pause / Resume / Stop for the active capture
- Start-daemon button when the daemon is down

Keys: arrows move over meetings, Enter starts the selected one, `t` focuses
the ad-hoc title field, `s` stops, `p` pauses/resumes, `r` refreshes, `d`
starts the daemon.

## Install

```bash
ln -s "$(pwd)" ~/.config/omarchy/plugins/melonamin.scribe
```

Then add `{"id": "melonamin.scribe"}` to a bar section in
`~/.config/omarchy/shell.json`.

## Settings

- `cliPath` — path to `secondscribe-capture` (absolute path if it is not on
  the shell's PATH; `~` is not expanded)
- `profileDir` — passed as `--profile`; blank uses the desktop client's
  default profile
- `refreshIntervalSec` — idle poll interval (polling tightens to 3s while a
  capture is active)

## IPC

```bash
omarchy-shell melonamin.scribe status
omarchy-shell melonamin.scribe stop
omarchy-shell melonamin.scribe toggle
```

Also: `open`, `close`, `refresh`, `pause`, `resume`.

## Tests

```bash
node --test tests/            # model + integration (uses a fake CLI fixture)
tests/e2e.sh                  # requires the widget installed in a live shell
```
