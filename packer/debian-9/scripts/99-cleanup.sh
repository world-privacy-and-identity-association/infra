#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Finally, cleanup all the things
apt-get install --yes deborphan # Let's try to remove some more
apt-get autoremove \
  $(deborphan) \
  deborphan \
  dictionaries-common \
  iamerican \
  ibritish \
  localepurge \
  task-english \
  tasksel \
  tasksel-data \
  --purge --yes

# Remove downloaded .deb files
apt-get clean

# Remove instance-specific files: we want this image to be as "impersonal" as
# possible.
find \
  /var/cache/apt \
  /var/lib/apt \
  /var/lib/dhcp \
  /var/log \
  -mindepth 1 -print -delete

rm -vf \
  /etc/network/interfaces.d/50-cloud-init.cfg \
  /etc/adjtime \
  /etc/hostname \
  /etc/hosts \
  /etc/ssh/*key* \
  /var/cache/ldconfig/aux-cache \
  /var/lib/systemd/random-seed \
  ~/.bash_history \
  "${SUDO_USER}/.bash_history"

# From https://www.freedesktop.org/software/systemd/man/machine-id.html:
# For operating system images which are created once and used on multiple
# machines, [...] /etc/machine-id should be an empty file in the generic file
# system image.
truncate -s 0 /etc/machine-id

# Recreate some useful files.
touch /var/log/lastlog
chown root:utmp /var/log/lastlog
chmod 664 /var/log/lastlog


# Free all unused storage block. This makes the final image smaller.
fstrim --all --verbose
