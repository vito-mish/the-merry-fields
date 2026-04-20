## HUD — 遊戲介面控制器 (S11-T01, S11-T02, S11-T03, S11-T04)
extends CanvasLayer

const NOTIFY_DURATION := 4.0

var _notify_label : Label
var _notify_timer : float = 0.0
var _hint_label   : Label

# ── 作物生長資訊面板 ─────────────────────────────────────────────────────
var _crop_info_root  : PanelContainer = null
var _crop_info_name  : Label
var _crop_info_bar   : Label
var _crop_info_stat  : Label

# ── 背包 UI ──────────────────────────────────────────────────────────────
var _inventory_ui    : Control = null
var inventory_open   : bool    = false

# ── 工具列常數 ────────────────────────────────────────────────────────────
const TOOL_ICONS : Dictionary = {
	"hoe":          "鋤",
	"watering_can": "壺",
	"seeds":        "種",
}
const TOOL_COLORS : Dictionary = {
	"hoe":          Color(0.80, 0.58, 0.28, 1.0),
	"watering_can": Color(0.28, 0.60, 0.90, 1.0),
	"seeds":        Color(0.35, 0.78, 0.32, 1.0),
}
const SLOT_SIZE   : int = 18
const SLOT_GAP    : int = 2

@onready var _time_label    : Label       = $TimePanel/VBox/TimeLabel
@onready var _date_label    : Label       = $TimePanel/VBox/DateLabel
@onready var _weather_label : Label       = $TimePanel/VBox/WeatherLabel
@onready var _gold_label    : Label       = $GoldLabel
@onready var _stamina_bar   : ProgressBar = $StaminaBar
@onready var _toolbar       : Control     = $Toolbar


func _ready() -> void:
	add_to_group("hud")
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.late_night.connect(_on_late_night)
	TimeManager.forced_sleep.connect(func() -> void: show_notification(tr("NOTIFY_FAINTED")))
	EconomyManager.gold_changed.connect(_on_gold_changed)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	_on_time_changed(TimeManager.hour, TimeManager.minute)
	_on_day_changed(TimeManager.day, TimeManager.season, TimeManager.year)
	_on_gold_changed(EconomyManager.gold)
	_on_weather_changed(WeatherManager.current_weather)
	_build_overlay_labels()
	_build_crop_info_panel()
	_build_inventory_ui()
	# 出貨箱結算報表（延遲一幀確保 shipping_box 已加入場景）
	call_deferred("_connect_shipping_box")


# ── 時間訊號 ──────────────────────────────────────────────────────────────

func _on_time_changed(h: int, m: int) -> void:
	_time_label.text = "%02d:%02d" % [h, m]


func _on_day_changed(_d: int, _s: int, _y: int) -> void:
	_date_label.text = TimeManager.get_date_string()


func _on_gold_changed(amount: int) -> void:
	_gold_label.text = tr("HUD_GOLD") % amount


func _on_weather_changed(weather: int) -> void:
	_weather_label.text = WeatherManager.get_weather_label()


func _on_locale_changed(_locale: String) -> void:
	# 語系切換後強制刷新所有文字
	_date_label.text = TimeManager.get_date_string()
	_gold_label.text = tr("HUD_GOLD") % EconomyManager.gold
	_toolbar.queue_redraw()


# ── 體力條 ────────────────────────────────────────────────────────────────

func _refresh_stamina() -> void:
	var player : Node = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var pct : float = player.stamina / GameConfig.STAMINA_MAX
	_stamina_bar.value = pct * 100.0
	var fill := _stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color(0.85, 0.22, 0.22, 1.0) if pct < 0.3 else Color(0.25, 0.78, 0.35, 1.0)


# ── 通知 / 提示標籤 ───────────────────────────────────────────────────────

func _build_overlay_labels() -> void:
	# 通知（有時限，居中上方）
	_notify_label = Label.new()
	_notify_label.add_theme_font_size_override("font_size", 7)
	_notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notify_label.anchor_left   = 0.5
	_notify_label.anchor_right  = 0.5
	_notify_label.anchor_top    = 0.0
	_notify_label.anchor_bottom = 0.0
	_notify_label.offset_left   = -80.0
	_notify_label.offset_right  =  80.0
	_notify_label.offset_top    =  36.0
	_notify_label.offset_bottom =  50.0
	_notify_label.modulate      = Color(1.0, 1.0, 0.5, 1.0)
	_notify_label.hide()
	add_child(_notify_label)

	# 互動提示（持續顯示直到離開觸發區）
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 7)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.anchor_left   = 0.5
	_hint_label.anchor_right  = 0.5
	_hint_label.anchor_top    = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left   = -60.0
	_hint_label.offset_right  =  60.0
	_hint_label.offset_top    = -42.0
	_hint_label.offset_bottom = -28.0
	_hint_label.modulate      = Color(1.0, 1.0, 1.0, 0.9)
	_hint_label.hide()
	add_child(_hint_label)


func _on_late_night(h: int) -> void:
	match h:
		1: show_notification(tr("NOTIFY_01"))
		2: show_notification(tr("NOTIFY_02"))
		3: show_notification(tr("NOTIFY_03"))


func _build_crop_info_panel() -> void:
	_crop_info_root = PanelContainer.new()
	_crop_info_root.anchor_left   = 0.5
	_crop_info_root.anchor_right  = 0.5
	_crop_info_root.anchor_top    = 1.0
	_crop_info_root.anchor_bottom = 1.0
	_crop_info_root.offset_left   = -55.0
	_crop_info_root.offset_right  =  55.0
	_crop_info_root.offset_top    = -68.0
	_crop_info_root.offset_bottom = -28.0
	var sty := StyleBoxFlat.new()
	sty.bg_color    = Color(0.04, 0.08, 0.04, 0.88)
	sty.border_color = Color(0.40, 0.70, 0.28, 0.90)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sty.set_border_width(side, 1)
	sty.set_corner_radius_all(2)
	sty.content_margin_left   = 4.0
	sty.content_margin_right  = 4.0
	sty.content_margin_top    = 2.0
	sty.content_margin_bottom = 2.0
	_crop_info_root.add_theme_stylebox_override("panel", sty)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	_crop_info_root.add_child(vb)
	_crop_info_name = Label.new()
	_crop_info_name.add_theme_font_size_override("font_size", 7)
	_crop_info_name.modulate = Color(0.90, 1.00, 0.65)
	vb.add_child(_crop_info_name)
	_crop_info_bar = Label.new()
	_crop_info_bar.add_theme_font_size_override("font_size", 7)
	_crop_info_bar.modulate = Color(0.75, 0.92, 0.50)
	vb.add_child(_crop_info_bar)
	_crop_info_stat = Label.new()
	_crop_info_stat.add_theme_font_size_override("font_size", 6)
	_crop_info_stat.modulate = Color(0.65, 0.82, 0.90)
	vb.add_child(_crop_info_stat)
	_crop_info_root.hide()
	add_child(_crop_info_root)


func _update_crop_info() -> void:
	if _crop_info_root == null:
		return
	var player : Node = get_tree().get_first_node_in_group("player")
	if not player:
		_crop_info_root.hide()
		return
	var farm_grid : Node = get_tree().get_first_node_in_group("farm_grid")
	if not farm_grid:
		_crop_info_root.hide()
		return
	var info : Dictionary = farm_grid.get_crop_progress(player._facing_tile_pos)
	if info.is_empty():
		_crop_info_root.hide()
		return
	# 名稱列
	if info["mature"]:
		_crop_info_name.text = info["name"] + "  ★ 可收成"
	else:
		var days_left : int = info["total"] - info["stage"]
		_crop_info_name.text = info["name"] + "  還需 " + str(days_left) + " 天"
	# 進度條（12 格）
	var filled : int = int(float(info["stage"]) / float(max(info["total"], 1)) * 12.0)
	var bar_str := "["
	for i in range(12):
		bar_str += "=" if i < filled else "."
	bar_str += "]"
	_crop_info_bar.text = bar_str
	# 狀態列
	var w_str : String = "澆水 O" if info["watered_today"] else "澆水 X"
	var f_str : String = "  施肥 O" if info["fertilized"]    else "  施肥 X"
	_crop_info_stat.text = w_str + f_str
	_crop_info_root.show()


func _build_inventory_ui() -> void:
	var script : GDScript = load("res://scripts/ui/inventory_ui.gd")
	_inventory_ui = script.new()
	_inventory_ui.seed_selected.connect(_on_inventory_seed_selected)
	add_child(_inventory_ui)


func _on_inventory_seed_selected(crop_id: String) -> void:
	var player : Node = get_tree().get_first_node_in_group("player")
	if player:
		player.seed_crop_id = crop_id
		_toolbar.queue_redraw()


func toggle_inventory() -> void:
	if _inventory_ui == null:
		return
	if inventory_open:
		_close_inventory()
	else:
		_open_inventory()


func _open_inventory() -> void:
	var player : Node = get_tree().get_first_node_in_group("player")
	var crop_id : String = player.seed_crop_id if player else "turnip"
	_inventory_ui.open_inventory(crop_id)
	inventory_open = true


func _close_inventory() -> void:
	_inventory_ui.close_inventory()
	inventory_open = false


func refresh_toolbar() -> void:
	_toolbar.queue_redraw()


func show_notification(text: String, color: Color = Color(1.0, 1.0, 0.5, 1.0)) -> void:
	_notify_label.text = text
	_notify_label.modulate = color
	_notify_label.show()
	_notify_timer = NOTIFY_DURATION


func show_harvest_notification(quality: String) -> void:
	var text  : String
	var color : Color
	match quality:
		"premium":
			text  = "[精品] 收成！"
			color = Color(0.85, 0.35, 1.0, 1.0)   # 紫色
		"good":
			text  = "[優良] 收成！"
			color = Color(1.00, 0.85, 0.20, 1.0)  # 金色
		_:
			text  = "收成！"
			color = Color(1.00, 1.00, 0.50, 1.0)  # 黃色（普通）
	_notify_label.text    = text
	_notify_label.modulate = color
	_notify_label.show()
	_notify_timer = NOTIFY_DURATION


func show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.show()


func hide_hint() -> void:
	_hint_label.hide()


# ── 出貨結算報表 ──────────────────────────────────────────────────────────────

var _report_panel  : PanelContainer
var _report_label  : Label
var report_open    : bool = false   # Player 讀取此值來鎖定移動


func _connect_shipping_box() -> void:
	var box : Node = get_tree().get_first_node_in_group("shipping_box")
	if box:
		box.items_shipped.connect(_on_items_shipped)


func _on_items_shipped(total_gold: int, lines: Array) -> void:
	var text := "出貨結算\n"
	for line in lines:
		text += "%s [%s] x%d  +%dG\n" % [
			line["name"], line["quality_label"], line["count"], line["subtotal"]
		]
	text += "----------\n合計  +%dG" % total_gold
	_show_report(text)


func _show_report(text: String) -> void:
	if _report_panel == null:
		_build_report_panel()
	_report_label.text = text
	_report_panel.show()
	report_open = true


func _close_report() -> void:
	_report_panel.hide()
	report_open = false


func _build_report_panel() -> void:
	_report_panel = PanelContainer.new()
	_report_panel.anchor_left   = 0.5
	_report_panel.anchor_right  = 0.5
	_report_panel.anchor_top    = 0.5
	_report_panel.anchor_bottom = 0.5
	_report_panel.offset_left   = -72.0
	_report_panel.offset_right  =  72.0
	_report_panel.offset_top    = -55.0
	_report_panel.offset_bottom =  55.0

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.08, 0.08, 0.10, 0.92)
	style.border_width_left          = 1
	style.border_width_right         = 1
	style.border_width_top           = 1
	style.border_width_bottom        = 1
	style.border_color               = Color(0.70, 0.65, 0.30, 1.0)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	_report_panel.add_theme_stylebox_override("panel", style)

	# 垂直容器
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_report_panel.add_child(vbox)

	# 報表文字
	_report_label = Label.new()
	_report_label.add_theme_font_size_override("font_size", 7)
	_report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_report_label.modulate = Color(1.0, 1.0, 0.85, 1.0)
	vbox.add_child(_report_label)

	# 關閉按鈕
	var btn        := Button.new()
	btn.text        = "[ 確認 ]"
	btn.add_theme_font_size_override("font_size", 7)
	btn.flat        = true
	btn.modulate    = Color(1.0, 0.85, 0.30, 1.0)
	btn.pressed.connect(_close_report)
	vbox.add_child(btn)

	_report_panel.hide()
	add_child(_report_panel)


func _process(delta: float) -> void:
	_refresh_stamina()
	_toolbar.queue_redraw()
	_update_crop_info()
	if _notify_timer > 0.0:
		_notify_timer -= delta
		if _notify_timer <= 0.0:
			_notify_label.hide()
