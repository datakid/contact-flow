#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

run dart format --output=none --set-exit-if-changed .
run flutter analyze --fatal-infos
run flutter test --exclude-tags "perf || golden"
run flutter test --tags perf

if grep -rqs --include='*_test.dart' "'golden'" test; then
  run flutter test --tags golden
else
  printf '\n==> no golden tests yet, skipping\n'
fi

printf '\nverify: all steps passed\n'
