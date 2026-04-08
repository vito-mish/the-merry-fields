## HUD — 遊戲介面控制器 (S11-T01, S11-T02, S11-T04)
extends CanvasLayer

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

@onready var _time_label  : Label       = $TimePanel/VBox/TimeLabel
@onready var _date_label  : Label       = $TimePanel/VBox/DateLabel
@onready var _gold_label  : Label       = $GoldLabel
@onready var _stamina_bar : ProgressBar = $StaminaBar
@onready var _toolbar     : Control     = $Toolbar


func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	EconomyManager.gold_changed.connect(_on_gold_changed)
	_on_time_changed(TimeManager.hour, TimeManager.minute)
	_on_day_changed(TimeManager.day, TimeManager.season, TimeManager.year)
	_on_gold_changed(EconomyManager.gold)


func _process(_delta: float) -> void:
	_refresh_stamina()
	_toolbar.queue_redraw()


# ── 時間訊號 ──────────────────────────────────────────────────────────────

func _on_time_changed(h: int, m: int) -> void:
	_time_label.text = "%02d:%02d" % [h, m]


func _on_day_changed(d: int, s: int, _y: int) -> void:
	_date_label.text = "%s 第%d天" % [TimeManager.SEASONS[s], d]


func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "G %d" % amount


# ── 體力條 ────────────────────────────────────────────────────────────────

func _refresh_stamina() -> void:
	var player : Node = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var pct : float = player.stamina / player.STAMINA_MAX
	_stamina_bar.value = pct * 100.0
	var fill := _stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color(0.85, 0.22, 0.22, 1.0) if pct < 0.3 else Color(0.25, 0.78, 0.35, 1.0)
