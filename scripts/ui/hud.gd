## HUD — 遊戲介面控制器 (S11-T01, S11-T02)
## 顯示時間、日期/季節、體力條
extends CanvasLayer

@onready var _time_label    : Label       = $TimePanel/VBox/TimeLabel
@onready var _date_label    : Label       = $TimePanel/VBox/DateLabel
@onready var _stamina_bar   : ProgressBar = $StaminaBar


func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)

	# 初始化顯示
	_on_time_changed(TimeManager.hour, TimeManager.minute)
	_on_day_changed(TimeManager.day, TimeManager.season, TimeManager.year)


func _process(_delta: float) -> void:
	_refresh_stamina()


# ── 訊號回呼 ──────────────────────────────────────────────────────────────

func _on_time_changed(h: int, m: int) -> void:
	_time_label.text = "%02d:%02d" % [h, m]


func _on_day_changed(d: int, s: int, _y: int) -> void:
	_date_label.text = "%s 第%d天" % [TimeManager.SEASONS[s], d]


# ── 體力條 ────────────────────────────────────────────────────────────────

func _refresh_stamina() -> void:
	var player : Node = get_tree().get_first_node_in_group("player")
	if player:
		var pct : float = player.stamina / player.STAMINA_MAX
		_stamina_bar.value = pct * 100.0
		# 體力低於 30% 變紅
		var fill := _stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = Color(0.85, 0.22, 0.22) if pct < 0.3 else Color(0.25, 0.78, 0.35)
