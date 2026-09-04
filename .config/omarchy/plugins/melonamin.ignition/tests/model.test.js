const test = require("node:test")
const assert = require("node:assert")
const Model = require("../Model.js")

// Trimmed from a real ignition.spot.t1a.dev lakesentry export (2026-08-18);
// same field layout, shorter lists.
const LAKESENTRY_EXPORT = {
  product: "lakesentry",
  asOf: "2026-08-16",
  funnel: {
    asOf: "2026-08-16",
    windowDays: 28,
    stages: [
      { key: "impressions", label: "Impressions", v: 8626, kind: "manual", sub: "June 2026" },
      { key: "visitors", label: "Website visitors", v: 127, kind: "feed", sub: null },
      { key: "intent", label: "Start Free clicks", v: 16, kind: "feed", sub: null },
      { key: "registered", label: "Registered", v: 1, kind: "manual", sub: null },
      { key: "paid", label: "Paid", v: 0, kind: "manual", sub: null }
    ],
    halves: {
      marketing: ["impressions", "visitors", "intent"],
      product: ["registered", "paid"]
    }
  },
  gsc: {
    kind: "feed",
    asOf: "2026-08-15",
    from: "2026-07-21",
    kpis: [
      { label: "Impressions", value: "12522" },
      { label: "Clicks", value: "85" },
      { label: "Avg position", value: "11.5" }
    ],
    series: {
      label: "Impressions",
      label2: "Clicks",
      points: [
        { date: "2026-07-21", v: 465, v2: 3 },
        { date: "2026-07-22", v: 512, v2: 5 },
        { date: "2026-07-23", v: 388, v2: 2 }
      ]
    }
  },
  signals: {
    kind: "feed",
    asOf: "2026-08-16",
    rows: [
      { label: "Sign-ins", v: 9, sub: "returning-user signal" }
    ]
  },
  directions: {
    inbound: {
      kind: "feed",
      asOf: "2026-08-16",
      kpis: [{ label: "Sessions", value: "238", sub: "consented · prod only · 48d" }]
    },
    awareness: {
      kind: "manual",
      asOf: "2026-07-20",
      kpis: [{ label: "LinkedIn impressions / mo", value: "2,653", sub: "June" }]
    },
    outbound: {
      kind: "manual",
      asOf: "2026-07-22",
      kpis: [{ label: "Accounts targeted", value: "228", sub: "DAIS 2026" }]
    }
  }
}

const SECONDSTACK_EXPORT = {
  product: "secondstack",
  asOf: "2026-08-16",
  gsc: {
    asOf: "2026-08-15",
    from: "2026-07-21",
    kpis: [
      { label: "Impressions", value: "375" },
      { label: "Clicks", value: "11" }
    ],
    series: { label: "Impressions", label2: "Clicks", points: [] }
  }
}

const IDS = ["lakesentry", "secondstack"]

function pollRaw(records) {
  return records.map(r => (typeof r === "string" ? r : JSON.stringify(r, null, 2)) + Model.RS).join("")
}

test("parseProducts: trims, lowercases, dedupes", () => {
  assert.deepStrictEqual(
    Model.parseProducts(" LakeSentry, secondstack ,, lakesentry "),
    ["lakesentry", "secondstack"]
  )
  assert.deepStrictEqual(Model.parseProducts(""), [])
})

test("urls: monitoring export and cockpit hash route", () => {
  assert.strictEqual(
    Model.monitoringUrl("https://ignition.spot.t1a.dev/", "lakesentry"),
    "https://ignition.spot.t1a.dev/products/lakesentry/exports/monitoring.json"
  )
  assert.strictEqual(
    Model.cockpitUrl("https://ignition.spot.t1a.dev", "lakesentry"),
    "https://ignition.spot.t1a.dev/#/lakesentry/monitoring"
  )
})

test("pollCommand: one URL per product, record separator write-out", () => {
  const cmd = Model.pollCommand("https://ignition.spot.t1a.dev", IDS)
  assert.strictEqual(cmd[0], "curl")
  assert.ok(cmd.includes("-w") && cmd.includes(Model.RS))
  assert.strictEqual(cmd.filter(a => a.endsWith("monitoring.json")).length, 2)
})

test("parsePoll: both products parse and stay aligned", () => {
  const result = Model.parsePoll(pollRaw([LAKESENTRY_EXPORT, SECONDSTACK_EXPORT]), IDS)
  assert.ok(result)
  assert.strictEqual(result.lakesentry.product, "lakesentry")
  assert.strictEqual(result.secondstack.product, "secondstack")
})

test("parsePoll: a failed transfer leaves an empty record, not misalignment", () => {
  const result = Model.parsePoll(pollRaw(["", SECONDSTACK_EXPORT]), IDS)
  assert.ok(result)
  assert.strictEqual(result.lakesentry, null)
  assert.strictEqual(result.secondstack.product, "secondstack")
})

test("parsePoll: garbage in every record means unreachable", () => {
  assert.strictEqual(Model.parsePoll("<html>502</html>", IDS), null)
  assert.strictEqual(Model.parsePoll("", IDS), null)
})

test("parseMonitoring: full lakesentry shape", () => {
  const m = Model.parseMonitoring(LAKESENTRY_EXPORT)
  assert.strictEqual(m.asOf, "2026-08-16")
  assert.strictEqual(m.gscAsOf, "2026-08-15")
  assert.strictEqual(m.kpis.length, 3)
  assert.deepStrictEqual(m.impressions, [465, 512, 388])
  assert.deepStrictEqual(m.clicks, [3, 5, 2])
  assert.strictEqual(m.stages.length, 5)
  assert.strictEqual(m.stages[0].half, "marketing")
  assert.strictEqual(m.stages[3].half, "product")
  assert.strictEqual(m.stages[0].sub, "June 2026")
  assert.strictEqual(m.stages[1].sub, "")
  assert.strictEqual(m.signals.length, 1)
  assert.strictEqual(m.lanes.length, 3)
  assert.strictEqual(m.lanes[1].kind, "manual")
  assert.strictEqual(m.lanes[0].kpis[0].value, "238")
})

test("parseMonitoring: sparse export still yields a model", () => {
  const m = Model.parseMonitoring(SECONDSTACK_EXPORT)
  assert.strictEqual(m.product, "secondstack")
  assert.deepStrictEqual(m.stages, [])
  assert.deepStrictEqual(m.signals, [])
  assert.deepStrictEqual(m.lanes, [])
  assert.strictEqual(m.kpis[0].value, "375")
})

test("parseMonitoring: rejects non-export payloads", () => {
  assert.strictEqual(Model.parseMonitoring(null), null)
  assert.strictEqual(Model.parseMonitoring({}), null)
  assert.strictEqual(Model.parseMonitoring({ hello: "world" }), null)
})

test("fmtCompact: every thousand collapses to K, decimal only below 10K", () => {
  assert.strictEqual(Model.fmtCompact(85), "85")
  assert.strictEqual(Model.fmtCompact(999), "999")
  assert.strictEqual(Model.fmtCompact(1000), "1K")
  assert.strictEqual(Model.fmtCompact(1845), "1.8K")
  assert.strictEqual(Model.fmtCompact(10000), "10K")
  assert.strictEqual(Model.fmtCompact(11400), "11K")
  assert.strictEqual(Model.fmtCompact(12522), "12K")
  assert.strictEqual(Model.fmtCompact(2400000), "2.4M")
  assert.strictEqual(Model.fmtFull(12522), "12,522")
})

test("fmtKpi: collapses numeric thousands, passes the rest through", () => {
  assert.strictEqual(Model.fmtKpi("12522"), "12K")
  assert.strictEqual(Model.fmtKpi("18,712"), "18K")
  assert.strictEqual(Model.fmtKpi("2,653"), "2.7K")
  assert.strictEqual(Model.fmtKpi("238"), "238")
  assert.strictEqual(Model.fmtKpi("11.5"), "11.5")
  assert.strictEqual(Model.fmtKpi("55%"), "55%")
  assert.strictEqual(Model.fmtKpi("—"), "—")
  assert.strictEqual(Model.fmtKpi(null), "—")
})

test("barTooltip", () => {
  const m = Model.parseMonitoring(LAKESENTRY_EXPORT)
  const tip = Model.barTooltip("lakesentry", m)
  assert.ok(tip.startsWith("LakeSentry · GSC 28d — Impressions 12522"))
  assert.ok(tip.endsWith("as of 2026-08-15"))
  assert.strictEqual(Model.barTooltip("lakesentry", null), "LakeSentry — no Ignition data yet")
})

test("kpiNumber: strips comma grouping", () => {
  const m = Model.parseMonitoring(LAKESENTRY_EXPORT)
  assert.strictEqual(Model.kpiNumber(m, "impressions"), 12522)
  assert.ok(Number.isNaN(Model.kpiNumber(m, "nope")))
})

test("stageRatio / maxStage: sqrt scale keeps small stages visible", () => {
  const m = Model.parseMonitoring(LAKESENTRY_EXPORT)
  const max = Model.maxStage(m.stages)
  assert.strictEqual(max, 8626)
  assert.strictEqual(Model.stageRatio(8626, max), 1)
  assert.strictEqual(Model.stageRatio(0, max), 0)
  const small = Model.stageRatio(1, max)
  assert.ok(small > 0.005, "1-unit stage should still paint: " + small)
})

test("productName: known map plus fallback capitalization", () => {
  assert.strictEqual(Model.productName("lakesentry"), "LakeSentry")
  assert.strictEqual(Model.productName("newthing"), "Newthing")
  assert.strictEqual(Model.productName(""), "")
})
