#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
#
# dietpex OS - bootable USB helper.
#
#   flashdrive.sh create <device> [--iso <path-or-url>]
#
# Writes an Ubuntu ISO to a USB device so the machine can boot into a real
# Linux UI for a full installation ("flash drive" path).
#
# Examples:
#   sudo bash helpers/flashdrive.sh create /dev/sdb
#   sudo bash helpers/flashdrive.sh create /dev/sdb --iso ./ubuntu-24.04.iso

# shellcheck source=lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Default to the latest Ubuntu LTS desktop ISO. Update this URL as releases
# change, or pass --iso to use your own.
DEFAULT_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.2-desktop-amd64.iso"

create_bootable_usb() {
  require_root

  local device="${1:?usage: flashdrive.sh create <device> [--iso <path-or-url>]}"
  shift
  local iso="$DEFAULT_ISO_URL"
  local iso_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso) shift; iso="$1";;
      *) warn "ignoring unknown argument: $1";;
    esac
    shift
  done

  need_cmd dd
  need_cmd curl

  [[ -b "$device" ]] || die "not a block device: $device"

  if [[ "$iso" =~ ^https?:// ]]; then
    iso_path="$(mktemp /tmp/dietpex-iso.XXXXXX)"
    info "downloading $iso"
    curl -fL --progress-bar "$iso" -o "$iso_path" || die "download failed"
  else
    iso_path="$iso"
  fi
  [[ -f "$iso_path" ]] || die "ISO not found: $iso_path"

  read -r -p "$(msg usb_confirm)" answer
  [[ "$answer" == "YES" ]] || die "aborted by user"

  info "$(msg usb_start)"
  sync
  dd if="$iso_path" of="$device" bs=4M status=progress conv=fsync
  sync

  if [[ "$iso_path" != "$iso" ]]; then
    rm -f "$iso_path"
  fi

  ok "$(msg usb_done)"
  info "boot the machine from this USB to install dietpex OS."
}

create_bootable_usb "$@"
