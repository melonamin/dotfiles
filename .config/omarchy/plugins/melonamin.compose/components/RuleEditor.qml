import QtQuick
import qs.Commons
import qs.Ui
import "../ComposeModel.js" as ComposeModel

Rectangle {
  id: root
  property var rule: null
  property string action: "new"
  property int sessionKey: 0
  property var existingRules: []
  property var keysymDefinitions: ({})
  property var sequence: ["Multi_key"]
  property var eventModifiers: [""]
  property bool advanced: false
  property string validationMessage: ""
  property string validationSeverity: "error"
  property bool canSave: false
  property bool syncing: false
  property bool resultStringPresent: false
  readonly property var chooserSuggestions: suggestKeysyms(chooserField.text)

  signal saveRequested(var rule, string rawRule)
  signal draftChanged(string rawRule)
  signal cancelRequested()

  color: Color.menu.background
  radius: Style.cornerRadius
  border.width: Math.max(1, Style.normalBorderWidth)
  border.color: Color.menu.selectedBorder

  function loadRule() {
    syncing = true
    var value = rule || {}
    sequence = value.sequence && value.sequence.length ? value.sequence.slice() : ["Multi_key"]
    eventModifiers = value.eventModifiers && value.eventModifiers.length
      ? value.eventModifiers.slice() : [value.modifiers || ""]
    resultStringPresent = (value.resultStringRaw !== null && value.resultStringRaw !== undefined)
      || (value.resultString !== null && value.resultString !== undefined)
    outputField.text = value.resultString !== null && value.resultString !== undefined ? value.resultString : ""
    commentField.text = value.comment || ""
    keysymField.text = value.resultKeysym || ""
    try { rawField.text = value.raw ? String(value.raw).replace(/(?:\r\n|\n|\r)$/, "") : ComposeModel.encodeRule(currentRule()) }
    catch (error) { rawField.text = "" }
    validationMessage = ""
    syncing = false
    draftChanged(rawField.text)
    validate()
  }

  function currentRule() {
    var modifiers = eventModifiers.slice()
    while (modifiers.length < sequence.length) modifiers.push("")
    return {
      sequence: sequence.slice(),
      modifiers: modifiers[0] || "",
      eventModifiers: modifiers,
      resultString: resultStringPresent ? outputField.text : null,
      resultKeysym: keysymField.text.trim(),
      comment: commentField.text
    }
  }

  function refreshRaw() {
    if (syncing) return
    try { rawField.text = ComposeModel.encodeRule(currentRule()) }
    catch (error) { rawField.text = "" }
    draftChanged(rawField.text)
    validate()
  }

  function validate() {
    var rawRule = ""
    if (!advanced) {
      if (sequence.length < 2) return setValidation("Record at least one key after Compose", "error", false)
      if (!resultStringPresent && !keysymField.text.trim()) return setValidation("Output or result keysym is required", "error", false)
      try { rawRule = ComposeModel.encodeRule(currentRule()) }
      catch (error) { return setValidation(String(error), "error", false) }
    } else rawRule = rawField.text

    var checked = ComposeModel.validateCandidate(rawRule + "\n", { keysymDefinitions: keysymDefinitions })
    var nodes = checked.document ? checked.document.nodes : []
    if (!checked.valid || nodes.length !== 1 || nodes[0].type !== "rule") {
      var message = checked.diagnostics.length ? checked.diagnostics[0].message : "Enter one valid Compose rule"
      return setValidation(message, "error", false)
    }
    var warning = conflictWarning(nodes[0])
    if (warning) return setValidation(warning, "warning", true)
    if (nodes[0].sequence.length > 6) return setValidation("Long sequence — confirm it is intentional", "warning", true)
    return setValidation("", "", true)
  }

  function setValidation(message, severity, valid) {
    validationMessage = String(message || "")
    validationSeverity = String(severity || "")
    canSave = valid === true
    return canSave
  }

  function conflictWarning(node) {
    var prefix = null
    for (var index = 0; index < existingRules.length; index++) {
      var existing = existingRules[index]
      if (!existing || !existing.active) continue
      if (rule && ((existing === rule) || (existing.id && existing.id === rule.id))) continue
      var relation = ComposeModel.sequenceRelation(existing.sequence, node.sequence)
      if (relation === "exact") {
        return existing.sourceKind === "Mine"
          ? "A local rule already uses this sequence; Save will replace it"
          : "This sequence will create a local override of " + existing.sourceKind
      }
      if (relation !== "none" && !prefix) prefix = existing
    }
    if (prefix) return "Prefix conflict with " + prefix.displaySequence + "; the later rule will shadow it"
    if (action === "override") return "This edit will be saved as a local override"
    return ""
  }

  function setModifierAt(index, value) {
    var next = eventModifiers.slice()
    while (next.length < sequence.length) next.push("")
    next[index] = String(value || "")
    eventModifiers = next
    refreshRaw()
  }

  function suggestKeysyms(value) {
    var needle = String(value || "").trim().toLowerCase()
    if (!needle) return []
    var exact = []
    var prefixes = []
    var contains = []
    var names = Object.keys(keysymDefinitions || {})
    for (var index = 0; index < names.length; index++) {
      var lower = names[index].toLowerCase()
      if (lower === needle) exact.push(names[index])
      else if (lower.indexOf(needle) === 0) prefixes.push(names[index])
      else if (lower.indexOf(needle) >= 0) contains.push(names[index])
    }
    exact.sort(); prefixes.sort(); contains.sort()
    return exact.concat(prefixes, contains).slice(0, 6)
  }

  function addKeysym(value) {
    var name = String(value || "").trim()
    if (!name) return
    var next = sequence.slice(); next.push(name); sequence = next
    var nextModifiers = eventModifiers.slice(); nextModifiers.push(""); eventModifiers = nextModifiers
    chooserField.text = ""
    refreshRaw()
  }

  function removeAt(index) {
    var next = sequence.slice()
    var nextModifiers = eventModifiers.slice()
    next.splice(index, 1)
    nextModifiers.splice(index, 1)
    sequence = next
    eventModifiers = nextModifiers
    refreshRaw()
  }

  function moveAt(index, delta) {
    var target = index + delta
    if (index < 1 || target < 1 || target >= sequence.length) return
    var next = sequence.slice()
    var nextModifiers = eventModifiers.slice()
    var value = next[index]
    var modifier = nextModifiers[index]
    next.splice(index, 1)
    nextModifiers.splice(index, 1)
    next.splice(target, 0, value)
    nextModifiers.splice(target, 0, modifier)
    sequence = next
    eventModifiers = nextModifiers
    refreshRaw()
  }

  function record(event) {
    if (event.key === Qt.Key_Control || event.key === Qt.Key_Shift || event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) return
    var mapped = ComposeModel.mapQtKey(event.key, event.text, event.modifiers)
    if (!mapped.valid || mapped.keysym === "Escape") return
    var next = sequence.slice()
    next.push(mapped.keysym)
    sequence = next
    var nextModifiers = eventModifiers.slice()
    nextModifiers.push(ComposeModel.qtModifiersToCompose(mapped.modifiers))
    eventModifiers = nextModifiers
    refreshRaw()
    event.accepted = true
  }

  onRuleChanged: loadRule()
  onSessionKeyChanged: loadRule()
  onAdvancedChanged: validate()
  onExistingRulesChanged: if (!syncing) validate()
  Component.onCompleted: loadRule()

  Column {
    anchors.fill: parent
    anchors.margins: Style.spacing.panelPadding
    spacing: Style.spacing.md

    Row {
      width: parent.width
      Text {
        width: parent.width - advancedButton.width
        text: root.action === "override" ? "Create local override" : root.action === "edit" ? "Edit local rule" : "New Compose rule"
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }
      Button {
        id: advancedButton
        text: root.advanced ? "Friendly" : "Advanced"
        selected: root.advanced
        focusable: true
        foreground: Color.menu.text
        onClicked: root.advanced = !root.advanced
      }
    }

    Column {
      visible: !root.advanced
      width: parent.width
      spacing: Style.spacing.sm

      Text { text: "Sequence"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      Flow {
        width: parent.width
        spacing: Style.spacing.sm
        KeyChip { label: root.sequence[0] === "Multi_key" ? "Compose" : root.sequence[0]; composeKey: root.sequence[0] === "Multi_key" }
        Repeater {
          model: root.sequence.slice(1)
          Row {
            required property int index
            required property string modelData
            spacing: Style.spacing.xs
            KeyChip { label: modelData; removable: true; onRemoveRequested: root.removeAt(index + 1) }
            Button { text: "←"; enabled: index > 0; focusable: true; foreground: Color.menu.text; onClicked: root.moveAt(index + 1, -1) }
            Button { text: "→"; enabled: index < root.sequence.length - 2; focusable: true; foreground: Color.menu.text; onClicked: root.moveAt(index + 1, 1) }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.space(40)
        radius: Style.cornerRadius
        color: Style.controlFill(recorder.activeFocus, recorder.containsMouse, Color.menu.text, Color.accent)
        border.width: Math.max(1, Style.normalBorderWidth)
        border.color: recorder.activeFocus ? Color.accent : Color.menu.selectedBorder
        Text { anchors.centerIn: parent; text: recorder.activeFocus ? "Type keys now…" : "Click to record keys after Compose"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        MouseArea { id: recorder; anchors.fill: parent; hoverEnabled: true; focus: true; onClicked: forceActiveFocus(); Keys.onPressed: event => root.record(event) }
      }

      Row {
        width: parent.width
        spacing: Style.spacing.sm
        TextField { id: chooserField; width: parent.width - chooserAdd.width - parent.spacing; placeholderText: "Search or enter an X11 keysym…"; Accessible.name: "Keysym chooser" }
        Button {
          id: chooserAdd
          text: "Add key"
          bordered: true
          focusable: true
          foreground: Color.menu.text
          onClicked: root.addKeysym(chooserField.text)
        }
      }

      Flow {
        width: parent.width
        spacing: Style.spacing.xs
        visible: root.chooserSuggestions.length > 0
        Repeater {
          model: root.chooserSuggestions
          Button {
            required property string modelData
            text: modelData
            focusable: true
            foreground: Color.menu.text
            onClicked: root.addKeysym(modelData)
          }
        }
      }

      Text { text: "Output"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      TextField { id: outputField; width: parent.width; placeholderText: "Text inserted by this sequence"; Accessible.name: "Compose output"; onTextEdited: { root.resultStringPresent = true; root.refreshRaw() } }
      Text { text: "Comment / label"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      TextField { id: commentField; width: parent.width; placeholderText: "Optional plain-language label"; Accessible.name: "Rule comment"; onTextEdited: root.refreshRaw() }
    }

    Column {
      visible: root.advanced
      width: parent.width
      spacing: Style.spacing.sm
      Text { text: "Raw XCompose rule"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      TextField {
        id: rawField
        width: parent.width
        placeholderText: '<Multi_key> <a> : "output" keysym # label'
        Accessible.name: "Raw XCompose rule"
        onTextEdited: {
          root.draftChanged(text)
          var parsed = ComposeModel.parseDocument(text + "\n", { keysymDefinitions: root.keysymDefinitions })
          if (parsed.nodes.length === 1 && parsed.nodes[0].type === "rule") {
            root.syncing = true
            var node = parsed.nodes[0]
            root.sequence = node.sequence.slice()
            root.eventModifiers = node.eventModifiers.slice()
            root.resultStringPresent = node.resultStringRaw !== null
            outputField.text = node.resultString !== null ? node.resultString : ""
            commentField.text = node.comment
            keysymField.text = node.resultKeysym
            root.syncing = false
          }
          root.validate()
        }
      }
      Text { text: "Per-event modifiers"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      Column {
        width: parent.width
        spacing: Style.spacing.xs
        Repeater {
          model: root.sequence
          Row {
            required property int index
            required property string modelData
            width: parent.width
            spacing: Style.spacing.sm
            Text { width: Style.space(150); anchors.verticalCenter: parent.verticalCenter; text: "<" + modelData + ">"; color: Color.menu.text; opacity: 0.72; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; elide: Text.ElideMiddle }
            TextField {
              width: parent.width - Style.space(150) - parent.spacing
              text: root.eventModifiers[index] || ""
              placeholderText: "None, ! Shift, ~Ctrl…"
              Accessible.name: "Modifiers for " + modelData
              onTextEdited: root.setModifierAt(index, text)
            }
          }
        }
      }
      Text { text: "Optional result keysym"; color: Color.menu.text; opacity: 0.7; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      TextField { id: keysymField; width: parent.width; placeholderText: "eacute"; Accessible.name: "Result keysym"; onTextEdited: root.refreshRaw() }
    }

    Text {
      visible: root.validationMessage !== ""
      width: parent.width
      text: root.validationMessage
      color: root.validationSeverity === "warning" ? Color.menu.text : Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Item { width: 1; height: Math.max(0, parent.height - y - actions.height) }

    Row {
      id: actions
      anchors.right: parent.right
      spacing: Style.spacing.sm
      Button { text: "Cancel"; bordered: true; focusable: true; foreground: Color.menu.text; onClicked: root.cancelRequested() }
      Button {
        text: root.action === "override" ? "Create override" : root.action === "edit" ? "Save" : "Add rule"
        bordered: true
        focusable: true
        enabled: root.canSave
        foreground: Color.menu.text
        accent: Color.accent
        onClicked: if (root.validate()) root.saveRequested(root.currentRule(), root.advanced ? rawField.text : "")
      }
    }
  }
}
