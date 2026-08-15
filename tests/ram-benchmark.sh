#!/usr/bin/env bash
#
# dietpex OS - XFCE app RAM benchmark.
#
# Launches every XFCE desktop application one-by-one and records RSS memory
# for each. Produces a sorted markdown table of memory usage per app.
#
# Usage (as root, with XFCE installed):
#   bash tests/ram-benchmark.sh
#
set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

OUTPUT_DIR="${1:-$ROOT_DIR/tests/screenshots}"
mkdir -p "$OUTPUT_DIR"

RESULTS="$OUTPUT_DIR/ram-benchmark-results.tsv"
SCREENSHOT_DIR="$OUTPUT_DIR/ram-benchmark"
mkdir -p "$SCREENSHOT_DIR"

info()  { echo "[ram-bench] $*"; }
pass()  { echo "[ram-bench] PASS: $*"; }
fail()  { echo "[ram-bench] FAIL: $*" >&2; }

# Start a minimal X server if none is running so we can launch apps.
if ! command -v xfdesktop >/dev/null 2>&1; then
  fail "XFCE not installed - run: sudo bash helpers/ui.sh install"
fi

if [[ -z "${DISPLAY:-}" ]]; then
  info "no DISPLAY - starting Xvfb"
  if command -v Xvfb >/dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x800x24 &
    XVFB_PID=$!
    export DISPLAY=:99
    sleep 2
  else
    fail "Xvfb not installed and no DISPLAY set"
  fi
fi

# Apps to benchmark - one per line: app_name|command
APPS=(
  "xfce4-terminal|xfce4-terminal -e true"
  "thunar|thunar --daemon"
  "xfce4-text-editor|xfce4-text-editor"
  "mousepad|mousepad"
  "xfce4-appfinder|xfce4-appfinder"
  "xfce4-taskmanager|xfce4-taskmanager"
  "xfce4-power-manager|xfce4-power-manager"
  "xfce4-screenshooter|xfce4-screenshooter --help"
  "xfce4-screencaster|xfce4-screencaster --help"
  "xfce4-notifyd|xfce4-notifyd"
  "orage|orage"
  "xfce4-cal|orage -c"
  "parole|parole --version"
  "xfce4-mixer|xfce4-mixer"
  "xfce4-clipman|xfce4-clipman"
  "xfce4-cpufreq|xfce4-cpufreq"
  "xfce4-cpugraph|xfce4-cpugraph"
  "xfce4-eyes|xfce4-eyes"
  "xfce4-fsguard|xfce4-fsguard"
  "xfce4-genmon|xfce4-genmon"
  "xfce4-indicator-plugin|xfce4-indicator-plugin"
  "xfce4-mailwatch|xfce4-mailwatch"
  "xfce4-mount|xfce4-mount"
  "xfce4-netload|xfce4-netload"
  "xfce4-notes|xfce4-notes"
  "xfce4-power|xfce4-power-manager"
  "xfce4-quicklauncher|xfce4-quicklauncher"
  "xfce4-systemblog|xfce4-systemblog"
  "xfce4-time|xfce4-time"
  "xfce4-timer|xfce4-timer"
  "xfce4-whiskey|xfce4-whiskey"
  "xfce4-splash|xfce4-splash"
)

info "found ${#APPS[@]} XFCE apps to benchmark"

# Baseline memory before launching anything.
BASELINE_RSS="$(grep -E '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
info "baseline MemAvailable: ${BASELINE_RSS} kB"

# Initialize output file.
printf "app\trss_kb\tvsz_kb\tcpu_pct\n" > "$RESULTS"

for entry in "${APPS[@]}"; do
  IFS='|' read -r name cmd <<< "$entry"
  base_cmd="${cmd%% *}"

  if ! command -v "$base_cmd" >/dev/null 2>&1; then
    info "$name: binary not installed - skip"
    continue
  fi

  info "launching: $name ($cmd)"

  eval "$cmd" &
  APP_PID=$!
  sleep 1

  # Sample metrics a few times to get a peak reading.
  MAX_RSS=0
  MAX_VSZ=0
  CPU_PCT=0
  for _ in 1 2 3; do
    if kill -0 "$APP_PID" 2>/dev/null; then
      stats="$(ps -o rss=,vsz=,pcpu= -p "$APP_PID" 2>/dev/null | tr -s ' ')"
      if [[ -n "$stats" ]]; then
        rss_kb="$(echo "$stats" | awk '{print $1}')"
        vsz_kb="$(echo "$stats" | awk '{print $2}')"
        cpu="$(echo "$stats" | awk '{print $3}')"
        MAX_RSS=$(( rss_kb > MAX_RSS ? rss_kb : MAX_RSS ))
        MAX_VSZ=$(( vsz_kb > MAX_VSZ ? vsz_kb : MAX_VSZ ))
        CPU_PCT="$cpu"
      fi
    fi
    sleep 0.5
  done

  # Capture a screenshot (best-effort).
  screen_file="$SCREENSHOT_DIR/${name}.png"
  if command -v scrot >/dev/null 2>&1; then
    DISPLAY="$DISPLAY" scrot "$screen_file" 2>/dev/null || echo "scrot failed"
  elif command -v gnome-screenshot >/dev/null 2>&1; then
    DISPLAY="$DISPLAY" timeout 5 gnome-screenshot -f "$screen_file" 2>/dev/null || echo "screenshot failed"
  fi

  # Record results.
  printf "%s\t%s\t%s\t%s\n" "$name" "$MAX_RSS" "$MAX_VSZ" "$CPU_PCT" >> "$RESULTS"

  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
  sleep 0.5

  info "  $name: RSS=${MAX_RSS} kB, VSZ=${MAX_VSZ} kB, CPU=${CPU_PCT}%"
done

# Print the summary table (sorted by RSS descending).
echo ""
echo "============================================"
echo " dietpex RAM Benchmark Results"
echo "============================================"
printf "%-30s %10s %10s %8s\n" "APP" "RSS(kB)" "VSZ(kB)" "CPU(%)"
printf "%-30s %10s %10s %8s\n" "----" "-------" "-------" "---"
sort -t$'\t' -k2 -rn "$RESULTS" | tail -n +2 | while IFS=$'\t' read -r app rss vsz cpu; do
  printf "%-30s %10s %10s %8s\n" "$app" "$rss" "$vsz" "$cpu"
done

# Write a markdown version too.
MD_FILE="$OUTPUT_DIR/ram-benchmark-results.md"
{
  echo "# dietpex RAM Benchmark"
  echo ""
  echo "Baseline MemAvailable: ${BASELINE_RSS} kB"
  echo ""
  echo "| App | RSS (kB) | VSZ (kB) | CPU (%) |"
  echo "|-----|---------|---------|---------|"
  sort -t$'\t' -k2 -rn "$RESULTS" | tail -n +2 | while IFS=$'\t' read -r app rss vsz cpu; do
    echo "| $app | $rss | $vsz | $cpu |"
  done
} > "$MD_FILE"

echo ""
info "results: $RESULTS"
info "markdown: $MD_FILE"
info "screenshots: $SCREENSHOT_DIR"

# Clean up Xvfb if we started it.
if [[ -n "${XVFB_PID:-}" ]]; then
  kill "$XVFB_PID" 2>/dev/null || true
fi

pass "RAM benchmark complete"
