## TreeObject — 像素風格樹木（支援 Y-sort 遮擋）
## Node2D 的 position.y 代表樹根（地面）位置，
## 父節點需開啟 y_sort_enabled = true 才能正確排序遮擋
extends Node2D

## 樹的高矮變化（0.8 ~ 1.2）
@export var scale_factor : float = 1.0

## 隨機種子（讓每棵樹顏色略有不同）
@export var seed_val : int = 0


func _ready() -> void:
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var green_base := Color(0.18 + rng.randf_range(-0.03, 0.03),
							0.55 + rng.randf_range(-0.05, 0.05),
							0.18 + rng.randf_range(-0.02, 0.02))
	var green_hi   := green_base.lightened(0.15)
	var brown      := Color(0.42 + rng.randf_range(-0.04, 0.04),
							0.26 + rng.randf_range(-0.03, 0.03),
							0.10)

	var s := scale_factor

	# ── 影子（橢圓，畫在底部） ───────────────────────────────────────────
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.18)
	shadow.polygon = _ellipse(7 * s, 3 * s)
	shadow.position = Vector2(0, -1)
	shadow.z_index = -1
	add_child(shadow)

	# ── 樹幹 ─────────────────────────────────────────────────────────────
	var trunk := Polygon2D.new()
	trunk.color = brown
	var hw: float = maxf(2.0, 3.0 * s)
	var th := 14.0 * s
	trunk.polygon = PackedVector2Array([
		Vector2(-hw, 0), Vector2(hw, 0),
		Vector2(hw - 1, -th), Vector2(-hw + 1, -th)
	])
	add_child(trunk)

	# ── 葉子（下層） ─────────────────────────────────────────────────────
	var fol_lo := Polygon2D.new()
	fol_lo.color = green_base
	fol_lo.polygon = _ellipse(10 * s, 8 * s)
	fol_lo.position = Vector2(0, -18 * s)
	add_child(fol_lo)

	# ── 葉子（上層） ─────────────────────────────────────────────────────
	var fol_hi := Polygon2D.new()
	fol_hi.color = green_hi
	fol_hi.polygon = _ellipse(7 * s, 6 * s)
	fol_hi.position = Vector2(-1 * s, -27 * s)
	add_child(fol_hi)


## 產生橢圓多邊形頂點（12 邊近似）
func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 12
	for i in range(steps):
		var a := i * TAU / steps
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
