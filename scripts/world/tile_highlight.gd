## TileHighlight — 顯示玩家當前聚焦的農地格子
extends Node2D

const TILE_SIZE := 16
const COL_CAN   := Color(0.35, 1.00, 0.35, 0.55)   # 可互動：淡綠，半透明
const COL_NONE  := Color(0.0,  0.0,  0.0,  0.0)     # 不可互動：完全透明

var _col    : Color = COL_NONE
var _active : bool  = false


func _process(_delta: float) -> void:
	var player    : Node = get_tree().get_first_node_in_group("player")
	var farm_grid : Node = get_tree().get_first_node_in_group("farm_grid")

	if not player or not farm_grid:
		_active = false
		queue_redraw()
		return

	var tile_pos : Vector2i = player._facing_tile_pos

	# 移到對應 tile 的左上角
	position = Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)

	var state   : String = farm_grid.get_tile_state(tile_pos)
	var can_use : bool   = _check_usable(player.current_tool, state, farm_grid, tile_pos)

	_active = can_use
	_col    = COL_CAN if can_use else COL_NONE
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	# 填色
	draw_rect(Rect2(0, 0, TILE_SIZE, TILE_SIZE), _col)

	# 框線（比填色更不透明）
	var border := Color(_col.r, _col.g, _col.b, minf(_col.a + 0.35, 1.0))
	draw_rect(Rect2(0, 0, TILE_SIZE, TILE_SIZE), border, false, 1.5)

	# 四角小方塊強調
	var corner_size := 2.5
	var c := border
	draw_rect(Rect2(0, 0, corner_size, corner_size), c)
	draw_rect(Rect2(TILE_SIZE - corner_size, 0, corner_size, corner_size), c)
	draw_rect(Rect2(0, TILE_SIZE - corner_size, corner_size, corner_size), c)
	draw_rect(Rect2(TILE_SIZE - corner_size, TILE_SIZE - corner_size, corner_size, corner_size), c)


func _check_usable(tool: String, state: String, farm_grid: Node, tile_pos: Vector2i) -> bool:
	match tool:
		"hoe":          return state == "dirt"
		"watering_can": return state == "tilled" or state == "planted"
		"seeds":        return state == "tilled" or state == "watered"
		_:              return farm_grid.is_mature(tile_pos)
