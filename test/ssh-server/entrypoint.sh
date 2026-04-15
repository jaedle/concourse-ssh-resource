#!/usr/bin/env bash

set -euo pipefail

ssh-keygen -t rsa -b 4096 -f /tmp/test_ssh_key -N "" -q -y > /dev/null 2>&1 || \
  ssh-keygen -t rsa -b 4096 -f /tmp/test_ssh_key -N "" -q

cat /tmp/test_ssh_key.pub

mkdir -p /home/testuser/.ssh
cat /tmp/test_ssh_key.pub >> /home/testuser/.ssh/authorized_keys
chmod 600 /home/testuser/.ssh/authorized_keys
chown -R testuser:testuser /home/testuser/.ssh

mkdir -p /shared-keys
cp /tmp/test_ssh_key /shared-keys/test_ssh_key
cp /tmp/test_ssh_key.pub /shared-keys/test_ssh_key.pub
chmod 644 /shared-keys/test_ssh_key

# Export the server's own RSA host public key for strict host key verification tests
cp /etc/ssh/ssh_host_rsa_key.pub /shared-keys/ssh_host_rsa_key.pub
chmod 644 /shared-keys/ssh_host_rsa_key.pub

exec /usr/sbin/sshd -D -e
