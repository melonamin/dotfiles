#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

mkdir -p "$test_dir/example.radial" "$test_dir/invalid.traversal" "$test_dir/unsafe.link"

cat >"$test_dir/example.radial/manifest.json" <<'JSON'
{
  "apiVersion": 1,
  "id": "example.radial",
  "name": "Radial",
  "entryPoint": "Radial.qml",
  "capabilities": ["compact"]
}
JSON
printf 'import QtQuick\nItem {}\n' >"$test_dir/example.radial/Radial.qml"

cat >"$test_dir/invalid.traversal/manifest.json" <<'JSON'
{
  "apiVersion": 1,
  "id": "invalid.traversal",
  "name": "Traversal",
  "entryPoint": "../example.radial/Radial.qml"
}
JSON

cat >"$test_dir/unsafe.link/manifest.json" <<'JSON'
{
  "apiVersion": 1,
  "id": "unsafe.link",
  "name": "Symlinked",
  "entryPoint": "Interface.qml"
}
JSON
ln -s "$test_dir/example.radial/Radial.qml" "$test_dir/unsafe.link/Interface.qml"

result=$("$repo_dir/scripts/list-renderers" "$test_dir")
jq -e '
  length == 1 and
  .[0].id == "example.radial" and
  .[0].apiVersion == 1 and
  .[0].capabilities == ["compact"] and
  (.[0].source | endswith("/example.radial/Radial.qml"))
' <<<"$result" >/dev/null

printf 'renderer discovery tests passed\n'
