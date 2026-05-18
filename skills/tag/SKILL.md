---
name: tag
description: Create an annotated git tag with a semantic version (x.y.z) and update CHANGELOG.md if it exists. Use when the user types /tag.
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git tag *) Bash(git status) Bash(git tag -l) Bash(ls CHANGELOG.md) Bash(date)
---

# /tag

Create a semver git tag and, if `CHANGELOG.md` exists, promote `[Unreleased]` to the new version with today's date. If the changelog is updated, commit it via the `/commit` skill before tagging.

## Arguments

The user supplies either:
- An explicit version `x.y.z` (optionally `vx.y.z`), or
- A bump level: `patch` (default if no argument), `minor`, or `major`.

If the argument is missing, default to `patch`. If malformed (neither a semver nor a known bump level), ask once.

## Steps

1. Resolve the target version:
   - If the argument matches `^v?\d+\.\d+\.\d+$`, normalize to `vX.Y.Z`.
   - Otherwise, treat it as a bump level (`patch` | `minor` | `major`; default `patch`). Detect the latest semver tag with `git tag -l 'v*.*.*' --sort=-v:refname | head -n1` (fallback to `v0.0.0` if none). Increment the appropriate component, resetting lower components to `0`, and normalize to `vX.Y.Z`.
2. Run in parallel:
   - `git status`
   - `git tag -l` to confirm the tag does not already exist
   - `ls CHANGELOG.md` (at repo root) to detect a changelog
3. If the tag already exists, stop and report it.
4. If `CHANGELOG.md` exists at repo root:
   - Get today's date with `date +%Y-%m-%d`.
   - Replace the `## [Unreleased]` heading with `## [X.Y.Z] - YYYY-MM-DD`. Do NOT add a fresh empty `## [Unreleased]` section above it — leave the file without an `[Unreleased]` heading until new entries are actually added.
   - Match the existing changelog format (Keep a Changelog conventions if used: `Added` / `Changed` / `Fixed` / `Removed`).
   - If the file uses link references at the bottom (e.g. `[Unreleased]: ...compare/vX.Y.Z...HEAD`), update those references too.
   - Invoke the `/commit` skill to stage `CHANGELOG.md` and commit with a message like `release vX.Y.Z` (no Conventional Commits prefix such as `chore:` / `feat:` / `fix:`).
5. Create the annotated tag on HEAD:
   ```
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   ```
6. Report the created tag and remind the user it is local — push with `git push origin vX.Y.Z` when ready (do not push automatically).

## Rules

- Never push the tag automatically.
- Never overwrite an existing tag (no `-f`).
- Only update CHANGELOG.md if it exists at the repo root; do not create one.
- Only invoke `/commit` when CHANGELOG.md was actually modified.
- Tag must be annotated (`-a`), not lightweight.
- Commit subject for the changelog release must be a plain imperative sentence — no Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, etc.).
- If the working tree has unrelated uncommitted changes, ask before proceeding.
