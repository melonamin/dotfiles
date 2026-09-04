import QtQuick 2.15
import QtTest 1.3
import "../engine" as Engine
import "../engine/ConfigParser.js" as ConfigParser

TestCase {
  id: testCase
  name: "LeaderEngine"

  property var parsedConfig: null

  Engine.LeaderEngine { id: engine }

  SignalSpy { id: actionSpy; target: engine; signalName: "actionRequested" }
  SignalSpy { id: closeSpy; target: engine; signalName: "closeRequested" }

  function init() {
    var parsed = ConfigParser.parse(`{
      "version": 1,
      "ui": { "sequenceTimeoutMs": 5000, "expandAfterMs": 4000 },
      "items": {
        "dev": { "key": "d", "label": "Dev" },
        "dev.git": { "key": "g", "label": "Git" },
        "dev.git.status": {
          "key": "s",
          "label": "Status",
          "action": { "type": "command", "argv": ["git", "status"] }
        }
      }
    }`)
    compare(parsed.errors.length, 0)
    parsedConfig = parsed.config
    engine.configure(parsedConfig)
    actionSpy.clear()
    closeSpy.clear()
    engine.close()
  }

  function cleanup() {
    engine.close()
  }

  function test_arms_on_first_unmodified_key() {
    verify(engine.open())
    compare(engine.phase, "arming")
    verify(engine.handleText("d", Qt.NoModifier))
    verify(engine.armed)
    compare(engine.currentId, "dev")
    compare(engine.path.length, 1)
  }

  function test_modifier_does_not_advance_sequence() {
    verify(engine.open())
    verify(engine.handleText("d", Qt.MetaModifier))
    compare(engine.currentId, "root")
    verify(!engine.armed)
  }

  function test_nested_sequence_requests_action() {
    verify(engine.open())
    engine.handleText("d", Qt.NoModifier)
    engine.handleText("g", Qt.NoModifier)
    engine.handleText("s", Qt.NoModifier)
    compare(actionSpy.count, 1)
    compare(engine.phase, "executing")
    compare(engine.typedKeys.join(""), "dgs")
  }

  function test_back_tracks_one_level() {
    verify(engine.open())
    engine.handleText("d", Qt.NoModifier)
    engine.handleText("g", Qt.NoModifier)
    verify(engine.handleSpecial(Qt.Key_Backspace))
    compare(engine.currentId, "dev")
    compare(engine.path.length, 1)
  }

  function test_unknown_key_reveals_error_board() {
    verify(engine.open())
    engine.handleText("x", Qt.NoModifier)
    compare(engine.phase, "error")
    compare(engine.displayMode, "board")
    verify(engine.errorMessage.length > 0)
  }

  function test_zero_timeout_stays_open() {
    var noTimeout = ConfigParser.clone(parsedConfig)
    noTimeout.ui.sequenceTimeoutMs = 0
    engine.configure(noTimeout)
    verify(engine.open())
    wait(350)
    compare(closeSpy.count, 0)
    verify(engine.active)
  }
}
