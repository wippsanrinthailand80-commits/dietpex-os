#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
#
# dietpex OS - UI installation helper (XFCE).
#
#   ui.sh install [--purge-gnome]
#
# Installs the lightweight XFCE desktop, sets it as the default graphical
# session, and optionally removes GNOME afterwards.

# shellcheck source=lib.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

XFCE_PACKAGES="xfce4 xfce4-terminal xfce4-goodies lightdm lightdm-gtk-greeter"
GNOME_PACKAGES="ubuntu-desktop gnome-shell gdm3 gnome-session gnome-remote-desktop gnome-online-accounts"

install_xfce() {
  local purge_gnome=0
  [[ "$1" == "--purge-gnome" ]] && purge_gnome=1

  require_root

  info "$(msg installing_xfce)"
  # shellcheck disable=SC2086
  apt_install $XFCE_PACKAGES

  if command -v update-alternatives >/dev/null 2>&1; then
    update-alternatives --set x-session-manager /usr/bin/xfce4-session >/dev/null 2>&1 \
      || warn "could not set xfce4-session as default x-session-manager"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl set-default graphical.target >/dev/null 2>&1 || true
  fi

  if [[ $purge_gnome -eq 1 ]]; then
    info "$(msg purging_gnome)"
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove $GNOME_PACKAGES >/dev/null 2>&1 \
      || warn "could not remove all GNOME packages (some may not be installed)"
    apt-get autoremove -y >/dev/null 2>&1 || true
    info "$(msg gnome_purged)"
  fi

  ok "$(msg xfce_installed)"
  info "$(msg reboot_hint)"
}

install_xfce "$@"
