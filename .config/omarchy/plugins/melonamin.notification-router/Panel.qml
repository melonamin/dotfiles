// Rule editor and live test bench.
//
// The rules file stays the source of truth — it hot-reloads, so anything typed
// there lands immediately. What the panel adds is the part a text editor
// cannot: seeing the firehose that just went past, which rule caught each
// notification, and turning one of them into a rule without guessing at the
// app name.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

import "RouterModel.js" as RouterModel

Panel {
  id: root
  moduleName: "melonamin.notification-router"
  ipcTarget: "melonamin.notification-router-panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var service: root.bar && root.bar.shell && root.bar.shell.serviceFor
    ? root.bar.shell.serviceFor("melonamin.notification-router") : null

  readonly property var rules: service ? service.rules : []
  readonly property var ruleErrors: service ? service.ruleErrors : []
  readonly property var recent: service ? service.recent : []
  readonly property bool attached: service ? service.attached : false

  // Recomputed whenever the panel opens or the rules change: what the current
  // rules would do to each of the recently-seen notifications.
  property var verdicts: []

  readonly property color dimText: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.45)
  readonly property color warnText: Color.urgent

  function refresh() {
    root.verdicts = service ? service.testAgainstRecent() : []
  }

  function open() {
    root.controller.show()
    root.refresh()
  }

  function openFromHotkey() { root.open() }

  onOpenedChanged: if (opened) refresh()
  onRulesChanged: if (opened) refresh()

  function editRulesFile() {
    if (!root.bar || !root.service) return
    // shellQuote lives on the Commons Util singleton, not on the bar.
    root.bar.run("omarchy-launch-editor " + Util.shellQuote(root.service.rulesPath))
    root.close()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "e" || t === "E") root.editRulesFile()
      }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(12)

        // ---- Hero -------------------------------------------------------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroButtons.implicitHeight)

          Text {
            id: heroIcon
            text: "󰵙"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Row {
            id: heroButtons
            spacing: Style.space(4)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Re-test rules against recent notifications"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : "monospace"
              onClicked: root.refresh()
            }

            PanelActionButton {
              iconText: "󰏫"
              tooltipText: "Edit rules.json"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : "monospace"
              onClicked: root.editRulesFile()
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: heroButtons.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Notification Router"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : "monospace"
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: {
                if (!root.attached) return "not attached to the notification service"
                var n = root.rules.length
                return n + (n === 1 ? " rule" : " rules") + " · " + root.recent.length + " seen"
              }
              color: root.attached ? root.dimText : root.warnText
              font.family: root.bar ? root.bar.fontFamily : "monospace"
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        // ---- Rule errors ------------------------------------------------
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.ruleErrors.length > 0

          PanelSectionHeader {
            width: parent.width
            text: "Problems"
            foreground: root.warnText
            fontFamily: root.bar ? root.bar.fontFamily : "monospace"
          }

          Repeater {
            model: root.ruleErrors
            delegate: Text {
              required property string modelData
              width: panelColumn.width
              text: "• " + modelData
              color: root.warnText
              font.family: root.bar ? root.bar.fontFamily : "monospace"
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }
        }

        // ---- Rules ------------------------------------------------------
        PanelSectionHeader {
          width: parent.width
          text: "Rules"
          foreground: root.dimText
          fontFamily: root.bar ? root.bar.fontFamily : "monospace"
        }

        Text {
          width: parent.width
          visible: root.rules.length === 0
          text: root.ruleErrors.length > 0
            ? "No rules loaded — see the problems above."
            : "No rules yet. Pick a notification below to draft one, or press E to edit the file."
          color: root.dimText
          font.family: root.bar ? root.bar.fontFamily : "monospace"
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.rules

          delegate: Item {
            id: ruleRow
            required property var modelData
            required property int index

            width: panelColumn.width
            implicitHeight: ruleText.implicitHeight + Style.space(8)

            readonly property bool ruleEnabled: modelData.enabled !== false
            property bool confirmingDelete: false

            // An armed delete that the user walked away from must not stay
            // armed for the next person to click it.
            Timer {
              id: disarmDelete
              interval: 3000
              onTriggered: ruleRow.confirmingDelete = false
            }

            Rectangle {
              anchors.fill: parent
              anchors.margins: -Style.space(2)
              radius: Style.space(4)
              color: ruleHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            }

            Column {
              id: ruleText
              anchors.left: parent.left
              anchors.right: ruleButtons.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                width: parent.width
                text: ruleRow.modelData.name
                color: ruleRow.ruleEnabled
                  ? (root.bar ? root.bar.foreground : Color.foreground) : root.dimText
                font.family: root.bar ? root.bar.fontFamily : "monospace"
                font.pixelSize: Style.font.body
                font.strikeout: !ruleRow.ruleEnabled
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: RouterModel.describeMatch(ruleRow.modelData)
                  + "  →  " + RouterModel.describeActions(ruleRow.modelData).join(", ")
                color: root.dimText
                font.family: root.bar ? root.bar.fontFamily : "monospace"
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            Row {
              id: ruleButtons
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              PanelActionButton {
                iconText: ruleRow.ruleEnabled ? "\uf06e" : "\uf070"
                tooltipText: ruleRow.ruleEnabled ? "Disable this rule" : "Enable this rule"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : "monospace"
                onClicked: {
                  ruleRow.confirmingDelete = false
                  if (root.service) root.service.setRuleEnabled(ruleRow.modelData.index, !ruleRow.ruleEnabled)
                  root.refresh()
                }
              }

              // Deleting a rule cannot be undone from here, and the button sits
              // a few pixels from the toggle — so the first click only arms it.
              PanelActionButton {
                iconText: ruleRow.confirmingDelete ? "\uf00c" : "\uf1f8"
                tooltipText: ruleRow.confirmingDelete
                  ? "Click again to delete \"" + ruleRow.modelData.name + "\""
                  : "Delete this rule"
                foreground: root.warnText
                fontFamily: root.bar ? root.bar.fontFamily : "monospace"
                onClicked: {
                  if (!ruleRow.confirmingDelete) {
                    ruleRow.confirmingDelete = true
                    disarmDelete.restart()
                    return
                  }
                  ruleRow.confirmingDelete = false
                  if (root.service) root.service.removeRule(ruleRow.modelData.index)
                  root.refresh()
                }
              }
            }

            MouseArea {
              id: ruleHover
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }
          }
        }

        PanelSeparator { width: parent.width }

        // ---- Live test bench --------------------------------------------
        PanelSectionHeader {
          width: parent.width
          text: "Recently seen"
          foreground: root.dimText
          fontFamily: root.bar ? root.bar.fontFamily : "monospace"
        }

        Text {
          width: parent.width
          visible: root.verdicts.length === 0
          text: "Nothing yet. Notifications that arrive while the shell is running show up here."
          color: root.dimText
          font.family: root.bar ? root.bar.fontFamily : "monospace"
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.verdicts

          delegate: Item {
            id: seenRow
            required property var modelData
            required property int index

            width: panelColumn.width
            implicitHeight: seenText.implicitHeight + Style.space(8)

            readonly property bool caught: modelData.matched && modelData.matched.length > 0

            Rectangle {
              anchors.fill: parent
              anchors.margins: -Style.space(2)
              radius: Style.space(4)
              color: seenHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            }

            // Same language as the bar: a tinted bell for a notification a rule
            // caught, a dim outline for one that passed through untouched.
            Text {
              id: seenDot
              text: seenRow.caught ? "󰂚" : "󰂜"
              font.family: root.bar ? root.bar.fontFamily : "monospace"
              font.pixelSize: Style.font.body
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              opacity: seenRow.caught ? 1.0 : 0.45
              color: {
                if (!seenRow.caught) return root.dimText
                var wanted = seenRow.modelData.dot
                if (!wanted) return root.bar ? root.bar.foreground : Color.foreground
                var parsed = Qt.color(String(wanted))
                return parsed.a > 0 ? parsed : (root.bar ? root.bar.foreground : Color.foreground)
              }
            }

            Column {
              id: seenText
              anchors.left: seenDot.right
              anchors.leftMargin: Style.space(6)
              anchors.right: draftButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                width: parent.width
                text: (seenRow.modelData.app ? seenRow.modelData.app + " — " : "") + seenRow.modelData.summary
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : "monospace"
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: {
                  var v = seenRow.modelData
                  if (!seenRow.caught) return "no rule matched — shown normally"
                  var what = []
                  if (v.silence) what.push("silenced")
                  if (v.dot) what.push("dot")
                  for (var i = 0; i < v.sinks.length; i++) what.push(v.sinks[i])
                  return v.matched.join(", ") + (what.length ? "  →  " + what.join(", ") : "")
                }
                color: root.dimText
                font.family: root.bar ? root.bar.fontFamily : "monospace"
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            PanelActionButton {
              id: draftButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰐕"
              tooltipText: "Draft a rule matching this app"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : "monospace"
              onClicked: {
                if (root.service) root.service.draftFromRecent(seenRow.index, [{ silence: true }])
                root.refresh()
              }
            }

            MouseArea {
              id: seenHover
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }
          }
        }

        Text {
          width: parent.width
          text: "R re-test · E edit rules.json"
          color: root.dimText
          font.family: root.bar ? root.bar.fontFamily : "monospace"
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
