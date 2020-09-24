#!/usr/bin/env bash

set -euo pipefail

# Configure cloud-init to allow image instanciation-time customization.
# The only cloud-init "datasources" that make sense for this image are:
#
# * "None": this is the last resort when nothing works. This prevents
#   cloud-init from exiting with an error because it didn't find any datasource
#   at all. This in turns allow to start the QEMU image with no
#
# * "NoCloud": this fetches the cloud-init data from a ISO disk mounted into
#   the new VM or from other non-network resources. See
#   https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html
#   for more information.
#
# Ultimately, this configures "datasource_list" in
# /etc/cloud/cloud.cfg.d/90_dpkg.cfg.
echo "cloud-init	cloud-init/datasources	multiselect	NoCloud, None" \
	| debconf-set-selections

# Configure localepurge to remove unused locales. This makes the image smaller.
echo "localepurge	localepurge/use-dpkg-feature	boolean true" \
	| debconf-set-selections
echo "localepurge	localepurge/nopurge	multiselect	en, en_US.UTF-8" \
	| debconf-set-selections

# Reconfigure cloud-init
# Don't "lock" the "wpia" user password. It is configured directly by the
# preseeding and all the rest depends on it. Cloud-init, with the default
# configuration, overrides this user's settings and prevents from using it
# without a SSH key (which needs to be passed by the "cloud" user-data, which
# we may not always have.)
cat <<EOF > /etc/cloud/cloud.cfg.d/91-debian-user.cfg
# System and/or distro specific settings
# (not accessible to handlers/transforms)
system_info:
   # This will affect which distro class gets used
   distro: debian
   # Default user name + that default users groups (if added/used)
   default_user:
     name: wpia
     lock_passwd: false
     gecos: Debian
     groups: [adm, audio, cdrom, dialout, dip, floppy, netdev, plugdev, sudo, video]
     sudo: ["ALL=(ALL) NOPASSWD:ALL"]
     shell: /bin/bash
   # Other config here will be given to the distro class and/or path classes
   paths:
      cloud_dir: /var/lib/cloud/
      templates_dir: /etc/cloud/templates/
      upstart_dir: /etc/init/
   package_mirrors:
     - arches: [default]
       failsafe:
         primary: http://deb.debian.org/debian
         security: http://security.debian.org/
   ssh_svcname: ssh
EOF

# Don't let cloud-init to take over the network configuration.
# This prevents to have more fine-grained configuration and enable lot of
# automagic configuration on interfaces that could (should!) be managed outside
# of cloud-init.
cat <<EOF > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network:
  config: disabled
EOF
