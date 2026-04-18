#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ALACRITTY_TOML="${HOME}/.config/alacritty/alacritty.toml"
ZLAUNCH="${HOME}/bin/zlaunch"
ALACRITTY_BIN="/usr/bin/alacritty"
CUSTOM_KEYBINDINGS_ROOT="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
GSETTINGS_BASE="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDINGS_ROOT}"
GSETTINGS_LIST_KEY="org.gnome.settings-daemon.plugins.media-keys"
GSETTINGS_LIST_PROP="custom-keybindings"

ALACRITTY_TOML_CONTENT='[window]
startup_mode = "Maximized"

[font]
normal = { family = "FiraCode Nerd Font", style = "Regular" }
bold = { family = "FiraCode Nerd Font", style = "Bold" }
italic = { family = "FiraCode Nerd Font", style = "Light" }
size = 11.0
'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

ask_yesno() {
    local prompt="$1"
    while true; do
        echo -ne "${YELLOW}[?]${NC} ${prompt} [y/N] "
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]|"") return 1 ;;
        esac
    done
}

check_gnome() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
        error "Not running in a GNOME desktop environment (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
        exit 1
    fi
}

check_alacritty() {
    if command -v alacritty &>/dev/null; then
        info "alacritty found at $(command -v alacritty)"
        return 0
    fi

    if [[ -x "$ALACRITTY_BIN" ]]; then
        info "alacritty found at ${ALACRITTY_BIN}"
        return 0
    fi

    warn "alacritty not found."
    if ! ask_yesno "Install alacritty via rpm-ostree? (requires reboot)"; then
        error "alacritty is required. Aborting."
        exit 1
    fi

    info "Installing alacritty via rpm-ostree..."
    sudo rpm-ostree install alacritty
    warn "alacritty installed. Please reboot and run this script again to complete setup."
    exit 0
}

check_zellij() {
    if command -v zellij &>/dev/null; then
        info "zellij found at $(command -v zellij)"
        return 0
    fi

    warn "zellij not found."
    if ! command -v brew &>/dev/null; then
        error "Homebrew not found. Please install zellij manually."
        exit 1
    fi

    if ! ask_yesno "Install zellij via brew?"; then
        error "zellij is required. Aborting."
        exit 1
    fi

    info "Installing zellij via brew..."
    brew install zellij

    if command -v zellij &>/dev/null; then
        info "zellij installed at $(command -v zellij)"
    else
        error "zellij installation failed. Aborting."
        exit 1
    fi
}

create_zlaunch() {
    local zellij_path
    zellij_path="$(command -v zellij)"

    mkdir -p "$(dirname "$ZLAUNCH")"
    cat > "$ZLAUNCH" <<EOF
#!/bin/sh
exec ${ALACRITTY_BIN} -e ${zellij_path}
EOF
    chmod +x "$ZLAUNCH"
    info "Created ${ZLAUNCH}"
    info "  zellij path: ${zellij_path}"
}

write_alacritty_toml() {
    local toml_dir
    toml_dir="$(dirname "$ALACRITTY_TOML")"

    if [[ -f "$ALACRITTY_TOML" ]]; then
        warn "${ALACRITTY_TOML} already exists:"
        echo "---"
        cat "$ALACRITTY_TOML"
        echo "---"
        if ! ask_yesno "Overwrite?"; then
            info "Skipping alacritty.toml (keeping existing)."
            return 0
        fi
    fi

    mkdir -p "$toml_dir"
    printf '%s' "$ALACRITTY_TOML_CONTENT" > "$ALACRITTY_TOML"
    info "Written ${ALACRITTY_TOML}"
}

parse_custom_slots() {
    gsettings get "$GSETTINGS_LIST_KEY" "$GSETTINGS_LIST_PROP" 2>/dev/null \
        | grep -oP "custom\d+" || true
}

find_custom_slot_by_name() {
    local target_name="$1"
    local slot
    for slot in $(parse_custom_slots); do
        local slot_name
        slot_name=$(gsettings get "${GSETTINGS_BASE}/${slot}/" name 2>/dev/null || echo "''")
        slot_name=$(echo "$slot_name" | tr -d "'")
        if [[ "$slot_name" == "$target_name" ]]; then
            echo "$slot"
            return 0
        fi
    done
    return 1
}

get_next_custom_index() {
    local max_idx=-1
    local slot
    for slot in $(parse_custom_slots); do
        local idx
        idx=$(echo "$slot" | grep -oP 'custom\K[0-9]+' || echo "0")
        if [[ "$idx" -gt "$max_idx" ]]; then
            max_idx="$idx"
        fi
    done
    echo $((max_idx + 1))
}

set_custom_binding() {
    local slot="$1"
    local name="$2"
    local binding="$3"
    local command="$4"

    gsettings set "${GSETTINGS_BASE}/${slot}/" name "$name"
    gsettings set "${GSETTINGS_BASE}/${slot}/" binding "$binding"
    gsettings set "${GSETTINGS_BASE}/${slot}/" command "$command"
}

add_custom_to_list() {
    local new_slot="custom$1"
    local new_path="${CUSTOM_KEYBINDINGS_ROOT}/${new_slot}/"
    local paths
    paths=$(gsettings get "$GSETTINGS_LIST_KEY" "$GSETTINGS_LIST_PROP" 2>/dev/null || echo "[]")

    local new_paths
    if [[ "$paths" == "[]" || "$paths" == "@as []" ]]; then
        new_paths="['${new_path}']"
    else
        new_paths=$(echo "$paths" | sed "s/]$/, '${new_path}']/")
    fi

    gsettings set "$GSETTINGS_LIST_KEY" "$GSETTINGS_LIST_PROP" "$new_paths"
}

setup_gnome_binding() {
    local target_name="Alacritty Zellij"
    local binding='<Super><Alt>Return'
    local command="${ZLAUNCH}"

    local existing_slot
    if existing_slot=$(find_custom_slot_by_name "$target_name"); then
        info "Found existing '${target_name}' at ${existing_slot}, updating..."
        set_custom_binding "$existing_slot" "$target_name" "$binding" "$command"
        info "Updated ${existing_slot}"
    elif existing_slot=$(find_custom_slot_by_name "Ptyxis Alt"); then
        info "Found 'Ptyxis Alt' at ${existing_slot}, replacing..."
        set_custom_binding "$existing_slot" "$target_name" "$binding" "$command"
        info "Replaced ${existing_slot} (Ptyxis Alt → ${target_name})"
    else
        local next_idx
        next_idx=$(get_next_custom_index)
        local new_slot="custom${next_idx}"
        info "No existing slot found, creating ${new_slot}..."
        set_custom_binding "$new_slot" "$target_name" "$binding" "$command"
        add_custom_to_list "$next_idx"
        info "Created ${new_slot}"
    fi
}

do_setup() {
    info "=== Alacritty + Zellij Shortcut Setup ==="
    echo ""

    check_alacritty
    check_zellij
    echo ""

    create_zlaunch
    write_alacritty_toml
    echo ""

    setup_gnome_binding
    echo ""

    info "Setup complete! Press Super+Alt+Enter to launch Alacritty with Zellij."
    warn "You may need to log out and log back in for the shortcut to take effect."
    echo ""

    do_check
}

do_restore() {
    info "=== Restoring defaults ==="
    echo ""

    local slot
    if slot=$(find_custom_slot_by_name "Alacritty Zellij"); then
        set_custom_binding "$slot" "Ptyxis Alt" '<Control><Alt>Return' '/usr/bin/ptyxis --new-window'
        info "Restored ${slot} → Ptyxis Alt (Ctrl+Alt+Enter)"
    else
        warn "No 'Alacritty Zellij' binding found to restore."
    fi

    if [[ -f "$ZLAUNCH" ]]; then
        rm -f "$ZLAUNCH"
        info "Removed ${ZLAUNCH}"
    else
        warn "${ZLAUNCH} not found."
    fi

    if [[ -f "$ALACRITTY_TOML" ]]; then
        rm -f "$ALACRITTY_TOML"
        info "Removed ${ALACRITTY_TOML}"
    else
        warn "${ALACRITTY_TOML} not found."
    fi

    echo ""
    do_check
}

do_check() {
    echo "=== Alacritty ==="
    if command -v alacritty &>/dev/null; then
        echo "  path: $(command -v alacritty)"
        echo "  version: $(alacritty --version 2>/dev/null || echo 'unknown')"
    elif [[ -x "$ALACRITTY_BIN" ]]; then
        echo "  path: ${ALACRITTY_BIN}"
        echo "  version: $(${ALACRITTY_BIN} --version 2>/dev/null || echo 'unknown')"
    else
        echo "  not installed"
    fi

    echo ""
    echo "=== Zellij ==="
    if command -v zellij &>/dev/null; then
        echo "  path: $(command -v zellij)"
        echo "  version: $(zellij --version 2>/dev/null || echo 'unknown')"
    else
        echo "  not installed"
    fi

    echo ""
    echo "=== zlaunch ==="
    if [[ -f "$ZLAUNCH" ]]; then
        echo "  path: ${ZLAUNCH}"
        echo "  content:"
        sed 's/^/    /' "$ZLAUNCH"
    else
        echo "  not found"
    fi

    echo ""
    echo "=== GNOME Custom Binding (Alacritty Zellij) ==="
    local slot
    if slot=$(find_custom_slot_by_name "Alacritty Zellij"); then
        echo "  slot: ${slot}"
        echo "  name: $(gsettings get "${GSETTINGS_BASE}/${slot}/" name)"
        echo "  binding: $(gsettings get "${GSETTINGS_BASE}/${slot}/" binding)"
        echo "  command: $(gsettings get "${GSETTINGS_BASE}/${slot}/" command)"
    else
        echo "  not configured"
    fi

    echo ""
    echo "=== alacritty.toml ==="
    if [[ -f "$ALACRITTY_TOML" ]]; then
        sed 's/^/  /' "$ALACRITTY_TOML"
    else
        echo "  not found"
    fi
}

usage() {
    cat <<EOF
Alacritty + Zellij GNOME Shortcut Setup

Bind Super+Alt+Enter to launch Alacritty maximized with Zellij.

Usage: $(basename "$0") [COMMAND]

Commands:
  --setup     Install and configure everything (default)
  --restore   Restore original Ptyxis Alt binding and remove files
  --check     Show current status
  --help      Show this help message

What --setup does:
  1. Install alacritty via rpm-ostree (if missing, requires reboot)
  2. Install zellij via brew (if missing, asks first)
  3. Create ~/bin/zlaunch wrapper script
  4. Write ~/.config/alacritty/alacritty.toml (asks before overwrite)
  5. Bind Super+Alt+Enter to launch Alacritty + Zellij

Keybinding:
  Super+Alt+Enter    Launch Alacritty (maximized) with Zellij
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
