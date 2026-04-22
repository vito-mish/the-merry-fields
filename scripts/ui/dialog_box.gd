## DialogBox — 通用對話框 UI (S11-T06)
## 由 HUD 動態建立。呼叫 show_dialog() 開啟，按 action 鍵翻頁/關閉。
## 使用方式：
##   hud.show_dialog("老農夫", ["你好！", "今天天氣不錯。"])
extends Control

# ── 佈局常數 ──────────────────────────────────────────────────────────────────
const DLG_W    := 280
const DLG_H    := 54
const PADDING  := 7
const NAME_H   := 11   # 說話者名稱列高度
const PORT_W   := 14   # 頭像色塊寬度

# ── 節點引用 ──────────────────────────────────────────────────────────────────
var _bg         : Panel
var _name_lbl   : Label
var _text_lbl   : Label
var _arrow      : Label   # ▼ 繼續指示器

# ── 狀態 ─────────────────────────────────────────────────────────────────────
var _pages      : Array[String] = []
var _page_idx   : int           = 0
var _arrow_time : float         = 0.0
var _portrait_color : Color     = Color(0.55, 0.75, 0.45)

signal dialog_closed


func _ready() -> void:
	custom_minimum_size = Vector2(DLG_W, DLG_H)
	size                = Vector2(DLG_W, DLG_H)
	# 置底置中（viewport 320×180）
	position = Vector2((320 - DLG_W) / 2.0, 180 - DLG_H - 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide()


func _build_ui() -> void:
	# ── 背景 ──────────────────────────────────────────────────────────────
	_bg = Panel.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sty := StyleBoxFlat.new()
	sty.bg_color            = Color(0.06, 0.08, 0.06, 0.93)
	sty.border_color        = Color(0.50, 0.80, 0.35, 0.90)
	sty.border_width_left   = 1
	sty.border_width_right  = 1
	sty.border_width_top    = 1
	sty.border_width_bottom = 1
	sty.corner_radius_top_left     = 3
	sty.corner_radius_top_right    = 3
	sty.corner_radius_bottom_left  = 3
	sty.corner_radius_bottom_right = 3
	_bg.add_theme_stylebox_override("panel", sty)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# ── 說話者頭像色塊 ────────────────────────────────────────────────────
	var portrait := ColorRect.new()
	portrait.size         = Vector2(PORT_W, NAME_H)
	portrait.position     = Vector2(PADDING, PADDING)
	portrait.color        = _portrait_color
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.name        = "Portrait"
	add_child(portrait)

	# ── 說話者名稱 ────────────────────────────────────────────────────────
	_name_lbl = Label.new()
	_name_lbl.text = ""
	_name_lbl.add_theme_font_size_override("font_size", 7)
	_name_lbl.modulate   = Color(0.95, 1.00, 0.65)
	_name_lbl.position   = Vector2(PADDING + PORT_W + 3, PADDING)
	_name_lbl.size       = Vector2(DLG_W - PADDING * 2 - PORT_W - 3, NAME_H)
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_lbl)

	# ── 分隔線 ────────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color        = Color(0.45, 0.70, 0.28, 0.50)
	sep.position     = Vector2(PADDING, PADDING + NAME_H + 2)
	sep.size         = Vector2(DLG_W - PADDING * 2, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

	# ── 對話文字 ──────────────────────────────────────────────────────────
	_text_lbl = Label.new()
	_text_lbl.text = ""
	_text_lbl.add_theme_font_size_override("font_size", 6)
	_text_lbl.modulate             = Color(0.92, 0.96, 0.82)
	_text_lbl.position             = Vector2(PADDING, PADDING + NAME_H + 6)
	_text_lbl.size                 = Vector2(DLG_W - PADDING * 2 - 10, DLG_H - PADDING - NAME_H - 10)
	_text_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	add_child(_text_lbl)

	# ── ▼ 繼續指示器 ──────────────────────────────────────────────────────
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 6)
	_arrow.modulate   = Color(0.85, 1.00, 0.50)
	_arrow.position   = Vector2(DLG_W - PADDING - 8, DLG_H - PADDING - 6)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)


func _process(delta: float) -> void:
	if not visible:
		return
	# ▼ 閃爍
	_arrow_time += delta
	_arrow.modulate.a = 0.5 + 0.5 * sin(_arrow_time * 4.0)


# ── 公開 API ─────────────────────────────────────────────────────────────────

## 開啟對話框
## speaker: 說話者名稱（空字串則不顯示名稱列）
## pages: 每個字串為一頁文字
## portrait_col: 頭像色塊顏色（可選）
func show_dialog(speaker: String, pages: Array, portrait_col: Color = Color(0.55, 0.75, 0.45)) -> void:
	_pages    = []
	for p in pages:
		_pages.append(str(p))
	_page_idx = 0
	_arrow_time = 0.0

	_name_lbl.text = speaker
	_name_lbl.visible = not speaker.is_empty()

	var portrait : ColorRect = get_node("Portrait")
	portrait.color   = portrait_col
	portrait.visible = not speaker.is_empty()

	_show_page(0)
	show()


## 按 action 鍵時呼叫（翻頁或關閉）
func advance() -> void:
	_page_idx += 1
	if _page_idx >= _pages.size():
		_close()
	else:
		_show_page(_page_idx)


func is_open() -> bool:
	return visible


# ── 私有 ──────────────────────────────────────────────────────────────────────

func _show_page(idx: int) -> void:
	_text_lbl.text = _pages[idx]
	# 最後一頁時把 ▼ 改成表示關閉
	if idx >= _pages.size() - 1:
		_arrow.text    = "■"
		_arrow.modulate = Color(0.70, 0.85, 0.50)
	else:
		_arrow.text    = "▼"
		_arrow.modulate = Color(0.85, 1.00, 0.50)


func _close() -> void:
	hide()
	_pages.clear()
	dialog_closed.emit()
