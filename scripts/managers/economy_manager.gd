## EconomyManager — 貨幣系統 (S08-T01)
## Autoload 單例，管理玩家金錢與收入紀錄
extends Node

var gold : int = 500   # 初始金錢

signal gold_changed(new_amount: int)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func get_gold() -> int:
	return gold
