#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <qcow2-image>" >&2
  exit 64
fi

IMAGE="$1"

if [[ ! -f "${IMAGE}" ]]; then
  echo "Image not found: ${IMAGE}" >&2
  exit 66
fi

for command in sha256sum virt-cat virt-ls qemu-img; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 69
  fi
done

FAILURES=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

inspection_failure() {
  echo "FAIL: image inspection failed: $1" >&2
  exit 70
}

BEFORE="$(sha256sum "${IMAGE}" | awk '{print $1}')"

echo "===== ACCEPTANCE HASH BEFORE ====="
echo "${BEFORE}"

#
# Read required image state first.
# Any inspection failure aborts acceptance rather than being interpreted
# as absence of the inspected state.
#

PASSWD="$(
  virt-cat -a "${IMAGE}" /etc/passwd
)" || inspection_failure "/etc/passwd"

GROUP="$(
  virt-cat -a "${IMAGE}" /etc/group
)" || inspection_failure "/etc/group"

DPKG_STATUS="$(
  virt-cat -a "${IMAGE}" /var/lib/dpkg/status
)" || inspection_failure "/var/lib/dpkg/status"

MACHINE_ID="$(
  virt-cat -a "${IMAGE}" /etc/machine-id
)" || inspection_failure "/etc/machine-id"

HOME_ENTRIES="$(
  virt-ls -a "${IMAGE}" /home
)" || inspection_failure "/home"

ETC_ENTRIES="$(
  virt-ls -a "${IMAGE}" /etc
)" || inspection_failure "/etc"

SSH_ENTRIES="$(
  virt-ls -a "${IMAGE}" /etc/ssh
)" || inspection_failure "/etc/ssh"

CLOUD_ENTRIES="$(
  virt-ls -a "${IMAGE}" /var/lib/cloud
)" || inspection_failure "/var/lib/cloud"

CLOUD_INSTANCE_ENTRIES=""
CLOUD_SEED_ENTRIES=""

if grep -Fxq 'instances' <<<"${CLOUD_ENTRIES}"; then
  CLOUD_INSTANCE_ENTRIES="$(
    virt-ls -a "${IMAGE}" /var/lib/cloud/instances
  )" || inspection_failure "/var/lib/cloud/instances"
fi

if grep -Fxq 'seed' <<<"${CLOUD_ENTRIES}"; then
  CLOUD_SEED_ENTRIES="$(
    virt-ls -a "${IMAGE}" /var/lib/cloud/seed
  )" || inspection_failure "/var/lib/cloud/seed"
fi

echo
echo "===== IMG-A5.1 PACKER ACCOUNT ====="
if grep -q '^packer:' <<<"${PASSWD}"; then
  fail "packer account exists"
else
  pass "packer account absent"
fi

echo
echo "===== IMG-A5.2 PACKER HOME ====="
if grep -Fxq 'packer' <<<"${HOME_ENTRIES}"; then
  fail "/home/packer exists"
else
  pass "/home/packer absent"
fi

echo
echo "===== IMG-A5.3 ACCOUNT DATABASE BACKUPS ====="
for file in passwd- shadow- group- gshadow-; do
  if grep -Fxq "${file}" <<<"${ETC_ENTRIES}"; then
    fail "/etc/${file} exists"
  else
    pass "/etc/${file} absent"
  fi
done

echo
echo "===== IMG-A5.4 SSH HOST PRIVATE KEYS ====="
if grep -Eq '^ssh_host_.*_key$' <<<"${SSH_ENTRIES}"; then
  fail "SSH host private key exists"
else
  pass "SSH host private keys absent"
fi

echo
echo "===== IMG-A5.5 CLOUD-INIT STATE ====="
if [[ -n "${CLOUD_INSTANCE_ENTRIES}" ]]; then
  fail "Cloud-Init instance state exists"
else
  pass "Cloud-Init instance state absent"
fi

if [[ -n "${CLOUD_SEED_ENTRIES}" ]]; then
  fail "Cloud-Init seed exists"
else
  pass "Cloud-Init seed absent"
fi

echo
echo "===== IMG-A5.6 MACHINE ID ====="
echo "${MACHINE_ID}"

if [[ "${MACHINE_ID}" == "uninitialized" ]]; then
  pass "machine-id generalized"
else
  fail "unexpected machine-id"
fi

echo
echo "===== IMG-A5.7 BUILD IDENTITY ====="
if grep -Eq \
  'Temporary Packer Build User|packer-temporary-build-key' \
  <<<"${PASSWD}"$'\n'"${GROUP}"; then
  fail "build identity residue found"
else
  pass "build identity residue absent"
fi

echo
echo "===== IMG-A5.8 QEMU GUEST AGENT ====="

QGA_BLOCK="$(
  awk '
    /^Package: qemu-guest-agent$/ { found=1 }
    found && /^(Package|Status|Version):/ { print }
    found && /^$/ { exit }
  ' <<<"${DPKG_STATUS}"
)"

printf '%s\n' "${QGA_BLOCK}"

if grep -Fxq 'Package: qemu-guest-agent' <<<"${QGA_BLOCK}" &&
   grep -Fxq 'Status: install ok installed' <<<"${QGA_BLOCK}"; then
  pass "qemu-guest-agent installed"
else
  fail "qemu-guest-agent not installed"
fi

echo
echo "===== QCOW2 INTEGRITY ====="
if qemu-img check "${IMAGE}"; then
  pass "QCOW2 integrity"
else
  fail "QCOW2 integrity"
fi

echo
echo "===== ACCEPTANCE HASH AFTER ====="
AFTER="$(sha256sum "${IMAGE}" | awk '{print $1}')"
echo "${AFTER}"

echo
echo "===== IMMUTABILITY GATE ====="
if [[ "${BEFORE}" == "${AFTER}" ]]; then
  pass "acceptance did not modify candidate"
else
  fail "candidate changed during acceptance"
fi

echo
echo "===== ACCEPTANCE RESULT ====="

if (( FAILURES > 0 )); then
  echo "FAIL: ${FAILURES} acceptance gate(s) failed"
  exit 1
fi

echo "PASS: IMG-A5 image acceptance"
echo "SHA256: ${AFTER}"
