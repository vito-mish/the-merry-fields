## Toolbar — 底部工具列 (S11-T04)
## 顯示三個工具格，當前選中的格子高亮
extends Control

const TOOLS       : Array[String] = ["hoe", "watering_can", "seeds", "fertilizer"]
const TOOL_TR_KEYS : Dictionary   = {
	"hoe":          "TOOL_HOE",
	"watering_can": "TOOL_WATERING_CAN",
	"seeds":        "TOOL_SEEDS",
	"fertilizer":   "TOOL_FERTILIZER",
}
const TOOL_COLORS : Dictionary    = {
	"hoe":          Color(0.80, 0.58, 0.28, 1.0),
	"watering_can": Color(0.28, 0.60, 0.90, 1.0),
	"seeds":        Color(0.35, 0.78, 0.32, 1.0),
	"fertilizer":   Color(0.72, 0.50, 0.18, 1.0),
}

const SLOT_W   := 22
const SLOT_H   := 22
const SLOT_GAP := 2
const FONT_SZ  := 6


func _draw() -> void:
	var player : Node = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var tool_index : int = player.tool_index
	var n          : int = TOOLS.size()
	var total_w    : int = n * SLOT_W + (n - 1) * SLOT_GAP
	var start_x    : float = (size.x - total_w) / 2.0
	var y          : float = 0.0

	for i in range(n):
		var x     : float  = start_x + i * (SLOT_W + SLOT_GAP)
		var rect  := Rect2(x, y, SLOT_W, SLOT_H)
		var active: bool   = (i == tool_index)
		var col   : Color  = TOOL_COLORS[TOOLS[i]]

		# 背景
		var bg := Color(0.10, 0.10, 0.10, 0.75) if not active else Color(col.r, col.g, col.b, 0.30)
		draw_rect(rect, bg)

		# 外框（選中時用工具顏色，未選中用灰）
		var border := col if active else Color(0.45, 0.45, 0.45, 0.9)
		draw_rect(rect, border, false, 1.5)

		# 文字標籤
		var label : String = tr(TOOL_TR_KEYS[TOOLS[i]])
		var font   := ThemeDB.fallback_font
		var fs     := FONT_SZ
		var tw     : float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx     : float = x + (SLOT_W - tw) / 2.0
		var ty     : float = y + SLOT_H * 0.65
		var tc     : Color = Color.WHITE if active else Color(0.70, 0.70, 0.70, 1.0)
		draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)

		# 快捷鍵提示（Q ← → E）
		if i == 0:
			draw_string(font, Vector2(x + 1, y + SLOT_H - 2), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.5, 0.5, 0.5, 0.8))
		elif i == n - 1:
			draw_string(font, Vector2(x + SLOT_W - 6, y + SLOT_H - 2), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.5, 0.5, 0.5, 0.8))
