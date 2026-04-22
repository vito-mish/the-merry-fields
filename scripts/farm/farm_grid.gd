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
	TimeManager.season_changed.connect(_on_season_changed)
	# 農地還原由 farm.gd._ready() 在 _generate_farm() 之後呼叫


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


## 回傳所有作物 id 列表（供 player 循環切換用）
func get_crop_ids() -> Array:
	return _crop_db.keys()


## 回傳完整作物資料表（供 toolbar 顯示名稱用）
func get_crop_db() -> Dictionary:
	return _crop_db


## 查詢作物是否可在當前季節種植 (S04-T13)
func can_plant_in_season(crop_id: String) -> bool:
	if not _crop_db.has(crop_id):
		return false
	var data : Dictionary = _crop_db[crop_id]
	var seasons : Array   = data.get("season", [])
	var cur_season : String = TimeManager.SEASON_EN[TimeManager.season]
	return seasons.has(cur_season)


## 播種：TILLED / WATERED → PLANTED
func plant(tile_pos: Vector2i, crop_id: String) -> bool:
	if not _crop_db.has(crop_id):
		return false
	# S04-T13: 季節限制
	if not can_plant_in_season(crop_id):
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


## 回傳某格作物的生長進度資訊（供 HUD focus 顯示）
func get_crop_progress(tile_pos: Vector2i) -> Dictionary:
	if not _tiles.has(tile_pos):
		return {}
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "planted":
		return {}
	var data  : Dictionary = _crop_db[t["crop_id"]]
	var total : int        = _total_stages(data)
	var stage : int        = t["growth_stage"]
	return {
		"name":          data.get("name", t["crop_id"]),
		"stage":         stage,
		"total":         total,
		"mature":        stage >= total,
		"watered_today": t.get("watered_today", false),
		"fertilized":    t.get("fertilized", false),
	}


func is_mature(tile_pos: Vector2i) -> bool:
	if not _tiles.has(tile_pos):
		return false
	var t : Dictionary = _tiles[tile_pos]
	if t["state"] != "planted":
		return false
	var data : Dictionary = _crop_db[t["crop_id"]]
	return t["growth_stage"] >= _total_stages(data)


# ── S12 存檔介面 ──────────────────────────────────────────────────────────────

## 回傳所有耕作中的 tile 座標（供 SaveManager 收集）
func get_saved_tiles() -> Array[Vector2i]:
	var result : Array[Vector2i] = []
	for k in _tiles.keys():
		result.append(k)
	return result


## 回傳某格的完整狀態資料（供 SaveManager 序列化）
func get_tile_data(tile_pos: Vector2i) -> Dictionary:
	if not _tiles.has(tile_pos):
		return {}
	return _tiles[tile_pos].duplicate()


## 從存檔資料還原農地狀態（S12-T04）
func restore_state(tiles_data: Array) -> void:
	# 清除現有狀態
	for pos : Vector2i in _crop_nodes.keys():
		_crop_nodes[pos].queue_free()
	_crop_nodes.clear()
	for pos : Vector2i in _fertilized_nodes.keys():
		_fertilized_nodes[pos].queue_free()
	_fertilized_nodes.clear()
	_tiles.clear()

	for entry : Dictionary in tiles_data:
		var pos := Vector2i(int(entry["x"]), int(entry["y"]))
		# 重建 _tiles（去掉座標欄位）
		var t : Dictionary = entry.duplicate()
		t.erase("x")
		t.erase("y")
		_tiles[pos] = t

		# 設定 TileMap 視覺
		var watered_now : bool = t.get("watered_today", false)
		if t["state"] == "planted" and watered_now:
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_WATERED)
		elif t["state"] == "planted" or t["state"] == "tilled":
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_TILLED)
		elif t["state"] == "watered":
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_WATERED)

		# 作物視覺
		if t["state"] == "planted" and t.has("crop_id"):
			_spawn_crop_visual(pos, t["crop_id"], t.get("growth_stage", 0))

		# 施肥視覺
		if t.get("fertilized", false):
			_spawn_fertilized_visual(pos)

	# 讀檔當下若為雨/雪天，立刻對耕地自動澆水（S04-T10 fix）
	if WeatherManager.is_raining() or WeatherManager.is_snowing():
		_apply_rain_watering()


## 雨/雪天自動澆水（供 restore_state 和 _on_day_changed 共用）
func _apply_rain_watering() -> void:
	for pos : Vector2i in _tiles.keys():
		var t : Dictionary = _tiles[pos]
		if t["state"] == "tilled":
			t["state"]         = "watered"
			t["watered_today"] = true
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_WATERED)
		elif t["state"] == "planted":
			# 成熟與未成熟作物皆澆水（視覺一致，成熟者不影響生長邏輯）
			t["watered_today"] = true
			_tile_map.set_cell(LAYER, pos, SOURCE_ID, T_WATERED)


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

	# 新的一天若為雨/雪天，自動澆水（S04-T10）
	# WeatherManager 在 day_changed 先執行已換成新天氣，is_raining() 取的正是今天
	if WeatherManager.is_raining() or WeatherManager.is_snowing():
		_apply_rain_watering()


# S04-T13: 季節切換時，清除所有不屬於新季節的作物（枯死）
func _on_season_changed(new_season: int) -> void:
	var cur_season : String = TimeManager.SEASON_EN[new_season]
	var to_kill : Array[Vector2i] = []
	for pos : Vector2i in _tiles.keys():
		var t : Dictionary = _tiles[pos]
		if t["state"] != "planted":
			continue
		var data    : Dictionary = _crop_db[t["crop_id"]]
		var seasons : Array      = data.get("season", [])
		if not seasons.has(cur_season):
			to_kill.append(pos)
	for pos in to_kill:
		_kill_crop(pos)


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
	var data   : Dictionary = _crop_db[crop_id]
	var total  : int        = _total_stages(data)
	var pct    : float      = float(stage) / float(max(total, 1))
	var mature : bool       = stage >= total
	var node   := Node2D.new()
	var shine_pos := Vector2(4.0, -18.0)

	# ── 幼苗（pct < 0.2）：統一嫩芽外觀 ──────────────────────────────────
	if pct < 0.2:
		var h : float = lerpf(2.0, 5.0, pct / 0.2)
		var sp := Polygon2D.new()
		sp.color   = Color(0.30, 0.62, 0.20)
		sp.polygon = PackedVector2Array([Vector2(-0.5, 0), Vector2(0.5, 0),
			Vector2(0.5, -h), Vector2(-0.5, -h)])
		node.add_child(sp)
		for li in range(2):
			var lx : float = 3.0 if li == 0 else -3.0
			var lf := Polygon2D.new()
			lf.color   = Color(0.35, 0.72, 0.22)
			lf.polygon = PackedVector2Array([Vector2(0.0, -h * 0.4),
				Vector2(lx, -h * 0.9), Vector2(lx * 0.4, -h - 1.0)])
			node.add_child(lf)
		shine_pos = Vector2(3.0, -h - 3.0)
	else:
		# ── 各作物專屬形狀 ────────────────────────────────────────────────
		match crop_id:

			"turnip":  # 蕪菁：橙黃球根 + 紫頂帽 + 3片上翹葉
				var br : float = lerpf(2.0, 5.5, pct)
				var lh : float = lerpf(4.0, 12.0, pct)
				var bulb := Polygon2D.new()
				bulb.color   = Color(0.92, 0.80, 0.22)
				bulb.polygon = _oval(br, br * 0.80, 10)
				bulb.position = Vector2(0.0, -br * 0.6)
				node.add_child(bulb)
				var cap := Polygon2D.new()
				cap.color   = Color(0.65, 0.18, 0.55)
				cap.polygon = _oval(br * 0.60, br * 0.40, 8)
				cap.position = Vector2(0.0, -br * 1.2)
				node.add_child(cap)
				for li in range(3):
					var ang : float = [-0.45, 0.0, 0.45][li]
					var lf2 := Polygon2D.new()
					lf2.color   = Color(0.28, 0.68, 0.20)
					lf2.polygon = PackedVector2Array([Vector2(0.0, -br * 1.4),
						Vector2(sin(ang) * lh * 0.75, -br * 1.4 - lh * 0.55),
						Vector2(sin(ang) * lh * 0.35, -br * 1.4 - lh)])
					node.add_child(lf2)
				shine_pos = Vector2(4.0, -br * 1.4 - lh - 2.0)

			"potato":  # 馬鈴薯：矮叢闊葉 + 成熟時白色五瓣花
				var bh : float = lerpf(4.0, 9.0, pct)
				var bw : float = lerpf(3.0, 8.0, pct)
				var pStem := Polygon2D.new()
				pStem.color   = Color(0.30, 0.58, 0.18)
				pStem.polygon = PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0),
					Vector2(0.8, -bh), Vector2(-0.8, -bh)])
				node.add_child(pStem)
				for li in range(3):
					var lx2 : float = [-bw, 0.0, bw][li]
					var ly2 : float = [-bh * 0.35, -bh, -bh * 0.35][li]
					var lf3 := Polygon2D.new()
					lf3.color   = Color(0.32, 0.65, 0.22)
					lf3.polygon = _oval(bw * 0.55, bh * 0.38, 7)
					lf3.position = Vector2(lx2 * 0.5, ly2)
					node.add_child(lf3)
				if mature:
					for fi in range(5):
						var fa : float = fi * TAU / 5.0
						var pt := Polygon2D.new()
						pt.color    = Color(0.95, 0.95, 0.90)
						pt.polygon  = _circle(1.6, 5)
						pt.position = Vector2(cos(fa) * 2.8, -bh - 1.5 + sin(fa) * 2.8)
						node.add_child(pt)
					var fc := Polygon2D.new()
					fc.color   = Color(0.98, 0.88, 0.20)
					fc.polygon = _circle(1.2, 6)
					fc.position = Vector2(0.0, -bh - 1.5)
					node.add_child(fc)
				shine_pos = Vector2(4.0, -bh - 6.0)

			"strawberry":  # 草莓：低矮圓葉 + 紅色心形果
				var lh2 : float = lerpf(3.0, 7.0, pct)
				for li in range(3):
					var ang2 : float = (li - 1) * 0.55
					var lf4 := Polygon2D.new()
					lf4.color   = Color(0.28, 0.70, 0.20)
					lf4.polygon = _oval(lh2 * 0.52, lh2 * 0.38, 6)
					lf4.position = Vector2(sin(ang2) * lh2 * 0.7, -lh2 * 0.45)
					node.add_child(lf4)
				if mature:
					for bi in range(2):
						var bx : float = [-3.0, 3.0][bi]
						var bry := Polygon2D.new()
						bry.color   = Color(0.92, 0.15, 0.22)
						bry.polygon = PackedVector2Array([Vector2(-2.0, -1.0), Vector2(2.0, -1.0),
							Vector2(2.5, 0.5), Vector2(0.0, 3.5), Vector2(-2.5, 0.5)])
						bry.position = Vector2(bx, -lh2 * 0.15)
						node.add_child(bry)
						var bc := Polygon2D.new()
						bc.color   = Color(0.28, 0.70, 0.20)
						bc.polygon = _circle(1.3, 5)
						bc.position = Vector2(bx, -lh2 * 0.15 - 2.0)
						node.add_child(bc)
				shine_pos = Vector2(4.0, -lh2 - 3.0)

			"tomato":  # 番茄：高藤蔓 + 2顆圓形紅果
				var vh : float = lerpf(6.0, 16.0, pct)
				var vStem := Polygon2D.new()
				vStem.color   = Color(0.30, 0.60, 0.20)
				vStem.polygon = PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0),
					Vector2(0.6, -vh), Vector2(-0.6, -vh)])
				node.add_child(vStem)
				var nl : int = clampi(int(pct * 4) + 1, 1, 3)
				for li in range(nl):
					var lh3 : float = vh * (0.28 + li * 0.30)
					var lx3 : float = 4.5 if li % 2 == 0 else -4.5
					var lf5 := Polygon2D.new()
					lf5.color   = Color(0.32, 0.68, 0.22)
					lf5.polygon = PackedVector2Array([Vector2(0.0, -lh3),
						Vector2(lx3, -lh3 - 3.5), Vector2(lx3 * 0.3, -lh3 - 5.5)])
					node.add_child(lf5)
				if mature:
					for ti in range(2):
						var tx : float = [-3.5, 3.5][ti]
						var ty2 : float = [-vh * 0.38, -vh * 0.62][ti]
						var tom := Polygon2D.new()
						tom.color   = Color(0.92, 0.20, 0.12)
						tom.polygon = _circle(3.8, 10)
						tom.position = Vector2(tx, ty2)
						node.add_child(tom)
						var cal := Polygon2D.new()
						cal.color   = Color(0.28, 0.65, 0.20)
						cal.polygon = _circle(1.5, 5)
						cal.position = Vector2(tx, ty2 - 3.5)
						node.add_child(cal)
				shine_pos = Vector2(4.5, -vh - 2.0)

			"corn":  # 玉米：最高莖桿 + 交叉寬葉 + 黃色玉米棒
				var sh : float = lerpf(8.0, 20.0, pct)
				var stk := Polygon2D.new()
				stk.color   = Color(0.45, 0.68, 0.22)
				stk.polygon = PackedVector2Array([Vector2(-1.5, 0), Vector2(1.5, 0),
					Vector2(1.0, -sh), Vector2(-1.0, -sh)])
				node.add_child(stk)
				var nl2 : int = clampi(int(pct * 3) + 1, 1, 3)
				for li in range(nl2):
					var lh4 : float = sh * (0.30 + li * 0.22)
					var lx4 : float = 8.0 if li % 2 == 0 else -8.0
					var lf6 := Polygon2D.new()
					lf6.color   = Color(0.38, 0.72, 0.22)
					lf6.polygon = PackedVector2Array([Vector2(0.0, -lh4 + 2),
						Vector2(lx4, -lh4 - 2), Vector2(lx4 * 0.6, -lh4 - 6),
						Vector2(0.0, -lh4 - 4)])
					node.add_child(lf6)
				if mature:
					var cob := Polygon2D.new()
					cob.color   = Color(0.98, 0.82, 0.18)
					cob.polygon = PackedVector2Array([Vector2(-2.5, -sh * 0.38),
						Vector2(2.5, -sh * 0.38), Vector2(2.5, -sh * 0.65),
						Vector2(-2.5, -sh * 0.65)])
					node.add_child(cob)
					var slk := Polygon2D.new()
					slk.color   = Color(0.85, 0.42, 0.12)
					slk.polygon = PackedVector2Array([Vector2(-1.5, -sh * 0.65),
						Vector2(1.5, -sh * 0.65), Vector2(2.0, -sh * 0.80),
						Vector2(-2.0, -sh * 0.80)])
					node.add_child(slk)
				shine_pos = Vector2(4.0, -sh - 2.0)

			"pumpkin":  # 南瓜：寬扁多瓣橙色大瓜 + 大葉 + 蒂
				var pw : float = lerpf(3.0, 9.0, pct)
				var ph : float = lerpf(2.5, 6.0, pct)
				var gl := Polygon2D.new()
				gl.color   = Color(0.32, 0.65, 0.20)
				gl.polygon = _oval(pw * 1.2, ph * 0.65, 8)
				gl.position = Vector2(pw * 0.55, -ph * 0.5)
				node.add_child(gl)
				var nseg : int = 3 if not mature else 5
				for si in range(nseg):
					var sx : float = lerpf(-pw * 0.8, pw * 0.8, float(si) / max(nseg - 1, 1))
					var sg := Polygon2D.new()
					sg.color   = Color(0.92, 0.52, 0.10) if si % 2 == 0 else Color(0.88, 0.44, 0.08)
					sg.polygon = _oval(pw * 0.52, ph, 8)
					sg.position = Vector2(sx, -ph)
					node.add_child(sg)
				var pdt := Polygon2D.new()
				pdt.color   = Color(0.25, 0.50, 0.12)
				pdt.polygon = PackedVector2Array([Vector2(-1.0, -ph * 2.0 + 1.0),
					Vector2(1.0, -ph * 2.0 + 1.0), Vector2(0.5, -ph * 2.0 - 3.5),
					Vector2(-0.5, -ph * 2.0 - 3.5)])
				node.add_child(pdt)
				shine_pos = Vector2(4.0, -ph * 2.0 - 5.0)

			"eggplant":  # 茄子：中高莖 + 側葉 + 深紫長橢圓果
				var esh : float = lerpf(5.0, 13.0, pct)
				var efh : float = lerpf(2.0,  7.0, pct)
				var eSt := Polygon2D.new()
				eSt.color   = Color(0.30, 0.55, 0.18)
				eSt.polygon = PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0),
					Vector2(0.5, -esh), Vector2(-0.5, -esh)])
				node.add_child(eSt)
				var eLf := Polygon2D.new()
				eLf.color   = Color(0.32, 0.62, 0.22)
				eLf.polygon = _oval(esh * 0.40, esh * 0.24, 6)
				eLf.position = Vector2(3.5, -esh * 0.45)
				node.add_child(eLf)
				if pct > 0.30:
					var frt := Polygon2D.new()
					frt.color   = Color(0.38, 0.08, 0.62)
					frt.polygon = _oval(efh * 0.45, efh, 10)
					frt.position = Vector2(0.0, -esh * 0.45)
					node.add_child(frt)
					var fcp := Polygon2D.new()
					fcp.color   = Color(0.28, 0.62, 0.20)
					fcp.polygon = _circle(1.6, 5)
					fcp.position = Vector2(0.0, -esh * 0.45 - efh)
					node.add_child(fcp)
				shine_pos = Vector2(4.0, -esh - 2.0)

			"cabbage":  # 白菜：同心橢圓疊層的圓頭菜球
				var cr : float = lerpf(2.5, 7.5, pct)
				var nl3 : int  = clampi(int(pct * 5) + 1, 1, 5)
				for li in range(nl3, 0, -1):
					var lr : float = cr * float(li) / nl3
					var tf : float = float(li) / nl3
					var lc := Polygon2D.new()
					lc.color   = Color(0.58 + tf * 0.22, 0.82 + tf * 0.12, 0.40 + tf * 0.25)
					lc.polygon = _oval(lr, lr * 0.72, 10)
					lc.position = Vector2(0.0, -cr - li * 0.5)
					node.add_child(lc)
				shine_pos = Vector2(4.0, -cr * 2.0 - 3.0)

			"daikon":  # 白蘿蔔：白色梯形根莖 + 羽狀蘿蔔纓
				var rh : float = lerpf(4.0, 12.0, pct)
				var rw : float = lerpf(1.5,  3.5, pct)
				var rt := Polygon2D.new()
				rt.color   = Color(0.94, 0.94, 0.90)
				rt.polygon = PackedVector2Array([Vector2(-rw, 0.0), Vector2(rw, 0.0),
					Vector2(rw * 0.45, -rh), Vector2(-rw * 0.45, -rh)])
				node.add_child(rt)
				var nl4 : int = clampi(int(pct * 4) + 2, 2, 5)
				for li in range(nl4):
					var ang3 : float = lerpf(-0.65, 0.65, float(li) / max(nl4 - 1, 1))
					var ll   : float = lerpf(4.0, 10.0, pct)
					var dlf  := Polygon2D.new()
					dlf.color   = Color(0.28, 0.70, 0.20)
					dlf.polygon = PackedVector2Array([Vector2(0.0, -rh),
						Vector2(sin(ang3) * ll * 0.75, -rh - ll * 0.55),
						Vector2(sin(ang3) * ll * 0.38, -rh - ll)])
					node.add_child(dlf)
				shine_pos = Vector2(4.0, -rh - 12.0)

			_:  # 後備通用形狀
				var cm2 : Array = data.get("color_mature", [0.35, 0.78, 0.32])
				var gc   := Color(cm2[0], cm2[1], cm2[2])
				var gsh  : float = lerpf(3.0, 10.0, pct)
				var ghr  : float = lerpf(2.0,  5.0, pct)
				var gst  := Polygon2D.new()
				gst.color   = Color(0.25, 0.55, 0.15)
				gst.polygon = PackedVector2Array([Vector2(-1, 0), Vector2(1, 0),
					Vector2(1, -gsh), Vector2(-1, -gsh)])
				node.add_child(gst)
				var ghd  := Polygon2D.new()
				ghd.color   = gc
				ghd.polygon = _circle(ghr, 8)
				ghd.position = Vector2(0.0, -gsh - ghr * 0.8)
				node.add_child(ghd)
				shine_pos = Vector2(4.0, -gsh - ghr * 1.8 - 2.0)

	# ── 成熟品質光暈 ──────────────────────────────────────────────────────
	if mature:
		var shine_col : Color
		match quality_hint:
			"premium": shine_col = Color(0.85, 0.35, 1.0, 0.90)
			"good":    shine_col = Color(1.00, 0.85, 0.20, 0.85)
			_:         shine_col = Color(1.00, 1.00, 1.00, 0.60)
		var shine := Polygon2D.new()
		shine.color   = shine_col
		shine.polygon = _circle(1.4, 6)
		shine.position = shine_pos
		node.add_child(shine)
		if quality_hint == "premium":
			var glow := Polygon2D.new()
			glow.color   = Color(0.85, 0.35, 1.0, 0.25)
			glow.polygon = _circle(3.0, 10)
			glow.position = shine_pos
			node.add_child(glow)

	return node


func _circle(r: float, pts: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(pts):
		var a := i * TAU / pts
		arr.append(Vector2(cos(a) * r, sin(a) * r))
	return arr


func _oval(rx: float, ry: float, pts: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for i in range(pts):
		var a := i * TAU / pts
		arr.append(Vector2(cos(a) * rx, sin(a) * ry))
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
