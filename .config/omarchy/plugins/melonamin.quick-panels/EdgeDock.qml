import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

PanelWindow {
  id: root

  property bool screenEnabled: true
  property var dockConfig: ({})
  property var items: []
  property string configError: ""
  property bool forcedOpen: false
  property var iconProvider: null
  property var runningProvider: null

  property bool hoverOpen: false

  readonly property bool opened: forcedOpen || hoverOpen
  readonly property int iconSize: Number(dockConfig.iconSize || 40)
  readonly property int cellSize: Math.max(iconSize + Style.space(10), Style.space(50))
  readonly property int dockPadding: Style.spacing.lg
  readonly property int dockHeight: cellSize + dockPadding * 2
  readonly property int screenMargin: Math.max(Style.gapsOut, Style.spacing.sm)
  readonly property int triggerHeight: Math.max(2, Style.spacing.xs)
  readonly property real desiredDockWidth: Math.max(Style.space(96), itemRow.implicitWidth + dockPadding * 2)
  readonly property real dockWidth: Math.min(Math.max(1, width - screenMargin * 2), desiredDockWidth)

  signal activated(var item, bool forceLaunch)

  function openSoon() {
    closeTimer.stop()
    if (opened) return
    if (Number(dockConfig.openDelay || 0) <= 0) hoverOpen = true
    else openTimer.restart()
  }

  function closeSoon() {
    openTimer.stop()
    if (!hoverOpen || forcedOpen) return
    closeTimer.restart()
  }

  visible: screenEnabled
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  implicitHeight: dockHeight + Style.space(54)
  surfaceFormat.opaque: false

  WlrLayershell.namespace: "omarchy-quick-panels"
  WlrLayershell.layer: String(dockConfig.layer || "top") === "overlay" ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    left: true
    right: true
    bottom: true
  }

  mask: Region {
    item: root.opened ? hitArea : trigger
  }

  Timer {
    id: openTimer
    interval: Math.max(1, Number(root.dockConfig.openDelay || 90))
    onTriggered: root.hoverOpen = true
  }

  Timer {
    id: closeTimer
    interval: Math.max(50, Number(root.dockConfig.closeDelay || 380))
    onTriggered: {
      root.hoverOpen = false
    }
  }

  Item {
    id: trigger
    width: Math.min(root.width, Math.max(root.dockWidth, Number(root.dockConfig.activationWidth || 360)))
    height: root.triggerHeight
    x: Math.round((root.width - width) / 2)
    y: root.height - height

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onContainsMouseChanged: {
        if (containsMouse) root.openSoon()
        else if (!root.opened) openTimer.stop()
      }
    }
  }

  MouseArea {
    id: hitArea
    width: root.dockWidth + Style.spacing.xl * 2
    height: Math.max(1, root.height - y)
    x: Math.round((root.width - width) / 2)
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    y: root.opened
      ? root.height - root.dockHeight - root.screenMargin - Style.spacing.lg
      : root.height + Style.spacing.lg

    onContainsMouseChanged: {
      if (containsMouse) {
        closeTimer.stop()
        openTimer.stop()
      } else {
        root.closeSoon()
      }
    }

    Behavior on y {
      NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    BorderSurface {
      id: dockSurface
      x: Style.spacing.xl
      y: Style.spacing.lg
      width: root.dockWidth
      height: root.dockHeight
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))
      radius: Math.max(Style.cornerRadius, Style.space(14))
      opacity: root.opened ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 70 } }

      Item {
        id: viewport
        anchors.fill: parent
        anchors.margins: root.dockPadding

        Flickable {
          id: flick
          anchors.fill: parent
          contentWidth: itemRow.implicitWidth
          contentHeight: height
          flickableDirection: Flickable.HorizontalFlick
          boundsBehavior: Flickable.StopAtBounds
          clip: contentWidth > width

          Row {
            id: itemRow
            height: flick.height
            spacing: Style.spacing.md

            Repeater {
              model: root.items || []

              DockItem {
                id: dockItem
                required property var modelData

                itemData: modelData
                cellSize: root.cellSize
                iconSize: root.iconSize
                iconSource: root.iconProvider ? root.iconProvider(modelData) : ""
                running: root.runningProvider ? root.runningProvider(modelData) : false

                onActivated: function(forceLaunch) { root.activated(modelData, forceLaunch) }
              }
            }

            Item {
              visible: root.configError !== ""
              width: visible ? root.cellSize : 0
              height: root.cellSize

              Text {
                anchors.centerIn: parent
                text: "!"
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }
          }
        }
      }
    }
  }

  onForcedOpenChanged: {
    if (forcedOpen) {
      openTimer.stop()
      closeTimer.stop()
    } else if (!hitArea.containsMouse) {
      closeSoon()
    }
  }

  onScreenEnabledChanged: if (!screenEnabled) {
    hoverOpen = false
  }
}
