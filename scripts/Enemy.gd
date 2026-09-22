extends CharacterBody2D

const SPEED := 50.0
const DETECT_RADIUS := 90.0
const CONTACT_DAMAGE := 5
const CONTACT_COOLDOWN := 0.6
const XP_REWARD := 7
const DROP_CHANCE := 0.5

const LootItemScene := preload("res://scenes/LootItem.tscn")

# Ordered clockwise from east, matching the angle of the wolf's heading, so a
# direction is a straight lookup rather than a chain of comparisons.
const DIRECTIONS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const SPRITE_PATH := "res://assets/enemies/wolf/%s.png"
# Lifts the sprite until the wolf's paws meet the bottom of its collision box.
const SPRITE_LIFT := -7

@onready var health: Health = $Health
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var sprite: Sprite2D = $Sprite

var player: Node2D
var contact_timer := 0.0
var facing := Vector2.DOWN

func _ready() -> void:
	add_to_group("enemies")
	sprite.offset = Vector2(0, SPRITE_LIFT)
	_face_sprite()
	health.died.connect(_on_died)
	contact_hitbox.body_entered.connect(_on_contact_body_entered)

func _physics_process(delta: float) -> void:
	if contact_timer > 0.0:
		contact_timer -= delta
	_find_player()
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= DETECT_RADIUS:
		velocity = global_position.direction_to(player.global_position) * SPEED
		facing = velocity
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_face_sprite()

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

# The wolf is drawn for all eight headings, so the angle maps straight onto a
# slot instead of collapsing diagonals onto a cardinal.
func _face_sprite() -> void:
	var slot := posmod(roundi(facing.angle() / (TAU / DIRECTIONS.size())), DIRECTIONS.size())
	sprite.texture = load(SPRITE_PATH % DIRECTIONS[slot])
