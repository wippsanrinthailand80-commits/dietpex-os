#!/usr/bin/env bash
#
# dietpex OS - boot the built ISO in QEMU/KVM and capture real desktop
# screenshots (BIOS -> GRUB -> kernel -> LightDM -> XFCE desktop).
#
# Usage:
#   sudo bash tests/os-boot-screenshot.sh [path-to-iso] [output-dir]
#
# Requires: qemu-system-x86, socat, imagemagick (installed on demand).
#
# Screenshots are captured with the QEMU monitor 'screendump' command, which
# reads the VM framebuffer - no VNC viewer needed.

set -euo pipefail

ISO="${1:-/tmp/dietpex-build/live-image-amd64.hybrid.iso}"
OUT_DIR="${2:-tests/screenshots-os}"
WORK="${WORK_DIR:-/tmp/dietpex-vm}"

info() { printf '[vm] %s\n' "$*"; }
die() { printf '[vm] ERROR: %s\n' "$*" >&2; exit 1; }

if [[ ! -f "$ISO" ]]; then
  echo "[vm] ISO check failed. Directory listing of $(dirname "$ISO"):" >&2
  find "$(dirname "$ISO")" -maxdepth 1 -printf '%M %s %p\n' 2>&1 | head -20
  echo "[vm] df:" >&2
  df -h "$(dirname "$ISO")" 2>&1 | tail -3
  die "ISO not found: $ISO"
fi
[[ $EUID -eq 0 ]] || die "must run as root"

for cmd in qemu-system-x86_64 socat convert; do
  command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done

mkdir -p "$OUT_DIR" "$WORK"
rm -f "$WORK"/screen-*.ppm "$WORK"/screen-*.png

# KVM acceleration is available on GitHub-hosted runners; fall back to TCG
# (software emulation, slower) if /dev/kvm is missing.
ACCEL=()
if [[ -e /dev/kvm ]]; then
  ACCEL=(-enable-kvm)
  info "KVM acceleration available"
else
  ACCEL=(-accel tcg -accel thread=multi)
  info "no /dev/kvm - using TCG software emulation (slower)"
fi

# Boot the live ISO. Autologin drops us straight into the XFCE desktop where
# the Thai demo terminal starts via XDG autostart.
rm -f "$WORK/qemu-monitor.sock" "$WORK/serial.log"
qemu-system-x86_64 "${ACCEL[@]}" \
  -machine q35,accel=kvm:tcg \
  -cpu max \
  -m 2048 \
  -smp 2 \
  -cdrom "$ISO" \
  -boot d \
  -vga std \
  -display vnc=:99 \
  -monitor "unix:$WORK/qemu-monitor.sock,server,nowait" \
  -serial "file:$WORK/serial.log" \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -rtc base=localtime \
  -no-reboot \
  -daemonize \
  -pidfile "$WORK/qemu.pid" || die "qemu failed to start"

info "VM started (pid $(cat "$WORK/qemu.pid"))"

# screendump <label> - capture the current VM framebuffer to a PNG.
screendump() {
  local label="$1"
  echo "screendump $WORK/screen-$label.ppm" | socat - "UNIX-CONNECT:$WORK/qemu-monitor.sock" >/dev/null 2>&1 || return 1
  if [[ -s "$WORK/screen-$label.ppm" ]]; then
    convert "$WORK/screen-$label.ppm" "$OUT_DIR/screen-$label.png" 2>/dev/null || return 1
    info "captured screen-$label.png ($(du -h "$OUT_DIR/screen-$label.png" | cut -f1))"
    rm -f "$WORK/screen-$label.ppm"
  fi
}

# Boot sequence timings (KVM). TCG is ~4x slower, so scale the wait.
SECONDS_STEP=20
MAX_WAIT=$(( 6 * 60 ))
if [[ ! -e /dev/kvm ]]; then MAX_WAIT=$(( 18 * 60 )); fi

elapsed=0
taken=0
while [[ $elapsed -lt $MAX_WAIT ]]; do
  label="$(printf '%02d' "$taken")"
  screendump "$label" && taken=$(( taken + 1 ))
  sleep "$SECONDS_STEP"
  elapsed=$(( elapsed + SECONDS_STEP ))

  # Stop early once the live system has fully booted (serial reaches login/
  # X display manager or desktop target).
  if grep -qE 'Reached target Graphical Interface|GDM|LightDM|dietpex-os login:' "$WORK/serial.log" 2>/dev/null; then
    info "graphical target reached at ${elapsed}s - capturing desktop"
    sleep 10
    screendump "desktop" && taken=$(( taken + 1 ))
    # Give the Thai demo terminal a moment, then capture the final desktop.
    sleep 10
    screendump "desktop-final" && taken=$(( taken + 1 ))
    break
  fi
done

# Always capture a final frame even if detection timed out.
screendump "final" && taken=$(( taken + 1 ))

info "shutting down VM"
if [[ -S "$WORK/qemu-monitor.sock" ]]; then
  echo "quit" | socat - "UNIX-CONNECT:$WORK/qemu-monitor.sock" >/dev/null 2>&1 || true
fi
sleep 2
if [[ -f "$WORK/qemu.pid" ]]; then kill "$(cat "$WORK/qemu.pid")" 2>/dev/null || true; fi

echo
info "============================================="
info " Screenshots captured: $taken"
info "============================================="
find "$OUT_DIR" -name '*.png' | sort | while read -r f; do
  info "  $(basename "$f")  ($(du -h "$f" | cut -f1))"
done
