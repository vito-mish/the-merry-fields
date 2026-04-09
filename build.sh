#!/usr/bin/env bash
# =============================================================================
# build.sh — The Merry Fields 打包腳本
# 用法：
#   ./build.sh                  # 打包全平台
#   ./build.sh windows          # 只打 Windows
#   ./build.sh macos            # 只打 macOS
#   ./build.sh linux            # 只打 Linux
#   ./build.sh all upload       # 打包全平台並上傳 itch.io
#   ./build.sh windows upload   # 打包 Windows 並上傳 itch.io
#
# 環境變數：
#   GODOT=godot4                Godot 執行檔路徑
#   BUTLER=butler               butler 執行檔路徑
#   VERSION=0.1.0               版本號
#   ITCH_USER=your-username     itch.io 帳號（或寫入 itch.cfg）
# =============================================================================
set -euo pipefail

# ── 設定區 ───────────────────────────────────────────────────────────────────
GAME_NAME="TheMerryFields"
VERSION="${VERSION:-0.1.0}"
GODOT="${GODOT:-godot4}"
BUTLER="${BUTLER:-butler}"
EXPORT_DIR="export"
DIST_DIR="dist"

# itch.io 設定（也可寫在 itch.cfg 裡）
ITCH_CFG="itch.cfg"
ITCH_USER=""
ITCH_GAME=""
if [ -f "$ITCH_CFG" ]; then
    # shellcheck disable=SC1090
    source "$ITCH_CFG"
fi

# ── 顏色輸出 ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN] ${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 前置檢查 ─────────────────────────────────────────────────────────────────
check_godot() {
    command -v "$GODOT" &>/dev/null \
        || error "找不到 Godot：$GODOT\n請設定 GODOT 環境變數或確認已加入 PATH"
    info "Godot：$("$GODOT" --version 2>&1 | head -1)"
}

check_butler() {
    command -v "$BUTLER" &>/dev/null \
        || error "找不到 butler\n安裝說明：https://itch.io/docs/butler/installing.html"
    info "butler：$("$BUTLER" version 2>&1 | head -1)"
    [ -n "$ITCH_USER" ] || error "未設定 ITCH_USER\n請建立 itch.cfg 或設定環境變數"
    [ -n "$ITCH_GAME" ] || error "未設定 ITCH_GAME\n請建立 itch.cfg 或設定環境變數"
}

# ── 清理 & 建目錄 ────────────────────────────────────────────────────────────
prepare_dirs() {
    local dir="$EXPORT_DIR/$1"
    rm -rf "$dir" && mkdir -p "$dir"
    echo "$dir"
}

# ── 各平台打包 ───────────────────────────────────────────────────────────────
build_windows() {
    info "▶ 打包 Windows..."
    local dir; dir=$(prepare_dirs "windows")
    "$GODOT" --headless --export-release "Windows Desktop" \
        "$dir/${GAME_NAME}.exe" 2>&1 | grep -E "(ERROR|error)" || true
    info "  完成 → $dir/${GAME_NAME}.exe"
}

build_macos() {
    info "▶ 打包 macOS..."
    local dir; dir=$(prepare_dirs "macos")
    "$GODOT" --headless --export-release "macOS" \
        "$dir/${GAME_NAME}.zip" 2>&1 | grep -E "(ERROR|error)" || true
    info "  完成 → $dir/${GAME_NAME}.zip"
}

build_linux() {
    info "▶ 打包 Linux..."
    local dir; dir=$(prepare_dirs "linux")
    "$GODOT" --headless --export-release "Linux/X11" \
        "$dir/${GAME_NAME}.x86_64" 2>&1 | grep -E "(ERROR|error)" || true
    chmod +x "$dir/${GAME_NAME}.x86_64"
    info "  完成 → $dir/${GAME_NAME}.x86_64"
}

# ── itch.io 上傳（butler push）────────────────────────────────────────────────
# butler 會自動做差異更新，不需要 zip
upload_itch() {
    local platform=$1   # windows / mac / linux
    local src=$2        # 本地目錄
    local channel="${ITCH_USER}/${ITCH_GAME}:${platform}"
    info "  上傳 → $channel"
    "$BUTLER" push "$src" "$channel" --userversion "$VERSION"
}

# ── 主流程 ───────────────────────────────────────────────────────────────────
main() {
    local target="${1:-all}"
    local do_upload="${2:-}"

    check_godot
    [ "$do_upload" = "upload" ] && check_butler
    mkdir -p "$DIST_DIR"

    case "$target" in
        windows)
            build_windows
            [ "$do_upload" = "upload" ] && upload_itch "windows" "$EXPORT_DIR/windows"
            ;;
        macos)
            build_macos
            [ "$do_upload" = "upload" ] && upload_itch "mac" "$EXPORT_DIR/macos"
            ;;
        linux)
            build_linux
            [ "$do_upload" = "upload" ] && upload_itch "linux" "$EXPORT_DIR/linux"
            ;;
        all)
            build_windows
            build_macos
            build_linux
            if [ "$do_upload" = "upload" ]; then
                upload_itch "windows" "$EXPORT_DIR/windows"
                upload_itch "mac"     "$EXPORT_DIR/macos"
                upload_itch "linux"   "$EXPORT_DIR/linux"
            fi
            ;;
        *)
            error "不支援的平台：$target（可用：windows / macos / linux / all）"
            ;;
    esac

    info "✅ 完成 (v${VERSION})"
}

main "$@"
