## WeatherManager — 天氣系統 (S02-T09)
## Autoload 單例，每天早上根據季節機率決定當天天氣
extends Node

# ── 天氣類型 ─────────────────────────────────────────────────────────────
enum Weather {
	SUNNY  = 0,  ## 晴天
	CLOUDY = 1,  ## 陰天
	RAINY  = 2,  ## 雨天
	SNOWY  = 3,  ## 雪天
}

## 天氣 i18n 鍵值（搭配 LocaleManager 或直接顯示中文）
const WEATHER_LABELS: Array[String] = ["晴", "陰", "雨", "雪"]

## 各季天氣機率表 [SUNNY, CLOUDY, RAINY, SNOWY]（加總 = 1.0）
## season 0=春 1=夏 2=秋 3=冬
const WEATHER_WEIGHTS: Array[Array] = [
	[0.50, 0.30, 0.20, 0.00],  # 春
	[0.60, 0.20, 0.20, 0.00],  # 夏
	[0.40, 0.30, 0.30, 0.00],  # 秋
	[0.25, 0.25, 0.20, 0.30],  # 冬
]

# ── 狀態 ─────────────────────────────────────────────────────────────────
var current_weather: int = Weather.SUNNY

# ── 訊號 ─────────────────────────────────────────────────────────────────
signal weather_changed(weather: int)


func _ready() -> void:
	# 遊戲啟動時先根據當前季節決定天氣
	_roll_weather(TimeManager.season)
	# 每天換日時重新決定天氣
	TimeManager.day_changed.connect(_on_day_changed)


# ── 公開方法 ─────────────────────────────────────────────────────────────

## 回傳當天天氣的中文標籤
func get_weather_label() -> String:
	return WEATHER_LABELS[current_weather]


## 目前是否正在下雨
func is_raining() -> bool:
	return current_weather == Weather.RAINY


## 目前是否正在下雪
func is_snowing() -> bool:
	return current_weather == Weather.SNOWY


## 目前是否天氣陰暗（陰/雨/雪）
func is_overcast() -> bool:
	return current_weather != Weather.SUNNY


# ── 私有 ─────────────────────────────────────────────────────────────────

func _on_day_changed(day: int, season: int, _year: int) -> void:
	_roll_weather(season)


func _roll_weather(season: int) -> void:
	var weights: Array = WEATHER_WEIGHTS[season]
	var roll: float = randf()
	var cumulative: float = 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			current_weather = i
			weather_changed.emit(current_weather)
			return
	# 保底（浮點誤差）
	current_weather = Weather.SUNNY
	weather_changed.emit(current_weather)
