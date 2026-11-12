#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  printf '\n==> %s\n' "$*"
  set +e
  "$@" 2>&1 | tee /tmp/step.log
  code=${PIPESTATUS[0]}
  set -e
  if [ "$code" -ne 0 ]; then
    python3 - "$*" <<'PY'
import re, sys
log = open('/tmp/step.log', errors='replace').read().splitlines()
key = re.compile(r"error •|warning •|info •|Changed |Expected|Actual|EXCEPTION|Some tests failed|\[E\]|Error:|Failed|lib/.*\.dart:\d+|test/.*\.dart:\d+")
picked = [l for l in log if key.search(l)][:60]
tail = log[-40:]
def enc(t):
    return t.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print('::error title=step failed: ' + sys.argv[1][:60] + '::' + enc('\n'.join(picked)[:5500]))
print('::error title=log tail::' + enc('\n'.join(tail)[:5500]))
PY
    exit "$code"
  fi
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
