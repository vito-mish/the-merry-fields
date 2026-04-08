## DebugPanel — 開發期快捷鍵（正式版移除）
## F1 = 跳到隔天
## F2 = 體力全滿
## F3 = 顯示當前面向 tile 狀態
extends Node

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				TimeManager.advance_to_next_day()
				print("[DEBUG] 跳到隔天：", TimeManager.get_date_string())

			KEY_F2:
				var player : Node = get_tree().get_first_node_in_group("player")
				if player:
					player.restore_stamina(player.STAMINA_MAX)
					print("[DEBUG] 體力補滿")

			KEY_F3:
				var player    : Node = get_tree().get_first_node_in_group("player")
				var farm_grid : Node = get_tree().get_first_node_in_group("farm_grid")
				if player and farm_grid:
					var tile_pos : Vector2i = player._facing_tile_pos
					var state    : String   = farm_grid.get_tile_state(tile_pos)
					var mature   : bool     = farm_grid.is_mature(tile_pos)
					print("[DEBUG] tile %s → state: %s, mature: %s" % [tile_pos, state, mature])
					# 印出完整 tile 資料
					if farm_grid._tiles.has(tile_pos):
						print("[DEBUG] tile data: ", farm_grid._tiles[tile_pos])
