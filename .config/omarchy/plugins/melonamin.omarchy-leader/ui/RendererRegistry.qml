import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property string pluginDir: ""
  property string userDir: Quickshell.env("HOME") + "/.config/omarchy/leader/interfaces"
  property var renderers: ({})
  property var errors: []

  function builtinRenderers() {
    return {
      board: { id: "board", name: "Board", source: String(Qt.resolvedUrl("Board.qml")), apiVersion: 1 },
      trail: { id: "trail", name: "Trail HUD", source: String(Qt.resolvedUrl("Trail.qml")), apiVersion: 1 },
      corner: { id: "corner", name: "Corner Guide", source: String(Qt.resolvedUrl("Corner.qml")), apiVersion: 1 }
    }
  }

  function refresh() {
    renderers = builtinRenderers()
    if (!pluginDir || scanner.running) return
    scanner.command = ["bash", pluginDir + "/scripts/list-renderers", userDir]
    scanner.running = true
  }

  function sourceFor(id) {
    var renderer = renderers[String(id || "")]
    if (!renderer) renderer = renderers.board || builtinRenderers().board
    return String(renderer.source).indexOf("file:") === 0
      ? renderer.source
      : "file://" + renderer.source
  }

  Process {
    id: scanner
    stdout: StdioCollector { id: scannerOut; waitForEnd: true }
    stderr: StdioCollector { id: scannerErr; waitForEnd: true }
    onExited: function(exitCode) {
      var next = root.builtinRenderers()
      var nextErrors = []
      if (exitCode === 0) {
        try {
          var found = JSON.parse(String(scannerOut.text || "[]"))
          for (var i = 0; i < found.length; i++) {
            var renderer = found[i]
            if (renderer.apiVersion !== 1 || !renderer.id || !renderer.source) continue
            if (next[renderer.id]) continue
            next[renderer.id] = renderer
          }
        } catch (error) {
          nextErrors.push("Could not parse interface registry: " + error)
        }
      } else {
        var message = String(scannerErr.text || "").trim()
        if (message) nextErrors.push(message)
      }
      root.renderers = next
      root.errors = nextErrors
    }
  }

  Component.onCompleted: refresh()
}
