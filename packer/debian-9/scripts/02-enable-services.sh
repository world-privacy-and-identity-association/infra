#!/usr/bin/env bash

set -euo pipefail

# Boot more quickly
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub

# Prevent clearing the terminal when systemd invokes the initial getty
# From: https://wiki.debian.org/systemd#Missing_startup_messages_on_console.28tty1.29_after_the_boot
SYSTEMD_NO_CLEAR_FILE=/etc/systemd/system/getty@tty1.service.d/no-clear.conf
mkdir --parents "$(dirname "$SYSTEMD_NO_CLEAR_FILE")"
cat <<EOF > "$SYSTEMD_NO_CLEAR_FILE"
[Service]
TTYVTDisallocate=no
EOF
systemctl daemon-reload


# Configure the ACPI daemon to gently turn off the VM when the "power button"
# is pressed.
cp /usr/share/doc/acpid/examples/powerbtn /etc/acpi/events/powerbtn
cp /usr/share/doc/acpid/examples/powerbtn.sh /etc/acpi/powerbtn.sh
chmod +x /etc/acpi/powerbtn.sh
systemctl enable acpid


# The QEMU guest agent helps the host to run the VM more optimally.
systemctl enable qemu-guest-agent
