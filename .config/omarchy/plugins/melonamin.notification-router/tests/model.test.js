const test = require("node:test")
const assert = require("node:assert")

const M = require("../RouterModel.js")

// A notification snapshot shaped the way the shell's popupModel rows are.
function notif(over) {
  return Object.assign({ app: "Slack", summary: "DM from Anna", body: "lunch?", urgency: 1 }, over || {})
}

function rulesFor(list) {
  const parsed = M.parseRules({ rules: list })
  assert.deepEqual(parsed.errors, [], "fixture rules should compile cleanly")
  return parsed.rules
}

// ------------------------------------------------------------------ matching

test("a plain string matches as a case-insensitive substring", () => {
  const m = M.compileMatcher("slack")
  assert.equal(m.kind, "substring")
  assert.ok(m.test("Slack"))
  assert.ok(m.test("Slack — Ameba"))
  assert.ok(!m.test("Discord"))
})

test("/pattern/flags compiles to a regex", () => {
  const m = M.compileMatcher("/^DM from/i")
  assert.equal(m.kind, "regex")
  assert.ok(m.test("DM from Anna"))
  assert.ok(!m.test("Re: DM from Anna"))
})

test("a /g regex is not stateful across repeated tests", () => {
  // With /g preserved, lastIndex would make the second call miss.
  const m = M.compileMatcher("/anna/gi")
  assert.ok(m.test("Anna"))
  assert.ok(m.test("Anna"))
  assert.ok(m.test("Anna"))
})

test("an unparseable regex is reported, not thrown", () => {
  const m = M.compileMatcher("/([unclosed/")
  assert.equal(m.kind, "invalid")
  assert.ok(m.error.length > 0)
})

test("title is an alias for summary", () => {
  const rules = rulesFor([{ name: "t", match: { title: "DM from" }, then: [{ silence: true }] }])
  assert.ok(M.matches(rules[0].match, notif()))
  assert.ok(!M.matches(rules[0].match, notif({ summary: "standup" })))
})

test("every clause in a match block must hold", () => {
  const rules = rulesFor([
    { name: "both", match: { app: "Slack", body: "lunch" }, then: [{ silence: true }] }
  ])
  assert.ok(M.matches(rules[0].match, notif()))
  assert.ok(!M.matches(rules[0].match, notif({ body: "deploy failed" })))
})

test("an empty match block is a catch-all", () => {
  const rules = rulesFor([{ name: "all", match: {}, then: [{ silence: true }] }])
  assert.ok(M.matches(rules[0].match, notif()))
  assert.ok(M.matches(rules[0].match, notif({ app: "anything" })))
})

test("urgency matches by name and rejects nonsense", () => {
  assert.equal(M.normalizeUrgency("critical"), 2)
  assert.equal(M.normalizeUrgency("LOW"), 0)
  assert.equal(M.normalizeUrgency(2), 2)
  assert.equal(M.normalizeUrgency("urgent"), null)
  assert.equal(M.normalizeUrgency(7), null)

  const rules = rulesFor([{ name: "u", match: { urgency: "critical" }, then: [{ dot: "#f00" }] }])
  assert.ok(M.matches(rules[0].match, notif({ urgency: 2 })))
  assert.ok(!M.matches(rules[0].match, notif({ urgency: 1 })))
})

// ------------------------------------------------------------------- parsing

test("parseRules never throws on malformed input", () => {
  for (const bad of ["", "{", "[]", "null", '{"rules":"nope"}', undefined]) {
    assert.doesNotThrow(() => M.parseRules(bad))
  }
  assert.deepEqual(M.parseRules("").rules, [])
  assert.ok(M.parseRules("{").errors.length > 0)
})

test("a rule with a broken regex is dropped, never widened to a catch-all", () => {
  // The dangerous failure: a bad matcher silently matching everything and
  // silencing the user's whole firehose.
  const parsed = M.parseRules({
    rules: [{ name: "broken", match: { app: "/([/" }, then: [{ silence: true }] }]
  })
  assert.equal(parsed.rules.length, 0)
  assert.ok(parsed.errors.some(e => /bad regex/.test(e)))
})

test("one bad rule does not take the good ones down with it", () => {
  const parsed = M.parseRules({
    rules: [
      { name: "good", match: { app: "Slack" }, then: [{ silence: true }] },
      { name: "broken", match: { app: "/([/" }, then: [{ silence: true }] },
      { name: "alsogood", match: { app: "Discord" }, then: [{ dot: "#fff" }] }
    ]
  })
  assert.deepEqual(parsed.rules.map(r => r.name), ["good", "alsogood"])
  assert.equal(parsed.errors.length, 1)
})

test("ha is no longer a recognised action", () => {
  // Removed deliberately; this guards against it creeping back in unnoticed.
  const parsed = M.parseRules({
    rules: [{ name: "x", match: {}, then: [{ ha: "light.turn_on" }] }]
  })
  assert.equal(parsed.rules.length, 0)
  assert.ok(parsed.errors.some(e => /unknown action "ha"/.test(e)))
})

test("unknown match fields and actions are reported", () => {
  const parsed = M.parseRules({
    rules: [{ name: "x", match: { sender: "bob" }, then: [{ teleport: true }] }]
  })
  assert.equal(parsed.rules.length, 0)
  assert.ok(parsed.errors.some(e => /unknown match field/.test(e)))
})

test("a rule with no usable actions is ignored", () => {
  const parsed = M.parseRules({ rules: [{ name: "empty", match: { app: "Slack" }, then: [] }] })
  assert.equal(parsed.rules.length, 0)
  assert.ok(parsed.errors.some(e => /no usable actions/.test(e)))
})

test("an action object must name exactly one action", () => {
  const parsed = M.parseRules({
    rules: [{ name: "x", match: {}, then: [{ silence: true, dot: "#fff" }] }]
  })
  assert.ok(parsed.errors.some(e => /exactly one/.test(e)))
})

test("enabled:false is preserved, other values default to enabled", () => {
  const parsed = M.parseRules({
    rules: [
      { name: "off", enabled: false, match: {}, then: [{ silence: true }] },
      { name: "on", match: {}, then: [{ silence: true }] }
    ]
  })
  assert.equal(parsed.rules[0].enabled, false)
  assert.equal(parsed.rules[1].enabled, true)
})

// ----------------------------------------------------------------- templates

test("placeholders expand from the notification", () => {
  assert.equal(M.expand("{app}: {summary}", notif()), "Slack: DM from Anna")
  assert.equal(M.expand("{title}", notif()), "DM from Anna")
  assert.equal(M.expand("{urgency}", notif({ urgency: 2 })), "critical")
})

test("unknown placeholders are left alone", () => {
  assert.equal(M.expand("{nope} {app}", notif()), "{nope} Slack")
})

test("expansion reaches strings at any depth", () => {
  const out = M.expandDeep({ topic: "alerts", payload: { text: ["{app}", "{summary}"] } }, notif())
  assert.deepEqual(out, { topic: "alerts", payload: { text: ["Slack", "DM from Anna"] } })
})

test("non-string leaves survive expansion unchanged", () => {
  const out = M.expandDeep({ priority: 4, urgent: true, nothing: null }, notif())
  assert.deepEqual(out, { priority: 4, urgent: true, nothing: null })
})

// ------------------------------------------------------------------ evaluate

test("a notification no rule matches is left completely alone", () => {
  const rules = rulesFor([{ name: "spotify", match: { app: "Spotify" }, then: [{ silence: true }] }])
  const verdict = M.evaluate(rules, notif())
  assert.deepEqual(verdict.matched, [])
  assert.ok(M.isNoop(verdict))
})

test("a matching rule yields its actions", () => {
  const rules = rulesFor([
    { name: "dms", match: { app: "Slack", body: "lunch" }, then: [{ silence: true }, { dot: "#e5c07b" }] }
  ])
  const verdict = M.evaluate(rules, notif())
  assert.deepEqual(verdict.matched, ["dms"])
  assert.equal(verdict.silence, true)
  assert.equal(verdict.dot, "#e5c07b")
  assert.ok(!M.isNoop(verdict))
})

test("later scalars win, sinks accumulate", () => {
  const rules = rulesFor([
    { name: "broad", match: { app: "Slack" }, then: [{ dot: "#111" }, { ntfy: { topic: "a" } }] },
    { name: "narrow", match: { body: "lunch" }, then: [{ dot: "#222" }, { ntfy: { topic: "b" } }] }
  ])
  const verdict = M.evaluate(rules, notif())
  assert.deepEqual(verdict.matched, ["broad", "narrow"])
  assert.equal(verdict.dot, "#222")
  assert.deepEqual(verdict.sinks.map(s => s.config.topic), ["a", "b"])
})

test("a later rule can rescue something a broad rule silenced", () => {
  const rules = rulesFor([
    { name: "mute all slack", match: { app: "Slack" }, then: [{ silence: true }] },
    { name: "except DMs", match: { summary: "/^DM from/" }, then: [{ silence: false }] }
  ])
  assert.equal(M.evaluate(rules, notif()).silence, false)
  assert.equal(M.evaluate(rules, notif({ summary: "#deploys" })).silence, true)
})

test("stop halts the pass at the matching rule", () => {
  const rules = rulesFor([
    { name: "first", match: { app: "Slack" }, then: [{ dot: "#111" }], stop: true },
    { name: "second", match: { app: "Slack" }, then: [{ dot: "#222" }] }
  ])
  const verdict = M.evaluate(rules, notif())
  assert.deepEqual(verdict.matched, ["first"])
  assert.equal(verdict.dot, "#111")
})

test("stop on a non-matching rule does not halt the pass", () => {
  const rules = rulesFor([
    { name: "miss", match: { app: "Discord" }, then: [{ dot: "#111" }], stop: true },
    { name: "hit", match: { app: "Slack" }, then: [{ dot: "#222" }] }
  ])
  assert.deepEqual(M.evaluate(rules, notif()).matched, ["hit"])
})

test("a disabled rule is skipped entirely", () => {
  const parsed = M.parseRules({
    rules: [{ name: "off", enabled: false, match: {}, then: [{ silence: true }] }]
  })
  assert.ok(M.isNoop(M.evaluate(parsed.rules, notif())))
})

test("sinks carry their rule name and expanded config", () => {
  const rules = rulesFor([
    { name: "to phone", match: { app: "Slack" }, then: [{ ntfy: { topic: "urgent", message: "{app}: {summary}" } }] }
  ])
  const sink = M.evaluate(rules, notif()).sinks[0]
  assert.equal(sink.kind, "ntfy")
  assert.equal(sink.rule, "to phone")
  assert.equal(sink.config.message, "Slack: DM from Anna")
})

test("evaluate tolerates a missing rule list", () => {
  assert.ok(M.isNoop(M.evaluate(null, notif())))
  assert.ok(M.isNoop(M.evaluate(undefined, notif())))
})

test("evaluate tolerates a notification with missing fields", () => {
  const rules = rulesFor([{ name: "any", match: { app: "slack" }, then: [{ silence: true }] }])
  assert.doesNotThrow(() => M.evaluate(rules, {}))
  assert.ok(M.isNoop(M.evaluate(rules, {})))
})
