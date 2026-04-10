## WeatherEffect — 天氣視覺特效 (S02-T10)
## CanvasLayer Autoload：在畫面上層繪製雨/雪粒子，跨場景持續顯示
extends CanvasLayer

# ── 視口尺寸 ─────────────────────────────────────────────────────────────
const VP_W := 320
const VP_H := 180

# ── 雨的參數 ─────────────────────────────────────────────────────────────
const RAIN_COUNT := 110
const RAIN_SPD_Y := 255.0   # 垂直速度（像素/秒）
const RAIN_SPD_X :=  52.0   # 水平偏移（斜角雨）
const RAIN_LEN   :=   7     # 雨絲長度（像素）
const RAIN_COLOR := Color(0.72, 0.88, 1.00, 0.50)

# ── 雪的參數 ─────────────────────────────────────────────────────────────
const SNOW_COUNT := 55
const SNOW_SPD_Y := 28.0    # 垂直速度
const SNOW_DRIFT := 10.0    # 水平擺動振幅（像素/秒）
const SNOW_COLOR := Color(1.00, 1.00, 1.00, 0.85)

# ── 粒子陣列（每個粒子 = [x, y, speed_mul, phase]） ─────────────────────
var _particles : Array = []
var _active    : bool  = false
var _type      : int   = -1   # WeatherManager.Weather 值

var _canvas    : Node2D


# ── 內部繪圖節點（extends Node2D 以便使用 draw_* API） ──────────────────
class _WeatherCanvas extends Node2D:
	var effect : Node   # WeatherEffect 的引用

	func _draw() -> void:
		if effect == null:
			return
		effect._draw_particles(self)


# ─────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 5   # 在世界場景（0）之上，HUD（10）之下，TransitionManager（100）之下
	var wc := _WeatherCanvas.new()
	wc.effect = self
	_canvas = wc
	add_child(_canvas)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(WeatherManager.current_weather)


func _process(delta: float) -> void:
	if not _active:
		return
	_update_particles(delta)
	_canvas.queue_redraw()


# ── 天氣切換 ─────────────────────────────────────────────────────────────

func _on_weather_changed(weather: int) -> void:
	_type   = weather
	_active = (weather == WeatherManager.Weather.RAINY or
			   weather == WeatherManager.Weather.SNOWY)
	_init_particles()
	_canvas.queue_redraw()


# ── 粒子初始化（散佈整個畫面，避免出現前先空白） ────────────────────────

func _init_particles() -> void:
	_particles.clear()
	if not _active:
		return
	var count := RAIN_COUNT if _type == WeatherManager.Weather.RAINY else SNOW_COUNT
	for i in range(count):
		_particles.append([
			randf_range(-20.0, VP_W + 20.0),   # x
			randf_range(-15.0, VP_H + 10.0),   # y（預散佈整個畫面）
			randf_range(0.80, 1.20),            # speed_mul（速度倍率，增加多樣性）
			randf_range(0.0, TAU),              # phase（雪的擺動相位）
		])


# ── 每幀更新粒子位置 ─────────────────────────────────────────────────────

func _update_particles(delta: float) -> void:
	if _type == WeatherManager.Weather.RAINY:
		for p in _particles:
			p[0] += RAIN_SPD_X * delta * p[2]
			p[1] += RAIN_SPD_Y * delta * p[2]
			# 超出底部：重置至頂部隨機 x
			if p[1] > VP_H + RAIN_LEN + 2.0:
				p[0] = randf_range(-20.0, VP_W + 20.0)
				p[1] = randf_range(float(-RAIN_LEN) - 10.0, -2.0)
	else:  # SNOWY
		for p in _particles:
			p[3] += delta * 1.1                         # 相位遞增
			p[0] += cos(p[3]) * SNOW_DRIFT * delta      # 左右飄動
			p[1] += SNOW_SPD_Y * delta * p[2]
			# 超出底部：重置至頂部
			if p[1] > VP_H + 4.0:
				p[0] = randf_range(-10.0, VP_W + 10.0)
				p[1] = randf_range(-8.0, -1.0)


# ── 繪製粒子（由 _WeatherCanvas._draw() 呼叫） ───────────────────────────

func _draw_particles(canvas: Node2D) -> void:
	if not _active:
		return
	if _type == WeatherManager.Weather.RAINY:
		# 每根雨絲：斜線，頂端透明、底端不透明
		for p in _particles:
			var tail := Vector2(p[0], p[1])
			var head := Vector2(
				p[0] - RAIN_SPD_X * 0.024,
				p[1] - float(RAIN_LEN)
			)
			# 頂端較淡，底端較濃
			canvas.draw_line(head, tail, RAIN_COLOR * Color(1, 1, 1, 0.5), 1.0, false)
			canvas.draw_line(tail, tail + Vector2(0.0, 1.0),
							 RAIN_COLOR, 1.0, false)
	elif _type == WeatherManager.Weather.SNOWY:
		# 每個雪片：2×2 白色方塊
		for p in _particles:
			canvas.draw_rect(
				Rect2(floor(p[0]), floor(p[1]), 2.0, 2.0),
				SNOW_COLOR
			)
