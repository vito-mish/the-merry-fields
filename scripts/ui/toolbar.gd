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

		# 文字標籤（種子欄由圖示區塊處理，跳過避免重疊）
		var font   := ThemeDB.fallback_font
		var fs     := FONT_SZ
		if TOOLS[i] != "seeds":
			var label : String = tr(TOOL_TR_KEYS[TOOLS[i]])
			var tw     : float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tx     : float = x + (SLOT_W - tw) / 2.0
			var ty     : float = y + SLOT_H * 0.65
			var tc     : Color = Color.WHITE if active else Color(0.70, 0.70, 0.70, 1.0)
			draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)

		# 種子欄：依作物畫彩色圖示
		if TOOLS[i] == "seeds":
			var crop_col := _get_seed_color(player)
			var cx : float = x + SLOT_W / 2.0
			var icon_y : float = y + SLOT_H * 0.30
			var seed_qty : int = InventoryManager.get_quantity("seed_" + player.seed_crop_id)
			if active:
				# 選中：較大圖示（莖 + 果實圓）
				draw_line(Vector2(cx, icon_y + 2), Vector2(cx, icon_y - 1),
					Color(0.25, 0.55, 0.15), 1.5)
				draw_circle(Vector2(cx, icon_y - 3), 4.0, crop_col)
				draw_circle(Vector2(cx, icon_y - 3), 2.5, crop_col.lightened(0.35))
				# 作物名稱
				var crop_name := _get_seed_name(player)
				var cn_w : float = font.get_string_size(crop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
				draw_string(font, Vector2(x + (SLOT_W - cn_w) / 2.0, y + SLOT_H - 10),
					crop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.95, 1.0, 0.70, 1.0))
				# 數量
				var qty_str : String = "x" + str(seed_qty)
				var qw : float = font.get_string_size(qty_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
				var qty_col : Color = Color(1.0, 0.95, 0.40, 1.0) if seed_qty > 0 else Color(0.65, 0.40, 0.40, 1.0)
				draw_string(font, Vector2(x + (SLOT_W - qw) / 2.0, y + SLOT_H - 3),
					qty_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, qty_col)
				draw_string(font, Vector2(x + 1, y + SLOT_H - 1), "Tab",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(0.5, 0.5, 0.5, 0.8))
			else:
				# 未選中：小點 + 作物名稱（淡色）
				draw_line(Vector2(cx, icon_y + 1), Vector2(cx, icon_y - 1),
					Color(0.25, 0.55, 0.15, 0.8), 1.0)
				draw_circle(Vector2(cx, icon_y - 2), 2.5, crop_col.darkened(0.2))
				var crop_name2 := _get_seed_name(player)
				var cn_w2 : float = font.get_string_size(crop_name2, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
				draw_string(font, Vector2(x + (SLOT_W - cn_w2) / 2.0, y + SLOT_H - 10),
					crop_name2, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.75, 0.85, 0.60, 0.85))
				# 數量（淡色）
				var qty_str2 : String = "x" + str(seed_qty)
				var qw2 : float = font.get_string_size(qty_str2, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
				var qty_col2 : Color = Color(0.85, 0.80, 0.35, 0.85) if seed_qty > 0 else Color(0.55, 0.35, 0.35, 0.85)
				draw_string(font, Vector2(x + (SLOT_W - qw2) / 2.0, y + SLOT_H - 3),
					qty_str2, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, qty_col2)

		# 快捷鍵提示（Q ← → E）
		if i == 0:
			draw_string(font, Vector2(x + 1, y + SLOT_H - 2), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.5, 0.5, 0.5, 0.8))
		elif i == n - 1:
			draw_string(font, Vector2(x + SLOT_W - 6, y + SLOT_H - 2), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.5, 0.5, 0.5, 0.8))


## 供 player 切換種子後呼叫，強制重繪
func refresh_toolbar() -> void:
	queue_redraw()


## 取得當前種子的成熟顏色
func _get_seed_color(player: Node) -> Color:
	var crop_id : String = player.seed_crop_id
	var farm_grid : Node = get_tree().get_first_node_in_group("farm_grid")
	if farm_grid == null:
		return Color(0.35, 0.78, 0.32, 1.0)
	var db : Dictionary = farm_grid.get_crop_db()
	if db.has(crop_id):
		var cm : Array = db[crop_id].get("color_mature", [0.35, 0.78, 0.32])
		return Color(cm[0], cm[1], cm[2])
	return Color(0.35, 0.78, 0.32, 1.0)


## 取得當前種子的顯示名稱（從 farm_grid 的 crop_db 讀）
func _get_seed_name(player: Node) -> String:
	var crop_id : String = player.seed_crop_id
	var farm_grid : Node = get_tree().get_first_node_in_group("farm_grid")
	if farm_grid == null:
		return crop_id
	var db : Dictionary = farm_grid.get_crop_db()
	if db.has(crop_id):
		return db[crop_id].get("name", crop_id)
	return crop_id
