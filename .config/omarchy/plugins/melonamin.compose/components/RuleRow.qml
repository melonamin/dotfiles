import QtQuick
import qs.Commons
import "../ComposeModel.js" as ComposeModel

Rectangle {
  id: root
  required property var rule
  property bool selected: false
  property bool compact: false
  signal clicked()
  signal activated()

  implicitHeight: compact ? Style.space(62) : Style.space(72)
  radius: Style.cornerRadius
  color: selected ? Color.menu.selectedBackground : (pointer.containsMouse ? Style.hoverFillFor(Color.menu.text, Color.accent) : "transparent")
  border.width: selected ? Math.max(1, Style.normalBorderWidth) : 0
  border.color: selected ? Color.menu.selectedBorder : "transparent"
  opacity: rule.active === false ? 0.64 : 1

  Row {
    anchors.fill: parent
    anchors.margins: Style.spacing.rowPaddingX
    spacing: Style.spacing.md

    Text {
      width: Math.max(Style.space(54), Math.min(Style.space(108), implicitWidth))
      anchors.verticalCenter: parent.verticalCenter
      text: ComposeModel.invisiblePreview(root.rule.output)
      color: root.selected ? Color.menu.selectedText : Color.menu.text
      font.family: Style.font.family
      font.pixelSize: root.compact ? Style.font.heading : Style.font.display
      font.bold: true
      elide: Text.ElideRight
    }

    Column {
      width: parent.width - parent.spacing - parent.children[0].width
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.labelGap

      Text {
        width: parent.width
        text: root.rule.comment || "Unnamed Compose rule"
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: root.rule.displaySequence
          + (root.rule.alternativeCount ? "   ·   " + root.rule.alternativeCount + (root.rule.alternativeCount === 1 ? " alternative" : " alternatives") : "")
          + "   ·   " + root.rule.sourceKind + (root.rule.active === false ? "   ·   Shadowed" : "")
        color: root.selected ? Color.menu.selectedText : Color.menu.text
        opacity: 0.62
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    onDoubleClicked: root.activated()
  }
}
