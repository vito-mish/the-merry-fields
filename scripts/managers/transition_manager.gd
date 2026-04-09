## TransitionManager — autoload singleton
## 負責場景切換與淡入淡出效果 (S03-T06, S03-T07)
extends CanvasLayer

const FADE_DURATION := 0.35

var _is_busy    := false
var _overlay    : ColorRect


func _ready() -> void:
	layer        = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # 場景切換時仍可繼續運作

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color        = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## 切換至目標場景，並在 spawn_id 對應的 SpawnPoint 處生成玩家
func change_scene(target_path: String, spawn_id: String = "default") -> void:
	if _is_busy:
		return
	_is_busy = true

	await _fade_to(1.0)

	get_tree().change_scene_to_file(target_path)

	# 等兩幀，確保新場景的 _ready() 已執行
	await get_tree().process_frame
	await get_tree().process_frame

	_teleport_player(spawn_id)

	await _fade_to(0.0)
	_is_busy = false


func is_transitioning() -> bool:
	return _is_busy


## 睡眠淡出淡入：淡黑後執行 on_black，再淡入
func sleep_transition(on_black: Callable) -> void:
	if _is_busy:
		return
	_is_busy = true
	await _fade_to(1.0)
	on_black.call()
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_is_busy = false


# ── 私有 ─────────────────────────────────────────────────────────────────

func _fade_to(alpha: float) -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_overlay, "color:a", alpha, FADE_DURATION)
	await tw.finished


func _teleport_player(spawn_id: String) -> void:
	var player : Node2D = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# 尋找符合 spawn_id 的 SpawnPoint
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if sp.get("spawn_id") == spawn_id:
			player.global_position = sp.global_position
			return

	# Fallback：使用任意一個 SpawnPoint
	var all_spawns: Array[Node] = get_tree().get_nodes_in_group("spawn_point")
	if all_spawns.size() > 0:
		player.global_position = all_spawns[0].global_position
