import QtQuick
import qs.Commons

Rectangle {
  id: root
  property string label: ""
  property bool composeKey: false
  property bool removable: false
  signal removeRequested()

  implicitWidth: chipText.implicitWidth + Style.spacing.controlPaddingX * 2
  implicitHeight: Math.max(Style.spacing.controlHeight, chipText.implicitHeight + Style.spacing.controlPaddingY * 2)
  radius: Math.max(Style.space(4), Style.cornerRadius / 2)
  color: composeKey ? Style.selectedFillFor(Color.menu.text, Color.accent) : Style.controlFill(false, false, Color.menu.text, Color.accent)
  border.width: Math.max(1, Style.normalBorderWidth)
  border.color: composeKey ? Color.accent : Color.menu.selectedBorder

  Text {
    id: chipText
    anchors.centerIn: parent
    text: root.label + (root.removable ? "  ×" : "")
    color: root.composeKey ? Color.accent : Color.menu.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: root.composeKey
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.removable
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.removeRequested()
  }
}
