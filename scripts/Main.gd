extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const ENEMY_COUNT := 5
const SPAWN_RADIUS := 150.0

@onready var chunk_manager := $ChunkManager
@onready var hud := $Hud

func _ready() -> void:
	var player := PlayerScene.instantiate()
	add_child(player)
	chunk_manager.follow(player)
	hud.bind(player)
	for i in ENEMY_COUNT:
		var enemy := EnemyScene.instantiate()
		enemy.global_position = Vector2(randf_range(-SPAWN_RADIUS, SPAWN_RADIUS), randf_range(-SPAWN_RADIUS, SPAWN_RADIUS))
		add_child(enemy)
