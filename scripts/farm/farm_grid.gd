## FarmGrid — 農地 Tile 狀態管理 (S04-T01~T08, T04)
## 掛在 Farm 場景下，管理每塊農地的翻土/澆水/播種/施肥/生長/收成
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
var _tiles     : Dictionary = {}   # 公開供 debug 讀取

# 作物視覺節點
# key: Vector2i, value: Node2D
var _crop_nodes: Dictionary = {}

# 施肥視覺節點
# key: Vector2i, value: Node2D
var _fertilized_nodes: Dictionary = {}

@onready var _tile_map : TileMap = get_parent().get_node("TileMap")
@onready var _ysort    : Node2D  = get_parent().get_node("YSort")

# ── 訊號 ─────────────────────────────────────────────────────────────────
signal harvested(crop_id: String, quality: String)


func _ready() -> void:
	add_to_group("farm_grid")
	_load_crop_db()
	TimeManager.day_changed.connect(_on_day_changed)


# ── 公開 API ─────────────────────────────────────────────────────────────

## 翻土（鋤頭）：DIRT → TILLED（雨天直接 WATERED）
func till(tile_pos: Vector2i) -> bool:
	if not _is_farmable(tile_pos):
		return false
	var atlas := _tile_map.get_cell_atlas_coords(LAYER, tile_pos)
	if atlas != T_DIRT:
		return false
	if WeatherManager.is_raining() or WeatherManager.is_snowing():
		# 雨天/雪天翻土：直接變澆水狀態（S04-T10 部分實作）
		_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_WATERED)
		_tiles[tile_pos] = { "state": "watered", "watered_today": true }
	else:
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


## 施肥（肥料）：在 TILLED / WATERED / PLANTED 格施肥，每格只能施一次
func fertilize(tile_pos: Vector2i) -> bool:
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	var state : String = t["state"]
	if state != "tilled" and state != "watered" and state != "planted":
		return false
	if t.get("fertilized", false):
		return false   # 已施過肥，不重複
	t["fertilized"] = true
	_spawn_fertilized_visual(tile_pos)
	return true


## 查詢某格是否已施肥
func is_fertilized(tile_pos: Vector2i) -> bool:
	if not _tiles.has(tile_pos):
		return false
	return _tiles[tile_pos].get("fertilized", false)


## 播種：TILLED / WATERED → PLANTED
func plant(tile_pos: Vector2i, crop_id: String) -> bool:
	if not _crop_db.has(crop_id):
		return false
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "tilled" and t["state"] != "watered":
		return false
	var was_watered    : bool = t.get("watered_today", false)
	t["state"]         = "planted"
	t["crop_id"]       = crop_id
	t["day_planted"]   = TimeManager.day
	t["days_watered"]  = 0
	t["missed_water"]  = 0   # 生長期間漏澆水的天數
	t["growth_stage"]  = 0
	t["dry_days"]      = 0
	t["watered_today"] = was_watered   # 保留澆水狀態，讓隔天推進正確計算
	_spawn_crop_visual(tile_pos, crop_id, 0)
	return true


## 收成：成熟的作物 → 獲得物品；回傳品質字串，失敗回傳 ""
func harvest(tile_pos: Vector2i) -> String:
	if not _tiles.has(tile_pos):
		return ""
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "planted":
		return ""
	var data : Dictionary = _crop_db[t["crop_id"]]
	if t["growth_stage"] < _total_stages(data):
		return ""   # 還沒成熟

	var quality := _calc_quality(t)
	harvested.emit(t["crop_id"], quality)

	# 自動放入出貨箱
	var box : Node = get_tree().get_first_node_in_group("shipping_box")
	if box:
		box.add_item(t["crop_id"], quality)

	# 多次收成作物（番茄等）重置生長
	if data.get("multi_harvest", false):
		t["growth_stage"] = 0
		t["day_planted"]  = TimeManager.day
		t["days_watered"] = 0
		# 多次收成後施肥效果消失（下次需重新施肥）
		t["fertilized"] = false
		_clear_fertilized_visual(tile_pos)
		_update_crop_visual(tile_pos)
	else:
		# 移除作物，土壤保留翻土/澆水狀態（不退回原始泥土）
		_clear_fertilized_visual(tile_pos)
		if _crop_nodes.has(tile_pos):
			_crop_nodes[tile_pos].queue_free()
			_crop_nodes.erase(tile_pos)
		var was_watered : bool = t.get("watered_today", false)
		if was_watered:
			_tiles[tile_pos] = { "state": "watered", "watered_today": true }
			_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_WATERED)
		else:
			_tiles[tile_pos] = { "state": "tilled", "watered_today": false }
			_tile_map.set_cell(LAYER, tile_pos, SOURCE_ID, T_TILLED)
	return quality


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
			# 非種植格：隔天一律乾掉（恢復翻土外觀）
			if t["state"] == "watered":
				t["state"] = "tilled"
				_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_TILLED)
			t["watered_today"] = false
			continue

		# 種植格：計算生長
		var data : Dictionary = _crop_db[t["crop_id"]]

		# 已成熟：不需澆水、不會枯死，等待收成
		if t["growth_stage"] >= _total_stages(data):
			t["watered_today"] = false
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_TILLED)
			continue

		if t.get("watered_today", false):
			t["days_watered"] = t.get("days_watered", 0) + 1
			t["dry_days"]     = 0
			t["watered_today"] = false
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_TILLED)   # 隔天恢復乾土外觀
		else:
			# 連續 3 天未澆水 → 枯死 (S04-T09)
			t["dry_days"]     = t.get("dry_days", 0) + 1
			t["missed_water"] = t.get("missed_water", 0) + 1
			if t["dry_days"] >= 3:
				to_kill.append(pos)
				continue

		# 更新生長階段
		var stage : int = _calc_stage(t, data)
		if stage != t["growth_stage"]:
			t["growth_stage"] = stage
			_update_crop_visual(pos)

	# 枯死的作物
	for pos in to_kill:
		_kill_crop(pos)

	# 雨天 / 雪天：新的一天開始自動澆水所有耕地（S04-T10）
	if WeatherManager.is_raining() or WeatherManager.is_snowing():
		for pos : Vector2i in _tiles.keys():
			var t : Dictionary = _tiles[pos]
			if t["state"] == "tilled":
				t["state"] = "watered"
				t["watered_today"] = true
				_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_WATERED)
			elif t["state"] == "planted":
				var data : Dictionary = _crop_db[t["crop_id"]]
				if t["growth_stage"] < _total_stages(data):
					t["watered_today"] = true
					_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_WATERED)


# ── 視覺 ─────────────────────────────────────────────────────────────────

func _spawn_crop_visual(tile_pos: Vector2i, crop_id: String, stage: int) -> void:
	if _crop_nodes.has(tile_pos):
		_crop_nodes[tile_pos].queue_free()
	var hint := _quality_hint(tile_pos)
	var node := _build_crop_node(crop_id, stage, hint)
	# 植物根部對齊 tile 中心底部
	node.position = Vector2(tile_pos.x * 16 + 8, tile_pos.y * 16 + 16)
	_ysort.add_child(node)
	_crop_nodes[tile_pos] = node


func _update_crop_visual(tile_pos: Vector2i) -> void:
	if not _tiles.has(tile_pos):
		return
	var t    : Dictionary = _tiles[tile_pos]
	var stage: int        = t["growth_stage"]
	_spawn_crop_visual(tile_pos, t["crop_id"], stage)


func _build_crop_node(crop_id: String, stage: int, quality_hint: String = "normal") -> Node2D:
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

	# 成熟品質指示星（顏色依品質）
	# 普通=白, 優良=金, 精品=紫+額外光暈
	if mature:
		var shine_col : Color
		match quality_hint:
			"premium": shine_col = Color(0.85, 0.35, 1.0, 0.90)  # 紫色（精品）
			"good":    shine_col = Color(1.00, 0.85, 0.20, 0.85)  # 金色（優良）
			_:         shine_col = Color(1.00, 1.00, 1.00, 0.60)  # 白色（普通）
		var shine       := Polygon2D.new()
		shine.color      = shine_col
		shine.polygon    = _circle(1.4, 6)
		shine.position   = Vector2(head_r * 0.4, -stem_h - head_r * 1.4)
		node.add_child(shine)
		# 精品額外光暈（大圓半透明）
		if quality_hint == "premium":
			var glow       := Polygon2D.new()
			glow.color      = Color(0.85, 0.35, 1.0, 0.25)
			glow.polygon    = _circle(3.0, 10)
			glow.position   = shine.position
			node.add_child(glow)

	return node


func _circle(r: float, pts: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(pts):
		var a := i * TAU / pts
		arr.append(Vector2(cos(a) * r, sin(a) * r))
	return arr


## 施肥視覺：整格半透明棕色疊層 + 散布的肥料顆粒小點
func _spawn_fertilized_visual(tile_pos: Vector2i) -> void:
	_clear_fertilized_visual(tile_pos)
	var node := Node2D.new()
	# tile 左上角為原點，整格 16×16
	node.position = Vector2(tile_pos.x * 16, tile_pos.y * 16)
	node.z_index  = 0   # 在 tile 上方，作物下方

	# 半透明棕色疊層（覆蓋整格，讓耕地顏色有變化）
	var overlay    := Polygon2D.new()
	overlay.color   = Color(0.48, 0.30, 0.08, 0.40)
	overlay.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(16, 0),
		Vector2(16, 16), Vector2(0, 16)
	])
	node.add_child(overlay)

	# 散布 5 個深棕色小顆粒，代表肥料
	var grain_positions : Array[Vector2] = [
		Vector2(3, 4), Vector2(10, 3), Vector2(6, 9),
		Vector2(13, 7), Vector2(4, 13),
	]
	for gp : Vector2 in grain_positions:
		var grain   := Polygon2D.new()
		grain.color  = Color(0.35, 0.20, 0.05, 0.85)
		grain.polygon = _circle(1.2, 6)
		grain.position = gp
		node.add_child(grain)

	_ysort.add_child(node)
	_fertilized_nodes[tile_pos] = node


func _clear_fertilized_visual(tile_pos: Vector2i) -> void:
	if _fertilized_nodes.has(tile_pos):
		_fertilized_nodes[tile_pos].queue_free()
		_fertilized_nodes.erase(tile_pos)


func _kill_crop(tile_pos: Vector2i) -> void:
	_clear_fertilized_visual(tile_pos)
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


func _calc_quality(t: Dictionary) -> String:
	# S04-T11: 三段品質系統
	# 精品 (premium)  = 施肥 AND 全程澆水
	# 優良 (good)     = 施肥 OR  全程澆水
	# 普通 (normal)   = 其他
	var watered_all : bool = t.get("missed_water", 0) == 0   # 生長期間從未漏水
	var fertilized  : bool = t.get("fertilized", false)
	if fertilized and watered_all:
		return "premium"
	elif fertilized or watered_all:
		return "good"
	return "normal"


## 依當前 tile 狀態預覽品質（供視覺提示）
func _quality_hint(tile_pos: Vector2i) -> String:
	if not _tiles.has(tile_pos):
		return "normal"
	return _calc_quality(_tiles[tile_pos])


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
