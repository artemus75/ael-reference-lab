#!/usr/bin/env bash
set -euo pipefail

# Remove SSH host identities. Deployed instances must generate their own.
rm -f /etc/ssh/ssh_host_*

# Remove Cloud-Init instance-specific state while retaining Cloud-Init itself.
cloud-init clean --logs --machine-id --seed

# Remove temporary build data.
rm -rf /tmp/* /var/tmp/*
rm -f /home/packer/.bash_history

# Flush filesystem buffers before shutdown.
sync

# The final Packer provisioner expects this SSH disconnect.
shutdown -P now
