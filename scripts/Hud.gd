extends CanvasLayer

@onready var label: Label = $Label

func bind(player: Node) -> void:
	player.health.damaged.connect(func(_amount, current): _refresh(current, player.health.max_health, player.loot_count))
	player.health.died.connect(func(): _refresh(0, player.health.max_health, player.loot_count))
	player.loot_changed.connect(func(count): _refresh(player.health.current, player.health.max_health, count))
	_refresh(player.health.current, player.health.max_health, player.loot_count)

func _refresh(hp: int, max_hp: int, loot: int) -> void:
	label.text = "HP: %d/%d   Loot: %d" % [hp, max_hp, loot]
