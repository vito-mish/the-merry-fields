extends CharacterBody2D

# Movement
const SPEED := 80.0

# Stamina
const STAMINA_MAX := 100.0
var stamina := STAMINA_MAX

# Direction: 0=down, 1=up, 2=left, 3=right
var facing := 0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(_delta: float) -> void:
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	velocity = input * SPEED
	move_and_slide()
	_update_facing(input)
	_update_animation(input)


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
	var dir := ["down", "up", "left", "right"][facing]
	var state := "walk_" + dir if input != Vector2.ZERO else "idle_" + dir
	if anim.animation != state:
		anim.play(state)


func consume_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


func restore_stamina(amount: float) -> void:
	stamina = min(stamina + amount, STAMINA_MAX)
