import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property string pluginDir: ""
  property string pluginId: "melonamin.omarchy-leader"
  property string phase: "idle"
  property var candidates: []
  property int selectedIndex: 0
  property string fileHash: ""
  property string bindingsPath: ""
  property string currentBinding: ""
  property string errorMessage: ""
  property string backupPath: ""

  readonly property var selectedCandidate: candidates.length > 0
    ? candidates[Math.max(0, Math.min(selectedIndex, candidates.length - 1))]
    : null

  signal closeRequested()
  signal installed(string binding)

  function start() {
    phase = "scanning"
    errorMessage = ""
    candidates = []
    selectedIndex = 0
    scan.command = ["bash", pluginDir + "/scripts/binding-helper", "status", pluginId]
    scan.running = true
  }

  function move(delta) {
    if (phase !== "selecting" || candidates.length === 0) return
    selectedIndex = (selectedIndex + delta + candidates.length) % candidates.length
  }

  function applySelected() {
    if (phase !== "selecting" || !selectedCandidate) return
    if (!selectedCandidate.available) {
      errorMessage = "That shortcut is already used by " + (selectedCandidate.description || "another action")
      return
    }
    phase = "applying"
    errorMessage = ""
    apply.command = [
      "bash",
      pluginDir + "/scripts/binding-helper",
      "apply",
      selectedCandidate.binding,
      fileHash,
      pluginId
    ]
    apply.running = true
  }

  function handleKey(key, text) {
    if (key === Qt.Key_Escape) {
      closeRequested()
      return true
    }
    if (phase === "selecting") {
      if (key === Qt.Key_Up || text === "k") { move(-1); return true }
      if (key === Qt.Key_Down || text === "j") { move(1); return true }
      if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
        applySelected()
        return true
      }
    }
    if (phase === "error" && String(text || "").toLowerCase() === "r") {
      start()
      return true
    }
    if (phase === "success" && (key === Qt.Key_Return || key === Qt.Key_Enter)) {
      closeRequested()
      return true
    }
    return false
  }

  Process {
    id: scan
    stdout: StdioCollector { id: scanOut; waitForEnd: true }
    stderr: StdioCollector { id: scanErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.phase = "error"
        root.errorMessage = String(scanErr.text || "Could not inspect Hyprland bindings").trim()
        return
      }
      try {
        var result = JSON.parse(String(scanOut.text || "{}"))
        root.candidates = result.candidates || []
        root.fileHash = String(result.fileHash || "")
        root.bindingsPath = String(result.bindingsPath || "")
        root.currentBinding = String(result.currentBinding || "")
        root.phase = "selecting"
        for (var i = 0; i < root.candidates.length; i++) {
          if (root.candidates[i].available) { root.selectedIndex = i; break }
        }
      } catch (error) {
        root.phase = "error"
        root.errorMessage = "Could not parse binding scan: " + error
      }
    }
  }

  Process {
    id: apply
    stdout: StdioCollector { id: applyOut; waitForEnd: true }
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.phase = "error"
        root.errorMessage = String(applyErr.text || "Could not install leader binding").trim()
        return
      }
      try {
        var result = JSON.parse(String(applyOut.text || "{}"))
        root.currentBinding = String(result.binding || "")
        root.backupPath = String(result.backup || "")
        root.phase = "success"
        root.installed(root.currentBinding)
      } catch (error) {
        root.phase = "error"
        root.errorMessage = "Binding changed, but its result could not be parsed: " + error
      }
    }
  }
}
