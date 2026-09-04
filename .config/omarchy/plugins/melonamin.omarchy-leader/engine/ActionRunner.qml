import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property var appLibrary: null
  property var resolveItem: null
  property int providerTimeoutMs: 2500
  property var currentItem: null
  property var currentAction: null
  property var workflowQueue: []
  property bool workflowActive: false
  property bool providerActive: false
  property bool timedOut: false

  signal succeeded(string message)
  signal failed(string message)
  signal providerLoaded(var rows)

  function expandedPath(path) {
    var value = String(path || "")
    return value.indexOf("~/") === 0 ? Quickshell.env("HOME") + value.slice(1) : value
  }

  function notify(item, success, message) {
    if (!item) return
    var policy = String(item.notify || "never")
    if (policy !== "always" && !(policy === "on-error" && !success)) return
    Quickshell.execDetached([
      "notify-send",
      success ? "Omarchy Leader" : "Omarchy Leader · Error",
      String(message || item.label || "Action completed")
    ])
  }

  function run(item) {
    if (!item || !item.action) {
      failed("Action is missing")
      return
    }
    currentItem = item
    workflowQueue = []
    workflowActive = false
    runAction(item.action)
  }

  function runProvider(item) {
    if (!item || !item.action || item.action.type !== "provider") {
      failed("Provider action is invalid")
      return
    }
    currentItem = item
    providerActive = true
    runProcess(item.action, true)
  }

  function runAction(action) {
    currentAction = action
    var type = String(action.type || "")

    if (type === "launch") {
      var desktop = String(action.desktop || "").replace(/\.desktop$/, "")
      if (appLibrary && appLibrary.launch) appLibrary.launch(desktop, currentItem ? currentItem.label : desktop)
      else Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", desktop + ".desktop"])
      finishSuccess(currentItem ? currentItem.label : "Application launched")
      return
    }

    if (type === "open") {
      Quickshell.execDetached(["xdg-open", expandedPath(action.target)])
      finishSuccess(currentItem ? currentItem.label : "Opened")
      return
    }

    if (type === "workflow") {
      workflowQueue = action.steps.slice(0)
      workflowActive = true
      runNextWorkflowStep()
      return
    }

    runProcess(action, false)
  }

  function resolveStep(step) {
    if (typeof step === "string" && resolveItem) {
      var item = resolveItem(step)
      return item && item.action ? item.action : null
    }
    return step && typeof step === "object" ? step : null
  }

  function runNextWorkflowStep() {
    if (workflowQueue.length === 0) {
      workflowActive = false
      finishSuccess(currentItem ? currentItem.label : "Workflow complete")
      return
    }
    var step = resolveStep(workflowQueue[0])
    workflowQueue = workflowQueue.slice(1)
    if (!step) {
      finishFailure("Workflow contains an unknown action")
      return
    }
    if (step.type === "launch") {
      var desktop = String(step.desktop || "").replace(/\.desktop$/, "")
      if (appLibrary && appLibrary.launch) appLibrary.launch(desktop, currentItem ? currentItem.label : desktop)
      else Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", desktop + ".desktop"])
      Qt.callLater(root.runNextWorkflowStep)
      return
    }
    if (step.type === "open") {
      Quickshell.execDetached(["xdg-open", expandedPath(step.target)])
      Qt.callLater(root.runNextWorkflowStep)
      return
    }
    if (step.type === "workflow" || step.type === "provider") {
      finishFailure("Nested workflows and providers are not supported")
      return
    }
    currentAction = step
    runProcess(step, false)
  }

  function commandFor(action) {
    var type = String(action.type || "")
    if (type === "command" || type === "provider") {
      if (Array.isArray(action.argv) && action.argv.length > 0) return action.argv.map(String)
      if (action.command) return ["bash", "-lc", String(action.command)]
    }
    if (type === "shell") return ["bash", "-lc", String(action.command || "")]
    if (type === "omarchy") return ["omarchy"].concat((action.args || []).map(String))
    return []
  }

  function runProcess(action, isProvider) {
    var command = commandFor(action)
    if (command.length === 0) {
      finishFailure("Unsupported or empty command")
      return
    }
    providerActive = isProvider
    timedOut = false
    process.command = command
    process.workingDirectory = expandedPath(action.cwd || "")
    process.environment = action.env && typeof action.env === "object" ? action.env : ({})
    process.running = true
    processTimeout.interval = isProvider ? providerTimeoutMs : Math.max(1000, Number(action.timeoutMs || 15000))
    processTimeout.restart()
  }

  function finishSuccess(message) {
    if (workflowActive) {
      Qt.callLater(root.runNextWorkflowStep)
      return
    }
    notify(currentItem, true, message)
    succeeded(String(message || "Done"))
  }

  function finishFailure(message) {
    workflowQueue = []
    workflowActive = false
    providerActive = false
    notify(currentItem, false, message)
    failed(String(message || "Action failed"))
  }

  Process {
    id: process
    stdout: StdioCollector { id: processStdout; waitForEnd: true }
    stderr: StdioCollector { id: processStderr; waitForEnd: true }
    onExited: function(exitCode) {
      processTimeout.stop()
      if (root.timedOut) {
        root.timedOut = false
        return
      }
      var out = String(processStdout.text || "").trim()
      var error = String(processStderr.text || "").trim()
      if (exitCode !== 0) {
        root.finishFailure(error || "Command exited with status " + exitCode)
        return
      }
      if (root.providerActive) {
        root.providerActive = false
        try {
          var rows = JSON.parse(out)
          if (!Array.isArray(rows)) throw new Error("expected a JSON array")
          root.providerLoaded(rows)
        } catch (parseError) {
          root.finishFailure("Provider returned invalid JSON: " + parseError)
        }
        return
      }
      root.finishSuccess(out || (root.currentItem ? root.currentItem.label : "Done"))
    }
  }

  Timer {
    id: processTimeout
    interval: 15000
    repeat: false
    onTriggered: {
      if (!process.running) return
      root.timedOut = true
      process.running = false
      root.finishFailure(root.providerActive ? "Provider timed out" : "Action timed out")
    }
  }
}
