#!/usr/bin/env bash
# shellcheck disable=SC1091 # sourced via dynamic path
set -euo pipefail
#
# dietpex OS - Thai / internationalization support.
#
# Fixes "lost" Thai characters (tofu boxes) in websites, browsers such as
# Google Chrome, and applications by:
#   - installing Thai-capable fonts (TLWG set, Noto Sans Thai, emoji)
#   - writing a fontconfig rule so Thai text uses a Thai font (fixes
#     floating above-vowels like ิีึื and submerged below-vowels like ุู)
#   - generating the th_TH.UTF-8 locale
#   - refreshing the fontconfig cache
#
#   i18n.sh install-thai [--set-locale]
#
#   --set-locale   also make th_TH.UTF-8 the system-wide locale

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

THAI_FONTS=(fonts-thai-tlwg fonts-thai-tlwg-ttf fonts-thai-tlwg-web fonts-noto-color-emoji)

# Fontconfig rule that forces Noto Sans Thai for Thai-language text.
# Without this, fc-match lang=th returns a Latin font and the combining
# marks float (above vowels) or sink (below vowels) due to wrong metrics.
THAI_FONTCONFIG_RULE='<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains"><string>th</string></test>
    <edit name="family" mode="assign" binding="same">
      <string>Noto Sans Thai</string>
    </edit>
  </match>
</fontconfig>'

install_thai_support() {
  local set_locale=0 arg
  for arg in "$@"; do
    case "$arg" in
      --noto)       ;; # accepted for backward compat (now always installs Noto)
      --set-locale) set_locale=1;;
      *)            warn "ignoring unknown argument: $arg";;
    esac
  done

  require_root
  info "$(msg thai_start)"

  apt_install locales
  apt_install "${THAI_FONTS[@]}"
  # Noto Sans Thai (from fonts-noto-core) is required by the fontconfig rule
  # below that fixes floating/submerged vowels. Always install it.
  apt_install fonts-noto-core

  # Install the fontconfig rule that fixes Thai vowel positioning.
  # Without this, fc-match lang=th returns a Latin font and the combining
  # marks float (above vowels) or sink (below vowels) due to wrong metrics.
  printf '%s\n' "$THAI_FONTCONFIG_RULE" > /etc/fonts/local.conf
  ok "fontconfig Thai language rule installed"

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
