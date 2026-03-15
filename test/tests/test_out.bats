#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export TMPDIR
}

teardown() {
  rm -rf "$TMPDIR"
}

run_out() {
  local payload="$1"
  echo "$payload" | /opt/resource/out "$TMPDIR"
}

@test "out executes simple command" {
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

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  JSON_OUTPUT=$(echo "$output" | sed -n '/^{/,$p')
  VERSION=$(echo "$JSON_OUTPUT" | jq -r '.version.time')
  [ -n "$VERSION" ]
  
  EXIT_CODE_META=$(echo "$JSON_OUTPUT" | jq -r '.metadata[] | select(.name=="exit_code") | .value')
  [ "$EXIT_CODE_META" = "0" ]
}

@test "out propagates non-zero exit code" {
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

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 42 ]
}

@test "out executes sudo command" {
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

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
}

@test "out passes environment variables" {
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

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
}

@test "out fails with missing command parameter" {
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

  run run_out "$PAYLOAD"
  
  [ "$status" -ne 0 ]
}

@test "out fails with missing hostname" {
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

  run run_out "$PAYLOAD"
  
  [ "$status" -ne 0 ]
}
