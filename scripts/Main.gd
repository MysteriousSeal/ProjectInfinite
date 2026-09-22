extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const ENEMY_COUNT := 5
const SPAWN_RADIUS := 150.0

@onready var chunk_manager := $ChunkManager
@onready var entities := $Entities
@onready var hud := $Hud
@onready var character_sheet := $CharacterSheet
@onready var loot_window := $LootWindow

func _ready() -> void:
	var player := PlayerScene.instantiate()
	# Everything that shares the ground goes in one depth-sorted layer, so the
	# player passes behind a tree standing below them and in front of one above.
	entities.add_child(player)
	chunk_manager.follow(player)
	chunk_manager.set_object_parent(entities)
	hud.bind(player)
	character_sheet.bind(player)
	loot_window.bind(player)
	for i in ENEMY_COUNT:
		var enemy := EnemyScene.instantiate()
		enemy.global_position = Vector2(randf_range(-SPAWN_RADIUS, SPAWN_RADIUS), randf_range(-SPAWN_RADIUS, SPAWN_RADIUS))
		entities.add_child(enemy)
