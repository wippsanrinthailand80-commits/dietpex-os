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

# block_size_bytes <device> - size of a block device in bytes.
block_size_bytes() {
  if command -v blockdev >/dev/null 2>&1; then
    blockdev --getsize64 "$1" 2>/dev/null
  else
    local name="${1#/dev/}"
    [[ -r "/sys/class/block/$name/size" ]] \
      && echo "$(( $(< "/sys/class/block/$name/size") * 512 ))"
  fi
}

# iso_size_bytes <path-or-url> - size of the ISO before download/write.
iso_size_bytes() {
  local src="$1"
  if [[ "$src" =~ ^https?:// ]]; then
    curl -fsSI --max-time 30 "$src" 2>/dev/null \
      | tr -d '\r' | awk -F': ' 'tolower($1)=="content-length"{print $2}' | tail -1
  elif [[ -f "$src" ]]; then
    stat -c%s "$src"
  fi
}

# device_is_in_use <device> - true if the device is the root disk or has any
# mounted partition (writing to it would destroy a live system).
device_is_in_use() {
  local dev="$1"
  local root_dev src
  root_dev="$(findmnt -no SOURCE / 2>/dev/null || echo "")"
  if [[ -n "$root_dev" ]] && [[ "$root_dev" == "$dev"* ]]; then
    return 0
  fi
  while IFS= read -r src; do
    [[ "$src" == "$dev"* ]] && return 0
  done < <(findmnt -rn -o SOURCE 2>/dev/null)
  return 1
}

create_bootable_usb() {
  require_root

  local device="${1:?usage: flashdrive.sh create <device> [--iso <path-or-url>]}"
  shift
  local iso="" iso_path="" iso_size dev_size tmp_iso=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso) shift || die "usage: flashdrive.sh create <device> --iso <path-or-url>"; iso="${1:-}"; [[ -n "$iso" ]] || die "usage: flashdrive.sh create <device> --iso <path-or-url>";;
      *) warn "ignoring unknown argument: $1";;
    esac
    shift || break
  done

  if [[ -z "$iso" ]]; then
    iso="$(resolve_iso_url)"
    info "using ISO: $iso"
  fi

  need_cmd dd
  need_cmd curl
  need_cmd findmnt

  [[ -b "$device" ]] || die "not a block device: $device"
  if device_is_in_use "$device"; then
    die "refusing to write $device: it looks like a mounted/system disk"
  fi

  iso_size="$(iso_size_bytes "$iso")"
  dev_size="$(block_size_bytes "$device")"
  if [[ -n "$iso_size" && -n "$dev_size" && "$iso_size" -gt "$dev_size" ]]; then
    die "ISO is larger than $device (ISO ${iso_size} B vs device ${dev_size} B)"
  fi

  read -r -p "$(msg usb_confirm)" answer || die "aborted by user"
  [[ "$answer" == "YES" ]] || die "aborted by user"

  if [[ "$iso" =~ ^https?:// ]]; then
    tmp_iso="$(mktemp /tmp/dietpex-iso.XXXXXX)"
    trap '[[ -n "$tmp_iso" ]] && rm -f "$tmp_iso"' EXIT
    info "downloading $iso"
    curl -fL --progress-bar "$iso" -o "$tmp_iso" || die "download failed"
    iso_path="$tmp_iso"
  else
    [[ -f "$iso" ]] || die "ISO not found: $iso"
    iso_path="$iso"
  fi

  info "$(msg usb_start)"
  sync
  dd if="$iso_path" of="$device" bs=4M status=progress conv=fsync
  sync

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
