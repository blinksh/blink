#!/bin/sh

# Generate host keys
ssh-keygen -A

# No Password user
adduser no-password
echo no-password:U6aMy0wojraho | chpasswd -e

# Partial
adduser partial
chmod 700 /home/partial/.ssh
chmod 644 /home/partial/.ssh/authorized_keys
adduser -m -d /home/partial partial
adduser -aG sudo partial
chown -R partial:partial /home/partial
chown root:root /home/partial
echo "partial:partial" | chpasswd

# Regular
adduser regular
chmod 700 /home/regular/.ssh
chmod 644 /home/regular/.ssh/authorized_keys
usermod -aG sudo regular
chown -R regular:regular /home/regular
chown root:root /home/regular
echo "regular:regular" | chpasswd
