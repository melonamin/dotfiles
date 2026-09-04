#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: ./bootstrap.sh --check | --apply

  --check  Report what differs without changing the machine.
  --apply  Install and reconcile the desktop workstation configuration.
USAGE
}

case "${1:-}" in
  --check) mode=check ;;
  --apply) mode=apply ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

export DOTFILES_ROOT="$ROOT"
export BOOTSTRAP_MODE="$mode"
export BOOTSTRAP_RUN_ID="$(date +%Y%m%d%H%M%S)"

steps=(
  packages
  dotfiles
  tools
  applications
  repositories
  plugins
  themes
  defaults
  validate
)

for step in "${steps[@]}"; do
  printf '\n\033[1;36m==> %s\033[0m\n' "$step"
  bash "$ROOT/bootstrap/steps/$step.sh"
done

if [[ $mode == apply ]]; then
  printf '\n\033[1;32mBootstrap complete.\033[0m\n'
else
  printf '\nCheck complete. Re-run with --apply to reconcile this machine.\n'
fi

printf 'Manual sign-ins and intentionally excluded items: %s\n' \
  "$ROOT/bootstrap/MANUAL.md"
