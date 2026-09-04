function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value === undefined ? null : value))
}

function stringValue(value, fallback) {
  if (typeof value !== "string") return fallback === undefined ? "" : fallback
  var result = value.trim()
  return result || (fallback === undefined ? "" : fallback)
}

function clampNumber(value, fallback, minimum, maximum) {
  var number = Number(value)
  if (!isFinite(number)) number = fallback
  return Math.max(minimum, Math.min(maximum, Math.round(number)))
}

function uniqueStrings(values, fallback) {
  if (!Array.isArray(values)) values = fallback || []
  var seen = {}
  var result = []
  for (var i = 0; i < values.length; i++) {
    var value = stringValue(values[i])
    if (!value || seen[value]) continue
    seen[value] = true
    result.push(value)
  }
  return result
}

function normalizeItem(value, index) {
  if (!isPlainObject(value)) {
    return { type: "invalid", name: "Invalid item", reason: "item " + index + " must be an object" }
  }

  var type = stringValue(value.type).toLowerCase()
  if (type === "separator") return { type: "separator" }

  if (type === "app") {
    var desktopId = stringValue(value.desktopId)
    if (!desktopId) {
      return { type: "invalid", name: stringValue(value.name, "Invalid app"), reason: "app item " + index + " requires desktopId" }
    }
    return {
      type: "app",
      desktopId: desktopId.replace(/\.desktop$/, ""),
      name: stringValue(value.name),
      icon: stringValue(value.icon)
    }
  }

  if (type === "folder") {
    var path = stringValue(value.path)
    if (!path) {
      return { type: "invalid", name: stringValue(value.name, "Invalid folder"), reason: "folder item " + index + " requires path" }
    }
    return {
      type: "folder",
      path: path,
      name: stringValue(value.name),
      icon: stringValue(value.icon)
    }
  }

  return {
    type: "invalid",
    name: stringValue(value.name, "Unsupported item"),
    reason: "item " + index + " has unsupported type: " + (type || "<empty>")
  }
}

function normalizeConfig(input) {
  var value = typeof input === "string" ? JSON.parse(input) : input
  if (!isPlainObject(value)) throw new Error("configuration must be an object")
  if (value.version !== 1) throw new Error("configuration version must be 1")

  var rawItems = Array.isArray(value.items) ? value.items : []
  var items = []
  for (var i = 0; i < rawItems.length; i++) items.push(normalizeItem(rawItems[i], i))

  var layer = stringValue(value.layer, "top").toLowerCase()
  if (layer !== "top" && layer !== "overlay") layer = "top"

  var screens = uniqueStrings(value.screens, ["*"])
  if (screens.length === 0) screens = ["*"]

  return {
    version: 1,
    edge: "bottom",
    screens: screens,
    openDelay: clampNumber(value.openDelay, 45, 0, 1000),
    closeDelay: clampNumber(value.closeDelay, 380, 50, 3000),
    layer: layer,
    iconSize: clampNumber(value.iconSize, 40, 24, 64),
    activationWidth: clampNumber(value.activationWidth, 360, 120, 1600),
    closeOnLaunch: value.closeOnLaunch !== false,
    items: items
  }
}

function validateConfig(input) {
  try {
    return { ok: true, value: normalizeConfig(input), error: null }
  } catch (error) {
    return { ok: false, value: null, error: String(error && error.message ? error.message : error) }
  }
}

function loadConfig(input, lastValid, safeDefault) {
  var parsed = validateConfig(input)
  if (parsed.ok) return { value: parsed.value, valid: true, error: null }
  var fallback = lastValid !== null && lastValid !== undefined ? lastValid : safeDefault
  return { value: cloneJson(fallback), valid: false, error: parsed.error }
}

function expandHome(path, home) {
  var value = stringValue(path)
  var base = String(home || "")
  if (value === "~") return base
  if (value.indexOf("~/") === 0) return base + value.slice(1)
  return value
}

function safeDefaultConfig(home) {
  return normalizeConfig({
    version: 1,
    screens: ["*"],
    items: [
      { type: "folder", name: "Home", path: String(home || "~") },
      { type: "folder", name: "Downloads", path: String(home || "~") + "/Downloads" }
    ]
  })
}

var STARTER_GROUPS = [
  ["com.mitchellh.ghostty", "org.gnome.Console", "Alacritty", "kitty", "org.wezfurlong.wezterm"],
  ["chromium", "google-chrome", "firefox", "org.mozilla.firefox", "brave-browser"],
  ["org.gnome.Nautilus", "thunar", "org.kde.dolphin"],
  ["dev.zed.Zed", "code", "codium", "com.visualstudio.code"]
]

function catalogLookup(catalog) {
  var lookup = {}
  var values = Array.isArray(catalog) ? catalog : []
  for (var i = 0; i < values.length; i++) {
    var id = stringValue(values[i] && values[i].id).replace(/\.desktop$/, "")
    if (id) lookup[id.toLowerCase()] = id
  }
  return lookup
}

function starterConfig(catalog, home) {
  var lookup = catalogLookup(catalog)
  var apps = []
  var used = {}
  for (var groupIndex = 0; groupIndex < STARTER_GROUPS.length; groupIndex++) {
    var group = STARTER_GROUPS[groupIndex]
    for (var candidateIndex = 0; candidateIndex < group.length; candidateIndex++) {
      var found = lookup[group[candidateIndex].toLowerCase()]
      if (!found || used[found]) continue
      used[found] = true
      apps.push({ type: "app", desktopId: found })
      break
    }
  }

  var items = apps.slice()
  if (items.length > 0) items.push({ type: "separator" })
  items.push({ type: "folder", name: "Home", path: "~" })
  items.push({ type: "folder", name: "Downloads", path: "~/Downloads" })

  return normalizeConfig({
    version: 1,
    edge: "bottom",
    screens: ["*"],
    openDelay: 45,
    closeDelay: 380,
    layer: "top",
    iconSize: 40,
    activationWidth: 360,
    closeOnLaunch: true,
    items: items
  })
}

function catalogById(catalog) {
  var values = Array.isArray(catalog) ? catalog : []
  var lookup = {}
  for (var i = 0; i < values.length; i++) {
    var entry = values[i] || {}
    var id = stringValue(entry.id).replace(/\.desktop$/, "")
    if (id) lookup[id.toLowerCase()] = entry
  }
  return lookup
}

function resolveItems(config, catalog, home) {
  var lookup = catalogById(catalog)
  var items = config && Array.isArray(config.items) ? config.items : []
  var result = []
  for (var i = 0; i < items.length; i++) {
    var item = cloneJson(items[i])
    item.key = item.type + ":" + i
    if (item.type === "app") {
      var entry = lookup[String(item.desktopId || "").toLowerCase()]
      item.available = !!entry
      item.name = item.name || stringValue(entry && entry.name, item.desktopId)
      item.entryIcon = stringValue(entry && entry.icon)
      item.startupClass = stringValue(entry && entry.startupClass)
      if (!entry) item.reason = "Desktop entry is not installed: " + item.desktopId
    } else if (item.type === "folder") {
      item.path = expandHome(item.path, home)
      item.name = item.name || item.path.split("/").pop() || "Folder"
      item.available = true
    } else if (item.type === "invalid") {
      item.available = false
    }
    result.push(item)
  }
  return result
}

function screenEnabled(screens, screenName) {
  var values = Array.isArray(screens) ? screens : ["*"]
  return values.indexOf("*") !== -1 || values.indexOf(String(screenName || "")) !== -1
}

function normalizedAppId(value) {
  return stringValue(value).replace(/\.desktop$/, "").toLowerCase()
}

function toplevelMatches(item, appId) {
  if (!item || item.type !== "app") return false
  var target = normalizedAppId(appId)
  if (!target) return false
  var desktopId = normalizedAppId(item.desktopId)
  var startupClass = normalizedAppId(item.startupClass)
  return target === desktopId || (!!startupClass && target === startupClass)
}

function serializeConfig(config) {
  return JSON.stringify(normalizeConfig(config), null, 2) + "\n"
}

if (typeof module !== "undefined") {
  module.exports = {
    isPlainObject: isPlainObject,
    cloneJson: cloneJson,
    normalizeItem: normalizeItem,
    normalizeConfig: normalizeConfig,
    validateConfig: validateConfig,
    loadConfig: loadConfig,
    expandHome: expandHome,
    safeDefaultConfig: safeDefaultConfig,
    starterConfig: starterConfig,
    resolveItems: resolveItems,
    screenEnabled: screenEnabled,
    toplevelMatches: toplevelMatches,
    serializeConfig: serializeConfig
  }
}
