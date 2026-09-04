// Compose's dependency-free core. Keep this file compatible with both the
// QML JavaScript engine and Node's CommonJS loader.

var DEFAULT_SHORTCUT = "SUPER + CTRL + SEMICOLON"
var LOCAL_SECTION_HEADER = "# --- Omarchy Compose: local rules ---"

var MODIFIER_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"]
var MODIFIER_ALIASES = {
  CMD: "SUPER", COMMAND: "SUPER", META: "SUPER", MOD4: "SUPER", SUPER: "SUPER",
  CONTROL: "CTRL", CTRL: "CTRL", ALT: "ALT", MOD1: "ALT", SHIFT: "SHIFT"
}
var KEY_ALIASES = {
  ";": "SEMICOLON", SEMICOLON: "SEMICOLON", RETURN: "RETURN", ENTER: "RETURN",
  ESC: "ESCAPE", ESCAPE: "ESCAPE", SPACE: "SPACE", TAB: "TAB",
  COMMA: "COMMA", PERIOD: "PERIOD", SLASH: "SLASH"
}

var KEYSYM_UTF8 = {
  space: " ", Tab: "\t", Return: "\r", Linefeed: "\n", Clear: "\v", BackSpace: "\b",
  nobreakspace: "\u00a0", exclamdown: "\u00a1", cent: "\u00a2", sterling: "\u00a3",
  currency: "\u00a4", yen: "\u00a5", brokenbar: "\u00a6", section: "\u00a7",
  diaeresis: "\u00a8", copyright: "\u00a9", ordfeminine: "\u00aa", guillemotleft: "\u00ab",
  notsign: "\u00ac", hyphen: "\u00ad", registered: "\u00ae", macron: "\u00af",
  degree: "\u00b0", plusminus: "\u00b1", twosuperior: "\u00b2", threesuperior: "\u00b3",
  acute: "\u00b4", mu: "\u00b5", paragraph: "\u00b6", periodcentered: "\u00b7",
  cedilla: "\u00b8", onesuperior: "\u00b9", masculine: "\u00ba", guillemotright: "\u00bb",
  onequarter: "\u00bc", onehalf: "\u00bd", threequarters: "\u00be", questiondown: "\u00bf",
  Agrave: "\u00c0", Aacute: "\u00c1", Acircumflex: "\u00c2", Atilde: "\u00c3",
  Adiaeresis: "\u00c4", Aring: "\u00c5", AE: "\u00c6", Ccedilla: "\u00c7",
  Egrave: "\u00c8", Eacute: "\u00c9", Ecircumflex: "\u00ca", Ediaeresis: "\u00cb",
  Igrave: "\u00cc", Iacute: "\u00cd", Icircumflex: "\u00ce", Idiaeresis: "\u00cf",
  ETH: "\u00d0", Ntilde: "\u00d1", Ograve: "\u00d2", Oacute: "\u00d3",
  Ocircumflex: "\u00d4", Otilde: "\u00d5", Odiaeresis: "\u00d6", multiply: "\u00d7",
  Oslash: "\u00d8", Ugrave: "\u00d9", Uacute: "\u00da", Ucircumflex: "\u00db",
  Udiaeresis: "\u00dc", Yacute: "\u00dd", THORN: "\u00de", ssharp: "\u00df",
  agrave: "\u00e0", aacute: "\u00e1", acircumflex: "\u00e2", atilde: "\u00e3",
  adiaeresis: "\u00e4", aring: "\u00e5", ae: "\u00e6", ccedilla: "\u00e7",
  egrave: "\u00e8", eacute: "\u00e9", ecircumflex: "\u00ea", ediaeresis: "\u00eb",
  igrave: "\u00ec", iacute: "\u00ed", icircumflex: "\u00ee", idiaeresis: "\u00ef",
  eth: "\u00f0", ntilde: "\u00f1", ograve: "\u00f2", oacute: "\u00f3",
  ocircumflex: "\u00f4", otilde: "\u00f5", odiaeresis: "\u00f6", division: "\u00f7",
  oslash: "\u00f8", ugrave: "\u00f9", uacute: "\u00fa", ucircumflex: "\u00fb",
  udiaeresis: "\u00fc", yacute: "\u00fd", thorn: "\u00fe", ydiaeresis: "\u00ff"
}

// Legacy X11 keysyms which libxkbcommon converts even though keysymdef.h has
// no U+ annotation. Everything else is derived from that header at runtime.
var LEGACY_KEYSYM_CODEPOINTS = {
  0x8a2: 0x250c,
  0x8a3: 0x2500,
  0x8a6: 0x2502,
  0xaac: 0x2423,
  0xabc: 0x27e8,
  0xabd: 0x2e,
  0xabe: 0x27e9,
  0xaca: 0x2613,
  0xacc: 0x25c1,
  0xacd: 0x25b7,
  0xace: 0x25cb,
  0xacf: 0x25af,
  0xadb: 0x25ac,
  0xadc: 0x25c0,
  0xadd: 0x25b6,
  0xade: 0x25cf,
  0xadf: 0x25ae,
  0xae0: 0x25e6,
  0xae1: 0x25ab,
  0xae2: 0x25ad,
  0xae3: 0x25b3,
  0xae4: 0x25bd,
  0xae5: 0x2606,
  0xae6: 0x2022,
  0xae7: 0x25aa,
  0xae8: 0x25b2,
  0xae9: 0x25bc,
  0xaea: 0x261c,
  0xaeb: 0x261e,
  0xba3: 0x3c,
  0xba6: 0x3e,
  0xba8: 0x2228,
  0xba9: 0x2227,
  0xbc0: 0xaf,
  0xbc3: 0x2229,
  0xbc6: 0x5f,
  0xbd6: 0x222a,
  0xbd8: 0x2283,
  0xbda: 0x2282,
  0xdde: 0xe3e,
  0xeff: 0x20a9
}

function copyObject(value) {
  var out = {}
  if (!value) return out
  for (var key in value) out[key] = value[key]
  return out
}

function normalizeShortcut(value) {
  var text = String(value === undefined || value === null ? DEFAULT_SHORTCUT : value).trim()
  if (!text) return ""
  var raw = text.replace(/\s*\+\s*/g, "+").split("+")
  var modifiers = {}
  var key = ""
  for (var i = 0; i < raw.length; i++) {
    var part = String(raw[i] || "").trim().toUpperCase()
    if (!part) continue
    if (MODIFIER_ALIASES[part]) modifiers[MODIFIER_ALIASES[part]] = true
    else key = KEY_ALIASES[part] || part
  }
  if (!key) return ""
  var out = []
  for (var m = 0; m < MODIFIER_ORDER.length; m++) {
    if (modifiers[MODIFIER_ORDER[m]]) out.push(MODIFIER_ORDER[m])
  }
  out.push(key)
  return out.join(" + ")
}

function shortcutChord(value) {
  var normalized = normalizeShortcut(value)
  if (!normalized) return { modmask: 0, key: "" }
  var parts = normalized.split(/\s*\+\s*/)
  var masks = { SHIFT: 1, CTRL: 4, ALT: 8, SUPER: 64 }
  var modmask = 0
  for (var index = 0; index < parts.length - 1; index++) modmask |= masks[parts[index]] || 0
  return { modmask: modmask, key: String(parts[parts.length - 1] || "").toUpperCase() }
}

function parseModePayload(payload) {
  var parsed = payload
  if (payload === undefined || payload === null || payload === "") parsed = {}
  else if (typeof payload === "string") {
    try { parsed = JSON.parse(payload) } catch (error) { parsed = {} }
  }
  var mode = parsed && String(parsed.mode || "").toLowerCase()
  return mode === "studio" ? "studio" : "quick"
}

function findPluginEntry(config, pluginId) {
  var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
  for (var i = 0; i < plugins.length; i++) {
    if (plugins[i] && String(plugins[i].id || "") === String(pluginId)) return plugins[i]
  }
  return null
}

function settingsFrom(entry) {
  return { shortcut: normalizeShortcut(entry && entry.shortcut !== undefined ? entry.shortcut : DEFAULT_SHORTCUT) }
}

function writePluginSetting(config, pluginId, key, value) {
  if (!config || typeof config !== "object") return false
  if (!Array.isArray(config.plugins)) config.plugins = []
  var entry = findPluginEntry(config, pluginId)
  if (!entry) {
    entry = { id: pluginId }
    config.plugins.push(entry)
  }
  entry[key] = value
  return true
}

function appendUtf8(bytes, value) {
  var text = String(value || "")
  for (var index = 0; index < text.length; index++) {
    var code = text.charCodeAt(index)
    if (code >= 0xd800 && code <= 0xdbff && index + 1 < text.length) {
      var low = text.charCodeAt(index + 1)
      if (low >= 0xdc00 && low <= 0xdfff) { code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00); index++ }
    }
    if (code < 0x80) bytes.push(code)
    else if (code < 0x800) bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f))
    else if (code < 0x10000) bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
    else bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
  }
}

function decodeUtf8(bytes) {
  var out = ""
  var errors = []
  for (var index = 0; index < bytes.length;) {
    var first = bytes[index++]
    if (first < 0x80) { out += String.fromCharCode(first); continue }
    var needed = first >= 0xc2 && first <= 0xdf ? 1 : first >= 0xe0 && first <= 0xef ? 2 : first >= 0xf0 && first <= 0xf4 ? 3 : -1
    if (needed < 0 || index + needed > bytes.length) {
      errors.push("invalid UTF-8 byte escape")
      out += "\ufffd"
      continue
    }
    var code = first & (needed === 1 ? 0x1f : needed === 2 ? 0x0f : 0x07)
    var valid = true
    for (var offset = 0; offset < needed; offset++) {
      var next = bytes[index + offset]
      if ((next & 0xc0) !== 0x80) { valid = false; break }
      code = (code << 6) | (next & 0x3f)
    }
    if (!valid || (needed === 2 && code < 0x800) || (needed === 3 && code < 0x10000) || code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff)) {
      errors.push("invalid UTF-8 byte escape")
      out += "\ufffd"
      continue
    }
    index += needed
    out += codePointString(code)
  }
  return { value: out, errors: errors }
}

function decodeComposeString(raw) {
  var bytes = []
  var errors = []
  for (var i = 0; i < raw.length; i++) {
    var ch = raw.charAt(i)
    if (ch !== "\\") {
      var high = ch.charCodeAt(0)
      if (high >= 0xd800 && high <= 0xdbff && i + 1 < raw.length) {
        var literalLow = raw.charCodeAt(i + 1)
        if (literalLow >= 0xdc00 && literalLow <= 0xdfff) ch += raw.charAt(++i)
      }
      appendUtf8(bytes, ch)
      continue
    }
    if (i + 1 >= raw.length) { errors.push("trailing backslash"); break }
    var next = raw.charAt(++i)
    var simple = { "\\": "\\", '"': '"' }
    if (simple[next] !== undefined) { appendUtf8(bytes, simple[next]); continue }
    if (/[0-7]/.test(next)) {
      var octal = next
      while (i + 1 < raw.length && octal.length < 3 && /[0-7]/.test(raw.charAt(i + 1))) octal += raw.charAt(++i)
      bytes.push(parseInt(octal, 8) & 0xff)
      continue
    }
    if (next === "x") {
      var hex = ""
      while (i + 1 < raw.length && hex.length < 2 && /[0-9a-fA-F]/.test(raw.charAt(i + 1))) hex += raw.charAt(++i)
      if (!hex) errors.push("invalid hexadecimal escape")
      else bytes.push(parseInt(hex, 16) & 0xff)
      continue
    }
    appendUtf8(bytes, next)
  }
  var decoded = decodeUtf8(bytes)
  return { value: decoded.value, errors: errors.concat(decoded.errors) }
}

function encodeComposeString(value) {
  var input = String(value === undefined || value === null ? "" : value)
  var out = ""
  for (var index = 0; index < input.length; index++) {
    var character = input.charAt(index)
    var code = input.charCodeAt(index)
    if (character === "\\") out += "\\\\"
    else if (character === '"') out += '\\"'
    else if (code < 0x20 || code === 0x7f) out += "\\x" + ("0" + code.toString(16)).slice(-2)
    else out += character
  }
  return out
}

function codePointString(code) {
  if (!(code > 0) || code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff)) return ""
  if (code <= 0xffff) return String.fromCharCode(code)
  code -= 0x10000
  return String.fromCharCode(0xd800 + (code >> 10), 0xdc00 + (code & 0x3ff))
}

function keysymToUtf8(name, definitions) {
  var key = String(name || "")
  if (!key || key === "NoSymbol" || key === "VoidSymbol") return ""
  if (definitions && typeof definitions[key] === "number") return codePointString(definitions[key])
  if (KEYSYM_UTF8[key] !== undefined) return KEYSYM_UTF8[key]
  if (/^U[0-9a-fA-F]{1,6}$/.test(key)) return codePointString(parseInt(key.slice(1), 16))
  if (key.length === 1) return key
  return ""
}

function parseKeysymDefinitions(raw) {
  var out = {}
  var lines = String(raw || "").split(/\r?\n/)
  var entries = []
  var unicodeByValue = {}
  for (var i = 0; i < lines.length; i++) {
    var bundled = lines[i].match(/^([A-Za-z0-9_]+)\t(-|[0-9a-fA-F]+)$/)
    if (bundled) {
      if (!Object.prototype.hasOwnProperty.call(out, bundled[1])) out[bundled[1]] = bundled[2] === "-" ? null : parseInt(bundled[2], 16)
      continue
    }
    var match = lines[i].match(/^#define\s+(XK_|XF86XK_|SunXK_|DXK_|hpXK_|osfXK_)([A-Za-z0-9_]+)\s+(?:0x([0-9a-fA-F]+)|_EVDEVK\(0x([0-9a-fA-F]+)\))(?:\s+\/\*\s*<?U\+([0-9a-fA-F]{4,6}))?/)
    if (!match) continue
    var namespacePrefix = { XK_: "", XF86XK_: "XF86", SunXK_: "Sun", DXK_: "D", hpXK_: "hp", osfXK_: "osf" }[match[1]]
    var name = namespacePrefix + match[2]
    var value = match[3] ? parseInt(match[3], 16) : 0x10081000 + parseInt(match[4], 16)
    var codePoint = match[5] ? parseInt(match[5], 16) : null
    var numericKey = name.match(/^XF86Numeric([0-9])$/)
    if (codePoint === null && numericKey) codePoint = numericKey[1].charCodeAt(0)
    else if (codePoint === null && name === "XF86NumericStar") codePoint = 0x2a
    else if (codePoint === null && name === "XF86NumericPound") codePoint = 0x23
    if (codePoint === null && ((value >= 0x20 && value <= 0x7e) || (value >= 0xa0 && value <= 0xff))) codePoint = value
    else if (codePoint === null && value >= 0x01000100 && value <= 0x0110ffff) codePoint = value & 0x00ffffff
    else if (codePoint === null && LEGACY_KEYSYM_CODEPOINTS[value] !== undefined) codePoint = LEGACY_KEYSYM_CODEPOINTS[value]
    if (codePoint !== null) unicodeByValue[value] = codePoint
    entries.push({ name: name, value: value, codePoint: codePoint })
  }
  for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
    var entry = entries[entryIndex]
    if (!Object.prototype.hasOwnProperty.call(out, entry.name)) {
      out[entry.name] = entry.codePoint !== null ? entry.codePoint : (unicodeByValue[entry.value] !== undefined ? unicodeByValue[entry.value] : null)
    }
  }
  return out
}

function knownKeysym(name, definitions) {
  var key = String(name || "")
  if (!key) return false
  if (definitions && Object.prototype.hasOwnProperty.call(definitions, key)) return true
  if (Object.prototype.hasOwnProperty.call(KEYSYM_UTF8, key)) return true
  return /^U[0-9a-fA-F]{1,6}$/.test(key) && keysymToUtf8(key, definitions) !== ""
}

function validModifierSyntax(value) {
  var text = String(value || "").trim()
  if (!text) return true
  if (/^None$/i.test(text)) return true
  return /^!?(?:\s*~?\s*(?:Ctrl|Lock|Caps|Shift|Alt|Meta)\b)+\s*$/i.test(text)
}

function parseResult(text, keysymDefinitions) {
  var index = 0
  var length = text.length
  function spaces() { while (index < length && /\s/.test(text.charAt(index))) index++ }
  spaces()
  var stringRaw = null
  var decoded = null
  var errors = []
  if (text.charAt(index) === '"') {
    index++
    var buffer = ""
    var closed = false
    while (index < length) {
      var ch = text.charAt(index++)
      if (ch === '"') { closed = true; break }
      if (ch === "\\" && index < length) buffer += ch + text.charAt(index++)
      else buffer += ch
    }
    if (!closed) errors.push("unterminated result string")
    stringRaw = buffer
    decoded = decodeComposeString(buffer)
    errors = errors.concat(decoded.errors)
  }
  spaces()
  var keysym = ""
  var keysymMatch = text.slice(index).match(/^([A-Za-z0-9_]+)\b/)
  if (keysymMatch) { keysym = keysymMatch[1]; index += keysymMatch[0].length }
  spaces()
  var comment = ""
  if (text.charAt(index) === "#") { comment = text.slice(index + 1).trim(); index = length }
  else if (index < length) errors.push("unexpected result text")
  if (stringRaw === null && !keysym) errors.push("rule has no result")
  var output = decoded ? decoded.value : keysymToUtf8(keysym, keysymDefinitions)
  return {
    stringRaw: stringRaw,
    resultString: decoded ? decoded.value : null,
    resultKeysym: keysym,
    output: output,
    insertable: output.length > 0,
    comment: comment,
    errors: errors
  }
}

function sequenceRelation(left, right) {
  var a = left || []
  var b = right || []
  var minimum = Math.min(a.length, b.length)
  for (var i = 0; i < minimum; i++) if (a[i] !== b[i]) return "none"
  if (a.length === b.length) return "exact"
  return a.length < b.length ? "left-prefix" : "right-prefix"
}

function parseRuleLine(content, keysymDefinitions) {
  var colon = content.indexOf(":")
  if (colon < 0) return { valid: false, errors: ["missing result separator"] }
  var lhs = content.slice(0, colon)
  var rhs = content.slice(colon + 1)
  var sequence = []
  var eventModifiers = []
  var match
  var cursor = 0
  var sequencePattern = /<([^>\r\n]+)>/g
  while ((match = sequencePattern.exec(lhs)) !== null) {
    var modifiers = lhs.slice(cursor, match.index).trim().replace(/\s+/g, " ")
    if (/[<>:]/.test(modifiers) || !validModifierSyntax(modifiers)) return { valid: false, errors: ["invalid modifier syntax"] }
    sequence.push(match[1].trim())
    eventModifiers.push(modifiers)
    cursor = sequencePattern.lastIndex
  }
  if (!sequence.length) return { valid: false, errors: ["rule has no event sequence"] }
  if (lhs.slice(cursor).trim()) return { valid: false, errors: ["invalid modifier syntax"] }
  var result = parseResult(rhs, keysymDefinitions)
  return {
    valid: result.errors.length === 0,
    errors: result.errors,
    modifiers: eventModifiers[0] || "",
    eventModifiers: eventModifiers,
    sequence: sequence,
    displaySequence: sequence.map(function(key) { return key === "Multi_key" ? "Compose" : key }).join(" › "),
    resultStringRaw: result.stringRaw,
    resultString: result.resultString,
    resultKeysym: result.resultKeysym,
    output: result.output,
    insertable: result.insertable,
    comment: result.comment
  }
}

function parseDocument(raw, options) {
  var text = String(raw === undefined || raw === null ? "" : raw)
  var opts = options || {}
  var sourceId = String(opts.sourceId || opts.path || "root")
  var nodes = []
  var diagnostics = []
  var newlineStyle = text.indexOf("\r\n") >= 0 ? "\r\n" : text.indexOf("\n") >= 0 ? "\n" : text.indexOf("\r") >= 0 ? "\r" : "\n"
  var offset = 0
  var line = 1
  while (offset < text.length) {
    var nextNewline = text.slice(offset).search(/\r\n|\n|\r/)
    var end
    if (nextNewline < 0) end = text.length
    else {
      var at = offset + nextNewline
      end = at + (text.slice(at, at + 2) === "\r\n" ? 2 : 1)
    }
    var rawLine = text.slice(offset, end)
    var content = rawLine.replace(/(?:\r\n|\n|\r)$/, "")
    var node = { raw: rawLine, start: offset, end: end, line: line, sourceId: sourceId }
    if (/^\s*$/.test(content)) node.type = "blank"
    else if (/^\s*#/.test(content)) node.type = "comment"
    else {
      var include = content.match(/^\s*include\s+"((?:\\.|[^"\\])*)"\s*(?:#\s*(.*))?$/)
      if (include) {
        node.type = "include"
        node.includePath = decodeComposeString(include[1]).value
        node.comment = include[2] || ""
      } else if (content.indexOf(":") >= 0 || /<[^>]+>/.test(content)) {
        var parsed = parseRuleLine(content, opts.keysymDefinitions)
        for (var key in parsed) node[key] = parsed[key]
        node.type = parsed.valid ? "rule" : "malformed"
        if (!parsed.valid) diagnostics.push({ kind: "malformed", severity: "error", sourceId: sourceId, line: line, message: parsed.errors.join("; ") })
      } else node.type = "unknown"
    }
    nodes.push(node)
    offset = end
    line++
  }
  return { raw: text, sourceId: sourceId, path: opts.path || "", nodes: nodes, diagnostics: diagnostics, newlineStyle: newlineStyle }
}

function cloneRule(node, source, index) {
  var rule = copyObject(node)
  rule.source = source || {}
  rule.sourceName = source && source.name ? source.name : source && source.kind ? source.kind : ""
  rule.sourceKind = source && source.kind ? source.kind : "Included"
  rule.path = source && source.path ? source.path : ""
  rule.active = true
  rule.shadowedBy = null
  rule.shadows = []
  rule.order = index
  rule.id = String(rule.sourceId) + ":" + String(rule.start)
  cacheRuleSearchFields(rule)
  return rule
}

function trieNode() { return { children: {}, activeIndex: -1 } }

function trieChild(node, symbol, create) {
  var key = "$" + String(symbol)
  if (!Object.prototype.hasOwnProperty.call(node.children, key)) {
    if (!create) return null
    node.children[key] = trieNode()
  }
  return node.children[key]
}

function collectActiveTrieIndices(node, output) {
  if (node.activeIndex >= 0) output.push(node.activeIndex)
  for (var key in node.children) {
    if (Object.prototype.hasOwnProperty.call(node.children, key)) collectActiveTrieIndices(node.children[key], output)
  }
}

function resolveEffectiveLibrary(sources) {
  var all = []
  var diagnostics = []
  var activeTrie = trieNode()
  var terminalNodes = []
  var list = Array.isArray(sources) ? sources : []
  for (var s = 0; s < list.length; s++) {
    var source = list[s]
    var doc = source.document || source
    var nodes = doc && Array.isArray(doc.nodes) ? doc.nodes : []
    for (var n = 0; n < nodes.length; n++) {
      if (nodes[n].type !== "rule") continue
      var next = cloneRule(nodes[n], source, all.length)
      var trie = activeTrie
      var conflicting = []
      for (var eventIndex = 0; eventIndex < next.sequence.length; eventIndex++) {
        if (trie.activeIndex >= 0) conflicting.push(trie.activeIndex)
        trie = trieChild(trie, next.sequence[eventIndex], true)
      }
      if (trie.activeIndex >= 0) conflicting.push(trie.activeIndex)
      for (var childKey in trie.children) {
        if (Object.prototype.hasOwnProperty.call(trie.children, childKey)) collectActiveTrieIndices(trie.children[childKey], conflicting)
      }
      conflicting.sort(function(left, right) { return left - right })
      for (var p = 0; p < conflicting.length; p++) {
        var previous = all[conflicting[p]]
        var relation = sequenceRelation(previous.sequence, next.sequence)
        previous.active = false
        previous.shadowedBy = next.id
        next.shadows.push(previous.id)
        terminalNodes[conflicting[p]].activeIndex = -1
        diagnostics.push({
          kind: relation === "exact" ? "override" : "prefix",
          severity: relation === "exact" ? "info" : "warning",
          sourceId: next.sourceId,
          line: next.line,
          message: relation === "exact" ? "Later rule overrides the same sequence" : "Later prefix-conflicting rule shadows an earlier definition",
          ruleId: next.id,
          relatedRuleId: previous.id
        })
      }
      trie.activeIndex = all.length
      terminalNodes.push(trie)
      all.push(next)
    }
  }
  return { rules: all, activeRules: all.filter(function(rule) { return rule.active }), diagnostics: diagnostics }
}

function normalizedText(value) { return String(value || "").trim().toLowerCase() }

function cacheRuleSearchFields(rule) {
  rule._searchOutput = String(rule.output || "")
  rule._searchComment = String(rule.comment || "")
  rule._searchDisplaySequence = String(rule.displaySequence || "")
  rule._searchSequence = (rule.sequence || []).join(" ")
  rule._searchResultKeysym = String(rule.resultKeysym || "")
  rule._searchSourceName = String(rule.sourceName || "")
  rule._searchPath = String(rule.path || "")
  rule._searchFields = [
    rule._searchOutput, rule._searchComment, rule._searchDisplaySequence,
    rule._searchSequence, rule._searchResultKeysym, rule._searchSourceName,
    rule._searchPath
  ].map(normalizedText)
  return rule._searchFields
}

function cachedRuleSearchFields(rule) {
  if (rule._searchFields
      && rule._searchOutput === String(rule.output || "")
      && rule._searchComment === String(rule.comment || "")
      && rule._searchDisplaySequence === String(rule.displaySequence || "")
      && rule._searchSequence === (rule.sequence || []).join(" ")
      && rule._searchResultKeysym === String(rule.resultKeysym || "")
      && rule._searchSourceName === String(rule.sourceName || "")
      && rule._searchPath === String(rule.path || "")) return rule._searchFields
  return cacheRuleSearchFields(rule)
}

function fuzzyContainsNormalized(h, n) {
  if (!n) return true
  var at = 0
  for (var i = 0; i < h.length && at < n.length; i++) if (h.charAt(i) === n.charAt(at)) at++
  return at === n.length
}

function scoreRule(rule, query) {
  var needle = normalizedText(query)
  if (!needle) return 0
  var fields = cachedRuleSearchFields(rule)
  var best = -1
  for (var i = 0; i < fields.length; i++) {
    var field = fields[i]
    if (!field) continue
    if (field === needle) best = Math.max(best, 1000 - i)
    else if (field.indexOf(needle) === 0) best = Math.max(best, 800 - i)
    else if (field.indexOf(needle) >= 0) best = Math.max(best, 600 - i)
    else if (fuzzyContainsNormalized(field, needle)) best = Math.max(best, 300 - i)
  }
  return best
}

function outputGroupKey(rule) {
  if (rule && rule.insertable && rule.output !== undefined && rule.output !== null && String(rule.output) !== "") return "$output:" + String(rule.output)
  return "$rule:" + String(rule && (rule.id || rule.order) || "")
}

function quickSourcePreference(rule) {
  return ({ Mine: 4, Omarchy: 3, Included: 2, System: 1 })[rule && rule.sourceKind] || 0
}

function outputLookupKey(output) { return "$" + String(output === undefined || output === null ? "" : output) }

function parseEmojiOutputs(raw) {
  var values
  try { values = JSON.parse(String(raw || "")) }
  catch (error) { return {} }
  if (!Array.isArray(values)) return {}
  var outputs = {}
  for (var index = 0; index < values.length; index++) {
    if (values[index] && values[index].e) outputs[outputLookupKey(values[index].e)] = true
  }
  return outputs
}

function searchRules(rules, query, options) {
  var opts = options || {}
  var includeShadowed = opts.includeShadowed === true
  var sourceFilter = String(opts.source || "All")
  var groupOutputs = opts.groupOutputs === true
  var excludeOutputs = opts.excludeOutputs || null
  var max = opts.limit === undefined ? 100 : Math.max(0, Number(opts.limit) || 0)
  var scored = []
  var groupTotals = {}
  var list = Array.isArray(rules) ? rules : []
  for (var i = 0; i < list.length; i++) {
    var rule = list[i]
    if (!rule || (!includeShadowed && !rule.active)) continue
    if (sourceFilter === "Conflicts" && !rule.shadowedBy && (!rule.shadows || !rule.shadows.length)) continue
    if (sourceFilter !== "All" && sourceFilter !== "Conflicts" && rule.sourceKind !== sourceFilter) continue
    if (excludeOutputs && Object.prototype.hasOwnProperty.call(excludeOutputs, outputLookupKey(rule.output))) continue
    if (groupOutputs) {
      var totalKey = outputGroupKey(rule)
      groupTotals[totalKey] = (groupTotals[totalKey] || 0) + 1
    }
    var score = scoreRule(rule, query)
    if (normalizedText(query) && score < 0) continue
    scored.push({ rule: rule, score: score, index: i })
  }
  scored.sort(function(a, b) {
    if (a.score !== b.score) return b.score - a.score
    if (a.rule.active !== b.rule.active) return a.rule.active ? -1 : 1
    if (groupOutputs) {
      var preferenceDifference = quickSourcePreference(b.rule) - quickSourcePreference(a.rule)
      if (preferenceDifference) return preferenceDifference
      var lengthDifference = (a.rule.sequence || []).length - (b.rule.sequence || []).length
      if (lengthDifference) return lengthDifference
    }
    var aMine = a.rule.active && a.rule.sourceKind === "Mine" ? 1 : 0
    var bMine = b.rule.active && b.rule.sourceKind === "Mine" ? 1 : 0
    if (aMine !== bMine) return bMine - aMine
    return a.index - b.index
  })
  if (!groupOutputs) return scored.slice(0, max).map(function(item) { return item.rule })
  var grouped = []
  var seenOutputs = {}
  for (var scoredIndex = 0; scoredIndex < scored.length && grouped.length < max; scoredIndex++) {
    var groupKey = outputGroupKey(scored[scoredIndex].rule)
    if (seenOutputs[groupKey]) continue
    seenOutputs[groupKey] = true
    var groupedRule = copyObject(scored[scoredIndex].rule)
    groupedRule.alternativeCount = Math.max(0, (groupTotals[groupKey] || 1) - 1)
    grouped.push(groupedRule)
  }
  return grouped
}

function invisiblePreview(value) {
  var text = String(value === undefined || value === null ? "" : value)
  if (!text) return "∅"
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (ch === " ") out += "␠"
    else if (ch === "\t") out += "⇥"
    else if (ch === "\n") out += "↵\n"
    else if (ch === "\r") out += "␍"
    else if (ch === "\u200b") out += "ZWSP"
    else if (ch === "\u00a0") out += "NBSP"
    else if (ch.charCodeAt(0) < 32 || ch.charCodeAt(0) === 127) out += "U+" + ("0000" + ch.charCodeAt(0).toString(16).toUpperCase()).slice(-4)
    else out += ch
  }
  return out
}

function replaceSpan(document, node, replacement) {
  if (!document || !node || node.start < 0 || node.end < node.start || node.end > document.raw.length) throw new Error("invalid source span")
  return document.raw.slice(0, node.start) + String(replacement || "") + document.raw.slice(node.end)
}

function applySpanEdits(document, edits) {
  if (!document || !Array.isArray(edits) || !edits.length) throw new Error("span edits are required")
  var ordered = edits.slice().sort(function(left, right) { return left.node.start - right.node.start })
  for (var i = 0; i < ordered.length; i++) {
    var node = ordered[i].node
    if (!node || node.start < 0 || node.end < node.start || node.end > document.raw.length) throw new Error("invalid source span")
    if (i > 0 && ordered[i - 1].node.end > node.start) throw new Error("overlapping source spans")
  }
  var raw = document.raw
  for (var index = ordered.length - 1; index >= 0; index--) {
    var edit = ordered[index]
    raw = raw.slice(0, edit.node.start) + String(edit.replacement || "") + raw.slice(edit.node.end)
  }
  return raw
}

function replaceLocalDefinitions(document, nodes, anchor, ruleText) {
  var targets = Array.isArray(nodes) ? nodes : []
  var seen = {}
  var edits = []
  var anchorKey = anchor ? String(anchor.start) + ":" + String(anchor.end) : ""
  for (var i = 0; i < targets.length; i++) {
    var node = targets[i]
    if (!node) continue
    var key = String(node.start) + ":" + String(node.end)
    if (seen[key]) continue
    seen[key] = true
    var terminator = String(node.raw || "").match(/(\r\n|\n|\r)$/)
    edits.push({ node: node, replacement: key === anchorKey ? String(ruleText) + (terminator ? terminator[1] : "") : "" })
  }
  var replaced = applySpanEdits(document, edits)
  if (anchorKey) return replaced
  return appendLocalRule(parseDocument(replaced), ruleText)
}

function deleteRule(document, node) { return replaceSpan(document, node, "") }

function moveRuleToLocalSection(document, node, ruleText) {
  var withoutRule = deleteRule(document, node)
  return appendLocalRule(parseDocument(withoutRule), ruleText)
}

function appendLocalRule(document, ruleText) {
  var raw = document ? String(document.raw || "") : ""
  var newline = document && document.newlineStyle ? document.newlineStyle : "\n"
  var prefix = raw
  if (prefix && !/(?:\r\n|\n|\r)$/.test(prefix)) prefix += newline
  if (prefix.indexOf(LOCAL_SECTION_HEADER) < 0) {
    if (prefix && !/(?:\r\n|\n|\r){2}$/.test(prefix)) prefix += newline
    prefix += LOCAL_SECTION_HEADER + newline
  }
  return prefix + String(ruleText).replace(/(?:\r\n|\n|\r)+$/, "") + newline
}

function encodeRule(rule, newline) {
  var value = rule || {}
  var sequence = Array.isArray(value.sequence) ? value.sequence : []
  if (!sequence.length) throw new Error("sequence is required")
  var eventModifiers = Array.isArray(value.eventModifiers) ? value.eventModifiers : []
  var lhs = sequence.map(function(key, index) {
    var modifiers = eventModifiers[index]
    if (modifiers === undefined || modifiers === null) modifiers = index === 0 ? value.modifiers : ""
    modifiers = String(modifiers || "").trim()
    return (modifiers ? modifiers + " " : "") + "<" + String(key) + ">"
  }).join(" ")
  var rhs = ""
  if (value.resultString !== undefined && value.resultString !== null) rhs += '"' + encodeComposeString(value.resultString) + '"'
  if (value.resultKeysym) rhs += (rhs ? " " : "") + String(value.resultKeysym)
  if (!rhs) throw new Error("result is required")
  if (value.comment) rhs += " # " + String(value.comment).replace(/[\r\n]+/g, " ")
  return lhs + " : " + rhs + (newline === undefined ? "" : newline)
}

function validateCandidate(raw, options) {
  var document = parseDocument(raw, options)
  var errors = document.diagnostics.slice()
  var definitions = options && options.keysymDefinitions
  var validateKeysyms = definitions && Object.keys(definitions).length > 0
  for (var i = 0; i < document.nodes.length; i++) {
    var node = document.nodes[i]
    if (node.type === "rule" && validateKeysyms) {
      for (var eventIndex = 0; eventIndex < node.sequence.length; eventIndex++) {
        if (!knownKeysym(node.sequence[eventIndex], definitions)) {
          errors.push({ kind: "keysym", severity: "error", sourceId: document.sourceId, line: node.line, message: "unrecognized event keysym: " + node.sequence[eventIndex] })
        }
      }
      if (node.resultKeysym && !knownKeysym(node.resultKeysym, definitions)) {
        errors.push({ kind: "keysym", severity: "error", sourceId: document.sourceId, line: node.line, message: "unrecognized result keysym: " + node.resultKeysym })
      }
    }
  }
  return { valid: errors.length === 0, document: document, diagnostics: errors }
}

function expandIncludePath(template, environment) {
  var env = environment || {}
  return String(template || "")
    .replace(/%%/g, "\u0000")
    .replace(/%H/g, String(env.home || ""))
    .replace(/%S/g, String(env.system || "/usr/share/X11/locale"))
    .replace(/%L/g, String(env.localeCompose || ""))
    .replace(/\u0000/g, "%")
}

function classifySource(path, rootPath, omarchyPath) {
  var value = String(path || "")
  if (value === String(rootPath || "")) return "Mine"
  if (omarchyPath && value.indexOf(String(omarchyPath).replace(/\/$/, "") + "/") === 0) return "Omarchy"
  if (value.indexOf("/usr/share/X11/") === 0 || value.indexOf("/usr/local/share/X11/") === 0) return "System"
  return "Included"
}

function normalizePosixPath(value) {
  var path = String(value || "")
  var absolute = path.charAt(0) === "/"
  var parts = path.split("/")
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var part = parts[i]
    if (!part || part === ".") continue
    if (part === "..") {
      if (out.length && out[out.length - 1] !== "..") out.pop()
      else if (!absolute) out.push(part)
    } else out.push(part)
  }
  return (absolute ? "/" : "") + out.join("/") || (absolute ? "/" : ".")
}

function dirnamePosix(value) {
  var path = normalizePosixPath(value)
  var at = path.lastIndexOf("/")
  if (at <= 0) return at === 0 ? "/" : "."
  return path.slice(0, at)
}

function resolveIncludePath(template, containingPath, environment) {
  var mapped = environment && environment.includePaths ? environment.includePaths[String(containingPath) + "|" + String(template)] : ""
  if (mapped) return normalizePosixPath(mapped)
  var expanded = expandIncludePath(template, environment)
  if (expanded.charAt(0) !== "/") expanded = dirnamePosix(containingPath) + "/" + expanded
  return normalizePosixPath(expanded)
}

function resolveSourceGraph(sources, rootPath, environment) {
  var input = Array.isArray(sources) ? sources : []
  var env = environment || {}
  var map = {}
  var documents = []
  var diagnostics = []
  var segments = []
  for (var i = 0; i < input.length; i++) {
    var item = input[i]
    var path = normalizePosixPath(item.path)
    var source = copyObject(item)
    source.path = path
    source.kind = source.kind || classifySource(path, rootPath, env.omarchyPath)
    source.name = source.name || source.kind
    source.document = source.document || parseDocument(source.raw || "", {
      sourceId: path,
      path: path,
      keysymDefinitions: env.keysymDefinitions
    })
    map[path] = source
    documents.push(source)
    diagnostics = diagnostics.concat(source.document.diagnostics || [])
    if (source.unreadableRoot) {
      diagnostics.push({ kind: "unreadable-root", severity: "error", sourceId: path, path: path, line: 0, message: "The root Compose file is unreadable; Studio is read-only" })
    }
  }

  var visiting = {}
  function visit(path, fromNode) {
    var normalized = normalizePosixPath(path)
    if (visiting[normalized]) {
      diagnostics.push({ kind: "include-cycle", severity: "warning", sourceId: fromNode ? fromNode.sourceId : normalized, line: fromNode ? fromNode.line : 0, message: "Include cycle stopped at " + normalized })
      return
    }
    var source = map[normalized]
    if (!source) {
      diagnostics.push({ kind: "missing-include", severity: "warning", sourceId: fromNode ? fromNode.sourceId : normalized, line: fromNode ? fromNode.line : 0, message: "Missing or unreadable include: " + normalized, path: normalized })
      return
    }
    visiting[normalized] = true
    var nodes = source.document.nodes || []
    for (var n = 0; n < nodes.length; n++) {
      var node = nodes[n]
      if (node.type === "include") visit(resolveIncludePath(node.includePath, normalized, env), node)
      else if (node.type === "rule") segments.push({ kind: source.kind, name: source.name, path: source.path, document: { nodes: [node] } })
    }
    delete visiting[normalized]
  }

  visit(normalizePosixPath(rootPath), null)
  var library = resolveEffectiveLibrary(segments)
  diagnostics = diagnostics.concat(library.diagnostics)
  return { rootPath: normalizePosixPath(rootPath), sources: documents, rules: library.rules, activeRules: library.activeRules, diagnostics: diagnostics }
}

function rootContentChanged(currentGraph, nextGraph) {
  function digest(graph) {
    if (!graph || !Array.isArray(graph.sources)) return ""
    for (var i = 0; i < graph.sources.length; i++) {
      var source = graph.sources[i]
      if (source && source.path === graph.rootPath) return String(source.digest || "")
    }
    return ""
  }
  var currentDigest = digest(currentGraph)
  var nextDigest = digest(nextGraph)
  return !currentGraph || !nextGraph
    || String(currentGraph.rootPath || "") !== String(nextGraph.rootPath || "")
    || !currentDigest || !nextDigest || currentDigest !== nextDigest
}

function mapQtKey(key, text, modifiers) {
  var named = {
    0x01000000: "Escape", 0x01000001: "Tab", 0x01000003: "BackSpace",
    0x01000004: "Return", 0x01000005: "Return", 0x01000012: "Left",
    0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down",
    0x20: "space"
  }
  var symbol = named[Number(key)] || ""
  var textValue = String(text || "")
  var textCode = textValue.length === 1 ? textValue.charCodeAt(0) : -1
  if (!symbol && textValue.length === 1 && textCode >= 0x20 && textCode !== 0x7f) {
    var character = textValue
    var punctuation = {
      " ": "space", "!": "exclam", '"': "quotedbl", "#": "numbersign", "$": "dollar", "%": "percent",
      "&": "ampersand", "'": "apostrophe", "(": "parenleft", ")": "parenright", "*": "asterisk", "+": "plus",
      ",": "comma", "-": "minus", ".": "period", "/": "slash", ":": "colon", ";": "semicolon", "<": "less",
      "=": "equal", ">": "greater", "?": "question", "@": "at", "[": "bracketleft", "\\": "backslash",
      "]": "bracketright", "^": "asciicircum", "_": "underscore", "`": "grave", "{": "braceleft", "|": "bar",
      "}": "braceright", "~": "asciitilde"
    }
    symbol = punctuation[character] || ""
    if (!symbol && character.charCodeAt(0) < 0x80) symbol = character
    if (!symbol) {
      for (var keysymName in KEYSYM_UTF8) {
        if (KEYSYM_UTF8[keysymName] === character) { symbol = keysymName; break }
      }
    }
    if (!symbol) symbol = "U" + character.codePointAt(0).toString(16).toUpperCase()
  }
  if (!symbol && Number(key) >= 0x41 && Number(key) <= 0x5a) symbol = String.fromCharCode(Number(key)).toLowerCase()
  return { keysym: symbol, modifiers: modifiers || 0, valid: symbol !== "" }
}

function qtModifiersToCompose(modifiers) {
  var mask = Number(modifiers) || 0
  var names = []
  if (mask & 0x04000000) names.push("Ctrl")
  if (mask & 0x02000000) names.push("Shift")
  if (mask & 0x08000000) names.push("Alt")
  if (mask & 0x10000000) names.push("Meta")
  return names.join(" ")
}

function findSequenceConflict(rules, sequence) {
  var list = Array.isArray(rules) ? rules : []
  var exact = null
  var prefixes = []
  for (var i = 0; i < list.length; i++) {
    var relation = sequenceRelation(list[i].sequence, sequence)
    if (relation === "exact") exact = list[i]
    else if (relation !== "none") prefixes.push(list[i])
  }
  return { exact: exact, prefixes: prefixes, action: exact && exact.active ? (exact.sourceKind === "Mine" ? "replace" : "override") : "append" }
}

var api = {
  DEFAULT_SHORTCUT: DEFAULT_SHORTCUT,
  LOCAL_SECTION_HEADER: LOCAL_SECTION_HEADER,
  normalizeShortcut: normalizeShortcut,
  shortcutChord: shortcutChord,
  parseModePayload: parseModePayload,
  findPluginEntry: findPluginEntry,
  settingsFrom: settingsFrom,
  writePluginSetting: writePluginSetting,
  decodeComposeString: decodeComposeString,
  encodeComposeString: encodeComposeString,
  keysymToUtf8: keysymToUtf8,
  parseKeysymDefinitions: parseKeysymDefinitions,
  knownKeysym: knownKeysym,
  validModifierSyntax: validModifierSyntax,
  parseRuleLine: parseRuleLine,
  parseDocument: parseDocument,
  sequenceRelation: sequenceRelation,
  resolveEffectiveLibrary: resolveEffectiveLibrary,
  parseEmojiOutputs: parseEmojiOutputs,
  searchRules: searchRules,
  invisiblePreview: invisiblePreview,
  replaceSpan: replaceSpan,
  applySpanEdits: applySpanEdits,
  replaceLocalDefinitions: replaceLocalDefinitions,
  deleteRule: deleteRule,
  moveRuleToLocalSection: moveRuleToLocalSection,
  appendLocalRule: appendLocalRule,
  encodeRule: encodeRule,
  validateCandidate: validateCandidate,
  expandIncludePath: expandIncludePath,
  classifySource: classifySource,
  normalizePosixPath: normalizePosixPath,
  resolveIncludePath: resolveIncludePath,
  resolveSourceGraph: resolveSourceGraph,
  rootContentChanged: rootContentChanged,
  mapQtKey: mapQtKey,
  qtModifiersToCompose: qtModifiersToCompose,
  findSequenceConflict: findSequenceConflict
}

if (typeof module !== "undefined") module.exports = api
