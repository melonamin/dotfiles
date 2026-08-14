-- Personal input overrides. Omarchy's defaults already match the rest of the
-- old input.conf (compose:caps, repeat_rate 40, clickfinger_behavior,
-- touchpad scroll_factor 0.4, and the per-terminal scroll_touchpad rules).

hl.config({
  input = {
    -- Longer than Omarchy's 250ms default.
    repeat_delay = 600,

    touchpad = {
      -- Use natural (inverse) scrolling.
      natural_scroll = true,
    },
  },
})

-- Touchpad gestures for workspace switching. Hyprland 0.56 replaced the old
-- `gestures { workspace_swipe_* }` block with this API, so the tuning values
-- from the pre-quattro config (distance 300, min_speed_to_force 30,
-- cancel_ratio 0.5, create_new) no longer have direct equivalents. Left off
-- because this machine has no touchpad; enable and re-tune on one that does.
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
