# 上架指南 — itch.io

> 本文件記錄《樂樂物語》上架 itch.io 的完整流程，待遊戲內容完整後依序執行。

---

## 一、前置準備

### 1. 安裝 Godot 匯出模板

在 Godot Editor 中：
- 選單 → **Editor → Manage Export Templates**
- 下載對應 Godot 版本的 Export Templates
- 等待安裝完成

### 2. 安裝 butler（itch.io 官方上傳工具）

**Windows**
1. 至 https://itch.io/docs/butler/installing.html 下載 butler
2. 解壓縮至任意目錄（如 `C:\tools\butler\`）
3. 將該目錄加入系統 PATH

**macOS / Linux**
```bash
# macOS (Homebrew)
brew install butler

# Linux
curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
unzip butler.zip
chmod +x butler
sudo mv butler /usr/local/bin/
```

驗證安裝：
```bash
butler version
```

### 3. 登入 butler

```bash
butler login
# 瀏覽器會開啟 itch.io 授權頁面，登入後複製 API key 貼回終端機
```

登入資訊儲存在本機，**之後不需要重複登入**。

---

## 二、itch.io 遊戲頁面設定

### 建立遊戲頁面

1. 登入 https://itch.io
2. 右上角頭像 → **Upload a new project**
3. 填寫基本資料：

| 欄位 | 填寫建議 |
|------|----------|
| Title | The Merry Fields |
| Project URL | `the-merry-fields`（記下此 slug） |
| Kind of project | Downloadable |
| Classification | Games |
| Genre | Role Playing |
| Tags | farming, cozy, rpg, pixel-art, godot |
| Short description | 輕鬆可愛的農場 RPG，耕種、交友、探索小鎮 |

### 頁面素材規格

| 素材 | 尺寸 | 格式 |
|------|------|------|
| Cover image | 315 × 250 px | PNG / JPG |
| Banner（頁首） | 960 × 380 px | PNG / JPG |
| Screenshots | 最少 3 張，建議 1280 × 720 | PNG |
| GIF 預覽 | 可選，≤ 5 MB | GIF |

### 定價設定

| 模式 | 說明 |
|------|------|
| Free | 完全免費 |
| Pay what you want | 免費但可自由付費（建議設最低 $0） |
| Paid | 固定售價 |

建議初期用 **Pay what you want（最低 $0）** 累積玩家與評價。

---

## 三、打包設定

### 填寫 itch.cfg

複製範本並填入你的資訊：

```bash
cp itch.cfg.example itch.cfg
```

編輯 `itch.cfg`：
```
ITCH_USER=your-itch-username
ITCH_GAME=the-merry-fields
```

> `itch.cfg` 已加入 `.gitignore`，不會進入版本控制。

### 版本號規則

採用 `MAJOR.MINOR.PATCH`：

| 版本號 | 時機 |
|--------|------|
| 0.x.x | 早期測試 / Demo |
| 1.0.0 | 正式發售 |
| 1.x.0 | 新增功能 |
| 1.0.x | Bug 修正 |

---

## 四、打包與上傳

### 打包指令

```bash
# Windows
build.bat all              # 打包全平台（不上傳）
build.bat windows          # 只打 Windows

# macOS / Linux
./build.sh all             # 打包全平台（不上傳）
./build.sh windows         # 只打 Windows
```

輸出位置：`export/<platform>/`

### 上傳指令

```bash
# Windows
VERSION=0.1.0 build.bat all upload

# macOS / Linux
VERSION=0.1.0 ./build.sh all upload
```

butler 會做**差異更新**，只上傳有變動的檔案。

### Channel 對應表

| 平台 | Butler Channel |
|------|----------------|
| Windows | `windows` |
| macOS | `mac` |
| Linux | `linux` |

---

## 五、Godot 匯出設定補充

> `export_presets.cfg` 已設定三平台，上架前需補充以下資訊：

### macOS

```
# 在 export_presets.cfg 填入
application/bundle_identifier = "com.<你的名稱>.the-merry-fields"
application/short_version = "1.0"
application/version = "1.0.0"
```

若需上架 Mac App Store 或提供公證（Notarization）：
- 需要 Apple Developer 帳號（US$99/年）
- 詳見 Godot 官方文件：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html

### Windows 程式碼簽署（可選）

不簽署仍可執行，但玩家下載時會出現 SmartScreen 警告。
日後有需要可購買代碼簽署憑證（EV Certificate）。

---

## 六、上架檢查清單

上架前確認以下項目：

### 遊戲內容
- [ ] 有完整的開始到結束流程
- [ ] 沒有影響遊戲的嚴重 Bug
- [ ] 支援中文與英文
- [ ] 有存檔系統

### 頁面素材
- [ ] Cover image（315×250）
- [ ] 至少 3 張截圖
- [ ] 遊戲描述（中英文）
- [ ] 操作說明（可附 `docs/manual.md` 內容）

### 技術
- [ ] Windows 版本可正常執行
- [ ] macOS 版本可正常執行（若有）
- [ ] Linux 版本可正常執行（若有）
- [ ] `export_presets.cfg` 填入正確版本號

### 定價
- [ ] 確認定價策略（建議初期 PWYW）

---

## 七、參考資源

- [butler 文件](https://itch.io/docs/butler/)
- [itch.io 開發者常見問題](https://itch.io/docs/creators/)
- [Godot 匯出教學](https://docs.godotengine.org/en/stable/tutorials/export/)
- [itch.io 分析後台](https://itch.io/dashboard/analytics)
