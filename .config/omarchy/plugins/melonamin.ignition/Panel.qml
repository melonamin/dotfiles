import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "melonamin.ignition"
  ipcTarget: "melonamin.ignition"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so popout coordination has to identify as that widget.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Configuration ----
  readonly property string baseUrl: String(setting("baseUrl", "https://ignition.spot.t1a.dev")).trim()
  readonly property var productIds: Model.parseProducts(setting("products", "lakesentry,secondstack,antares,pondpilot"))
  readonly property string barProduct: {
    var id = String(setting("barProduct", "lakesentry")).trim().toLowerCase()
    if (productIds.indexOf(id) !== -1) return id
    return productIds.length > 0 ? productIds[0] : ""
  }

  // ---- Data ----
  // data maps product id -> parsed monitoring model (or null while missing).
  property var data: ({})
  property bool reachable: false
  property string selectedId: ""

  readonly property string currentId: selectedId !== "" ? selectedId : barProduct
  readonly property var current: data && data[currentId] ? data[currentId] : null
  readonly property var barModel: data && data[barProduct] ? data[barProduct] : null

  readonly property string barTooltip: Model.barTooltip(barProduct, barModel)

  readonly property real funnelMax: current ? Model.maxStage(current.stages) : 0
  readonly property color dimText: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.pollNow()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.pollNow()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // ---- Ignition I/O ----

  function pollNow() {
    if (productIds.length === 0 || pollProc.running) return
    pollProc.command = Model.pollCommand(baseUrl, productIds)
    pollProc.running = true
  }

  function applyPoll(raw) {
    var result = Model.parsePoll(raw, productIds)
    if (!result) {
      reachable = false
      return
    }
    // Keep the last good model for a product whose fetch failed this round.
    var merged = {}
    for (var i = 0; i < productIds.length; i++) {
      var id = productIds[i]
      merged[id] = result[id] || (data && data[id] ? data[id] : null)
    }
    data = merged
    reachable = true
  }

  function selectProduct(id) {
    selectedId = id
  }

  function cycleProduct(step) {
    if (productIds.length === 0) return
    var index = productIds.indexOf(currentId)
    if (index === -1) index = 0
    selectedId = productIds[(index + step + productIds.length) % productIds.length]
  }

  function openCockpit() {
    Quickshell.execDetached(["xdg-open", Model.cockpitUrl(baseUrl, currentId)])
  }

  Process {
    id: pollProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPoll(text)
    }
  }

  // The exports regenerate once a day; half-hourly keeps the bar numbers
  // honest without hammering the site.
  Timer {
    interval: 1800000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.pollNow()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.pollNow() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.cycleProduct(dx > 0 ? 1 : -1)
      }
      onActivateRequested: root.openCockpit()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var index = "1234".indexOf(t)
        if (index !== -1 && index < root.productIds.length)
          root.selectProduct(root.productIds[index])
        else if (t === "r" || t === "R") root.pollNow()
      }

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(12)

        // ---- Hero: rocket · product name/stamp · refresh + cockpit ----
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroButtons.implicitHeight)

          Text {
            id: heroIcon
            text: "󱓞"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
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
              tooltipText: "Refresh"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.pollNow()
            }

            PanelActionButton {
              iconText: "󰖟"
              tooltipText: "Open cockpit in browser"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.openCockpit()
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
              text: Model.productName(root.currentId)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.reachable
                ? ("IGNITION" + (root.current && root.current.asOf ? " · AS OF " + root.current.asOf : ""))
                : "IGNITION · UNREACHABLE"
              color: root.dimText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        // ---- Product switcher ----
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: root.productIds.length > 1

          Repeater {
            model: root.productIds

            CursorSurface {
              id: productPill
              required property string modelData

              readonly property bool isActive: root.currentId === modelData
              current: isActive
              bordered: true
              foreground: root.bar.foreground
              implicitWidth: pillLabel.implicitWidth + Style.space(20)
              implicitHeight: pillLabel.implicitHeight + Style.space(10)

              Text {
                id: pillLabel
                anchors.centerIn: parent
                text: Model.productName(productPill.modelData)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: productPill.isActive
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: productPill.hasCursor = containsMouse
                onClicked: root.selectProduct(productPill.modelData)
              }
            }
          }
        }

        Text {
          visible: !root.current
          width: parent.width
          text: root.reachable ? "No monitoring export for this product yet." : "Fetching Ignition exports…"
          color: root.dimText
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        // ---- Search (GSC 28d): KPIs + trend ----
        PanelSeparator {
          visible: root.current !== null
          foreground: root.bar.foreground
        }

        Column {
          visible: root.current !== null
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "SEARCH · 28 DAYS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width

            Repeater {
              model: root.current ? root.current.kpis : []

              Column {
                required property var modelData
                width: parent.width / Math.max(1, root.current ? root.current.kpis.length : 1)
                spacing: Style.space(2)

                Text {
                  text: Model.fmtKpi(modelData.value)
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }

                Text {
                  text: modelData.label.toUpperCase()
                  color: root.dimText
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }

          Sparkline {
            width: parent.width
            height: Style.space(52)
            values: root.current ? root.current.impressions : []
            values2: root.current ? root.current.clicks : []
            lineColor: Color.accent
            line2Color: root.bar.foreground
            visible: root.current && root.current.impressions.length > 1
          }

          Item {
            width: parent.width
            implicitHeight: legendLeft.implicitHeight
            visible: root.current && root.current.impressions.length > 1

            Row {
              id: legendLeft
              spacing: Style.space(10)
              anchors.left: parent.left

              Row {
                spacing: Style.space(4)

                Rectangle {
                  width: Style.space(8)
                  height: Style.space(2)
                  radius: height / 2
                  color: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: root.current ? root.current.seriesLabel : ""
                  color: root.dimText
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Row {
                spacing: Style.space(4)

                Rectangle {
                  width: Style.space(8)
                  height: Style.space(2)
                  radius: height / 2
                  color: root.bar.foreground
                  opacity: 0.7
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: root.current ? root.current.series2Label : ""
                  color: root.dimText
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Text {
              text: root.current ? root.current.gscFrom + " → " + root.current.gscAsOf : ""
              color: root.dimText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
            }
          }
        }

        // ---- Funnel ----
        PanelSeparator {
          visible: root.current !== null && root.current.stages.length > 0
          foreground: root.bar.foreground
        }

        Column {
          visible: root.current !== null && root.current.stages.length > 0
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "FUNNEL · 28 DAYS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Repeater {
            model: root.current ? root.current.stages : []

            Column {
              id: stageRow
              required property var modelData
              required property int index

              // The gate between the marketing and product halves of the funnel.
              readonly property bool startsProductHalf: index > 0
                && modelData.half === "product"
                && root.current.stages[index - 1].half === "marketing"

              width: parent.width
              spacing: Style.space(6)

              Text {
                visible: stageRow.startsProductHalf
                text: "— PRODUCT —"
                color: root.dimText
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1.2
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Rectangle {
                width: parent.width
                height: Style.space(20)
                radius: Style.spacing.labelGap
                color: Style.normalFillFor(root.bar.foreground, Color.accent)
                // Manual figures are stale by definition; dim them slightly.
                opacity: stageRow.modelData.kind === "feed" ? 1.0 : 0.65

                Rectangle {
                  height: parent.height
                  radius: parent.radius
                  width: parent.width * Model.stageRatio(stageRow.modelData.v, root.funnelMax)
                  color: Util.alpha(Color.accent, 0.35)
                }

                Text {
                  text: stageRow.modelData.label
                    + (stageRow.modelData.sub ? " · " + stageRow.modelData.sub : "")
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  anchors.right: stageValue.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: stageValue
                  text: Model.fmtCompact(stageRow.modelData.v)
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }
        }

        // ---- Signals ----
        PanelSeparator {
          visible: root.current !== null && root.current.signals.length > 0
          foreground: root.bar.foreground
        }

        Column {
          visible: root.current !== null && root.current.signals.length > 0
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "SIGNALS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Repeater {
            model: root.current ? root.current.signals : []

            Item {
              required property var modelData
              width: parent.width
              implicitHeight: signalLabel.implicitHeight

              Text {
                id: signalLabel
                text: modelData.label + (modelData.sub ? " · " + modelData.sub : "")
                color: root.dimText
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: signalValue.left
                anchors.rightMargin: Style.space(8)
              }

              Text {
                id: signalValue
                text: Model.fmtCompact(modelData.v)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.right: parent.right
              }
            }
          }
        }

        // ---- Direction lanes (headline KPI each) ----
        PanelSeparator {
          visible: root.current !== null && root.current.lanes.length > 0
          foreground: root.bar.foreground
        }

        Column {
          visible: root.current !== null && root.current.lanes.length > 0
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "DIRECTIONS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Repeater {
            model: root.current ? root.current.lanes : []

            Item {
              id: laneRow
              required property var modelData

              readonly property var headline: modelData.kpis.length > 0 ? modelData.kpis[0] : null

              width: parent.width
              implicitHeight: laneLabels.implicitHeight

              Column {
                id: laneLabels
                anchors.left: parent.left
                anchors.right: laneValue.left
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(1)

                Text {
                  text: laneRow.modelData.title.toUpperCase()
                    + (laneRow.modelData.kind === "manual" ? " · MANUAL" : "")
                  color: root.dimText
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.1
                }

                Text {
                  text: laneRow.headline
                    ? laneRow.headline.label + (laneRow.headline.sub ? " · " + laneRow.headline.sub : "")
                    : "not wired"
                  color: root.dimText
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              Text {
                id: laneValue
                text: laneRow.headline ? Model.fmtKpi(laneRow.headline.value) : "—"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }
  }
}
