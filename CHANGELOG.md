# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.1] - 2026-05-10

### Changed
- `skills/tag/SKILL.md`: stop inserting an empty `## [Unreleased]` section after promoting it to a release; leave the file without an `[Unreleased]` heading until new entries land.
- `skills/commit/SKILL.md`: recreate a `## [Unreleased]` section at the top of `CHANGELOG.md` when missing (e.g. right after a release).

## [v0.1.0] - 2026-05-10

### Added
- `CHANGELOG.md` following Keep a Changelog format.
- `skills/tag/SKILL.md`: new `/tag` skill creating annotated `vX.Y.Z` git tags and promoting `[Unreleased]` to a dated release section in `CHANGELOG.md`.
- `CLAUDE.md`, `RTK.md`: global instructions for terse responses and RTK proxy usage.
- `LICENSE`, `README.md`: project license and overview.
- `README.md.d/`: image-generation assets (DejaVuSansMono Nerd Font files, `html_to_png.py`, `my-config.html`, `my-config.png`).
- `config/notification_states.json`: notification state configuration.
- `hooks/rtk-rewrite.sh`: hook rewriting commands through the `rtk` proxy.
- `install.sh`: installer script.
- `settings.json`: Claude Code settings (permissions, hooks, statusline).
- `skills/code/SKILL.md`: `/code` skill launching VS Code in the current folder.
- `skills/commit/SKILL.md`: `/commit` skill creating commits with Co-Authored-By trailer.
- `skills/review/SKILL.md`: `/review` skill for code review.
- `statusline-command.sh`: custom statusline script.

### Changed
- `skills/commit/SKILL.md`: rewrite `/commit` to stage explicit files and run `git commit` with Co-Authored-By trailer (HEREDOC), including `CHANGELOG.md` updates.
- `skills/commit/SKILL.md`: forbid Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, etc.) in commit subjects.
- `settings.json`: bump `statusLine.refreshInterval` from 1 to 30.

### Removed
- `statusline-command.sh`: drop redundant `rm -rf "$tmp"` calls in `session_usage`.
