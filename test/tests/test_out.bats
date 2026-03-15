#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export TMPDIR
  
  SSH_KEY_FILE=$(mktemp)
  chmod 600 "$SSH_KEY_FILE"
  echo "$SSH_KEY" > "$SSH_KEY_FILE"
  export SSH_KEY_FILE
}

teardown() {
  rm -rf "$TMPDIR"
  rm -f "$SSH_KEY_FILE"
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

@test "out uploads single file" {
  printf "test content" > "$TMPDIR/testfile.txt"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "testfile.txt",
        "dest": "/tmp/upload-test"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  JSON_OUTPUT=$(echo "$output" | sed -n '/^{/,$p')
  FILES_UPLOADED=$(echo "$JSON_OUTPUT" | jq -r '.metadata[] | select(.name=="files_uploaded") | .value')
  [ "$FILES_UPLOADED" = "1" ]
  
  run ssh -i "$SSH_KEY_FILE" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o LogLevel=ERROR "$SSH_USER@$SSH_HOST" "cat /tmp/upload-test/testfile.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "test content" ]
}

@test "out uploads files with glob pattern" {
  mkdir -p "$TMPDIR/dist"
  echo "file1" > "$TMPDIR/dist/file1.txt"
  echo "file2" > "$TMPDIR/dist/file2.txt"
  echo "file3" > "$TMPDIR/dist/file3.log"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "dist/*.txt",
        "dest": "/tmp/upload-glob-test"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  JSON_OUTPUT=$(echo "$output" | sed -n '/^{/,$p')
  FILES_UPLOADED=$(echo "$JSON_OUTPUT" | jq -r '.metadata[] | select(.name=="files_uploaded") | .value')
  [ "$FILES_UPLOADED" = "2" ]
  
  run ssh -i "$SSH_KEY_FILE" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o LogLevel=ERROR "$SSH_USER@$SSH_HOST" "ls /tmp/upload-glob-test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"file1.txt"* ]]
  [[ "$output" == *"file2.txt"* ]]
}

@test "out uploads directory recursively" {
  mkdir -p "$TMPDIR/app/subdir"
  echo "main" > "$TMPDIR/app/main.sh"
  echo "config" > "$TMPDIR/app/subdir/config.yml"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "app",
        "dest": "/tmp/upload-dir-test"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  run ssh -i "$SSH_KEY_FILE" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o LogLevel=ERROR "$SSH_USER@$SSH_HOST" "cat /tmp/upload-dir-test/app/subdir/config.yml"
  [ "$status" -eq 0 ]
  [ "$output" = "config" ]
}

@test "out uploads multiple file entries" {
  echo "file-a" > "$TMPDIR/file-a.txt"
  mkdir -p "$TMPDIR/data"
  echo "file-b" > "$TMPDIR/data/file-b.txt"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "file-a.txt",
        "dest": "/tmp/upload-multi-a"
      },
      {
        "src": "data/file-b.txt",
        "dest": "/tmp/upload-multi-b"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  JSON_OUTPUT=$(echo "$output" | sed -n '/^{/,$p')
  FILES_UPLOADED=$(echo "$JSON_OUTPUT" | jq -r '.metadata[] | select(.name=="files_uploaded") | .value')
  [ "$FILES_UPLOADED" = "2" ]
}

@test "out uploads with sudo" {
  echo "root-file" > "$TMPDIR/rootfile.txt"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "rootfile.txt",
        "dest": "/opt/sudo-test",
        "use_sudo": true
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  run ssh -i "$SSH_KEY_FILE" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o LogLevel=ERROR "$SSH_USER@$SSH_HOST" "sudo cat /opt/sudo-test/rootfile.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "root-file" ]
  
  ssh -i "$SSH_KEY_FILE" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o LogLevel=ERROR "$SSH_USER@$SSH_HOST" "sudo rm -rf /opt/sudo-test" || true
}

@test "out fails when both command and files specified" {
  echo "test" > "$TMPDIR/test.txt"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "command": "echo hello",
    "files": [
      {
        "src": "test.txt",
        "dest": "/tmp/test"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -ne 0 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

@test "out fails when file pattern matches nothing" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "nonexistent*.txt",
        "dest": "/tmp/test"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -ne 0 ]
  [[ "$output" == *"no files match"* ]]
}

@test "out fails when files missing src" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "dest": "/tmp/test"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -ne 0 ]
  [[ "$output" == *"'src' is required"* ]]
}

@test "out fails when files missing dest" {
  echo "test" > "$TMPDIR/test.txt"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "params": {
    "files": [
      {
        "src": "test.txt"
      }
    ]
  }
}
EOF
)

  run run_out "$PAYLOAD"
  
  [ "$status" -ne 0 ]
  [[ "$output" == *"'dest' is required"* ]]
}
