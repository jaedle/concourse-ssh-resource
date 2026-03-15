#!/usr/bin/env bash

set -euo pipefail

echo "Testing out script..."

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

test_success() {
  local description="$1"
  echo "  Testing: $description"
}

test_failure() {
  local description="$1"
  local expected_code="${2:-1}"
  
  echo "  Testing: $description (expecting failure)"
}

echo ""
echo "Test 1: Execute simple command"
test_success "echo hello"
PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "command": "echo hello"
  }
}
EOF
)

RESULT=$(echo "$PAYLOAD" | /opt/resource/out "$TMPDIR")
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "FAIL: Command should succeed"
  echo "Exit code: $EXIT_CODE"
  exit 1
fi

VERSION=$(echo "$RESULT" | jq -r '.version.time')
if [ -z "$VERSION" ]; then
  echo "FAIL: Expected version with time field"
  echo "Got: $RESULT"
  exit 1
fi

EXIT_CODE_META=$(echo "$RESULT" | jq -r '.metadata[] | select(.name=="exit_code") | .value')
if [ "$EXIT_CODE_META" != "0" ]; then
  echo "FAIL: Expected exit_code metadata to be 0"
  echo "Got: $EXIT_CODE_META"
  exit 1
fi

echo "  ✓ Simple command executed successfully"

echo ""
echo "Test 2: Command with non-zero exit code"
test_failure "exit 42" 42
PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "command": "exit 42"
  }
}
EOF
)

set +e
RESULT=$(echo "$PAYLOAD" | /opt/resource/out "$TMPDIR" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 42 ]; then
  echo "FAIL: Expected exit code 42, got $EXIT_CODE"
  echo "Output: $RESULT"
  exit 1
fi

echo "  ✓ Non-zero exit code propagated correctly"

echo ""
echo "Test 3: Sudo command"
test_success "sudo whoami"
PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "command": "whoami",
    "use_sudo": true
  }
}
EOF
)

RESULT=$(echo "$PAYLOAD" | /opt/resource/out "$TMPDIR")
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "FAIL: Sudo command should succeed"
  echo "Exit code: $EXIT_CODE"
  exit 1
fi

echo "  ✓ Sudo command executed successfully"

echo ""
echo "Test 4: Environment variables"
test_success "env vars"
PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "command": "test \"\$TEST_VAR\" = \"test_value\"",
    "environment": {
      "TEST_VAR": "test_value"
    }
  }
}
EOF
)

RESULT=$(echo "$PAYLOAD" | /opt/resource/out "$TMPDIR")
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "FAIL: Command with env vars should succeed"
  echo "Exit code: $EXIT_CODE"
  exit 1
fi

echo "  ✓ Environment variables passed correctly"

echo ""
echo "Test 5: Missing command parameter"
test_failure "missing command"
PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {}
}
EOF
)

set +e
RESULT=$(echo "$PAYLOAD" | /opt/resource/out "$TMPDIR" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "FAIL: Should fail with missing command"
  exit 1
fi

echo "  ✓ Fails correctly with missing command"

echo ""
echo "Test 6: Missing hostname"
test_failure "missing hostname"
PAYLOAD=$(cat <<EOF
{
  "source": {
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .)
  },
  "params": {
    "command": "echo test"
  }
}
EOF
)

set +e
RESULT=$(echo "$PAYLOAD" | /opt/resource/out "$TMPDIR" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo "FAIL: Should fail with missing hostname"
  exit 1
fi

echo "  ✓ Fails correctly with missing hostname"

echo ""
echo "All out tests passed!"
