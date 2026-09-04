// Pure helpers shared by Service.qml, Panel.qml, and the node test suite.
// The capture CLI speaks camelCase JSON (CaptureAppState / LikelyMeeting) with
// snake_case status values ("idle", "recording", "paused", "audio_only").

function buildCommand(cliPath, profileDir, args) {
  var command = [String(cliPath || "secondscribe-capture")]
  var profile = String(profileDir || "").trim()
  if (profile !== "") command.push("--profile", profile)
  command.push("--json")
  return command.concat(args || [])
}

function statusLabel(status) {
  switch (String(status || "")) {
    case "idle": return "Idle"
    case "recording": return "Recording"
    case "paused": return "Paused"
    case "audio_only": return "Recording · audio only"
    default: return "Unknown"
  }
}

function isActive(status) {
  var value = String(status || "")
  return value === "recording" || value === "paused" || value === "audio_only"
}

function startTimeLabel(startsAt) {
  var stamp = Date.parse(String(startsAt || ""))
  if (!isFinite(stamp)) return ""
  var date = new Date(stamp)
  var hours = String(date.getHours())
  var minutes = String(date.getMinutes())
  if (hours.length < 2) hours = "0" + hours
  if (minutes.length < 2) minutes = "0" + minutes
  return hours + ":" + minutes
}

function normalizeMeeting(meeting) {
  var value = meeting || {}
  return {
    id: String(value.id || ""),
    title: String(value.title || "Untitled meeting"),
    startsAt: String(value.startsAt || ""),
    startLabel: startTimeLabel(value.startsAt),
    participantCount: Number(value.participantCount || 0)
  }
}

function normalizeMeetings(list) {
  var result = []
  if (Array.isArray(list)) {
    for (var i = 0; i < list.length; i++) result.push(normalizeMeeting(list[i]))
  }
  return result
}

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, message: "Empty status output" }
  try {
    var data = JSON.parse(text)
    var status = String(data.status || "idle")
    return {
      ok: true,
      status: status,
      active: isActive(status),
      paused: status === "paused",
      meetingTitle: data.meetingTitle ? String(data.meetingTitle) : "",
      startedAtMs: Number(data.captureStartedAtMs || 0),
      pausedAtMs: Number(data.pausedAtMs || 0),
      pausedTotalMs: Number(data.pausedTotalMs || 0),
      meetings: normalizeMeetings(data.likelyMeetings),
      transcriptionDegraded: data.transcriptionDegraded === true,
      serverNotice: data.serverNotice ? String(data.serverNotice) : "",
      microphoneNotice: data.microphoneFallbackNotice ? String(data.microphoneFallbackNotice) : "",
      deviceName: String(data.deviceName || ""),
      modelStatus: String(data.modelStatus || "")
    }
  } catch (error) {
    return { ok: false, message: "Status parse error", error: String(error) }
  }
}

function parseMeetings(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: true, meetings: [] }
  try {
    return { ok: true, meetings: normalizeMeetings(JSON.parse(text)) }
  } catch (error) {
    return { ok: false, message: "Meetings parse error", error: String(error) }
  }
}

// Errors arrive on stderr as {"error":{"code","message"}} when --json is set,
// or as "error[code]: message" without it.
function parseCliError(raw, fallback) {
  var text = String(raw || "").trim()
  if (text === "") return { code: "unknown", message: String(fallback || "Command failed") }
  try {
    var data = JSON.parse(text)
    if (data && data.error) {
      return {
        code: String(data.error.code || "unknown"),
        message: String(data.error.message || fallback || "Command failed")
      }
    }
  } catch (ignored) {}
  var match = text.match(/^error\[([^\]]+)\]:\s*(.*)$/m)
  if (match) return { code: match[1], message: match[2] }
  return { code: "unknown", message: text.split("\n")[0] }
}

// Elapsed capture time excluding completed pauses. While paused the clock
// freezes at pausedAtMs; pausedTotalMs only accumulates finished pauses.
function formatElapsed(state, nowMs) {
  if (!state || !state.active || !(state.startedAtMs > 0)) return ""
  var end = state.paused && state.pausedAtMs > 0 ? state.pausedAtMs : Number(nowMs || 0)
  var elapsed = end - state.startedAtMs - Number(state.pausedTotalMs || 0)
  if (!isFinite(elapsed) || elapsed < 0) elapsed = 0
  var totalSeconds = Math.floor(elapsed / 1000)
  var hours = Math.floor(totalSeconds / 3600)
  var minutes = Math.floor((totalSeconds % 3600) / 60)
  var seconds = String(totalSeconds % 60)
  if (seconds.length < 2) seconds = "0" + seconds
  if (hours > 0) {
    var paddedMinutes = String(minutes)
    if (paddedMinutes.length < 2) paddedMinutes = "0" + paddedMinutes
    return hours + ":" + paddedMinutes + ":" + seconds
  }
  return minutes + ":" + seconds
}

if (typeof module !== "undefined") {
  module.exports = {
    buildCommand: buildCommand,
    statusLabel: statusLabel,
    isActive: isActive,
    startTimeLabel: startTimeLabel,
    normalizeMeeting: normalizeMeeting,
    normalizeMeetings: normalizeMeetings,
    parseStatus: parseStatus,
    parseMeetings: parseMeetings,
    parseCliError: parseCliError,
    formatElapsed: formatElapsed
  }
}
