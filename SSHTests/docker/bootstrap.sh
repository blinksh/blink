#!/bin/sh

# No Password user
sudo useradd no-password
echo no-password:U6aMy0wojraho | sudo chpasswd -e

# Partial
sudo mkdir -p /home/partial/.ssh
touch /home/partial/.ssh/authorized_keys
chmod 700 /home/partial/.ssh
chmod 644 /home/partial/.ssh/authorized_keys
sudo useradd -m -d /home/partial partial
sudo usermod -aG sudo partial
chown -R partial:partial /home/partial
chown root:root /home/partial
echo "partial:partial" | sudo chpasswd

# Regular
sudo useradd regular
sudo mkdir -p /home/regular/.ssh
touch /home/regular/.ssh/authorized_keys
chmod 700 /home/regular/.ssh
chmod 644 /home/regular/.ssh/authorized_keys
sudo usermod -aG sudo regular
chown -R regular:regular /home/regular
chown root:root /home/regular
echo "regular:regular" | sudo chpasswd

# Copy keys
# cat /id_rsa.pub >> /home/partial/.ssh/authorized_keys
# cat /id_rsa.pub >> /home/regular/.ssh/authorized_keys
# cat /id_ecdsa.pub >> /home/regular/.ssh/authorized_keys
# cat /user_key-cert.pub >> /home/regular/.ssh/authorized_keys
