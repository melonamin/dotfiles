import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool installed: false
  property bool daemonRunning: false
  property bool refreshing: false
  property bool startingDaemon: false

  property string status: "idle"
  property bool active: false
  property bool paused: false
  property string meetingTitle: ""
  property real startedAtMs: 0
  property real pausedAtMs: 0
  property real pausedTotalMs: 0
  property var meetings: []
  property bool transcriptionDegraded: false
  property string serverNotice: ""
  property string microphoneNotice: ""

  property string lastError: ""
  property string actionStatus: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 10, 2, 3600)
  readonly property bool busy: actionProcess.running
  readonly property string statusText: {
    if (!installed) return "CLI not found"
    if (!daemonRunning) return startingDaemon ? "Starting daemon…" : "Daemon not running"
    return Model.statusLabel(status)
  }

  property string statusOutput: ""
  property string statusErrorOutput: ""
  property bool statusTimedOut: false
  property string meetingsOutput: ""
  property string meetingsErrorOutput: ""
  property string actionOutput: ""
  property string actionErrorOutput: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function cliPath() {
    return String(setting("cliPath", "secondscribe-capture"))
  }

  function command(args) {
    return Model.buildCommand(cliPath(), setting("profileDir", ""), args)
  }

  function elideMessage(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 140 ? value.substring(0, 137) + "…" : value
  }

  function clearCapture() {
    status = "idle"
    active = false
    paused = false
    meetingTitle = ""
    startedAtMs = 0
    pausedAtMs = 0
    pausedTotalMs = 0
  }

  function applyStatus(raw) {
    var parsed = Model.parseStatus(raw)
    if (!parsed.ok) {
      lastError = elideMessage(parsed.message)
      return
    }
    status = parsed.status
    active = parsed.active
    paused = parsed.paused
    meetingTitle = parsed.meetingTitle
    startedAtMs = parsed.startedAtMs
    pausedAtMs = parsed.pausedAtMs
    pausedTotalMs = parsed.pausedTotalMs
    if (parsed.meetings.length > 0 || !active) meetings = parsed.meetings
    transcriptionDegraded = parsed.transcriptionDegraded
    serverNotice = parsed.serverNotice
    microphoneNotice = parsed.microphoneNotice
    lastError = ""
  }

  function refresh() {
    if (!installed) {
      if (!whichProcess.running) {
        refreshing = true
        whichProcess.command = ["which", cliPath()]
        whichProcess.running = true
      }
      return
    }
    if (statusProcess.running) return
    refreshing = true
    statusOutput = ""
    statusErrorOutput = ""
    statusTimedOut = false
    statusProcess.command = command(["status"])
    statusProcess.running = true
    watchdog.restart()
  }

  function refreshMeetings() {
    if (!installed || !daemonRunning || meetingsProcess.running) return
    meetingsOutput = ""
    meetingsErrorOutput = ""
    meetingsProcess.command = command(["meetings"])
    meetingsProcess.running = true
  }

  function startMeeting(meeting) {
    if (meeting && meeting.id) runAction(["start", "--meeting", meeting.id], "Starting…")
  }

  function startTitle(title) {
    var value = String(title || "").trim()
    if (value !== "") runAction(["start", "--title", value], "Starting…")
  }

  function stop() { runAction(["stop"], "Stopping…") }
  function pause() { runAction(["pause"], "Pausing…") }
  function resume() { runAction(["resume"], "Resuming…") }

  function togglePause() {
    if (paused) resume()
    else pause()
  }

  function runAction(args, label) {
    if (!installed || !daemonRunning || actionProcess.running) return
    actionOutput = ""
    actionErrorOutput = ""
    actionStatus = label || ""
    actionProcess.command = command(args)
    actionProcess.running = true
  }

  function startDaemon() {
    if (!installed || daemonRunning || startingDaemon) return
    startingDaemon = true
    lastError = ""
    Quickshell.execDetached(command(["daemon", "run"]))
    daemonRamp.ticks = 0
    daemonRamp.running = true
  }

  onDaemonRunningChanged: {
    if (daemonRunning) {
      startingDaemon = false
      daemonRamp.running = false
      refreshMeetings()
    }
  }

  Timer {
    interval: (root.active ? 3 : root.refreshIntervalSec) * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: daemonRamp
    property int ticks: 0
    interval: 1500
    repeat: true
    running: false
    onTriggered: {
      ticks += 1
      if (ticks > 20) {
        running = false
        root.startingDaemon = false
        root.lastError = "Daemon did not come up"
        return
      }
      root.refresh()
    }
  }

  Timer {
    id: delayedRefresh
    interval: 600
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: messageTimer
    interval: 2500
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Timer {
    id: watchdog
    interval: 15000
    repeat: false
    onTriggered: if (statusProcess.running) {
      root.statusTimedOut = true
      statusProcess.running = false
      root.refreshing = false
      root.lastError = "Capture status timed out"
    }
  }

  Process {
    id: whichProcess
    running: false
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      if (root.installed) root.refresh()
      else {
        root.refreshing = false
        root.daemonRunning = false
        root.clearCapture()
      }
    }
  }

  Process {
    id: statusProcess
    running: false
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root.statusOutput = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root.statusErrorOutput = text }
    onExited: function(exitCode) {
      watchdog.stop()
      root.refreshing = false
      var output = String(statusStdout.text || root.statusOutput || "")
      var errorOutput = String(statusStderr.text || root.statusErrorOutput || "")
      if (root.statusTimedOut) {
        root.statusTimedOut = false
        return
      }
      if (exitCode === 0) {
        root.daemonRunning = true
        root.applyStatus(output)
        return
      }
      var failure = Model.parseCliError(errorOutput, "Could not read capture status")
      if (failure.code === "daemon_not_running") {
        root.daemonRunning = false
        root.clearCapture()
        if (!root.startingDaemon) root.lastError = ""
      } else {
        root.lastError = root.elideMessage(failure.message)
      }
    }
  }

  Process {
    id: meetingsProcess
    running: false
    stdout: StdioCollector { id: meetingsStdout; waitForEnd: true; onStreamFinished: root.meetingsOutput = text }
    stderr: StdioCollector { id: meetingsStderr; waitForEnd: true; onStreamFinished: root.meetingsErrorOutput = text }
    onExited: function(exitCode) {
      var output = String(meetingsStdout.text || root.meetingsOutput || "")
      var errorOutput = String(meetingsStderr.text || root.meetingsErrorOutput || "")
      if (exitCode === 0) {
        var parsed = Model.parseMeetings(output)
        if (parsed.ok) root.meetings = parsed.meetings
        else root.lastError = root.elideMessage(parsed.message)
      } else {
        var failure = Model.parseCliError(errorOutput, "Could not list meetings")
        if (failure.code !== "daemon_not_running") root.lastError = root.elideMessage(failure.message)
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root.actionOutput = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root.actionErrorOutput = text }
    onExited: function(exitCode) {
      var output = String(actionStdout.text || root.actionOutput || "")
      var errorOutput = String(actionStderr.text || root.actionErrorOutput || "")
      if (exitCode === 0) {
        root.actionStatus = ""
        root.applyStatus(output)
      } else {
        var failure = Model.parseCliError(errorOutput, "Capture command failed")
        root.lastError = root.elideMessage(failure.message)
        root.actionStatus = root.lastError
        messageTimer.restart()
      }
      delayedRefresh.restart()
    }
  }
}
