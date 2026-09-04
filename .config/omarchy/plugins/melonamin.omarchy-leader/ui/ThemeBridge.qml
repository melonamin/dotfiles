import QtQuick
import qs.Commons

QtObject {
  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color border: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color accent: Color.menu.selectedText
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedBorder: Color.menu.selectedBorder
  readonly property color urgent: Color.urgent
  readonly property color muted: Color.muted
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int titleSize: Style.font.title
  readonly property int bodySize: Style.font.body
  readonly property int captionSize: Style.font.caption
  readonly property int radius: Style.cornerRadius
  readonly property int outerGap: Style.gapsOut
  readonly property int panelPadding: Style.spacing.panelPadding
  readonly property int mediumGap: Style.spacing.md
  readonly property int smallGap: Style.spacing.sm
}
