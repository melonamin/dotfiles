.pragma library

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

// JSONC here intentionally mirrors Omarchy's authoring format: full-line //
// comments and trailing commas. Restricting comments to their own line keeps
// URLs and shell strings containing // untouched.
function stripJsonc(raw) {
  return String(raw || "")
    .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
    .replace(/,(\s*[}\]])/g, "$1")
}

function parentFor(id, rawParent) {
  if (rawParent !== undefined && rawParent !== null) return String(rawParent)
  var at = id.lastIndexOf(".")
  return at >= 0 ? id.slice(0, at) : "root"
}

function normalizeItem(id, raw, order) {
  var item = clone(raw)
  item.id = id
  item.parent = parentFor(id, raw.parent)
  item.key = String(raw.key || "").toLowerCase()
  item.label = String(raw.label || id)
  item.icon = String(raw.icon || "")
  item.order = order
  item.sticky = raw.sticky === true
  item.hidden = raw.hidden === true
  item.notify = raw.notify === true ? "always" : String(raw.notify || "never")
  return item
}

function validateAction(action, path, errors) {
  if (!isObject(action)) {
    errors.push(path + ": action must be an object")
    return
  }

  var type = String(action.type || "")
  var supported = ["launch", "open", "command", "shell", "omarchy", "workflow", "provider"]
  if (supported.indexOf(type) === -1) {
    errors.push(path + ": unsupported action type '" + type + "'")
    return
  }

  if (type === "launch" && !action.desktop) errors.push(path + ": launch requires desktop")
  if (type === "open" && !action.target) errors.push(path + ": open requires target")
  if (type === "command" && (!Array.isArray(action.argv) || action.argv.length === 0))
    errors.push(path + ": command requires a non-empty argv array")
  if (type === "shell" && !action.command) errors.push(path + ": shell requires command")
  if (type === "omarchy" && !Array.isArray(action.args)) errors.push(path + ": omarchy requires args")
  if (type === "workflow" && (!Array.isArray(action.steps) || action.steps.length === 0))
    errors.push(path + ": workflow requires non-empty steps")
  if (type === "provider") {
    var hasArgv = Array.isArray(action.argv) && action.argv.length > 0
    if (!hasArgv && !action.command) errors.push(path + ": provider requires argv or command")
  }
}

function normalize(parsed) {
  var errors = []
  if (!isObject(parsed)) return { config: null, errors: ["Configuration root must be an object"] }
  if (parsed.version !== 1) errors.push("version: expected 1")
  if (!isObject(parsed.items)) errors.push("items: expected an object")

  var rawItems = isObject(parsed.items) ? parsed.items : {}
  var items = {
    root: {
      id: "root",
      parent: "",
      key: "",
      label: "Home",
      icon: "",
      order: -1,
      sticky: false,
      hidden: false,
      notify: "never"
    }
  }
  var order = []
  var index = 0

  for (var id in rawItems) {
    if (!id || id === "root") {
      errors.push("items: 'root' is reserved")
      continue
    }
    if (!isObject(rawItems[id])) {
      errors.push("items." + id + ": expected an object")
      continue
    }
    var item = normalizeItem(id, rawItems[id], index++)
    if (!item.key || item.key.length !== 1)
      errors.push("items." + id + ": key must be one printable character")
    if (!item.action && item.sticky)
      errors.push("items." + id + ": sticky is only valid on actions")
    if (item.action) validateAction(item.action, "items." + id + ".action", errors)
    items[id] = item
    order.push(id)
  }

  var siblingKeys = {}
  for (var i = 0; i < order.length; i++) {
    var current = items[order[i]]
    if (!items[current.parent]) {
      errors.push("items." + current.id + ": parent '" + current.parent + "' does not exist")
      continue
    }
    var keyId = current.parent + "\u0000" + current.key
    if (siblingKeys[keyId])
      errors.push("items." + current.id + ": key '" + current.key + "' conflicts with " + siblingKeys[keyId])
    else siblingKeys[keyId] = current.id
  }

  var ui = isObject(parsed.ui) ? clone(parsed.ui) : {}
  ui.start = String(ui.start || "trail")
  ui.onPause = String(ui.onPause || "board")
  ui.onError = String(ui.onError || "board")
  ui.sticky = String(ui.sticky || "corner")
  ui.expandAfterMs = Math.max(0, Number(ui.expandAfterMs || 700))
  var rawSequenceTimeout = ui.sequenceTimeoutMs === undefined
    ? 0
    : Number(ui.sequenceTimeoutMs)
  ui.sequenceTimeoutMs = !isFinite(rawSequenceTimeout) || rawSequenceTimeout <= 0
    ? 0
    : Math.max(250, rawSequenceTimeout)

  var providers = isObject(parsed.providers) ? clone(parsed.providers) : {}
  providers.timeoutMs = Math.max(250, Number(providers.timeoutMs || 2500))

  return {
    config: {
      version: 1,
      ui: ui,
      providers: providers,
      items: items,
      itemOrder: order
    },
    errors: errors
  }
}

function parse(raw) {
  try {
    return normalize(JSON.parse(stripJsonc(raw)))
  } catch (error) {
    return { config: null, errors: ["Invalid JSONC: " + error] }
  }
}

function children(config, parentId) {
  var result = []
  if (!config || !config.items) return result
  var order = config.itemOrder || []
  for (var i = 0; i < order.length; i++) {
    var item = config.items[order[i]]
    if (item && item.parent === parentId && !item.hidden) result.push(item)
  }
  return result
}
