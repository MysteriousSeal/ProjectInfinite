extends CharacterBody2D

const SPEED := 50.0
const DETECT_RADIUS := 90.0
const CONTACT_DAMAGE := 5
const CONTACT_COOLDOWN := 0.6
const XP_REWARD := 7
const DROP_CHANCE := 0.5

const LootItemScene := preload("res://scenes/LootItem.tscn")

# Wolves travel on the four cardinals only, which is also the set the walk
# cycle is drawn for. Ordered clockwise from east so a heading maps onto a slot
# by angle rather than a chain of comparisons.
const DIRECTIONS := ["east", "south", "west", "north"]
const IDLE_PATH := "res://assets/enemies/wolf/%s.png"
const WALK_PATH := "res://assets/enemies/wolf/walk/%s_%d.png"
const WALK_FRAMES := 4
const WALK_FPS := 8.0
const MOVING_SPEED := 1.0
# Lifts the sprite until the wolf's paws meet the bottom of its collision box.
const SPRITE_LIFT := -7

@onready var health: Health = $Health
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var sprite: AnimatedSprite2D = $Sprite

var player: Node2D
var contact_timer := 0.0
var facing := Vector2.DOWN

func _ready() -> void:
	add_to_group("enemies")
	sprite.sprite_frames = _build_sprite_frames()
	sprite.offset = Vector2(0, SPRITE_LIFT)
	_update_animation()
	health.died.connect(_on_died)
	contact_hitbox.body_entered.connect(_on_contact_body_entered)

func _physics_process(delta: float) -> void:
	if contact_timer > 0.0:
		contact_timer -= delta
	_find_player()
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= DETECT_RADIUS:
		# Closes the larger gap first, so the approach is a series of straight
		# runs rather than a diagonal the wolf has no art for.
		var offset := player.global_position - global_position
		if absf(offset.x) > absf(offset.y):
			velocity = Vector2(signf(offset.x), 0.0) * SPEED
		else:
			velocity = Vector2(0.0, signf(offset.y)) * SPEED
		facing = velocity
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_animation()

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		player = nodes[0]

func take_hit(amount: int, _from_dir: Vector2) -> void:
	health.take_damage(amount)

func _on_contact_body_entered(body: Node) -> void:
	if contact_timer <= 0.0 and body.is_in_group("player") and body.has_method("take_hit"):
		body.take_hit(CONTACT_DAMAGE, Vector2.ZERO)
		contact_timer = CONTACT_COOLDOWN

func _on_died() -> void:
	if player and is_instance_valid(player):
		player.add_xp(XP_REWARD)
	if randf() < DROP_CHANCE:
		var loot := LootItemScene.instantiate()
		loot.global_position = global_position
		get_parent().add_child(loot)
	queue_free.call_deferred()

func _facing_name() -> String:
	return DIRECTIONS[posmod(roundi(facing.angle() / (TAU / DIRECTIONS.size())), DIRECTIONS.size())]

func _update_animation() -> void:
	var clip := "walk_" if velocity.length() > MOVING_SPEED else "idle_"
	var wanted := clip + _facing_name()
	if sprite.animation != wanted:
		sprite.play(wanted)

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction: String in DIRECTIONS:
		var idle := "idle_" + direction
		frames.add_animation(idle)
		frames.add_frame(idle, load(IDLE_PATH % direction))
		var walk := "walk_" + direction
		frames.add_animation(walk)
		frames.set_animation_speed(walk, WALK_FPS)
		for i in WALK_FRAMES:
			frames.add_frame(walk, load(WALK_PATH % [direction, i]))
	return frames
