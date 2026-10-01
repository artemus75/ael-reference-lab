#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

KEY_DIR="${BUILD_DIR}/.build"
PRIVATE_KEY="${KEY_DIR}/packer_ed25519"
PUBLIC_KEY="${PRIVATE_KEY}.pub"

OUTPUT_DIR="${BUILD_DIR}/output/debian-13-proxmox"
IMAGE="${OUTPUT_DIR}/debian-13-proxmox.qcow2"

BUILD_CREDENTIAL_CREATED=false

cleanup_build_credentials() {
  if [[ "${BUILD_CREDENTIAL_CREATED}" == "true" ]]; then
    rm -f "${PRIVATE_KEY}" "${PUBLIC_KEY}"
  fi
}

trap cleanup_build_credentials EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for command in packer ssh-keygen virt-customize qemu-img sha256sum; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 69
  fi
done

if [[ -e "${OUTPUT_DIR}" ]]; then
  echo "Output directory already exists: ${OUTPUT_DIR}" >&2
  echo "Refusing to overwrite an existing image candidate." >&2
  exit 73
fi

mkdir -p "${KEY_DIR}"

if [[ -e "${PRIVATE_KEY}" || -e "${PUBLIC_KEY}" ]]; then
  echo "Build credential already exists in ${KEY_DIR}." >&2
  echo "Refusing to overwrite credentials not owned by this build." >&2
  exit 73
fi

echo "Generating ephemeral Packer SSH credential."

# The paths were verified absent above. From this point onward, any files
# created at these paths belong to this build and may be cleaned up safely.
BUILD_CREDENTIAL_CREATED=true

ssh-keygen \
  -q \
  -t ed25519 \
  -N '' \
  -C 'packer-temporary-build-key' \
  -f "${PRIVATE_KEY}"

echo "Building image."

(
  cd "${BUILD_DIR}"
  packer build .
)

if [[ ! -f "${IMAGE}" ]]; then
  echo "Expected image artifact not found: ${IMAGE}" >&2
  exit 66
fi

echo "Sanitizing image."

"${SCRIPT_DIR}/sanitize-image.sh" "${IMAGE}"

echo "Validating QCOW2 integrity."

qemu-img check "${IMAGE}"

echo
echo "Image candidate created successfully:"
echo "${IMAGE}"
sha256sum "${IMAGE}"
