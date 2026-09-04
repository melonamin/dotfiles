# Omarchy workstation bootstrap

This recreates the interactive desktop from a fresh Omarchy installation
without copying personal data, credentials, runtime state, or hardware-specific
configuration.

It covers the user-selected Arch/AUR packages, Mise and Cargo CLI tools,
Hyprland and application configs, macOS-style keyd shortcuts, Fish/tmux plugins,
web apps, agterm and its keymap, Omarchy shell plugins, installed themes, active
theme and background, font, login shell, and default browser/editor/terminal/agent.

## New laptop

Sign into GitHub/SSH first, then clone this repository at the same conventional
location. The scripts substitute the active `$HOME` when a tracked config still
contains `/home/sasha`.

```bash
git clone git@github.com:melonamin/dotfiles.git \
  ~/Developer/github.com/melonamin/dotfiles
cd ~/Developer/github.com/melonamin/dotfiles

./bootstrap.sh --check
./bootstrap.sh --apply
```

Both modes are idempotent. `--check` is read-only. `--apply` backs up differing
files with a `bootstrap-<timestamp>.bak` suffix before replacing them.

`--apply` follows current package and tool releases instead of pinning the old
laptop's versions. Run it from a graphical Omarchy session so theme, browser,
and shell refresh commands can reach the desktop.

## Current workstation

Run the capture audit before committing workstation changes:

```bash
./bootstrap/capture.sh --check
```

Use `--apply` only after reviewing its output. It refreshes the scoped package
manifests; dotfile copies continue to use the dotfiles sync workflow.

Package versions are intentionally not pinned. A new machine installs the
current versions compatible with its current Omarchy release.

## Manifests

- `packages-arch.txt`, `packages-aur.txt`: apps and system/CLI packages beyond
  the stock Omarchy manifests.
- `cargo-tools.txt` and `.config/mise/config.toml`: language-level CLI tools.
- `webapps.tsv`: custom browser apps; icons are fetched at install time.
- `plugins.tsv`: Git-installed, repo-linked, and locally vendored shell plugins.
- `themes.tsv`: Git themes and two local Aether palettes whose wallpapers are
  fetched from Wallhaven by ID.
- `copy-paths.txt`: configuration copied into the new `$HOME`.
- `defaults.tsv`: active UI and application defaults.
