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

func increase_max(amount: int) -> void:
	max_health += amount
	current += amount

# Maximum granted by equipment, which comes and goes as gear is swapped. Held
# apart from max_health so taking a bonus off can never dig into the maximum
# earned by spending attribute points.
var bonus_max := 0

func set_bonus_max(amount: int) -> void:
	var delta := amount - bonus_max
	if delta == 0:
		return
	bonus_max = amount
	max_health = maxi(max_health + delta, 1)
	# Gaining a bonus grants the health with it; losing one only trims what no
	# longer fits, so equipping and unequipping in a loop cannot be used to heal.
	if delta > 0:
		current += delta
	current = clampi(current, 0, max_health)
