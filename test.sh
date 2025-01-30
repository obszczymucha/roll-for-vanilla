#!/usr/bin/env bash

set -o pipefail

LISTENING_DIRS=(".")
CHANGE_REGEX="\.lua$"

WHITE_COLOR="\033[0;37m"
GREEN_COLOR="\033[0;32m"
RED_COLOR="\033[0;31m"
NO_COLOR="\033[0m"

TEST_FAILED=0

run_test() {
  local full_file="$1"

  local file
  file=$(basename "$full_file")

  local dir
  dir=$(dirname "$full_file")
  
  pushd "$dir" > /dev/null || return
  local params=(-v -T Spec -m should -o text)

  if [[ "$#" -ne 1 ]]; then
    params=("${@:2}")
  fi

  lua "$file" "${params[@]}" | awk '{ gsub("^OK$", "\033[1;32m&\033[0m");
                          gsub("Ok$", "\033[1;32m&\033[0m");
                          gsub("^Failed tests:$", "\033[1;31m&\033[0m");
                          gsub("FAIL$", "\033[1;31m&\033[0m");
                          gsub("ERROR$", "\033[1;31m&\033[0m");
                          print }' >&2

  TEST_FAILED=$?
  popd > /dev/null || return
}

run_all_tests() {
  echo "Running tests..." >&2
  find . -name "*_test.lua" | while read -r file; do {
    echo >&2
    echo "Testing $file..." >&2
    run_test "$file" "$@"

    if [[ $TEST_FAILED -ne 0 ]]; then
      return $TEST_FAILED
    fi
  }; done

  return $?
}

listen() {
  echo "Listening..."
  inotifywait -mqre close_write --format "%w%f" . | while read -r FILENAME; do
    local filename
    filename=$(echo "$FILENAME" | sed -E 's/^(\.\/)*(.*)\/\.(.*\.lua)(\..{6})*$/\2\/\3/g')

    if [[ "$filename" =~ .*lua$ ]]; then
      on_change "$filename"
    fi
  done
}

print_usage() {
  echo "Usage: $0 [listen]"
}

on_change() {
  local full_file
  # shellcheck disable=SC2001
  full_file=$(echo "$1" | sed -E "s|(~)$||") # when-changed adds '~' to the filename.

  if ! echo "$full_file" | grep -E "$CHANGE_REGEX" > /dev/null; then
    return
  fi

  local pwdp
  pwdp=$(pwd -P)

  local sed_expression="s|^$pwdp/||"
  local file
  file=$(echo "$full_file" | sed -E "$sed_expression")

  echo "File: $file" >&2
  echo >&2

  if echo "$file" | grep -E "^.+_test\.lua$" > /dev/null; then
    echo "Changed: $file. Running it." >&2
    run_test "$file"
  else
    run_all_tests
  fi
}

run() {
  if [[ $1 == "listen" ]]; then
    "$0"
    listen
  elif [[ $1 == "--help" ]]; then
    print_usage
    exit 1
  else
    run_all_tests "$@"
  fi
}

run "$@"

