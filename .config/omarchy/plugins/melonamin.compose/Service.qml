import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "ComposeModel.js" as ComposeModel

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: manifest && manifest.id ? manifest.id : "melonamin.compose"
  readonly property string sourceDir: manifest && manifest.__sourceDir ? manifest.__sourceDir : ""
  readonly property string luaPath: sourceDir ? sourceDir + "/hypr/compose.lua" : ""
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"

  property var settings: ComposeModel.settingsFrom(null)
  readonly property string requestedShortcut: String(settings.shortcut || "")
  property bool shortcutRegistered: false
  property bool bindsInstalled: false
  property string shortcutDiagnostic: ""
  property bool repairAllowed: false

  // Redacted UI/document state. Compose.qml owns content and updates only
  // counts and health here so IPC status can never leak a user's expansions.
  property bool uiOpen: false
  property string uiMode: "quick"
  property string rootRevision: ""
  property int sourceCount: 0
  property int ruleCount: 0
  property int diagnosticsCount: 0
  property var diagnosticKinds: ({})
  property var diagnosticReasons: ({})
  property bool dirty: false
  property bool fcitxHealthy: false
  property bool fcitxHealthKnown: false

  function setUiState(state) {
    var value = state || {}
    uiOpen = value.open === true
    uiMode = value.mode === "studio" ? "studio" : "quick"
    rootRevision = String(value.revision || "")
    sourceCount = Number(value.sourceCount || 0)
    ruleCount = Number(value.ruleCount || 0)
    diagnosticsCount = Number(value.diagnosticsCount || 0)
    diagnosticKinds = value.diagnosticKinds || ({})
    diagnosticReasons = value.diagnosticReasons || ({})
    dirty = value.dirty === true
  }

  function summon(mode) {
    if (!shell || typeof shell.summon !== "function") return false
    return shell.summon(pluginId, JSON.stringify({ mode: mode })) === true
  }

  function dismiss() {
    if (!shell || typeof shell.hide !== "function") return false
    return shell.hide(pluginId) === true
  }

  function effectiveDiagnosticSummary() {
    var kinds = {}
    var reasons = {}
    var count = diagnosticsCount
    for (var kind in diagnosticKinds) kinds[kind] = diagnosticKinds[kind]
    for (var reason in diagnosticReasons) reasons[reason] = diagnosticReasons[reason]
    if (fcitxHealthKnown && !fcitxHealthy) {
      kinds["input-method"] = (kinds["input-method"] || 0) + 1
      reasons["omarchy-fcitx5.service is not active; saved rules cannot be activated"] = 1
      count++
    }
    if (shortcutDiagnostic) {
      kinds.shortcut = (kinds.shortcut || 0) + 1
      reasons[shortcutDiagnostic] = (reasons[shortcutDiagnostic] || 0) + 1
      count++
    }
    return { count: count, kinds: kinds, reasons: reasons }
  }

  function writeShortcut(value) {
    var normalized = ComposeModel.normalizeShortcut(value)
    if (!shell || typeof shell.mutateShellConfig !== "function") return false
    shell.mutateShellConfig(function(config) {
      ComposeModel.writePluginSetting(config, root.pluginId, "shortcut", normalized)
    })
    var next = {}
    for (var key in settings) next[key] = settings[key]
    next.shortcut = normalized
    settings = next
    installBinds(false)
    return true
  }

  FileView {
    path: root.configPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.settings = ComposeModel.settingsFrom(null)
  }

  function applyConfig(raw) {
    var parsed
    try { parsed = JSON.parse(raw) }
    catch (error) { console.warn("compose: could not parse shell.json:", error); return }
    var next = ComposeModel.settingsFrom(ComposeModel.findPluginEntry(parsed, pluginId))
    var changed = next.shortcut !== settings.shortcut
    settings = next
    if (changed && luaPath) installBinds(false)
  }

  function luaQuote(value) {
    return "'" + String(value || "").replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'"
  }

  function removeCollidingBind() {
    if (!luaPath) return
    Quickshell.execDetached(["hyprctl", "-i", "0", "eval",
      "dofile(" + luaQuote(luaPath) + "); omarchy_compose.uninstall()"])
  }

  function installBinds(afterReload) {
    if (!luaPath) return
    if (binder.running) {
      binder.queued = true
      if (afterReload) binder.queuedStale = true
      return
    }
    binder.command = ["hyprctl", "-i", "0", "eval",
      "dofile(" + luaQuote(luaPath) + "); omarchy_compose.install(" + luaQuote(requestedShortcut) + ", " + (afterReload ? "true" : "false") + ")"]
    binder.running = true
  }

  Process {
    id: binder
    property bool queued: false
    property bool queuedStale: false
    onExited: function(code) {
      root.bindsInstalled = code === 0
      if (code !== 0) {
        root.shortcutDiagnostic = "Could not register the Compose shortcut"
        console.warn("compose: hyprctl eval failed with", code)
      } else if (!shortcutCheck.running) shortcutCheck.running = true
      if (queued) {
        queued = false
        var stale = queuedStale
        queuedStale = false
        root.installBinds(stale)
      }
    }
  }

  Process {
    id: shortcutCheck
    command: ["hyprctl", "-i", "0", "binds", "-j"]
    stdout: StdioCollector { id: shortcutOutput; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) {
        root.repairAllowed = false
        return
      }
      var bindings = []
      try { bindings = JSON.parse(String(shortcutOutput.text || "[]")) } catch (error) { root.repairAllowed = false; return }
      var chord = ComposeModel.shortcutChord(root.requestedShortcut)
      var found = false
      var collision = false
      for (var index = 0; index < bindings.length; index++) {
        var binding = bindings[index] || {}
        var sameChord = Number(binding.modmask || 0) === chord.modmask && String(binding.key || "").toUpperCase() === chord.key && String(binding.submap || "") === ""
        if (!sameChord) continue
        if (String(binding.description || "") === "Compose: Quick picker") found = true
        else collision = true
      }
      root.shortcutRegistered = root.requestedShortcut !== "" && found && !collision
      if (root.requestedShortcut === "") root.shortcutDiagnostic = "Shortcut disabled"
      else if (collision) root.shortcutDiagnostic = "Shortcut collision: " + root.requestedShortcut
      else if (!found) root.shortcutDiagnostic = "Compose shortcut is not registered"
      else root.shortcutDiagnostic = ""
      if (collision && found) root.removeCollidingBind()
      if (!found && !collision && root.requestedShortcut !== "" && root.repairAllowed && !binder.running) {
        root.repairAllowed = false
        root.installBinds(true)
      }
    }
  }

  onLuaPathChanged: if (luaPath) installBinds(false)

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") reinstall.restart()
    }
  }

  Timer {
    id: reinstall
    interval: 400
    onTriggered: root.installBinds(true)
  }

  // The event singleton normally catches configreloaded. A low-frequency
  // described-bind check also repairs the shortcut after a compositor restart
  // or a stale inherited instance signature prevents that event connection.
  Timer {
    interval: 15000
    repeat: true
    running: root.luaPath !== ""
    onTriggered: if (!shortcutCheck.running) { root.repairAllowed = true; shortcutCheck.running = true }
  }

  Process {
    id: healthCheck
    command: ["systemctl", "--user", "is-active", "omarchy-fcitx5.service"]
    onExited: function(code) {
      root.fcitxHealthy = code === 0
      root.fcitxHealthKnown = true
    }
  }

  Timer {
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!healthCheck.running) healthCheck.running = true
  }

  IpcHandler {
    target: "compose"

    function quick(): string { return root.summon("quick") ? "ok" : "unavailable" }
    function manage(): string { return root.summon("studio") ? "ok" : "unavailable" }
    function close(): string { return root.dismiss() ? "ok" : "unavailable" }
    function status(): string {
      var summary = root.effectiveDiagnosticSummary()
      return JSON.stringify({
        mode: root.uiMode,
        open: root.uiOpen,
        requestedShortcut: root.requestedShortcut,
        registeredShortcut: root.shortcutRegistered ? root.requestedShortcut : "",
        rootRevision: root.rootRevision,
        sourceCount: root.sourceCount,
        ruleCount: root.ruleCount,
        diagnosticsCount: summary.count,
        diagnosticKinds: summary.kinds,
        diagnosticReasons: summary.reasons,
        dirty: root.dirty,
        fcitx5Healthy: root.fcitxHealthy,
        fcitx5HealthKnown: root.fcitxHealthKnown,
        shortcutDiagnostic: root.shortcutDiagnostic
      })
    }
  }

  Component.onDestruction: {
    if (!luaPath) return
    Quickshell.execDetached(["hyprctl", "-i", "0", "eval",
      "dofile(" + luaQuote(luaPath) + "); omarchy_compose.uninstall()"])
  }
}
