-- Personal look'n'feel overrides: rounded corners, shadow and blur on,
-- animations off, and full-width pairs in the scrolling layout.

hl.config({
  scrolling = {
    column_width = 0.5,
  },

  decoration = {
    rounding = 8,

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },

    blur = {
      enabled = true,
      size = 3,
      passes = 1,
      vibrancy = 0.1696,
    },
  },

  animations = {
    enabled = false,
  },

  -- Software cursor so screen sharing (portal/screencopy) captures the pointer;
  -- a hardware cursor lives on a scanout plane the capture never sees.
  cursor = {
    no_hardware_cursors = true,
  },

  -- Silence the warning about not using start-hyprland (Omarchy uses uwsm).
  misc = {
    disable_watchdog_warning = true,
  },
})

-- Handy recording overlay: float at bottom center, no decorations, pinned.
o.window({ class = "^(handy)$", title = "^(Recording)$" }, {
  float = true,
  pin = true,
  size = { 172, 36 },
  border_size = 0,
  no_shadow = true,
  no_focus = true,
  no_blur = true,
  no_anim = true,
  move = { "(min(max((monitor_w*0.47),0),monitor_w-window_w))", "(min(max((monitor_h*0.98),0),monitor_h-window_h))" },
})
