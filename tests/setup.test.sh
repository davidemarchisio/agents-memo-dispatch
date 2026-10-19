#!/usr/bin/env bash
# Tests for setup.sh. Each case uses a temporary HOME, so the real ~/.claude is never touched.
# Run: bash tests/setup.test.sh
set -u

setup="$(cd "$(dirname "$0")/.." && pwd)/setup.sh"
failures=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
not() { ! "$@"; }
check() {  # check <description> <command...>
  local what=$1; shift
  if "$@"; then echo "PASS $what"; else echo "FAIL $what"; failures=$((failures + 1)); fi
}

# A normal run, then a second run that must change nothing.
home=$(mktemp -d -p "$tmp"); board="$tmp/board"
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
  for path in "" "/" "//" "/." "/tmp/.."; do
    home=$(mktemp -d -p "$tmp")
    err=$(HOME=$home bash "$setup" "$path" 2>&1 >/dev/null)
    check "board path '$path' refused" [ $? -ne 0 ]
    check "board path '$path' gives the error" grep -q 'board folder is empty or /' <<<"$err"
    check "board path '$path' writes nothing in HOME" [ ! -e "$home/.claude" ]
  done
fi

# Same board again: CLAUDE.md is byte-identical.
home=$(mktemp -d -p "$tmp")
HOME=$home bash "$setup" "$board" >/dev/null
cp "$home/.claude/CLAUDE.md" "$tmp/claude.before"
HOME=$home bash "$setup" "$board" >/dev/null
check "same board twice leaves CLAUDE.md identical" cmp -s "$tmp/claude.before" "$home/.claude/CLAUDE.md"

# A new board path replaces the block in place and keeps the user's own text around it.
home=$(mktemp -d -p "$tmp"); mkdir "$home/.claude"
printf 'my notes before\n' > "$home/.claude/CLAUDE.md"
HOME=$home bash "$setup" "$tmp/old-board" >/dev/null
printf 'my notes after\n' >> "$home/.claude/CLAUDE.md"
HOME=$home bash "$setup" "$tmp/new-board" >/dev/null
md="$home/.claude/CLAUDE.md"
check "new path: one block" [ "$(grep -c '<!-- message-board start -->' "$md")" = 1 ]
check "new path: block names the new board" grep -qF "$tmp/new-board" "$md"
check "new path: old board gone" not grep -qF "$tmp/old-board" "$md"
check "new path: text before kept" [ "$(head -1 "$md")" = "my notes before" ]
check "new path: text after kept" [ "$(tail -1 "$md")" = "my notes after" ]

# Start marker without end marker: refuse, leave CLAUDE.md alone.
home=$(mktemp -d -p "$tmp"); mkdir "$home/.claude"
printf 'x\n<!-- message-board start -->\ny\n' > "$home/.claude/CLAUDE.md"
cp "$home/.claude/CLAUDE.md" "$tmp/half.before"
err=$(HOME=$home bash "$setup" "$tmp/b" 2>&1 >/dev/null)
check "half block: refused" [ $? -ne 0 ]
check "half block: names the end marker" grep -qF '<!-- message-board end -->' <<<"$err"
check "half block: CLAUDE.md unchanged" cmp -s "$tmp/half.before" "$home/.claude/CLAUDE.md"

if command -v python3 >/dev/null 2>&1; then
  # settings.json with an unexpected shape: left alone, setup still succeeds.
  for json in '[]' '{"permissions": []}' '{"permissions": {"additionalDirectories": "x"}}'; do
    home=$(mktemp -d -p "$tmp"); mkdir "$home/.claude"
    printf '%s\n' "$json" > "$home/.claude/settings.json"
    out=$(HOME=$home bash "$setup" "$tmp/b" 2>&1)
    check "settings $json: exits 0" [ $? -eq 0 ]
    check "settings $json: unchanged" [ "$(cat "$home/.claude/settings.json")" = "$json" ]
    check "settings $json: says add by hand" grep -q 'by hand' <<<"$out"
  done

  # settings.json keeps its file mode.
  home=$(mktemp -d -p "$tmp"); mkdir "$home/.claude"
  printf '{}\n' > "$home/.claude/settings.json"; chmod 600 "$home/.claude/settings.json"
  HOME=$home bash "$setup" "$tmp/b" >/dev/null
  check "settings.json keeps mode 600" [ "$(stat -c %a "$home/.claude/settings.json")" = 600 ]
fi

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
echo "all passed"
