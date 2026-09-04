import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "engine" as Engine
import "setup" as Setup
import "ui" as Ui

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  // Resolve from this file instead of waiting for omarchy-shell to inject the
  // manifest. Child objects begin loading before that injection is complete.
  readonly property string entryUrl: String(Qt.resolvedUrl("Leader.qml"))
  readonly property string pluginDir: decodeURIComponent(entryUrl
    .replace(/^file:\/\//, "")
    .replace(/\/Leader\.qml$/, ""))

  property bool opened: false
  property bool setupOpen: false
  property bool configErrorOpen: false
  property bool focusPrimed: false

  readonly property string requestedRenderer: setupOpen ? "setup" : (configErrorOpen ? "board" : engine.displayMode)
  readonly property var configErrorModel: ({
    active: true,
    armed: true,
    phase: "error",
    path: [],
    choices: [],
    typedKeys: [],
    errorMessage: configStore.errors.join("\n"),
    statusMessage: "Edit " + configStore.configPath + " and reopen the leader.",
    currentId: "root",
    revision: configStore.generation
  })
  readonly property var currentModel: configErrorOpen ? configErrorModel : engine.presentationModel

  function parsePayload(payloadJson) {
    try { return JSON.parse(payloadJson || "{}") } catch (error) { return ({}) }
  }

  function open(payloadJson) {
    var payload = parsePayload(payloadJson)
    setupOpen = payload.setup === true || payload.mode === "setup"
    configErrorOpen = false

    if (setupOpen) {
      opened = true
      focusPrimed = false
      bindingSetup.start()
      focusTimer.restart()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }

    if (!configStore.config || configStore.errors.length > 0) {
      configErrorOpen = true
      opened = true
      focusPrimed = false
      focusTimer.restart()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }

    engine.configure(configStore.config)
    if (!engine.open()) return
    actionRunner.providerTimeoutMs = configStore.config.providers.timeoutMs
    opened = true
    focusPrimed = false
    focusTimer.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    opened = false
    setupOpen = false
    configErrorOpen = false
    focusTimer.stop()
    focusPrimed = false
    engine.close()
  }

  function refresh() {
    configStore.reload()
    rendererRegistry.refresh()
    return "ok"
  }

  function ping() { return "ok" }
  function setup() { open('{"setup":true}'); return "ok" }

  Engine.ConfigStore {
    id: configStore
    defaultPath: root.pluginDir ? root.pluginDir + "/config.default.jsonc" : ""
    onLoaded: {
      engine.configure(config)
      if (!engine.active) root.configErrorOpen = false
    }
  }

  Engine.LeaderEngine {
    id: engine
    onCloseRequested: root.close()
    onActionRequested: function(item) { actionRunner.run(item) }
    onProviderRequested: function(item) { actionRunner.runProvider(item) }
  }

  Engine.ActionRunner {
    id: actionRunner
    appLibrary: root.shell ? root.shell.appLibrary : null
    resolveItem: function(id) { return engine.itemById(id) }
    onSucceeded: function(message) { engine.actionSucceeded(message) }
    onFailed: function(message) { engine.actionFailed(message) }
    onProviderLoaded: function(rows) { engine.providerLoaded(rows) }
  }

  Ui.ThemeBridge { id: theme }

  Ui.RendererRegistry {
    id: rendererRegistry
    pluginDir: root.pluginDir
    onPluginDirChanged: if (pluginDir) refresh()
  }

  Setup.BindingSetup {
    id: bindingSetup
    pluginDir: root.pluginDir
    onCloseRequested: root.close()
  }

  Timer {
    id: focusTimer
    interval: 75
    repeat: false
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-leader"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: root.requestedRenderer === "trail"
        ? Qt.rgba(theme.scrim.r, theme.scrim.g, theme.scrim.b, 0.08)
        : theme.scrim

      Behavior on color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      onClicked: root.close()
    }

    Item {
      id: rendererFrame

      property bool revealAnimationEnabled: true

      function concealForSwap() {
        revealAnimationEnabled = false
        opacity = 0
        scale = 0.985
        revealAnimationEnabled = true
      }

      function reveal() {
        opacity = 1
        scale = 1
      }

      width: rendererLoader.item ? rendererLoader.item.implicitWidth : 680
      height: rendererLoader.item ? rendererLoader.item.implicitHeight : 420
      x: root.requestedRenderer === "corner"
        ? panel.width - width - Math.max(18, theme.outerGap * 3)
        : Math.round((panel.width - width) / 2)
      y: root.requestedRenderer === "trail"
        ? Math.max(28, theme.outerGap * 5)
        : root.requestedRenderer === "corner"
          ? panel.height - height - Math.max(18, theme.outerGap * 3)
          : Math.round((panel.height - height) / 2)

      Behavior on opacity {
        enabled: rendererFrame.revealAnimationEnabled
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
      }

      Behavior on scale {
        enabled: rendererFrame.revealAnimationEnabled
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }

      MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true } }

      Loader {
        id: rendererLoader
        anchors.fill: parent
        source: root.setupOpen
          ? Qt.resolvedUrl("ui/Setup.qml")
          : rendererRegistry.sourceFor(root.requestedRenderer)

        onSourceChanged: rendererFrame.concealForSwap()

        onLoaded: {
          if (!item) return
          if (root.setupOpen) {
            item.setupModel = Qt.binding(function() { return bindingSetup })
            item.theme = Qt.binding(function() { return theme })
          } else {
            item.model = Qt.binding(function() { return root.currentModel })
            item.theme = Qt.binding(function() { return theme })
          }
          Qt.callLater(function() { rendererFrame.reveal() })
        }

        onStatusChanged: {
          if (status !== Loader.Error || root.setupOpen || root.requestedRenderer === "board") return
          console.warn("omarchy-leader: renderer failed; falling back to Board", source)
          Qt.callLater(function() {
            engine.displayMode = "board"
            engine.bump()
          })
        }
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem

      Keys.onPressed: function(event) {
        if (root.setupOpen) {
          if (bindingSetup.handleKey(event.key, event.text)) event.accepted = true
          return
        }
        if (root.configErrorOpen) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.close()
            event.accepted = true
          }
          return
        }
        if (engine.handleSpecial(event.key)) {
          event.accepted = true
          return
        }
        if (event.text && event.text.length === 1) {
          if (engine.handleText(event.text, event.modifiers)) event.accepted = true
        }
      }
    }

    onVisibleChanged: {
      if (visible) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }
}
