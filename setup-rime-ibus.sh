#!/bin/bash

# setup-rime-ibus.sh
# 設定 ibus-rime + 快速倉頡 (scj6) — Bluefin (GNOME/Wayland) 版本
# 移植自 omarchy-custom-scripts/setup-input.sh（fcitx5 → ibus）
# Category: 輸入法
# Description: 安裝 ibus-rime + 快速倉頡

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
source "$SCRIPT_DIR/lib/common.sh"

# ibus-rime 的使用者資料目錄（Fedora/GNOME）
RIME_DIR="$HOME/.config/ibus/rime"
GSETTINGS_SOURCES="org.gnome.desktop.input-sources sources"

# ========================================
# 套件
# ========================================

setup_ibus_rime() {
    info "檢查 ibus-rime..."
    if check_package "ibus-rime"; then
        info "ibus-rime 已安裝，跳過"
        return 0
    fi

    if ! check_package "ibus"; then
        warn "ibus 未安裝。GNOME 通常已內建 ibus，若未安裝請先安裝 ibus。"
    fi

    install_rpm "ibus-rime"

    # rpm-ostree layering 需重開機才會生效；若剛裝完仍未載入，提示重開機
    if ! check_package "ibus-rime"; then
        warn "ibus-rime 尚未在當前 session 生效（rpm-ostree 需重開機）。"
        warn "請 reboot 後重新執行：$SCRIPT_NAME -i"
        return 1
    fi
}

# ========================================
# rime-scj（快速倉頡方案）
# ========================================

check_rime_scj() {
    [[ -f "$RIME_DIR/scj6.schema.yaml" ]]
}

setup_rime_scj() {
    info "檢查 rime-scj..."

    if check_rime_scj; then
        info "rime-scj 已安裝，跳過"
        return 0
    fi

    info "下載並安裝 rime-scj..."
    mkdir -p "$RIME_DIR"

    local temp_dir
    temp_dir=$(mktemp -d)
    if ! git clone --depth 1 https://github.com/rime/rime-scj.git "$temp_dir"; then
        rm -rf "$temp_dir"
        error "git clone rime-scj 失敗"
    fi

    cp "$temp_dir"/*.yaml "$RIME_DIR/"
    rm -rf "$temp_dir"

    detail "已安裝檔案:"
    ls -1 "$RIME_DIR"/scj6.* 2>/dev/null | sed 's/^/  /'

    info "rime-scj 安裝完成"
}

remove_rime_scj() {
    info "移除 rime-scj..."
    rm -f "$RIME_DIR"/scj6.*
    info "rime-scj 已移除"
}

# ========================================
# scj6.custom.yaml（預設英文模式）
# ========================================

check_scj6_custom() {
    if [[ -f "$RIME_DIR/scj6.custom.yaml" ]]; then
        grep -q "ascii_mode" "$RIME_DIR/scj6.custom.yaml" && \
        grep -q "reset: 1" "$RIME_DIR/scj6.custom.yaml"
    else
        return 1
    fi
}

setup_scj6_custom() {
    info "檢查 scj6.custom.yaml..."

    if check_scj6_custom; then
        info "scj6.custom.yaml 已設定，跳過"
        return 0
    fi

    info "建立 scj6.custom.yaml..."
    mkdir -p "$RIME_DIR"

    cat > "$RIME_DIR/scj6.custom.yaml" << 'EOF'
patch:
  switches:
    - name: ascii_mode
      reset: 1
      states: [ 中文, 西文 ]
EOF

    detail "scj6.custom.yaml 內容:"
    cat "$RIME_DIR/scj6.custom.yaml" | sed 's/^/  /'

    info "scj6.custom.yaml 建立完成"
}

remove_scj6_custom() {
    info "移除 scj6.custom.yaml..."
    rm -f "$RIME_DIR/scj6.custom.yaml"
    info "scj6.custom.yaml 已移除"
}

# ========================================
# default.custom.yaml（方案清單 + 切換鍵）
# ========================================

check_default_custom() {
    if [[ -f "$RIME_DIR/default.custom.yaml" ]]; then
        grep -q "schema: scj6" "$RIME_DIR/default.custom.yaml" && \
        grep -q "schema: cangjie5" "$RIME_DIR/default.custom.yaml" && \
        grep -q "ascii_composer" "$RIME_DIR/default.custom.yaml" && \
        grep -q "switcher" "$RIME_DIR/default.custom.yaml"
    else
        return 1
    fi
}

setup_default_custom() {
    info "檢查 default.custom.yaml..."

    if check_default_custom; then
        info "default.custom.yaml 已設定，跳過"
        return 0
    fi

    info "建立 default.custom.yaml..."
    mkdir -p "$RIME_DIR"

    cat > "$RIME_DIR/default.custom.yaml" << 'EOF'
patch:
  schema_list:
    - schema: scj6
    - schema: cangjie5
    - schema: luna_pinyin
  menu:
    page_size: 5
  switcher:
    hotkeys:
      - F4
  ascii_composer:
    switch_key:
      Shift_L: noop
      Shift_R: commit_code
      Control_L: noop
      Control_R: noop
      Caps_Lock: noop
      Eisu_toggle: noop
EOF

    detail "default.custom.yaml 內容:"
    cat "$RIME_DIR/default.custom.yaml" | sed 's/^/  /'

    info "default.custom.yaml 建立完成"
}

remove_default_custom() {
    info "移除 default.custom.yaml..."
    rm -f "$RIME_DIR/default.custom.yaml"
    info "default.custom.yaml 已移除"
}

# ========================================
# GNOME input-source 設定（冪等，保留既有來源）
# ========================================

# gsettings 回傳格式如 [('xkb', 'us'), ('ibus', 'chewing')]
# 此為合法 Python literal，可直接 eval 處理。

get_gnome_sources() {
    gsettings get $GSETTINGS_SOURCES 2>/dev/null
}

check_rime_in_sources() {
    local cur
    cur=$(get_gnome_sources)
    grep -q "'ibus', 'rime'" <<<"$cur"
}

# 將 ('ibus','rime') 加入來源清單（若不存在）
setup_gnome_source() {
    info "檢查 GNOME 輸入來源..."

    if check_rime_in_sources; then
        info "Rime 已在輸入來源中，跳過"
        return 0
    fi

    info "將 Rime 加入 GNOME 輸入來源（保留既有來源）..."

    local cur
    cur=$(get_gnome_sources)
    if [[ -z "$cur" ]]; then
        cur="[]"
    fi

    # 用 python 解析 GVariant 文字格式並 append，保持原有元素順序
    local new_val
    new_val=$(python3 - "$cur" <<'PY'
import sys, ast
raw = sys.argv[1]
try:
    a = ast.literal_eval(raw)
except Exception:
    a = []
entry = ('ibus', 'rime')
if entry not in a:
    a.append(entry)
# 輸出為 GVariant a(ss) 文字格式
print("[" + ", ".join("('%s', '%s')" % (k, v) for k, v in a) + "]")
PY
)
    if [[ -z "$new_val" ]]; then
        error "解析 GNOME 輸入來源失敗"
    fi

    gsettings set $GSETTINGS_SOURCES "$new_val"
    detail "輸入來源: $(get_gnome_sources)"
    info "Rime 已加入輸入來源"
}

# 從來源清單移除 ('ibus','rime')
remove_gnome_source() {
    info "從 GNOME 輸入來源移除 Rime..."

    if ! check_rime_in_sources; then
        info "Rime 不在輸入來源中，跳過"
        return 0
    fi

    local cur
    cur=$(get_gnome_sources)

    local new_val
    new_val=$(python3 - "$cur" <<'PY'
import sys, ast
raw = sys.argv[1]
try:
    a = ast.literal_eval(raw)
except Exception:
    a = []
a = [t for t in a if t != ('ibus', 'rime')]
print("[" + ", ".join("('%s', '%s')" % (k, v) for k, v in a) + "]")
PY
)

    gsettings set $GSETTINGS_SOURCES "$new_val"
    detail "輸入來源: $(get_gnome_sources)"
    info "Rime 已從輸入來源移除"
}

# ========================================
# 重新部署 Rime
# ========================================

redeploy_rime() {
    info "重新部署 Rime..."

    rm -rf "$RIME_DIR/build"

    # ibus-rime 在 ibus 重新載入時會自動部署
    if command -v ibus >/dev/null 2>&1; then
        info "重新啟動 ibus..."
        ibus restart 2>/dev/null || true
        sleep 1
    else
        warn "找不到 ibus 指令"
    fi

    local count=0
    while [[ $count -lt 10 ]]; do
        if [[ -d "$RIME_DIR/build" ]] && [[ -f "$RIME_DIR/build/scj6.schema.yaml" ]]; then
            info "Rime 部署完成"
            return 0
        fi
        sleep 1
        ((count++))
    done

    warn "等待 Rime 部署超時。請登出再登入（或手動執行 `ibus restart`）以觸發部署。"
}

# ========================================
# 顯示狀態
# ========================================

show_status() {
    echo -e "${CYAN}ibus-rime 狀態:${NC}"

    if check_package "ibus-rime"; then
        echo -e "  ${GREEN}✓${NC} ibus-rime 已安裝"
    else
        echo -e "  ${RED}✗${NC} ibus-rime 未安裝（執行 rpm-ostree install ibus-rime 並重開機）"
    fi

    if check_rime_scj; then
        echo -e "  ${GREEN}✓${NC} rime-scj 已安裝"
    else
        echo -e "  ${RED}✗${NC} rime-scj 未安裝"
    fi

    if check_scj6_custom; then
        echo -e "  ${GREEN}✓${NC} scj6.custom.yaml 已設定"
    else
        echo -e "  ${RED}✗${NC} scj6.custom.yaml 未設定"
    fi

    if check_default_custom; then
        echo -e "  ${GREEN}✓${NC} default.custom.yaml 已設定"
    else
        echo -e "  ${RED}✗${NC} default.custom.yaml 未設定"
    fi

    if check_rime_in_sources; then
        echo -e "  ${GREEN}✓${NC} Rime 已加入 GNOME 輸入來源"
    else
        echo -e "  ${RED}✗${NC} Rime 未在 GNOME 輸入來源中"
    fi
    echo -e "  目前輸入來源: $(get_gnome_sources)"

    if pgrep -x ibus-daemon >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} ibus-daemon 執行中"
    else
        echo -e "  ${YELLOW}!${NC} ibus-daemon 未執行"
    fi
}

# ========================================
# 安裝 / 解除安裝
# ========================================

install() {
    info "開始設定 ibus-rime + 快速倉頡..."

    local need_redeploy=false

    if ! check_package "ibus-rime"; then
        setup_ibus_rime || return 1
    fi

    if ! check_rime_scj; then
        setup_rime_scj
        need_redeploy=true
    fi

    if ! check_scj6_custom; then
        setup_scj6_custom
        need_redeploy=true
    fi

    if ! check_default_custom; then
        setup_default_custom
        need_redeploy=true
    fi

    setup_gnome_source

    if $need_redeploy; then
        redeploy_rime
    else
        info "所有設定已完成，無需重新部署"
    fi

    info ""
    info "設定完成！"
    info "快捷鍵："
    info "  - Super+Space: 切換輸入法（切到 Rime）"
    info "  - F4: 切換輸入法方案 (scj6 / cangjie5 / luna_pinyin)"
    info "  - 右 Shift: 切換中英文"
    info "  - 左 Shift: 不會觸發中英文切換"
    info "  - 快速倉頡 (scj6): 預設方案，啟動時為英文模式"
    info ""
    if ! check_package "ibus-rime"; then
        warn "提醒：ibus-rime 剛透過 rpm-ostree 安裝，需 reboot 後再執行一次 $SCRIPT_NAME -i 完成部署。"
    fi
}

uninstall() {
    info "開始還原 ibus-rime 設定..."

    remove_gnome_source
    remove_scj6_custom
    remove_default_custom
    remove_rime_scj

    # 清理 build 目錄
    rm -rf "$RIME_DIR/build"

    info "ibus-rime 設定已還原！"
    info "注意: ibus-rime 套件未移除，如需移除請手動執行:"
    info "  sudo rpm-ostree uninstall ibus-rime   (需重開機)"
}

usage() {
    echo "Usage: $SCRIPT_NAME [OPTION]"
    echo ""
    echo "Options:"
    echo "  -i, --install     安裝/設定 ibus-rime + 快速倉頡 (預設)"
    echo "  -u, --uninstall   還原設定（保留 ibus-rime 套件）"
    echo "  -s, --status      顯示目前狀態"
    echo "  -h, --help        顯示此說明"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME              # 設定輸入法"
    echo "  $SCRIPT_NAME -s           # 顯示狀態"
}

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
