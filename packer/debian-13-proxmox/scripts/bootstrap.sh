#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y --no-install-recommends qemu-guest-agent
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
