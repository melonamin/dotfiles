#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output=$(timeout 10s qs --no-color -p "$repo_dir/actionrunner-smoke.qml" 2>&1 || true)

if ! grep -Fq 'ACTIONRUNNER_PASS' <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi

printf 'action runner smoke tests passed\n'
