import QtQuick 2.15
import "ConfigParser.js" as ConfigParser

Item {
  id: root
  visible: false

  property var config: null
  property var snapshot: null
  property bool active: false
  property bool armed: false
  property string phase: "closed"
  property string currentId: "root"
  property var path: []
  property var choices: []
  property var typedKeys: []
  property string displayMode: "trail"
  property string errorMessage: ""
  property string statusMessage: ""
  property var dynamicChoices: ({})
  property var pendingItem: null
  property int revision: 0

  readonly property var presentationModel: ({
    active: root.active,
    armed: root.armed,
    phase: root.phase,
    path: root.path,
    choices: root.choices,
    typedKeys: root.typedKeys,
    errorMessage: root.errorMessage,
    statusMessage: root.statusMessage,
    currentId: root.currentId,
    revision: root.revision
  })

  signal closeRequested()
  signal actionRequested(var item)
  signal providerRequested(var item)

  function bump() { revision += 1 }

  function configure(nextConfig) {
    config = nextConfig
  }

  function open() {
    if (!config) return false
    snapshot = ConfigParser.clone(config)
    active = true
    armed = false
    phase = "arming"
    currentId = "root"
    path = []
    choices = ConfigParser.children(snapshot, "root")
    typedKeys = []
    dynamicChoices = ({})
    pendingItem = null
    errorMessage = ""
    statusMessage = "Release leader keys"
    displayMode = snapshot.ui.start
    pauseTimer.interval = snapshot.ui.expandAfterMs
    restartTimeout()
    pauseTimer.restart()
    bump()
    return true
  }

  function close() {
    timeoutTimer.stop()
    pauseTimer.stop()
    active = false
    armed = false
    phase = "closed"
    pendingItem = null
    errorMessage = ""
    statusMessage = ""
    bump()
  }

  function restartTimers() {
    restartTimeout()
    if (phase === "active") pauseTimer.restart()
  }

  function restartTimeout() {
    timeoutTimer.stop()
    if (!snapshot || snapshot.ui.sequenceTimeoutMs <= 0) return
    timeoutTimer.interval = snapshot.ui.sequenceTimeoutMs
    timeoutTimer.restart()
  }

  function arm() {
    if (armed) return
    armed = true
    phase = "active"
    statusMessage = ""
    pauseTimer.restart()
    bump()
  }

  function pathLabel() {
    var labels = ["Home"]
    for (var i = 0; i < path.length; i++) labels.push(path[i].label)
    return labels.join(" › ")
  }

  function itemById(id) {
    return snapshot && snapshot.items ? snapshot.items[id] : null
  }

  function hasChildren(id) {
    return ConfigParser.children(snapshot, id).length > 0
  }

  function enter(item) {
    currentId = item.id
    path = path.concat([item])
    typedKeys = typedKeys.concat([item.key])
    choices = dynamicChoices[item.id] || ConfigParser.children(snapshot, item.id)
    phase = "active"
    errorMessage = ""
    statusMessage = ""
    restartTimers()
    bump()
  }

  function goBack() {
    if (path.length === 0) {
      closeRequested()
      return
    }
    var nextPath = path.slice(0, path.length - 1)
    currentId = nextPath.length > 0 ? nextPath[nextPath.length - 1].id : "root"
    path = nextPath
    typedKeys = typedKeys.slice(0, typedKeys.length - 1)
    choices = dynamicChoices[currentId] || ConfigParser.children(snapshot, currentId)
    phase = "active"
    errorMessage = ""
    statusMessage = ""
    restartTimers()
    bump()
  }

  function showError(message) {
    phase = "error"
    errorMessage = String(message || "Unknown error")
    statusMessage = ""
    displayMode = snapshot.ui.onError
    pauseTimer.stop()
    restartTimeout()
    bump()
  }

  function handleText(text, modifiers) {
    if (!active) return false
    var blockedModifiers = modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
    if (blockedModifiers) {
      statusMessage = "Release leader modifiers"
      phase = "arming"
      armed = false
      bump()
      return true
    }

    if (!armed) arm()
    var normalized = String(text || "").toLowerCase()
    if (normalized.length !== 1) return false

    for (var i = 0; i < choices.length; i++) {
      var item = choices[i]
      if (item.key !== normalized) continue

      errorMessage = ""
      if (item.action && item.action.type === "provider") {
        pendingItem = item
        phase = "loading"
        typedKeys = typedKeys.concat([item.key])
        statusMessage = "Loading " + item.label + "…"
        pauseTimer.stop()
        restartTimeout()
        bump()
        providerRequested(item)
        return true
      }
      if (!item.action || hasChildren(item.id)) {
        enter(item)
        return true
      }

      pendingItem = item
      phase = "executing"
      typedKeys = typedKeys.concat([item.key])
      statusMessage = "Running " + item.label + "…"
      pauseTimer.stop()
      restartTimeout()
      bump()
      actionRequested(item)
      return true
    }

    showError("No action for “" + normalized + "”")
    return true
  }

  function handleSpecial(key) {
    if (!active) return false
    if (key === Qt.Key_Escape) {
      closeRequested()
      return true
    }
    if (key === Qt.Key_Backspace || key === Qt.Key_Left) {
      if (!armed) arm()
      goBack()
      return true
    }
    if (key === Qt.Key_Question || key === Qt.Key_F1) {
      if (!armed) arm()
      displayMode = "board"
      phase = "active"
      restartTimers()
      bump()
      return true
    }
    return false
  }

  function actionSucceeded(message) {
    var item = pendingItem
    pendingItem = null
    phase = "success"
    statusMessage = String(message || (item ? item.label : "Done"))
    errorMessage = ""
    bump()

    if (item && item.sticky) {
      displayMode = snapshot.ui.sticky
      phase = "active"
      statusMessage = ""
      typedKeys = typedKeys.slice(0, Math.max(0, typedKeys.length - 1))
      restartTimers()
      bump()
    } else {
      successTimer.restart()
    }
  }

  function actionFailed(message) {
    pendingItem = null
    showError(message)
  }

  function providerLoaded(rows) {
    var item = pendingItem
    pendingItem = null
    if (!item) return

    var normalized = []
    var seen = {}
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      if (!row || typeof row !== "object") continue
      var key = String(row.key || "").toLowerCase()
      if (key.length !== 1 || seen[key]) continue
      seen[key] = true
      row.id = item.id + ".provider." + i
      row.parent = item.id
      row.key = key
      row.label = String(row.label || row.title || row.id)
      row.icon = String(row.icon || "")
      row.sticky = row.sticky === true
      row.notify = row.notify === true ? "always" : String(row.notify || "never")
      normalized.push(row)
    }
    if (normalized.length === 0) {
      showError("Provider returned no usable choices")
      return
    }
    var nextDynamic = ConfigParser.clone(dynamicChoices)
    nextDynamic[item.id] = normalized
    dynamicChoices = nextDynamic
    currentId = item.id
    path = path.concat([item])
    choices = normalized
    phase = "active"
    statusMessage = ""
    errorMessage = ""
    restartTimers()
    bump()
  }

  Timer {
    id: timeoutTimer
    interval: 3000
    repeat: false
    onTriggered: if (root.active) root.closeRequested()
  }

  Timer {
    id: pauseTimer
    interval: 700
    repeat: false
    onTriggered: {
      if (!root.active || !root.snapshot || root.phase !== "active") return
      root.displayMode = root.snapshot.ui.onPause
      root.bump()
    }
  }

  Timer {
    id: successTimer
    interval: 120
    repeat: false
    onTriggered: if (root.active) root.closeRequested()
  }
}
