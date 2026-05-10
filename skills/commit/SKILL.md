---
name: commit
description: Stage explicit files with git add and create a git commit including the Co-Authored-By Claude trailer. Use when the user types /commit.
---

# /commit

Stage changes with an explicit `git add <files>` then commit with the Co-Authored-By Claude trailer.

## Steps

1. Run in parallel:
   - `git status` (no `-uall`)
   - `git diff` (staged + unstaged)
   - `git log -n 5 --oneline` to match repo style
2. Build the explicit file list from `git status` (modified, added, untracked you want to include). Skip gitignored files (check with `git check-ignore <file>`). Never use `git add .` or `git add -A`.
3. If `CHANGELOG.md` exists at the repo root, update it before staging:
   - Match its existing format (e.g. Keep a Changelog: `## [Unreleased]` with `Added` / `Changed` / `Fixed` / `Removed` sections).
   - If a `## [Unreleased]` section is missing (e.g. the previous release just promoted it away), create one at the top above the most recent release section.
   - Add one bullet per logical change under the right sub-section (`Added` / `Changed` / `Fixed` / `Removed`) in `[Unreleased]`. Create the sub-section if missing.
   - Do not invent a new release/version unless the user asks.
   - Include `CHANGELOG.md` in the explicit `git add` list.
4. Stage with `git add <file1> <file2> ...`.
5. Draft the commit message:
   - **Subject**: single line, imperative mood ("fix X", "add Y", "refactor Z"), under 70 chars
   - Do not use Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, etc.) — write the subject as a plain imperative sentence
   - **Body**: blank line after subject, then bullet points explicitly listing the changes (one bullet per logical change, referencing files/symbols affected). Wrap at ~72 chars.
6. Output the full message in a code block, then commit via Bash using a HEREDOC:
   ```
   git commit -S -m "$(cat <<'EOF'
   <subject>

   - <explicit change 1>
   - <explicit change 2>

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

## Rules

- Always include the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer.
- Always `git add` with an explicit file list — never `.` or `-A`.
- Body must explicitly enumerate the changes as bullets — no vague summaries.
- If there are no changes, say so instead of inventing a commit.
- If the commit fails (e.g. hook failure), report the error and do not retry blindly.
