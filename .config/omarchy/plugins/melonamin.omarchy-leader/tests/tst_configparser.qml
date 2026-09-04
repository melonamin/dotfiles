import QtQuick 2.15
import QtTest 1.3
import "../engine/ConfigParser.js" as ConfigParser

TestCase {
  name: "ConfigParser"

  function test_parses_jsonc_and_hierarchy() {
    var parsed = ConfigParser.parse(`{
      // comment
      "version": 1,
      "items": {
        "dev": { "key": "d", "label": "Dev", },
        "dev.git": {
          "key": "g",
          "label": "Git",
          "action": { "type": "command", "argv": ["git", "status"], },
        },
      },
    }`)

    compare(parsed.errors.length, 0)
    compare(parsed.config.items["dev.git"].parent, "dev")
    compare(ConfigParser.children(parsed.config, "root").length, 1)
    compare(ConfigParser.children(parsed.config, "dev")[0].key, "g")
  }

  function test_preserves_urls_with_double_slashes() {
    var parsed = ConfigParser.parse(`{
      "version": 1,
      "items": {
        "docs": {
          "key": "d",
          "label": "Docs",
          "action": { "type": "open", "target": "https://example.com/docs" }
        }
      }
    }`)

    compare(parsed.errors.length, 0)
    compare(parsed.config.items.docs.action.target, "https://example.com/docs")
  }

  function test_zero_disables_sequence_timeout() {
    var parsed = ConfigParser.parse(`{
      "version": 1,
      "ui": { "sequenceTimeoutMs": 0 },
      "items": {
        "test": { "key": "t", "label": "Test" }
      }
    }`)

    compare(parsed.errors.length, 0)
    compare(parsed.config.ui.sequenceTimeoutMs, 0)
  }

  function test_rejects_duplicate_sibling_keys() {
    var parsed = ConfigParser.parse(`{
      "version": 1,
      "items": {
        "one": { "key": "x", "label": "One" },
        "two": { "key": "x", "label": "Two" }
      }
    }`)

    verify(parsed.errors.join("\n").indexOf("conflicts") >= 0)
  }

  function test_rejects_missing_parent() {
    var parsed = ConfigParser.parse(`{
      "version": 1,
      "items": {
        "missing.child": { "key": "c", "label": "Child" }
      }
    }`)

    verify(parsed.errors.join("\n").indexOf("does not exist") >= 0)
  }
}
