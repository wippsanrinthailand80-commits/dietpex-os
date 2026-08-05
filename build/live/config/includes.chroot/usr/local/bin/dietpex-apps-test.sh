#!/bin/bash
# dietpex-apps-test.sh - drives the live desktop through a real app test.
#
# Runs via XDG autostart in the autologged-in live session and:
#   1. opens Firefox (real Mozilla .deb) with a first-run-skipping profile
#   2. loads Google with the Thai UI and types/pastes Thai into the search box
#   3. submits the search so the results page renders Thai
#   4. opens YouTube, types a Thai query into its search box and submits it
#   5. brings Thunar, Mousepad and a terminal to the front one at a time
#   6. dumps a RAM/disk resource report (idle footprint vs stock Ubuntu)
#
# The host VM script screenshots the desktop on a fixed cadence while this
# script runs, so every phase ends up in the artifact. Progress is mirrored
# to the serial console so the host's serial.log shows what happened.

set -uo pipefail

export DISPLAY="${DISPLAY:-:0}"

LOG=/home/dietpex/dietpex-apps-test.log
echo "dietpex-apps-test started at $(date)" > "$LOG" 2>/dev/null || true

# Dump the whole log to the serial console on exit (as root; the redirect must
# happen inside sudo or the unprivileged user can't open /dev/ttyS0).
sink_log() {
  sudo -n sh -c "cat '$LOG' > /dev/ttyS0" 2>/dev/null || true
}
trap sink_log EXIT

log() {
  local msg="$*"
  echo "[$(date +%T)] $msg" >> "$LOG" 2>/dev/null || true
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
  sink_log
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

# Launch the other apps up front so they exist for the raise phase below.
thunar >/dev/null 2>&1 &
mousepad >/dev/null 2>&1 &
xfce4-terminal --title="dietpex apps test" >/dev/null 2>&1 &
log "apps launched (thunar, mousepad, terminal)"

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
    # Give slirp time to render the Google homepage (which autofocuses its
    # search box) so the Thai paste below lands in the search box, not the
    # still-focused address bar.
    sleep 25
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

# --- YouTube: navigate Firefox there, focus its search box with the '/'
# hotkey, type a Thai query and submit it. This proves a second major site
# (video streaming, heavier page) renders and accepts Thai input.
log "navigating Firefox to YouTube"
WID=$(xdotool search --onlyvisible --class firefox 2>/dev/null | head -1 || true)
if [[ -n "$WID" ]]; then
  xdotool windowactivate "$WID" 2>/dev/null || true
  setxkbmap us 2>/dev/null || true
  xdotool key --clearmodifiers ctrl+l
  sleep 1
  xdotool type --delay 60 "https://www.youtube.com"
  xdotool key Return
  log "navigating to youtube.com - waiting for load"
  sleep 18
  setxkbmap us 2>/dev/null || true
  xdotool key slash
  sleep 2
  log "YouTube search focused - typing Thai query"
  setxkbmap th 2>/dev/null || true
  sleep 1
  if command -v xclip >/dev/null 2>&1; then
    printf '%s' 'เพลงไทย' | xclip -selection clipboard 2>/dev/null || true
    xdotool key --clearmodifiers ctrl+v
  else
    xdotool type --delay 100 'เพลงไทย' 2>/dev/null || true
  fi
  sleep 3
  xdotool key Return
  log "YouTube search submitted - holding on results"
  sleep 20
else
  log "WARNING: no Firefox window for the YouTube phase"
fi

# Raise a window to the front. xfwm4's focus-stealing prevention ignores
# xdotool's application-initiated activation, so use wmctrl (pager-source
# _NET_ACTIVE_WINDOW, which xfwm4 honors) as the primary mechanism and keep
# xdotool as a fallback. Search expression is e.g. "--class Thunar".
raise() {
  local arg="$*" wid="" cmd
  xfconf-query -c xfwm4 -p /general/focus_new_windows -s off 2>/dev/null || true
  for _ in $(seq 1 10); do
    wid=$(xdotool search --onlyvisible $arg 2>/dev/null | head -1 || true)
    [[ -n "$wid" ]] && break
    sleep 1
  done
  if [[ -n "$wid" ]]; then
    if command -v wmctrl >/dev/null 2>&1; then
      wmctrl -i -a "$wid" 2>/dev/null || true
    fi
    xdotool windowactivate "$wid" 2>/dev/null || true
    xdotool windowraise "$wid" 2>/dev/null || true
    xdotool windowfocus "$wid" 2>/dev/null || true
    log "raised $wid"
  else
    log "WARNING: no window found for $arg"
  fi
}

log "raising Thunar (file manager)"
raise --class Thunar
sleep 20

log "raising Mousepad (editor) and typing a Thai line"
raise --class Mousepad
sleep 2
if command -v xclip >/dev/null 2>&1; then
  printf '%s' 'สวัสดีจาก dietpex OS' | xclip -selection clipboard 2>/dev/null || true
  xdotool key --clearmodifiers ctrl+v
else
  xdotool type --delay 100 'สวัสดีจาก dietpex OS' 2>/dev/null || true
fi
sleep 20

log "raising the app-test terminal"
# The app-test terminal is the last-mapped Xfce4-terminal (higher XID); the
# first one is the fullscreen demo terminal, which we leave alone.
TWID=$(xdotool search --onlyvisible --class Xfce4-terminal 2>/dev/null | tail -1 || true)
if [[ -n "$TWID" ]]; then
  wmctrl -i -a "$TWID" 2>/dev/null || true
  xdotool windowactivate "$TWID" 2>/dev/null || true
  log "raised app-test terminal"
else
  log "WARNING: no Xfce4-terminal windows found"
fi
sleep 15

# --- Resource report: dump memory + disk usage so the host can compare the
# live system against stock Ubuntu Desktop figures (idle RAM, squashfs size).
# Everything is appended to the log and pushed to the serial console.
log "== system resources =="
{
  echo "== /etc/os-release =="
  grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release 2>/dev/null || true
  echo "== free -m =="
  free -m
  echo "== /proc/meminfo (key lines) =="
  grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree)' /proc/meminfo 2>/dev/null || true
  echo "== df -h =="
  df -h
  echo "== root filesystem =="
  findmnt -o TARGET,FSTYPE,SIZE,USED,SOURCE / 2>/dev/null || true
  echo "== squashfs size on the live medium =="
  du -h /run/live/medium/live/*.squashfs 2>/dev/null || true
  echo "== top processes by RSS (kB) =="
  ps -eo pid,rss,comm --sort=-rss 2>/dev/null | head -8
} >> "$LOG" 2>&1 || true
sink_log
sleep 5

log "apps test complete"
