#!/usr/bin/env bash
# Tests for setup.sh. Each case uses a temporary HOME, so the real ~/.claude is never touched.
# Run: bash tests/setup.test.sh
set -u

setup="$(cd "$(dirname "$0")/.." && pwd)/setup.sh"
failures=0
check() {  # check <description> <command...>
  local what=$1; shift
  if "$@"; then echo "PASS $what"; else echo "FAIL $what"; failures=$((failures + 1)); fi
}

# A normal run, then a second run that must change nothing.
home=$(mktemp -d); board="$(mktemp -d)/board"
HOME=$home bash "$setup" "$board" >/dev/null
check "first run exits 0" [ $? -eq 0 ]
check "files/ created" [ -d "$board/files" ]
check "rules copied" cmp -s "$board/README.md" "$(dirname "$setup")/board/README.md"
HOME=$home bash "$setup" "$board/" >/dev/null
check "second run exits 0" [ $? -eq 0 ]
check "CLAUDE.md block added once" [ "$(grep -c '<!-- message-board start -->' "$home/.claude/CLAUDE.md")" -eq 1 ]
if command -v python3 >/dev/null 2>&1; then
  check "settings.json lists the board once" [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["permissions"]["additionalDirectories"].count(sys.argv[2]))' "$home/.claude/settings.json" "$board")" -eq 1 ]
else
  echo "SKIP settings.json checks: python3 not found"
fi

# An empty or root board path must be refused before anything is written.
if [ "$(id -u)" -eq 0 ]; then
  echo "SKIP empty and / path checks: running as root, a broken setup.sh would write to /"
else
  for path in "" "/" "//"; do
    home=$(mktemp -d)
    err=$(HOME=$home bash "$setup" "$path" 2>&1 >/dev/null)
    check "board path '$path' refused" [ $? -ne 0 ]
    check "board path '$path' gives the error" grep -q 'board folder is empty or /' <<<"$err"
    check "board path '$path' writes nothing in HOME" [ ! -e "$home/.claude" ]
  done
fi

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
echo "all passed"
