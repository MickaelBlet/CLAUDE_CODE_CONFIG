# CLAUDE_CODE_CONFIG

<p align="center">
  <img src="README.md.d/images/my-config.png" />
</p>

A personal [Claude Code](https://claude.ai) configuration: opinionated `settings.json`, a custom Powerline status line, and a handful of git/dev slash commands packaged as skills.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/MickaelBlet/CLAUDE_CODE_CONFIG/refs/heads/master/install.sh | sh
```

The installer:
1. Installs [Claude Code](https://claude.ai) (`claude.ai/install.sh`).
2. Installs [RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk) and runs `rtk init -g` to provision its global hook.
3. Downloads this repo as a tarball and extracts it into `$HOME/.claude` (overridable via `$CLAUDE_CONFIG_DIR`).
4. Backs up any pre-existing `settings.json` to `settings.json.bak` on first install.

---

## Settings (`settings.json`)

### Environment

| Key | Value | Effect |
|---|---|---|
| `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `60` | Trigger auto-compaction at 60% context usage (default is higher) so long sessions stay responsive. |

### Model

| Key | Value | Effect |
|---|---|---|
| `model` | `opus` | Default model for new sessions (overridable per-session via `/model`). |

### Permissions

Pre-approved Bash patterns — Claude can run these without asking each time.

| Permission | Why |
|---|---|
| `Bash(rtk *)` | The RTK proxy is invoked by hooks and as a CLI; avoids permission prompts on every call. |
| `Bash(cat *)` | Read-only file viewing. |
| `Bash(grep *)`, `Bash(/bin/grep *)` | Search. Both paths are listed because some shells resolve `grep` to the absolute path. |
| `Bash(cmake *)`, `Bash(ctest *)` | C/C++ build and test loops without prompts. |
| `Bash(code *)` | Required by the `/code` skill to launch VS Code. |

### Hooks

Hooks fire on harness lifecycle events. This config wires three of them to a terminal bell and one to the RTK proxy.

| Event | Command | Purpose |
|---|---|---|
| `Notification` | `printf '\a' > /dev/tty` | Bell when Claude posts a notification. |
| `PermissionRequest` | `printf '\a' > /dev/tty` | Bell when Claude asks for tool permission — useful when the window is in the background. |
| `Stop` | `printf '\a' > /dev/tty` | Bell when the turn finishes, so you can tab away during long runs. |
| `PreToolUse` (matcher: `Bash`) | `rtk hook claude` | Routes Bash invocations through RTK to trim/rewrite output before it reaches the model's context. |

> The bell uses `printf '\a' > /dev/tty` instead of `tput bel` because it rings reliably even when stdout is redirected (fixed in v0.1.6).

### Status line

| Key | Value |
|---|---|
| `statusLine.type` | `command` |
| `statusLine.command` | `$HOME/.claude/statusline-command.sh` |
| `statusLine.refreshInterval` | `1` (seconds) |

`statusline-command.sh` is a Bash script that reads the harness JSON from stdin and renders a Powerline-style status bar showing:
- working directory
- model (short label: `Opus`, `Sonnet`, `Sonnet(1M)`, `Haiku`) + effort level, color-coded
- context window % with formatted input/output token counts (`fmt_tokens` → `k`/`M`)
- 5-hour session window % with absolute reset time
- 7-day quota window % with absolute reset time (and weekday when >24h away)
- git branch / detached-HEAD info, rebase/conflict state, ahead/behind

See `README.md.d/images/my-config.png` for the preview.

### Other behavior flags

| Key | Value | Effect |
|---|---|---|
| `effortLevel` | `low` | Default model effort level (overridden by `/model`). |
| `spinnerTipsEnabled` | `false` | Hide spinner tips. |
| `syntaxHighlightingDisabled` | `true` | Disable syntax highlighting in the TUI. |
| `awaySummaryEnabled` | `false` | No auto-summary when returning to the terminal. |
| `prefersReducedMotion` | `true` | Reduce animation in the TUI. |
| `shell.disable_aliases` | `true` | Run shell commands without sourcing user aliases — keeps tool calls reproducible. |

---

## Skills

Custom slash commands in `skills/<name>/SKILL.md`. Each skill is a Markdown file with YAML frontmatter that Claude Code loads on startup.

### `/code`

Open VS Code in the current working directory.

```
/code
```

Runs `code .` via Bash. Inside VS Code's integrated terminal you can `claude --resume` to continue the same session — sessions are stored under `~/.claude/projects/<project-hash>/`, keyed by the working directory.

---

### `/commit`

Stage explicit files and create a commit with a `Co-Authored-By: Claude` trailer.

```
/commit
```

**Rules enforced by the skill:**
- Never `git add .` or `git add -A` — always an explicit file list (skips gitignored files).
- If `CHANGELOG.md` exists at the repo root: updates the `## [Unreleased]` section (creating it if missing) with one bullet per logical change under `Added` / `Changed` / `Fixed` / `Removed`.
- Subject is a plain imperative sentence (`fix bell hook`, `add THIRD.md`) — **no** Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, …).
- Body is a bullet list explicitly enumerating the changes, referencing files/symbols.
- Always appends `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Refuses to invent a commit when there are no changes.

---

### `/commit-gpg`

Same as `/commit`, but wraps `git commit -S` in an `xterm` so `pinentry-tty` can prompt for the GPG passphrase.

```
/commit-gpg
```

- `xterm -e bash -c '…'` gives `pinentry-tty` a real TTY for the passphrase prompt.
- Inside the xterm: `GPG_TTY=$(tty) git -c gpg.program=gpg -c gpg.pinentry-mode=loopback commit -S …`.
- After the xterm exits, runs `git log -1 --show-signature` to confirm the signature.
- Requires `xterm` (`sudo apt install xterm`); refuses to fall back to an unsigned commit.

---

### `/review`

Senior-engineer-style code review of a file, directory, or recent diff.

```
/review [path or description]
```

If no argument is given, reviews recently modified files (`git diff HEAD` / `git status`). Findings are grouped by severity:

- **Critical** — bugs or security issues that must be fixed.
- **Warning** — likely problems worth addressing.
- **Suggestion** — optional improvements.

Each finding cites `file:line`. Praise, nitpicks, and tutorial-style explanations are skipped.

Dimensions reviewed: correctness (logic, null derefs, edge cases), security (injection, secrets, path traversal), performance (real impact only), and code quality (dead code, error handling at boundaries).

---

### `/tag`

Create an annotated semver git tag and promote `[Unreleased]` in `CHANGELOG.md`.

```
/tag                # patch bump (default)
/tag patch          # 0.1.7 -> 0.1.8
/tag minor          # 0.1.7 -> 0.2.0
/tag major          # 0.1.7 -> 1.0.0
/tag 1.2.3          # explicit version (v-prefix optional)
```

**Behavior:**
- Auto-detects the latest `vX.Y.Z` tag with `git tag -l 'v*.*.*' --sort=-v:refname` and increments accordingly (falls back to `v0.0.0` if none exists).
- If `CHANGELOG.md` exists at the repo root: promotes `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` (today's date), updates any compare-link references at the bottom, then invokes `/commit` to record the release (subject: plain `release vX.Y.Z`).
- Creates the tag as **annotated** (`git tag -a -m "Release vX.Y.Z"`), never lightweight, never with `-f`.
- Refuses to overwrite an existing tag.
- **Never pushes** — reminds you to `git push origin vX.Y.Z` manually when ready.
