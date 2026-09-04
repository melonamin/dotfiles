import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var itemData: ({})
  property int cellSize: Style.space(50)
  property int iconSize: Style.space(40)
  property url iconSource: ""
  property bool running: false
  property bool hovered: false
  property bool folderChecked: false
  property bool folderAvailable: true

  readonly property string itemType: String((itemData && itemData.type) || "invalid")
  readonly property bool separator: itemType === "separator"
  readonly property bool folder: itemType === "folder"
  readonly property bool effectiveEnabled: itemData && itemData.available !== false && (!folder || (folderChecked && folderAvailable))
  readonly property string tooltipText: {
    var label = String((itemData && itemData.name) || "")
    var reason = ""
    if (folder && folderChecked && !folderAvailable) reason = "Folder is unavailable: " + String(itemData.path || "")
    else if (itemData && itemData.reason) reason = String(itemData.reason)
    return reason ? label + "\n" + reason : label
  }

  signal activated(bool forceLaunch)

  width: separator ? Style.spacing.xxl : cellSize
  height: cellSize
  z: hovered ? 10 : 0

  function verifyFolder() {
    if (!folder || !itemData.path) {
      folderChecked = !folder
      folderAvailable = !folder || !!itemData.path
      return
    }
    folderChecked = false
    if (!folderProbe.running) folderProbe.running = true
  }

  Process {
    id: folderProbe
    command: ["test", "-d", String((root.itemData && root.itemData.path) || "")]
    onExited: function(exitCode) {
      root.folderAvailable = exitCode === 0
      root.folderChecked = true
    }
  }

  Rectangle {
    visible: root.separator
    width: Math.max(1, Style.spacing.hairline)
    height: Math.round(root.cellSize * 0.56)
    anchors.centerIn: parent
    color: Util.alpha(Color.popups.text, 0.22)
  }

  Item {
    id: visual
    visible: !root.separator
    anchors.centerIn: parent
    width: root.cellSize
    height: root.cellSize
    scale: root.hovered && root.effectiveEnabled ? 1.08 : 1
    y: root.hovered && root.effectiveEnabled ? -Style.spacing.xs : 0
    opacity: root.effectiveEnabled ? 1 : 0.42

    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 90 } }

    Rectangle {
      anchors.fill: parent
      radius: Math.max(Style.cornerRadius, Style.spacing.lg)
      color: root.hovered && root.effectiveEnabled ? Style.hoverFill : "transparent"

      Behavior on color { ColorAnimation { duration: 80 } }
    }

    Image {
      anchors.centerIn: parent
      width: root.iconSize
      height: root.iconSize
      source: root.iconSource
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      cache: true
      smooth: true
      mipmap: true
    }

    Rectangle {
      visible: root.running && root.itemType === "app"
      width: Style.spacing.sm
      height: width
      radius: width / 2
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -Style.spacing.xs
      color: Color.accent
    }
  }

  BorderSurface {
    id: tooltip
    readonly property int paddingX: Style.spacing.controlPaddingX
    readonly property int paddingY: Style.spacing.controlPaddingY

    visible: root.hovered && root.tooltipText !== ""
    width: Math.min(Style.space(88), tooltipLabel.implicitWidth + paddingX * 2)
    height: tooltipLabel.implicitHeight + paddingY * 2
    x: Math.round((root.width - width) / 2)
    y: -height - Style.spacing.sm
    color: Color.tooltip.background
    borderSpec: Border.localOrSurfaceSpec("tooltip", "border", Color.tooltip.border, Color.tooltip.border, Style.normalBorderWidth)
    radius: Math.max(Style.cornerRadius, Style.spacing.md)

    Text {
      id: tooltipLabel
      anchors.centerIn: parent
      width: parent.width - tooltip.paddingX * 2
      text: root.tooltipText
      color: Color.tooltip.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  MouseArea {
    visible: !root.separator
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: root.effectiveEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
    onContainsMouseChanged: root.hovered = containsMouse
    onClicked: function(mouse) {
      if (!root.effectiveEnabled) return
      var forceLaunch = mouse.button === Qt.MiddleButton || (mouse.modifiers & Qt.ControlModifier)
      root.activated(forceLaunch)
    }
  }

  Component.onCompleted: verifyFolder()
}
