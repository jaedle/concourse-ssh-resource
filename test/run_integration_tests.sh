#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

echo "Running integration tests..."
echo ""

EXIT_CODE=0
docker compose up --abort-on-container-exit --build || EXIT_CODE=$?

docker compose down -v

if [ "$EXIT_CODE" -eq 0 ]; then
  echo ""
  echo "✓ All integration tests passed!"
  exit 0
else
  echo ""
  echo "✗ Integration tests failed!"
  exit 1
fi
