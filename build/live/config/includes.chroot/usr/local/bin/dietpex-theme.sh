#!/bin/bash
# dietpex-theme.sh - enforce the branded look in the live session.
#
# The XFCE defaults shipped in /etc/xdg usually suffice, but the wallpaper
# property path includes the monitor name (monitor0, monitorHDMI-1, ...) which
# varies. Walk every existing backdrop property and set the image explicitly
# once the desktop is up.

set -uo pipefail

export DISPLAY="${DISPLAY:-:0}"
WALL=/usr/share/backgrounds/dietpex-os-wallpaper.png

sleep 6

for _ in $(seq 1 15); do
  PROPS=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/backdrop/' || true)
  if [[ -z "$PROPS" ]]; then
    sleep 2
    continue
  fi
  while IFS= read -r p; do
    case "$p" in
      */last-image)  xfconf-query -c xfce4-desktop -p "$p" -s "$WALL" 2>/dev/null || true ;;
      */image-style) xfconf-query -c xfce4-desktop -p "$p" -s 5 2>/dev/null || true ;;
      */image-show)  xfconf-query -c xfce4-desktop -p "$p" -s true 2>/dev/null || true ;;
    esac
  done <<< "$PROPS"
  break
done
