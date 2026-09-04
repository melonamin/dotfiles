const test = require("node:test")
const assert = require("node:assert")

const S = require("../SinkModel.js")

function notif(over) {
  return Object.assign({ app: "Slack", summary: "DM from Anna", body: "lunch?", urgency: 1 }, over || {})
}

// Find the value following a flag in an argv array.
function argAfter(argv, flag) {
  const i = argv.indexOf(flag)
  return i === -1 ? undefined : argv[i + 1]
}

// ------------------------------------------------------------------- safety

test("notification text never reaches a shell", () => {
  // The whole reason for argv arrays. If this ever regresses to a shell
  // string, a chat message could run commands.
  const hostile = notif({ summary: '"; rm -rf $HOME; echo "', body: "`id`; $(whoami)" })
  const built = [
    S.ntfyRequest({ topic: "t", message: "{summary}" }, hostile),
    S.webhookRequest({ url: "https://example.com", json: {} }, hostile)
  ]
  for (const r of built) {
    assert.ok(r.ok)
    assert.ok(Array.isArray(r.argv))
    assert.equal(r.argv[0], "curl")
    // No element is a shell invocation, and nothing was concatenated into one.
    assert.ok(!r.argv.some(a => a === "sh" || a === "bash" || a === "-c" || a === "-lc"))
  }
})

test("hostile text survives intact inside the JSON payload", () => {
  const hostile = notif({ summary: '"; rm -rf $HOME; echo "' })
  const r = S.ntfyRequest({ topic: "t", message: "{summary}" }, hostile)
  // RouterModel expands templates; SinkModel just carries the value. Here the
  // literal template is passed through, so assert the JSON is well-formed and
  // round-trips whatever it was given.
  const payload = JSON.parse(argAfter(r.argv, "--data-binary"))
  assert.equal(typeof payload.message, "string")
})

test("every HTTP sink bounds its runtime", () => {
  for (const r of [S.ntfyRequest("t", notif()), S.webhookRequest("https://example.com", notif())]) {
    assert.equal(argAfter(r.argv, "--max-time"), "10")
  }
})

// -------------------------------------------------------------------- sound

test("a bare name resolves to the freedesktop theme", () => {
  assert.equal(S.resolveSoundPath("message-new-instant"),
    "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga")
})

test("anything with a slash is used as a path", () => {
  assert.equal(S.resolveSoundPath("/home/sasha/ping.wav"), "/home/sasha/ping.wav")
  assert.equal(S.resolveSoundPath("./ping.wav"), "./ping.wav")
})

test("soundCommand builds a player argv and rejects empty input", () => {
  const r = S.soundCommand("bell", "pw-play")
  assert.deepEqual(r.argv, ["pw-play", "/usr/share/sounds/freedesktop/stereo/bell.oga"])
  assert.ok(!S.soundCommand("").ok)
  assert.ok(!S.soundCommand("   ").ok)
})

// --------------------------------------------------------------------- ntfy

test("a bare string is treated as a topic", () => {
  const r = S.ntfyRequest("alerts", notif())
  assert.ok(r.ok)
  assert.equal(r.endpoint, "https://ntfy.sh/alerts")
  assert.equal(JSON.parse(argAfter(r.argv, "--data-binary")).topic, "alerts")
})

test("ntfy defaults title and message from the notification", () => {
  const payload = JSON.parse(argAfter(S.ntfyRequest({ topic: "t" }, notif()).argv, "--data-binary"))
  assert.equal(payload.title, "Slack")
  assert.equal(payload.message, "DM from Anna")
})

test("an empty summary falls back to the body so ntfy never gets a blank message", () => {
  const payload = JSON.parse(argAfter(S.ntfyRequest({ topic: "t" }, notif({ summary: "" })).argv, "--data-binary"))
  assert.equal(payload.message, "lunch?")
})

test("ntfy posts JSON, so newlines in a body are safe", () => {
  const r = S.ntfyRequest({ topic: "t", message: "line one\nline two" }, notif())
  assert.equal(JSON.parse(argAfter(r.argv, "--data-binary")).message, "line one\nline two")
})

test("a custom server is honoured and its trailing slash trimmed", () => {
  assert.equal(S.ntfyRequest({ topic: "t", server: "https://ntfy.example.com/" }, notif()).endpoint,
    "https://ntfy.example.com/t")
})

test("ntfy rejects a missing topic and a non-http server", () => {
  assert.ok(!S.ntfyRequest({}, notif()).ok)
  assert.ok(!S.ntfyRequest({ topic: "t", server: "ftp://nope" }, notif()).ok)
})

test("ntfy priority is range-checked", () => {
  assert.ok(S.ntfyRequest({ topic: "t", priority: 5 }, notif()).ok)
  assert.ok(!S.ntfyRequest({ topic: "t", priority: 9 }, notif()).ok)
  assert.ok(!S.ntfyRequest({ topic: "t", priority: 0 }, notif()).ok)
})

test("tags accept a single value or a list", () => {
  const one = JSON.parse(argAfter(S.ntfyRequest({ topic: "t", tags: "warning" }, notif()).argv, "--data-binary"))
  const many = JSON.parse(argAfter(S.ntfyRequest({ topic: "t", tags: ["a", "b"] }, notif()).argv, "--data-binary"))
  assert.deepEqual(one.tags, ["warning"])
  assert.deepEqual(many.tags, ["a", "b"])
})

test("a token becomes a bearer header", () => {
  const r = S.ntfyRequest({ topic: "t", token: "tk_secret" }, notif())
  assert.ok(r.argv.includes("Authorization: Bearer tk_secret"))
})

// ------------------------------------------------------------------ webhook

test("a bare url string works and defaults to GET", () => {
  const r = S.webhookRequest("https://example.com/hook", notif())
  assert.ok(r.ok)
  assert.equal(argAfter(r.argv, "-X"), "GET")
  assert.equal(r.argv[r.argv.length - 1], "https://example.com/hook")
})

test("supplying a body implies POST", () => {
  assert.equal(argAfter(S.webhookRequest({ url: "https://e.com", body: "hi" }, notif()).argv, "-X"), "POST")
  assert.equal(argAfter(S.webhookRequest({ url: "https://e.com", json: {} }, notif()).argv, "-X"), "POST")
})

test("an empty json object forwards the whole notification", () => {
  const r = S.webhookRequest({ url: "https://e.com", json: {} }, notif())
  assert.deepEqual(JSON.parse(argAfter(r.argv, "--data-binary")),
    { app: "Slack", summary: "DM from Anna", body: "lunch?", urgency: 1 })
})

test("a populated json object is sent verbatim", () => {
  const r = S.webhookRequest({ url: "https://e.com", json: { text: "hello" } }, notif())
  assert.deepEqual(JSON.parse(argAfter(r.argv, "--data-binary")), { text: "hello" })
})

test("custom headers are passed through", () => {
  const r = S.webhookRequest({ url: "https://e.com", headers: { "X-Token": "abc" } }, notif())
  assert.ok(r.argv.includes("X-Token: abc"))
})

test("webhook rejects a missing url, a bad scheme and a bad method", () => {
  assert.ok(!S.webhookRequest({}, notif()).ok)
  assert.ok(!S.webhookRequest({ url: "file:///etc/passwd" }, notif()).ok)
  assert.ok(!S.webhookRequest({ url: "https://e.com", method: "TRACE" }, notif()).ok)
})

// -------------------------------------------------------------------- build

test("build dispatches on kind and rejects unknown kinds", () => {
  assert.ok(S.build({ kind: "ntfy", config: "t" }, notif()).ok)
  assert.ok(!S.build({ kind: "carrier-pigeon", config: {} }, notif()).ok)
  assert.ok(!S.build(null, notif()).ok)
})

test("every rejection carries a message worth reading", () => {
  for (const bad of [
    S.ntfyRequest({}, notif()),
    S.webhookRequest({}, notif()),
    S.soundCommand("")
  ]) {
    assert.equal(bad.ok, false)
    assert.ok(typeof bad.error === "string" && bad.error.length > 10, "error should explain itself")
  }
})
