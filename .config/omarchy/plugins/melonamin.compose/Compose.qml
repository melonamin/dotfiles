import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ComposeModel.js" as ComposeModel
import "components"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property string omarchyPath: ""

  readonly property string pluginId: (manifest && manifest.id) || "melonamin.compose"
  readonly property string sourceDir: (manifest && manifest.__sourceDir) || ""
  readonly property string effectiveOmarchyPath: omarchyPath || Quickshell.env("OMARCHY_PATH") || (Quickshell.env("HOME") + "/.local/share/omarchy")
  readonly property string composeFileHelper: sourceDir + "/scripts/compose-file"
  readonly property string insertHelper: sourceDir + "/scripts/compose-insert"

  property bool opened: false
  property string mode: "quick"
  property string query: ""
  property string sourceFilter: "All"
  property bool includeShadowed: false
  property int selectedIndex: 0
  property var graph: ({ rootPath: sourceLoader.rootPath, sources: [], rules: [], activeRules: [], diagnostics: [] })
  property var displayRules: []
  property var emojiOutputs: ({})
  readonly property var selectedRule: selectedIndex >= 0 && selectedIndex < displayRules.length ? displayRules[selectedIndex] : null
  property string revision: ""
  property var revisionMetadata: ({})
  property string statusMessage: ""
  property bool busy: false
  property bool editorOpen: false
  property var editorTarget: null
  property string editorAction: "new"
  property int editorSession: 0
  property bool dirty: false
  property bool externalChanged: false
  property string draftRaw: ""
  property string pendingCandidate: ""
  property string pendingConfirmedCandidate: ""
  property var pendingGraph: null
  property var deleteTarget: null
  property string confirmPurpose: ""
  property bool graphReady: false
  property bool readOnly: externalChanged || !graphReady || !rootSource() || rootSource().unreadableRoot || !revision || !revisionMetadata.writable || rootHasUnsafeSyntax()
  property string lastTransactionDiagnostic: ""

  function utf8Base64(value) {
    return Qt.btoa(String(value || ""))
  }

  function rootSource() {
    for (var i = 0; i < graph.sources.length; i++) if (graph.sources[i].path === graph.rootPath) return graph.sources[i]
    return null
  }

  function rootDocument() {
    var source = rootSource()
    return source ? source.document : ComposeModel.parseDocument("", { sourceId: graph.rootPath, path: graph.rootPath })
  }

  function rootHasUnsafeSyntax() {
    var source = rootSource()
    if (!source || !source.document) return false
    var nodes = source.document.nodes || []
    for (var i = 0; i < nodes.length; i++) if (nodes[i].type === "malformed") return true
    return false
  }

  function updateServiceState() {
    if (!service) return
    var diagnostics = documentDiagnostics()
    var kinds = {}
    var reasons = {}
    for (var i = 0; i < diagnostics.length; i++) {
      var kind = String(diagnostics[i].kind || "unknown")
      kinds[kind] = (kinds[kind] || 0) + 1
      var reason = String(diagnostics[i].message || kind)
      reasons[reason] = (reasons[reason] || 0) + 1
    }
    service.setUiState({
      open: opened,
      mode: mode,
      revision: revision,
      sourceCount: graph.sources.length,
      ruleCount: graph.rules.length,
      diagnosticsCount: diagnostics.length,
      diagnosticKinds: kinds,
      diagnosticReasons: reasons,
      dirty: dirty
    })
  }

  function documentDiagnostics() {
    var items = graph && graph.diagnostics ? graph.diagnostics.slice() : []
    var source = rootSource()
    if (lastTransactionDiagnostic) items.push({
      kind: "transaction", severity: "error", message: lastTransactionDiagnostic
    })
    if (externalChanged) items.push({
      kind: "external-edit", severity: "error", path: graph.rootPath,
      message: "The root Compose file changed while an edit was in progress"
    })
    if (graphReady && source && source.unreadableRoot) items.push({
      kind: "read-only", severity: "error", path: graph.rootPath,
      message: "Studio is read-only because the root Compose file is unreadable"
    })
    else if (graphReady && rootHasUnsafeSyntax()) items.push({
      kind: "read-only", severity: "error", path: graph.rootPath,
      message: "Studio is read-only until malformed root syntax is repaired"
    })
    else if (graphReady && revisionMetadata && revisionMetadata.writable === false) items.push({
      kind: "read-only", severity: "error", path: graph.rootPath,
      message: "Studio cannot safely replace the root Compose file"
    })
    return items
  }

  function overlayDiagnostics() {
    var items = documentDiagnostics()
    if (service && service.fcitxHealthKnown && !service.fcitxHealthy) items.push({
      kind: "input-method", severity: "error",
      message: "omarchy-fcitx5.service is not active; saved rules cannot be activated"
    })
    if (service && service.shortcutDiagnostic) items.push({
      kind: "shortcut",
      severity: service.requestedShortcut ? "warning" : "info",
      message: service.shortcutDiagnostic
    })
    return items
  }

  function open(payloadJson) {
    var nextMode = ComposeModel.parseModePayload(payloadJson)
    if (!opened) { query = ""; selectedIndex = 0 }
    mode = nextMode
    opened = true
    if (graphReady) {
      statusMessage = graph.diagnostics.length ? graph.diagnostics.length + " diagnostics" : "Compose library ready"
      rebuildDisplay()
      updateServiceState()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    graphReady = false
    revision = ""
    revisionMetadata = ({})
    statusMessage = "Loading Compose library…"
    sourceLoader.reload()
    updateServiceState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    if (busy) { statusMessage = "Saving and activating the Compose file…"; return }
    if (dirty) {
      confirmPurpose = "discard-close"
      confirmDialog.message = "Discard the unsaved Compose rule and close?"
      confirmDialog.confirmText = "Discard"
      confirmDialog.opened = true
      return
    }
    opened = false
    updateServiceState()
  }

  function forceClose() {
    editorOpen = false
    dirty = false
    opened = false
    updateServiceState()
  }

  function dismiss() {
    if (dirty) { close(); return }
    forceClose()
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }

  function setMode(next) {
    if (busy) return
    mode = next === "studio" ? "studio" : "quick"
    rebuildDisplay()
    updateServiceState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function requestRevision() {
    if (!composeFileHelper || revisionProcess.running) return
    revisionProcess.command = [composeFileHelper, "--file", sourceLoader.rootPath, "revision"]
    revisionProcess.running = true
  }

  function acceptGraph(nextGraph) {
    if (dirty && ComposeModel.rootContentChanged(graph, nextGraph)) {
      pendingGraph = nextGraph
      externalChanged = true
      statusMessage = "The Compose file changed outside Studio — reload or copy your draft"
      updateServiceState()
      return
    }
    if (confirmPurpose === "delete") {
      confirmDialog.opened = false
      deleteTarget = null
      confirmPurpose = ""
    }
    graph = nextGraph
    graphReady = rootSource() !== null
    revision = ""
    revisionMetadata = ({})
    pendingGraph = null
    externalChanged = false
    statusMessage = graph.diagnostics.length ? graph.diagnostics.length + " diagnostics" : "Compose library ready"
    rebuildDisplay()
    requestRevision()
    updateServiceState()
  }

  function rebuildDisplay() {
    displayRules = ComposeModel.searchRules(graph.rules, query, {
      includeShadowed: includeShadowed || sourceFilter === "Conflicts",
      source: mode === "studio" ? sourceFilter : "All",
      groupOutputs: mode === "quick",
      excludeOutputs: mode === "quick" ? emojiOutputs : null,
      limit: mode === "studio" ? graph.rules.length : 200
    })
    if (displayRules.length === 0) selectedIndex = 0
    else selectedIndex = Math.max(0, Math.min(selectedIndex, displayRules.length - 1))
  }

  function setQuery(value) {
    query = String(value || "")
    selectedIndex = 0
    searchDebounce.restart()
  }

  function select(delta) {
    if (!displayRules.length) return
    selectedIndex = (selectedIndex + delta + displayRules.length) % displayRules.length
  }

  function selectAbsolute(index) {
    if (!displayRules.length) return
    selectedIndex = Math.max(0, Math.min(index, displayRules.length - 1))
  }

  function inspectWinner(rule) {
    if (!rule || !rule.shadowedBy) return
    var winner = null
    for (var i = 0; i < graph.rules.length; i++) {
      if (graph.rules[i].id === rule.shadowedBy) { winner = graph.rules[i]; break }
    }
    if (!winner) { statusMessage = "The winning definition is no longer available"; return }
    query = ""
    sourceFilter = "All"
    includeShadowed = false
    rebuildDisplay()
    for (var shown = 0; shown < displayRules.length; shown++) {
      if (displayRules[shown].id === winner.id) { selectedIndex = shown; break }
    }
    statusMessage = "Showing the active definition"
  }

  function activateSelected(copyOnly) {
    var rule = selectedRule
    if (!rule || !rule.insertable) { statusMessage = "This keysym has no insertable UTF-8 output"; return }
    if (!copyOnly) {
      forceClose()
      if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    }
    insertProcess.copyOnly = copyOnly
    insertProcess.payload = utf8Base64(rule.output)
    insertProcess.command = [insertHelper, copyOnly ? "--copy-only" : "--insert"]
    insertProcess.running = true
  }

  function beginEditor(rule, action) {
    if (busy) return
    if (readOnly) { statusMessage = "Studio is read-only until the root file is repaired or reloaded"; return }
    editorTarget = rule || null
    editorAction = action || "new"
    editorSession++
    editorOpen = true
    dirty = true
    draftRaw = rule && rule.raw ? String(rule.raw).replace(/(?:\r\n|\n|\r)$/, "") : ""
    updateServiceState()
  }

  function cancelEditor() {
    if (busy) { statusMessage = "Saving and activating the Compose file…"; return }
    confirmPurpose = "discard-editor"
    confirmDialog.message = "Discard this unsaved Compose rule?"
    confirmDialog.confirmText = "Discard"
    confirmDialog.opened = true
  }

  function saveEditor(rule, rawRule) {
    if (busy) return
    var document = rootDocument()
    var newline = document.newlineStyle || "\n"
    var ruleText = rawRule ? String(rawRule).replace(/(?:\r\n|\n|\r)+$/, "") : ComposeModel.encodeRule(rule)
    draftRaw = ruleText
    var modelOptions = { keysymDefinitions: sourceLoader.keysymDefinitions }
    var parsed = ComposeModel.parseDocument(ruleText + newline, modelOptions)
    if (parsed.nodes.length !== 1 || parsed.nodes[0].type !== "rule") { statusMessage = "The edited rule is not valid XCompose syntax"; return }
    var conflictRules = []
    var localExactRules = []
    for (var i = 0; i < graph.rules.length; i++) {
      var existing = graph.rules[i]
      var isEditedRule = editorAction === "edit" && editorTarget
        && (existing === editorTarget || (existing.id && existing.id === editorTarget.id))
      if (!isEditedRule && existing.sourceKind === "Mine"
          && ComposeModel.sequenceRelation(existing.sequence, parsed.nodes[0].sequence) === "exact") {
        localExactRules.push(existing)
      }
      if (existing.active && !isEditedRule) conflictRules.push(existing)
    }
    var conflict = ComposeModel.findSequenceConflict(conflictRules, parsed.nodes[0].sequence)
    var candidate
    if (localExactRules.length) {
      var localTargets = localExactRules.slice()
      if (editorAction === "edit" && editorTarget && editorTarget.sourceKind === "Mine") localTargets.push(editorTarget)
      var localAnchor = conflict.exact && conflict.exact.sourceKind === "Mine" ? conflict.exact : null
      candidate = ComposeModel.replaceLocalDefinitions(document, localTargets, localAnchor, ruleText)
      var movedAfterConflict = !localAnchor && (conflict.exact || conflict.prefixes.length)
      confirmApply(candidate,
        "Replace the existing local rule" + (localExactRules.length > 1 ? "s" : "")
          + " for this sequence? This keeps only one local definition"
          + (movedAfterConflict ? " and moves it after later conflicting definitions." : "."),
        "Replace")
      statusMessage = "An existing local rule uses this sequence"
      return
    }
    if (editorAction === "edit" && editorTarget && editorTarget.sourceKind === "Mine") {
      candidate = conflict.exact
        ? ComposeModel.moveRuleToLocalSection(document, editorTarget, ruleText)
        : ComposeModel.replaceSpan(document, editorTarget, ruleText + originalTerminator(editorTarget))
    } else candidate = ComposeModel.appendLocalRule(document, ruleText)
    if (conflict.exact) {
      confirmApply(candidate,
        "This sequence is already defined by " + conflict.exact.sourceKind + ". Save a local override?",
        "Create override")
      statusMessage = "This sequence will override an included definition"
      return
    }
    if (conflict.prefixes.length) {
      var firstPrefix = conflict.prefixes[0]
      var prefixCount = conflict.prefixes.length
      confirmApply(candidate,
        "This creates a prefix collision with " + firstPrefix.displaySequence
          + (prefixCount > 1 ? " and " + (prefixCount - 1) + " other active rules" : "")
          + ". Under libxkbcommon, the later definition stays active and shadows the earlier one.",
        "Save anyway")
      statusMessage = "This sequence has an active prefix conflict"
      return
    }
    startApply(candidate)
  }

  function confirmApply(candidate, message, confirmText) {
    pendingConfirmedCandidate = candidate
    confirmPurpose = "apply"
    confirmDialog.message = message
    confirmDialog.confirmText = confirmText
    confirmDialog.opened = true
  }

  function originalTerminator(target) {
    var match = String(target && target.raw || "").match(/(\r\n|\n|\r)$/)
    return match ? match[1] : ""
  }

  function startApply(candidate) {
    if (busy || transactionProcess.running) return
    var checked = ComposeModel.validateCandidate(candidate, { keysymDefinitions: sourceLoader.keysymDefinitions })
    if (!checked.valid) { statusMessage = checked.diagnostics.length ? checked.diagnostics[0].message : "Complete candidate validation failed"; return }
    if (!revision) { statusMessage = "Waiting for the current file revision"; requestRevision(); return }
    pendingCandidate = candidate
    busy = true
    statusMessage = "Saving and activating the Compose file…"
    transactionProcess.command = [composeFileHelper, "--file", sourceLoader.rootPath, "apply", revision]
    transactionProcess.running = true
  }

  function requestDelete(rule) {
    if (busy || !rule || rule.sourceKind !== "Mine" || readOnly) return
    deleteTarget = rule
    confirmPurpose = "delete"
    confirmDialog.message = "Delete “" + (rule.comment || rule.displaySequence) + "” from your Compose file?"
    confirmDialog.confirmText = "Delete"
    confirmDialog.opened = true
  }

  function performDelete() {
    if (!deleteTarget) return
    startApply(ComposeModel.deleteRule(rootDocument(), deleteTarget))
    deleteTarget = null
  }

  function requestUndo() {
    if (busy || !revision || readOnly || undoProcess.running) return
    busy = true
    undoProcess.command = [composeFileHelper, "--file", sourceLoader.rootPath, "undo", revision]
    undoProcess.running = true
  }

  function reloadExternal() {
    dirty = false
    editorOpen = false
    externalChanged = false
    if (pendingGraph) acceptGraph(pendingGraph)
    else sourceLoader.reload()
  }

  function copyDraft() {
    if (!draftRaw) { statusMessage = "There is no raw draft to copy"; return }
    insertProcess.copyOnly = true
    insertProcess.payload = utf8Base64(draftRaw)
    insertProcess.command = [insertHelper, "--copy-only"]
    insertProcess.running = true
  }

  function openRawFile() {
    Quickshell.execDetached([effectiveOmarchyPath + "/bin/omarchy-launch-editor", sourceLoader.rootPath])
  }

  function handleKey(event) {
    if (busy) { event.accepted = true; return }
    if (confirmDialog.opened && confirmDialog.handleKey(event)) { event.accepted = true; return }
    if (editorOpen) {
      if (event.key === Qt.Key_Escape) { cancelEditor(); event.accepted = true }
      return
    }
    if (event.key === Qt.Key_Escape) {
      if (query) setQuery("")
      else if (mode === "studio") setMode("quick")
      else dismiss()
      event.accepted = true
    } else if (event.key === Qt.Key_Up) { select(-1); event.accepted = true }
    else if (event.key === Qt.Key_Down) { select(1); event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateSelected((event.modifiers & Qt.ControlModifier) !== 0); event.accepted = true }
    else if (Util.editsFilter(event, query)) { setQuery(Util.editedFilter(event, query)); event.accepted = true }
    else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) { setQuery(query + event.text); event.accepted = true }
  }

  SourceLoader {
    id: sourceLoader
    sourceDir: root.sourceDir
    omarchyPath: root.effectiveOmarchyPath
    onLoaded: graph => root.acceptGraph(graph)
    onFailed: message => { root.statusMessage = message; root.updateServiceState() }
  }

  FileView {
    path: root.effectiveOmarchyPath + "/shell/plugins/emojis/emojis.json"
    watchChanges: true
    onLoaded: {
      root.emojiOutputs = ComposeModel.parseEmojiOutputs(text())
      if (root.graphReady) root.rebuildDisplay()
    }
    onLoadFailed: {
      root.emojiOutputs = ({})
      if (root.graphReady) root.rebuildDisplay()
    }
    onFileChanged: reload()
  }

  Timer { id: searchDebounce; interval: 60; onTriggered: root.rebuildDisplay() }

  Process {
    id: revisionProcess
    stdout: StdioCollector { id: revisionOutput; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.statusMessage = "Could not inspect the Compose file"; return }
      try {
        var result = JSON.parse(revisionOutput.text)
        var snapshot = root.rootSource()
        if (!snapshot || !snapshot.digest || result.digest !== snapshot.digest) {
          root.revision = ""
          root.revisionMetadata = ({})
          root.statusMessage = "The Compose file changed while loading — reloading"
          sourceLoader.reload()
          root.updateServiceState()
          return
        }
        root.revision = result.revision || ""
        root.revisionMetadata = result
        root.updateServiceState()
      } catch (error) { root.statusMessage = "Invalid revision response" }
    }
  }

  Process {
    id: transactionProcess
    stdinEnabled: true
    environment: ({ COMPOSE_INPUT_BASE64: "1" })
    stdout: StdioCollector { id: transactionOutput; waitForEnd: true }
    onStarted: write(root.utf8Base64(root.pendingCandidate) + "\n")
    onExited: function(code) {
      root.busy = false
      var result = null
      try { result = JSON.parse(transactionOutput.text) } catch (error) {}
      if (code === 0 && result && result.ok) {
        root.revision = result.revision
        root.editorOpen = false
        root.dirty = false
        root.externalChanged = false
        root.lastTransactionDiagnostic = ""
        root.statusMessage = "Saved and activated"
        sourceLoader.reload()
      } else {
        root.lastTransactionDiagnostic = result && result.error ? result.error : "Transaction failed"
        root.statusMessage = result && result.rolledBack ? "Activation failed; previous Compose file restored" : root.lastTransactionDiagnostic
      }
      root.updateServiceState()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Process {
    id: undoProcess
    stdout: StdioCollector { id: undoOutput; waitForEnd: true }
    onExited: function(code) {
      root.busy = false
      var result = null
      try { result = JSON.parse(undoOutput.text) } catch (error) {}
      root.statusMessage = code === 0 ? "Restored the previous Compose file" : (result && result.error ? result.error : "Undo failed")
      if (code === 0) { root.revision = result.revision; sourceLoader.reload() }
      root.updateServiceState()
    }
  }

  Process {
    id: insertProcess
    property bool copyOnly: false
    property string payload: ""
    stdinEnabled: true
    environment: ({ COMPOSE_INPUT_BASE64: "1" })
    stdout: StdioCollector { id: insertOutput; waitForEnd: true }
    onStarted: write(payload + "\n")
    onExited: function(code) {
      var result = null
      try { result = JSON.parse(insertOutput.text) } catch (error) {}
      if (copyOnly) root.statusMessage = code === 0 ? "Copied exact Compose output" : (result && result.error ? result.error : "Copy failed")
      else if (code !== 0) {
        root.statusMessage = result && result.error ? result.error : "Compose could not insert the selected output"
        Quickshell.execDetached(["omarchy-notification-send", "Compose", root.statusMessage])
      }
      if (root.opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; right: true; bottom: true; left: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "melonamin-compose"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle { anchors.fill: parent; color: Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: Math.min(Style.space(root.mode === "studio" ? 1120 : 650), panel.width - Style.gapsOut * 2)
      height: Math.min(Style.space(root.mode === "studio" ? 740 : 560), panel.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: Style.spacing.panelPadding
      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        focus: true
        Keys.priority: Keys.AfterItem
        Keys.onPressed: event => root.handleKey(event)

        QuickView {
          anchors.fill: parent
          visible: root.mode === "quick"
          rules: root.displayRules
          selectedIndex: root.selectedIndex
          query: root.query
          statusMessage: root.statusMessage
          loading: sourceLoader.loading
          onSelected: index => root.selectAbsolute(index)
          onActivated: copyOnly => root.activateSelected(copyOnly)
          onManageRequested: root.setMode("studio")
        }

        StudioView {
          anchors.fill: parent
          visible: root.mode === "studio"
          rules: root.displayRules
          allRules: root.graph.rules
          selectedRule: root.selectedRule
          selectedIndex: root.selectedIndex
          query: root.query
          sourceFilter: root.sourceFilter
          diagnostics: root.overlayDiagnostics()
          keysymDefinitions: sourceLoader.keysymDefinitions
          shortcut: root.service ? root.service.requestedShortcut : ComposeModel.DEFAULT_SHORTCUT
          shortcutDiagnostic: root.service ? root.service.shortcutDiagnostic : ""
          statusMessage: root.statusMessage
          readOnly: root.readOnly
          editorOpen: root.editorOpen
          editorRule: root.editorTarget
          editorAction: root.editorAction
          editorSession: root.editorSession
          busy: root.busy
          onSelected: index => root.selectAbsolute(index)
          onFilterRequested: function(filter) { root.sourceFilter = filter; root.includeShadowed = filter === "Conflicts"; root.selectedIndex = 0; root.rebuildDisplay() }
          onQuickRequested: root.setMode("quick")
          onEditRequested: rule => root.beginEditor(rule, "edit")
          onOverrideRequested: rule => root.beginEditor(rule, "override")
          onDeleteRequested: rule => root.requestDelete(rule)
          onInspectWinnerRequested: rule => root.inspectWinner(rule)
          onNewRequested: root.beginEditor(null, "new")
          onUndoRequested: root.requestUndo()
          onValidateRequested: sourceLoader.reload()
          onOpenRawRequested: root.openRawFile()
          onShortcutChangeRequested: shortcut => { if (root.service) root.service.writeShortcut(shortcut) }
          onEditorSaveRequested: (rule, rawRule) => root.saveEditor(rule, rawRule)
          onEditorDraftChanged: rawRule => root.draftRaw = rawRule
          onEditorCancelRequested: root.cancelEditor()
        }

        ConfirmDialog {
          id: confirmDialog
          anchors.fill: parent
          background: Color.menu.background
          foreground: Color.menu.text
          onCanceled: {
            opened = false
            if (root.confirmPurpose === "apply") root.pendingConfirmedCandidate = ""
            if (root.confirmPurpose === "delete") root.deleteTarget = null
            root.confirmPurpose = ""
            Qt.callLater(function() { keyCatcher.forceActiveFocus() })
          }
          onConfirmed: {
            opened = false
            var purpose = root.confirmPurpose
            root.confirmPurpose = ""
            if (purpose === "delete") root.performDelete()
            else if (purpose === "apply") {
              var candidate = root.pendingConfirmedCandidate
              root.pendingConfirmedCandidate = ""
              if (candidate) root.startApply(candidate)
            }
            else if (purpose === "discard-editor") { root.editorOpen = false; root.dirty = false; root.draftRaw = ""; root.updateServiceState() }
            else if (purpose === "discard-close") {
              root.editorOpen = false; root.dirty = false; root.forceClose()
              if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
            }
            Qt.callLater(function() { keyCatcher.forceActiveFocus() })
          }
        }

        Row {
          visible: root.externalChanged
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: Style.spacing.sm
          Button { text: "Reload external file"; bordered: true; focusable: true; foreground: Color.menu.text; onClicked: root.reloadExternal() }
          Button { text: "Copy raw draft"; bordered: true; focusable: true; foreground: Color.menu.text; onClicked: root.copyDraft() }
        }
      }
    }
  }
}
