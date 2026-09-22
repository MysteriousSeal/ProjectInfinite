extends Node
class_name Health

signal died
signal damaged(amount: int, current: int)

@export var max_health: int = 30
var current: int

func _ready() -> void:
	current = max_health

func take_damage(amount: int) -> void:
	if current <= 0:
		return
	current = max(current - amount, 0)
	damaged.emit(amount, current)
	if current == 0:
		died.emit()

func heal(amount: int) -> void:
	current = min(current + amount, max_health)
