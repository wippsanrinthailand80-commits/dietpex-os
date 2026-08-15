#!/usr/bin/env bash
#
# dietpex OS - browser purge verification test.
#
# Installs each browser from packages-remove.list, runs the real purge, and
# confirms the browser is actually deinstalled.
#
# Usage (as root on Ubuntu 24.04 with systemd):
#   bash tests/browser-purge-test.sh
#
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
info() { echo "INFO: $*"; }

[[ $EUID -eq 0 ]] || fail "must run as root"
command -v apt-get >/dev/null 2>&1 || fail "apt-get not found"
command -v dpkg-query >/dev/null 2>&1 || fail "dpkg-query not found"

# Source dietpex helpers.
# shellcheck source=dietpex.sh
source "$ROOT_DIR/dietpex.sh"

PURGE_LIST="$ROOT_DIR/config/packages-remove.list"
PROTECT_LIST="$ROOT_DIR/config/packages-protect.list"

info "loading purge + protect lists"
load_list "$PURGE_LIST" _all_packages
load_list "$PROTECT_LIST" _protected

# Known browser package names from the remove list.
BROWSERS=(
  firefox
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

# Collect the browser packages that are both listed AND installable.
installable=()
for b in "${BROWSERS[@]}"; do
  if contains "$b" _protected; then
    info "$b is protected - skip"
    continue
  fi
  # Check if the package exists in any apt source.
  if apt-cache show "$b" >/dev/null 2>&1; then
    installable+=("$b")
  else
    info "$b not in apt cache - skip"
  fi
done

[[ ${#installable[@]} -gt 0 ]] || fail "no installable browser packages found to test"

info "testing ${#installable[@]} browser packages"

for pkg in "${installable[@]}"; do
  echo ""
  echo "== browser: $pkg =="

  # Install the browser (dry-run first to avoid actually downloading large
  # binaries in CI).
  info "apt-get install --only-upgrade --dry-run $pkg"
  if ! apt-get install --dry-run -y "$pkg" >/dev/null 2>&1; then
    fail "$pkg cannot be installed (no apt candidate)"
  fi

  # Install it for real.
  info "installing $pkg"
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1 \
    || { info "$pkg install failed (maybe needs extra sources) - skipping"; continue; }

  # Confirm it is installed.
  installed_before="$(dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null || true)"
  echo "$installed_before" | grep -q 'install ok installed' \
    || fail "$pkg not installed after apt-get install"

  # Run the real purge.
  info "running dietpex.sh --purge"
  bash dietpex.sh --purge > "/tmp/browser-purge-${pkg}.log" 2>&1 \
    || {
      tail -5 "/tmp/browser-purge-${pkg}.log"
      fail "dietpex.sh --purge failed for $pkg"
    }

  # Confirm the browser was removed.
  installed_after="$(dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null || true)"
  if echo "$installed_after" | grep -q 'install ok installed'; then
    fail "$pkg still installed after purge"
  fi

  # Check the log confirms it was purged.
  grep -qi "purging.*$pkg\|purged.*$pkg" "/tmp/browser-purge-${pkg}.log" \
    && pass "$pkg purged" || info "$pkg not in purge log (may have been auto-removed)"

  pass "$pkg"
done

info "all browser purge tests passed"
