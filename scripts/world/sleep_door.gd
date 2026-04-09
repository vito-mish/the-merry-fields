## SleepDoor — 房屋門口睡覺觸發 (S02-T06)
## 玩家進入觸發區後按 Z 睡覺，淡出後推進至隔天
extends Area2D

var _player_inside : bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask  = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("action"):
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("sleep"):
			player.sleep()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	# 顯示提示
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(tr("SLEEP_HINT"))


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_hint"):
		hud.hide_hint()
