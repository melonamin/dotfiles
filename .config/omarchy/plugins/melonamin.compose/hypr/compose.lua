-- Runtime shortcut registration for melonamin.compose. Loaded with
-- `hyprctl eval`; it never edits a Hyprland configuration file.

_G.omarchy_compose = _G.omarchy_compose or {}
local C = _G.omarchy_compose
C.handles = C.handles or {}
C.installed = C.installed or false
C.shortcut = C.shortcut or nil

local function release_handles()
  for _, handle in ipairs(C.handles) do
    pcall(function() handle:unbind() end)
  end
  C.handles = {}
  C.installed = false
  C.shortcut = nil
end

function C.uninstall()
  release_handles()
  return "uninstalled"
end

function C.install(shortcut, force)
  shortcut = tostring(shortcut or "")

  -- Config reloads discard compositor-side handles already. Forget stale
  -- references without calling unbind on them, then install the current key.
  if force then
    C.handles = {}
    C.installed = false
    C.shortcut = nil
  elseif C.installed and C.shortcut == shortcut then
    return "already"
  else
    release_handles()
  end

  C.installed = true
  C.shortcut = shortcut
  if shortcut == "" then return "disabled" end

  local handle = hl.bind(shortcut, function()
    hl.exec_cmd("omarchy-shell -q compose quick")
  end, { description = "Compose: Quick picker" })
  table.insert(C.handles, handle)
  return "installed"
end
