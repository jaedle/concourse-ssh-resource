#!/usr/bin/env bats

@test "check returns random uuid version" {
  run /opt/resource/check <<< '{}'

  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" -eq 1 ]
  UUID=$(echo "$output" | jq -r '.[0].uuid')
  [[ "$UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

@test "check returns different version on each invocation" {
  run /opt/resource/check <<< '{}'
  [ "$status" -eq 0 ]
  FIRST_UUID=$(echo "$output" | jq -r '.[0].uuid')

  run /opt/resource/check <<< '{}'
  [ "$status" -eq 0 ]
  SECOND_UUID=$(echo "$output" | jq -r '.[0].uuid')

  [ "$FIRST_UUID" != "$SECOND_UUID" ]
}
