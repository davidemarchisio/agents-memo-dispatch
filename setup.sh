#!/usr/bin/env bash
# Sets up the message board shared by Claude Code (WSL) and Cowork (Windows).
#
# Run in WSL, from this repo:  bash setup.sh [board-folder]
# Default board folder:        <your Windows home>/agents-notice-board, e.g. /mnt/c/Users/Davide/agents-notice-board
#
# Safe to run again. It:
#   1. creates the board folder and files/, and copies board/README.md (the rules) into it.
#      Conversation files are never touched.
#   2. adds a short block to ~/.claude/CLAUDE.md (once), so Claude Code knows the board.
#   3. adds the board folder to permissions.additionalDirectories in
#      ~/.claude/settings.json, so Claude Code can read it without asking.
set -euo pipefail

fail() { echo "error: $*" >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
rules="$here/board/README.md"
[ -f "$rules" ] || fail "$rules not found. Run this script from the repo checkout."

# 1. Board folder
if [ $# -ge 1 ]; then
  case "$1" in
    [A-Za-z]:\\*|[A-Za-z]:/*) board=$(wslpath -u "$1") ;;  # Windows path given
    *) board=$1 ;;
  esac
else
  winhome=""
  for c in cmd.exe /mnt/c/Windows/System32/cmd.exe; do
    if command -v "$c" >/dev/null 2>&1; then
      winhome=$( (cd /mnt/c 2>/dev/null; "$c" /c 'echo %USERPROFILE%') 2>/dev/null | tr -d '\r' ) || true
      break
    fi
  done
  case "$winhome" in
    "" | *%*) fail "can't find your Windows home folder. Run: bash $0 /mnt/c/Users/<you>/agents-notice-board" ;;
  esac
  board="$(wslpath -u "$winhome")/agents-notice-board"
fi
board=$(realpath -m -- "${board:-/}")   # absolute, no trailing slash, no . or ..
[ "$board" != / ] || fail "board folder is empty or /. Give a real folder, e.g. bash $0 /mnt/c/Users/<you>/agents-notice-board"

mkdir -p "$board/files"
cp "$rules" "$board/README.md"   # the rules; replaced on every run
echo "Board folder: $board"

# 2. CLAUDE.md block
claude_dir="$HOME/.claude"
claude_md="$claude_dir/CLAUDE.md"
mkdir -p "$claude_dir"
touch "$claude_md"
if grep -q '<!-- message-board start -->' "$claude_md"; then
  echo "$claude_md: message-board block already there, left unchanged"
else
  # shellcheck disable=SC2016  # backticks are Markdown, not command substitution
  {
    printf '\n<!-- message-board start -->\n'
    printf '## Message board\n\n'
    printf 'Davide, Cowork and you leave each other messages on a shared board: %s\n' "$board"
    printf 'When Davide says "check the board" or names a board conversation, read README.md in that folder first and follow it.\n'
    printf 'Your name on the board is `code`.\n'
    printf '<!-- message-board end -->\n'
  } >> "$claude_md"
  echo "$claude_md: added the message-board block"
fi

# 3. Allowed directories
settings="$claude_dir/settings.json"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$settings" "$board" <<'__PY__'
import json, os, sys

path, board = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        text = f.read()
    data = json.loads(text) if text.strip() else {}
except FileNotFoundError:
    data = {}
except (ValueError, OSError) as e:
    print(f"~/.claude/settings.json: can't parse it ({e}).", file=sys.stderr)
    print(f"Add {board} to permissions.additionalDirectories by hand.", file=sys.stderr)
    sys.exit(0)

dirs = data.setdefault("permissions", {}).setdefault("additionalDirectories", [])
if board in dirs:
    print("~/.claude/settings.json: board folder already allowed")
else:
    dirs.append(board)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    print("~/.claude/settings.json: board folder added to permissions.additionalDirectories")
__PY__
else
  echo "python3 not found: add $board to permissions.additionalDirectories in ~/.claude/settings.json by hand."
fi
