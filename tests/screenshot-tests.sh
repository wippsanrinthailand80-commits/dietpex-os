#!/usr/bin/env bash
#
# dietpex OS - screenshot test suite.
#
# Captures visual screenshots of every feature/option for manual review.
# Requires: chromium-browser (or google-chrome), systemd, root.
#
# Output: tests/screenshots/ directory with PNG files.
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/tests/screenshots"
mkdir -p "$OUT_DIR"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
info() { echo "INFO: $*"; }

[[ $EUID -eq 0 ]] || fail "must run as root"

# Find a working screenshot tool
CHROME_BIN=""

if command -v chromium-browser >/dev/null 2>&1; then
  CHROME_BIN="$(command -v chromium-browser)"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="$(command -v chromium)"
elif command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="$(command -v google-chrome)"
elif command -v google-chrome-stable >/dev/null 2>&1; then
  CHROME_BIN="$(command -v google-chrome-stable)"
fi

if [[ -z "$CHROME_BIN" ]]; then
  fail "no chromium/chrome found - install chromium-browser"
fi
info "using chrome: $CHROME_BIN"

# Helper: render HTML file to PNG using headless Chrome
html_to_png() {
  local html_file="$1"
  local png_file="$2"
  local width="${3:-1200}"
  local height="${4:-900}"
  "$CHROME_BIN" --headless --disable-gpu --no-sandbox \
    --window-size="${width},${height}" \
    --screenshot="$png_file" \
    "file://$html_file" 2>/dev/null || true
  if [[ -f "$png_file" ]]; then
    local size
    size=$(stat -c%s "$png_file" 2>/dev/null || echo 0)
    if [[ "$size" -gt 0 ]]; then
      pass "screenshot: $(basename "$png_file") (${size} bytes)"
    else
      info "screenshot empty: $(basename "$png_file")"
      rm -f "$png_file"
    fi
  else
    info "screenshot failed: $(basename "$png_file")"
  fi
}

# Helper: wrap terminal output in styled HTML and screenshot
output_to_png() {
  local title="$1"
  local cmd="$2"
  local png_file="$3"
  local width="${4:-1200}"
  local height="${5:-800}"
  local html_file
  html_file="$(mktemp /tmp/dietpex-screenshot-XXXXXX.html)"

  # Capture command output
  local output
  output="$(eval "$cmd" 2>&1)" || true

  # Count pass/fail/warn
  local passes fails warns
  passes="$(echo "$output" | grep -c '^PASS:' || true)"
  fails="$(echo "$output" | grep -c '^FAIL:' || true)"
  warns="$(echo "$output" | grep -c '^WARN:' || true)"

  # Determine status color
  local status_color="#2e7d32" status_text="OK"
  if [[ "$fails" -gt 0 ]]; then
    status_color="#c62828" status_text="FAILURES"
  elif [[ "$warns" -gt 0 ]]; then
    status_color="#f57f17" status_text="WARNINGS"
  fi

  # Escape HTML
  local escaped
  escaped="$(echo "$output" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"

  # Highlight PASS/FAIL/WARN lines
  escaped="$(echo "$escaped" | sed \
    -e 's/^PASS:.*$/<span style="color:#2e7d32;font-weight:bold">&<\/span>/' \
    -e 's/^FAIL:.*$/<span style="color:#c62828;font-weight:bold">&<\/span>/' \
    -e 's/^WARN:.*$/<span style="color:#f57f17;font-weight:bold">&<\/span>/' \
    -e 's/^\[dietpex\] OK.*$/<span style="color:#2e7d32">&<\/span>/' \
    -e 's/^\[dietpex\] WARN.*$/<span style="color:#f57f17">&<\/span>/' \
    -e 's/^\[dietpex\] ERROR.*$/<span style="color:#c62828;font-weight:bold">&<\/span>/')"

  cat > "$html_file" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<style>
  * { box-sizing: border-box; }
  body {
    font-family: 'SF Mono', 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
    margin: 0; padding: 20px;
    background: #1e1e1e; color: #d4d4d4;
    font-size: 13px; line-height: 1.5;
  }
  .header {
    background: #2d2d2d; border-bottom: 2px solid ${status_color};
    padding: 12px 20px; margin: -20px -20px 20px -20px;
    display: flex; align-items: center; gap: 16px;
  }
  .title { font-size: 18px; font-weight: bold; color: #fff; }
  .badge {
    display: inline-block; padding: 3px 12px; border-radius: 12px;
    font-size: 12px; font-weight: bold; color: #fff;
    background: ${status_color};
  }
  .stats {
    margin-left: auto; font-size: 12px; color: #888;
  }
  .stats span { margin-left: 12px; }
  .stats .pass { color: #4caf50; }
  .stats .fail { color: #f44336; }
  .stats .warn { color: #ffb300; }
  pre {
    margin: 0; white-space: pre-wrap; word-wrap: break-word;
  }
</style>
</head>
<body>
<div class="header">
  <span class="title">${title}</span>
  <span class="badge">${status_text}</span>
  <div class="stats">
    <span class="pass">PASS: ${passes}</span>
    <span class="fail">FAIL: ${fails}</span>
    <span class="warn">WARN: ${warns}</span>
  </div>
</div>
<pre>${escaped}</pre>
</body>
</html>
HTMLEOF

  html_to_png "$html_file" "$png_file" "$width" "$height"
  rm -f "$html_file"
}

echo "=========================================="
echo " dietpex OS - Screenshot Test Suite"
echo "=========================================="

# --- 1. Thai Vowel Test Page ---
echo ""
echo "== 1/12 Thai Vowel Rendering Test"
html_to_png "$ROOT_DIR/tests/thai-vowel-test.html" \
  "$OUT_DIR/01-thai-vowel-test.png" 1200 900

# --- 2. dietpex.sh --help ---
echo ""
echo "== 2/12 dietpex.sh --help"
output_to_png \
  "dietpex OS - Help (--help)" \
  "bash dietpex.sh --help" \
  "$OUT_DIR/02-dietpex-help.png" 1200 700

# --- 3. dietpex.sh --dry-run --purge ---
echo ""
echo "== 3/12 dietpex.sh --dry-run --purge"
output_to_png \
  "dietpex OS - Dry Run (--dry-run --purge)" \
  "bash dietpex.sh --dry-run --purge" \
  "$OUT_DIR/03-dietpex-dry-run.png" 1200 900

# --- 4. dietpex.sh --purge (real run) ---
echo ""
echo "== 4/12 dietpex.sh --purge (full run)"
output_to_png \
  "dietpex OS - Full Purge (--purge)" \
  "bash dietpex.sh --purge" \
  "$OUT_DIR/04-dietpex-purge.png" 1200 1000

# --- 5. dietpex.sh --skip-services ---
echo ""
echo "== 5/12 dietpex.sh --skip-services"
output_to_png \
  "dietpex OS - Skip Services (--skip-services --dry-run --purge)" \
  "bash dietpex.sh --skip-services --dry-run --purge" \
  "$OUT_DIR/05-skip-services.png" 1200 700

# --- 6. Service Status After Trim ---
echo ""
echo "== 6/12 Service Status After Trim"
output_to_png \
  "dietpex OS - Service Status After Trim" \
  "bash -c 'echo \"== Masked services ==\"; systemctl list-unit-files --state=masked --no-pager 2>/dev/null | head -30; echo; echo \"== udisks2 status ==\"; systemctl is-enabled udisks2.service 2>/dev/null || echo \"not-found\"; systemctl is-enabled udisks2.socket 2>/dev/null || echo \"not-found\"; echo; echo \"== apt-daily.timer ==\"; systemctl is-enabled apt-daily.timer 2>/dev/null || echo \"not-found\"'" \
  "$OUT_DIR/06-service-status.png" 1200 700

# --- 7. install.sh --help ---
echo ""
echo "== 7/12 install.sh --help"
output_to_png \
  "dietpex OS - Installer Help (install.sh --help)" \
  "bash install.sh --help" \
  "$OUT_DIR/07-install-help.png" 1200 700

# --- 8. install.sh --lang th --help ---
echo ""
echo "== 8/12 install.sh --lang th --help"
output_to_png \
  "dietpex OS - Installer Thai Help (install.sh --lang th --help)" \
  "bash install.sh --lang th --help" \
  "$OUT_DIR/08-install-help-thai.png" 1200 700

# --- 9. Flashdrive Resolve ---
echo ""
echo "== 9/12 flashdrive.sh resolve"
output_to_png \
  "dietpex OS - USB Flash Drive (resolve ISO URL)" \
  "bash helpers/flashdrive.sh resolve" \
  "$OUT_DIR/09-flashdrive-resolve.png" 1200 300

# --- 10. Thai i18n Verification ---
echo ""
echo "== 10/12 Thai i18n Verification"
output_to_png \
  "dietpex OS - Thai i18n Verification" \
  "bash -c 'echo \"== fc-match :lang=th ==\"; fc-match \":lang=th\" 2>/dev/null; echo; echo \"== Thai fonts ==\"; fc-list :lang=th 2>/dev/null | head -15; echo; echo \"== /etc/fonts/local.conf ==\"; cat /etc/fonts/local.conf 2>/dev/null || echo \"NOT INSTALLED\"; echo; echo \"== th_TH locale ==\"; locale -a 2>/dev/null | grep -i th'" \
  "$OUT_DIR/10-thai-i18n.png" 1200 800

# --- 11. HarfBuzz Shaping Proof ---
echo ""
echo "== 11/12 HarfBuzz Shaping Proof"
output_to_png \
  "dietpex OS - HarfBuzz Shaping Proof (Thai Vowels)" \
  "bash -c 'echo \"== hb-shape กิน (correct: vowel ิ above consonant ก) ==\"; HB_FONT=\"\$(fc-match --format=%{file} :lang=th)\"; echo \"Font: \$HB_FONT\"; echo; echo \"Thai text: กิน\"; hb-shape \"\$HB_FONT\" กิน 2>/dev/null || echo \"hb-shape not available\"; echo; echo \"Thai text: กินข้าว\"; hb-shape \"\$HB_FONT\" กินข้าว 2>/dev/null || true; echo; echo \"== Noto Sans Latin (wrong font - should show .notdef) ==\"; hb-shape /usr/share/fonts/truetype/noto/NotoSans-Regular.ttf กิน 2>/dev/null || true'" \
  "$OUT_DIR/11-harfbuzz-shaping.png" 1200 600

# --- 12. Locale & System Info ---
echo ""
echo "== 12/12 System Info Summary"
output_to_png \
  "dietpex OS - System Info Summary" \
  "bash -c 'echo \"== OS ==\"; cat /etc/os-release 2>/dev/null | head -5; echo; echo \"== Disk usage ==\"; df -h / 2>/dev/null; echo; echo \"== Memory ==\"; free -h 2>/dev/null; echo; echo \"== Masked services count ==\"; systemctl list-unit-files --state=masked --no-legend 2>/dev/null | wc -l; echo; echo \"== Default target ==\"; systemctl get-default 2>/dev/null; echo; echo \"== Desktop session ==\"; cat /etc/lightdm/lightdm.conf.d/50-dietpex-session.conf 2>/dev/null || echo \"not configured\"; echo; echo \"== Installed Thai packages ==\"; dpkg-query -W -f=\"\${Package}\n\" 2>/dev/null | grep -i thai | head -10'" \
  "$OUT_DIR/12-system-info.png" 1200 700

# --- Summary ---
echo ""
echo "=========================================="
echo " Screenshot Results"
echo "=========================================="
find "$OUT_DIR" -name '*.png' -exec ls -lh {} \; 2>/dev/null | awk '{print $NF, $5}'
echo ""
total=$(find "$OUT_DIR" -name '*.png' 2>/dev/null | wc -l)
echo "Total screenshots: $total"
echo "Directory: $OUT_DIR"
