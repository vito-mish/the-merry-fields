## Village — 村莊場景生成 (S03-T02)
## 80×50 tiles，含道路、建築地基、廣場、出入口
extends Node2D

# ── Tile 座標（重用 farm_tiles.png 圖集）─────────────────────────────────
const T_GRASS  := Vector2i(0, 0)
const T_DIRT   := Vector2i(1, 0)
const T_PATH   := Vector2i(4, 0)
const T_WATER  := Vector2i(5, 0)
const T_BORDER := Vector2i(7, 0)

const SOURCE_ID := 0
const LAYER     := 0

# 半寬 / 半高（tiles）→ 80×50
const VW := 40
const VH := 25

@onready var tile_map: TileMap = $TileMap

# 建築區域（用於放置靜態碰撞體）
var _building_rects : Array[Rect2] = []


func _ready() -> void:
	tile_map.add_to_group("tile_map")
	_setup_tileset()
	_generate_village()
	_add_colliders()
	_add_scene_exits()
	_add_spawn_points()
	_add_trees()


# ── Tileset ───────────────────────────────────────────────────────────────

func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	var src := TileSetAtlasSource.new()
	src.texture = preload("res://assets/tilesets/farm_tiles.png")
	src.texture_region_size = Vector2i(16, 16)

	for coord in [T_GRASS, T_DIRT, T_PATH, T_WATER, T_BORDER]:
		src.create_tile(coord)

	ts.add_source(src, SOURCE_ID)
	tile_map.tile_set = ts


# ── 地圖生成 ──────────────────────────────────────────────────────────────

func _generate_village() -> void:
	# 1. 草地底層
	for x in range(-VW, VW):
		for y in range(-VH, VH):
			_place(x, y, T_GRASS)

	# 2. 外牆（樹木邊界）
	for i in range(-VW, VW):
		_place(i, -VH,     T_BORDER)
		_place(i,  VH - 1, T_BORDER)
		_place(-VW, i,     T_BORDER)
		_place( VW - 1, i, T_BORDER)

	# 3. 主要道路系統
	#    水平主道 y=0（東西向）
	for x in range(-VW + 1, VW - 1):
		_place(x, -1, T_PATH)
		_place(x,  0, T_PATH)

	#    垂直主道 x=0（南北向，連接農場入口）
	for y in range(-VH + 1, VH - 1):
		_place(-1, y, T_PATH)
		_place( 0, y, T_PATH)

	#    水平副道 y=-12（北區商業街）
	for x in range(-VW + 1, VW - 1):
		_place(x, -12, T_PATH)
		_place(x, -11, T_PATH)

	#    水平副道 y=12（南區住宅街）
	for x in range(-VW + 1, VW - 1):
		_place(x, 12, T_PATH)
		_place(x, 13, T_PATH)

	# 4. 中央廣場（市集廣場）
	for x in range(-8, 9):
		for y in range(-8, 9):
			_place(x, y, T_PATH)
	# 廣場中央水池
	for x in range(-3, 4):
		for y in range(-3, 4):
			_place(x, y, T_WATER)

	# 5. 建築地基 ─────────────────────────────────────────────────────────
	# 北商業區（y=-24 ~ -14）
	_fill_building(-38, -23, 10, 9)   # 西北 商店A
	_fill_building(-25, -23, 10, 9)   # 西北 商店B
	_fill_building( 15, -23, 10, 9)   # 東北 商店C
	_fill_building( 28, -23, 10, 9)   # 東北 商店D
	_fill_building(-12, -23, 10, 9)   # 正北 鐵匠

	# 南住宅區（y=14 ~ 23）
	_fill_building(-38, 15, 8, 8)    # 西南 住宅A
	_fill_building(-27, 15, 8, 8)    # 西南 住宅B
	_fill_building(-16, 15, 8, 8)    # 南側 住宅C
	_fill_building( 10, 15, 8, 8)    # 東南 住宅D
	_fill_building( 21, 15, 8, 8)    # 東南 住宅E
	_fill_building( 32, 15, 6, 8)    # 最東 住宅F

	# 西東兩側建築（-12~-1 之間）
	_fill_building(-38, -9, 8, 17)   # 西側 市政廳
	_fill_building( 31, -9, 7, 17)   # 東側 教堂


func _fill_building(bx: int, by: int, bw: int, bh: int) -> void:
	for x in range(bx, bx + bw):
		for y in range(by, by + bh):
			_place(x, y, T_DIRT)
	# 記錄矩形（像素）供碰撞使用
	_building_rects.append(Rect2(
		Vector2(bx * 16, by * 16),
		Vector2(bw * 16, bh * 16)
	))


# ── 碰撞 ─────────────────────────────────────────────────────────────────

func _add_colliders() -> void:
	var w := VW * 16
	var h := VH * 16

	# 外牆
	# 頂部：留出南北主道缺口（tile x=[-2..1] = pixel -32~32，64px）
	const ROAD_L := -32
	const ROAD_R :=  32
	var side_w : int = w - 32   # 640 - 32 = 608
	_wall(Vector2(-w + side_w / 2, -h + 8), Vector2(side_w, 16))   # top-left
	_wall(Vector2( w - side_w / 2, -h + 8), Vector2(side_w, 16))   # top-right
	_wall(Vector2(    0,  h - 8), Vector2(w * 2, 16))               # bottom（無出口）
	_wall(Vector2(-w + 8,     0), Vector2(16, h * 2))               # left
	_wall(Vector2( w - 8,     0), Vector2(16, h * 2))               # right

	# 建築實體碰撞
	for r in _building_rects:
		_wall(r.get_center(), r.size)

	# 廣場水池碰撞（tile x/y = -3~3，共 7 tiles = 112px，中心在 tile 0 = pixel 8）
	_wall(Vector2(8, 8), Vector2(7 * 16, 7 * 16))


func _wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape  = rect
	body.position = center
	body.add_child(col)
	add_child(body)


# ── 場景出口 ──────────────────────────────────────────────────────────────

func _add_scene_exits() -> void:
	# 北出口 → 農場（缺口內側，玩家走到頂部路口即觸發）
	_make_exit(
		Vector2(0, -VH * 16 + 20),         # 稍微往內，讓玩家碰得到
		Vector2(64, 24),                    # 觸發框寬於缺口，確保碰到
		"res://scenes/maps/farm.tscn",
		"from_village"
	)

	# 南出口預留（未來接其他地圖）
	# _make_exit(Vector2(0, VH * 16 - 8), ...)


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
	# 從農場進入：北側道路入口
	_make_spawn("from_farm",   Vector2(8, (-VH + 3) * 16))
	_make_spawn("default",     Vector2(8, (-VH + 3) * 16))


func _make_spawn(id: String, pos: Vector2) -> void:
	var sp := Marker2D.new()
	sp.set_script(preload("res://scripts/world/spawn_point.gd"))
	sp.position = pos
	add_child(sp)
	# spawn_id 需在 add_child 後設定（_ready 會被呼叫）
	sp.spawn_id = id


# ── 裝飾樹木 ─────────────────────────────────────────────────────────────

func _add_trees() -> void:
	var TreeScene := preload("res://scenes/world/tree_object.tscn")

	# 沿地圖邊緣種樹（避開道路和出口）
	var positions : Array[Vector2] = [
		# 西北角
		Vector2(-36, -22), Vector2(-33, -22), Vector2(-36, -18),
		# 東北角
		Vector2(30, -22),  Vector2(33, -22),  Vector2(30, -18),
		# 西南角
		Vector2(-36, 10),  Vector2(-33, 10),
		# 東南角
		Vector2(30, 10),   Vector2(33, 10),
		# 東側牆邊
		Vector2(37, -20), Vector2(37, -8),  Vector2(37, 5),
		# 西側牆邊
		Vector2(-37, -20), Vector2(-37, -8), Vector2(-37, 5),
	]

	var ysort := $YSort
	for i in range(positions.size()):
		var tree : Node2D = TreeScene.instantiate()
		tree.position     = positions[i] * 16
		tree.seed_val     = i * 137 + 42
		tree.scale_factor = 0.9 + (i % 3) * 0.1
		ysort.add_child(tree)


# ── 工具 ─────────────────────────────────────────────────────────────────

func _place(x: int, y: int, coord: Vector2i) -> void:
	tile_map.set_cell(LAYER, Vector2i(x, y), SOURCE_ID, coord)
