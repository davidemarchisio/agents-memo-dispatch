# memo-dispatch

A memo-dispatch board for Claude Code and Cowork: a shared folder of Markdown files that both can read and write.

Example: Code calculates the numbers for a client report. Cowork builds the deck, has a question about one number, and posts it on memo dispatch. You tell Code "check memos". Code checks the data and posts the answer. You tell Cowork "check memos", and it carries on.

Nothing runs on its own. You tell each side when to check memos.

## How it works

- The board is a folder in your Windows home, `C:\Users\<you>\agents-notice-board`. Code reaches it from WSL at `/mnt/c/Users/<you>/agents-notice-board`. Cowork reaches it as a connected folder.
- One Markdown file per conversation. The file name is the conversation ID, so the two sides don't need to share a project name.
- Messages are only added at the end, never edited, so the history stays intact.
- Each side can only open files in the board folder, so shared files go in `files/<conversation-id>/`.
- The full rules are in [board/README.md](board/README.md). Setup copies them into the board folder, where both agents read them.

## Install

Needs Claude Code in WSL and Cowork on the same Windows PC.

**Claude Code (WSL):**

```bash
git clone https://github.com/davidemarchisio/agents-memo-dispatch.git
bash agents-memo-dispatch/setup.sh             # or: bash agents-memo-dispatch/setup.sh /path/to/board
```

The script creates the board folder with the rules, adds a short block to `~/.claude/CLAUDE.md`, and adds the folder to `permissions.additionalDirectories` in `~/.claude/settings.json`. It's safe to run again. Restart open Code sessions afterwards.

**Cowork:** add [memo-dispatch-skill/SKILL.md](memo-dispatch-skill/SKILL.md) as a skill. The first time it's used, Cowork asks for access to the board folder.

## Use

- In Cowork: "ask Code on memo dispatch: how was the 18% on slide 4 calculated?"
- In Code: "check memos"
- In Cowork: "check memos"

## Layout

```
board/README.md         the rules, copied into the board folder
setup.sh                setup for Claude Code in WSL
memo-dispatch-skill/SKILL.md   skill for Cowork
```
