## TreeObject — 像素風格樹木（支援 Y-sort 遮擋）
extends Node2D

@export var scale_factor : float = 1.0
@export var seed_val     : int   = 0

var _fol_lo    : Polygon2D   # 葉子下層（春夏秋）
var _fol_hi    : Polygon2D   # 葉子上層（春夏秋）
var _blossoms  : Array       # 春：花朵小點
var _branches  : Array       # 冬：裸枝
var _snow_cap  : Polygon2D   # 冬：積雪


func _ready() -> void:
	_build()
	_set_season(TimeManager.season)
	TimeManager.season_changed.connect(_set_season)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var s   := scale_factor
	var brown := Color(0.38 + rng.randf_range(-0.04, 0.04),
					   0.24 + rng.randf_range(-0.03, 0.03), 0.10)

	# ── 影子 ─────────────────────────────────────────────────────────────
	var shadow := Polygon2D.new()
	shadow.color   = Color(0, 0, 0, 0.18)
	shadow.polygon = _ellipse(7 * s, 3 * s)
	shadow.position = Vector2(0, -1)
	shadow.z_index  = -1
	add_child(shadow)

	# ── 樹幹 ─────────────────────────────────────────────────────────────
	var hw   : float = maxf(2.0, 3.0 * s)
	var th   : float = 14.0 * s
	var trunk := Polygon2D.new()
	trunk.color   = brown
	trunk.polygon = PackedVector2Array([
		Vector2(-hw, 0), Vector2(hw, 0),
		Vector2(hw - 1, -th), Vector2(-hw + 1, -th)
	])
	add_child(trunk)

	# ── 葉子（春/夏/秋用） ───────────────────────────────────────────────
	_fol_lo = Polygon2D.new()
	_fol_lo.position = Vector2(0, -18 * s)
	add_child(_fol_lo)

	_fol_hi = Polygon2D.new()
	_fol_hi.position = Vector2(-1 * s, -27 * s)
	add_child(_fol_hi)

	# ── 春：花朵小點（隨機散佈在葉層上） ────────────────────────────────
	for i in range(5):
		var blossom := Polygon2D.new()
		blossom.color   = Color(1.0, 0.75, 0.80)
		blossom.polygon = _ellipse(1.5 * s, 1.5 * s)
		var angle := i * TAU / 5.0
		blossom.position = Vector2(
			cos(angle) * 6 * s,
			-20 * s + sin(angle) * 5 * s
		)
		add_child(blossom)
		_blossoms.append(blossom)

	# ── 冬：裸枝（2～3 條橫枝） ──────────────────────────────────────────
	var branch_color := brown.lightened(0.1)
	for i in range(3):
		var br := Polygon2D.new()
		br.color = branch_color
		var blen := (5 - i) * 3.0 * s
		var by   := -(th + 4 + i * 5) * s
		br.polygon = PackedVector2Array([
			Vector2(-blen, by - 1), Vector2(blen, by - 1),
			Vector2(blen, by + 1),  Vector2(-blen, by + 1),
		])
		add_child(br)
		_branches.append(br)

	# ── 冬：積雪帽 ───────────────────────────────────────────────────────
	_snow_cap = Polygon2D.new()
	_snow_cap.color   = Color(0.92, 0.95, 1.0)
	_snow_cap.polygon = _ellipse(5 * s, 2.5 * s)
	_snow_cap.position = Vector2(0, -(th + 6) * s)
	add_child(_snow_cap)


func _set_season(s: int) -> void:
	if _fol_lo == null:
		return
	var sf := scale_factor
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + s * 1000
	var drift := rng.randf_range(-0.04, 0.04)

	match s:
		0:  # ── 春：亮草綠 + 粉花 ─────────────────────────────────────
			_fol_lo.polygon  = _ellipse(10 * sf, 8 * sf)
			_fol_hi.polygon  = _ellipse(7  * sf, 6 * sf)
			_fol_lo.color    = Color(0.25, 0.82, 0.20).lightened(drift)
			_fol_hi.color    = Color(0.40, 0.95, 0.30).lightened(drift)
			_fol_lo.visible  = true
			_fol_hi.visible  = true
			for b in _blossoms:  b.visible = true
			for b in _branches:  b.visible = false
			_snow_cap.visible = false

		1:  # ── 夏：深墨綠，葉量最大 ─────────────────────────────────
			_fol_lo.polygon  = _ellipse(13 * sf, 10 * sf)
			_fol_hi.polygon  = _ellipse(9  * sf,  8 * sf)
			_fol_lo.color    = Color(0.08, 0.45, 0.08).lightened(drift)
			_fol_hi.color    = Color(0.12, 0.58, 0.12).lightened(drift)
			_fol_lo.visible  = true
			_fol_hi.visible  = true
			for b in _blossoms:  b.visible = false
			for b in _branches:  b.visible = false
			_snow_cap.visible = false

		2:  # ── 秋：橙紅，葉片縮小 ───────────────────────────────────
			_fol_lo.polygon  = _ellipse(8 * sf, 6 * sf)
			_fol_hi.polygon  = _ellipse(5 * sf, 4 * sf)
			# 每棵樹在橙/紅/黃之間隨機偏移
			var hue_shift := rng.randf_range(0.0, 0.15)
			_fol_lo.color = Color(0.85, 0.40 + hue_shift, 0.05).lightened(drift)
			_fol_hi.color = Color(0.95, 0.60 + hue_shift, 0.10).lightened(drift)
			_fol_lo.visible  = true
			_fol_hi.visible  = true
			for b in _blossoms:  b.visible = false
			for b in _branches:  b.visible = false
			_snow_cap.visible = false

		3:  # ── 冬：光禿樹枝 + 積雪 ─────────────────────────────────
			_fol_lo.visible  = false
			_fol_hi.visible  = false
			for b in _blossoms:  b.visible = false
			for b in _branches:  b.visible = true
			_snow_cap.visible = true


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts   := PackedVector2Array()
	var steps := 12
	for i in range(steps):
		var a := i * TAU / steps
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
