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

# 2b. But udisks2 (needed to mount USB drives) must NOT be masked.
echo "== udisks2 left usable"
for u in udisks2.service udisks2.socket; do
  st="$(systemctl is-enabled "$u" 2>/dev/null || true)"
  if [[ "$st" == "masked" ]]; then
    fail "$u was masked - USB drives will not mount in the file manager"
  fi
done
pass "udisks2 not masked (USB mounting still works)"

# 2c. Firmware refresh unit is referenced with its real name.
echo "== fwupd-refresh unit name"
grep -Fq 'fwupd-refresh.service' config/services-disable.list \
  || fail "fwupd-refresh.service (not fwupd.refresh.service) should be in the list"
grep -Fq 'fwupd.refresh.service' config/services-disable.list \
  && fail "stale fwupd.refresh.service entry still present"
pass "fwupd-refresh unit name is correct"

# 3. Protected packages survived.
echo "== protected packages"
dpkg-query -W -f='${Status}\n' apt 2>/dev/null | grep -q 'install ok installed' \
  || fail "protected package 'apt' was removed"
pass "protected package 'apt' intact"

# 4. Purge actually removes a real package.
echo "== purge removes a real package"
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-mines > /dev/null 2>&1 \
  || fail "could not install gnome-mines (fixture)"
bash dietpex.sh --purge > /tmp/dietpex2.log 2>&1 || fail "second trim failed"
if dpkg-query -W -f='${Status}\n' gnome-mines 2>/dev/null | grep -q 'install ok installed'; then
  fail "gnome-mines still installed after purge"
fi
pass "purge removed gnome-mines"

# 5. Dry-run changes nothing and reports.
echo "== dry run"
# systemctl is-enabled returns non-zero for some states, so guard the capture.
before="$(systemctl is-enabled apt-daily.timer 2>/dev/null || true)"
bash dietpex.sh --dry-run --purge > /tmp/dietpex3.log 2>&1 || fail "dry run failed"
grep -q 'WOULD' /tmp/dietpex3.log || fail "dry run printed no WOULD lines"
after="$(systemctl is-enabled apt-daily.timer 2>/dev/null || true)"
[[ "$before" == "$after" ]] || fail "dry run modified the system"
pass "dry run is non-destructive"

# 6. Single-line installer paths work.
echo "== installer smoke"
bash install.sh --lang th --help > /tmp/help.log 2>&1 || fail "install.sh --help failed"
bash install.sh --lang en --trim-only > /tmp/install.log 2>&1 || fail "install.sh --trim-only failed"
grep -q 'ERROR' /tmp/install.log && fail "installer log contains ERROR"
pass "installer trim-only + help ok"

# 6b. Flags with missing arguments fail cleanly, not with a bash crash.
echo "== missing-arg handling"
for args in "--make-usb" "--lang"; do
  out="$(bash install.sh $args 2>&1)" && rc=0 || rc=$?
  [[ $rc -eq 1 ]] || fail "'install.sh $args' should exit 1, got $rc"
  grep -qiE 'unbound|traceback|line [0-9]+' <<<"$out" && fail "'install.sh $args' crashed with an unhandled error"
done
pass "missing arguments fail cleanly"

# 6c. --skip-services runs the purge phase without masking anything.
echo "== skip-services"
bash dietpex.sh --dry-run --skip-services > /tmp/skip.log 2>&1 || fail "dietpex.sh --skip-services failed"
grep -q 'WOULD disable' /tmp/skip.log && fail "skip-services still tried to mask services"
pass "skip-services skips the service phase"

# 7. Thai support actually makes Thai renderable.
echo "== thai support"
bash helpers/i18n.sh install-thai > /tmp/i18n.log 2>&1 || fail "i18n helper failed"
grep -q 'ERROR' /tmp/i18n.log && fail "i18n log contains ERROR"
if command -v fc-list >/dev/null 2>&1; then
  fc-list :lang=th 2>/dev/null | grep -q . || fail "no Thai-capable fonts registered with fontconfig"
  pass "Thai fonts registered with fontconfig"
fi
locale -a 2>/dev/null | grep -qi 'th_TH' || fail "th_TH locale not generated"
pass "th_TH locale present"

# 7b. Fontconfig rule forces Noto Sans Thai for Thai text (vowel fix).
echo "== thai vowel fix"
if command -v fc-match >/dev/null 2>&1; then
  best="$(fc-match ':lang=th' 2>/dev/null)"
  [[ "$best" == *NotoSansThai* || "$best" == *Waree* || "$best" == *Kinnari* ]] \
    || fail "lang=th matched '$best' instead of a Thai font - vowels will misposition"
  [[ -f /etc/fonts/local.conf ]] \
    || fail "fontconfig Thai language rule not installed"
  grep -q 'Noto Sans Thai' /etc/fonts/local.conf \
    || fail "fontconfig rule does not reference Noto Sans Thai"
  pass "Thai vowels will render with correct positioning"
fi

# 8. XFCE UI actually installs and is configured as the default session.
echo "== xfce ui install"
bash helpers/ui.sh install > /tmp/ui.log 2>&1 || fail "ui.sh failed: $(tail -5 /tmp/ui.log)"
command -v xfce4-session >/dev/null 2>&1 || fail "xfce4-session not installed"
command -v lightdm >/dev/null 2>&1 || fail "lightdm not installed"
[[ "$(systemctl get-default)" == "graphical.target" ]] || fail "default target is not graphical"
grep -q 'user-session=xfce' /etc/lightdm/lightdm.conf.d/50-dietpex-session.conf \
  || fail "LightDM session config missing"
pass "XFCE installed and set as default session"

# 9. ISO URL resolution returns a reachable, current 24.04 desktop ISO.
echo "== iso url resolution"
iso_url="$(bash helpers/flashdrive.sh resolve 2>/dev/null || true)"
[[ "$iso_url" == *.iso ]] || fail "resolve did not return an ISO: '$iso_url'"
curl -fsI --max-time 30 "$iso_url" >/dev/null 2>&1 || fail "resolved ISO URL not reachable: $iso_url"
pass "ISO URL resolves and is reachable: $iso_url"

# 10. Bootable USB writer works (best-effort, via a loop device).
echo "== usb writer"
if command -v losetup >/dev/null 2>&1; then
  img="$(mktemp /tmp/dietpex-usb.XXXXXX)"
  dd if=/dev/zero of="$img" bs=1M count=4 >/dev/null 2>&1
  loop="$(losetup -f 2>/dev/null || true)"
  if [[ -n "$loop" ]] && losetup "$loop" "$img" 2>/dev/null; then
    printf 'THIS IS NOT A REAL ISO, BUT TESTS THE WRITE PATH' > /tmp/fake.iso
    echo YES | bash helpers/flashdrive.sh create "$loop" --iso /tmp/fake.iso > /tmp/usb.log 2>&1 \
      || fail "flashdrive failed: $(tail -5 /tmp/usb.log)"
    grep -q 'Bootable USB created' /tmp/usb.log || fail "missing success message"
    losetup -d "$loop" >/dev/null 2>&1 || true
    pass "USB writer wrote to block device"
  else
    warn "could not set up loop device - skipping USB writer test"
  fi

  # 10b. The writer must refuse to destroy the disk the system is on.
  root_dev="$(findmnt -no SOURCE / 2>/dev/null || true)"
  root_disk="${root_dev%%[0-9]*}"   # /dev/sda1 -> /dev/sda
  root_disk="${root_disk%p}"        # /dev/nvme0n1p2 -> /dev/nvme0n1
  if [[ -n "$root_disk" && -b "$root_disk" ]]; then
    bash helpers/flashdrive.sh create "$root_disk" --iso /tmp/fake.iso > /tmp/refuse.log 2>&1 \
      && fail "flashdrive wrote to the system disk!"
    grep -qi 'refusing' /tmp/refuse.log \
      || fail "did not refuse the system disk: $(tail -1 /tmp/refuse.log)"
    pass "refuses to write the system disk"
  else
    warn "could not identify a real system disk - skipping refusal test"
  fi
fi

pass "all integration checks passed"
