extends CharacterBody2D

# ── 體力 ─────────────────────────────────────────────────────────────────
var stamina : float = GameConfig.STAMINA_MAX

# ── 工具 ─────────────────────────────────────────────────────────────────
## 可用工具清單
const TOOLS : Array[String] = ["hoe", "watering_can", "seeds", "fertilizer"]
## 目前選擇的工具索引
var tool_index : int    = 0
var current_tool: String:
	get: return TOOLS[tool_index]

## 目前攜帶的種子種類
var seed_crop_id : String = "turnip"

# ── 方向：0=down 1=up 2=left 3=right ─────────────────────────────────────
var facing := 0

## 當前面向的 tile（供 TileHighlight 讀取）
var _facing_tile_pos : Vector2i = Vector2i.ZERO

# ── 互動冷卻（避免按住 action 連續觸發）────────────────────────────────────
var _action_cooldown : float = 0.0
const ACTION_CD      : float = 0.3

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null


func _ready() -> void:
	add_to_group("player")
	TimeManager.late_night.connect(_on_late_night)
	TimeManager.forced_sleep.connect(_on_forced_sleep)


func _physics_process(delta: float) -> void:
	var hud : Node = get_tree().get_first_node_in_group("hud")

	# 背包 / 報表開啟時鎖定移動與動作
	if hud and (hud.report_open or hud.inventory_open):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		# 仍允許開關背包
		if Input.is_action_just_pressed("ui_inventory"):
			if hud:
				hud.toggle_inventory()
		return

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	velocity = input * GameConfig.PLAYER_SPEED
	move_and_slide()
	_update_facing(input)
	_update_animation(input)
	_facing_tile_pos = _facing_tile()

	# 開關背包（I 鍵 / 手把 Y）
	if Input.is_action_just_pressed("ui_inventory"):
		if hud:
			hud.toggle_inventory()
		return

	# 工具切換（Q / E 或 LB / RB）
	if Input.is_action_just_pressed("tool_prev"):
		tool_index = (tool_index - 1 + TOOLS.size()) % TOOLS.size()
	if Input.is_action_just_pressed("tool_next"):
		tool_index = (tool_index + 1) % TOOLS.size()

	# 種子切換（Tab 或手把 LT）：只在持種子時有效
	if Input.is_action_just_pressed("cycle_seed") and current_tool == "seeds":
		_cycle_seed()

	# 互動
	_action_cooldown = maxf(0.0, _action_cooldown - delta)
	if Input.is_action_pressed("action") and _action_cooldown <= 0.0:
		_action_cooldown = ACTION_CD
		_use_tool()


# ── 工具使用 ──────────────────────────────────────────────────────────────

func _use_tool() -> void:
	var farm_grid := _get_farm_grid()
	if farm_grid == null:
		return

	var tile_pos := _facing_tile()
	var cost     : float = GameConfig.TOOL_STAMINA.get(current_tool, 0.0)

	match current_tool:
		"hoe":
			if farm_grid.get_tile_state(tile_pos) == "dirt":
				if consume_stamina(cost):
					farm_grid.till(tile_pos)

		"watering_can":
			var state : String = farm_grid.get_tile_state(tile_pos)
			if state == "tilled" or state == "planted":
				if consume_stamina(cost):
					farm_grid.water(tile_pos)

		"seeds":
			var state : String = farm_grid.get_tile_state(tile_pos)
			if state == "tilled" or state == "watered":
				var hud_ref : Node = get_tree().get_first_node_in_group("hud")
				# S04-T13: 季節限制
				if not farm_grid.can_plant_in_season(seed_crop_id):
					if hud_ref:
						hud_ref.show_notification(tr("NOTIF_WRONG_SEASON"), Color(0.95, 0.55, 0.15))
				else:
					var sid : String = InventoryManager.seed_id_for_crop(seed_crop_id)
					if not InventoryManager.has_item(sid):
						if hud_ref:
							hud_ref.show_notification("種子不足！", Color(1.0, 0.45, 0.15))
					elif consume_stamina(cost):
						if farm_grid.plant(tile_pos, seed_crop_id):
							InventoryManager.remove_item(sid)

		"fertilizer":
			var state : String = farm_grid.get_tile_state(tile_pos)
			if state == "tilled" or state == "watered" or state == "planted":
				if not farm_grid.is_fertilized(tile_pos):
					if consume_stamina(cost):
						farm_grid.fertilize(tile_pos)

	# 成熟作物隨時可收成（不限工具）
	if farm_grid.is_mature(tile_pos):
		var quality : String = farm_grid.harvest(tile_pos)
		if quality != "":
			var hud : Node = get_tree().get_first_node_in_group("hud")
			if hud:
				hud.show_harvest_notification(quality)


## 回傳玩家面向的 tile 座標
func _facing_tile() -> Vector2i:
	var offsets : Array[Vector2i] = [
		Vector2i( 0,  1),  # down
		Vector2i( 0, -1),  # up
		Vector2i(-1,  0),  # left
		Vector2i( 1,  0),  # right
	]
	var foot := Vector2i(
		int(floor(position.x / 16.0)),
		int(floor(position.y / 16.0))
	)
	return foot + offsets[facing]


## 循環切換到下一個當前季節可種的作物
func _cycle_seed() -> void:
	var farm_grid := _get_farm_grid()
	if farm_grid == null:
		return
	# 取得所有作物 id（從 farm_grid 的 crop_db）
	var all_ids : Array = farm_grid.get_crop_ids()
	# 篩出當前季節可種且背包有種子的
	var available : Array[String] = []
	for id : String in all_ids:
		if farm_grid.can_plant_in_season(id) and InventoryManager.has_item(InventoryManager.seed_id_for_crop(id)):
			available.append(id)
	if available.is_empty():
		return
	var idx : int = available.find(seed_crop_id)
	idx = (idx + 1) % available.size()
	seed_crop_id = available[idx]
	# 通知 HUD 更新工具列
	queue_redraw()
	var hud : Node = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.refresh_toolbar()


func _get_farm_grid() -> Node:
	return get_tree().get_first_node_in_group("farm_grid")


# ── 動畫 ─────────────────────────────────────────────────────────────────

func _update_facing(input: Vector2) -> void:
	if input.x > 0:
		facing = 3
	elif input.x < 0:
		facing = 2
	elif input.y < 0:
		facing = 1
	elif input.y > 0:
		facing = 0


func _update_animation(input: Vector2) -> void:
	if anim == null:
		return
	var dir   : String = ["down", "up", "left", "right"][facing]
	var state : String = "walk_" + dir if input != Vector2.ZERO else "idle_" + dir
	if anim.animation != state:
		anim.play(state)


# ── 體力 ─────────────────────────────────────────────────────────────────

func consume_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, GameConfig.STAMINA_MAX)


# ── 睡眠 ─────────────────────────────────────────────────────────────────

func _on_late_night(_hour: int) -> void:
	pass  # 只顯示 HUD 警告，不影響體力


func _on_forced_sleep() -> void:
	var fee := mini(GameConfig.DOCTOR_FEE, EconomyManager.get_gold())
	EconomyManager.spend_gold(fee)
	_do_sleep(true)


## 主動睡覺（進房屋觸發）
func sleep() -> void:
	_do_sleep(false)


func _do_sleep(fainted: bool) -> void:
	var penalty := GameConfig.FAINT_STAMINA_PENALTY if fainted else _calc_sleep_penalty()
	var wake_stamina := GameConfig.STAMINA_MAX * (1.0 - penalty)
	TransitionManager.sleep_transition(func() -> void:
		stamina = wake_stamina
		TimeManager.advance_to_next_day()
	)


## 依目前時間查表，取得主動睡覺的體力懲罰
func _calc_sleep_penalty() -> float:
	var h := TimeManager.hour
	# 懲罰只在 01:00~03:59 之間有效，其他時間睡覺不扣體力
	if h < 1 or h >= 4:
		return 0.0
	for check_hour in [3, 2, 1]:
		if h >= check_hour:
			return GameConfig.SLEEP_PENALTY_BY_HOUR[check_hour]
	return 0.0
