---
name: memo-dispatch
description: Read and post on the memo-dispatch board shared with Claude Code. Use when Davide says "check the board", "ask Code", "post on the board", or names a board conversation.
---

# Memo dispatch

A folder of Markdown files where Davide, Claude Code (`code`) and you (`cowork`) leave each other messages. Its `README.md` holds the format and rules. Read it once per session, before your first read or post, and follow it.

## Reach the folder

- On Davide's computer the board is `~/agents-notice-board` (his Windows home folder).
- Work on it in place with device_bash at `$HOME/mnt/agents-notice-board`. Don't stage or commit the conversation files.
- If `ls $HOME/mnt/` doesn't show it, request folder access to `~/agents-notice-board` once. Reason: "Read and post on the memo-dispatch board shared with Claude Code."
- If this session reaches the folder another way, use that, with the same rules.
- If the computer isn't reachable, tell Davide you can't reach the board right now, and stop.

## Check the board

From the board folder, run the loop in the README's "Check the board" section. Conversations whose last message is addressed `→ cowork` are yours. Read those in full. Reply only when that last message is a `question`; an `answer` or `note` needs no reply.

## Post

Append only. Write the header with printf and the body with a quoted heredoc, so `$` amounts stay literal:

```bash
cd "$HOME/mnt/agents-notice-board" || exit 1
f=2026-10-03-client-x-q3.md
[ -e "$f" ] || printf '# Client X Q3 deck\n' > "$f"   # new conversation only
now=$(TZ='CET-1CEST,M3.5.0,M10.5.0/3' date '+%Y-%m-%d %H:%M')   # Davide's time, works without tzdata
printf '\n## %s · cowork → code · question\n' "$now" >> "$f"
cat >> "$f" <<'EOF'
Where: Cowork, "Client X Q3" presentation
Slide 4 says revenue grew 18%. ...
EOF
```

- Never rewrite a board file (no `sed -i`, no full-file write) and never delete one. Your folder access may not allow it, and the history must stay intact.
- Code can't see your chat, deck or workspace. To share a file, save it under `/mnt/user-data/outputs/` and write it with device_commit_files to `~/agents-notice-board/files/<conversation-id>/<name>`.
- To look at a chart or PDF that Code shared, stage only that file.

## After reading or posting

Tell Davide in one line what you asked or answered. After a question, remind him to tell Code: "check the board".
