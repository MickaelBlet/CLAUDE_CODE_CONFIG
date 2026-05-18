---
name: commit-gpg
description: Same as the commit skill, but spawns an xterm running pinentry-tty so the GPG signing passphrase can be entered interactively. Use when the user types /commit-gpg.
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git check-ignore *) Bash(xterm *)
---

# /commit-gpg

Identical to `/commit`, but wraps the signed commit in an `xterm` so `pinentry-tty` can prompt for the GPG passphrase.

## Steps

1. Run in parallel:
   - `git status` (no `-uall`)
   - `git diff` (staged + unstaged)
   - `git log -n 5 --oneline` to match repo style
2. Build the explicit file list from `git status` (modified, added, untracked you want to include). Skip gitignored files (check with `git check-ignore <file>`). Never use `git add .` or `git add -A`.
3. If `CHANGELOG.md` exists at the repo root, you MUST verify whether it needs updating before staging:
   - Read the current `CHANGELOG.md` and compare its `[Unreleased]` section against the staged + unstaged diff from step 1.
   - For every logical change in the diff, confirm there is a corresponding bullet in `[Unreleased]`. If any are missing, update the file.
   - Match its existing format (e.g. Keep a Changelog: `## [Unreleased]` with `Added` / `Changed` / `Fixed` / `Removed` sections).
   - If a `## [Unreleased]` section is missing (e.g. the previous release just promoted it away), create one at the top above the most recent release section.
   - Add one bullet per logical change under the right sub-section (`Added` / `Changed` / `Fixed` / `Removed`) in `[Unreleased]`. Create the sub-section if missing.
   - Do not invent a new release/version unless the user asks.
   - Include `CHANGELOG.md` in the explicit `git add` list.
   - Do not skip this verification — even for small changes. Only bypass if the change is purely non-functional (e.g. typo in a comment) and state so explicitly.
4. Stage with `git add <file1> <file2> ...`.
5. Draft the commit message:
   - **Subject**: single line, imperative mood ("fix X", "add Y", "refactor Z"), under 70 chars
   - Do not use Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, etc.) — write the subject as a plain imperative sentence
   - **Body**: blank line after subject, then bullet points explicitly listing the changes (one bullet per logical change, referencing files/symbols affected). Wrap at ~72 chars.
6. Output the full message in a code block, then commit through `xterm` so `pinentry-tty` can prompt for the passphrase. Pass the message inline via a HEREDOC — no temp file:
   ```
   xterm -T commit-gpg -bg black -fg white -geometry 120x30 -e bash -c "GPG_TTY=\$(tty) git -c gpg.program=gpg -c gpg.pinentry-mode=loopback commit -S -m \"\$(cat <<'EOF'
   <subject>

   - <explicit change 1>
   - <explicit change 2>

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )\""
   ```
   - `xterm -e` gives `pinentry-tty` a real TTY for the passphrase prompt.
   - `GPG_TTY=$(tty)` inside the xterm ensures gpg targets that terminal.
   - The trailing `read` keeps the window open if signing fails so the error is visible.
7. After the xterm exits, run `git log -1 --show-signature` to confirm the commit was created and signed.

## Rules

- Always include the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer.
- Always `git add` with an explicit file list — never `.` or `-A`.
- Body must explicitly enumerate the changes as bullets — no vague summaries.
- If there are no changes, say so instead of inventing a commit.
- If `xterm` is not installed, tell the user (`sudo apt install xterm`) instead of falling back to an unsigned commit.
- If signing fails (no key, cancelled pinentry, etc.), report the error and do not retry blindly.
