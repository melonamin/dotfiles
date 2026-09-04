import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var rules: []
  property int selectedIndex: 0
  property string query: ""
  property string statusMessage: ""
  property bool loading: false

  signal selected(int index)
  signal activated(bool copyOnly)
  signal manageRequested()
  signal queryEditRequested(string query)

  Column {
    anchors.fill: parent
    spacing: Style.spacing.md

    Row {
      width: parent.width
      height: Math.max(Style.space(42), Style.font.heading + Style.spacing.controlPaddingY * 2)
      spacing: Style.spacing.md

      Text {
        width: parent.width - manageButton.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: root.query || "Type to search your Compose library…"
        color: Color.menu.text
        opacity: root.query ? 1 : 0.52
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.heading
        elide: Text.ElideRight
      }

      Button {
        id: manageButton
        anchors.verticalCenter: parent.verticalCenter
        text: "Studio"
        iconText: "⌘"
        bordered: true
        focusable: true
        foreground: Color.menu.text
        Accessible.name: "Open Compose Studio"
        onClicked: root.manageRequested()
      }
    }

    Rectangle { width: parent.width; height: Math.max(1, Style.normalBorderWidth); color: Color.menu.border; opacity: 0.28 }

    ListView {
      id: list
      width: parent.width
      height: parent.height - y - footer.height - parent.spacing
      model: root.rules
      spacing: Style.spacing.xs
      clip: true
      currentIndex: root.selectedIndex

      delegate: RuleRow {
        required property int index
        required property var modelData
        width: ListView.view.width
        rule: modelData
        selected: index === root.selectedIndex
        onClicked: root.selected(index)
        onActivated: { root.selected(index); root.activated(false) }
      }

      Text {
        anchors.centerIn: parent
        visible: !root.loading && root.rules.length === 0
        text: root.query ? "No Compose rules match" : "No active Compose rules"
        color: Color.menu.text
        opacity: 0.58
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
    }

    Row {
      id: footer
      width: parent.width
      height: Style.space(28)

      Text {
        width: parent.width * 0.65
        anchors.verticalCenter: parent.verticalCenter
        text: root.statusMessage || (root.rules.length + " results")
        color: Color.menu.text
        opacity: 0.58
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
      Text {
        width: parent.width * 0.35
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: "↵ insert   Ctrl+↵ copy   Esc close"
        color: Color.menu.text
        opacity: 0.52
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
