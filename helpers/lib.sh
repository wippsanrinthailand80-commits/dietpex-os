#!/usr/bin/env bash
#
# dietpex OS - shared library for the installer and its helpers.
# This file is meant to be sourced, not executed.

HELPERS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$HELPERS_DIR/.." && pwd)"

LANG_CODE="${LANG_CODE:-auto}"

info() { printf '[dietpex] %s\n' "$*"; }
ok()    { printf '[dietpex] \033[32mOK\033[0m  %s\n' "$*"; }
warn()  { printf '[dietpex] \033[33mWARN\033[0m %s\n' "$*" >&2; }
die()   { printf '[dietpex] \033[31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# load_lang <code> - source the message file for the requested language.
load_lang() {
  local code="$1"
  case "$code" in
    th|th_TH|th-TH|thai) code=th ;;
    *) code=en ;;
  esac
  LANG_CODE="$code"
  # shellcheck source=lang/en.sh
  # shellcheck disable=SC1090,SC1091 # selected at runtime
  source "$ROOT_DIR/lang/$code.sh"
}

# auto_lang - pick a language from the environment (locale) if available.
auto_lang() {
  case "${LC_ALL:-${LANG:-}}" in
    th*|Thai*) echo th ;;
    *) echo en ;;
  esac
}

is_root() { [[ $EUID -eq 0 ]]; }

require_root() {
  is_root || die "$(msg need_root)"
}

# detect_env - print one of: wsl, live, apt, unknown
detect_env() {
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    echo "wsl"
  elif command -v findmnt >/dev/null 2>&1 && [[ "$(findmnt -no FSTYPE / 2>/dev/null)" =~ overlay|squashfs ]]; then
    echo "live"
  elif [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
      ubuntu|debian|linuxmint|pop|neon|elementary|kali|raspbian) echo "apt" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

# os_pretty - human readable name of the current OS.
os_pretty() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s %s' "${NAME:-$ID}" "${VERSION_ID:-}"
  else
    echo "unknown"
  fi
}

# apt_update - refresh package lists once per run.
APT_UPDATED=0
apt_update() {
  if [[ $APT_UPDATED -eq 0 ]]; then
    info "$(msg apt_update)"
    DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null || warn "apt-get update reported errors"
    APT_UPDATED=1
  fi
}

# apt_install <pkg...>
apt_install() {
  need_cmd apt-get
  apt_update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || die "failed to install: $*"
}
