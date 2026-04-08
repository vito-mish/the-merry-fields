## ToolSprite — 顯示在玩家手上的工具視覺
## 掛在 Player 底下，依 facing 方向偏移到手的位置
extends Node2D

# 各方向手部偏移（相對於玩家中心）
# 玩家 sprite 16×24，中心在 (0,0)，腳在 y=12
const HAND_OFFSET : Array[Vector2] = [
	Vector2( 6,  2),   # down  → 右手在右側
	Vector2(-6,  -6),  # up    → 左手在左側
	Vector2(-7,  0),   # left  → 手在左側
	Vector2( 7,  0),   # right → 手在右側
]

# 各工具外觀（顏色 + 形狀標識）
const TOOL_COLOR : Dictionary = {
	"hoe":          Color(0.72, 0.50, 0.22, 1.0),
	"watering_can": Color(0.28, 0.58, 0.92, 1.0),
	"seeds":        Color(0.35, 0.80, 0.30, 1.0),
}

var _player : Node = null


func _ready() -> void:
	_player = get_parent()


func _process(_delta: float) -> void:
	if not _player:
		return
	var facing : int = _player.facing
	position = HAND_OFFSET[facing]
	queue_redraw()


func _draw() -> void:
	if not _player:
		return

	var tool  : String = _player.current_tool
	var col   : Color  = TOOL_COLOR.get(tool, Color.WHITE)

	match tool:
		"hoe":
			# 鋤頭：斜線握柄 + 頭部
			draw_line(Vector2(0, 0), Vector2(0, -6), col.darkened(0.3), 1.5)
			draw_rect(Rect2(-2, -8, 4, 3), col)

		"watering_can":
			# 水壺：小矩形 + 噴嘴
			draw_rect(Rect2(-3, -4, 5, 4), col)
			draw_line(Vector2(2, -3), Vector2(5, -5), col.lightened(0.2), 1.0)

		"seeds":
			# 種子袋：小圓點
			draw_circle(Vector2(0, -3), 3.0, col)
			draw_circle(Vector2(0, -3), 2.0, col.lightened(0.3))
