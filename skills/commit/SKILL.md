---
name: commit
description: Suggest a short, concise git commit message for the current changes. Use when the user types /commit. Does NOT run git commit.
---

# /commit

Propose a short git commit message. **Do not run `git commit`.** Only output the message text for the user to copy.

## Steps

1. Run in parallel:
   - `git status` (no `-uall`)
   - `git diff` (staged + unstaged)
   - `git log -n 5 --oneline` to match repo style
2. Draft a **short** commit message:
   - Single line, imperative mood ("fix X", "add Y", "refactor Z")
   - Under 70 characters
   - No body, no footer
   - Match the repo's existing style (use `feat:` / `fix:` prefix only if the repo already does)
3. Stage the impacted files directly with `git add <file1> <file2> ...` (Bash). Use the explicit list of impacted files (from `git status`, both staged and unstaged) — never `git add .` or `git add -A`. Exclude any gitignored files: check each candidate with `git check-ignore <file>` and skip matches.
4. Output the message in a code block, then automatically launch the commit via Bash inside xterm. Let **gpg's own `pinentry-curses`** handle the passphrase prompt — do not read the passphrase in bash. The only thing the script must do is export `GPG_TTY` so pinentry can find the terminal, then run `git commit`. This is what was failing before: a manual `read` + wrapper-script chain that swallowed Enter or fed a malformed wrapper to git. Pinentry handles Enter natively.
   ```
   xterm -T commit -bg black -fg white -geometry 120x30 -e bash -c '
     export GPG_TTY=$(tty);
     gpgconf --kill gpg-agent 2>/dev/null;
     git commit -S -m "<message>

   Co-Authored-By: Claude <noreply@anthropic.com>";
     STATUS=$?;
     [ $STATUS -ne 0 ] && echo "commit failed (status $STATUS)" && read -n 1 -s -r -p "Press any key to close..."'
   ```
   - `export GPG_TTY=$(tty)` — pinentry-curses needs the TTY of the xterm to draw the prompt. Without it the prompt is sent to a dead fd and never appears.
   - `gpgconf --kill gpg-agent` then `gpg-connect-agent UPDATESTARTUPTTY /bye` — kills the stale agent and rebinds the freshly-respawned one to the xterm's TTY so the next `git commit` triggers pinentry-curses on this terminal.
   - The trailing `read -n 1` keeps the window open so you can see success or error output.
   No other explanation.

## Rules

- Do not run `git commit` directly — only via `xterm -bg black -fg white -geometry 80x10 -e bash -c '...'`.
- `git add` is run directly (no wrapper script).
- One line. No fluff.
- If there are no changes, say so instead of inventing a message.
