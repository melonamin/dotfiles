// Drives the full capture lifecycle through the fake CLI using the exact
// command lines Service.qml builds, then parses the real stdout/stderr with
// Model.js — the same pipeline the widget runs, minus the QML layer.
process.env.TZ = "UTC"

const test = require("node:test")
const assert = require("node:assert")
const { spawnSync } = require("node:child_process")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const Model = require("../Model.js")

const cliPath = path.join(__dirname, "fixtures", "fake-capture-cli")

function run(profileDir, args) {
  const command = Model.buildCommand(cliPath, profileDir, args)
  const result = spawnSync(command[0], command.slice(1), { encoding: "utf8" })
  assert.strictEqual(result.error, undefined, String(result.error))
  return result
}

test("capture lifecycle: idle → start meeting → pause → resume → stop", () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), "scribe-widget-test-"))

  let result = run(profileDir, ["status"])
  assert.strictEqual(result.status, 0, result.stderr)
  let state = Model.parseStatus(result.stdout)
  assert.strictEqual(state.ok, true)
  assert.strictEqual(state.status, "idle")
  assert.strictEqual(state.active, false)
  assert.strictEqual(state.meetings.length, 2)
  assert.strictEqual(state.meetings[0].startLabel, "14:30")

  result = run(profileDir, ["meetings"])
  assert.strictEqual(result.status, 0, result.stderr)
  const meetings = Model.parseMeetings(result.stdout)
  assert.strictEqual(meetings.ok, true)
  assert.strictEqual(meetings.meetings[1].title, "Design review")

  result = run(profileDir, ["start", "--meeting", meetings.meetings[0].id])
  assert.strictEqual(result.status, 0, result.stderr)
  state = Model.parseStatus(result.stdout)
  assert.strictEqual(state.status, "recording")
  assert.strictEqual(state.meetingTitle, "Weekly sync")
  assert.ok(state.startedAtMs > 0)

  result = run(profileDir, ["start", "--title", "Another one"])
  assert.strictEqual(result.status, 4)
  const conflict = Model.parseCliError(result.stderr, "fallback")
  assert.strictEqual(conflict.code, "capture_active")

  result = run(profileDir, ["pause"])
  assert.strictEqual(result.status, 0, result.stderr)
  state = Model.parseStatus(result.stdout)
  assert.strictEqual(state.paused, true)
  assert.ok(state.pausedAtMs > 0)
  assert.notStrictEqual(Model.formatElapsed(state, Date.now() + 60000), "")

  result = run(profileDir, ["resume"])
  assert.strictEqual(result.status, 0, result.stderr)
  state = Model.parseStatus(result.stdout)
  assert.strictEqual(state.status, "recording")

  result = run(profileDir, ["stop"])
  assert.strictEqual(result.status, 0, result.stderr)
  state = Model.parseStatus(result.stdout)
  assert.strictEqual(state.status, "idle")
  assert.strictEqual(state.meetingTitle, "")

  fs.rmSync(profileDir, { recursive: true, force: true })
})

test("ad-hoc title capture round-trips", () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), "scribe-widget-test-"))

  const result = run(profileDir, ["start", "--title", "Hallway chat"])
  assert.strictEqual(result.status, 0, result.stderr)
  const state = Model.parseStatus(result.stdout)
  assert.strictEqual(state.status, "recording")
  assert.strictEqual(state.meetingTitle, "Hallway chat")

  fs.rmSync(profileDir, { recursive: true, force: true })
})

test("daemon-down surfaces the daemon_not_running code on exit 3", () => {
  const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), "scribe-widget-test-"))
  fs.writeFileSync(path.join(profileDir, "daemon-down"), "")

  const result = run(profileDir, ["status"])
  assert.strictEqual(result.status, 3)
  const failure = Model.parseCliError(result.stderr, "fallback")
  assert.strictEqual(failure.code, "daemon_not_running")

  fs.rmSync(profileDir, { recursive: true, force: true })
})
