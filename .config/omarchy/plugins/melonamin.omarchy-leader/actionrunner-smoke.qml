import QtQuick
import Quickshell
import "engine"

ShellRoot {
  id: root

  property int testIndex: -1

  function item(action) {
    return { id: "test", label: "Test action", notify: "never", action: action }
  }

  function fail(message) {
    console.error("ACTIONRUNNER_FAIL: " + message)
    Qt.quit()
  }

  function next() {
    testIndex += 1
    watchdog.restart()
    if (testIndex === 0) {
      runner.run(item({ type: "command", argv: ["bash", "-lc", "printf ready"] }))
    } else if (testIndex === 1) {
      runner.run(item({
        type: "workflow",
        steps: [
          { type: "command", argv: ["bash", "-lc", "printf first"] },
          "referenced"
        ]
      }))
    } else if (testIndex === 2) {
      runner.runProvider(item({
        type: "provider",
        argv: ["bash", "-lc", "printf '[{\"key\":\"a\",\"label\":\"Alpha\"}]'"]
      }))
    } else if (testIndex === 3) {
      runner.run(item({
        type: "command",
        argv: ["bash", "-lc", "printf broken >&2; exit 7"]
      }))
    } else {
      watchdog.stop()
      console.log("ACTIONRUNNER_PASS")
      Qt.quit()
    }
  }

  ActionRunner {
    id: runner
    providerTimeoutMs: 1000
    resolveItem: function(id) {
      if (id !== "referenced") return null
      return { action: { type: "command", argv: ["bash", "-lc", "printf referenced"] } }
    }

    onSucceeded: function(message) {
      if (root.testIndex === 0 && message === "ready") root.next()
      else if (root.testIndex === 1 && message === "Test action") root.next()
      else root.fail("unexpected success at test " + root.testIndex + ": " + message)
    }

    onFailed: function(message) {
      if (root.testIndex === 3 && message === "broken") root.next()
      else root.fail("unexpected failure at test " + root.testIndex + ": " + message)
    }

    onProviderLoaded: function(rows) {
      if (root.testIndex === 2 && rows.length === 1 && rows[0].key === "a") root.next()
      else root.fail("unexpected provider result")
    }
  }

  Timer {
    id: watchdog
    interval: 5000
    repeat: false
    onTriggered: root.fail("timed out at test " + root.testIndex)
  }

  Component.onCompleted: Qt.callLater(next)
}
