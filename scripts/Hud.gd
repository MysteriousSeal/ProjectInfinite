extends CanvasLayer

@onready var label: Label = $Label

var player: Node

func bind(target: Node) -> void:
	player = target
	player.health.damaged.connect(func(_amount, _current): _refresh())
	player.health.died.connect(_refresh)
	player.loot_changed.connect(func(_count): _refresh())
	player.xp_changed.connect(func(_xp, _next): _refresh())
	player.leveled_up.connect(func(_level): _refresh())
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(player):
		return
	label.text = "Lv %d   HP: %d/%d   XP: %d/%d   Loot: %d" % [
		player.level, player.health.current, player.health.max_health,
		player.xp, player.xp_to_next, player.loot_count]
