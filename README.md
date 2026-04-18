# Bluefin Customized Scripts

自訂腳本集合，用於配置 Bluefin (GNOME) 桌面環境。

---

## gnome-workspace-keybindings.sh

將 GNOME 的 `Super+數字` 快捷鍵從 Dock 應用切換改為 Workspace 管理，類似 i3/Sway 的體驗。

### 快捷鍵對照表

| 快捷鍵 | 功能 |
|--------|------|
| `Super+1` ~ `Super+9` | 跳轉到 Workspace 1-9 |
| `Super+0` | 跳轉到 Workspace 10 |
| `Super+Shift+1` ~ `Super+Shift+9` | 將當前窗口移動到 Workspace 1-9 |
| `Super+Shift+0` | 將當前窗口移動到 Workspace 10 |

### 使用方式

```bash
# 設定快捷鍵（預設動作）
./gnome-workspace-keybindings.sh
./gnome-workspace-keybindings.sh --setup

# 查看當前狀態
./gnome-workspace-keybindings.sh --check

# 修復 dash-to-dock 衝突
./gnome-workspace-keybindings.sh --fix-dock

# 恢復 GNOME 預設
./gnome-workspace-keybindings.sh --restore
```

### 注意事項

- 如果啟用了 dash-to-dock 的 hot-keys，會與本腳本衝突。`--setup` 會自動處理此問題。
- 適用於 GNOME 46.x / Bluefin。
- 若要恢復預設，使用 `--restore` 即可。

---

## alacritty-zellij-shortcut.sh

一鍵安裝 Alacritty 終端機 + Zellij（終端多工器），並綁定 `Super+Alt+Enter` 快捷鍵啟動最大化視窗。

### 快捷鍵對照表

| 快捷鍵 | 功能 |
|--------|------|
| `Super+Alt+Enter` | 啟動 Alacritty（最大化）並執行 Zellij |

### 使用方式

```bash
# 一鍵安裝（預設動作）
./alacritty-zellij-shortcut.sh
./alacritty-zellij-shortcut.sh --setup

# 查看當前狀態
./alacritty-zellij-shortcut.sh --check

# 恢復預設（還原 Ptyxis Alt 快捷鍵、刪除檔案）
./alacritty-zellij-shortcut.sh --restore
```

### 安裝流程

1. 檢查 alacritty → 未安裝則透過 `rpm-ostree install` 安裝（需重啟）
2. 檢查 zellij → 未安裝則詢問是否透過 `brew install` 安裝
3. 建立 `~/bin/zlaunch` 包裝腳本
4. 寫入 `~/.config/alacritty/alacritty.toml`（已存在會詢問是否覆蓋）
5. 設定 GNOME 快捷鍵（優先替換 `Ptyxis Alt`，否則新增自訂綁定）

### 還原說明

- `--restore` 會將快捷鍵還原為原始的 Ptyxis Alt（`Ctrl+Alt+Enter`）
- 刪除 `~/bin/zlaunch` 和 `~/.config/alacritty/alacritty.toml`
- 不會卸載 alacritty 或 zellij

---

*適用 GNOME 版本: 46.x*
