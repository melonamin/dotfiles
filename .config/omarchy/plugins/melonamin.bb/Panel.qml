import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "melonamin.bb"
  ipcTarget: "melonamin.bb"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color runningColor: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string stateCommand: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/melonamin.bb/bb-state.sh"
  readonly property string switchCommand: (Quickshell.env("HOME") || "")
    + "/.config/omarchy/plugins/melonamin.bb/bb-switch.sh"
  readonly property url logoSource: Qt.resolvedUrl("assets/bb-mark.svg")

  property var state: ({
    online: false,
    serviceStatus: "unknown",
    version: "",
    total: 0,
    working: 0,
    blocked: 0,
    errors: 0,
    idle: 0,
    threads: [],
    profiles: { claude: [], codex: [] },
    activeClaudeId: "claude-1",
    activeCodexId: "codex-1"
  })

  property string pendingClaudeId: "claude-1"
  property string pendingCodexId: "codex-1"
  property bool pendingTouched: false
  property bool restartConfirmation: false
  property string actionStatus: ""
  property bool actionFailed: false
  property bool refreshing: false

  readonly property bool online: state && state.online === true
  readonly property int total: Number(state.total || 0)
  readonly property int working: Number(state.working || 0)
  readonly property int blocked: Number(state.blocked || 0)
  readonly property int idle: Number(state.idle || 0)
  readonly property var threads: state && Array.isArray(state.threads) ? state.threads : []
  readonly property var claudeProfiles: state && state.profiles && Array.isArray(state.profiles.claude)
    ? state.profiles.claude : []
  readonly property var codexProfiles: state && state.profiles && Array.isArray(state.profiles.codex)
    ? state.profiles.codex : []
  readonly property bool selectionChanged: pendingClaudeId !== String(state.activeClaudeId || "claude-1")
    || pendingCodexId !== String(state.activeCodexId || "codex-1")
  readonly property color statusColor: blocked > 0 ? urgent : (working > 0 ? runningColor : foreground)
  readonly property string barCountText: {
    if (!online) return "×"
    if (blocked > 0) return String(blocked)
    if (working > 0) return String(working)
    return String(total)
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function alpha(color, amount) {
    return Qt.rgba(color.r, color.g, color.b, amount)
  }

  function profileKnown(kind, id) {
    var list = kind === "claude" ? claudeProfiles : codexProfiles
    for (var i = 0; i < list.length; i++)
      if (String(list[i].id) === String(id)) return true
    return false
  }

  function profileLabel(kind, id) {
    var list = kind === "claude" ? claudeProfiles : codexProfiles
    for (var i = 0; i < list.length; i++)
      if (String(list[i].id) === String(id)) return String(list[i].label || id)
    return id === "custom" ? "Custom" : String(id || "Unknown")
  }

  function syncPendingFromState() {
    var activeClaude = String(state.activeClaudeId || "claude-1")
    var activeCodex = String(state.activeCodexId || "codex-1")
    var matchesPending = pendingClaudeId === activeClaude && pendingCodexId === activeCodex
    if (matchesPending) pendingTouched = false
    if (!pendingTouched && !applyProcess.running) {
      pendingClaudeId = profileKnown("claude", activeClaude) ? activeClaude : "claude-1"
      pendingCodexId = profileKnown("codex", activeCodex) ? activeCodex : "codex-1"
    }
  }

  function parseState(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed || typeof parsed !== "object") return
      state = parsed
      syncPendingFromState()
    } catch (e) {
      console.warn("melonamin.bb: invalid state output", e)
    }
  }

  function refresh() {
    if (stateProcess.running) return
    refreshing = true
    stateProcess.running = true
  }

  function chooseClaude(id) {
    if (applyProcess.running) return
    pendingClaudeId = String(id)
    pendingTouched = true
    restartConfirmation = false
    confirmationTimer.stop()
  }

  function chooseCodex(id) {
    if (applyProcess.running) return
    pendingCodexId = String(id)
    pendingTouched = true
    restartConfirmation = false
    confirmationTimer.stop()
  }

  function requestApply() {
    if (!selectionChanged || applyProcess.running) return
    if (working > 0 && !restartConfirmation) {
      restartConfirmation = true
      confirmationTimer.restart()
      return
    }
    restartConfirmation = false
    confirmationTimer.stop()
    actionStatus = "Applying profiles and restarting BB…"
    actionFailed = false
    applyProcess.command = [switchCommand, pendingClaudeId, pendingCodexId]
    applyProcess.running = true
  }

  function parseApplyResult(exitCode, raw) {
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (e) {}
    if (exitCode === 0 && parsed && parsed.ok === true) {
      actionStatus = "BB restarted with " + profileLabel("claude", pendingClaudeId)
        + " + " + profileLabel("codex", pendingCodexId)
      actionFailed = false
      refresh()
    } else {
      actionStatus = parsed && parsed.error ? String(parsed.error) : "Could not restart BB"
      actionFailed = true
    }
    actionStatusTimer.restart()
  }

  function statusGlyph(status) {
    if (status === "working") return "󰐊"
    if (status === "blocked") return ""
    if (status === "error") return ""
    return "󰒲"
  }

  function statusLabel(status) {
    if (status === "blocked") return "Attention"
    var text = String(status || "idle")
    return text.charAt(0).toUpperCase() + text.slice(1)
  }

  function threadColor(status, fallback) {
    if (status === "blocked") return urgent
    if (status === "working") return runningColor
    return fallback
  }

  function formatAge(timestamp) {
    var value = Number(timestamp || 0)
    if (!(value > 0)) return ""
    var seconds = Math.max(0, Math.floor((Date.now() - value) / 1000))
    if (seconds < 60) return "now"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h"
    return Math.floor(hours / 24) + "d"
  }

  function heroMeta() {
    if (!online) return String(state.serviceStatus || "offline").toUpperCase()
    if (blocked > 0) return blocked + " NEED ATTENTION"
    if (working > 0) return working + " ACTIVE"
    return "READY"
  }

  function heroDetail() {
    var version = String(state.version || "")
    return (version === "" ? "BB" : "BB " + version) + " · "
      + profileLabel("claude", String(state.activeClaudeId || "")) + " + "
      + profileLabel("codex", String(state.activeCodexId || ""))
  }

  onOpenedChanged: if (opened) {
    if (panelFlick) panelFlick.contentY = 0
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: stateProcess
    command: [root.stateCommand]
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseState(text)
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("melonamin.bb/state", text.trim())
    }

    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0) console.warn("melonamin.bb: state command exited", exitCode)
    }
  }

  Process {
    id: applyProcess
    running: false

    stdout: StdioCollector {
      id: applyStdout
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: applyStderr
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.parseApplyResult(exitCode, applyStdout.text)
      if (String(applyStderr.text || "").trim() !== "")
        console.warn("melonamin.bb/switch", String(applyStderr.text).trim())
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: confirmationTimer
    interval: 5000
    repeat: false
    onTriggered: root.restartConfirmation = false
  }

  Timer {
    id: actionStatusTimer
    interval: 7000
    repeat: false
    onTriggered: {
      root.actionStatus = ""
      root.actionFailed = false
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function show(): string { root.open(); return "ok" }
    function hide(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string { return root.online ? "online" : String(root.state.serviceStatus || "offline") }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    active: root.blocked > 0 || root.working > 0
    activeColor: root.statusColor
    fixedWidth: root.bar && root.bar.vertical ? -1 : barContent.implicitWidth + Style.space(7)
    horizontalMargin: 0
    tooltipText: root.online
      ? "BB · " + root.working + " active · " + root.blocked + " attention"
      : "BB · " + String(root.state.serviceStatus || "offline")

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(3)

      BbMark {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        height: Style.space(14)
        tint: root.foreground
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.barCountText
        color: root.statusColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: root.blocked > 0
        renderType: Text.NativeRendering
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
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
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          panelFlick.contentY = Math.max(0, Math.min(
            panelFlick.contentY + dy * Style.space(58),
            Math.max(0, panelFlick.contentHeight - panelFlick.height)
          ))
        }
      }
      onActivateRequested: root.refresh()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "BB"
            meta: root.heroMeta()
            detail: root.heroDetail()
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              BbMark {
                width: Style.font.display
                height: Style.font.display
                tint: root.statusColor
              }
            }
          }

          Text {
            visible: !root.online
            width: parent.width
            text: "BB is " + String(root.state.serviceStatus || "offline")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            topPadding: Style.space(16)
            bottomPadding: Style.space(8)
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "ACTIVITY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              SummaryCell { label: "Active"; value: root.working; active: root.working > 0; runningCell: true }
              SummaryCell { label: "Attention"; value: root.blocked; active: root.blocked > 0; urgentCell: true }
              SummaryCell { label: "Idle"; value: root.idle }
              SummaryCell { label: "Total"; value: root.total }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "CREDENTIAL PROFILES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              text: "CLAUDE"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Grid {
              id: claudeGrid
              width: parent.width
              columns: Math.max(1, root.claudeProfiles.length)
              columnSpacing: Style.spacing.md
              readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

              Repeater {
                model: root.claudeProfiles

                Button {
                  required property var modelData
                  width: claudeGrid.cellWidth
                  text: String(modelData.label || modelData.id)
                    + (String(modelData.id) === String(root.state.activeClaudeId) ? " · LIVE" : "")
                  selected: String(modelData.id) === root.pendingClaudeId
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.bodySmall
                  verticalPadding: Style.spacing.controlPaddingY
                  enabled: !applyProcess.running
                  onClicked: root.chooseClaude(modelData.id)
                }
              }
            }

            Text {
              topPadding: Style.space(4)
              text: "CODEX"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Grid {
              id: codexGrid
              width: parent.width
              columns: Math.max(1, root.codexProfiles.length)
              columnSpacing: Style.spacing.md
              readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

              Repeater {
                model: root.codexProfiles

                Button {
                  required property var modelData
                  width: codexGrid.cellWidth
                  text: String(modelData.label || modelData.id)
                    + (String(modelData.id) === String(root.state.activeCodexId) ? " · LIVE" : "")
                  selected: String(modelData.id) === root.pendingCodexId
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.bodySmall
                  verticalPadding: Style.spacing.controlPaddingY
                  enabled: !applyProcess.running
                  onClicked: root.chooseCodex(modelData.id)
                }
              }
            }

            Text {
              visible: root.selectionChanged && root.working > 0
              width: parent.width
              text: root.working + " active thread" + (root.working === 1 ? "" : "s")
                + " will be interrupted by the restart."
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              width: parent.width
              text: applyProcess.running
                ? "Restarting BB…"
                : (root.restartConfirmation
                    ? "Restart with " + root.working + " active thread" + (root.working === 1 ? "?" : "s?")
                    : "Apply & Restart BB")
              selected: root.selectionChanged || root.restartConfirmation
              bordered: true
              foreground: root.restartConfirmation ? root.urgent : root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              verticalPadding: Style.spacing.controlPaddingY
              enabled: root.selectionChanged && !applyProcess.running
              onClicked: root.requestApply()
            }

            Text {
              visible: root.actionStatus !== ""
              width: parent.width
              text: root.actionStatus
              color: root.actionFailed ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator {
            visible: root.online && root.threads.length > 0
            foreground: root.foreground
          }

          Column {
            visible: root.online && root.threads.length > 0
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "THREADS  ·  " + root.total
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.threads

              ThreadRow {
                width: parent ? parent.width : 0
                thread: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component BbMark: Item {
    id: bbMark
    property color tint: root.foreground

    Image {
      id: bbMarkMask
      anchors.fill: parent
      source: root.logoSource
      sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
      sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
      fillMode: Image.PreserveAspectFit
      visible: false
      layer.enabled: true
    }

    MultiEffect {
      anchors.fill: bbMarkMask
      source: bbMarkMask
      brightness: 1.0
      colorization: 1.0
      colorizationColor: bbMark.tint
    }
  }

  component SummaryCell: Rectangle {
    id: summaryCell
    property string label: ""
    property int value: 0
    property bool active: false
    property bool urgentCell: false
    property bool runningCell: false

    width: (parent.width - parent.spacing * 3) / 4
    implicitHeight: summaryLabels.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: summaryCell.active
      ? Style.selectedFillFor(summaryCell.urgentCell ? root.urgent : root.foreground, Color.accent)
      : root.alpha(root.foreground, 0.035)

    Column {
      id: summaryLabels
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: summaryCell.value
        color: summaryCell.active
          ? (summaryCell.urgentCell ? root.urgent : (summaryCell.runningCell ? root.runningColor : root.foreground))
          : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: summaryCell.label.toUpperCase()
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  component ThreadRow: Column {
    id: threadRow
    property var thread: ({})
    property int rowIndex: 0

    spacing: Style.space(8)

    PanelSeparator {
      visible: threadRow.rowIndex > 0
      foreground: root.foreground
      strength: 0.07
    }

    Item {
      width: threadRow.width
      implicitHeight: Math.max(threadGlyph.implicitHeight, threadLabels.implicitHeight, threadStatus.implicitHeight)

      Text {
        id: threadGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.statusGlyph(String(threadRow.thread.status || "idle"))
        color: root.threadColor(String(threadRow.thread.status || "idle"), root.foreground)
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
      }

      Column {
        id: threadLabels
        anchors.left: threadGlyph.right
        anchors.leftMargin: Style.space(10)
        anchors.right: threadStatus.left
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(2)

        Text {
          width: parent.width
          text: String(threadRow.thread.name || "BB thread")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: threadRow.thread.status === "working" || threadRow.thread.status === "blocked"
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: String(threadRow.thread.provider || "")
            + (root.formatAge(threadRow.thread.updatedAt) === "" ? "" : " · " + root.formatAge(threadRow.thread.updatedAt))
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        id: threadStatus
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.statusLabel(String(threadRow.thread.status || "idle"))
        color: root.threadColor(String(threadRow.thread.status || "idle"), root.dim)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: threadRow.thread.status === "blocked"
      }
    }
  }
}
