extends Control

const MAP_HALF := 30        # farm goes -30 to +29
const MAP_SIZE := MAP_HALF * 2  # 60 tiles
const DISPLAY  := 48        # minimap display size in pixels

const PALETTE := {
	Vector2i(0, 0): Color(0.32, 0.58, 0.24),  # grass
	Vector2i(1, 0): Color(0.68, 0.50, 0.32),  # dirt
	Vector2i(2, 0): Color(0.47, 0.32, 0.17),  # tilled
	Vector2i(3, 0): Color(0.35, 0.23, 0.12),  # watered
	Vector2i(4, 0): Color(0.63, 0.58, 0.50),  # path
	Vector2i(5, 0): Color(0.19, 0.51, 0.82),  # water
	Vector2i(6, 0): Color(0.55, 0.38, 0.22),  # fence
	Vector2i(7, 0): Color(0.14, 0.35, 0.15),  # border
}

var _map_texture: ImageTexture
var _player_dot := Vector2(MAP_HALF, MAP_HALF)


func _ready() -> void:
	custom_minimum_size = Vector2(DISPLAY, DISPLAY)
	# Wait one frame so TileMap is ready
	await get_tree().process_frame
	_build_map_texture()


func _build_map_texture() -> void:
	var tile_map: TileMap = get_tree().get_first_node_in_group("tile_map")
	if not tile_map:
		return

	var img := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)

	for x in range(-MAP_HALF, MAP_HALF):
		for y in range(-MAP_HALF, MAP_HALF):
			var atlas := tile_map.get_cell_atlas_coords(0, Vector2i(x, y))
			var col: Color = PALETTE.get(atlas, Color.BLACK)
			img.set_pixel(x + MAP_HALF, y + MAP_HALF, col)

	_map_texture = ImageTexture.create_from_image(img)
	queue_redraw()


func _process(_delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player:
		var tile := player.position / 16.0
		_player_dot = Vector2(tile.x + MAP_HALF, tile.y + MAP_HALF)
	queue_redraw()


func _draw() -> void:
	if _map_texture:
		draw_texture_rect(_map_texture, Rect2(0, 0, DISPLAY, DISPLAY), false)

	# Player dot (white with black outline)
	var scale := float(DISPLAY) / MAP_SIZE
	var dot := _player_dot * scale
	draw_circle(dot, 2.5, Color.BLACK)
	draw_circle(dot, 1.5, Color.WHITE)
