## SceneExit — 玩家踩入後觸發場景切換的 Area2D
## 搭配 TransitionManager 使用
extends Area2D

## 目標場景的路徑（res://...）
@export_file("*.tscn") var target_scene : String = ""

## 目標場景中的 SpawnPoint ID
@export var spawn_id : String = "default"

## （選用）顯示在 HUD 的提示文字，例如「前往村莊」
@export var label    : String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not target_scene.is_empty():
		if not TransitionManager.is_transitioning():
			TransitionManager.change_scene(target_scene, spawn_id)
