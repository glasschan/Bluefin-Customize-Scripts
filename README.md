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

*適用 GNOME 版本: 46.x*
