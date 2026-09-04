process.env.TZ = "UTC"

const test = require("node:test")
const assert = require("node:assert")
const Model = require("../Model.js")

test("buildCommand shapes the CLI invocation", () => {
  assert.deepStrictEqual(
    Model.buildCommand("secondscribe-capture", "", ["status"]),
    ["secondscribe-capture", "--json", "status"]
  )
  assert.deepStrictEqual(
    Model.buildCommand("/opt/scribe/bin/secondscribe-capture", "/home/user/.scribe", ["start", "--meeting", "m1"]),
    ["/opt/scribe/bin/secondscribe-capture", "--profile", "/home/user/.scribe", "--json", "start", "--meeting", "m1"]
  )
  assert.deepStrictEqual(Model.buildCommand("", "  ", []), ["secondscribe-capture", "--json"])
})

test("statusLabel and isActive cover every CaptureStatus value", () => {
  assert.strictEqual(Model.statusLabel("idle"), "Idle")
  assert.strictEqual(Model.statusLabel("recording"), "Recording")
  assert.strictEqual(Model.statusLabel("paused"), "Paused")
  assert.strictEqual(Model.statusLabel("audio_only"), "Recording · audio only")
  assert.strictEqual(Model.statusLabel("bogus"), "Unknown")
  assert.strictEqual(Model.isActive("idle"), false)
  assert.strictEqual(Model.isActive("recording"), true)
  assert.strictEqual(Model.isActive("paused"), true)
  assert.strictEqual(Model.isActive("audio_only"), true)
})

test("parseStatus normalizes a recording state", () => {
  const parsed = Model.parseStatus(JSON.stringify({
    status: "recording",
    captureStartedAtMs: 1000,
    pausedAtMs: null,
    pausedTotalMs: 0,
    meetingTitle: "Weekly sync",
    likelyMeetings: [
      { id: "m1", title: "Weekly sync", startsAt: "2026-08-26T14:30:00Z", participantCount: 4 }
    ],
    transcriptionDegraded: false,
    serverNotice: null,
    microphoneFallbackNotice: null,
    deviceName: "desk",
    modelStatus: "ready"
  }))
  assert.strictEqual(parsed.ok, true)
  assert.strictEqual(parsed.status, "recording")
  assert.strictEqual(parsed.active, true)
  assert.strictEqual(parsed.paused, false)
  assert.strictEqual(parsed.meetingTitle, "Weekly sync")
  assert.strictEqual(parsed.startedAtMs, 1000)
  assert.strictEqual(parsed.meetings.length, 1)
  assert.strictEqual(parsed.meetings[0].id, "m1")
  assert.strictEqual(parsed.meetings[0].startLabel, "14:30")
  assert.strictEqual(parsed.meetings[0].participantCount, 4)
})

test("parseStatus handles paused, audio_only, and malformed payloads", () => {
  const paused = Model.parseStatus(JSON.stringify({
    status: "paused", captureStartedAtMs: 1000, pausedAtMs: 5000, pausedTotalMs: 200
  }))
  assert.strictEqual(paused.paused, true)
  assert.strictEqual(paused.active, true)

  const audioOnly = Model.parseStatus(JSON.stringify({ status: "audio_only", transcriptionDegraded: true }))
  assert.strictEqual(audioOnly.active, true)
  assert.strictEqual(audioOnly.transcriptionDegraded, true)

  assert.strictEqual(Model.parseStatus("{").ok, false)
  assert.strictEqual(Model.parseStatus("").ok, false)
})

test("parseMeetings tolerates empty output and rejects malformed JSON", () => {
  assert.deepStrictEqual(Model.parseMeetings(""), { ok: true, meetings: [] })
  const parsed = Model.parseMeetings(JSON.stringify([
    { id: "m2", title: "1:1", startsAt: "2026-08-26T09:05:00Z", participantCount: 2 }
  ]))
  assert.strictEqual(parsed.ok, true)
  assert.strictEqual(parsed.meetings[0].startLabel, "09:05")
  assert.strictEqual(Model.parseMeetings("not json").ok, false)
})

test("startTimeLabel falls back to empty for unparseable stamps", () => {
  assert.strictEqual(Model.startTimeLabel("2026-08-26T14:30:00Z"), "14:30")
  assert.strictEqual(Model.startTimeLabel("whenever"), "")
  assert.strictEqual(Model.startTimeLabel(""), "")
})

test("parseCliError reads JSON, human, and unknown formats", () => {
  const json = Model.parseCliError('{"error":{"code":"daemon_not_running","message":"no socket"}}')
  assert.deepStrictEqual(json, { code: "daemon_not_running", message: "no socket" })
  const human = Model.parseCliError("error[capture_active]: a capture is already running")
  assert.deepStrictEqual(human, { code: "capture_active", message: "a capture is already running" })
  const unknown = Model.parseCliError("segfault\nmore", "fallback")
  assert.deepStrictEqual(unknown, { code: "unknown", message: "segfault" })
  const empty = Model.parseCliError("", "fallback")
  assert.deepStrictEqual(empty, { code: "unknown", message: "fallback" })
})

test("formatElapsed counts running time and freezes while paused", () => {
  const running = { active: true, paused: false, startedAtMs: 1000, pausedAtMs: 0, pausedTotalMs: 0 }
  assert.strictEqual(Model.formatElapsed(running, 66000), "1:05")
  assert.strictEqual(Model.formatElapsed(running, 3724000), "1:02:03")

  const paused = { active: true, paused: true, startedAtMs: 1000, pausedAtMs: 31000, pausedTotalMs: 0 }
  assert.strictEqual(Model.formatElapsed(paused, 999999), "0:30")

  const withPastPauses = { active: true, paused: false, startedAtMs: 1000, pausedAtMs: 0, pausedTotalMs: 10000 }
  assert.strictEqual(Model.formatElapsed(withPastPauses, 71000), "1:00")

  assert.strictEqual(Model.formatElapsed({ active: false }, 1000), "")
  assert.strictEqual(Model.formatElapsed(null, 1000), "")
  const negative = { active: true, paused: false, startedAtMs: 5000, pausedAtMs: 0, pausedTotalMs: 0 }
  assert.strictEqual(Model.formatElapsed(negative, 1000), "0:00")
})
