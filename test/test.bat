#!/usr/bin/env bats

@test "only one echom" {
  result="$(grep '^[ ]*echom' ../autoload/vmenu.vim | wc -l)"
  [ "$result" -eq 1 ]
}

@test "test flag is off" {
  result=$(sed -n '/" <TEST-FLAG>/ {n;p}' ../autoload/vmenu.vim)
  [ "$result" == "if 0" ]
}
