#!/usr/bin/env bash
#
# dietpex OS - single-line installer.
#
# One command to install and trim a lean Ubuntu, replacing the default UI
# with XFCE, handling dual-boot and Windows (WSL2) installs, and creating
# bootable USBs for a full native install.
#
# Run from a checkout:
#   sudo bash install.sh
#   sudo bash install.sh --full
#   sudo bash install.sh --trim-only
#   sudo bash install.sh --dual-boot
#   sudo bash install.sh --windows-wsl
#   sudo bash install.sh --make-usb /dev/sdb
#
# Run as a single line (fetches the latest version first):
#   curl -fsSL https://raw.githubusercontent.com/wippsanrinthailand80-commits/dietpex-os/main/install.sh | sudo bash
#
# Options:
#   --full            Full install: dietpex trim + XFCE UI (+ --purge-gnome)
#   --trim-only       Only run the dietpex trim (services + bloat removal)
#   --ui              Install the XFCE UI only
#   --purge-gnome     With --full/--ui, remove GNOME after installing XFCE
#   --dual-boot       Configure the GRUB dual-boot menu (os-prober)
#   --windows-wsl     Install inside Windows via WSL2
#   --make-usb DEV    Write the Ubuntu ISO to a USB device
#   --thai            Install Thai fonts + locale support (no tofu boxes)
#   --thai-noto       Same as --thai, plus Noto Sans Thai fonts
#   --lang CODE       Force language: en, th (default: auto-detect)
#   -h, --help        Show this help

set -euo pipefail

REPO="https://github.com/wippsanrinthailand80-commits/dietpex-os.git"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------ bootstrap
# When piped from curl, the rest of the project is not present. Fetch the
# repo to a temp dir and re-exec ourselves from there.
if [[ ! -d "$SCRIPT_DIR/config" ]]; then
  echo '[dietpex] fetching dietpex OS sources...'
  tmp="$(mktemp -d)"
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "$REPO" "$tmp/dietpex-os" >/dev/null 2>&1
  else
    curl -fsSL "${REPO%.git}/archive/refs/heads/main.tar.gz" \
      | tar -xz -C "$tmp"
    mv "$tmp/dietpex-os-main" "$tmp/dietpex-os"
  fi
  exec bash "$tmp/dietpex-os/install.sh" "$@"
fi

# shellcheck source=helpers/lib.sh
# shellcheck disable=SC1091 # path is resolved at runtime
source "$SCRIPT_DIR/helpers/lib.sh"

# --------------------------------------------------------------------- options

LANG_CODE="auto"
ACTION=""
DEVICE=""
PURGE_GNOME=0
NOTO=0

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --full)         ACTION=full;;
      --trim-only)    ACTION=trim;;
      --ui)           ACTION=ui;;
      --purge-gnome)  PURGE_GNOME=1;;
      --dual-boot)    ACTION=dualboot;;
      --windows-wsl)  ACTION=windows;;
      --make-usb)     shift; ACTION=usb; DEVICE="$1";;
      --thai)         ACTION=thai;;
      --thai-noto)    ACTION=thai; NOTO=1;;
      --lang)         shift; LANG_CODE="$1";;
      -h|--help)      usage; exit 0;;
      *)              warn "ignoring unknown argument: $1";;
    esac
    shift
  done
}

# ------------------------------------------------------------------ dispatch

run_full() {
  require_root
  info "$(msg trim_started)"
  bash "$SCRIPT_DIR/dietpex.sh" --purge
  ok "$(msg trim_done)"
  bash "$HELPERS_DIR/ui.sh" install --purge-gnome
  run_thai
  info "$(msg complete)"
}

run_trim() {
  require_root
  info "$(msg trim_started)"
  bash "$SCRIPT_DIR/dietpex.sh" --purge
  ok "$(msg trim_done)"
}

run_ui() {
  local args=()
  [[ $PURGE_GNOME -eq 1 ]] && args=(--purge-gnome)
  bash "$HELPERS_DIR/ui.sh" install "${args[@]}"
}

run_dualboot() {
  require_root
  bash "$HELPERS_DIR/dualboot.sh" setup
}

run_windows() {
  bash "$HELPERS_DIR/windows-wsl.sh" install --ui
  run_thai
}

run_thai() {
  require_root
  local args=(install-thai)
  [[ $NOTO -eq 1 ]] && args+=(--noto)
  bash "$HELPERS_DIR/i18n.sh" "${args[@]}"
}

run_usb() {
  [[ -n "$DEVICE" ]] || die "usage: install.sh --make-usb /dev/sdX"
  bash "$HELPERS_DIR/flashdrive.sh" create "$DEVICE"
}

# ---------------------------------------------------------------------- menu

run_menu() {
  local env
  env="$(detect_env)"

  printf '%s\n' "$(msg title) - $(msg os_detected) $(os_pretty)"
  case "$env" in
    wsl)   info "$(msg env_wsl)";;
    live)  info "$(msg env_live)";;
    apt)   info "$(msg env_linux_apt)";;
    *)     die "$(msg os_unsupported)";;
  esac

  while true; do
    printf '\n%s\n' "$(msg menu_title)"
    printf '  %s\n' "$(msg opt_full)"
    printf '  %s\n' "$(msg opt_trim)"
    printf '  %s\n' "$(msg opt_ui)"
    printf '  %s\n' "$(msg opt_dualboot)"
    printf '  %s\n' "$(msg opt_windows)"
    printf '  %s\n' "$(msg opt_usb)"
    printf '  %s\n' "$(msg opt_thai)"
    printf '  %s\n' "$(msg opt_quit)"
    printf '%s' "$(msg enter_choice)"
    read -r choice || exit 0
    case "$choice" in
      1) run_full; return 0;;
      2) run_trim; return 0;;
      3) run_ui; return 0;;
      4) run_dualboot; return 0;;
      5) run_windows; return 0;;
      6) printf '%s' "$(msg usb_confirm_device)"; read -r d; DEVICE="$d"; run_usb; return 0;;
      7) run_thai; return 0;;
      0) return 0;;
      *) warn "$(msg invalid_choice)";;
    esac
  done
}

# --------------------------------------------------------------------- main

main() {
  parse_args "$@"

  if [[ "$LANG_CODE" == "auto" ]]; then
    LANG_CODE="$(auto_lang)"
  fi
  load_lang "$LANG_CODE"

  if [[ -n "$ACTION" ]]; then
    case "$ACTION" in
      full)      run_full;;
      trim)      run_trim;;
      ui)        run_ui;;
      dualboot)  run_dualboot;;
      windows)   run_windows;;
      usb)       run_usb;;
      thai)      run_thai;;
    esac
  else
    run_menu
  fi

  info "$(msg reboot_hint)"
}

main "$@"
