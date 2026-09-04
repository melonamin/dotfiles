#!/usr/bin/env bash
# Read-only integration test: run the plugin's real poll command against the
# live Ignition site and check Model.parsePoll understands every product's
# export. Network access required; changes nothing anywhere.
#
# Usage: tests/integration.sh [base-url]
set -euo pipefail

BASE_URL="${1:-https://ignition.spot.t1a.dev}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export DIR

node - "$BASE_URL" <<'EOF'
const { execFileSync } = require("node:child_process")
const assert = require("node:assert")
const Model = require(process.env.DIR + "/Model.js")

const baseUrl = process.argv[2]
const ids = Model.parseProducts("lakesentry,secondstack,antares,pondpilot")
const cmd = Model.pollCommand(baseUrl, ids)
const raw = execFileSync(cmd[0], cmd.slice(1), { encoding: "utf8", timeout: 30000, maxBuffer: 16 * 1024 * 1024 })

const result = Model.parsePoll(raw, ids)
assert.ok(result, "parsePoll returned null for a live response")

for (const id of ids) {
  const m = result[id]
  assert.ok(m, id + ": export did not parse")
  assert.strictEqual(m.product, id, id + ": product mismatch")
  assert.ok(m.asOf, id + ": missing asOf")
  assert.ok(m.kpis.length > 0, id + ": no GSC KPIs")
  const kpis = m.kpis.map(k => k.label + " " + Model.fmtKpi(k.value)).join(" · ")
  console.log("ok — " + Model.productName(id) + ": " + kpis
    + " · " + m.stages.length + " funnel stages · " + m.impressions.length + " series points"
    + " · as of " + m.asOf)
}
EOF
