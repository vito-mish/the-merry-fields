#!/usr/bin/env bash
# 快速 GDScript 編譯檢查
# 用法：bash check.sh
# 只顯示 SCRIPT ERROR / WARNING，忽略 Godot 內部 BUG 字串

GODOT="/c/Users/mishm/Desktop/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== GDScript check: $PROJECT_DIR ==="

OUTPUT=$(timeout 15 "$GODOT" --headless --check-only --path "$PROJECT_DIR" 2>&1 || true)

# 過濾掉已知的 Godot 內部 cleanup BUG
ERRORS=$(echo "$OUTPUT" | grep -E "^(SCRIPT ERROR|ERROR:|WARNING:)" \
  | grep -v "BUG: Unreferenced static string" \
  | grep -v "RID allocations" \
  | grep -v "Pages in use" \
  | grep -v "Thread object" )

if [ -z "$ERRORS" ]; then
  echo "✅ 無錯誤"
else
  echo "$ERRORS"
  echo ""
  echo "❌ 發現問題，請修正後重新檢查"
  exit 1
fi
