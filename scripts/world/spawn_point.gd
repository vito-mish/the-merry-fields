## SpawnPoint — 場景內的玩家出現位置標記
## 放置在場景中，TransitionManager 會依 spawn_id 定位玩家
extends Marker2D

@export var spawn_id : String = "default"


func _ready() -> void:
	add_to_group("spawn_point")
