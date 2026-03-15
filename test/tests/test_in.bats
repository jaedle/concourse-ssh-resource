#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export TMPDIR
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "in returns version with timestamp" {
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

  run /opt/resource/in "$TMPDIR" <<< "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  
  VERSION=$(echo "$output" | jq -r '.version.time')
  [ -n "$VERSION" ]
}

@test "in creates destination directory" {
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

  run /opt/resource/in "$TMPDIR" <<< "$PAYLOAD"
  
  [ "$status" -eq 0 ]
  [ -d "$TMPDIR" ]
}
