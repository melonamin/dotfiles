// Executes the outbound half of a verdict: sound, ntfy, webhook.
//
// HTTP sinks run through a single serialised Process rather than a burst of
// detached ones. Sinks fire at notification rate, which during a chat storm is
// faster than a human reads; serialising bounds how many curls can exist at
// once and gives every call a place to report a non-zero exit. Fire-and-forget
// would swallow the failures silently.

import QtQuick
import Quickshell
import Quickshell.Io

import "SinkModel.js" as SinkModel

Item {
  id: sinks

  // Player used for the `sound` action. pw-play ships with PipeWire, which
  // Omarchy runs.
  property string soundPlayer: "pw-play"

  // Bounded so a misconfigured rule during a notification storm cannot grow
  // the queue without limit.
  readonly property int maxQueue: 32
  property var queue: []

  signal failed(string kind, string rule, string message)

  function report(kind, rule, message) {
    console.warn("notification-router: " + kind + " sink"
      + (rule ? ' for rule "' + rule + '"' : "") + " failed: " + message)
    sinks.failed(kind, rule || "", message)
  }

  // ------------------------------------------------------------------ sound

  function playSound(value, rule) {
    var built = SinkModel.soundCommand(value, sinks.soundPlayer)
    if (!built.ok) {
      report("sound", rule, built.error)
      return
    }
    // Sound is latency-sensitive and cheap, so it skips the HTTP queue: a slow
    // webhook must never delay the ping that tells the user something happened.
    // It still runs through a Process rather than execDetached so a missing
    // file or a broken player reports itself instead of failing silently.
    if (!soundRunner.running) {
      soundRunner.rule = rule || ""
      soundRunner.path = built.argv[built.argv.length - 1]
      soundRunner.command = built.argv
      soundRunner.running = true
      return
    }
    // Already playing — overlap rather than queue, so a burst of notifications
    // does not turn into a slow drip of delayed pings. This one goes
    // unreported, which is the right trade for a sound that is already known
    // to work: the tracked path above has reported it at least once.
    Quickshell.execDetached(built.argv)
  }

  Process {
    id: soundRunner
    property string rule: ""
    property string path: ""
    running: false

    stderr: StdioCollector { id: soundErr }

    onExited: function (code, status) {
      if (code === 0) return
      var detail = String(soundErr.text || "").trim()
      sinks.report("sound", soundRunner.rule,
        "exit " + code + " playing " + soundRunner.path + (detail ? " — " + detail : ""))
    }
  }

  // --------------------------------------------------------------- dispatch

  function fire(sink, notification) {
    if (!sink) return

    var built = SinkModel.build(sink, notification)
    if (!built.ok) {
      report(sink.kind, sink.rule, built.error)
      return
    }
    enqueue({ kind: sink.kind, rule: sink.rule, argv: built.argv, endpoint: built.endpoint })
  }

  // ------------------------------------------------------------------ queue

  function enqueue(job) {
    if (sinks.queue.length >= sinks.maxQueue) {
      report(job.kind, job.rule, "sink queue is full (" + sinks.maxQueue + " pending), dropping this call")
      return
    }
    var next = sinks.queue.slice()
    next.push(job)
    sinks.queue = next
    pump()
  }

  function pump() {
    if (runner.running || sinks.queue.length === 0) return
    var next = sinks.queue.slice()
    var job = next.shift()
    sinks.queue = next
    runner.job = job
    runner.command = job.argv
    runner.running = true
  }

  Process {
    id: runner
    property var job: null
    running: false

    stderr: StdioCollector { id: runnerErr }

    onExited: function (code, status) {
      var current = runner.job
      runner.job = null
      if (code !== 0 && current) {
        var detail = String(runnerErr.text || "").trim()
        sinks.report(current.kind, current.rule,
          "exit " + code + (current.endpoint ? " calling " + current.endpoint : "")
          + (detail ? " — " + detail : ""))
      }
      // Drain on the next tick so a queue of failing jobs cannot recurse.
      Qt.callLater(sinks.pump)
    }
  }
}
