## Farm — 農場場景生成 (S03-T01)
## 含場景出口→村莊、SpawnPoint、Y-sort 樹木
extends Node2D

# Tile atlas coordinates
const T_GRASS   := Vector2i(0, 0)
const T_DIRT    := Vector2i(1, 0)
const T_TILLED  := Vector2i(2, 0)
const T_WATERED := Vector2i(3, 0)
const T_PATH    := Vector2i(4, 0)
const T_WATER   := Vector2i(5, 0)
const T_FENCE   := Vector2i(6, 0)
const T_BORDER  := Vector2i(7, 0)

const SOURCE_ID := 0
const LAYER     := 0
const FARM_SIZE := 30  # -30 to +29 tiles

@onready var tile_map: TileMap = $TileMap


func _ready() -> void:
	tile_map.add_to_group("tile_map")
	_setup_tileset()
	_generate_farm()
	_add_colliders()
	_add_scene_exits()
	_add_spawn_points()
	_add_trees()


func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/tilesets/farm_tiles.png")
	source.texture_region_size = Vector2i(16, 16)

	for coord in [T_GRASS, T_DIRT, T_TILLED, T_WATERED, T_PATH, T_FENCE, T_WATER, T_BORDER]:
		source.create_tile(coord)

	ts.add_source(source, SOURCE_ID)
	tile_map.tile_set = ts


# StaticBody2D approach — reliable collision regardless of TileMap physics quirks
func _add_colliders() -> void:
	var s := FARM_SIZE * 16  # 480px

	# Outer border (4 walls)
	# 大門缺口在 tile x=[-2..2] → pixel x=-32 ~ x=48（5 tiles × 16px，中心 x=8）
	# 底部牆分左右兩段，中間留 80px 通道
	const GATE_LEFT  := -32   # 缺口左邊（pixel）
	const GATE_RIGHT :=  48   # 缺口右邊（pixel）
	var left_w  : int = GATE_LEFT  + s          # 480-32  = 448
	var right_w : int = s - GATE_RIGHT          # 480-48  = 432
	_make_wall(Vector2(-s + left_w  / 2, s - 8), Vector2(left_w,  16))  # bottom-left
	_make_wall(Vector2( s - right_w / 2, s - 8), Vector2(right_w, 16))  # bottom-right
	_make_wall(Vector2(    0, -s + 8),            Vector2(s * 2,   16))  # top
	_make_wall(Vector2(-s + 8,     0),            Vector2(16,   s * 2))  # left
	_make_wall(Vector2( s - 8,     0),            Vector2(16,   s * 2))  # right

	# Water pond: tiles x[10..17], y[-26..-19] → pixels (160,-416)→(288,-288)
	_make_wall(Vector2(224, -352), Vector2(128, 128))


func _make_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape  = rect
	body.position = center
	body.add_child(col)
	add_child(body)


func _generate_farm() -> void:
	var s := FARM_SIZE

	# ── Ground fill ──────────────────────────────────────────────────────
	for x in range(-s, s):
		for y in range(-s, s):
			_place(x, y, T_GRASS)

	# ── Border (impassable tree line) ────────────────────────────────────
	for i in range(-s, s):
		_place(i, -s, T_BORDER)
		_place(i,  s - 1, T_BORDER)
		_place(-s, i, T_BORDER)
		_place( s - 1, i, T_BORDER)

	# ── Inner fence (farm boundary) ───────────────────────────────────────
	for i in range(-s + 2, s - 2):
		_place(i, -s + 2, T_FENCE)
		_place(-s + 2, i, T_FENCE)
		_place( s - 3, i, T_FENCE)
	# Bottom fence has gate gap (entrance)
	for i in range(-s + 2, s - 2):
		if i < -2 or i > 2:
			_place(i, s - 3, T_FENCE)

	# ── Stone path (gate → house) ─────────────────────────────────────────
	for y in range(-10, s - 2):
		_place(-1, y, T_PATH)
		_place( 0, y, T_PATH)

	# ── Farmable dirt patch (left side) ───────────────────────────────────
	for x in range(-s + 4, -4):
		for y in range(-s + 4, 10):
			_place(x, y, T_DIRT)

	# ── Pond (top-right) ──────────────────────────────────────────────────
	for x in range(10, 18):
		for y in range(-s + 4, -18):
			_place(x, y, T_WATER)
	# Pond border (grass around)
	for x in range(9, 19):
		_place(x, -18, T_PATH)
		_place(x, -s + 3, T_PATH)
	for y in range(-s + 3, -17):
		_place(9, y, T_PATH)
		_place(18, y, T_PATH)


# ── 場景出口 ──────────────────────────────────────────────────────────────

func _add_scene_exits() -> void:
	# 農場底部大門 → 村莊
	# 大門缺口在 tile x=[-2..2], y=27；觸發框放在邊界外側
	_make_exit(
		Vector2(8, FARM_SIZE * 16 - 8),   # 地圖底邊
		Vector2(80, 16),
		"res://scenes/maps/village.tscn",
		"from_farm"
	)


func _make_exit(pos: Vector2, size: Vector2,
				target: String, spawn_id: String) -> void:
	var exit  := Area2D.new()
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size    = size
	col.shape     = shape
	exit.position = pos
	exit.collision_layer = 0
	exit.collision_mask  = 1
	exit.add_child(col)
	exit.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player") and not TransitionManager.is_transitioning():
			TransitionManager.change_scene(target, spawn_id)
	)
	add_child(exit)


# ── 出生點 ────────────────────────────────────────────────────────────────

func _add_spawn_points() -> void:
	# 預設出生點：農場中心小屋前
	_make_spawn("default",      Vector2(8,  -160))
	# 從村莊回來：剛進大門的位置
	_make_spawn("from_village", Vector2(8,   400))


func _make_spawn(id: String, pos: Vector2) -> void:
	var sp := Marker2D.new()
	sp.set_script(preload("res://scripts/world/spawn_point.gd"))
	sp.position = pos
	add_child(sp)
	sp.spawn_id = id


# ── 裝飾樹木（Y-sort）────────────────────────────────────────────────────

func _add_trees() -> void:
	var TreeScene := preload("res://scenes/world/tree_object.tscn")
	var s         := FARM_SIZE

	# 樹木位置（tile 座標），避開農地、水池、路徑
	var tree_tiles : Array[Vector2i] = [
		# 右側樹帶（x=20..28，避開水池 y=-26..-19）
		Vector2i(22, -15), Vector2i(24, -13), Vector2i(26, -15),
		Vector2i(22,  -8), Vector2i(25,  -5), Vector2i(28,  -2),
		Vector2i(22,   3), Vector2i(25,   6), Vector2i(28,   9),
		Vector2i(22,  14), Vector2i(25,  18), Vector2i(27,  22),
		# 左側（農地外圍）
		Vector2i(-27, -25), Vector2i(-24, -25), Vector2i(-21, -25),
		# 右上角（水池右方）
		Vector2i(20, -25), Vector2i(23, -25), Vector2i(26, -25),
		# 頂部（邊界內）
		Vector2i(-15, -27), Vector2i(-8, -27), Vector2i(5, -27),
		Vector2i(12, -27), Vector2i(18, -27),
	]

	var ysort := $YSort
	for i in range(tree_tiles.size()):
		var t    := tree_tiles[i]
		var tree : Node2D = TreeScene.instantiate()
		tree.position     = Vector2(t.x * 16, t.y * 16)
		tree.seed_val     = i * 97 + 13
		tree.scale_factor = 0.85 + (i % 4) * 0.1
		ysort.add_child(tree)


# ── 工具 ─────────────────────────────────────────────────────────────────

func _place(x: int, y: int, coord: Vector2i) -> void:
	tile_map.set_cell(LAYER, Vector2i(x, y), SOURCE_ID, coord)
