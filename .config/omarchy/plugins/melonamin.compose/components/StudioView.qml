import QtQuick
import qs.Commons
import qs.Ui
import "../ComposeModel.js" as ComposeModel

Item {
  id: root
  property var rules: []
  property var allRules: []
  property var selectedRule: null
  property int selectedIndex: 0
  property string query: ""
  property string sourceFilter: "All"
  property var diagnostics: []
  property var keysymDefinitions: ({})
  property string shortcut: ""
  property string shortcutDiagnostic: ""
  property string statusMessage: ""
  property bool readOnly: false
  property bool showDiagnostics: false
  property bool editorOpen: false
  property bool busy: false
  property var editorRule: null
  property string editorAction: "new"
  property int editorSession: 0
  enabled: !busy

  signal selected(int index)
  signal queryEditRequested(string query)
  signal filterRequested(string filter)
  signal quickRequested()
  signal editRequested(var rule)
  signal overrideRequested(var rule)
  signal deleteRequested(var rule)
  signal inspectWinnerRequested(var rule)
  signal newRequested()
  signal undoRequested()
  signal validateRequested()
  signal openRawRequested()
  signal shortcutChangeRequested(string shortcut)
  signal editorSaveRequested(var rule, string rawRule)
  signal editorDraftChanged(string rawRule)
  signal editorCancelRequested()

  readonly property var filters: ["All", "Mine", "Omarchy", "System", "Included", "Conflicts"]

  Column {
    anchors.fill: parent
    spacing: Style.spacing.md

    Row {
      width: parent.width
      height: Style.space(42)
      spacing: Style.spacing.sm
      Text {
        width: Style.space(168)
        anchors.verticalCenter: parent.verticalCenter
        text: "COMPOSE / STUDIO"
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
        font.letterSpacing: 1.2
      }
      Text {
        width: parent.width - Style.space(168) - quickButton.width - newButton.width - parent.spacing * 3
        anchors.verticalCenter: parent.verticalCenter
        text: root.query || "Search the effective library…"
        color: Color.menu.text
        opacity: root.query ? 1 : 0.52
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.heading
        elide: Text.ElideRight
      }
      Button { id: newButton; text: "+ Rule"; bordered: true; focusable: true; foreground: Color.menu.text; enabled: !root.readOnly; onClicked: root.newRequested() }
      Button { id: quickButton; text: "Quick"; focusable: true; foreground: Color.menu.text; onClicked: root.quickRequested() }
    }

    Row {
      width: parent.width
      height: Style.space(34)
      spacing: Style.spacing.xs
      Repeater {
        model: root.filters
        Button {
          required property string modelData
          text: modelData
          selected: root.sourceFilter === modelData
          focusable: true
          foreground: Color.menu.text
          onClicked: root.filterRequested(modelData)
        }
      }
      Item { width: Math.max(0, parent.width - x - diagnosticsButton.width); height: 1 }
      Button {
        id: diagnosticsButton
        text: "Diagnostics " + root.diagnostics.length
        selected: root.showDiagnostics
        focusable: true
        foreground: Color.menu.text
        onClicked: root.showDiagnostics = !root.showDiagnostics
      }
    }

    Rectangle { width: parent.width; height: Math.max(1, Style.normalBorderWidth); color: Color.menu.border; opacity: 0.28 }

Item {
      width: parent.width
      height: parent.height - y - footer.height - parent.spacing

      Row {
        anchors.fill: parent
        spacing: Style.spacing.lg

        ListView {
          id: library
          width: parent.width * 0.43
          height: parent.height
          model: root.rules
          spacing: Style.spacing.xs
          clip: true
          currentIndex: root.selectedIndex
          delegate: RuleRow {
            required property int index
            required property var modelData
            width: ListView.view.width
            compact: true
            rule: modelData
            selected: index === root.selectedIndex
            onClicked: root.selected(index)
          }
          onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        }

        Rectangle { width: Math.max(1, Style.normalBorderWidth); height: parent.height; color: Color.menu.border; opacity: 0.24 }

        Item {
          width: parent.width - library.width - parent.spacing * 2 - Style.normalBorderWidth
          height: parent.height

          DiagnosticsView { anchors.fill: parent; visible: root.showDiagnostics; diagnostics: root.diagnostics }

          Column {
            anchors.fill: parent
            visible: !root.showDiagnostics && !root.editorOpen
            spacing: Style.spacing.md

            Text {
              width: parent.width
              text: root.selectedRule ? ComposeModel.invisiblePreview(root.selectedRule.output) : "Select a rule"
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.displayLarge
              font.bold: true
              elide: Text.ElideRight
            }
            Text { width: parent.width; text: root.selectedRule ? (root.selectedRule.comment || "Unnamed Compose rule") : ""; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.title; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: root.selectedRule ? root.selectedRule.displaySequence : ""; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body; wrapMode: Text.Wrap }
            Text { width: parent.width; text: root.selectedRule ? root.selectedRule.sourceKind + " · " + (root.selectedRule.sourceKind === "Mine" ? "~/.XCompose" : root.selectedRule.path) + ":" + root.selectedRule.line : ""; color: Color.menu.text; opacity: 0.6; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle }
            Text { width: parent.width; text: root.selectedRule && !root.selectedRule.active ? "Shadowed by " + root.selectedRule.shadowedBy : root.selectedRule ? "Active definition" : ""; color: Color.menu.text; opacity: 0.68; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
            Item { width: 1; height: Style.spacing.sm }
            Row {
              spacing: Style.spacing.sm
              Button { visible: root.selectedRule && root.selectedRule.sourceKind === "Mine"; text: "Edit"; bordered: true; focusable: true; foreground: Color.menu.text; enabled: !root.readOnly; onClicked: root.editRequested(root.selectedRule) }
              Button { visible: root.selectedRule && root.selectedRule.sourceKind === "Mine"; text: "Delete"; bordered: true; focusable: true; foreground: Color.urgent; enabled: !root.readOnly; onClicked: root.deleteRequested(root.selectedRule) }
              Button { visible: root.selectedRule && root.selectedRule.sourceKind !== "Mine"; text: "Create local override"; bordered: true; focusable: true; foreground: Color.menu.text; enabled: !root.readOnly; onClicked: root.overrideRequested(root.selectedRule) }
              Button { visible: root.selectedRule && !root.selectedRule.active && root.selectedRule.shadowedBy; text: "Show active rule"; bordered: true; focusable: true; foreground: Color.menu.text; onClicked: root.inspectWinnerRequested(root.selectedRule) }
            }
          }

          RuleEditor {
            anchors.fill: parent
            visible: root.editorOpen
            rule: root.editorRule
            action: root.editorAction
            sessionKey: root.editorSession
            existingRules: root.allRules
            keysymDefinitions: root.keysymDefinitions
            onSaveRequested: (rule, rawRule) => root.editorSaveRequested(rule, rawRule)
            onDraftChanged: rawRule => root.editorDraftChanged(rawRule)
            onCancelRequested: root.editorCancelRequested()
          }
        }
      }
    }

    Row {
      id: footer
      width: parent.width
      height: Style.space(34)
      spacing: Style.spacing.sm
      Text { width: Math.max(Style.space(180), parent.width - shortcutField.width - undoButton.width - validateButton.width - rawButton.width - parent.spacing * 4); anchors.verticalCenter: parent.verticalCenter; text: root.shortcutDiagnostic || root.statusMessage || (root.rules.length + " shown"); color: Color.menu.text; opacity: 0.62; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
      TextField { id: shortcutField; width: Style.space(230); text: root.shortcut; placeholderText: "Shortcut (empty disables)"; Accessible.name: "Compose shortcut"; onEditingFinished: root.shortcutChangeRequested(text) }
      Button { id: undoButton; text: "Undo"; focusable: true; foreground: Color.menu.text; enabled: !root.readOnly; onClicked: root.undoRequested() }
      Button { id: validateButton; text: "Validate"; focusable: true; foreground: Color.menu.text; onClicked: root.validateRequested() }
      Button { id: rawButton; text: "Open raw"; focusable: true; foreground: Color.menu.text; onClicked: root.openRawRequested() }
    }
  }
}
