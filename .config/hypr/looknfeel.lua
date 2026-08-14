-- Personal look'n'feel overrides: denser window spacing, rounded corners,
-- shadow and blur on, animations off.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
  },

  decoration = {
    rounding = 10,

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
