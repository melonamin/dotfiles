-- Extra autostart processes.

-- Handy needs a persistent instance: `handy --toggle-transcription` (SUPER + E)
-- is a message to a running app, and with nothing listening it becomes a full
-- app instance instead. Pressing the key again before that one finishes
-- starting spawns a second app, and each draws its own recording overlay.
-- Handy's own XDG autostart entry never fires here because
-- xdg-desktop-autostart.target is inactive on this session.
o.launch_on_start("handy --start-hidden")

-- Disable phantom monitor duplicates (e.g. Apple Studio Display registering
-- two ports). No-op when no two monitors share a serial.
o.exec_on_start("~/.config/hypr/scripts/disable-phantom-monitors.sh")

-- Self-heal monitors on hot-plug (re-runs phantom cleanup + config reload).
-- Complements Omarchy's own omarchy-hyprland-monitor-watch, which covers
-- clamshell and monitor removal rather than duplicate-port cleanup.
o.exec_on_start("~/.config/hypr/scripts/monitor-hotplug-listener.sh")

-- Eagerly start the Hyprland xdg-desktop-portal backend so xdg-desktop-portal
-- sees the ScreenCast interface at session start. Without this, xdp caches
-- fallback backend choices before xdph gets D-Bus activated, and Chromium /
-- OBS end up with tab-only sharing in Meet et al.
--
-- Must be restart, not start: user services outlive the compositor, so when
-- Hyprland restarts without a full logout the old xdph stays active, bound to
-- a dead compositor socket (it also spins a core). start is then a no-op and
-- ScreenCast never appears. The frontend is restarted after the backend
-- because it only enumerates backend interfaces at its own startup.
--
-- The environment is imported here rather than relying on Omarchy's own
-- import-environment autostart: Hyprland launches these entries in order but
-- does not wait for them, so restarting the portal first would race ahead and
-- hand it the previous session's HYPRLAND_INSTANCE_SIGNATURE. Importing
-- inline keeps this correct regardless of ordering.
o.exec_on_start(
  "systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    .. " && dbus-update-activation-environment --systemd HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    .. " && systemctl --user restart xdg-desktop-portal-hyprland.service"
    .. " && systemctl --user restart xdg-desktop-portal.service"
)
