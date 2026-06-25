#!/bin/bash
#
# common.sh - Shared helper functions for bluefin-custom-scripts
#
# Bluefin variant of the omarchy-custom-scripts common library.
# Logging/util functions are identical; package management is rpm/ostree-based
# instead of pacman/paru/yay.
#
# Note: no `set -e` — sourced by scripts where strict exit-on-error breaks
# grep-based guards (grep returns 1 when no match).

# ========================================
# Color definitions
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ========================================
# Logging functions
# ========================================

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

detail() {
    echo -e "${BLUE}[DETAIL]${NC} $1"
}

header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# ========================================
# Package management (rpm / rpm-ostree)
# ========================================

# Check whether an rpm package is installed on the host image.
check_package() {
    rpm -q "$1" >/dev/null 2>&1
}

# Install one or more rpm packages onto the immutable Bluefin image.
# rpm-ostree layering requires a reboot to take effect — we warn but do not reboot.
install_rpm() {
    local pkgs=("$@")
    local missing=()
    for pkg in "${pkgs[@]}"; do
        if check_package "$pkg"; then
            info "$pkg 已安裝，跳過"
        else
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    info "透過 rpm-ostree 安裝: ${missing[*]}..."
    if command -v rpm-ostree >/dev/null 2>&1; then
        rpm-ostree install --idempotent --allow-inactive "${missing[@]}" || {
            warn "rpm-ostree install 失敗，請手動執行: sudo rpm-ostree install ${missing[*]}"
            return 1
        }
        warn "rpm-ostree layering 需要重新開機才會生效。請 reboot 後再執行此腳本完成設定。"
    else
        warn "找不到 rpm-ostree，請手動安裝: ${missing[*]}"
        return 1
    fi
}

# ========================================
# Common utilities
# ========================================

confirm() {
    read -p "$1 (y/N): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

config_contains() {
    local file="$1"
    local pattern="$2"
    [[ -f "$file" ]] && grep -q "$pattern" "$file"
}

ensure_dir() {
    mkdir -p "$(dirname "$1")"
}

create_backup() {
    local file="$1"
    local backup_file="${file}.bak.$(date +%s)"
    if [[ -f "$file" ]]; then
        cp "$file" "$backup_file"
        detail "已備份原始設定: $backup_file"
    fi
}

# Standard usage template (scripts can append their own examples)
usage_template() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTION]

Options:
  -i, --install     安裝/設定 (預設)
  -u, --uninstall   還原設定
  -s, --status      顯示目前狀態
  -h, --help        顯示此說明

Examples:
  $SCRIPT_NAME              # 安裝/設定
  $SCRIPT_NAME -u           # 還原設定
  $SCRIPT_NAME -s           # 檢查狀態
EOF
}
