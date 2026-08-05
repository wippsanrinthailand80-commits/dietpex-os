#!/bin/bash
# dietpex-apps-test.sh - drives the live desktop through a real app test.
#
# Runs via XDG autostart in the autologged-in live session and:
#   1. opens Firefox -> Google (Thai UI)
#   2. switches to the Thai (Kedmanee) keyboard layout and types Thai text
#   3. runs the search so the results page renders Thai
#   4. opens Thunar (file manager), Mousepad (editor) and a terminal
#
# The host VM script screenshots the desktop on a fixed cadence while this
# script runs, so every phase ends up in the artifact. Progress is mirrored
# to the serial console so the host's serial.log shows what happened.

set -uo pipefail

export DISPLAY="${DISPLAY:-:0}"

LOG=/home/dietpex/dietpex-apps-test.log
echo "dietpex-apps-test started at $(date)" > "$LOG" 2>/dev/null || true

log() {
  local msg="$*"
  echo "[$(date +%T)] $msg" >> "$LOG" 2>/dev/null || true
  echo "[apps-test] $msg" > /dev/ttyS0 2>/dev/null || true
}

log "waiting for the XFCE panel"
for _ in $(seq 1 30); do
  if xdotool search --onlyvisible --class Xfce4-panel >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
sleep 5
log "desktop ready"

setxkbmap us 2>/dev/null || true
log "launching Firefox"
firefox --no-first-run "https://www.google.com/webhp?hl=th" >/dev/null 2>&1 &
log "firefox launched"

# Poll for the Google window with a hard deadline instead of xdotool --sync,
# which would block forever if the browser fails to open.
sleep 20
WID=""
for _ in $(seq 1 12); do
  WID=$(xdotool search --onlyvisible --name 'Google' 2>/dev/null | head -1 || true)
  [[ -n "$WID" ]] && break
  sleep 3
done

if [[ -n "$WID" ]]; then
  xdotool windowactivate "$WID" 2>/dev/null || true
  log "focused Firefox window"
else
  log "WARNING: Firefox window not found after poll - continuing"
fi

sleep 2
setxkbmap th 2>/dev/null || true
sleep 1
log "typing Thai into the Google search box"
xdotool type --delay 150 'สวัสดีครับ ยินดีต้อนรับ' 2>/dev/null || log "WARNING: xdotool type failed"
log "Thai text typed (holding before Enter so the host can screenshot it)"
sleep 18

xdotool key Return
log "pressed Return - searching Google"

sleep 20
log "opening other apps for the UI test"
thunar >/dev/null 2>&1 &
mousepad >/dev/null 2>&1 &
xfce4-terminal --title="dietpex apps test" >/dev/null 2>&1 &
log "apps opened (thunar, mousepad, terminal)"

sleep 15
log "apps test complete"
