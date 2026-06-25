#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PTYXIS_BIN="/usr/bin/ptyxis"
BINDING_NAME="Super Enter Ptyxis"
BINDING_KEY='<Super>Return'
CUSTOM_KEYBINDINGS_ROOT="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
GSETTINGS_BASE="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${CUSTOM_KEYBINDINGS_ROOT}"
GSETTINGS_LIST_KEY="org.gnome.settings-daemon.plugins.media-keys"
GSETTINGS_LIST_PROP="custom-keybindings"

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

check_gnome() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
        error "Not running in a GNOME desktop environment (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})"
        exit 1
    fi
}

check_ptyxis() {
    if [[ ! -x "$PTYXIS_BIN" ]]; then
        error "Ptyxis not found at ${PTYXIS_BIN}. Is Bluefin installed correctly?"
        exit 1
    fi
    info "Ptyxis found at ${PTYXIS_BIN}"
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
        new_paths=$(echo "$paths" | sed "s|]$|, '${new_path}']|")
    fi

    gsettings set "$GSETTINGS_LIST_KEY" "$GSETTINGS_LIST_PROP" "$new_paths"
}

remove_custom_from_list() {
    local target_slot="$1"
    local paths
    paths=$(gsettings get "$GSETTINGS_LIST_KEY" "$GSETTINGS_LIST_PROP" 2>/dev/null || echo "[]")

    # Rebuild the list excluding the target slot, using Python for clean array handling
    local new_paths
    new_paths=$(python3 - "$paths" "$CUSTOM_KEYBINDINGS_ROOT" "$target_slot" <<'PY'
import sys, ast
paths_str = sys.argv[1]
root = sys.argv[2]
slot = sys.argv[3]
target_path = root + "/" + slot + "/"
try:
    a = ast.literal_eval(paths_str) if paths_str not in ("[]", "@as []") else []
except Exception:
    a = []
a = [p for p in a if p != target_path]
if not a:
    print("[]")
else:
    print("[" + ", ".join("'%s'" % p for p in a) + "]")
PY
)

    gsettings set "$GSETTINGS_LIST_KEY" "$GSETTINGS_LIST_PROP" "$new_paths"
}

do_setup() {
    info "=== Super+Enter → Ptyxis ==="
    echo ""

    check_ptyxis
    echo ""

    local existing_slot
    if existing_slot=$(find_custom_slot_by_name "$BINDING_NAME"); then
        info "Found existing '${BINDING_NAME}' at ${existing_slot}, updating..."
        set_custom_binding "$existing_slot" "$BINDING_NAME" "$BINDING_KEY" "$PTYXIS_BIN"
        info "Updated ${existing_slot}"
    else
        local next_idx
        next_idx=$(get_next_custom_index)
        local new_slot="custom${next_idx}"
        info "No existing slot found, creating ${new_slot}..."
        set_custom_binding "$new_slot" "$BINDING_NAME" "$BINDING_KEY" "$PTYXIS_BIN"
        add_custom_to_list "$next_idx"
        info "Created ${new_slot}"
    fi

    echo ""
    info "Done! Press Super+Enter to launch Ptyxis."
    warn "You may need to log out and back in for the shortcut to take effect."
    echo ""

    do_check
}

do_restore() {
    info "=== Restoring — removing Super+Enter Ptyxis ==="
    echo ""

    local slot
    if slot=$(find_custom_slot_by_name "$BINDING_NAME"); then
        remove_custom_from_list "$slot"
        info "Removed ${slot} from custom-keybindings list"
    else
        warn "No '${BINDING_NAME}' binding found. Nothing to restore."
    fi

    echo ""
    do_check
}

do_check() {
    echo "=== Super+Enter Ptyxis Binding ==="

    local slot
    if slot=$(find_custom_slot_by_name "$BINDING_NAME"); then
        echo "  slot: ${slot}"
        echo "  name: $(gsettings get "${GSETTINGS_BASE}/${slot}/" name)"
        echo "  binding: $(gsettings get "${GSETTINGS_BASE}/${slot}/" binding)"
        echo "  command: $(gsettings get "${GSETTINGS_BASE}/${slot}/" command)"
    else
        echo "  not configured"
    fi

    echo ""
    echo "=== Ptyxis Binary ==="
    if [[ -x "$PTYXIS_BIN" ]]; then
        echo "  ${PTYXIS_BIN}"
    else
        echo "  not found"
    fi
}

usage() {
    cat <<EOF
Bind Super+Enter to launch Ptyxis terminal.

Usage: $(basename "$0") [COMMAND]

Commands:
  --setup     Create or update the Super+Enter → Ptyxis binding (default)
  --restore   Remove the Super+Enter binding
  --check     Show current status
  --help      Show this help message

Keybinding:
  Super+Enter    Launch Ptyxis terminal
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
