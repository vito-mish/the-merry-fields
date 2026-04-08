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
	_make_wall(Vector2(    0, -s + 8), Vector2(s * 2,      16))  # top
	_make_wall(Vector2(    0,  s - 8), Vector2(s * 2,      16))  # bottom
	_make_wall(Vector2(-s + 8,     0), Vector2(16,     s * 2))   # left
	_make_wall(Vector2( s - 8,     0), Vector2(16,     s * 2))   # right

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


func _place(x: int, y: int, coord: Vector2i) -> void:
	tile_map.set_cell(LAYER, Vector2i(x, y), SOURCE_ID, coord)
