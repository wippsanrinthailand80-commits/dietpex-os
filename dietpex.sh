#!/usr/bin/env bash
#
# dietpex OS - trim an Ubuntu installation down to its essentials.
#
# Disables (masks) unnecessary systemd services and, optionally, purges
# bloatware packages so the system boots faster and uses less RAM, disk and
# CPU. Designed to run on Ubuntu (and compatible Debian-family) hosts.
#
# Usage:
#   sudo ./dietpex.sh [options]
#
# Options:
#   --purge       Also purge bloatware packages (see config/packages-remove.list)
#   --dry-run     Only report what would change; make no modifications
#   --no-clean    Skip apt autoremove / cache cleanup / user cleanup
#   --snap        Keep the snap ecosystem (disable snapd masking)
#   --keep-list FILE   Use an alternate services-disable list
#   --purge-list FILE  Use an alternate packages-remove list
#   -q, --quiet   Suppress informational output
#   -h, --help    Show this help and exit

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SERVICES_LIST="${SCRIPT_DIR}/config/services-disable.list"
DEFAULT_PURGE_LIST="${SCRIPT_DIR}/config/packages-remove.list"
DEFAULT_PROTECT_LIST="${SCRIPT_DIR}/config/packages-protect.list"

SERVICES_LIST="$DEFAULT_SERVICES_LIST"
PURGE_LIST="$DEFAULT_PURGE_LIST"
PROTECT_LIST="$DEFAULT_PROTECT_LIST"

MODE_PURGE=0
MODE_DRY_RUN=0
MODE_CLEAN=1
MODE_SNAP=0
QUIET=0

# ---------------------------------------------------------------- utilities

info() { [[ $QUIET -eq 1 ]] || printf '[dietpex] %s\n' "$*"; }
ok()    { [[ $QUIET -eq 1 ]] || printf '[dietpex] \033[32mOK\033[0m  %s\n' "$*"; }
warn()  { printf '[dietpex] \033[33mWARN\033[0m %s\n' "$*" >&2; }
die()   { printf '[dietpex] \033[31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

# Strip comments and blank lines from a list file into a caller's array.
#   load_list <file> <array_name>
load_list() {
  local file="$1" line entry
  local -a items=()
  local -n list_ref="$2"
  [[ -r "$file" ]] || die "list file not readable: $file"
  while IFS= read -r line; do
    line="${line%%#*}"                    # strip inline comments
    line="${line//[[:space:]]/}"          # strip all whitespace
    [[ -n "$line" ]] && items+=("$line")
  done < "$file"
  # shellcheck disable=SC2034 # nameref assignment to caller's array
  list_ref=("${items[@]}")
}

# contains <item> <array_name>
contains() {
  local item="$1"
  # shellcheck disable=SC2178 # nameref target is an array
  local -n list_ref="$2"
  local entry
  for entry in "${list_ref[@]}"; do
    [[ "$entry" == "$item" ]] && return 0
  done
  return 1
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# ------------------------------------------------------------ prerequisites

check_root() {
  [[ $EUID -eq 0 ]] || die "must be run as root (try: sudo ./dietpex.sh)"
}

check_os() {
  [[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release
  case "$ID" in
    ubuntu|debian|linuxmint|pop|neon|elementary|kali|raspbian) ;;
    *) warn "unsupported distro '$ID' - proceeding anyway";;
  esac
  command -v systemctl >/dev/null 2>&1 || die "systemd (systemctl) not found"
  command -v dpkg-query >/dev/null 2>&1 || die "dpkg-query not found"
  info "detected: ${PRETTY_NAME:-$ID $VERSION_ID}"
}

# -------------------------------------------------------------- service phase

disable_services() {
  local svc arr=()
  load_list "$SERVICES_LIST" arr

  [[ ${#arr[@]} -eq 0 ]] && { info "no services listed in $SERVICES_LIST"; return 0; }
  info "processing ${#arr[@]} services (mask)"

  for svc in "${arr[@]}"; do
    # Only touch units that actually exist.
    if ! systemctl list-unit-files "$svc" >/dev/null 2>&1 \
       && ! systemctl list-unit-files --state=not-found "$svc" >/dev/null 2>&1; then
      [[ $MODE_DRY_RUN -eq 0 ]] && info "  skip: $svc (not installed)"
      continue
    fi
    if systemctl is-enabled "$svc" >/dev/null 2>&1 || [[ -e "/etc/systemd/system/${svc}" ]]; then
      if [[ $MODE_DRY_RUN -eq 1 ]]; then
        info "  WOULD disable/mask: $svc"
      else
        systemctl stop "$svc" >/dev/null 2>&1 || true
        systemctl disable "$svc" >/dev/null 2>&1 || true
        if systemctl mask "$svc" >/dev/null 2>&1; then
          ok "disabled & masked: $svc"
        else
          warn "failed to mask: $svc"
        fi
      fi
    fi
  done

  if [[ $MODE_DRY_RUN -eq 0 && $MODE_SNAP -eq 0 ]]; then
    # Stop and unmount snap loop devices if snapd was just masked.
    systemctl stop snapd.mounts.service >/dev/null 2>&1 || true
    swapoff /snap >/dev/null 2>&1 || true
    systemctl daemon-reload
    info "reloaded systemd daemon"
  fi
}

# ---------------------------------------------------------------- purge phase

purge_packages() {
  need_cmd apt-get
  # shellcheck disable=SC2034 # 'protect' is read via the 'contains' nameref
  local pkg arr=() proto=() protect=()
  load_list "$PURGE_LIST" arr
  load_list "$PROTECT_LIST" protect

  [[ ${#arr[@]} -eq 0 ]] && { info "no packages listed in $PURGE_LIST"; return 0; }

  # Filter: only packages that exist in the dpkg database, and drop any that
  # are protected or that match a protected package.
  for pkg in "${arr[@]}"; do
    if contains "$pkg" protect; then
      warn "protected, skipping: $pkg"
      continue
    fi
    # Glob expansion support: libreoffice-* etc.
    if [[ "$pkg" == *'*'* ]]; then
      # Match installed packages against the pattern.
      local matches
      matches="$(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E "^${pkg//\*/.*}$" || true)"
      while IFS= read -r m; do
        [[ -z "$m" ]] && continue
        contains "$m" protect && { warn "protected, skipping: $m"; continue; }
        proto+=("$m")
      done <<< "$matches"
    else
      if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
        proto+=("$pkg")
      fi
    fi
  done

  # Deduplicate while preserving order.
  local seen=() final=() p
  for p in "${proto[@]}"; do
    contains "$p" seen || { seen+=("$p"); final+=("$p"); }
  done

  if [[ ${#final[@]} -eq 0 ]]; then
    info "no purgeable packages found"
    return 0
  fi

  info "purging ${#final[@]} packages"
  if [[ $MODE_DRY_RUN -eq 1 ]]; then
    for p in "${final[@]}"; do info "  WOULD purge: $p"; done
  else
    DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove "${final[@]}" \
      || warn "apt-get purge reported errors (see output above)"
    apt-get autoremove -y >/dev/null || true
  fi
}

# ------------------------------------------------------------------ cleanup

cleanup() {
  [[ $MODE_DRY_RUN -eq 1 ]] && return 0
  need_cmd apt-get
  info "running cleanup"
  apt-get autoremove -y >/dev/null || true
  apt-get autoclean -y >/dev/null || true
  apt-get clean || true
  journalctl --vacuum-time=7d >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- reporting

summarize() {
  info "all done."
  if [[ $MODE_DRY_RUN -eq 1 ]]; then
    info "(dry run - no changes were made)"
  fi
  info "reboot recommended: sudo reboot"
}

# ------------------------------------------------------------------- options

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --purge)        MODE_PURGE=1;;
      --dry-run)      MODE_DRY_RUN=1;;
      --no-clean)     MODE_CLEAN=0;;
      --snap)         MODE_SNAP=1;;
      --keep-list)    shift; SERVICES_LIST="$1";;
      --purge-list)   shift; PURGE_LIST="$1";;
      -q|--quiet)     QUIET=1;;
      -h|--help)      usage; exit 0;;
      *)              warn "ignoring unknown argument: $1";;
    esac
    shift
  done
}

# --------------------------------------------------------------------- main

main() {
  parse_args "$@"
  check_root
  check_os

  info "dietpex OS trimmer starting"
  if [[ $MODE_SNAP -eq 1 ]]; then
    info "snap ecosystem will be preserved (--snap)"
  fi

  if [[ $MODE_DRY_RUN -eq 1 ]]; then
    warn "dry run enabled - reporting only"
  fi

  disable_services

  if [[ $MODE_PURGE -eq 1 ]]; then
    purge_packages
  else
    info "skipping package purge (pass --purge to remove bloatware)"
  fi

  if [[ $MODE_CLEAN -eq 1 ]]; then
    cleanup
  fi

  summarize
}

# Run only when invoked as a script (not when sourced, so tests can reuse the
# helper functions).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

# vim: set ts=2 sw=2 expandtab:
