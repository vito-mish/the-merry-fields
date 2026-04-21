## SaveManager — 存檔與讀檔 (S12-T01~T04)
## Autoload 單例。資料以 JSON 存於 user://save.json。
## 讀檔流程：
##   _ready() → 解析 JSON → 立刻套用 Time/Economy/Inventory
##              → 暫存 Farm/Player → FarmGrid._ready() / Player._ready() 各自領取
extends Node

const SAVE_PATH : String = "user://save.json"
const VERSION   : int    = 1

# 暫存待套用的場景資料（autoload 比場景節點先 ready）
var _pending_player      : Dictionary = {}
var _pending_farm        : Array      = []
var _has_pending_player  : bool       = false
var _has_pending_farm    : bool       = false

signal save_completed
signal load_completed(success: bool)


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_load_file()


# ── 存檔 ─────────────────────────────────────────────────────────────────────

func save() -> void:
	var data : Dictionary = {
		"version":   VERSION,
		"time":      _collect_time(),
		"player":    _collect_player(),
		"economy":   _collect_economy(),
		"inventory": _collect_inventory(),
		"farm":      _collect_farm(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		save_completed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# ── 讀檔 ─────────────────────────────────────────────────────────────────────

func _load_file() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		load_completed.emit(false)
		return
	var text : String = f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		load_completed.emit(false)
		return

	var data : Dictionary = json.get_data()

	# 立刻套用（Autoload 已就緒）
	_apply_time(data.get("time", {}))
	_apply_economy(data.get("economy", {}))
	_apply_inventory(data.get("inventory", {}))

	# 暫存場景資料，等場景節點 _ready() 後自行領取
	_pending_player     = data.get("player", {})
	_pending_farm       = data.get("farm", [])
	_has_pending_player = not _pending_player.is_empty()
	_has_pending_farm   = not _pending_farm.is_empty()

	load_completed.emit(true)


## farm.gd._ready() 呼叫：領取農地資料（只能領一次）
func pop_pending_farm() -> Array:
	if not _has_pending_farm:
		return []
	var d := _pending_farm
	_pending_farm     = []
	_has_pending_farm = false
	return d


## Player._ready() 呼叫：領取玩家資料（只能領一次）
func pop_pending_player() -> Dictionary:
	if not _has_pending_player:
		return {}
	var d := _pending_player
	_pending_player     = {}
	_has_pending_player = false
	return d


# ── 收集存檔資料 ──────────────────────────────────────────────────────────────

func _collect_time() -> Dictionary:
	return {
		"day":    TimeManager.day,
		"season": TimeManager.season,
		"year":   TimeManager.year,
		"hour":   TimeManager.hour,
		"minute": TimeManager.minute,
	}


func _collect_player() -> Dictionary:
	var player : Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return {}
	return {
		"x":           player.position.x,
		"y":           player.position.y,
		"stamina":     player.stamina,
		"tool_index":  player.tool_index,
		"seed_crop_id": player.seed_crop_id,
	}


func _collect_economy() -> Dictionary:
	return { "gold": EconomyManager.get_gold() }


func _collect_inventory() -> Dictionary:
	return InventoryManager.get_all_items()


func _collect_farm() -> Array:
	var farm_grid : Node = get_tree().get_first_node_in_group("farm_grid")
	if farm_grid == null:
		return []
	var result : Array = []
	for pos : Vector2i in farm_grid.get_saved_tiles():
		var t : Dictionary = farm_grid.get_tile_data(pos)
		var entry : Dictionary = { "x": pos.x, "y": pos.y }
		entry.merge(t)
		result.append(entry)
	return result


# ── 套用存檔資料 ──────────────────────────────────────────────────────────────

func _apply_time(d: Dictionary) -> void:
	if d.is_empty():
		return
	TimeManager.day    = d.get("day",    1)
	TimeManager.season = d.get("season", 0)
	TimeManager.year   = d.get("year",   1)
	TimeManager.hour   = d.get("hour",   GameConfig.DAY_START_HOUR)
	TimeManager.minute = d.get("minute", 0)


func _apply_economy(d: Dictionary) -> void:
	if d.is_empty():
		return
	var target : int = d.get("gold", 500)
	var diff   : int = target - EconomyManager.get_gold()
	if diff > 0:
		EconomyManager.add_gold(diff)
	elif diff < 0:
		EconomyManager.spend_gold(-diff)


func _apply_inventory(d: Dictionary) -> void:
	if d.is_empty():
		return
	for item_id : String in d.keys():
		var qty : int = d[item_id]
		# 重設為存檔數量
		var cur : int = InventoryManager.get_quantity(item_id)
		if cur < qty:
			InventoryManager.add_item(item_id, qty - cur)
		elif cur > qty:
			InventoryManager.remove_item(item_id, cur - qty)
