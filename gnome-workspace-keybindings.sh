#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

check_gnome() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
        error "Not running in a GNOME desktop environment (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
        exit 1
    fi
}

do_setup() {
    info "Unbinding Super+1~9 from dock app switching..."
    for i in {1..9}; do
        gsettings set org.gnome.shell.keybindings "switch-to-application-$i" "[]"
    done
    info "Dock app switching bindings cleared."

    info "Setting Super+1~9 → Workspace 1-9, Super+0 → Workspace 10..."
    for i in {1..9}; do
        gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "['<Super>$i']"
    done
    gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-10 "['<Super>0', '<Super>KP_0']"
    info "Workspace switch keybindings set."

    info "Setting Super+Shift+1~9 → Move to Workspace 1-9, Super+Shift+0 → Move to Workspace 10..."
    for i in {1..9}; do
        gsettings set org.gnome.desktop.wm.keybindings "move-to-workspace-$i" "['<Super><Shift>$i']"
    done
    gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-10 "['<Super><Shift>0']"
    info "Move window keybindings set."

    do_fix_dock
    echo ""
    do_check
}

do_restore() {
    info "Restoring GNOME defaults..."

    for i in {1..9}; do
        gsettings set org.gnome.shell.keybindings "switch-to-application-$i" "['<Super>$i']"
    done
    info "Dock app switching restored."

    for i in {1..10}; do
        gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "[]"
        gsettings set org.gnome.desktop.wm.keybindings "move-to-workspace-$i" "[]"
    done
    info "Workspace keybindings cleared."

    echo ""
    do_check
}

do_check() {
    echo "=== Switch to Workspace ==="
    for i in {1..10}; do
        val=$(gsettings get org.gnome.desktop.wm.keybindings "switch-to-workspace-$i")
        echo "  switch-to-workspace-$i: $val"
    done

    echo ""
    echo "=== Move to Workspace ==="
    for i in {1..10}; do
        val=$(gsettings get org.gnome.desktop.wm.keybindings "move-to-workspace-$i")
        echo "  move-to-workspace-$i: $val"
    done

    echo ""
    echo "=== Dash-to-Dock ==="
    local dock_hk
    dock_hk=$(dconf read /org/gnome/shell/extensions/dash-to-dock/hot-keys 2>/dev/null || echo "not configured")
    local dock_ack
    dock_ack=$(dconf read /org/gnome/shell/extensions/dash-to-dock/app-ctrl-hot-keys 2>/dev/null || echo "not configured")
    echo "  hot-keys: $dock_hk"
    echo "  app-ctrl-hot-keys: $dock_ack"

    echo ""
    echo "=== Dock App Switching (should be empty) ==="
    for i in {1..9}; do
        val=$(gsettings get org.gnome.shell.keybindings "switch-to-application-$i")
        echo "  switch-to-application-$i: $val"
    done
}

do_fix_dock() {
    # GNOME 45+ Dash to Dock stores hot-keys in dconf, not gsettings
    local hot_keys
    hot_keys=$(dconf read /org/gnome/shell/extensions/dash-to-dock/hot-keys 2>/dev/null || echo "not available")

    if [[ "$hot_keys" == "true" ]]; then
        warn "dash-to-dock hot-keys is enabled — disabling to prevent conflicts..."
        dconf write /org/gnome/shell/extensions/dash-to-dock/hot-keys false
        info "dash-to-dock hot-keys disabled."
    else
        info "dash-to-dock hot-keys is already disabled (no conflict)."
    fi

    local app_ctrl
    app_ctrl=$(dconf read /org/gnome/shell/extensions/dash-to-dock/app-ctrl-hot-keys 2>/dev/null || echo "not available")
    if [[ "$app_ctrl" == "true" ]]; then
        warn "dash-to-dock app-ctrl-hot-keys is enabled — disabling to prevent Super+0 conflict..."
        dconf write /org/gnome/shell/extensions/dash-to-dock/app-ctrl-hot-keys false
        info "dash-to-dock app-ctrl-hot-keys disabled."
    else
        info "dash-to-dock app-ctrl-hot-keys is already disabled (no conflict)."
    fi
}

usage() {
    cat <<EOF
GNOME Super+Number Workspace Keybindings

Usage: $(basename "$0") [COMMAND]

Commands:
  --setup     Set up Super+1~0 for workspace switching (default)
  --restore   Restore GNOME default keybindings
  --check     Show current keybinding status
  --fix-dock  Disable dash-to-dock hot-keys to prevent conflicts
  --help      Show this help message

Keybindings after --setup:
  Super+1 ~ Super+0           Switch to Workspace 1-10
  Super+Shift+1 ~ Super+0     Move window to Workspace 1-10
EOF
}

check_gnome

case "${1:---setup}" in
    --setup)    do_setup   ;;
    --restore)  do_restore ;;
    --check)    do_check   ;;
    --fix-dock) do_fix_dock ;;
    --help|-h)  usage      ;;
    *)          error "Unknown option: $1"; usage; exit 1 ;;
esac
