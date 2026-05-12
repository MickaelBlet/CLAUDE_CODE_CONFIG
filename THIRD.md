# Third-Party Dependencies

This project depends on the following third-party software.

## Runtime Dependencies

| Name | Purpose | Source | License |
|------|---------|--------|---------|
| Claude Code | Anthropic CLI agent (target of this configuration) | https://claude.ai/install.sh | Proprietary (Anthropic) |
| RTK (Rust Token Killer) | Token-optimized CLI proxy used via hooks | https://github.com/rtk-ai/rtk | See upstream repo |

## Installer Dependencies (system tools)

| Name | Purpose | License |
|------|---------|---------|
| curl | Download installer scripts and archives | MIT/X |
| tar | Extract config archive | GPL |
| sh / bash | Execute install scripts | GPL |
| git | Version control (recommended) | GPL-2.0 |

## Notes

- This repository contains shell scripts and configuration files only; no compiled or vendored third-party code is bundled.
- Each dependency is fetched at install time from its upstream source and is governed by its own license.
