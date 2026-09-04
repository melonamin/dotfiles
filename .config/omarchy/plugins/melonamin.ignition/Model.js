/* Ignition — Launch Control (ignition.spot.t1a.dev) analytics model.
   Data source: the site's per-product JSON exports, the same files its
   Monitoring cockpit fetches (regenerated daily around 11:00 UTC):
     <baseUrl>/products/<id>/exports/monitoring.json
   Parsing is defensive throughout: a missing section renders as an empty
   list rather than breaking the panel. */

var PRODUCT_NAMES = {
  lakesentry: "LakeSentry",
  secondstack: "SecondStack",
  antares: "Antares",
  pondpilot: "PondPilot"
}

// Record separator curl emits between JSON bodies; chosen because it can
// never appear inside minified or pretty-printed JSON text.
var RS = "\u001e"

function productName(id) {
  if (PRODUCT_NAMES[id]) return PRODUCT_NAMES[id]
  var s = String(id || "")
  return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
}

function parseProducts(csv) {
  var out = []
  var parts = String(csv || "").split(",")
  for (var i = 0; i < parts.length; i++) {
    var id = parts[i].trim().toLowerCase()
    if (id !== "" && out.indexOf(id) === -1) out.push(id)
  }
  return out
}

function trimBase(baseUrl) {
  return String(baseUrl || "").replace(/\/+$/, "")
}

function monitoringUrl(baseUrl, id) {
  return trimBase(baseUrl) + "/products/" + encodeURIComponent(id) + "/exports/monitoring.json"
}

function cockpitUrl(baseUrl, id) {
  return trimBase(baseUrl) + "/#/" + encodeURIComponent(id) + "/monitoring"
}

// One curl fetches every product's export. -w RS is written after every
// transfer — including failed ones (-f suppresses the body, not the write-out)
// — so records stay aligned with the id list even when one product 404s.
function pollCommand(baseUrl, ids) {
  var cmd = ["curl", "-fsS", "--max-time", "15", "-w", RS]
  for (var i = 0; i < ids.length; i++) cmd.push(monitoringUrl(baseUrl, ids[i]))
  return cmd
}

// Batched poll response -> { id: model | null }, or null when nothing at all
// parsed (treated as unreachable; the caller keeps its previous data visible).
function parsePoll(raw, ids) {
  var records = String(raw || "").split(RS)
  var out = {}
  var any = false
  for (var i = 0; i < ids.length; i++) {
    var model = null
    if (i < records.length) {
      var text = records[i].trim()
      if (text !== "") {
        try { model = parseMonitoring(JSON.parse(text)) } catch (e) { model = null }
      }
    }
    out[ids[i]] = model
    if (model) any = true
  }
  return any ? out : null
}

function num(v) {
  var n = Number(v)
  return isFinite(n) ? n : 0
}

function str(v) {
  return v === null || v === undefined ? "" : String(v)
}

function parseKpis(list) {
  var out = []
  if (Array.isArray(list))
    for (var i = 0; i < list.length; i++)
      out.push({ label: str(list[i].label), value: str(list[i].value), sub: str(list[i].sub) })
  return out
}

// monitoring.json -> flat display model the QML binds to directly.
function parseMonitoring(m) {
  if (!m || typeof m !== "object" || !m.product) return null

  var gsc = m.gsc || {}
  var series = gsc.series || {}
  var pts = Array.isArray(series.points) ? series.points : []
  var impressions = [], clicks = [], dates = []
  for (var i = 0; i < pts.length; i++) {
    impressions.push(num(pts[i].v))
    clicks.push(num(pts[i].v2))
    dates.push(str(pts[i].date))
  }

  var funnel = m.funnel || {}
  var halves = funnel.halves || {}
  var productHalf = {}
  var productKeys = Array.isArray(halves.product) ? halves.product : []
  for (var p = 0; p < productKeys.length; p++) productHalf[productKeys[p]] = true

  var stages = []
  var rawStages = Array.isArray(funnel.stages) ? funnel.stages : []
  for (var s = 0; s < rawStages.length; s++) {
    stages.push({
      key: str(rawStages[s].key),
      label: str(rawStages[s].label),
      v: num(rawStages[s].v),
      kind: str(rawStages[s].kind),
      sub: str(rawStages[s].sub),
      half: productHalf[rawStages[s].key] ? "product" : "marketing"
    })
  }

  var signals = []
  var signalRows = m.signals && Array.isArray(m.signals.rows) ? m.signals.rows : []
  for (var g = 0; g < signalRows.length; g++)
    signals.push({ label: str(signalRows[g].label), v: num(signalRows[g].v), sub: str(signalRows[g].sub) })

  // The cockpit's three direction lanes; each contributes its KPI strip.
  var lanes = []
  var directions = m.directions || {}
  var laneOrder = [
    { key: "inbound", title: "Inbound" },
    { key: "awareness", title: "Awareness" },
    { key: "outbound", title: "Outbound" }
  ]
  for (var l = 0; l < laneOrder.length; l++) {
    var lane = directions[laneOrder[l].key]
    if (!lane) continue
    lanes.push({
      key: laneOrder[l].key,
      title: laneOrder[l].title,
      kind: str(lane.kind),
      asOf: str(lane.asOf),
      kpis: parseKpis(lane.kpis)
    })
  }

  return {
    product: str(m.product),
    asOf: str(m.asOf),
    gscAsOf: str(gsc.asOf),
    gscFrom: str(gsc.from),
    kpis: parseKpis(gsc.kpis),
    seriesLabel: str(series.label) || "Impressions",
    series2Label: str(series.label2) || "Clicks",
    impressions: impressions,
    clicks: clicks,
    dates: dates,
    stages: stages,
    signals: signals,
    lanes: lanes
  }
}

function trimZero(v) {
  var s = (Math.round(v * 10) / 10).toFixed(1)
  return s.slice(-2) === ".0" ? s.slice(0, -2) : s
}

// Display rule: thousands collapse to K — one decimal below 10K so the low
// thousands keep some precision (1,845 -> "1.8K"), whole K from 10,000 up
// (12,522 -> "12K") — and millions to one-decimal M; smaller values stay
// exact.
function fmtCompact(n) {
  var v = Number(n)
  if (!isFinite(v)) return "—"
  var abs = Math.abs(v)
  if (abs >= 1e6) return trimZero(v / 1e6) + "M"
  if (abs >= 10000) return String(Math.floor(v / 1000)) + "K"
  if (abs >= 1000) return trimZero(v / 1000) + "K"
  return String(Math.round(v))
}

// 12522 -> "12,522" for places where the exact figure matters (tooltips).
function fmtFull(n) {
  var v = Number(n)
  if (!isFinite(v)) return "—"
  return String(Math.round(v)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// KPI values arrive as strings ("12522", "11.5", "55%", "2,653"); collapse
// the thousands per fmtCompact, pass everything else through untouched.
function fmtKpi(value) {
  var raw = String(value === null || value === undefined ? "—" : value)
  var v = Number(raw.replace(/,/g, ""))
  if (!isFinite(v) || Math.abs(v) < 1000) return raw
  return fmtCompact(v)
}

// KPI values arrive as strings, sometimes comma-grouped ("2,653").
function kpiNumber(model, label) {
  if (!model) return NaN
  for (var i = 0; i < model.kpis.length; i++)
    if (model.kpis[i].label.toLowerCase() === label)
      return Number(String(model.kpis[i].value).replace(/,/g, ""))
  return NaN
}

function barTooltip(id, model) {
  var name = productName(id)
  if (!model) return name + " — no Ignition data yet"
  var parts = []
  for (var i = 0; i < model.kpis.length; i++)
    parts.push(model.kpis[i].label + " " + model.kpis[i].value)
  var when = model.gscAsOf || model.asOf
  return name + " · GSC 28d — " + parts.join(" · ") + (when ? " · as of " + when : "")
}

// Funnel bars span four orders of magnitude (impressions vs paid); sqrt
// keeps the small stages visible without lying about the shape.
function stageRatio(v, max) {
  if (!(max > 0) || !(v > 0)) return 0
  return Math.sqrt(v) / Math.sqrt(max)
}

function maxStage(stages) {
  var max = 0
  if (Array.isArray(stages))
    for (var i = 0; i < stages.length; i++) max = Math.max(max, num(stages[i].v))
  return max
}

if (typeof module !== "undefined") {
  module.exports = {
    PRODUCT_NAMES: PRODUCT_NAMES,
    RS: RS,
    productName: productName,
    parseProducts: parseProducts,
    monitoringUrl: monitoringUrl,
    cockpitUrl: cockpitUrl,
    pollCommand: pollCommand,
    parsePoll: parsePoll,
    parseMonitoring: parseMonitoring,
    fmtCompact: fmtCompact,
    fmtFull: fmtFull,
    fmtKpi: fmtKpi,
    kpiNumber: kpiNumber,
    barTooltip: barTooltip,
    stageRatio: stageRatio,
    maxStage: maxStage
  }
}
