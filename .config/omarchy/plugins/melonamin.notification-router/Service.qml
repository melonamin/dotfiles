// Notification router service.
//
// Attaches to the first-party notification service rather than replacing it.
// The shell's `omarchy.notifications` plugin owns the org.freedesktop
// NotificationServer, and only one process can; but its `popupModel` is a
// public alias, and a row removed inside the model's own rowsInserted handler
// is gone before control returns to the event loop — so the toast's Wayland
// surface is never mapped and never composited. Silencing this way is exact,
// not a race, and it leaves the notification in omarchy's history where the
// user can still find it.

import QtQuick
import Quickshell
import Quickshell.Io

import "RouterModel.js" as RouterModel
import "SinkModel.js" as SinkModel

Item {
  id: root

  // Injected by the shell's service loader.
  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/notification-router"
  readonly property string rulesPath: configDir + "/rules.json"

  // Compiled rules and the diagnostics from the last parse. Errors are held
  // rather than logged-and-dropped so the panel can show the user exactly
  // which rule is broken.
  property var rules: []
  property var ruleErrors: []
  property bool rulesLoaded: false
  // The rules file as parsed, kept so panel edits rewrite the user's document
  // rather than a reconstruction of it.
  property var rulesDoc: ({ rules: [] })

  // The first-party notification service, once it exists.
  property var notifService: null
  readonly property bool attached: !!notifService && !!notifService.popupModel

  // Routed notifications waiting to be acknowledged — one dot each.
  property alias pending: pendingModel
  ListModel { id: pendingModel }

  // Ring buffer of what recently came through, so the panel can test a rule
  // against real traffic instead of hypotheticals. Holds snapshots only.
  property var recent: []
  readonly property int recentLimit: 20

  // Notifications already routed, keyed by originalId + timestamp. A history
  // replay re-inserts old rows into popupModel; without this, opening the
  // notification history would re-fire every ntfy and webhook in it.
  property var routedKeys: ({})

  signal routed(string summary, var verdict)

  // ------------------------------------------------------------ rule loading

  function applyRules(raw) {
    var parsed = RouterModel.parseRules(raw)
    root.rules = parsed.rules
    root.ruleErrors = parsed.errors
    root.rulesDoc = parsed.doc
    root.rulesLoaded = true
    for (var i = 0; i < parsed.errors.length; i++) {
      console.warn("notification-router: " + parsed.errors[i])
    }
  }

  FileView {
    id: rulesFile
    path: root.rulesPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyRules(text())
    // No rules file yet is the normal first-run state, not an error: the
    // router simply passes everything through until one is written.
    onLoadFailed: root.applyRules("")
    onFileChanged: reload()
  }

  function saveRules(text) {
    rulesFile.setText(text)
    // FileView does not re-emit onLoaded for its own write.
    root.applyRules(text)
  }

  // ------------------------------------------------------------ rule editing
  //
  // Every edit rewrites the whole document from the parsed original, so a rule
  // the panel cannot display (one that failed to compile) survives untouched
  // instead of being dropped on the next save.

  function saveDoc(doc) {
    root.saveRules(RouterModel.serialize(doc))
  }

  function setRuleEnabled(sourceIndex, enabled) {
    saveDoc(RouterModel.withRuleEnabled(root.rulesDoc, sourceIndex, !!enabled))
  }

  function removeRule(sourceIndex) {
    saveDoc(RouterModel.withRuleRemoved(root.rulesDoc, sourceIndex))
  }

  function appendRule(rule) {
    saveDoc(RouterModel.withRuleAppended(root.rulesDoc, rule))
  }

  // Draft a rule from one of the recently-seen notifications and save it.
  function draftFromRecent(recentIndex, actions) {
    if (recentIndex < 0 || recentIndex >= root.recent.length) return false
    appendRule(RouterModel.draftRule(root.recent[recentIndex], actions))
    return true
  }

  // FileView will not create a missing parent directory, and spawning mkdir
  // inside a save would race the write it is meant to enable.
  Process { id: configDirProcess; command: ["mkdir", "-p", root.configDir] }

  // ------------------------------------------------------------- attachment

  // The first-party service may not be constructed yet when this one loads;
  // the shell builds services in registry order. Poll briefly rather than
  // depend on that order.
  Timer {
    id: attachTimer
    interval: 250
    repeat: true
    running: true
    onTriggered: {
      if (root.attached || !root.shell || !root.shell.serviceFor) return
      var svc = root.shell.serviceFor("omarchy.notifications")
      if (!svc || !svc.popupModel) return
      root.notifService = svc
      running = false
    }
  }

  Connections {
    target: root.attached ? root.notifService.popupModel : null
    ignoreUnknownSignals: true
    function onRowsInserted(parent, first, last) {
      // Descending: acting on a row can remove it, which shifts every index
      // above it down.
      for (var i = last; i >= first; i--) root.consider(i)
    }
  }

  // Whether this row is a notification that just arrived, as opposed to one
  // the shell restored after a restart or replayed out of history. A genuinely
  // new notification is the only kind with a live server object behind it.
  function isFreshArrival(row) {
    if (!row) return false
    var id = row.originalId
    if (id === undefined || id === null || id < 0) return false
    if (root.notifService.isRestoredRow && root.notifService.isRestoredRow(row)) return false
    var refs = root.notifService.liveRefs
    return !!(refs && refs[id])
  }

  function routeKey(row) {
    return String(row.originalId) + ":" + String(row.timestamp)
  }

  function snapshotOf(row) {
    return {
      app: String(row.app || ""),
      summary: String(row.summary || ""),
      body: String(row.body || ""),
      // Omarchy's own toasts carry their click action here; it outlives the
      // notification object, so a dot stays clickable after silencing.
      exec: String(row.exec || ""),
      urgency: row.urgency,
      timestamp: row.timestamp
    }
  }

  function consider(index) {
    if (!root.attached) return
    var model = root.notifService.popupModel
    if (index < 0 || index >= model.count) return

    var row = model.get(index)
    if (!row || !isFreshArrival(row)) return

    var key = routeKey(row)
    if (root.routedKeys[key]) return
    root.routedKeys[key] = true

    var snapshot = snapshotOf(row)
    rememberRecent(snapshot)

    var verdict = RouterModel.evaluate(root.rules, snapshot)
    if (RouterModel.isNoop(verdict)) return

    apply(verdict, snapshot, index)
    root.routed(snapshot.summary, verdict)
  }

  function rememberRecent(snapshot) {
    var next = root.recent.slice()
    next.unshift(snapshot)
    if (next.length > root.recentLimit) next.length = root.recentLimit
    root.recent = next
  }

  function apply(verdict, snapshot, index) {
    if (verdict.dot) addDot(verdict, snapshot)
    if (verdict.sound) sinks.playSound(verdict.sound, verdict.matched.join(", "))
    for (var i = 0; i < verdict.sinks.length; i++) sinks.fire(verdict.sinks[i], snapshot)

    if (verdict.silence) {
      // "expire", not "dismiss": the user never saw this, so the sender should
      // be told it timed out rather than that the user waved it away. Chat
      // clients treat those two very differently.
      root.notifService.removePopup(index, "expire")
    }
  }

  // ------------------------------------------------------------------- dots

  function addDot(verdict, snapshot) {
    pendingModel.insert(0, {
      colour: String(verdict.dot),
      app: snapshot.app,
      summary: snapshot.summary,
      body: snapshot.body,
      rule: verdict.matched.join(", "),
      exec: snapshot.exec || "",
      timestamp: snapshot.timestamp
    })
  }

  function clearDot(index) {
    if (index < 0 || index >= pendingModel.count) return
    pendingModel.remove(index)
  }

  function clearDots() {
    pendingModel.clear()
  }

  // -------------------------------------------------------------- rule test

  // What the current rules would do to the last `recentLimit` notifications.
  // The panel uses this to show which of them a rule catches before the user
  // commits to it.
  function testAgainstRecent() {
    var out = []
    for (var i = 0; i < root.recent.length; i++) {
      var snapshot = root.recent[i]
      var verdict = RouterModel.evaluate(root.rules, snapshot)
      out.push({
        app: snapshot.app,
        summary: snapshot.summary,
        matched: verdict.matched,
        silence: verdict.silence,
        dot: verdict.dot,
        sinks: verdict.sinks.map(function (s) { return s.kind })
      })
    }
    return out
  }

  Sinks { id: sinks }

  // -------------------------------------------------------------------- IPC

  IpcHandler {
    target: "notification-router"

    function status(): string {
      return JSON.stringify({
        attached: root.attached,
        rulesLoaded: root.rulesLoaded,
        rules: root.rules.length,
        errors: root.ruleErrors,
        pending: pendingModel.count,
        recent: root.recent.length,
        rulesPath: root.rulesPath
      })
    }

    function reload(): string {
      rulesFile.reload()
      return "ok"
    }

    // Ask what the rules would do to a hypothetical notification, without
    // sending one. The whole point of a rule engine is being able to answer
    // "why did that get silenced" afterwards.
    function explain(app: string, summary: string, body: string): string {
      var verdict = RouterModel.evaluate(root.rules, {
        app: String(app || ""), summary: String(summary || ""),
        body: String(body || ""), urgency: 1
      })
      return JSON.stringify(verdict)
    }

    function test(): string {
      return JSON.stringify(root.testAgainstRecent())
    }

    function pending(): string {
      var out = []
      for (var i = 0; i < pendingModel.count; i++) {
        var row = pendingModel.get(i)
        out.push({ colour: row.colour, app: row.app, summary: row.summary, rule: row.rule })
      }
      return JSON.stringify(out)
    }

    function clear(): string {
      root.clearDots()
      return "ok"
    }

    function ping(): string { return "ok" }
  }

  Component.onCompleted: configDirProcess.running = true
}
