#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091 # nameref/sourced vars
#
# dietpex OS - unit tests for the pure-bash helpers in dietpex.sh.
#
# These tests only need bash (no systemd, no root). They source dietpex.sh
# and exercise load_list / contains / glob matching used by the purge phase.
#
# Usage: bash tests/unit.sh

set -uo pipefail

# shellcheck disable=SC2154 # arrays are filled via the load_list nameref

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=dietpex.sh
source "$ROOT_DIR/dietpex.sh"

PASS=0
FAIL=0

t() { # t <description> <expected> <actual>
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS  %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n      expected: %s\n      actual:   %s\n' "$desc" "$expected" "$actual"
  fi
}

# --- fixtures ---------------------------------------------------------------
FIXTURE_LIST="$(mktemp)"
cat > "$FIXTURE_LIST" <<'EOF'
# comment line
snapd.service
snapd.socket   # inline comment

  padded.service
cups.service

EOF

# --- load_list --------------------------------------------------------------
load_list "$FIXTURE_LIST" parsed
t "load_list counts parsed entries" "4" "${#parsed[@]}"
t "load_list entry 1" "snapd.service" "${parsed[0]}"
t "load_list entry 2 (inline comment stripped)" "snapd.socket" "${parsed[1]}"
t "load_list entry 3 (whitespace stripped)" "padded.service" "${parsed[2]}"
t "load_list entry 4" "cups.service" "${parsed[3]}"

# --- contains ---------------------------------------------------------------
t "contains finds member" "yes" "$(contains snapd.service parsed && echo yes || echo no)"
t "contains misses non-member" "no" "$(contains apt-daily.timer parsed && echo yes || echo no)"

# --- purge glob matching ----------------------------------------------------
# Stub dpkg-query to simulate a small set of installed packages.
fake_dpkg_query() {
  printf '%s\n' \
    'apt' \
    'libreoffice-core' \
    'libreoffice-writer' \
    'thunderbird' \
    'perl-base'
}
dpkg-query() {
  if [[ "$1" == "-W" ]]; then
    fake_dpkg_query
  else
    command dpkg-query "$@"
  fi
}

TMP="$(mktemp -d)"
printf 'libreoffice-*\nthunderbird\nnonexistent-pkg\n' > "$TMP/purge.list"
printf 'thunderbird\n' > "$TMP/protect.list"

PURGE_LIST="$TMP/purge.list"
PROTECT_LIST="$TMP/protect.list"

# Capture which packages purge_packages WOULD remove (dry-run mode).
MODE_DRY_RUN=1
MODE_PURGE=1
out="$(purge_packages 2>&1)" && rc=$? || rc=$?

t "purge_packages exits 0" "0" "$rc"
t "purge expands libreoffice-* glob" "yes" "$(grep -q 'libreoffice-core' <<<"$out" && echo yes || echo no)"
t "purge expands multiple glob matches" "yes" "$(grep -q 'libreoffice-writer' <<<"$out" && echo yes || echo no)"
t "purge honours protect list (thunderbird)" "yes" "$(grep -q 'protected, skipping: thunderbird' <<<"$out" && echo yes || echo no)"
t "purge skips missing packages" "no" "$(grep -q 'nonexistent-pkg' <<<"$out" && echo yes || echo no)"

# --- real config lists are well-formed ---------------------------------------
load_list "$ROOT_DIR/config/services-disable.list" svcs
load_list "$ROOT_DIR/config/packages-remove.list" pkgs
load_list "$ROOT_DIR/config/packages-protect.list" prot

t "services list is non-empty" "yes" "$([[ ${#svcs[@]} -gt 0 ]] && echo yes || echo no)"
t "packages list is non-empty" "yes" "$([[ ${#pkgs[@]} -gt 0 ]] && echo yes || echo no)"
t "protect list is non-empty" "yes" "$([[ ${#prot[@]} -gt 0 ]] && echo yes || echo no)"

overlap=0
for p in "${prot[@]}"; do
  if contains "$p" pkgs; then overlap=1; break; fi
done
t "no protected package also in purge list" "0" "$overlap"

# --- safety: udisks2 must NOT be masked (file manager mounts USB drives) -----
t "udisks2.socket not in mask list" "no" "$(contains udisks2.socket svcs && echo yes || echo no)"
t "udisks2.service not in mask list" "no" "$(contains udisks2.service svcs && echo yes || echo no)"

# --- --skip-services flag -----------------------------------------------------
MODE_SKIP_SERVICES=0
parse_args --skip-services
t "--skip-services sets MODE_SKIP_SERVICES" "1" "$MODE_SKIP_SERVICES"

rm -rf "$FIXTURE_LIST" "$TMP"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
