#!/usr/bin/env sh
# CLAUDE_CODE_CONFIG installer - https://github.com/MickaelBlet/CLAUDE_CODE_CONFIG
# Usage: curl -fsSL https://raw.githubusercontent.com/MickaelBlet/CLAUDE_CODE_CONFIG/refs/heads/master/install.sh | sh

set -e

REPO="MickaelBlet/CLAUDE_CODE_CONFIG"
BRANCH="${CLAUDE_CONFIG_BRANCH:-master}"
INSTALL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; exit 1; }

check_deps() {
    for cmd in curl tar; do
        command -v "$cmd" >/dev/null 2>&1 || error "Required command not found: $cmd"
    done
}

install_claude_code() {
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
}

install_rtk() {
    info "Installing RTK (Rust Token Killer)..."
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    rtk init -g
}

install_config() {
    info "Fetching config from ${REPO}@${BRANCH}..."
    TEMP_DIR=$(mktemp -d)
    ARCHIVE="${TEMP_DIR}/config.tar.gz"
    URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"

    if ! curl -fsSL "$URL" -o "$ARCHIVE"; then
        rm -rf "$TEMP_DIR"
        error "Failed to download archive: $URL"
    fi

    tar -xzf "$ARCHIVE" -C "$TEMP_DIR"
    SRC_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -d "$SRC_DIR" ] || { rm -rf "$TEMP_DIR"; error "Extracted source directory not found"; }

    mkdir -p "$INSTALL_DIR"

    if [ -f "$INSTALL_DIR/settings.json" ] && [ ! -f "$INSTALL_DIR/settings.json.bak" ]; then
        info "Backing up existing settings.json -> settings.json.bak"
        cp "$INSTALL_DIR/settings.json" "$INSTALL_DIR/settings.json.bak"
    fi

    info "Installing config to ${INSTALL_DIR}"
    # Copy contents (including dotfiles) but skip VCS metadata
    (cd "$SRC_DIR" && tar -cf - \
        --exclude='.git' --exclude='.github' --exclude='.gitignore' \
        .) | (cd "$INSTALL_DIR" && tar -xf -)

    [ -f "$INSTALL_DIR/install.sh" ] && chmod +x "$INSTALL_DIR/install.sh"
    [ -f "$INSTALL_DIR/statusline-command.sh" ] && chmod +x "$INSTALL_DIR/statusline-command.sh"

    rm -rf "$TEMP_DIR"
}

verify() {
    if command -v claude >/dev/null 2>&1; then
        info "claude: $(claude --version 2>/dev/null || echo installed)"
    else
        warn "claude not in PATH"
    fi
    if command -v rtk >/dev/null 2>&1; then
        info "rtk: $(rtk --version 2>/dev/null || echo installed)"
    else
        warn "rtk not in PATH (add \$HOME/.local/bin to PATH)"
    fi
}

main() {
    check_deps
    install_claude_code
    install_rtk
    install_config
    verify
    echo ""
    info "Installation complete! Config installed at ${INSTALL_DIR}"
}

main
