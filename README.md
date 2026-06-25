# Bluefin Customized Scripts

自訂腳本集合，用於配置 Bluefin (GNOME) 桌面環境。

---

## setup-fonts.sh

安裝 CJK 字體 (MiSans + OPPO Sans) + 可選 GTK 介面字體。

```bash
./setup-fonts.sh         # 安裝 (預設)
./setup-fonts.sh -s      # 顯示狀態
./setup-fonts.sh -u      # 還原
```

## setup-rime-ibus.sh

安裝 ibus-rime + 快速倉頡 (scj6) 輸入法。

```bash
./setup-rime-ibus.sh     # 安裝 (預設)
./setup-rime-ibus.sh -s  # 顯示狀態
./setup-rime-ibus.sh -u  # 還原
```

**注意:** 需先 `sudo rpm-ostree install ibus-rime` 並 reboot，再執行此腳本。

## gnome-workspace-keybindings.sh

將 GNOME 的 `Super+數字` 快捷鍵從 Dock 應用切換改為 Workspace 管理，類似 i3/Sway 的體驗。

| 快捷鍵 | 功能 |
|--------|------|
| `Super+1` ~ `Super+9` | 跳轉到 Workspace 1-9 |
| `Super+0` | 跳轉到 Workspace 10 |
| `Super+Shift+1` ~ `Super+Shift+9` | 將當前窗口移動到 Workspace 1-9 |
| `Super+Shift+0` | 將當前窗口移動到 Workspace 10 |

```bash
./gnome-workspace-keybindings.sh         # 設定 (預設)
./gnome-workspace-keybindings.sh --check # 查看狀態
./gnome-workspace-keybindings.sh --restore  # 恢復 GNOME 預設
```

**注意:** dash-to-dock hot-keys 會與本腳本衝突，`--setup` 會自動處理。

## alacritty-zellij-shortcut.sh

一鍵安裝 Alacritty + Zellij，綁定 `Super+Alt+Enter` 啟動最大化終端機。

| 快捷鍵 | 功能 |
|--------|------|
| `Super+Alt+Enter` | 啟動 Alacritty（最大化）並執行 Zellij |

```bash
./alacritty-zellij-shortcut.sh           # 安裝 (預設)
./alacritty-zellij-shortcut.sh --restore # 還原
```

## setup-super-enter-ptyxis.sh

將 `Super+Enter` 綁定到 Ptyxis 終端機。

| 快捷鍵 | 功能 |
|--------|------|
| `Super+Enter` | 啟動 Ptyxis 終端機 |

```bash
./setup-super-enter-ptyxis.sh           # 設定 (預設)
./setup-super-enter-ptyxis.sh --restore # 移除綁定
./setup-super-enter-ptyxis.sh --check   # 查看狀態
```

## setup-keyd-swap.sh

交換 Laptop 內建鍵盤的 Alt 和 Super 鍵 (外接鍵盤不受影響)。

| 按鍵 | 效果 |
|------|------|
| Alt | 變成 Super |
| Super | 變成 Alt |

```bash
./setup-keyd-swap.sh           # 編譯 + 安裝 keyd + 啟用 (預設)
./setup-keyd-swap.sh --restore # 停用 keyd + 還原
./setup-keyd-swap.sh --check   # 查看狀態
```

**注意:** 需要 gcc + make (Bluefin-DX 已預裝)。首次安裝會下載 keyd 原始碼編譯。

---

## 還原所有設定

每個 script 都有 `--restore` 或 `-u` 參數。全部還原：

```bash
for s in *.sh; do ./$s --restore; done   # 還原全部
```

*適用 GNOME 版本: 46.x / Bluefin 44*
