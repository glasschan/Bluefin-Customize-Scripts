#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

KEYD_VER="2.6.0"
KEYD_TARBALL_URL="https://github.com/rvaiya/keyd/archive/refs/tags/v${KEYD_VER}.tar.gz"
KEYD_BIN="/usr/local/bin/keyd"
KEYD_SERVICE="/usr/lib/systemd/system/keyd.service"
KEYD_CONFIG="/etc/keyd/default.conf"
KEYD_BUILD_DIR="/tmp/keyd-build-${KEYD_VER}"

# Internal keyboard name detected from system
KEYBOARD_NAME="AT Translated Set 2 keyboard"

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

check_gnome() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
        error "Not running in a GNOME desktop environment (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
        exit 1
    fi
}

check_prerequisites() {
    if ! command -v gcc &>/dev/null; then
        error "gcc not found. Install build tools: sudo rpm-ostree install gcc make"
        exit 1
    fi
    if ! command -v make &>/dev/null; then
        error "make not found. Install build tools: sudo rpm-ostree install make"
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        error "curl not found"
        exit 1
    fi
    info "Build prerequisites found (gcc + make)"
}

install_keyd() {
    if [[ -x "$KEYD_BIN" ]] && [[ -f "$KEYD_SERVICE" ]]; then
        local ver
        ver=$("$KEYD_BIN" --version 2>/dev/null | head -1 || echo "unknown")
        info "keyd already installed (${ver}), skipping build"
        return 0
    fi

    info "Downloading keyd v${KEYD_VER}..."
    mkdir -p "$KEYD_BUILD_DIR"
    curl -fL "$KEYD_TARBALL_URL" | tar xz --strip-components=1 -C "$KEYD_BUILD_DIR"

    info "Building keyd..."
    make -C "$KEYD_BUILD_DIR"

    info "Installing keyd (needs sudo)..."
    sudo make -C "$KEYD_BUILD_DIR" install

    rm -rf "$KEYD_BUILD_DIR"
    info "keyd v${KEYD_VER} installed at ${KEYD_BIN}"
}

write_config() {
    info "Writing keyd config for internal keyboard..."

    if [[ -f "$KEYD_CONFIG" ]] && grep -q "leftmeta" "$KEYD_CONFIG" 2>/dev/null; then
        info "Config already exists with swap settings, skipping"
        return 0
    fi

    sudo mkdir -p "$(dirname "$KEYD_CONFIG")"
    sudo tee "$KEYD_CONFIG" > /dev/null << EOF
[ids]
${KEYBOARD_NAME}

[main]
leftalt = leftmeta
leftmeta = leftalt
EOF

    info "Written ${KEYD_CONFIG}"
    detail "Applies to: ${KEYBOARD_NAME}"
    detail "  leftalt  → leftmeta (Alt acts as Super)"
    detail "  leftmeta → leftalt  (Super acts as Alt)"
}

enable_service() {
    info "Enabling keyd service..."

    if systemctl --quiet is-active keyd 2>/dev/null; then
        info "keyd service already active, reloading config..."
        sudo systemctl restart keyd
        return 0
    fi

    sudo systemctl enable --now keyd
    info "keyd service enabled and started"
}

do_setup() {
    info "=== Per-device Alt/Super swap (keyd) ==="
    echo ""

    check_prerequisites
    echo ""

    install_keyd
    echo ""

    write_config
    echo ""

    enable_service
    echo ""

    info "Swap active on internal keyboard (${KEYBOARD_NAME})"
    info "  Alt key  → acts as Super"
    info "  Super key → acts as Alt"
    info "External keyboards unaffected."
    warn "If keyd conflicts with anything, run --restore to disable."
    echo ""

    do_check
}

do_restore() {
    info "=== Restoring — disabling keyd swap ==="
    echo ""

    if systemctl --quiet is-active keyd 2>/dev/null; then
        sudo systemctl disable --now keyd
        info "keyd service disabled and stopped"
    else
        warn "keyd service not active, skipping"
    fi

    if [[ -f "$KEYD_CONFIG" ]]; then
        sudo rm -f "$KEYD_CONFIG"
        info "Removed ${KEYD_CONFIG}"
    else
        warn "No config file found, skipping"
    fi

    if [[ -x "$KEYD_BIN" ]]; then
        info "Uninstalling keyd binary..."
        sudo rm -f /usr/local/bin/keyd
        sudo rm -f /usr/local/bin/keyd-application-mapper
        sudo rm -f /usr/lib/systemd/system/keyd.service
        sudo rm -rf /usr/local/share/keyd
        sudo rm -f /usr/share/man/man1/keyd.1.gz
        sudo systemctl daemon-reload
        info "keyd uninstalled"
    else
        warn "keyd binary not found, skipping uninstall"
    fi

    echo ""
    info "Swap disabled. Internal keyboard back to normal."
    echo ""
    do_check
}

do_check() {
    echo "=== keyd Binary ==="
    if [[ -x "$KEYD_BIN" ]]; then
        local ver
        ver=$("$KEYD_BIN" --version 2>/dev/null | head -1 || echo "unknown")
        echo "  ${KEYD_BIN} (${ver})"
    else
        echo "  not installed"
    fi

    echo ""
    echo "=== keyd Service ==="
    if systemctl --quiet is-active keyd 2>/dev/null; then
        echo "  active (running)"
    elif systemctl --quiet is-enabled keyd 2>/dev/null; then
        echo "  enabled (not running)"
    else
        echo "  not enabled"
    fi

    echo ""
    echo "=== Config (${KEYD_CONFIG}) ==="
    if [[ -f "$KEYD_CONFIG" ]]; then
        sed 's/^/  /' "$KEYD_CONFIG"
    else
        echo "  not found"
    fi

    echo ""
    echo "=== Current xkb-options (GNOME global) ==="
    echo "  $(gsettings get org.gnome.desktop.input-sources xkb-options)"
}

usage() {
    cat <<EOF
Swap Alt and Super keys on laptop internal keyboard only.

Uses keyd (https://github.com/rvaiya/keyd) — a per-device input remapper.
External keyboards are NOT affected.

Usage: $(basename "$0") [COMMAND]

Commands:
  --setup     Build, install, and enable keyd swap (default)
  --restore   Disable keyd and remove config
  --check     Show current status
  --help      Show this help message

Target device:
  ${KEYBOARD_NAME}
EOF
}

check_gnome

case "${1:---setup}" in
    --setup)    do_setup   ;;
    --restore)  do_restore ;;
    --check)    do_check   ;;
    --help|-h)  usage      ;;
    *)          error "Unknown option: $1"; usage; exit 1 ;;
esac
