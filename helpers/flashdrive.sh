#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
set -euo pipefail
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
#   bash helpers/flashdrive.sh resolve   # print the ISO URL that would be used

# shellcheck source=lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# Fallback only: the current 24.04 desktop ISO is resolved from the Ubuntu
# releases index at run time, so this never goes stale.
DEFAULT_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso"

# resolve_iso_url - print the latest ubuntu-24.04 desktop ISO URL, or the
# fallback if the index cannot be reached.
resolve_iso_url() {
  local base="https://releases.ubuntu.com/24.04"
  local latest
  latest="$(curl -fsSL --max-time 20 "$base/" 2>/dev/null \
    | grep -oE 'ubuntu-24\.04\.[0-9]+-desktop-amd64\.iso' | sort -uV | tail -1 || true)"
  if [[ -n "$latest" ]]; then
    echo "$base/$latest"
  else
    echo "$DEFAULT_ISO_URL"
  fi
}

create_bootable_usb() {
  require_root

  local device="${1:?usage: flashdrive.sh create <device> [--iso <path-or-url>]}"
  shift
  local iso="" iso_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso) shift; iso="$1";;
      *) warn "ignoring unknown argument: $1";;
    esac
    shift
  done

  if [[ -z "$iso" ]]; then
    iso="$(resolve_iso_url)"
    info "using ISO: $iso"
  fi

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

  read -r -p "$(msg usb_confirm)" answer || die "aborted by user"
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

if [[ "${1:-}" == "resolve" ]]; then
  resolve_iso_url
  exit 0
fi
if [[ "${1:-}" == "create" ]]; then
  shift
fi

create_bootable_usb "$@"
