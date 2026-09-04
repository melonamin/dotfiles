# Ignition: G2M Analytics

Omarchy shell bar widget for [Ignition — Launch Control](https://ignition.spot.t1a.dev/),
the go-to-market cockpit for the g2m products (LakeSentry, SecondStack,
Antares, PondPilot).

The bar shows a rocket; hovering it reveals the bar product's GSC 28-day
headline. The panel shows, per product:

- **Search · 28 days** — GSC KPIs (impressions, clicks, avg position) and a
  dual sparkline (impressions area, clicks line, each on its own scale)
- **Funnel · 28 days** — marketing → product stages with sqrt-scaled bars
  (manual figures dimmed), split at the activation gate
- **Signals** — returning-user and CTA signals
- **Directions** — headline KPI per lane (inbound / awareness / outbound)

Thousands collapse to K — one decimal below 10K (1,845 → 1.8K), whole K
from 10,000 up (12,522 → 12K) — and millions to one-decimal M; smaller
values stay exact.

## Data source

The same static JSON exports the site's Monitoring cockpit fetches,
regenerated daily:

```
<baseUrl>/products/<id>/exports/monitoring.json
```

One batched curl per refresh (on panel open plus every 30 minutes); a failed
product keeps its last good numbers.

## Controls

- **Left click** — toggle the panel
- **Right click** — open the cockpit in the browser
- **Middle click** — refresh now
- Panel: click a product pill, or arrows / `1`–`4` to switch products,
  `r` to refresh, `Enter` to open the cockpit

## Settings

| Key | Default | Meaning |
|-----|---------|---------|
| `baseUrl` | `https://ignition.spot.t1a.dev` | Ignition site root |
| `products` | `lakesentry,secondstack,antares,pondpilot` | Product ids to fetch |
| `barProduct` | `lakesentry` | Product behind the bar tooltip |

```bash
omarchy bar set melonamin.ignition barProduct pondpilot
```

## Tests

```bash
node --test tests/model.test.js   # unit: parsing, formatting, URLs
tests/integration.sh              # live: fetch + parse all product exports
```

End-to-end: with the shell running, `omarchy-shell melonamin.ignition toggle`
opens the panel from the mounted bar widget.
