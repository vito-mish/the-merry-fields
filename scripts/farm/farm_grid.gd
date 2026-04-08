## FarmGrid — 農地 Tile 狀態管理 (S04-T01~T08)
## 掛在 Farm 場景下，管理每塊農地的翻土/澆水/播種/生長/收成
extends Node

# ── 常數 ─────────────────────────────────────────────────────────────────
const T_DIRT    := Vector2i(1, 0)
const T_TILLED  := Vector2i(2, 0)
const T_WATERED := Vector2i(3, 0)
const SOURCE_ID := 0
const LAYER     := 0

# 農地範圍（farm.gd 產生的 DIRT 區域：x=-26~-4, y=-26~9）
const DIRT_X_MIN := -26
const DIRT_X_MAX := -4
const DIRT_Y_MIN := -26
const DIRT_Y_MAX :=  9

# 作物資料（從 JSON 讀取）
var _crop_db   : Dictionary = {}

# 每格 tile 的狀態
# key: Vector2i, value: { "state": "tilled"|"watered"|"planted",
#                          "crop_id": String, "day_planted": int,
#                          "days_watered": int, "watered_today": bool,
#                          "growth_stage": int }
var _tiles     : Dictionary = {}

# 作物視覺節點
# key: Vector2i, value: Node2D
var _crop_nodes: Dictionary = {}

@onready var _tile_map : TileMap = get_parent().get_node("TileMap")
@onready var _ysort    : Node2D  = get_parent().get_node("YSort")

# ── 訊號 ─────────────────────────────────────────────────────────────────
signal harvested(crop_id: String, quality: String)


func _ready() -> void:
	add_to_group("farm_grid")
	_load_crop_db()
	TimeManager.day_changed.connect(_on_day_changed)


# ── 公開 API ─────────────────────────────────────────────────────────────

## 翻土（鋤頭）：DIRT → TILLED
func till(tile_pos: Vector2i) -> bool:
	if not _is_farmable(tile_pos):
		return false
	var atlas := _tile_map.get_cell_atlas_coords(LAYER, tile_pos)
	if atlas != T_DIRT:
		return false
	_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_TILLED)
	_tiles[tile_pos] = { "state": "tilled", "watered_today": false }
	return true


## 澆水（澆水壺）：TILLED / PLANTED → WATERED
func water(tile_pos: Vector2i) -> bool:
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] == "tilled":
		_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_WATERED)
		t["state"] = "watered"
		t["watered_today"] = true
		return true
	if t["state"] == "planted":
		t["watered_today"] = true
		# 視覺上顯示深色（澆水後的土）
		_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_WATERED)
		return true
	return false


## 播種：TILLED / WATERED → PLANTED
func plant(tile_pos: Vector2i, crop_id: String) -> bool:
	if not _crop_db.has(crop_id):
		return false
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "tilled" and t["state"] != "watered":
		return false
	t["state"]         = "planted"
	t["crop_id"]       = crop_id
	t["day_planted"]   = TimeManager.day
	t["days_watered"]  = 1 if t.get("watered_today", false) else 0
	t["growth_stage"]  = 0
	_spawn_crop_visual(tile_pos, crop_id, 0)
	return true


## 收成：成熟的作物 → 獲得物品
func harvest(tile_pos: Vector2i) -> bool:
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "planted":
		return false
	var data : Dictionary = _crop_db[t["crop_id"]]
	if t["growth_stage"] < _total_stages(data):
		return false   # 還沒成熟

	var quality := _calc_quality(t)
	harvested.emit(t["crop_id"], quality)

	# 多次收成作物（番茄等）重置生長
	if data.get("multi_harvest", false):
		t["growth_stage"] = 0
		t["day_planted"]  = TimeManager.day
		t["days_watered"] = 0
		_update_crop_visual(tile_pos)
	else:
		# 清除
		_tiles.erase(tile_pos)
		if _crop_nodes.has(tile_pos):
			_crop_nodes[tile_pos].queue_free()
			_crop_nodes.erase(tile_pos)
		_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_DIRT)
	return true


## 查詢 tile 狀態（供 Player 決定要做什麼動作）
func get_tile_state(tile_pos: Vector2i) -> String:
	if not _tiles.has(tile_pos):
		var atlas := _tile_map.get_cell_atlas_coords(LAYER, tile_pos)
		if atlas == T_DIRT:
			return "dirt"
		return "none"
	return _tiles[tile_pos]["state"]


func is_mature(tile_pos: Vector2i) -> bool:
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "planted":
		return false
	var data : Dictionary = _crop_db[t["crop_id"]]
	return t["growth_stage"] >= _total_stages(data)


# ── 日期推進 ──────────────────────────────────────────────────────────────

func _on_day_changed(_day: int, _season: int, _year: int) -> void:
	var to_kill : Array[Vector2i] = []

	for pos : Vector2i in _tiles.keys():
		var t : Dictionary = _tiles[pos]
		if t["state"] != "planted":
			# 非種植格：重設澆水標記，隔天乾掉
			if t.get("watered_today", false):
				t["watered_today"] = false
			elif t["state"] == "watered":
				t["state"] = "tilled"
				_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_TILLED)
			continue

		# 種植格：計算生長
		if t.get("watered_today", false):
			t["days_watered"] = t.get("days_watered", 0) + 1
			t["watered_today"] = false
		else:
			# 連續 3 天未澆水 → 枯死 (S04-T09)
			t["dry_days"] = t.get("dry_days", 0) + 1
			if t["dry_days"] >= 3:
				to_kill.append(pos)
				continue

		# 更新生長階段
		var data    : Dictionary = _crop_db[t["crop_id"]]
		var stage   : int = _calc_stage(t, data)
		if stage != t["growth_stage"]:
			t["growth_stage"] = stage
			_update_crop_visual(pos)

		# 重置 dry_days 若今天有澆水
		if t.get("watered_today", false) == false and t.get("dry_days", 0) > 0:
			pass  # 已在上面處理

	# 枯死的作物
	for pos in to_kill:
		_kill_crop(pos)


# ── 視覺 ─────────────────────────────────────────────────────────────────

func _spawn_crop_visual(tile_pos: Vector2i, crop_id: String, stage: int) -> void:
	if _crop_nodes.has(tile_pos):
		_crop_nodes[tile_pos].queue_free()
	var node := _build_crop_node(crop_id, stage)
	# 植物根部對齊 tile 中心底部
	node.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 16)
	_ysort.add_child(node)
	_crop_nodes[tile_pos] = node


func _update_crop_visual(tile_pos: Vector2i) -> void:
	if not _tiles.has(tile_pos):
		return
	var t    : Dictionary = _tiles[tile_pos]
	var data : Dictionary = _crop_db[t["crop_id"]]
	var stage: int        = t["growth_stage"]
	_spawn_crop_visual(tile_pos, t["crop_id"], stage)


func _build_crop_node(crop_id: String, stage: int) -> Node2D:
	var data    : Dictionary = _crop_db[crop_id]
	var total   : int        = _total_stages(data)
	var pct     : float      = float(stage) / float(max(total, 1))
	var mature  : bool       = stage >= total

	var col_s   := data["color_seedling"] as Array
	var col_m   := data["color_mature"]   as Array
	var col     := Color(
		lerpf(col_s[0], col_m[0], pct),
		lerpf(col_s[1], col_m[1], pct),
		lerpf(col_s[2], col_m[2], pct)
	)

	var node    := Node2D.new()
	var stem_h  : float = lerpf(3.0, 10.0, pct)
	var head_r  : float = lerpf(2.0, 5.0,  pct)

	# 莖
	var stem    := Polygon2D.new()
	stem.color  = Color(0.25, 0.55, 0.15)
	stem.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(1, -stem_h), Vector2(-1, -stem_h)
	])
	node.add_child(stem)

	# 頭部（葉/果）
	var head    := Polygon2D.new()
	head.color  = col
	head.polygon = _circle(head_r, 8)
	head.position = Vector2(0, -stem_h - head_r * 0.8)
	node.add_child(head)

	# 成熟閃光（白點）
	if mature:
		var shine   := Polygon2D.new()
		shine.color  = Color(1, 1, 1, 0.6)
		shine.polygon = _circle(1.2, 6)
		shine.position = Vector2(head_r * 0.4, -stem_h - head_r * 1.4)
		node.add_child(shine)

	return node


func _circle(r: float, pts: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(pts):
		var a := i * TAU / pts
		arr.append(Vector2(cos(a) * r, sin(a) * r))
	return arr


func _kill_crop(tile_pos: Vector2i) -> void:
	_tiles.erase(tile_pos)
	if _crop_nodes.has(tile_pos):
		_crop_nodes[tile_pos].queue_free()
		_crop_nodes.erase(tile_pos)
	_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_DIRT)


# ── 計算 ─────────────────────────────────────────────────────────────────

func _total_stages(data: Dictionary) -> int:
	return data["grow_days"] - 1   # 0 = 剛播種, grow_days-1 = 成熟


func _calc_stage(t: Dictionary, data: Dictionary) -> int:
	var days   : int = t.get("days_watered", 0)
	var total  : int = _total_stages(data)
	return clampi(days, 0, total)


func _calc_quality(_t: Dictionary) -> String:
	# 未來可依澆水天數、施肥決定品質（S04-T11）
	return "normal"


func _is_farmable(tile_pos: Vector2i) -> bool:
	return (tile_pos.x >= DIRT_X_MIN and tile_pos.x <= DIRT_X_MAX and
	        tile_pos.y >= DIRT_Y_MIN  and tile_pos.y <= DIRT_Y_MAX)


# ── 資料載入 ──────────────────────────────────────────────────────────────

func _load_crop_db() -> void:
	var f := FileAccess.open("res://data/crops/crops.json", FileAccess.READ)
	if f == null:
		push_error("FarmGrid: 無法讀取 crops.json")
		return
	_crop_db = JSON.parse_string(f.get_as_text())
	f.close()
