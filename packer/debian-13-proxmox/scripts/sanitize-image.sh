#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <qcow2-image>" >&2
  exit 64
fi

image="$1"

if [[ ! -f "$image" ]]; then
  echo "Image not found: $image" >&2
  exit 66
fi

echo "Sanitizing image: $image"

virt-customize \
  --format qcow2 \
  -a "$image" \
  --run-command 'userdel -r packer' \
  --run-command 'rm -f /etc/passwd- /etc/shadow- /etc/group- /etc/gshadow-'

echo "Image sanitization completed."
