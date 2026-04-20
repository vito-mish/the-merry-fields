## InventoryManager — 背包道具管理 (S11-T05, S08-T02)
## Autoload 單例，管理玩家持有的道具與種子數量
extends Node

# ── 種子道具靜態資料 ─────────────────────────────────────────────────────────
const SEASON_COLORS : Dictionary = {
	"spring": Color(0.40, 0.88, 0.38),
	"summer": Color(0.98, 0.78, 0.18),
	"autumn": Color(0.88, 0.50, 0.16),
	"winter": Color(0.60, 0.82, 0.98),
}
const SEASON_LABELS : Dictionary = {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
}

const SEED_ITEMS : Dictionary = {
	"seed_turnip":     { "name": "蕪菁",   "crop_id": "turnip",     "color": Color(0.92, 0.80, 0.22), "seasons": ["spring"] },
	"seed_potato":     { "name": "馬鈴薯", "crop_id": "potato",     "color": Color(0.72, 0.58, 0.25), "seasons": ["spring"] },
	"seed_strawberry": { "name": "草莓",   "crop_id": "strawberry", "color": Color(0.92, 0.15, 0.22), "seasons": ["spring"] },
	"seed_tomato":     { "name": "番茄",   "crop_id": "tomato",     "color": Color(0.92, 0.20, 0.12), "seasons": ["summer"] },
	"seed_corn":       { "name": "玉米",   "crop_id": "corn",       "color": Color(0.98, 0.82, 0.18), "seasons": ["summer"] },
	"seed_pumpkin":    { "name": "南瓜",   "crop_id": "pumpkin",    "color": Color(0.92, 0.52, 0.10), "seasons": ["autumn"] },
	"seed_eggplant":   { "name": "茄子",   "crop_id": "eggplant",   "color": Color(0.38, 0.08, 0.62), "seasons": ["autumn"] },
	"seed_cabbage":    { "name": "白菜",   "crop_id": "cabbage",    "color": Color(0.78, 0.92, 0.60), "seasons": ["winter"] },
	"seed_daikon":     { "name": "白蘿蔔", "crop_id": "daikon",     "color": Color(0.94, 0.94, 0.90), "seasons": ["winter"] },
}

# ── 背包資料 ──────────────────────────────────────────────────────────────────
var _items : Dictionary = {}   # item_id → quantity

signal item_changed(item_id: String, new_qty: int)


func _ready() -> void:
	_give_starter_seeds()


## 初始種子（每種 10 個）
func _give_starter_seeds() -> void:
	for sid in SEED_ITEMS.keys():
		_items[sid] = 10


# ── 公開 API ─────────────────────────────────────────────────────────────────

func add_item(item_id: String, qty: int = 1) -> void:
	_items[item_id] = _items.get(item_id, 0) + qty
	item_changed.emit(item_id, _items[item_id])


func remove_item(item_id: String, qty: int = 1) -> bool:
	var cur : int = _items.get(item_id, 0)
	if cur < qty:
		return false
	_items[item_id] = cur - qty
	item_changed.emit(item_id, _items[item_id])
	return true


func has_item(item_id: String, qty: int = 1) -> bool:
	return _items.get(item_id, 0) >= qty


func get_quantity(item_id: String) -> int:
	return _items.get(item_id, 0)


func get_all_items() -> Dictionary:
	return _items.duplicate()


func get_item_info(item_id: String) -> Dictionary:
	if SEED_ITEMS.has(item_id):
		return SEED_ITEMS[item_id]
	return {}


## 給定作物 id，回傳對應的種子道具 id
func seed_id_for_crop(crop_id: String) -> String:
	return "seed_" + crop_id
