import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "melonamin.quick-panels"
  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy"
  readonly property string configPath: configDir + "/quick-panels.json"
  readonly property var appLibrary: shell ? shell.appLibrary : null

  property var config: Model.safeDefaultConfig(home)
  property var lastValidConfig: null
  property bool configMissing: false
  property bool configReady: false
  property string configError: ""
  property int configRevision: 0
  property int catalogRevision: 0
  property int toplevelRevision: 0
  property bool forcedOpen: false

  readonly property var catalog: {
    var ignored = catalogRevision
    var entries = DesktopEntries.applications.values || []
    var result = []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || entry.noDisplay || !entry.id) continue
      result.push({
        id: String(entry.id),
        name: String(entry.name || entry.id),
        icon: String(entry.icon || ""),
        startupClass: String(entry.startupClass || "")
      })
    }
    return result
  }

  readonly property var resolvedItems: {
    var ignoredConfig = configRevision
    var ignoredCatalog = catalogRevision
    return Model.resolveItems(config, catalog, home)
  }

  function open(payloadJson) {
    forcedOpen = true
  }

  function close() {
    forcedOpen = false
  }

  function toggle() {
    forcedOpen = !forcedOpen
  }

  function reload() {
    configFile.reload()
    return "ok"
  }

  function loadConfig(rawText) {
    var result = Model.loadConfig(rawText, lastValidConfig, Model.safeDefaultConfig(home))
    config = result.value
    configReady = true
    configError = result.error || ""
    if (result.valid) {
      lastValidConfig = Model.cloneJson(result.value)
      configMissing = false
    } else {
      console.warn(pluginId + ": configuration error at " + configPath + ": " + configError)
    }
    configRevision++
  }

  function initializeMissingConfig() {
    if (!configMissing) return
    var starter = Model.starterConfig(catalog, home)
    var serialized = Model.serializeConfig(starter)
    configFile.setText(serialized)
    loadConfig(serialized)
    console.log(pluginId + ": created starter configuration at " + configPath)
  }

  function iconSource(item) {
    var icon = String((item && (item.icon || item.entryIcon)) || "")
    if (item && item.type === "folder" && !icon) {
      icon = String(item.name || "").toLowerCase() === "downloads" ? "folder-download" : "folder"
    }
    if (!icon) icon = item && item.type === "invalid" ? "dialog-warning" : "application-x-executable"
    if (appLibrary) return appLibrary.iconSource(icon)
    if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0) return icon
    if (icon.charAt(0) === "/") return Util.fileUrl(icon)
    return Quickshell.iconPath(icon, true)
  }

  function matchingToplevel(item) {
    var ignored = toplevelRevision
    var values = ToplevelManager.toplevels.values || []
    for (var i = 0; i < values.length; i++) {
      var candidate = values[i]
      if (candidate && Model.toplevelMatches(item, candidate.appId)) return candidate
    }
    return null
  }

  function isRunning(item) {
    return matchingToplevel(item) !== null
  }

  function activateItem(item, forceLaunch) {
    if (!item || item.available === false) return
    if (item.type === "app") {
      if (!forceLaunch) {
        var toplevel = matchingToplevel(item)
        if (toplevel) {
          try {
            toplevel.activate()
            return
          } catch (error) {
            console.warn(pluginId + ": could not focus " + item.desktopId + ": " + error)
          }
        }
      }

      if (appLibrary) {
        appLibrary.launch(item.desktopId, item.name)
        return
      }

      var entry = DesktopEntries.byId(item.desktopId) || DesktopEntries.byId(item.desktopId + ".desktop")
      if (entry) entry.execute()
      else console.warn(pluginId + ": desktop entry disappeared: " + item.desktopId)
      return
    }

    if (item.type === "folder") {
      Util.execArgv(["uwsm-app", "--", "xdg-open", item.path])
    }
  }

  function statusJson() {
    var screens = []
    var values = Quickshell.screens || []
    for (var i = 0; i < values.length; i++) screens.push(String(values[i].name || ""))
    return JSON.stringify({
      version: 1,
      open: forcedOpen,
      configuration: { valid: configError === "", error: configError || null, path: configPath },
      screens: screens,
      items: resolvedItems.length
    })
  }

  Process {
    id: configDirPrep
    command: ["mkdir", "-p", root.configDir]
    onExited: root.initializeMissingConfig()
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadConfig(text())
    onLoadFailed: function(error) {
      root.configMissing = true
      root.configReady = true
      root.configError = ""
      root.initializeMissingConfig()
    }
    onFileChanged: reload()
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() {
      root.catalogRevision++
      root.initializeMissingConfig()
    }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.toplevelRevision++ }
  }

  IpcHandler {
    target: root.pluginId
    function open(): string { root.open("{}"); return "ok" }
    function close(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function reload(): string { return root.reload() }
    function status(): string { return root.statusJson() }
    function ping(): string { return "ok" }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      EdgeDock {
        required property var modelData

        screen: modelData
        screenEnabled: Model.screenEnabled(root.config.screens, modelData ? modelData.name : "")
        dockConfig: root.config
        items: root.resolvedItems
        configError: root.configError
        forcedOpen: root.forcedOpen
        iconProvider: function(item) { return root.iconSource(item) }
        runningProvider: function(item) { return root.isRunning(item) }
        onActivated: function(item, forceLaunch) {
          root.activateItem(item, forceLaunch)
          if (root.config.closeOnLaunch) root.forcedOpen = false
        }
      }
    }
  }

  Component.onCompleted: configDirPrep.running = true
}
