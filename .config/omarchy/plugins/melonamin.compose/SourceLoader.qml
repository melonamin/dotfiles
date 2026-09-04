import QtQuick
import Quickshell
import Quickshell.Io
import "ComposeModel.js" as ComposeModel

Item {
  id: root

  property string sourceDir: ""
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || (Quickshell.env("HOME") + "/.local/share/omarchy")
  property string rootPath: Quickshell.env("XCOMPOSEFILE") || (Quickshell.env("HOME") + "/.XCompose")
  property bool loading: loader.running
  property var keysymDefinitions: ({})
  property var graph: ({ rootPath: rootPath, sources: [], rules: [], activeRules: [], diagnostics: [] })
  property var watchedPaths: []
  property string errorMessage: ""
  property bool reloadPending: false

  signal loaded(var graph)
  signal failed(string message)

  function decodeBase64Utf8(encoded) {
    // Qt's QML helper decodes the UTF-8 payload into a JavaScript string.
    // Treating that string as raw bytes a second time consumes closing quotes
    // after non-ASCII results and turns otherwise valid system rules malformed.
    return Qt.atob(String(encoded || ""))
  }

  function reload() {
    if (!sourceDir) return
    if (loader.running) { reloadPending = true; return }
    errorMessage = ""
    loader.command = [sourceDir + "/scripts/compose-sources", "--root", rootPath, "--omarchy", omarchyPath]
    loader.running = true
  }

  function consume(raw) {
    var payload
    try { payload = JSON.parse(String(raw || "")) }
    catch (error) { errorMessage = "Could not decode the Compose source graph"; failed(errorMessage); return }
    var definitions = ComposeModel.parseKeysymDefinitions(decodeBase64Utf8(payload.keysymB64 || ""))
    keysymDefinitions = definitions
    var includePaths = {}
    var includes = payload.includes || []
    for (var m = 0; m < includes.length; m++) includePaths[includes[m].from + "|" + includes[m].template] = includes[m].resolved
    var sources = []
    for (var i = 0; i < payload.sources.length; i++) {
      var source = payload.sources[i]
      sources.push({
        path: source.path,
        raw: decodeBase64Utf8(source.contentB64 || ""),
        digest: String(source.digest || ""),
        missingRoot: source.missingRoot === true,
        unreadableRoot: source.unreadableRoot === true,
        kind: ComposeModel.classifySource(source.path, payload.rootPath, payload.omarchyPath)
      })
    }
    graph = ComposeModel.resolveSourceGraph(sources, payload.rootPath, {
      home: payload.home,
      system: payload.system,
      localeCompose: payload.localeCompose,
      omarchyPath: payload.omarchyPath,
      keysymDefinitions: definitions,
      includePaths: includePaths
    })
    var watched = {}
    for (var sourceIndex = 0; sourceIndex < graph.sources.length; sourceIndex++) {
      var sourcePath = graph.sources[sourceIndex].path
      if (sourcePath !== graph.rootPath) watched[sourcePath] = true
    }
    for (var includeIndex = 0; includeIndex < includes.length; includeIndex++) {
      var resolvedPath = String(includes[includeIndex].resolved || "")
      if (resolvedPath && resolvedPath !== graph.rootPath) watched[resolvedPath] = true
    }
    watchedPaths = Object.keys(watched)
    loaded(graph)
  }

  Process {
    id: loader
    stdout: StdioCollector { id: output }
    onExited: function(code) {
      if (root.reloadPending) {
        root.reloadPending = false
        Qt.callLater(root.reload)
      } else if (code === 0) root.consume(output.text)
      else {
        root.errorMessage = "Could not read Compose sources"
        root.failed(root.errorMessage)
      }
    }
  }

  FileView {
    path: root.rootPath
    watchChanges: true
    preload: false
    onFileChanged: refreshDebounce.restart()
  }

  Instantiator {
    model: root.watchedPaths
    delegate: FileView {
      required property string modelData
      path: modelData
      watchChanges: true
      preload: false
      onFileChanged: refreshDebounce.restart()
    }
  }

  Timer {
    id: refreshDebounce
    interval: 180
    onTriggered: root.reload()
  }
}
