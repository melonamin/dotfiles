#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/bootstrap/lib.sh"

require_command pacman
require_command omarchy

install_ioq3_bin() {
  local build_dir result

  build_dir="$(mktemp -d /tmp/omarchy-ioq3-bin.XXXXXX)"
  git clone --quiet https://aur.archlinux.org/ioq3-bin.git "$build_dir"

  # The current AUR recipe names the obsolete libjpeg package even though the
  # binary works with Arch's libjpeg-turbo (as does the source workstation).
  if grep -q "'libjpeg'" "$build_dir/PKGBUILD"; then
    patch -d "$build_dir" -p1 < "$BOOTSTRAP_DIR/patches/ioq3-bin-libjpeg-turbo.patch"
  fi

  (
    cd "$build_dir"
    makepkg --syncdeps --install --noconfirm
  )
  result=$?

  if [[ $build_dir == /tmp/omarchy-ioq3-bin.* ]]; then
    rm -rf -- "$build_dir"
  fi
  return "$result"
}

install_manifest() {
  local label="$1" manifest="$2" installer="$3" package
  local missing=()

  while IFS= read -r package; do
    pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
  done < <(manifest_lines "$manifest")

  if (( ${#missing[@]} == 0 )); then
    note "ok: $label packages"
  elif ! is_apply; then
    note "missing $label (${#missing[@]}): ${missing[*]}"
  else
    note "installing $label (${#missing[@]}): ${missing[*]}"
    if [[ $installer == arch ]]; then
      omarchy pkg add "${missing[@]}"
    else
      local filtered=()
      for package in "${missing[@]}"; do
        if [[ $package == ioq3-bin ]]; then
          install_ioq3_bin
        else
          filtered+=("$package")
        fi
      done
      if (( ${#filtered[@]} > 0 )); then
        CMAKE_POLICY_VERSION_MINIMUM=3.5 omarchy pkg aur add "${filtered[@]}"
      fi
    fi
  fi
}

install_manifest "repository" "$BOOTSTRAP_DIR/packages-arch.txt" arch
install_manifest "AUR" "$BOOTSTRAP_DIR/packages-aur.txt" aur
