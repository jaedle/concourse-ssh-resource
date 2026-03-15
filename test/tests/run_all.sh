#!/usr/bin/env bash

set -euo pipefail

echo "Waiting for SSH server to be ready..."

for i in {1..30}; do
  if [ -f "$SSH_KEY_PATH" ]; then
    echo "SSH key found!"
    break
  fi
  echo "Attempt $i: Waiting for SSH key..."
  sleep 1
done

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "ERROR: SSH key not found at $SSH_KEY_PATH"
  exit 1
fi

SSH_KEY=$(cat "$SSH_KEY_PATH")

export SSH_KEY

for i in {1..30}; do
  if timeout 2 bash -c "echo > /dev/tcp/$SSH_HOST/$SSH_PORT" 2>/dev/null; then
    echo "SSH server is ready!"
    break
  fi
  echo "Attempt $i: SSH server not ready yet, waiting..."
  sleep 1
done

sleep 2

echo "Running BATS tests..."
bats /tests/*.bats

echo ""
echo "All tests passed!"
exit 0
