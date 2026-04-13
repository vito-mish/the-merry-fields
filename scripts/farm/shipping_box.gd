## ShippingBox — 出貨箱 (S08-T03)
## 玩家面向出貨箱按 Z 放入收成物，隔天結算獲得金錢
## 掛在 Farm 場景，由 farm.gd 在 _ready() 建立
extends Area2D

# 等待出貨的物品 { crop_id: String, quality: String, count: int }
var _pending : Array[Dictionary] = []

# 作物 DB（從 FarmGrid 讀取，或直接讀 JSON）
var _crop_db : Dictionary = {}

# lines: Array[Dictionary] — { name, quality_label, count, subtotal }
signal items_shipped(total_gold: int, lines: Array)


func _ready() -> void:
	add_to_group("shipping_box")
	_load_crop_db()
	TimeManager.day_changed.connect(_on_day_changed)
	body_entered.connect(_on_body_entered)


## 放入一筆收成
func add_item(crop_id: String, quality: String) -> void:
	for entry in _pending:
		if entry["crop_id"] == crop_id and entry["quality"] == quality:
			entry["count"] += 1
			return
	_pending.append({ "crop_id": crop_id, "quality": quality, "count": 1 })


## 隔天結算
func _on_day_changed(_day: int, _season: int, _year: int) -> void:
	if _pending.is_empty():
		return

	var total : int = 0
	var lines : Array = []
	for entry in _pending:
		var base     : int   = _get_sell_price(entry["crop_id"])
		var multi    : float = _quality_multiplier(entry["quality"])
		var subtotal : int   = int(base * multi) * entry["count"]
		total += subtotal
		lines.append({
			"name":          _get_crop_name(entry["crop_id"]),
			"quality_label": _quality_label(entry["quality"]),
			"count":         entry["count"],
			"subtotal":      subtotal,
		})

	_pending.clear()
	EconomyManager.add_gold(total)
	items_shipped.emit(total, lines)


## 玩家進入範圍（自動放入手持作物，簡易版）
func _on_body_entered(body: Node) -> void:
	# 實際背包系統做好後再接，這裡先留接口
	pass


func _get_crop_name(crop_id: String) -> String:
	if _crop_db.has(crop_id):
		return _crop_db[crop_id].get("name", crop_id)
	return crop_id


func _quality_label(quality: String) -> String:
	match quality:
		"premium": return "精品"
		"good":    return "優良"
		_:         return "普通"


func _get_sell_price(crop_id: String) -> int:
	if _crop_db.has(crop_id):
		return _crop_db[crop_id].get("sell_price", 50)
	return 50


func _quality_multiplier(quality: String) -> float:
	match quality:
		"premium": return 2.0   # 精品
		"good":    return 1.5   # 優良
		_:         return 1.0   # 普通 (normal)


func _load_crop_db() -> void:
	var f := FileAccess.open("res://data/crops/crops.json", FileAccess.READ)
	if f:
		_crop_db = JSON.parse_string(f.get_as_text())
		f.close()
