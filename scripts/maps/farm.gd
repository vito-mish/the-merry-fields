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


func _setup_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# Physics layer: must set collision_layer so CharacterBody2D (mask=1) hits it
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)

	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/tilesets/farm_tiles.png")
	source.texture_region_size = Vector2i(16, 16)

	# Walkable tiles (no collision)
	for coord in [T_GRASS, T_DIRT, T_TILLED, T_WATERED, T_PATH, T_FENCE]:
		source.create_tile(coord)

	# Blocking tiles (water, border) — full 16×16 solid box
	var box := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	for coord in [T_WATER, T_BORDER]:
		source.create_tile(coord)
		var td := source.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, box)

	ts.add_source(source, SOURCE_ID)
	tile_map.tile_set = ts


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
