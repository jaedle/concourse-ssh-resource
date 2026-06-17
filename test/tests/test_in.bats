#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export TMPDIR

  SSH_KEY_FILE=$(mktemp)
  chmod 600 "$SSH_KEY_FILE"
  echo "$SSH_KEY" > "$SSH_KEY_FILE"
  export SSH_KEY_FILE

  TEST_ID=$(date +%s%N)
  REMOTE_BASE="/tmp/in-test-$TEST_ID"
  export REMOTE_BASE
}

teardown() {
  remote_exec "rm -rf '$REMOTE_BASE'" >/dev/null 2>&1 || true
  remote_exec "sudo rm -rf '/root/in-test-$TEST_ID-secret.txt' && sudo find /tmp -maxdepth 1 -name 'concourse-ssh-resource-in-*' -exec rm -rf {} +" >/dev/null 2>&1 || true
  rm -rf "$TMPDIR"
  rm -f "$SSH_KEY_FILE"
}

remote_exec() {
  ssh \
    -i "$SSH_KEY_FILE" \
    -p "$SSH_PORT" \
    -o StrictHostKeyChecking=no \
    -o LogLevel=ERROR \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o PreferredAuthentications=publickey \
    -o PasswordAuthentication=no \
    "$SSH_USER@$SSH_HOST" \
    "$1"
}

run_in() {
  local payload="$1"
  echo "$payload" | /opt/resource/in "$TMPDIR"
}

json_output() {
  echo "$output" | sed -n '/^{/,$p'
}

files_metadata() {
  echo "$1" | jq -r '.metadata[] | select(.name=="files") | .value'
}

@test "in downloads single readable remote file into nested dest" {
  remote_exec "mkdir -p '$REMOTE_BASE' && printf 'hello world' > '$REMOTE_BASE/status.txt'"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "$REMOTE_BASE/status.txt",
        "dest": "downloads/status"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/downloads/status/status.txt" ]
  [ "$(cat "$TMPDIR/downloads/status/status.txt")" = "hello world" ]
}

@test "in downloads sudo-only remote file" {
  remote_exec "printf 'top-secret' | sudo tee '/root/in-test-$TEST_ID-secret.txt' >/dev/null && sudo chmod 600 '/root/in-test-$TEST_ID-secret.txt'"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/root/in-test-$TEST_ID-secret.txt",
        "dest": "secrets",
        "use_sudo": true
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/secrets/in-test-$TEST_ID-secret.txt" ]
  [ "$(cat "$TMPDIR/secrets/in-test-$TEST_ID-secret.txt")" = "top-secret" ]
}

@test "in downloads multiple files in one request" {
  remote_exec "mkdir -p '$REMOTE_BASE/a' '$REMOTE_BASE/b' && printf 'one' > '$REMOTE_BASE/a/one.txt' && printf 'two' > '$REMOTE_BASE/b/two.txt'"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "$REMOTE_BASE/a/one.txt",
        "dest": "bundle"
      },
      {
        "src": "$REMOTE_BASE/b/two.txt",
        "dest": "bundle/nested"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -eq 0 ]
  [ "$(cat "$TMPDIR/bundle/one.txt")" = "one" ]
  [ "$(cat "$TMPDIR/bundle/nested/two.txt")" = "two" ]
}

@test "in fails when remote file missing and names src" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "$REMOTE_BASE/missing.txt",
        "dest": "downloads"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"$REMOTE_BASE/missing.txt"* ]]
}

@test "in fails when dest is absolute" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/tmp/file.txt",
        "dest": "/absolute"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"dest must be a relative path"* ]]
}

@test "in fails when dest contains traversal" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/tmp/file.txt",
        "dest": "../escape"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"must not escape destination directory"* ]]
}

@test "in fails when src empty" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "",
        "dest": "downloads"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"src is required"* ]]
}

@test "in fails when dest empty" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/tmp/file.txt",
        "dest": ""
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"dest is required"* ]]
}

@test "in fails when files missing" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {}
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"params.files is required"* ]]
}

@test "in fails when files empty" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": []
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"must not be empty"* ]]
}

@test "in fails when files is not array" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": "nope"
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"must be an array"* ]]
}

@test "in fails when src is not absolute" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "relative.txt",
        "dest": "downloads"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"src must be an absolute remote path"* ]]
}

@test "in fails on duplicate resolved local target path" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/tmp/a/report.txt",
        "dest": "same/dir"
      },
      {
        "src": "/var/tmp/b/report.txt",
        "dest": "same/dir"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]
  [[ "$output" == *"duplicate local target path"* ]]
}

@test "in supports dest dot" {
  remote_exec "mkdir -p '$REMOTE_BASE' && printf 'root-file' > '$REMOTE_BASE/root.txt'"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "$REMOTE_BASE/root.txt",
        "dest": "."
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/root.txt" ]
  [ "$(cat "$TMPDIR/root.txt")" = "root-file" ]
}

@test "in sudo download cleans remote temp on success" {
  remote_exec "printf 'cleanup-ok' | sudo tee '/root/in-test-$TEST_ID-secret.txt' >/dev/null && sudo chmod 600 '/root/in-test-$TEST_ID-secret.txt'"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/root/in-test-$TEST_ID-secret.txt",
        "dest": "cleanup",
        "use_sudo": true
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -eq 0 ]

  run remote_exec "find /tmp -maxdepth 1 -name 'concourse-ssh-resource-in-*' | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "in sudo download cleans remote temp on failure path" {
  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {},
  "params": {
    "files": [
      {
        "src": "/root/in-test-$TEST_ID-secret.txt",
        "dest": "cleanup",
        "use_sudo": true
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -ne 0 ]

  run remote_exec "find /tmp -maxdepth 1 -name 'concourse-ssh-resource-in-*' | wc -l | tr -d '[:space:]'"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "in response contains hostname count files metadata and timestamp version" {
  remote_exec "mkdir -p '$REMOTE_BASE' && printf 'meta' > '$REMOTE_BASE/meta.txt'"

  PAYLOAD=$(cat <<EOF
{
  "source": {
    "hostname": "$SSH_HOST",
    "username": "$SSH_USER",
    "ssh_key": $(echo "$SSH_KEY" | jq -Rs .),
    "port": $SSH_PORT
  },
  "version": {
    "time": "ignored"
  },
  "params": {
    "files": [
      {
        "src": "$REMOTE_BASE/meta.txt",
        "dest": "meta"
      }
    ]
  }
}
EOF
)

  run run_in "$PAYLOAD"

  [ "$status" -eq 0 ]

  JSON_OUTPUT=$(json_output)
  [ -n "$(echo "$JSON_OUTPUT" | jq -r '.version.time')" ]
  [ "$(echo "$JSON_OUTPUT" | jq -r '.metadata[] | select(.name=="hostname") | .value')" = "$SSH_HOST" ]
  [ "$(echo "$JSON_OUTPUT" | jq -r '.metadata[] | select(.name=="files_downloaded") | .value')" = "1" ]
  [[ "$(files_metadata "$JSON_OUTPUT")" == *"$REMOTE_BASE/meta.txt -> meta/meta.txt"* ]]
}
