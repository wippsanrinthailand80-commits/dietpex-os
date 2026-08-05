#!/bin/bash
# dietpex-apps-test.sh - drives the live desktop through a real app test.
#
# Runs via XDG autostart in the autologged-in live session and:
#   1. opens Firefox (real Mozilla .deb) with a first-run-skipping profile
#   2. loads Google with the Thai UI and types/pastes Thai into the search box
#   3. submits the search so the results page renders Thai
#   4. brings Thunar, Mousepad and a terminal to the front one at a time
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

# --- Deterministic slirp networking (self-heal before launching the browser).
# The static 10.0.2.15/24 config comes from the 0003-network hook; re-apply
# and dump state to the serial console so the host artifact shows it.
netdump() {
  { echo "== network state $1 =="; ip addr show; ip route; cat /etc/resolv.conf; } >> "$LOG" 2>&1 || true
  sudo -n cat "$LOG" > /dev/ttyS0 2>/dev/null || true
}
netdump "before"
if ! ip -4 addr show | grep -q "inet "; then
  log "no IPv4 address - restarting systemd-networkd"
  sudo -n systemctl restart systemd-networkd 2>/dev/null || true
  sleep 5
fi
if ! getent hosts google.com >/dev/null 2>&1; then
  log "DNS failing - forcing the slirp resolver"
  sudo -n sh -c 'echo "nameserver 10.0.2.3" > /etc/resolv.conf' 2>/dev/null || true
  sleep 2
fi
netdump "after"

# --- Firefox with a fresh profile that skips the welcome tab and onboarding
# overlays, so the loaded URL is the active tab with its real title.
PROFILE_DIR=/tmp/ffprofile
mkdir -p "$PROFILE_DIR"
cat > "$PROFILE_DIR/user.js" <<'EOF'
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.page", 0);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.contentblocking.introCount", 99);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("signon.rememberSignons", false);
EOF

log "launching Firefox (fresh profile, Google Thai UI)"
firefox --no-first-run -profile "$PROFILE_DIR" "https://www.google.com/webhp?hl=th" >/dev/null 2>&1 &
log "firefox launched"

# Wait for the Google window title, with a hard deadline (never --sync, which
# would block forever if the browser fails to start).
sleep 20
WID=""
for _ in $(seq 1 12); do
  WID=$(xdotool search --onlyvisible --name 'Google' 2>/dev/null | head -1 || true)
  [[ -n "$WID" ]] && break
  sleep 3
done

if [[ -n "$WID" ]]; then
  xdotool windowactivate "$WID" 2>/dev/null || true
  log "focused Firefox window (title Google)"
else
  log "WARNING: Google window not found; using the firefox window instead"
  WID=$(xdotool search --onlyvisible --class firefox 2>/dev/null | head -1 || true)
  if [[ -n "$WID" ]]; then
    xdotool windowactivate "$WID" 2>/dev/null || true
    xdotool key --clearmodifiers ctrl+l
    sleep 1
    xdotool type --delay 80 "https://www.google.com/webhp?hl=th"
    xdotool key Return
    sleep 10
  else
    log "WARNING: no Firefox window at all - typing will go nowhere useful"
  fi
fi

# Google's homepage autofocuses the search box; switch to the Thai (Kedmanee)
# keyboard layout and put the Thai phrase into the search box. Pasting via the
# clipboard is far more reliable for arbitrary Unicode than XTEST keysym typing.
log "switching to Thai layout and entering Thai text"
setxkbmap th 2>/dev/null || true
sleep 2
if command -v xclip >/dev/null 2>&1; then
  printf '%s' 'สวัสดีครับ ยินดีต้อนรับ' | xclip -selection clipboard 2>/dev/null || true
  xdotool key --clearmodifiers ctrl+v
else
  xdotool type --delay 100 'สวัสดีครับ ยินดีต้อนรับ' 2>/dev/null || true
fi
log "Thai text entered - holding so the host can screenshot it"
sleep 20

log "pressing Enter - searching Google"
xdotool key Return
log "search submitted - holding on the Thai results page"
sleep 20

log "raising Thunar (file manager)"
THUNAR=$(xdotool search --onlyvisible --class Thunar 2>/dev/null | head -1 || true)
if [[ -n "$THUNAR" ]]; then
  xdotool windowactivate "$THUNAR" 2>/dev/null || true
fi
sleep 20

log "raising Mousepad (editor) and typing a Thai line"
MOUSEPAD=$(xdotool search --onlyvisible --class Mousepad 2>/dev/null | head -1 || true)
if [[ -n "$MOUSEPAD" ]]; then
  xdotool windowactivate "$MOUSEPAD" 2>/dev/null || true
  sleep 2
  if command -v xclip >/dev/null 2>&1; then
    printf '%s' 'สวัสดีจาก dietpex OS' | xclip -selection clipboard 2>/dev/null || true
    xdotool key --clearmodifiers ctrl+v
  else
    xdotool type --delay 100 'สวัสดีจาก dietpex OS' 2>/dev/null || true
  fi
fi
sleep 20

log "raising a terminal"
TERM=$(xdotool search --onlyvisible --class Xfce4-terminal 2>/dev/null | head -1 || true)
if [[ -n "$TERM" ]]; then
  xdotool windowactivate "$TERM" 2>/dev/null || true
fi
sleep 15

log "apps test complete"
