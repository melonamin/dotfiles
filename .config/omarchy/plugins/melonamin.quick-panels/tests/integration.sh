#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

node --test tests/model.test.js
qmllint Main.qml EdgeDock.qml DockItem.qml Model.js
omarchy plugin validate .

git diff --check

echo "Quick Panels validation passed"
