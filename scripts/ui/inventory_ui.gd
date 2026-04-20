## InventoryUI — 背包格狀介面 (S11-T05)
## 由 HUD 動態建立並管理開關狀態
extends Control

# ── 佈局常數 ──────────────────────────────────────────────────────────────────
const COLS     := 3
const SLOT_W   := 44
const SLOT_H   := 48
const SLOT_GAP := 3
const TITLE_H  := 14
const PADDING  := 5

# 面板尺寸（依上方常數自動計算）
const PANEL_W  := COLS * SLOT_W + (COLS + 1) * SLOT_GAP + PADDING * 2        # 152
const PANEL_H  := TITLE_H + 3 * SLOT_H + 4 * SLOT_GAP + PADDING * 2         # 166

signal seed_selected(crop_id: String)

var _slot_nodes  : Array[Control] = []
var _selected_id : String = ""   # 目前選中的 item_id（如 "seed_turnip"）


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size                = Vector2(PANEL_W, PANEL_H)
	# 置中（viewport 320×180）
	position = Vector2((320 - PANEL_W) / 2.0, (180 - PANEL_H) / 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()
	InventoryManager.item_changed.connect(_on_item_changed)


func _build_ui() -> void:
	# ── 背景面板 ──────────────────────────────────────────────────────────
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.05, 0.08, 0.05, 0.94)
	sty.border_color = Color(0.42, 0.72, 0.28, 0.92)
	sty.border_width_left   = 1
	sty.border_width_right  = 1
	sty.border_width_top    = 1
	sty.border_width_bottom = 1
	sty.corner_radius_top_left     = 3
	sty.corner_radius_top_right    = 3
	sty.corner_radius_bottom_left  = 3
	sty.corner_radius_bottom_right = 3
	bg.add_theme_stylebox_override("panel", sty)
	add_child(bg)

	# ── 標題列 ────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "背包"
	title.add_theme_font_size_override("font_size", 8)
	title.modulate = Color(0.90, 1.00, 0.65)
	title.position = Vector2(PADDING, PADDING)
	add_child(title)

	var hint := Label.new()
	hint.text = "[I] 關閉"
	hint.add_theme_font_size_override("font_size", 6)
	hint.modulate = Color(0.55, 0.65, 0.50)
	hint.position = Vector2(PANEL_W - 62, PADDING + 1)
	add_child(hint)

	# ── 分隔線 ────────────────────────────────────────────────────────────
	var line := ColorRect.new()
	line.color    = Color(0.42, 0.72, 0.28, 0.45)
	line.position = Vector2(PADDING, PADDING + TITLE_H - 3)
	line.size     = Vector2(PANEL_W - PADDING * 2, 1)
	add_child(line)

	# ── 種子格子 ──────────────────────────────────────────────────────────
	var keys : Array = InventoryManager.SEED_ITEMS.keys()
	for i in range(keys.size()):
		var item_id : String = keys[i]
		var col     : int    = i % COLS
		var row     : int    = i / COLS
		var sx      : float  = PADDING + SLOT_GAP + col * (SLOT_W + SLOT_GAP)
		var sy      : float  = PADDING + TITLE_H + SLOT_GAP + row * (SLOT_H + SLOT_GAP)
		var slot    : Control = _make_slot(item_id, sx, sy)
		add_child(slot)
		_slot_nodes.append(slot)


func _make_slot(item_id: String, x: float, y: float) -> Control:
	var info : Dictionary = InventoryManager.SEED_ITEMS[item_id]
	var qty  : int        = InventoryManager.get_quantity(item_id)

	var slot := Control.new()
	slot.position            = Vector2(x, y)
	slot.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	slot.size                = Vector2(SLOT_W, SLOT_H)
	slot.mouse_filter        = Control.MOUSE_FILTER_STOP
	slot.set_meta("item_id", item_id)

	# 背景框
	var bg_box := Panel.new()
	bg_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(0.12, 0.16, 0.10, 0.90) if qty > 0 else Color(0.07, 0.07, 0.07, 0.88)
	sty.border_color = Color(0.35, 0.55, 0.25, 0.75)
	sty.border_width_left   = 1
	sty.border_width_right  = 1
	sty.border_width_top    = 1
	sty.border_width_bottom = 1
	sty.corner_radius_top_left     = 2
	sty.corner_radius_top_right    = 2
	sty.corner_radius_bottom_left  = 2
	sty.corner_radius_bottom_right = 2
	bg_box.add_theme_stylebox_override("panel", sty)
	bg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 讓事件穿透到 slot
	slot.set_meta("bg_style", sty)
	slot.add_child(bg_box)

	# ── 圖示（彩色方塊）─────────────────────────────────────────────────
	var icon := ColorRect.new()
	icon.color        = info["color"] if qty > 0 else Color(0.28, 0.28, 0.28)
	icon.size         = Vector2(12, 12)
	icon.position     = Vector2((SLOT_W - 12) / 2.0, 3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("icon", icon)
	slot.add_child(icon)

	# ── 作物名稱（置中）─────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.text                 = info["name"]
	name_lbl.add_theme_font_size_override("font_size", 6)
	name_lbl.modulate             = Color(0.88, 0.95, 0.72) if qty > 0 else Color(0.40, 0.40, 0.38)
	name_lbl.position             = Vector2(0, 17)
	name_lbl.size                 = Vector2(SLOT_W, 9)
	name_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text            = false
	slot.set_meta("name_lbl", name_lbl)
	slot.add_child(name_lbl)

	# ── 季節標籤（置中，彩色）───────────────────────────────────────────
	var seasons  : Array  = info.get("seasons", [])
	var sea_str  : String = ""
	var sea_col  : Color  = Color(0.65, 0.65, 0.65)
	if not seasons.is_empty():
		var s : String = seasons[0]
		sea_str = InventoryManager.SEASON_LABELS.get(s, s)
		sea_col = InventoryManager.SEASON_COLORS.get(s, sea_col)
	var sea_lbl := Label.new()
	sea_lbl.text                 = sea_str + "季"
	sea_lbl.add_theme_font_size_override("font_size", 6)
	sea_lbl.modulate             = sea_col if qty > 0 else sea_col.darkened(0.5)
	sea_lbl.position             = Vector2(0, 27)
	sea_lbl.size                 = Vector2(SLOT_W, 9)
	sea_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	sea_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.set_meta("sea_lbl", sea_lbl)
	slot.add_child(sea_lbl)

	# ── 數量（置中）─────────────────────────────────────────────────────
	var qty_lbl := Label.new()
	qty_lbl.text                 = "x" + str(qty)
	qty_lbl.add_theme_font_size_override("font_size", 7)
	qty_lbl.modulate             = Color(1.00, 0.95, 0.55) if qty > 0 else Color(0.45, 0.42, 0.35)
	qty_lbl.position             = Vector2(0, 37)
	qty_lbl.size                 = Vector2(SLOT_W, 10)
	qty_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.set_meta("qty_lbl", qty_lbl)
	slot.add_child(qty_lbl)

	# 輸入偵測
	slot.gui_input.connect(_on_slot_gui_input.bind(item_id))

	return slot


# ── 互動 ─────────────────────────────────────────────────────────────────────

func _on_slot_gui_input(ev: InputEvent, item_id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if InventoryManager.has_item(item_id):
			select_seed(item_id)


func select_seed(item_id: String) -> void:
	_selected_id = item_id
	_refresh_highlights()
	var info : Dictionary = InventoryManager.get_item_info(item_id)
	seed_selected.emit(info.get("crop_id", ""))


func _refresh_highlights() -> void:
	for slot in _slot_nodes:
		var sid  : String        = slot.get_meta("item_id")
		var sty  : StyleBoxFlat  = slot.get_meta("bg_style")
		var qty  : int           = InventoryManager.get_quantity(sid)
		var icon : ColorRect     = slot.get_meta("icon")
		var info : Dictionary    = InventoryManager.SEED_ITEMS[sid]
		if sid == _selected_id:
			sty.border_color = Color(0.95, 1.00, 0.28, 1.00)
			sty.bg_color     = Color(0.20, 0.28, 0.10, 0.96)
			sty.border_width_left   = 2
			sty.border_width_right  = 2
			sty.border_width_top    = 2
			sty.border_width_bottom = 2
		else:
			sty.border_color = Color(0.35, 0.55, 0.25, 0.75)
			sty.bg_color     = Color(0.12, 0.16, 0.10, 0.90) if qty > 0 else Color(0.07, 0.07, 0.07, 0.88)
			sty.border_width_left   = 1
			sty.border_width_right  = 1
			sty.border_width_top    = 1
			sty.border_width_bottom = 1
		icon.color = info["color"] if qty > 0 else Color(0.28, 0.28, 0.28)


# ── 數量更新 ─────────────────────────────────────────────────────────────────

func _on_item_changed(item_id: String, new_qty: int) -> void:
	for slot in _slot_nodes:
		if slot.get_meta("item_id") != item_id:
			continue
		var qty_lbl : Label     = slot.get_meta("qty_lbl")
		var icon    : ColorRect = slot.get_meta("icon")
		var info    : Dictionary = InventoryManager.SEED_ITEMS.get(item_id, {})
		qty_lbl.text    = "x" + str(new_qty)
		qty_lbl.modulate = Color(1.00, 0.95, 0.55) if new_qty > 0 else Color(0.45, 0.42, 0.35)
		icon.color = info.get("color", Color.GRAY) if new_qty > 0 else Color(0.28, 0.28, 0.28)
		_refresh_highlights()
		break


# ── 開關 ─────────────────────────────────────────────────────────────────────

func open_inventory(current_crop_id: String) -> void:
	_selected_id = InventoryManager.seed_id_for_crop(current_crop_id)
	_refresh_highlights()
	show()


func close_inventory() -> void:
	hide()
