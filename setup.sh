#!/usr/bin/env bash
# Sets up the memo-dispatch board shared by Claude Code (WSL) and Cowork (Windows).
#
# Run in WSL, from this repo:  bash setup.sh [board-folder]
# Default board folder:        <your Windows home>/agents-notice-board, e.g. /mnt/c/Users/Davide/agents-notice-board
#
# Safe to run again. It:
#   1. creates the board folder and files/, and copies board/README.md (the rules) into it.
#      Conversation files are never touched.
#   2. adds a short block to ~/.claude/CLAUDE.md, or updates it when the board folder changed,
#      so Claude Code knows the board.
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
# shellcheck disable=SC2016  # backticks are Markdown, not command substitution
block=$(
  printf '<!-- message-board start -->\n'
  printf '## Memo dispatch\n\n'
  printf 'Davide, Cowork and you leave each other messages on a shared board: %s\n' "$board"
  printf 'When Davide says "check the board" or names a board conversation, read README.md in that folder first and follow it.\n'
  printf 'Your name on the board is `code`.\n'
  printf '<!-- message-board end -->'
)
start_line='<!-- message-board start -->'
end_line='<!-- message-board end -->'
if ! grep -qF '<!-- message-board' "$claude_md"; then
  printf '\n%s\n' "$block" >> "$claude_md"
  echo "$claude_md: added the memo-dispatch block"
else
  s=$(grep -nxF "$start_line" "$claude_md" | cut -d: -f1 || true)
  e=$(grep -nxF "$end_line" "$claude_md" | cut -d: -f1 || true)
  # exactly two marker lines in the file: the start line, then the end line
  [ "$(grep -cF '<!-- message-board' "$claude_md")" -eq 2 ] && [ -n "$s" ] && [ -n "$e" ] && [ "$s" -lt "$e" ] ||
    fail "$claude_md must have one line $start_line followed by one line $end_line. Fix or remove the block by hand, then run again."
  target=$(realpath "$claude_md")   # write through a symlink, don't replace it
  tmp="$target.tmp"
  BLOCK=$block awk -v s="$s" -v e="$e" 'NR == s { print ENVIRON["BLOCK"] } NR < s || NR > e' "$target" > "$tmp"
  if cmp -s "$tmp" "$target"; then
    rm "$tmp"
    echo "$claude_md: memo-dispatch block already there, left unchanged"
  else
    chmod --reference="$target" "$tmp"
    mv "$tmp" "$target"
    echo "$claude_md: updated the memo-dispatch block to $board"
    echo "An older board folder may still be in permissions.additionalDirectories in $claude_dir/settings.json. Remove it there if you no longer use it."
  fi
fi

# 3. Allowed directories
settings="$claude_dir/settings.json"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$settings" "$board" <<'__PY__'
import json, os, shutil, sys

path, board = os.path.realpath(sys.argv[1]), sys.argv[2]  # write through a symlink, don't replace it
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

perms = data.get("permissions", {}) if isinstance(data, dict) else None
dirs = perms.get("additionalDirectories", []) if isinstance(perms, dict) else None
if not isinstance(dirs, list):
    print("~/.claude/settings.json: expected an object with permissions.additionalDirectories as a list, found another shape.", file=sys.stderr)
    print(f"Add {board} to permissions.additionalDirectories by hand.", file=sys.stderr)
    sys.exit(0)
data.setdefault("permissions", perms).setdefault("additionalDirectories", dirs)
if board in dirs:
    print("~/.claude/settings.json: board folder already allowed")
else:
    dirs.append(board)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        if os.path.exists(path):
            shutil.copymode(path, tmp)  # keep the user's file mode
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    print("~/.claude/settings.json: board folder added to permissions.additionalDirectories")
__PY__
else
  echo "python3 not found: add $board to permissions.additionalDirectories in ~/.claude/settings.json by hand."
fi
