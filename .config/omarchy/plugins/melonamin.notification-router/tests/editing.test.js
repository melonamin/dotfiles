const test = require("node:test")
const assert = require("node:assert")

const M = require("../RouterModel.js")

const DOC = {
  rules: [
    { name: "one", match: { app: "Slack" }, then: [{ silence: true }] },
    { name: "two", match: { app: "Spotify" }, then: [{ dot: "#fff" }] }
  ]
}

// ------------------------------------------------------------- source anchor

test("parse carries the source document back", () => {
  const parsed = M.parseRules(DOC)
  assert.deepEqual(parsed.doc, DOC)
})

test("each compiled rule knows its index in the source document", () => {
  // The panel writes back by index, and dropped rules must not shift it.
  const parsed = M.parseRules({
    rules: [
      { name: "broken", match: { app: "/([/" }, then: [{ silence: true }] },
      { name: "good", match: { app: "Slack" }, then: [{ silence: true }] }
    ]
  })
  assert.equal(parsed.rules.length, 1)
  assert.equal(parsed.rules[0].name, "good")
  assert.equal(parsed.rules[0].index, 1, "index must point at the source position, not the compiled one")
})

// -------------------------------------------------------------- descriptions

test("a match block describes itself", () => {
  const rules = M.parseRules({
    rules: [{ name: "x", match: { app: "Slack", title: "/^DM/i", urgency: "critical" }, then: [{ silence: true }] }]
  }).rules
  const text = M.describeMatch(rules[0])
  assert.ok(text.includes("app Slack"))
  assert.ok(text.includes("title /^DM/i"))
  assert.ok(text.includes("urgency critical"))
})

test("an empty match block describes itself as a catch-all", () => {
  const rules = M.parseRules({ rules: [{ name: "x", match: {}, then: [{ silence: true }] }] }).rules
  assert.equal(M.describeMatch(rules[0]), "anything")
})

test("actions describe themselves legibly", () => {
  const rules = M.parseRules({
    rules: [{
      name: "x", match: {}, then: [
        { silence: true }, { silence: false }, { dot: "#e5c07b" }, { sound: "bell" },
        { ntfy: { topic: "alerts" } }, { webhook: { url: "https://e.com/h" } }
      ]
    }]
  }).rules
  assert.deepEqual(M.describeActions(rules[0]), [
    "silence", "don't silence", "dot #e5c07b", "sound bell",
    "ntfy alerts", "webhook https://e.com/h"
  ])
})

test("shorthand sink forms still describe themselves", () => {
  const rules = M.parseRules({
    rules: [{ name: "x", match: {}, then: [{ ntfy: "topic" }] }]
  }).rules
  assert.deepEqual(M.describeActions(rules[0]), ["ntfy topic"])
})

// ------------------------------------------------------------------ drafting

test("a notification drafts into a rule matching its app", () => {
  const rule = M.draftRule({ app: "Slack", summary: "DM from Anna" })
  assert.equal(rule.match.app, "Slack")
  assert.deepEqual(rule.then, [{ silence: true }])
  assert.ok(rule.name.includes("Slack"))
})

test("a notification with no app falls back to matching its summary", () => {
  const rule = M.draftRule({ app: "", summary: "Build failed" })
  assert.equal(rule.match.summary, "Build failed")
  assert.equal(rule.match.app, undefined)
})

test("a draft carries the actions it was given", () => {
  const rule = M.draftRule({ app: "Slack" }, [{ dot: "#e5c07b" }, { ntfy: "phone" }])
  assert.deepEqual(rule.then, [{ dot: "#e5c07b" }, { ntfy: "phone" }])
})

test("a draft round-trips back through the parser", () => {
  // The panel writes drafts straight to disk, so a draft that does not parse
  // would break the rules file the moment it is saved.
  const draft = M.draftRule({ app: "Slack", summary: "x" }, [{ dot: "#e5c07b" }])
  const parsed = M.parseRules({ rules: [draft] })
  assert.deepEqual(parsed.errors, [])
  assert.equal(parsed.rules.length, 1)
})

// ------------------------------------------------------------------- editing

test("toggling a rule off writes enabled:false, on removes the key", () => {
  const off = M.withRuleEnabled(DOC, 0, false)
  assert.equal(off.rules[0].enabled, false)
  const on = M.withRuleEnabled(off, 0, true)
  assert.ok(!("enabled" in on.rules[0]))
})

test("edits never mutate the document they were given", () => {
  const before = JSON.stringify(DOC)
  M.withRuleEnabled(DOC, 0, false)
  M.withRuleAppended(DOC, { name: "n", match: {}, then: [{ silence: true }] })
  M.withRuleRemoved(DOC, 0)
  assert.equal(JSON.stringify(DOC), before, "the source document must be untouched")
})

test("an out-of-range index is a no-op, not a crash", () => {
  assert.doesNotThrow(() => M.withRuleEnabled(DOC, 99, false))
  assert.doesNotThrow(() => M.withRuleRemoved(DOC, -1))
  assert.equal(M.withRuleRemoved(DOC, 99).rules.length, 2)
})

test("append and remove do what they say", () => {
  const added = M.withRuleAppended(DOC, { name: "three", match: {}, then: [{ silence: true }] })
  assert.equal(added.rules.length, 3)
  assert.equal(added.rules[2].name, "three")
  assert.equal(M.withRuleRemoved(added, 0).rules.map(r => r.name).join(","), "two,three")
})

test("editing a document that is missing its rules list still works", () => {
  for (const doc of [{}, null, undefined, { rules: "nope" }]) {
    assert.doesNotThrow(() => M.withRuleAppended(doc, { name: "n", match: {}, then: [{ silence: true }] }))
    assert.equal(M.withRuleAppended(doc, { name: "n", match: {}, then: [{ silence: true }] }).rules.length, 1)
  }
})

// --------------------------------------------------------------- serialising

test("serialize produces parseable JSON with a trailing newline", () => {
  const text = M.serialize(DOC)
  assert.ok(text.endsWith("\n"))
  assert.deepEqual(JSON.parse(text), DOC)
})

test("a full edit round-trip survives the parser", () => {
  const edited = M.withRuleAppended(M.withRuleEnabled(DOC, 1, false), M.draftRule({ app: "Discord" }))
  const reparsed = M.parseRules(M.serialize(edited))
  assert.deepEqual(reparsed.errors, [])
  assert.deepEqual(reparsed.rules.map(r => r.name), ["one", "two", "Discord rule"])
  assert.equal(reparsed.rules[1].enabled, false)
})

test("serialize repairs a document with no rules list", () => {
  assert.deepEqual(JSON.parse(M.serialize({})), { rules: [] })
  assert.deepEqual(JSON.parse(M.serialize(null)), { rules: [] })
})
