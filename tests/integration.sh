#!/usr/bin/env bash
#
# dietpex OS - integration tests.
#
# Runs the REAL trim inside a systemd-enabled Ubuntu container as root:
#   - masks services for real
#   - purges a package for real
#   - keeps protected packages
#   - exercises the single-line installer paths
#
# Usage (as root, with the repo at /dietpex):
#   bash tests/integration.sh

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ $EUID -eq 0 ]] || fail "must run as root"
command -v systemctl >/dev/null 2>&1 || fail "systemctl not found (need systemd environment)"
command -v dpkg-query >/dev/null 2>&1 || fail "dpkg-query not found"

# 1. Full trim runs cleanly.
echo "== run 1: dietpex.sh --purge"
bash dietpex.sh --purge > /tmp/dietpex1.log 2>&1 || fail "dietpex.sh --purge failed"
grep -q 'ERROR' /tmp/dietpex1.log && fail "dietpex run 1 log contains ERROR"
pass "trim run 1 completed"

# 2. Services are actually masked.
echo "== services masked"
st="$(systemctl is-enabled apt-daily.timer 2>/dev/null || true)"
[[ "$st" == "masked" ]] || fail "apt-daily.timer is '$st' (expected masked)"
pass "apt-daily.timer masked"

# 3. Protected packages survived.
echo "== protected packages"
dpkg-query -W -f='${Status}\n' apt 2>/dev/null | grep -q 'install ok installed' \
  || fail "protected package 'apt' was removed"
pass "protected package 'apt' intact"

# 4. Purge actually removes a real package.
echo "== purge removes a real package"
DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-mines > /dev/null 2>&1 \
  || fail "could not install gnome-mines (fixture)"
bash dietpex.sh --purge > /tmp/dietpex2.log 2>&1 || fail "second trim failed"
if dpkg-query -W -f='${Status}\n' gnome-mines 2>/dev/null | grep -q 'install ok installed'; then
  fail "gnome-mines still installed after purge"
fi
pass "purge removed gnome-mines"

# 5. Dry-run changes nothing and reports.
echo "== dry run"
before="$(systemctl is-enabled apt-daily.timer)"
bash dietpex.sh --dry-run --purge > /tmp/dietpex3.log 2>&1 || fail "dry run failed"
grep -q 'WOULD' /tmp/dietpex3.log || fail "dry run printed no WOULD lines"
after="$(systemctl is-enabled apt-daily.timer)"
[[ "$before" == "$after" ]] || fail "dry run modified the system"
pass "dry run is non-destructive"

# 6. Single-line installer paths work.
echo "== installer smoke"
bash install.sh --lang th --help > /tmp/help.log 2>&1 || fail "install.sh --help failed"
bash install.sh --lang en --trim-only > /tmp/install.log 2>&1 || fail "install.sh --trim-only failed"
grep -q 'ERROR' /tmp/install.log && fail "installer log contains ERROR"
pass "installer trim-only + help ok"

pass "all integration checks passed"
