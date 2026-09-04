import QtQuick
import qs.Commons

Item {
  id: root
  property var diagnostics: []

  ListView {
    anchors.fill: parent
    clip: true
    spacing: Style.spacing.sm
    model: root.diagnostics

    delegate: Rectangle {
      required property var modelData
      width: ListView.view.width
      height: message.implicitHeight + Style.spacing.rowPaddingX * 2
      radius: Style.cornerRadius
      color: Style.controlFill(false, false, Color.menu.text, Color.accent)
      border.width: Math.max(1, Style.normalBorderWidth)
      border.color: modelData.severity === "error" ? Color.urgent : Color.menu.selectedBorder

      Text {
        id: message
        anchors.fill: parent
        anchors.margins: Style.spacing.rowPaddingX
        text: (modelData.severity === "error" ? "Error · " : modelData.severity === "warning" ? "Warning · " : "Info · ")
          + modelData.message
          + (modelData.path || modelData.sourceId ? "  ·  " + (modelData.path || modelData.sourceId) : "")
          + (modelData.line ? ":" + modelData.line : "")
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.diagnostics.length === 0
      text: "No diagnostics"
      color: Color.menu.text
      opacity: 0.58
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
