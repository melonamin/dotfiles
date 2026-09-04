import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigParser.js" as ConfigParser

Item {
  id: root
  visible: false

  property string configPath: Quickshell.env("HOME") + "/.config/omarchy/leader/config.jsonc"
  property string defaultPath: ""
  property var config: null
  property var errors: []
  property bool valid: config !== null && errors.length === 0
  property bool initialized: false
  property bool usingDefaults: false
  property bool userUnavailable: false
  property int generation: 0
  property string defaultText: ""

  signal loaded()
  signal loadFailed(var errors)

  function apply(raw, fromDefaults) {
    var result = ConfigParser.parse(raw)
    errors = result.errors
    if (!result.config || result.errors.length > 0) {
      loadFailed(errors)
      return false
    }
    config = result.config
    usingDefaults = fromDefaults === true
    initialized = true
    generation += 1
    loaded()
    return true
  }

  function reload() {
    userFile.reload()
  }

  function ensureUserCopy() {
    if (!defaultText || ensureDir.running) return
    ensureDir.running = true
  }

  FileView {
    id: defaultFile
    path: root.defaultPath
    printErrors: false
    onLoaded: {
      root.defaultText = text()
      if (!root.initialized) root.apply(root.defaultText, true)
      if (root.userUnavailable) root.ensureUserCopy()
    }
    onLoadFailed: function(error) {
      root.errors = ["Could not load bundled configuration: " + error]
      root.loadFailed(root.errors)
    }
  }

  FileView {
    id: userFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.userUnavailable = false
      root.apply(text(), false)
    }
    onLoadFailed: function() {
      root.userUnavailable = true
      if (root.defaultText) {
        root.apply(root.defaultText, true)
        root.ensureUserCopy()
      }
    }
    onFileChanged: reload()
  }

  Process {
    id: ensureDir
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/omarchy/leader"]
    onExited: function(exitCode) {
      if (exitCode !== 0 || !root.defaultText) return
      userFile.setText(root.defaultText)
      Qt.callLater(function() { userFile.reload() })
    }
  }
}
