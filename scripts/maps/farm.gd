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
	_setup_tileset()
	_generate_farm()


func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()

	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/tilesets/farm_tiles.png")
	source.texture_region_size = Vector2i(16, 16)

	# Walkable tiles (no collision)
	for coord in [T_GRASS, T_DIRT, T_TILLED, T_WATERED, T_PATH, T_FENCE]:
		source.create_tile(coord)

	# Blocking tiles (water, border)
	for coord in [T_WATER, T_BORDER]:
		source.create_tile(coord)
		var td := source.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
		]))

	ts.add_source(source, SOURCE_ID)
	tile_map.tile_set = ts


func _generate_farm() -> void:
	var s := FARM_SIZE

	# ── Ground fill ──────────────────────────────────────────────────────
	for x in range(-s, s):
		for y in range(-s, s):
			_set(x, y, T_GRASS)

	# ── Border (impassable tree line) ────────────────────────────────────
	for i in range(-s, s):
		_set(i, -s, T_BORDER)
		_set(i,  s - 1, T_BORDER)
		_set(-s, i, T_BORDER)
		_set( s - 1, i, T_BORDER)

	# ── Inner fence (farm boundary) ───────────────────────────────────────
	for i in range(-s + 2, s - 2):
		_set(i, -s + 2, T_FENCE)
		_set(-s + 2, i, T_FENCE)
		_set( s - 3, i, T_FENCE)
	# Bottom fence has gate gap (entrance)
	for i in range(-s + 2, s - 2):
		if i < -2 or i > 2:
			_set(i, s - 3, T_FENCE)

	# ── Stone path (gate → house) ─────────────────────────────────────────
	for y in range(-10, s - 2):
		_set(-1, y, T_PATH)
		_set( 0, y, T_PATH)

	# ── Farmable dirt patch (left side) ───────────────────────────────────
	for x in range(-s + 4, -4):
		for y in range(-s + 4, 10):
			_set(x, y, T_DIRT)

	# ── Pond (top-right) ──────────────────────────────────────────────────
	for x in range(10, 18):
		for y in range(-s + 4, -18):
			_set(x, y, T_WATER)
	# Pond border (grass around)
	for x in range(9, 19):
		_set(x, -18, T_PATH)
		_set(x, -s + 3, T_PATH)
	for y in range(-s + 3, -17):
		_set(9, y, T_PATH)
		_set(18, y, T_PATH)


func _set(x: int, y: int, coord: Vector2i) -> void:
	tile_map.set_cell(LAYER, Vector2i(x, y), SOURCE_ID, coord)
