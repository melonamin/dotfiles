import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "melonamin.scribe"
  ipcTarget: "melonamin.scribe"
  manageIpc: false

  property int meetingIndex: 0
  property bool cursorActive: false
  property real nowMs: Date.now()

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool ready: scribe.installed && scribe.daemonRunning
  readonly property bool pickerVisible: ready && !scribe.active
  readonly property string elapsedText: Model.formatElapsed({
    active: scribe.active,
    paused: scribe.paused,
    startedAtMs: scribe.startedAtMs,
    pausedAtMs: scribe.pausedAtMs,
    pausedTotalMs: scribe.pausedTotalMs
  }, nowMs)

  readonly property string barIcon: {
    if (!scribe.installed || !scribe.daemonRunning) return "󰍭"
    if (scribe.paused) return "󰏤"
    if (scribe.active) return "󰑊"
    return "󰍬"
  }

  readonly property string barTooltip: {
    if (!scribe.installed) return "SecondScribe · CLI not found"
    if (!scribe.daemonRunning) return "SecondScribe · daemon not running"
    if (scribe.active) {
      var parts = [scribe.statusText]
      if (scribe.meetingTitle !== "") parts.push(scribe.meetingTitle)
      if (elapsedText !== "") parts.push(elapsedText)
      return parts.join(" · ")
    }
    return "SecondScribe · idle"
  }

  function selectedMeeting() {
    if (scribe.meetings.length === 0) return null
    return scribe.meetings[Math.max(0, Math.min(meetingIndex, scribe.meetings.length - 1))]
  }

  function moveCursor(delta) {
    if (!pickerVisible || scribe.meetings.length === 0) return
    cursorActive = true
    meetingIndex = Math.max(0, Math.min(scribe.meetings.length - 1, meetingIndex + delta))
  }

  function activateCursor() {
    if (!pickerVisible) return
    var meeting = selectedMeeting()
    if (meeting) scribe.startMeeting(meeting)
  }

  function setMeetingCursor(index) {
    cursorActive = true
    meetingIndex = index
  }

  function refreshAll() {
    scribe.refresh()
    scribe.refreshMeetings()
  }

  function startAdHoc() {
    var title = adhocField.text.trim()
    if (title === "") return
    scribe.startTitle(title)
    adhocField.text = ""
    keyCatcher.forceActiveFocus()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    meetingIndex = 0
    nowMs = Date.now()
    refreshAll()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: scribe
    settings: root.settings
  }

  Timer {
    interval: 1000
    repeat: true
    running: scribe.active
    triggeredOnStart: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshAll(); return "ok" }
    function stop(): string { scribe.stop(); return "ok" }
    function pause(): string { scribe.pause(); return "ok" }
    function resume(): string { scribe.resume(); return "ok" }
    function status(): string { return scribe.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon
    active: scribe.active && !scribe.paused
    dimmed: !root.ready
    tooltipText: root.barTooltip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && scribe.active) scribe.stop()
      else if (buttonCode === Qt.MiddleButton) root.refreshAll()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshAll()
        else if (t === "s" || t === "S") { if (scribe.active) scribe.stop() }
        else if (t === "p" || t === "P") { if (scribe.active) scribe.togglePause() }
        else if (t === "d" || t === "D") { if (scribe.installed && !scribe.daemonRunning) scribe.startDaemon() }
        else if (t === "t" || t === "T") { if (root.pickerVisible) adhocField.forceActiveFocus() }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: scribe.active && scribe.meetingTitle !== "" ? scribe.meetingTitle : "SecondScribe"
          meta: {
            var parts = [scribe.statusText]
            if (root.elapsedText !== "") parts.push(root.elapsedText)
            return parts.join(" · ")
          }
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: scribe.active ? 1 : 0.5
          iconComponent: Component {
            Text {
              text: scribe.active ? "󰑊" : "󰍬"
              color: scribe.active && !scribe.paused ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            PanelActionButton {
              visible: scribe.active
              iconText: "󰓛"
              tooltipText: "Stop capture"
              foreground: hero.foreground
              fontFamily: hero.fontFamily
              enabled: !scribe.busy
              onClicked: scribe.stop()
            }
          }
        }

        Text {
          visible: scribe.actionStatus !== "" || scribe.lastError !== ""
          width: parent.width
          text: scribe.actionStatus !== "" ? scribe.actionStatus : scribe.lastError
          color: scribe.lastError !== "" && scribe.actionStatus === "" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: scribe.transcriptionDegraded || scribe.serverNotice !== "" || scribe.microphoneNotice !== ""
          width: parent.width
          text: {
            var parts = []
            if (scribe.transcriptionDegraded) parts.push("Transcription degraded — audio kept locally")
            if (scribe.microphoneNotice !== "") parts.push(scribe.microphoneNotice)
            if (scribe.serverNotice !== "") parts.push(scribe.serverNotice)
            return parts.join("\n")
          }
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        CursorSurface {
          visible: !scribe.installed
          width: parent.width
          implicitHeight: missingText.implicitHeight + Style.spacing.rowPaddingX
          foreground: root.foreground
          Text {
            id: missingText
            anchors.fill: parent
            anchors.margins: Style.space(12)
            text: "SecondScribe capture CLI not found. Set the \"Capture CLI path\" widget setting to the secondscribe-capture binary."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }

        Column {
          visible: scribe.installed && !scribe.daemonRunning
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width
            text: "The capture daemon is not running."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Button {
            text: scribe.startingDaemon ? "Starting…" : "Start daemon"
            enabled: !scribe.startingDaemon
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: scribe.startDaemon()
          }
        }

        Row {
          visible: scribe.active
          spacing: Style.space(8)

          Button {
            text: scribe.paused ? "Resume" : "Pause"
            enabled: !scribe.busy
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: scribe.togglePause()
          }

          Button {
            text: "Stop"
            enabled: !scribe.busy
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: scribe.stop()
          }
        }

        PanelSeparator {
          visible: root.pickerVisible
          foreground: root.foreground
        }

        Column {
          visible: root.pickerVisible
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(meetingsHeader.implicitHeight, refreshButton.implicitHeight)
            PanelSectionHeader {
              id: meetingsHeader
              text: "LIKELY MEETINGS"
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            PanelActionButton {
              id: refreshButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑐"
              tooltipText: "Refresh meetings"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.refreshAll()
            }
          }

          Text {
            visible: scribe.meetings.length === 0
            width: parent.width
            text: "No likely meetings."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: meetingColumn
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: scribe.meetings
              MeetingRow {
                required property var modelData
                required property int index
                width: meetingColumn.width
                meeting: modelData
                rowIndex: index
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: adhocField
              width: parent.width - startAdhocButton.width - Style.space(8)
              placeholderText: "Ad-hoc capture title…"
              foreground: root.foreground
              enabled: !scribe.busy
              onAccepted: root.startAdHoc()
            }

            PanelActionButton {
              id: startAdhocButton
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑊"
              tooltipText: "Start ad-hoc capture"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !scribe.busy && adhocField.text.trim() !== ""
              onClicked: root.startAdHoc()
            }
          }
        }
        }
      }
    }
  }

  component MeetingRow: CursorSurface {
    id: meetingRow
    property var meeting: null
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.meetingIndex === rowIndex
    foreground: root.foreground
    implicitHeight: meetingContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setMeetingCursor(meetingRow.rowIndex)
      onClicked: scribe.startMeeting(meetingRow.meeting)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: "󰃭"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: meetingContent
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: meetingRow.meeting ? meetingRow.meeting.title : "Untitled meeting"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: {
            if (!meetingRow.meeting) return ""
            var parts = []
            if (meetingRow.meeting.startLabel !== "") parts.push(meetingRow.meeting.startLabel)
            if (meetingRow.meeting.participantCount > 0)
              parts.push(meetingRow.meeting.participantCount + (meetingRow.meeting.participantCount === 1 ? " participant" : " participants"))
            return parts.join(" · ")
          }
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        iconText: "󰑊"
        tooltipText: "Start capture"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: !scribe.busy
        Layout.alignment: Qt.AlignVCenter
        onClicked: scribe.startMeeting(meetingRow.meeting)
      }
    }
  }
}
