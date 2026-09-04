// Turns a sink action's config into an argv array.
//
// Every sink is built as an explicit argv list and never as a shell string.
// Notification summaries and bodies are attacker-influenced text — a chat
// message can say whatever it likes — and they end up inside ntfy messages
// and webhook bodies. Handing that to `bash -lc` would be a command injection
// with extra steps. `Quickshell.execDetached(["curl", ...])` has no shell in
// the path at all.
//
// Pure JavaScript, no Qt: see RouterModel.js for why.

var NTFY_DEFAULT_SERVER = "https://ntfy.sh"
var FREEDESKTOP_SOUNDS = "/usr/share/sounds/freedesktop/stereo/"

// curl flags shared by both HTTP sinks. Fail loudly on HTTP errors (-f), stay
// quiet on success but print errors (-sS), and never let a hung endpoint leave
// a curl lying around forever (--max-time).
function curlBase() {
  return ["curl", "-fsS", "--max-time", "10", "-o", "/dev/null"]
}

function fail(message) {
  return { ok: false, error: message }
}

// ------------------------------------------------------------------- sound

// A value containing a slash is a path; anything else names a sound from the
// freedesktop theme, so `{"sound": "message-new-instant"}` just works.
function resolveSoundPath(value) {
  var raw = String(value || "").trim()
  if (!raw) return ""
  if (raw.indexOf("/") !== -1) return raw
  return FREEDESKTOP_SOUNDS + raw + ".oga"
}

function soundCommand(value, player) {
  var path = resolveSoundPath(value)
  if (!path) return fail("sound needs a file path or a freedesktop sound name")
  return { ok: true, argv: [player || "pw-play", path] }
}

// -------------------------------------------------------------------- ntfy

// Posted as a JSON document to the server root rather than as X-Title /
// X-Message headers, because header values cannot carry the newlines that
// notification bodies routinely contain.
function ntfyRequest(config, notification) {
  var cfg = config
  // `{"ntfy": "my-topic"}` is the shorthand everyone reaches for first.
  if (typeof cfg === "string") cfg = { topic: cfg }
  if (!cfg || typeof cfg !== "object") return fail("ntfy needs a topic or a config object")

  var topic = String(cfg.topic || "").trim()
  if (!topic) return fail("ntfy needs a `topic`")

  var server = String(cfg.server || NTFY_DEFAULT_SERVER).trim().replace(/\/+$/, "")
  if (!/^https?:\/\//.test(server)) return fail('ntfy `server` must start with http:// or https:// (got "' + server + '")')

  var n = notification || {}
  var payload = {
    topic: topic,
    title: cfg.title !== undefined ? String(cfg.title) : String(n.app || "Notification"),
    message: cfg.message !== undefined ? String(cfg.message) : String(n.summary || "")
  }
  if (payload.message === "") payload.message = String(n.body || " ")
  if (cfg.priority !== undefined) {
    var priority = parseInt(cfg.priority, 10)
    if (!isFinite(priority) || priority < 1 || priority > 5) return fail("ntfy `priority` must be 1-5")
    payload.priority = priority
  }
  if (cfg.tags !== undefined) {
    payload.tags = Array.isArray(cfg.tags) ? cfg.tags.map(String) : [String(cfg.tags)]
  }
  if (cfg.click !== undefined) payload.click = String(cfg.click)

  var argv = curlBase().concat([
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "--data-binary", JSON.stringify(payload),
    server
  ])
  if (cfg.token) argv = argv.concat(["-H", "Authorization: Bearer " + String(cfg.token)])
  return { ok: true, argv: argv, endpoint: server + "/" + topic }
}

// ----------------------------------------------------------------- webhook

var HTTP_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"]

function webhookRequest(config, notification) {
  var cfg = config
  if (typeof cfg === "string") cfg = { url: cfg }
  if (!cfg || typeof cfg !== "object") return fail("webhook needs a url or a config object")

  var url = String(cfg.url || "").trim()
  if (!url) return fail("webhook needs a `url`")
  if (!/^https?:\/\//.test(url)) return fail('webhook `url` must start with http:// or https:// (got "' + url + '")')

  var method = String(cfg.method || (cfg.json !== undefined || cfg.body !== undefined ? "POST" : "GET")).toUpperCase()
  if (HTTP_METHODS.indexOf(method) === -1) return fail('webhook `method` must be one of ' + HTTP_METHODS.join(", "))

  var argv = curlBase().concat(["-X", method])

  var headers = cfg.headers
  if (headers && typeof headers === "object") {
    for (var key in headers) {
      if (!Object.prototype.hasOwnProperty.call(headers, key)) continue
      argv = argv.concat(["-H", String(key) + ": " + String(headers[key])])
    }
  }

  if (cfg.json !== undefined) {
    // Default the whole notification in, so `{"webhook":{"url":"..","json":{}}}`
    // still forwards something useful.
    var body = cfg.json
    if (body && typeof body === "object" && Object.keys(body).length === 0) {
      var n = notification || {}
      body = { app: n.app || "", summary: n.summary || "", body: n.body || "", urgency: n.urgency }
    }
    argv = argv.concat(["-H", "Content-Type: application/json", "--data-binary", JSON.stringify(body)])
  } else if (cfg.body !== undefined) {
    argv = argv.concat(["--data-binary", String(cfg.body)])
  }

  argv.push(url)
  return { ok: true, argv: argv, endpoint: url }
}

// -------------------------------------------------------------------- build

// One entry point the QML side calls for any sink kind.
function build(sink, notification, options) {
  if (!sink || !sink.kind) return fail("sink has no kind")
  var opts = options || {}
  switch (sink.kind) {
  case "ntfy": return ntfyRequest(sink.config, notification)
  case "webhook": return webhookRequest(sink.config, notification)
  case "sound": return soundCommand(sink.config, opts.player)
  }
  return fail('unknown sink kind "' + sink.kind + '"')
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    NTFY_DEFAULT_SERVER: NTFY_DEFAULT_SERVER,
    FREEDESKTOP_SOUNDS: FREEDESKTOP_SOUNDS,
    resolveSoundPath: resolveSoundPath,
    soundCommand: soundCommand,
    ntfyRequest: ntfyRequest,
    webhookRequest: webhookRequest,
    build: build
  }
}
