#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
set -euo pipefail
#
# dietpex OS - dual-boot helper.
#
#   dualboot.sh setup
#
# Enables os-prober and regenerates the GRUB menu so that all operating
# systems installed on the machine appear in the boot menu (a "choose your
# OS" screen at startup). Run this inside the installed Ubuntu system.
#
# For a full second-OS install (the "yes" path of the installer), boot the
# machine from a dietpex bootable USB and choose "Install Ubuntu alongside".

# shellcheck source=lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

GRUB_DEFAULT="/etc/default/grub"

setup_dualboot() {
  require_root

  info "$(msg dualboot_start)"
  apt_install os-prober

  if [[ -f "$GRUB_DEFAULT" ]]; then
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_DEFAULT"
    grep -q '^GRUB_DISABLE_OS_PROBER' "$GRUB_DEFAULT" \
      || echo 'GRUB_DISABLE_OS_PROBER=false' >> "$GRUB_DEFAULT"
  else
    echo 'GRUB_DISABLE_OS_PROBER=false' > "$GRUB_DEFAULT"
  fi

  if command -v os-prober >/dev/null 2>&1; then
    os-prober >/dev/null 2>&1 || true
  fi

  if command -v update-grub >/dev/null 2>&1; then
    update-grub || die "update-grub failed"
  else
    grub-mkconfig -o /boot/grub/grub.cfg || die "grub-mkconfig failed"
  fi

  ok "$(msg dualboot_done)"
  info "$(msg reboot_hint)"
}

setup_dualboot "$@"
