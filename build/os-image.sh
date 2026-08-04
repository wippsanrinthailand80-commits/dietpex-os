#!/usr/bin/env bash
#
# dietpex OS - build a real, bootable Ubuntu-based live ISO.
#
# Uses live-build to produce a hybrid ISO with:
#   - XFCE desktop (LightDM, autologin to the 'dietpex' user)
#   - Full Thai support (fonts + fontconfig vowel fix + th_TH locale)
#   - The dietpex service trim applied at build time
#
# Output: dietpex-os.iso (in the repo root)
#
# Usage:
#   sudo bash build/os-image.sh

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
WORK_DIR="${WORK_DIR:-/tmp/dietpex-build}"
OUT_ISO="${OUT_ISO:-$ROOT_DIR/dietpex-os.iso}"

info() { printf '[build] %s\n' "$*"; }
die() { printf '[build] ERROR: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root"

command -v lb >/dev/null 2>&1 || { info "installing live-build..."; apt-get update -qq; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq live-build syslinux-utils >/dev/null; }
command -v lb >/dev/null 2>&1 || die "live-build (lb) not available"
command -v isohybrid >/dev/null 2>&1 || { info "installing isohybrid..."; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq syslinux-utils >/dev/null; }
command -v isohybrid >/dev/null 2>&1 || die "isohybrid not available (syslinux-utils)"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -a "$BUILD_DIR/live/." "$WORK_DIR/"

cd "$WORK_DIR"

info "configuring live-build"
lb config \
  --distribution noble \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --mode ubuntu \
  --archive-areas "main restricted universe multiverse" \
  --bootappend-live "boot=live config quiet splash" \
  --linux-flavours generic \
  --initramfs live-boot \
  --initsystem systemd \
  --iso-volume "dietpex OS 24.04" \
  --debian-installer false \
  --bootloader syslinux \
  --syslinux-theme live-build

info "building ISO (this downloads packages and may take a while)"
lb build 2>&1 | tee "$WORK_DIR/build.log" || die "lb build failed (see $WORK_DIR/build.log)"

iso="$(find "$WORK_DIR" -maxdepth 1 -name '*.iso' | head -1)"
[[ -n "$iso" ]] || die "no ISO produced"

cp "$iso" "$OUT_ISO"
info "ISO built: $OUT_ISO ($(du -h "$OUT_ISO" | cut -f1))"
