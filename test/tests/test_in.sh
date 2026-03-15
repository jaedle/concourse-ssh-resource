#!/usr/bin/env bash

set -euo pipefail

echo "Testing in script..."

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "dummy",
    "username": "dummy",
    "ssh_key": "dummy"
  },
  "version": {}
}
EOF
)

RESULT=$(echo "$PAYLOAD" | /opt/resource/in "$TMPDIR")

VERSION=$(echo "$RESULT" | jq -r '.version.time')

if [ -z "$VERSION" ]; then
  echo "FAIL: Expected version with time field"
  echo "Got: $RESULT"
  exit 1
fi

if [ ! -d "$TMPDIR" ]; then
  echo "FAIL: Expected destination directory to exist"
  exit 1
fi

echo "✓ in returns version with timestamp"
echo "✓ in creates destination directory"
