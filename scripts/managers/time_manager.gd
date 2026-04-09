## TimeManager — 遊戲時間與季節系統 (S02-T01~T03)
## Autoload 單例，掛在 project.godot
extends Node

# ── 常數 ─────────────────────────────────────────────────────────────────
const HOURS_PER_DAY := 24
const MINUTES_PER_HOUR := 60

const SEASON_EN: Array[String] = ["spring", "summer", "autumn", "winter"]
const SEASON_KEYS: Array[String] = ["SEASON_SPRING", "SEASON_SUMMER", "SEASON_FALL", "SEASON_WINTER"]

const DAY_START_MINUTE := 0

# ── 狀態 ─────────────────────────────────────────────────────────────────
var hour: int = GameConfig.DAY_START_HOUR
var minute: int = DAY_START_MINUTE
var day: int = 1
var season: int = 0 # 0=春 1=夏 2=秋 3=冬
var year: int = 1

var paused: bool = false

var _accum: float = 0.0

# 每天已觸發過的夜深時間（避免重複發訊號）
var _late_night_notified: Array = [] # 記錄哪些整點已通知過
var _forced_sleep_done: bool = false

# ── 訊號 ─────────────────────────────────────────────────────────────────
signal time_changed(hour: int, minute: int)
signal day_changed(day: int, season: int, year: int)
signal season_changed(season: int)
signal late_night(hour: int) ## 01:00 / 02:00 / 03:00：依時間給予提示
signal forced_sleep ## 04:00：強制暈倒


func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta * GameConfig.TIME_SPEED
	while _accum >= 1.0:
		_accum -= 1.0
		_tick_minute()


# ── 公開方法 ─────────────────────────────────────────────────────────────

## 睡覺後推進到隔天早上
func advance_to_next_day() -> void:
	hour = GameConfig.DAY_START_HOUR
	minute = DAY_START_MINUTE
	_accum = 0.0
	_late_night_notified.clear()
	_forced_sleep_done = false
	_advance_day()
	time_changed.emit(hour, minute)


func get_time_string() -> String:
	return "%02d:%02d" % [hour, minute]


func get_date_string() -> String:
	return tr("HUD_DATE") % [tr(SEASON_KEYS[season]), day]


## 時段（依語系）
func get_period() -> String:
	if hour < 6: return tr("PERIOD_MIDNIGHT")
	if hour < 9: return tr("PERIOD_MORNING")
	if hour < 12: return tr("PERIOD_FORENOON")
	if hour < 18: return tr("PERIOD_AFTERNOON")
	if hour < 21: return tr("PERIOD_EVENING")
	return tr("PERIOD_NIGHT")


# ── 私有 ─────────────────────────────────────────────────────────────────

func _tick_minute() -> void:
	minute += 1
	if minute >= MINUTES_PER_HOUR:
		minute = 0
		hour += 1
		if hour >= HOURS_PER_DAY:
			hour = 0
			_late_night_notified.clear()
			_forced_sleep_done = false
			_advance_day()
	time_changed.emit(hour, minute)
	# 夜深警告（01:00 / 02:00 / 03:00 各觸發一次）
	if minute == 0 and hour in [1, 2, 3] and not (hour in _late_night_notified):
		_late_night_notified.append(hour)
		late_night.emit(hour)
	# 強制暈倒（04:00）
	if hour == 4 and minute == 0 and not _forced_sleep_done:
		_forced_sleep_done = true
		forced_sleep.emit()


func _advance_day() -> void:
	day += 1
	if day > GameConfig.DAYS_PER_SEASON:
		day = 1
		season = (season + 1) % 4
		if season == 0:
			year += 1
		season_changed.emit(season)
	day_changed.emit(day, season, year)
