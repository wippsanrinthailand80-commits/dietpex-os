#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
set -euo pipefail
#
# dietpex OS - Windows (WSL2) install helper.
#
#   windows-wsl.sh install [--ui]
#
# Installs a trimmed Ubuntu inside Windows Subsystem for Linux. This is the
# "no dual-boot" path: you get a real Ubuntu that runs on Windows without
# touching your partitions. With --ui it also installs the XFCE desktop,
# which renders through WSLg on Windows 11.

# shellcheck source=lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

install_in_wsl() {
  local install_ui=0
  [[ "$1" == "--ui" ]] && install_ui=1

  info "$(msg wsl_start)"

  if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    warn "not running under WSL - continuing anyway"
  fi

  require_root

  # Trim the base system first (reuses the dietpex core).
  bash "$ROOT_DIR/dietpex.sh" --purge || warn "dietpex trim reported errors"

  if [[ $install_ui -eq 1 ]]; then
    bash "$HELPERS_DIR/ui.sh" install
    info "$(msg wsl_gui_hint)"
  fi

  ok "$(msg wsl_done)"
}

install_in_wsl "$@"
