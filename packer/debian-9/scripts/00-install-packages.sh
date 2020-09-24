#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Default packages installed, which makes the image usable for WPIA teams. These
# tools are pretty important to have for QEMU, as it makes the image smarter.
apt-get update
apt-get install --no-install-recommends \
    acpid \
    cloud-init \
    cloud-guest-utils \
    lsb-release \
    net-tools \
    qemu-guest-agent \
    puppet \
    puppet-master \
    --yes

# These tools are just "nice to have".
apt-get install --no-install-recommends \
    curl \
    git \
    less \
    localepurge \
    vim \
    emacs-nox \
    tmux \
    --yes
