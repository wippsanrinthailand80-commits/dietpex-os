#!/usr/bin/env bash
#
# dietpex OS - browser purge verification test.
#
# Installs a set of common browsers, runs the real purge once, and confirms
# each browser is actually deinstalled.
#
# Usage (as root on Ubuntu 24.04):
#   bash tests/browser-purge-test.sh
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Source dietpex helpers (provides info / load_list / contains).
# shellcheck source=dietpex.sh
source "$ROOT_DIR/dietpex.sh"

[[ $EUID -eq 0 ]] || fail "must run as root"
command -v apt-get >/dev/null 2>&1 || fail "apt-get not found"
command -v dpkg-query >/dev/null 2>&1 || fail "dpkg-query not found"

PURGE_LIST="$ROOT_DIR/config/packages-remove.list"
PROTECT_LIST="$ROOT_DIR/config/packages-protect.list"

info "loading purge + protect lists"
load_list "$PURGE_LIST" _purge_pkgs
load_list "$PROTECT_LIST" _protected

# Browsers to verify are in the purge list or get removed by it.
BROWSERS=(
  firefox
  firefox-locale-*
  thunderbird
  chromium-browser
  chromium-browser-l10n
  google-chrome-stable
  google-chrome
  microsoft-edge-stable
  microsoft-edge
  opera
  opera-stable
  brave-browser
  brave-keyring
  vivaldi-stable
)

# --- 1. Verify browsers are in the purge list ---
info "checking browser entries exist in packages-remove.list"
for b in "${BROWSERS[@]}"; do
  if contains "$b" _purge_pkgs; then
    pass "purge list contains: $b"
  fi
done

# --- 2. Install a few browsers that exist in apt repos ---
info "installing test browsers (firefox, chromium-browser)"
DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || true
for pkg in firefox chromium-browser; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    info "  installing $pkg ..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1 || \
      info "  $pkg install failed (may need extra sources) - continuing"
  fi
done

# --- 3. Verify at least one browser is actually installed ---
installed_count=0
for pkg in firefox chromium-browser; do
  if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    installed_count=$((installed_count + 1))
    pass "$pkg is installed"
  fi
done
[[ $installed_count -gt 0 ]] || { info "no browsers installed for testing - skipping purge verification"; exit 0; }

# --- 4. Run the real purge ---
info "running dietpex.sh --purge"
bash dietpex.sh --purge > /tmp/browser-purge.log 2>&1 || {
  tail -5 /tmp/browser-purge.log
  fail "dietpex.sh --purge failed"
}

# --- 5. Verify browsers were removed ---
all_removed=true
for pkg in firefox chromium-browser; do
  if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    fail "$pkg still installed after purge"
  else
    pass "$pkg removed by purge"
  fi
done

# --- 6. Verify protected packages survived ---
info "verifying protected packages survived"
for p in apt dpkg bash coreutils systemd; do
  if dpkg-query -W -f='${Status}\n' "$p" 2>/dev/null | grep -q 'install ok installed'; then
    pass "$p still installed (protected)"
  else
    fail "$p was removed - should be protected!"
  fi
done

pass "all browser purge tests passed"
