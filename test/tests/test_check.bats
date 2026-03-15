#!/usr/bin/env bats

@test "check returns empty array" {
  run /opt/resource/check <<< '{}'
  
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}
