## GameMenu — ESC 開啟遊戲選單
## 流程：主選單 → 設定 → 語言列表
extends Control

const FONT_SZ   := 7
const BTN_MIN_H := 12

var _menu_panel     : PanelContainer
var _settings_panel : PanelContainer
var _lang_option    : OptionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暫停時仍可操作選單
	# anchors 已在 tscn 設為 full rect，清除 offset 確保完全填滿
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_build_ui()
	LocaleManager.locale_changed.connect(_on_locale_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if visible:
			_on_resume()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()


# ── UI 建構 ───────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color       = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	_menu_panel     = _build_main_panel()
	_settings_panel = _build_settings_panel()
	add_child(_menu_panel)
	add_child(_settings_panel)
	_settings_panel.hide()


func _build_main_panel() -> PanelContainer:
	var panel := _make_panel(100, 68)
	var vbox  := _panel_vbox(panel)

	var title := _make_label("MENU", 8, true)
	vbox.add_child(title)
	vbox.add_child(_make_separator())

	_add_button(vbox, tr("MENU_RESUME"),   _on_resume)
	_add_button(vbox, tr("MENU_SETTINGS"), _on_settings)
	_add_button(vbox, tr("MENU_QUIT"),     _on_quit)
	return panel


func _build_settings_panel() -> PanelContainer:
	var panel := _make_panel(120, 62)
	var vbox  := _panel_vbox(panel)

	vbox.add_child(_make_label(tr("SETTINGS_TITLE"), FONT_SZ, true))
	vbox.add_child(_make_separator())

	# 語言列
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vbox.add_child(row)

	var lbl := _make_label(tr("SETTINGS_LANGUAGE"), FONT_SZ, false)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	_lang_option = _make_option_button()
	_lang_option.add_item("繁體中文", 0)
	_lang_option.add_item("English",  1)
	_lang_option.selected = LocaleManager.LOCALES.find(LocaleManager.current_locale)
	_lang_option.item_selected.connect(_on_lang_selected)
	row.add_child(_lang_option)

	vbox.add_child(_make_separator())
	_add_button(vbox, tr("MENU_BACK"), _on_back)
	return panel


func _make_option_button() -> OptionButton:
	var btn := OptionButton.new()
	btn.custom_minimum_size = Vector2(62, BTN_MIN_H)
	btn.add_theme_font_size_override("font_size", FONT_SZ)

	# 縮小按鈕本體的內距
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.18, 0.22, 1.0) if state != "hover" else Color(0.25, 0.25, 0.30, 1.0)
		s.set_corner_radius_all(2)
		s.set_content_margin(SIDE_LEFT,   3)
		s.set_content_margin(SIDE_RIGHT,  3)
		s.set_content_margin(SIDE_TOP,    1)
		s.set_content_margin(SIDE_BOTTOM, 1)
		btn.add_theme_stylebox_override(state, s)

	# 縮小下拉清單的字型與間距
	var popup := btn.get_popup()
	popup.add_theme_font_size_override("font_size", FONT_SZ)
	popup.add_theme_constant_override("v_separation",      2)
	popup.add_theme_constant_override("item_start_padding", 4)
	popup.add_theme_constant_override("item_end_padding",   4)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.15, 0.18, 0.97)
	ps.set_corner_radius_all(2)
	ps.set_content_margin_all(2)
	popup.add_theme_stylebox_override("panel", ps)
	return btn


# ── 工具函式 ─────────────────────────────────────────────────────────────

func _make_panel(w: int, h: int) -> PanelContainer:
	var p     := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.12, 0.95)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(7)
	p.add_theme_stylebox_override("panel", style)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.set_offset(SIDE_LEFT,   -w * 0.5)
	p.set_offset(SIDE_TOP,    -h * 0.5)
	p.set_offset(SIDE_RIGHT,   w * 0.5)
	p.set_offset(SIDE_BOTTOM,  h * 0.5)
	return p


func _panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)
	return vbox


func _make_label(text: String, fs: int, centered: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", fs)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = BTN_MIN_H
	btn.add_theme_font_size_override("font_size", FONT_SZ)
	btn.pressed.connect(callback)
	parent.add_child(btn)




# ── 動作 ─────────────────────────────────────────────────────────────────

func _open_menu() -> void:
	_menu_panel.show()
	_settings_panel.hide()
	show()
	get_tree().paused = true


func _on_resume() -> void:
	hide()
	get_tree().paused = false


func _on_settings() -> void:
	_menu_panel.hide()
	_settings_panel.show()


func _on_back() -> void:
	_settings_panel.hide()
	_menu_panel.show()


func _on_lang_selected(index: int) -> void:
	LocaleManager.set_locale(LocaleManager.LOCALES[index])


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_locale_changed(_locale: String) -> void:
	# 同步 OptionButton 選中項（外部切換時保持一致）
	if _lang_option:
		_lang_option.selected = LocaleManager.LOCALES.find(_locale)
