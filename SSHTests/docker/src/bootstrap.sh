#!/bin/sh

# Generate host keys
ssh-keygen -A

# No Password user
adduser no-password
echo no-password:U6aMy0wojraho | chpasswd -e
chown -R no-password:no-password /home/no-password

# Partial
adduser partial
chmod 700 /home/partial/.ssh
chmod 644 /home/partial/.ssh/authorized_keys
adduser -m -d /home/partial partial
# adduser -aG sudo partial
chown -R partial:partial /home/partial
echo "partial:partial" | chpasswd

# Regular
adduser regular
chmod 700 /home/regular/.ssh
chmod 644 /home/regular/.ssh/authorized_keys
# usermod -aG sudo regular
chown -R regular:regular /home/regular
echo "regular:regular" | chpasswd

# Download files for SFTP tests
curl -X GET https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.99.tar.xz --output /home/no-password/linux.tar.xz
# chown no-password:no-password /home/no-password/linux.tar.xz
# chown -R no-password:no-password /home/no-password/copy_test
