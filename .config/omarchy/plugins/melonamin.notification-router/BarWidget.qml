// One bell per routed notification, tinted by the rule that caught it, behind
// a routing glyph that shows the router is watching when nothing is pending.
//
// This is the router's replacement for "colour the toast", which the stock
// notification card cannot do: its accent is a readonly property derived from
// urgency alone. A dot is the better trade anyway — a toast is gone in eight
// seconds, a dot waits until it is acknowledged.

import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "melonamin.notification-router"

  readonly property var service: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("melonamin.notification-router") : null
  readonly property var pending: service ? service.pending : null
  readonly property int pendingCount: pending ? pending.count : 0

  // Dots shown individually before the rest collapse into a +N badge, so a
  // notification storm cannot push the clock off the bar.
  readonly property int maxDots: Math.max(1, parseInt(setting("maxDots", 5), 10) || 5)
  readonly property int shownCount: Math.min(pendingCount, maxDots)
  readonly property int overflowCount: pendingCount - shownCount

  readonly property int iconSize: Style.bar.iconFont
  readonly property int iconGap: Math.max(2, Math.round(iconSize * 0.22))
  readonly property string glyphFamily: root.bar ? root.bar.fontFamily : "monospace"

  implicitWidth: vertical ? barSize : layout.implicitWidth + iconGap * 2
  implicitHeight: vertical ? layout.implicitHeight + iconGap * 2 : barSize

  function clearAll() {
    if (root.service) root.service.clearDots()
  }

  // ---- panel plumbing (shape contract expected by Bar.findPanelWidget) ----

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = layout
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey() }
  function close() { if (panelLoader.item && panelLoader.item.close) panelLoader.item.close() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Row {
    id: layout
    anchors.centerIn: parent
    spacing: root.iconGap

    // At rest the router shows its routing glyph rather than nothing at all.
    // Hiding entirely would be quieter, but it would also leave no way to
    // reach the rule editor on a bar that has no other affordance for it.
    Text {
      id: restIcon
      visible: root.pendingCount === 0
      text: "󰃻"
      color: root.bar ? root.bar.foreground : "white"
      font.family: root.glyphFamily
      font.pixelSize: root.iconSize
      opacity: restMouse.containsMouse ? 0.9 : 0.45
      anchors.verticalCenter: parent.verticalCenter

      Behavior on opacity { NumberAnimation { duration: 90 } }

      MouseArea {
        id: restMouse
        anchors.fill: parent
        anchors.margins: -root.iconGap
        hoverEnabled: true
        onEntered: if (root.bar) root.bar.showTooltip(restIcon, "Notification Router — nothing pending")
        onExited: if (root.bar) root.bar.hideTooltip(restIcon)
        onClicked: {
          if (root.bar) root.bar.hideTooltip(restIcon)
          root.togglePanel()
        }
      }
    }

    Repeater {
      model: root.shownCount

      delegate: Text {
        id: bell
        required property int index

        readonly property var entry: root.pending && index < root.pending.count
          ? root.pending.get(index) : null

        text: "󰂚"
        font.family: root.glyphFamily
        font.pixelSize: root.iconSize
        anchors.verticalCenter: parent.verticalCenter
        // An unparseable colour in a rule must not paint an invisible bell;
        // fall back to the bar foreground so the notification is still seen.
        color: {
          var wanted = entry ? String(entry.colour || "") : ""
          if (!wanted) return root.bar ? root.bar.foreground : "white"
          var parsed = Qt.color(wanted)
          return parsed.a > 0 ? parsed : (root.bar ? root.bar.foreground : "white")
        }
        opacity: mouse.containsMouse ? 1.0 : 0.9

        Behavior on opacity { NumberAnimation { duration: 90 } }

        MouseArea {
          id: mouse
          anchors.fill: parent
          anchors.margins: -root.iconGap / 2
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

          onEntered: {
            if (!root.bar || !bell.entry) return
            var e = bell.entry
            var text = (e.app ? e.app + " — " : "") + e.summary
            if (e.body) text += "\n" + e.body
            if (e.rule) text += "\n\nrouted by: " + e.rule
            root.bar.showTooltip(bell, text)
          }
          onExited: if (root.bar) root.bar.hideTooltip(bell)

          onClicked: function (event) {
            if (!root.service) return
            if (root.bar) root.bar.hideTooltip(bell)
            if (event.button === Qt.RightButton) {
              root.togglePanel()
              return
            }
            if (event.button === Qt.MiddleButton) {
              root.clearAll()
              return
            }
            // Omarchy's own toasts carry their click action as a command in
            // the `exec` hint, which survives the notification object. A
            // third-party app's libnotify action does not — see README.
            var command = bell.entry ? String(bell.entry.exec || "") : ""
            if (command && root.bar) root.bar.run(command)
            root.service.clearDot(bell.index)
          }
        }
      }
    }

    Text {
      id: overflow
      visible: root.overflowCount > 0
      anchors.verticalCenter: parent.verticalCenter
      text: "+" + root.overflowCount
      color: root.bar ? root.bar.foreground : "white"
      font.family: root.bar ? root.bar.fontFamily : "monospace"
      font.pixelSize: Math.round(root.iconSize * 0.85)
      opacity: 0.8

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: if (root.bar) root.bar.showTooltip(overflow, root.overflowCount + " more routed notifications")
        onExited: if (root.bar) root.bar.hideTooltip(overflow)
        onClicked: function (event) {
          if (root.bar) root.bar.hideTooltip(overflow)
          if (event.button === Qt.RightButton) root.togglePanel()
          else root.clearAll()
        }
      }
    }
  }
}
