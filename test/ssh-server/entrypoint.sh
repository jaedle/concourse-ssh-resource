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

exec /usr/sbin/sshd -D -e
