// Rule engine for the notification router.
//
// Pure JavaScript on purpose: no Qt types, no I/O, no side effects. The QML
// service hands it a notification snapshot and a rule list and gets back a
// verdict describing what should happen. That keeps the part with all the
// decisions in it runnable under `node --test`.
//
// Loaded both as a QML JS resource and as a CommonJS module (see the export
// shim at the bottom).

// ---------------------------------------------------------------- urgency

// freedesktop urgency levels, as the notification server reports them.
var URGENCY = { low: 0, normal: 1, critical: 2 }

function normalizeUrgency(value) {
  if (value === null || value === undefined || value === "") return null
  if (typeof value === "number") {
    return (value === 0 || value === 1 || value === 2) ? value : null
  }
  var key = String(value).trim().toLowerCase()
  return key in URGENCY ? URGENCY[key] : null
}

// ---------------------------------------------------------------- matching

// A match value is either `/pattern/flags` (a regex) or a plain string, which
// matches as a case-insensitive substring. Substring rather than equality
// because "Slack" should catch "Slack" and "Slack — Ameba" alike; anyone who
// wants anchoring can say `/^Slack$/`.
var REGEX_FORM = /^\/(.*)\/([gimsuy]*)$/

function compileMatcher(spec) {
  if (spec === null || spec === undefined) return null
  var raw = String(spec)
  var form = REGEX_FORM.exec(raw)
  if (form) {
    try {
      // Drop /g: a stateful lastIndex would make repeated tests of the same
      // matcher alternate between hit and miss.
      var re = new RegExp(form[1], form[2].replace(/g/g, ""))
      return { kind: "regex", test: function (value) { return re.test(String(value || "")) }, source: raw }
    } catch (e) {
      return { kind: "invalid", error: String(e && e.message || e), source: raw }
    }
  }
  var needle = raw.toLowerCase()
  return {
    kind: "substring",
    source: raw,
    test: function (value) { return String(value || "").toLowerCase().indexOf(needle) !== -1 }
  }
}

// Which notification fields a `match` block may name. `title` is accepted as
// an alias for `summary` because that is what every other notification tool
// calls it.
var MATCH_FIELDS = { app: "app", summary: "summary", title: "summary", body: "body" }

function compileMatch(match) {
  var compiled = { tests: [], errors: [], urgency: null }
  if (!match || typeof match !== "object") return compiled

  for (var key in match) {
    if (!Object.prototype.hasOwnProperty.call(match, key)) continue

    if (key === "urgency") {
      var level = normalizeUrgency(match[key])
      if (level === null) compiled.errors.push('urgency must be low, normal or critical (got "' + match[key] + '")')
      else compiled.urgency = level
      continue
    }

    var field = MATCH_FIELDS[key]
    if (!field) {
      compiled.errors.push('unknown match field "' + key + '"')
      continue
    }
    var matcher = compileMatcher(match[key])
    if (!matcher) continue
    if (matcher.kind === "invalid") {
      compiled.errors.push('bad regex for "' + key + '": ' + matcher.error)
      continue
    }
    compiled.tests.push({ field: field, matcher: matcher })
  }
  return compiled
}

// Every clause in a `match` block has to hold. An empty block matches
// everything, which is how a catch-all rule is written.
function matches(compiled, notification) {
  var n = notification || {}
  if (compiled.urgency !== null && normalizeUrgency(n.urgency) !== compiled.urgency) return false
  for (var i = 0; i < compiled.tests.length; i++) {
    var t = compiled.tests[i]
    if (!t.matcher.test(n[t.field])) return false
  }
  return true
}

// ---------------------------------------------------------------- actions

// Scalar actions are settled by the last rule that names them; sink actions
// pile up, so two rules can both forward the same notification onward.
var SCALAR_ACTIONS = { silence: true, dot: true, sound: true }
var SINK_ACTIONS = { ntfy: true, webhook: true }

function compileActions(then, errors) {
  var list = []
  if (!Array.isArray(then)) {
    if (then) errors.push("`then` must be a list of actions")
    return list
  }
  for (var i = 0; i < then.length; i++) {
    var action = then[i]
    if (!action || typeof action !== "object") {
      errors.push("action " + (i + 1) + " is not an object")
      continue
    }
    var names = Object.keys(action)
    if (names.length !== 1) {
      errors.push("action " + (i + 1) + " must name exactly one of silence, dot, sound, ntfy, webhook")
      continue
    }
    var name = names[0]
    if (!SCALAR_ACTIONS[name] && !SINK_ACTIONS[name]) {
      errors.push('unknown action "' + name + '"')
      continue
    }
    list.push({ name: name, value: action[name] })
  }
  return list
}

// ---------------------------------------------------------------- parsing

// Never throws. A rules file the user is halfway through editing should
// degrade to "these rules loaded, these did not" rather than take the
// service down with it.
function parseRules(raw) {
  var result = { rules: [], errors: [], doc: { rules: [] } }

  var doc = raw
  if (typeof raw === "string") {
    if (!raw.trim()) return result
    try {
      doc = JSON.parse(raw)
    } catch (e) {
      result.errors.push("rules.json is not valid JSON: " + String(e && e.message || e))
      return result
    }
  }
  if (!doc || typeof doc !== "object") {
    result.errors.push("rules.json must contain an object")
    return result
  }

  var rules = doc.rules
  if (!Array.isArray(rules)) {
    result.errors.push("rules.json needs a `rules` list")
    return result
  }
  result.doc = doc

  for (var i = 0; i < rules.length; i++) {
    var rule = rules[i]
    var label = "rule " + (i + 1)
    if (!rule || typeof rule !== "object") {
      result.errors.push(label + " is not an object")
      continue
    }
    var name = String(rule.name || label)
    var errors = []
    var compiled = compileMatch(rule.match)
    for (var e = 0; e < compiled.errors.length; e++) result.errors.push(name + ": " + compiled.errors[e])

    var actions = compileActions(rule.then, errors)
    for (var f = 0; f < errors.length; f++) result.errors.push(name + ": " + errors[f])

    // A rule whose match block failed to compile is dropped rather than
    // silently widened — a broken regex must not turn into a catch-all that
    // silences everything.
    if (compiled.errors.length) continue
    if (!actions.length) {
      result.errors.push(name + ": no usable actions, rule ignored")
      continue
    }

    result.rules.push({
      name: name,
      // Position in doc.rules, so a panel edit lands on the right rule even
      // though rules that failed to compile were dropped from this list.
      index: i,
      enabled: rule.enabled !== false,
      match: compiled,
      actions: actions,
      stop: rule.stop === true,
      source: rule
    })
  }
  return result
}

// ---------------------------------------------------------------- templates

// {app} {summary} {body} {urgency} in any sink string. Unknown placeholders
// are left alone so a JSON body containing braces survives untouched.
var URGENCY_NAMES = ["low", "normal", "critical"]

function expand(template, notification) {
  if (typeof template !== "string") return template
  var n = notification || {}
  return template.replace(/\{(app|summary|title|body|urgency)\}/g, function (whole, key) {
    switch (key) {
    case "app": return String(n.app || "")
    case "title":
    case "summary": return String(n.summary || "")
    case "body": return String(n.body || "")
    case "urgency":
      var level = normalizeUrgency(n.urgency)
      return level === null ? "" : URGENCY_NAMES[level]
    }
    return whole
  })
}

// Walk a sink payload expanding every string it contains, so templates work
// at any depth (an ntfy `message`, a webhook body's nested field).
function expandDeep(value, notification) {
  if (typeof value === "string") return expand(value, notification)
  if (Array.isArray(value)) {
    var out = []
    for (var i = 0; i < value.length; i++) out.push(expandDeep(value[i], notification))
    return out
  }
  if (value && typeof value === "object") {
    var obj = {}
    for (var key in value) {
      if (Object.prototype.hasOwnProperty.call(value, key)) obj[key] = expandDeep(value[key], notification)
    }
    return obj
  }
  return value
}

// ---------------------------------------------------------------- evaluate

// Runs every rule in order and folds the actions of those that match into one
// verdict. Order matters twice over: later scalars overwrite earlier ones, and
// a matching rule with `stop` ends the pass.
function evaluate(rules, notification) {
  var verdict = {
    matched: [],
    silence: false,
    dot: null,
    sound: null,
    sinks: []
  }
  if (!Array.isArray(rules)) return verdict

  for (var i = 0; i < rules.length; i++) {
    var rule = rules[i]
    if (!rule || rule.enabled === false) continue
    if (!matches(rule.match, notification)) continue

    verdict.matched.push(rule.name)
    for (var a = 0; a < rule.actions.length; a++) {
      var action = rule.actions[a]
      switch (action.name) {
      case "silence":
        // `{"silence": false}` is a real instruction: it lets a later, more
        // specific rule rescue something a broad rule silenced.
        verdict.silence = action.value !== false
        break
      case "dot":
        verdict.dot = action.value === false ? null : String(action.value)
        break
      case "sound":
        verdict.sound = action.value === false ? null : String(action.value)
        break
      default:
        verdict.sinks.push({
          kind: action.name,
          rule: rule.name,
          config: expandDeep(action.value, notification)
        })
      }
    }
    if (rule.stop) break
  }
  return verdict
}

// Whether a verdict asks for anything at all. A notification no rule touched
// must reach the screen untouched.
function isNoop(verdict) {
  if (!verdict) return true
  return !verdict.silence && !verdict.dot && !verdict.sound && verdict.sinks.length === 0
}


// -------------------------------------------------------- panel presentation

// Human-readable one-liners for the rule list. Kept here rather than formatted
// in QML so the strings the panel shows are covered by the same tests as the
// behaviour they describe.

var FIELD_LABELS = { app: "app", summary: "title", body: "body" }

function describeMatch(rule) {
  var compiled = rule && rule.match
  if (!compiled) return "anything"
  var parts = []
  for (var i = 0; i < compiled.tests.length; i++) {
    var t = compiled.tests[i]
    parts.push((FIELD_LABELS[t.field] || t.field) + " " + t.matcher.source)
  }
  if (compiled.urgency !== null && compiled.urgency !== undefined) {
    parts.push("urgency " + URGENCY_NAMES[compiled.urgency])
  }
  return parts.length ? parts.join(" · ") : "anything"
}

function describeAction(action) {
  if (!action) return ""
  var value = action.value
  switch (action.name) {
  case "silence": return value === false ? "don't silence" : "silence"
  case "dot": return "dot " + String(value)
  case "sound": return "sound " + String(value)
  case "ntfy": return "ntfy " + String((value && value.topic) || value || "")
  case "webhook": return "webhook " + String((value && value.url) || value || "")
  }
  return action.name
}

function describeActions(rule) {
  var out = []
  var actions = (rule && rule.actions) || []
  for (var i = 0; i < actions.length; i++) out.push(describeAction(actions[i]))
  return out
}

// ------------------------------------------------------------------ drafting

// Turn a notification the user just saw into a starting rule. This is the
// panel's "route this" affordance: matching on the app is almost always what
// somebody wants, and the exact regex can be tuned in the file afterwards.
function draftRule(snapshot, actions) {
  var n = snapshot || {}
  var app = String(n.app || "").trim()
  var rule = {
    name: (app || "Untitled") + " rule",
    match: {},
    then: Array.isArray(actions) && actions.length ? actions : [{ silence: true }]
  }
  if (app) rule.match.app = app
  else if (n.summary) rule.match.summary = String(n.summary)
  return rule
}

// Serialise a document back to the file. Two spaces and a trailing newline to
// match how omarchy writes its own JSON.
function serialize(doc) {
  var safe = doc && typeof doc === "object" ? doc : {}
  if (!Array.isArray(safe.rules)) safe.rules = []
  return JSON.stringify(safe, null, 2) + "\n"
}

// Flip a rule's enabled flag in the source document, addressed by its index in
// doc.rules. Returns a new document; never mutates the one passed in.
function withRuleEnabled(doc, index, enabled) {
  var next = JSON.parse(JSON.stringify(doc && typeof doc === "object" ? doc : { rules: [] }))
  if (!Array.isArray(next.rules)) next.rules = []
  if (index < 0 || index >= next.rules.length) return next
  if (enabled) delete next.rules[index].enabled
  else next.rules[index].enabled = false
  return next
}

function withRuleAppended(doc, rule) {
  var next = JSON.parse(JSON.stringify(doc && typeof doc === "object" ? doc : { rules: [] }))
  if (!Array.isArray(next.rules)) next.rules = []
  next.rules.push(rule)
  return next
}

function withRuleRemoved(doc, index) {
  var next = JSON.parse(JSON.stringify(doc && typeof doc === "object" ? doc : { rules: [] }))
  if (!Array.isArray(next.rules)) next.rules = []
  if (index < 0 || index >= next.rules.length) return next
  next.rules.splice(index, 1)
  return next
}

// ---------------------------------------------------------------- node shim
//
// QML loads this file as a JS library, where `module` does not exist; node
// loads it as CommonJS. The typeof guard lets one file serve both.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    URGENCY: URGENCY,
    normalizeUrgency: normalizeUrgency,
    compileMatcher: compileMatcher,
    compileMatch: compileMatch,
    matches: matches,
    parseRules: parseRules,
    expand: expand,
    expandDeep: expandDeep,
    evaluate: evaluate,
    isNoop: isNoop,
    describeMatch: describeMatch,
    describeAction: describeAction,
    describeActions: describeActions,
    draftRule: draftRule,
    serialize: serialize,
    withRuleEnabled: withRuleEnabled,
    withRuleAppended: withRuleAppended,
    withRuleRemoved: withRuleRemoved
  }
}
