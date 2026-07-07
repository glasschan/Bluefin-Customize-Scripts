#!/bin/bash

# setup-fonts.sh
# 安裝 CJK 字體 (MiSans + OPPO Sans) + Droid Sans Mono (等寬) + 可選 GTK 介面字體
# Bluefin (GNOME/Wayland) 版本 — 移植自 omarchy-custom-scripts/setup-fonts.sh
# Category: 系統設定
# Description: 安裝 CJK 字體 (MiSans + OPPO Sans) + Droid Sans Mono + GTK 字體

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

FONT_DIR="$HOME/.local/share/fonts"
FONT_NAME="MiSans"
FONT_SIZE=10

# 字體下載連結
MISANS_URL="https://hyperos.mi.com/font-download/MiSans.zip"
OPPOSANS_URL="https://openfs.oppomobile.com/open/oop/202412/05/0f155015fff7700fbbcef7fa2aad78dc.zip"
# Droid Sans Mono 已從 Google Fonts 目錄下架 (deprecated)，但仍可透過 CSS API 取得 gstatic 直鏈
DROIDSANSMONO_URL="https://fonts.gstatic.com/s/droidsansmono/v21/6NUO8FuJNQ2MbkrZ5-J8lKFrp7phfg.ttf"

# 檢查字體是否已安裝
check_font_installed() {
    fc-list | grep -qi "$1"
}

# 檢查 GTK 字體設定
check_gtk_font() {
    local current_font
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "")
    [[ "$current_font" == *"$FONT_NAME"* ]]
}

# 下載並安裝 MiSans
download_misans() {
    info "下載 MiSans 字體..."
    local temp_dir
    temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/MiSans.zip"

    # hyperos.mi.com 偶爾會在中途斷線 (SSL EOF)，加上重試以提升可靠度
    if ! curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "$zip_file" "$MISANS_URL"; then
        error "下載 MiSans 失敗（已重試 5 次）"
    fi

    info "解壓 MiSans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        error "解壓 MiSans 失敗"
    fi

    local font_file
    font_file=$(find "$temp_dir" -name "MiSansVF.ttf" -o -name "MiSans-VF.ttf" | head -1)

    if [[ -z "$font_file" ]]; then
        error "找不到 MiSansVF.ttf"
    fi

    mkdir -p "$FONT_DIR"
    cp "$font_file" "$FONT_DIR/"
    rm -rf "$temp_dir"

    detail "已安裝: $FONT_DIR/$(basename "$font_file")"
    info "MiSans 安裝完成"
}

# 下載並安裝 OPPO Sans
download_opposans() {
    info "下載 OPPO Sans 字體..."
    local temp_dir
    temp_dir=$(mktemp -d)
    local zip_file="$temp_dir/OPPOSans.zip"

    if ! curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "$zip_file" "$OPPOSANS_URL"; then
        error "下載 OPPO Sans 失敗（已重試 5 次）"
    fi

    info "解壓 OPPO Sans..."
    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        error "解壓 OPPO Sans 失敗"
    fi

    local font_file
    font_file=$(find "$temp_dir" -name "OPPO Sans 4.0.ttf" -o -name "OPPOSans40.ttf" | head -1)

    if [[ -z "$font_file" ]]; then
        error "找不到 OPPO Sans 4.0.ttf"
    fi

    mkdir -p "$FONT_DIR"
    cp "$font_file" "$FONT_DIR/"
    rm -rf "$temp_dir"

    detail "已安裝: $FONT_DIR/$(basename "$font_file")"
    info "OPPO Sans 安裝完成"
}

# 下載並安裝 Droid Sans Mono（等寬字體，直接 TTF，無需解壓）
download_droidsansmono() {
    info "下載 Droid Sans Mono 字體..."
    mkdir -p "$FONT_DIR"

    # gstatic 直鏈需要瀏覽器 UA 才會穩定回應 200
    if ! curl -fL --retry 5 --retry-delay 2 --retry-all-errors \
             -A "Mozilla/5.0" \
             -o "$FONT_DIR/DroidSansMono.ttf" "$DROIDSANSMONO_URL"; then
        error "下載 Droid Sans Mono 失敗（已重試 5 次）"
    fi

    detail "已安裝: $FONT_DIR/DroidSansMono.ttf"
    info "Droid Sans Mono 安裝完成"
}

# 更新字體快取
update_font_cache() {
    info "更新字體快取..."
    fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
    info "字體快取更新完成"
}

# 安裝字體（冪等：已存在則跳過）
install_fonts() {
    info "檢查字體安裝狀態..."

    local need_update=false

    if ! check_font_installed "MiSans"; then
        download_misans
        need_update=true
    else
        info "MiSans 已安裝，跳過"
    fi

    if ! check_font_installed "OPPO Sans"; then
        download_opposans
        need_update=true
    else
        info "OPPO Sans 已安裝，跳過"
    fi

    if ! check_font_installed "Droid Sans Mono"; then
        download_droidsansmono
        need_update=true
    else
        info "Droid Sans Mono 已安裝，跳過"
    fi

    if $need_update; then
        update_font_cache
    fi
}

# 設定 GTK 介面字體為 MiSans（可選，冪等）
setup_gtk_font() {
    info "檢查 GTK 字體設定..."

    if check_gtk_font; then
        info "GTK 字體已設定為 $FONT_NAME，跳過"
        return 0
    fi

    if ! check_font_installed "$FONT_NAME"; then
        warn "$FONT_NAME 字體未安裝，跳過 GTK 字體設定"
        return 0
    fi

    local font_setting="$FONT_NAME $FONT_SIZE"
    local font_bold="$FONT_NAME Bold $FONT_SIZE"

    info "設定 GTK 字體為 $font_setting..."
    gsettings set org.gnome.desktop.interface font-name "$font_setting"
    gsettings set org.gnome.desktop.interface document-font-name "$font_setting"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font "$font_bold"

    detail "Interface font: $(gsettings get org.gnome.desktop.interface font-name)"
    detail "Document font: $(gsettings get org.gnome.desktop.interface document-font-name)"
    detail "Titlebar font: $(gsettings get org.gnome.desktop.wm.preferences titlebar-font)"

    info "GTK 字體設定完成"
}

# 還原字體設定
remove_fonts() {
    info "還原 GTK 字體設定..."
    gsettings reset org.gnome.desktop.interface font-name
    gsettings reset org.gnome.desktop.interface document-font-name
    gsettings reset org.gnome.desktop.wm.preferences titlebar-font

    info "移除字體檔案..."
    rm -f "$FONT_DIR/MiSansVF.ttf" "$FONT_DIR/MiSans-VF.ttf"
    rm -f "$FONT_DIR/OPPO Sans 4.0.ttf" "$FONT_DIR/OPPOSans40.ttf"
    rm -f "$FONT_DIR/DroidSansMono.ttf"
    fc-cache -f >/dev/null 2>&1

    info "字體已移除（如需移除其他自行放入的字體請手動處理）"
}

# 顯示狀態
show_status() {
    echo -e "${CYAN}字體設定狀態:${NC}"

    if check_font_installed "MiSans"; then
        echo -e "  ${GREEN}✓${NC} MiSans 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} MiSans 字體未安裝"
    fi

    if check_font_installed "OPPO Sans"; then
        echo -e "  ${GREEN}✓${NC} OPPO Sans 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} OPPO Sans 字體未安裝"
    fi

    if check_font_installed "Droid Sans Mono"; then
        echo -e "  ${GREEN}✓${NC} Droid Sans Mono 字體已安裝"
    else
        echo -e "  ${RED}✗${NC} Droid Sans Mono 字體未安裝"
    fi

    local current_font
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null || echo "未設定")
    echo -e "  目前 GTK 字體: $current_font"
}

# 安裝模式
install() {
    info "開始設定 CJK 字體..."
    install_fonts
    setup_gtk_font
    info "字體設定完成！"
}

# 解除安裝模式
uninstall() {
    info "開始還原字體設定..."
    remove_fonts
    info "字體設定已還原！"
}

# 使用說明
usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝字體 + GTK 字體 (預設)"
    echo "  -u, --uninstall   還原字體設定 (reset gsettings + 移除字體檔)"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 安裝字體"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
}

# 主程式
main() {
    case "${1:-}" in
        -u|--uninstall)
            uninstall
            ;;
        -s|--status)
            show_status
            ;;
        -h|--help)
            usage
            ;;
        -i|--install|"")
            install
            ;;
        *)
            error "未知選項: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
