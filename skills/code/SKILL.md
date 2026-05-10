---
name: code
description: Launch VS Code in the current folder. Use when the user types /code.
---

# /code

Open VS Code on the current working directory.

## Steps

1. Run `code .` via Bash from the current working directory to open VS Code.
2. In VS Code's integrated terminal, the user can run `claude --resume` to pick up this session (sessions are stored under `~/.claude/projects/<project-hash>/`, so opening the same folder exposes the same history).
3. Confirm with a one-line message. No further explanation.
