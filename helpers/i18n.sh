#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
set -euo pipefail
#
# dietpex OS - Thai / internationalization support.
#
# Fixes "lost" Thai characters (tofu boxes) in websites, browsers such as
# Google Chrome, and applications by:
#   - installing Thai-capable fonts (TLWG set, emoji; optionally Noto)
#   - generating the th_TH.UTF-8 locale
#   - refreshing the fontconfig cache
#
#   i18n.sh install-thai [--noto] [--set-locale]
#
#   --noto         also install fonts-noto-core (Noto Sans Thai) - prettier
#                  on Google sites, but a larger download
#   --set-locale   also make th_TH.UTF-8 the system-wide locale

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

THAI_FONTS=(fonts-thai-tlwg fonts-thai-tlwg-ttf fonts-thai-tlwg-web fonts-noto-color-emoji)

install_thai_support() {
  local noto=0 set_locale=0 arg
  for arg in "$@"; do
    case "$arg" in
      --noto)       noto=1;;
      --set-locale) set_locale=1;;
      *)            warn "ignoring unknown argument: $arg";;
    esac
  done

  require_root
  info "$(msg thai_start)"

  apt_install locales
  apt_install "${THAI_FONTS[@]}"

  if [[ $noto -eq 1 ]]; then
    info "$(msg noto_note)"
    apt_install fonts-noto-core
  fi

  # Generate the th_TH.UTF-8 locale (plus en_US as a fallback).
  if command -v locale-gen >/dev/null 2>&1; then
    locale-gen th_TH.UTF-8 en_US.UTF-8 >/dev/null 2>&1 || true
  fi
  # Some systems (minimal containers, odd locales config) ignore locale-gen;
  # verify and fall back to localedef directly.
  if ! locale -a 2>/dev/null | grep -qi 'th_TH'; then
    if command -v localedef >/dev/null 2>&1; then
      if localedef -i th_TH -f UTF-8 /usr/lib/locale/th_TH.UTF-8 >/dev/null 2>&1; then
        ok "generated th_TH.UTF-8 via localedef"
      else
        warn "could not generate th_TH.UTF-8 locale"
      fi
    else
      warn "th_TH.UTF-8 not available and localedef missing"
    fi
  fi

  if [[ $set_locale -eq 1 ]] && command -v update-locale >/dev/null 2>&1; then
    update-locale LANG=th_TH.UTF-8 >/dev/null 2>&1 || true
    info "$(msg locale_set)"
  fi

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
  fi

  ok "$(msg thai_done)"
  info "$(msg thai_hint)"
}

install_thai_support "$@"
