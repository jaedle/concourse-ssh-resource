#!/usr/bin/env bash

set -euo pipefail

echo "Testing check script..."

RESULT=$(echo '{}' | /opt/resource/check)

if [ "$RESULT" != "[]" ]; then
  echo "FAIL: Expected empty array, got: $RESULT"
  exit 1
fi

echo "✓ check returns empty array"
