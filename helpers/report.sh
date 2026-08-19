#!/usr/bin/env bash
# shellcheck disable=SC1091 # self-contained (no lib.sh dependency)
#
# dietpex OS - read-only system resource report.
#
# Prints a quick, non-destructive snapshot of how light the system is:
#   - storage (root fs usage, /usr size, heaviest packages)
#   - RAM (total / used / available)
#   - masked services (proof the trim worked) + delta vs the baseline
#   - boot time (systemd-analyze)
#
# If dietpex.sh saved a baseline (see /var/lib/dietpex/baseline) it also
# shows the savings (packages removed, size freed, services masked).
#
# Needs no root and changes nothing. Install as /usr/local/bin/dietpex-report.
#
# Usage:
#   bash helpers/report.sh
#   dietpex-report

set -uo pipefail

info() { printf '[dietpex] %s\n' "$*"; }
hr()   { printf '%s\n' "------------------------------------------------------------"; }

BASELINE_FILE="/var/lib/dietpex/baseline"

# Read a key from the baseline file (if present). Returns empty if absent.
baseline_get() {
  local key="$1" val=""
  [[ -r "$BASELINE_FILE" ]] || return 0
  val="$(grep -E "^${key}=" "$BASELINE_FILE" 2>/dev/null | head -1 | cut -d= -f2-)"
  printf '%s' "$val"
}

current_pkg_stats() {
  # Prints "<count> <size_kb>" of currently installed packages.
  dpkg-query -W -f='${Package} ${Installed-Size}\n' 2>/dev/null \
    | awk '{c++; s+=$2} END{printf "%d %d", c, s}'
}

current_masked_count() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files --state=masked --no-legend --no-pager 2>/dev/null | wc -l
  else
    echo 0
  fi
}

report_storage() {
  info "Storage"
  local used total pct mp usr
  read -r used total pct mp < <(df -h / 2>/dev/null | awk 'NR==2{print $3, $2, $5, $6}')
  printf '  root %s: %s used of %s (%s)\n' "$mp" "${used:-?}" "${total:-?}" "${pct:-?}"

  if [[ -d /usr ]]; then
    usr="$(du -sh /usr 2>/dev/null | cut -f1)"
    printf '  /usr size: %s\n' "${usr:-?}"
  fi

  info "  top packages by installed size:"
  dpkg-query -W -f='${Installed-Size}\t${Package}\n' 2>/dev/null \
    | sort -rn | head -10 \
    | awk '{printf "    %8.1f MB  %s\n", $1/1024, $2}'
}

report_ram() {
  info "RAM"
  local total used avail
  total="$(awk '/^MemTotal:/{printf "%.1f GB", $2/1024/1024}' /proc/meminfo)"
  avail="$(awk '/^MemAvailable:/{printf "%.1f GB", $2/1024/1024}' /proc/meminfo)"
  used="$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%.1f GB", (t-a)/1024/1024}' /proc/meminfo)"
  printf '  total: %s | used (apparent): %s | available: %s\n' "${total:-?}" "${used:-?}" "${avail:-?}"
}

report_services() {
  info "Masked services (trim)"
  if command -v systemctl >/dev/null 2>&1; then
    local n
    n="$(current_masked_count)"
    printf '  %s units masked\n' "$n"
    systemctl list-unit-files --state=masked --no-legend --no-pager 2>/dev/null \
      | awk '{printf "    %s\n", $1}' | head -50
  else
    printf '  systemctl not available (WSL without systemd?)\n'
  fi
}

report_boot() {
  info "Boot time"
  if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze 2>/dev/null | head -3 | sed 's/^/  /'
    local t
    t="$(systemd-analyze time 2>/dev/null | awk '{print $1, $2}' | head -1)"
    [[ -n "$t" ]] && printf '  total boot: %s\n' "$t"
  else
    printf '  systemd-analyze not available\n'
  fi
}

report_baseline() {
  [[ -r "$BASELINE_FILE" ]] || return 0

  local b_count b_size b_masked c_count c_size c_masked
  b_count="$(baseline_get DIETPEX_BASELINE_PKG_COUNT)"
  b_size="$(baseline_get DIETPEX_BASELINE_PKG_SIZE_KB)"
  b_masked="$(baseline_get DIETPEX_BASELINE_MASKED)"
  read -r c_count c_size < <(current_pkg_stats)
  c_masked="$(current_masked_count)"

  info "Savings vs baseline (before trim)"
  if [[ -n "$b_count" && -n "$c_count" ]]; then
    printf '  packages: %s -> %s  (%+d)\n' "$b_count" "$c_count" "$((c_count - b_count))"
  fi
  if [[ -n "$b_size" && -n "$c_size" ]]; then
    local freed=$(( b_size - c_size ))
    printf '  installed size: %.1f MB -> %.1f MB  (%.1f MB freed)\n' \
      "$((b_size/1024))" "$((c_size/1024))" "$((freed/1024))"
  fi
  if [[ -n "$b_masked" && -n "$c_masked" ]]; then
    printf '  masked services: %s -> %s  (%+d)\n' "$b_masked" "$c_masked" "$((c_masked - b_masked))"
  fi
}

main() {
  hr
  info "dietpex OS - system resource report"
  hr
  report_storage
  hr
  report_ram
  hr
  report_services
  hr
  report_boot
  if [[ -r "$BASELINE_FILE" ]]; then
    hr
    report_baseline
  fi
  hr
  info "done. (read-only; no changes made)"
}

main "$@"
