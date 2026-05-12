# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.7] - 2026-05-12

### Added
- `THIRD.md`: document third-party runtime and installer dependencies.

### Changed
- Move `README.md.d/generate_images/` assets under `README.md.d/images/generate_images/` (fonts, `html_to_png.py`, `my-config.html`).
- `README.md.d/images/generate_images/html_to_png.py`: write PNGs to parent `images/` directory via `output_path`.
- `settings.json`: add `"awaySummaryEnabled": false`.

## [v0.1.6] - 2026-05-10

### Fixed
- `settings.json`: replace `tput bel &` with `printf '\a' > /dev/tty` in `Notification`, `PermissionRequest`, and `Stop` hooks so the bell rings reliably regardless of stdout redirection.

## [v0.1.5] - 2026-05-10

### Changed
- `skills/tag/SKILL.md`: accept `patch` (default), `minor`, `major`, or explicit `x.y.z`; auto-detect latest `vX.Y.Z` tag and bump accordingly.
- `skills/tag/SKILL.md`: forbid Conventional Commits prefixes in the changelog release commit subject (use plain `release vX.Y.Z`).

## [v0.1.4] - 2026-05-10

### Changed
- `install.sh`: pipe `N\ny\n` into `rtk init -g` with explicit `PATH="$HOME/.local/bin:$PATH"` to avoid interactive prompts.
- `.gitignore`: ignore `RTK.md` and split the previously merged `todos/RTK.md` line.

### Removed
- `RTK.md`: untrack from the repo (file kept locally).

## [v0.1.3] - 2026-05-10

### Fixed
- `README.md.d/generate_images/my-config.html`: extend gray border styling to include `yolo` text after the `/` slash indicator.
- `README.md.d/images/my-config.png`: regenerate to reflect the HTML fix.

## [v0.1.2] - 2026-05-10

### Added
- `.gitignore`: ignore local Claude state, caches, sessions, plugins, and `hooks/rtk-rewrite.sh` / `hooks/.rtk-hook.sha256`.
- `install.sh`: run `rtk init -g` after installing RTK to provision the global hook.

### Changed
- `install.sh`: pipe the Claude installer to `bash` instead of `sh`.
- `settings.json`: replace the local `rtk-rewrite.sh` PreToolUse hook with `rtk hook claude`; switch the Stop hook to `tput bel &`.

### Removed
- `hooks/rtk-rewrite.sh`: delete the in-repo hook (now provided by `rtk hook claude`).
- `config/notification_states.json`: drop tracked notification state file (now gitignored).
- `settings.json`: remove the `Bash(xterm -T commit *)` permission entry.

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
