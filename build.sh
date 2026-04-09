#!/usr/bin/env bash
# =============================================================================
# build.sh — The Merry Fields 打包腳本
# 用法：
#   ./build.sh              # 打包全平台
#   ./build.sh windows      # 只打 Windows
#   ./build.sh macos        # 只打 macOS
#   ./build.sh linux        # 只打 Linux
#   ./build.sh all upload   # 打包後上傳 Steam
# =============================================================================
set -euo pipefail

# ── 設定區 ───────────────────────────────────────────────────────────────────
GAME_NAME="TheMerryFields"
VERSION="${VERSION:-0.1.0}"
GODOT="${GODOT:-godot4}"              # 可用環境變數覆蓋，例如 GODOT=/path/to/godot4
STEAMCMD="${STEAMCMD:-steamcmd}"      # SteamCMD 路徑
STEAM_SCRIPT="steam/app_build.vdf"   # Steam 上傳腳本

EXPORT_DIR="export"
DIST_DIR="dist"

# ── 顏色輸出 ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN] ${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 前置檢查 ─────────────────────────────────────────────────────────────────
check_godot() {
    if ! command -v "$GODOT" &>/dev/null; then
        error "找不到 Godot：$GODOT\n請安裝 Godot 4 並確認在 PATH，或設定 GODOT 環境變數"
    fi
    info "Godot 版本：$("$GODOT" --version 2>&1 | head -1)"
}

# ── 清理 & 建目錄 ────────────────────────────────────────────────────────────
prepare_dirs() {
    local platform=$1
    local dir="$EXPORT_DIR/$platform"
    rm -rf "$dir"
    mkdir -p "$dir"
    echo "$dir"
}

# ── 寫入 steam_appid.txt ─────────────────────────────────────────────────────
write_appid() {
    local dir=$1
    if [ -f steam/app_build.vdf ]; then
        local appid
        appid=$(grep '"appid"' steam/app_build.vdf | head -1 | grep -oP '\d+')
        echo "$appid" > "$dir/steam_appid.txt"
        info "  steam_appid.txt → $appid"
    fi
}

# ── 各平台打包 ───────────────────────────────────────────────────────────────
build_windows() {
    info "▶ 打包 Windows..."
    local dir
    dir=$(prepare_dirs "windows")
    "$GODOT" --headless --export-release "Windows Desktop" \
        "$dir/${GAME_NAME}.exe" 2>&1 | grep -v "^$" || true
    write_appid "$dir"
    info "  完成 → $dir/${GAME_NAME}.exe"

    # 打 zip 供分發
    local zip="$DIST_DIR/${GAME_NAME}-${VERSION}-windows.zip"
    mkdir -p "$DIST_DIR"
    (cd "$EXPORT_DIR" && zip -r "../$zip" windows/)
    info "  壓縮 → $zip"
}

build_macos() {
    info "▶ 打包 macOS..."
    local dir
    dir=$(prepare_dirs "macos")
    "$GODOT" --headless --export-release "macOS" \
        "$dir/${GAME_NAME}.zip" 2>&1 | grep -v "^$" || true
    write_appid "$dir"
    info "  完成 → $dir/${GAME_NAME}.zip"

    cp "$dir/${GAME_NAME}.zip" "$DIST_DIR/${GAME_NAME}-${VERSION}-macos.zip"
    info "  複製 → $DIST_DIR/${GAME_NAME}-${VERSION}-macos.zip"
}

build_linux() {
    info "▶ 打包 Linux..."
    local dir
    dir=$(prepare_dirs "linux")
    "$GODOT" --headless --export-release "Linux/X11" \
        "$dir/${GAME_NAME}.x86_64" 2>&1 | grep -v "^$" || true
    chmod +x "$dir/${GAME_NAME}.x86_64"
    write_appid "$dir"
    info "  完成 → $dir/${GAME_NAME}.x86_64"

    local zip="$DIST_DIR/${GAME_NAME}-${VERSION}-linux.zip"
    (cd "$EXPORT_DIR" && zip -r "../$zip" linux/)
    info "  壓縮 → $zip"
}

# ── Steam 上傳 ───────────────────────────────────────────────────────────────
upload_steam() {
    info "▶ 上傳 Steam..."
    if [ ! -f "$STEAM_SCRIPT" ]; then
        error "找不到 Steam 腳本：$STEAM_SCRIPT"
    fi
    if ! command -v "$STEAMCMD" &>/dev/null; then
        error "找不到 SteamCMD：$STEAMCMD"
    fi
    "$STEAMCMD" +login anonymous +run_app_build "$STEAM_SCRIPT" +quit
    info "  上傳完成"
}

# ── 主流程 ───────────────────────────────────────────────────────────────────
main() {
    local target="${1:-all}"
    local upload="${2:-}"

    check_godot
    mkdir -p "$DIST_DIR"

    case "$target" in
        windows) build_windows ;;
        macos)   build_macos ;;
        linux)   build_linux ;;
        all)
            build_windows
            build_macos
            build_linux
            ;;
        *)
            error "不支援的平台：$target（可用：windows / macos / linux / all）"
            ;;
    esac

    if [ "$upload" = "upload" ]; then
        upload_steam
    fi

    info "✅ 打包完成 (v${VERSION})"
    ls -lh "$DIST_DIR/"
}

main "$@"
