---
name: review
description: Review code for bugs, security issues, style, and best practices. Use when the user says "review", "review my code", "check my code", "code review", or wants feedback on their implementation.
argument-hint: "file or description"
allowed-tools: [Read, Glob, Grep, Bash]
---

# Code Review

The user wants a code review. Arguments: $ARGUMENTS

## Instructions

1. **Identify what to review**
   - If `$ARGUMENTS` is a file path, read that file
   - If no arguments, ask which file(s) or read recently modified files via `git diff HEAD` or `git status`
   - If a directory, glob for source files

2. **Review across these dimensions** (only report real issues, skip nitpicks):

   ### Bugs & Correctness
   - Logic errors, off-by-one, null/undefined dereferences
   - Incorrect assumptions about inputs or state
   - Missing edge cases

   ### Security
   - Injection vulnerabilities (SQL, command, XSS)
   - Hardcoded secrets or credentials
   - Unsafe deserialization, path traversal, insecure defaults

   ### Performance
   - Obvious inefficiencies (N+1 queries, unnecessary allocations, blocking calls)
   - Only flag if the impact is meaningful

   ### Code Quality
   - Dead code, unreachable branches
   - Overly complex logic that could be simplified
   - Missing error handling at system boundaries

3. **Format your output**

   Group findings by severity:

   - **Critical** — bugs or security issues that must be fixed
   - **Warning** — likely problems worth addressing
   - **Suggestion** — optional improvements

   For each finding, cite the file and line number.

4. **Be concise** — skip praise, skip obvious things, don't repeat what the code already says. A senior engineer's review, not a tutorial.

## Example Output Format

```
**Critical**
- `auth.js:42` — JWT secret falls back to empty string if env var is unset; any token will verify

**Warning**
- `db.js:88` — query result is never checked for null before `.rows[0]` access

**Suggestion**
- `utils.js:15` — `Array.from(set)` allocates unnecessarily; spread `[...set]` is equivalent and slightly cleaner
```

If no issues found, say so briefly.
