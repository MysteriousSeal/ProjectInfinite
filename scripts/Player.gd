extends CharacterBody2D

const SPEED := 90.0
const ATTACK_DURATION := 0.18
const ATTACK_COOLDOWN := 0.3
const ATTACK_DAMAGE := 10
const HITBOX_OFFSET := 12.0

@onready var health: Health = $Health
@onready var hitbox: Area2D = $Hitbox

var facing := Vector2.DOWN
var attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var loot_count := 0
var _attack_key_was_down := false

signal died
signal loot_changed(count: int)

func _ready() -> void:
	add_to_group("player")
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if attacking:
		velocity = Vector2.ZERO
	else:
		_handle_movement()
		if _poll_attack_pressed() and cooldown_timer <= 0.0:
			_start_attack()
	move_and_slide()
	queue_redraw()

func _handle_movement() -> void:
	var dir := _get_input_dir()
	if dir.length() > 0.0:
		dir = dir.normalized()
		facing = dir
	velocity = dir * SPEED

func _get_input_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	return dir

func _poll_attack_pressed() -> bool:
	var down := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var just_pressed := down and not _attack_key_was_down
	_attack_key_was_down = down
	return just_pressed

func _start_attack() -> void:
	attacking = true
	attack_timer = ATTACK_DURATION
	cooldown_timer = ATTACK_COOLDOWN
	hitbox.position = facing * HITBOX_OFFSET
	hitbox.monitoring = true

func _tick_timers(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	if attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attacking = false
			hitbox.monitoring = false

func _on_hitbox_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		body.take_hit(ATTACK_DAMAGE, facing)

func take_hit(amount: int, _from_dir: Vector2) -> void:
	health.take_damage(amount)

func add_loot(amount: int) -> void:
	loot_count += amount
	loot_changed.emit(loot_count)

func _on_died() -> void:
	died.emit()
	queue_free.call_deferred()

func _draw() -> void:
	draw_rect(Rect2(-6, -8, 12, 16), Color(0.2, 0.6, 1.0))
	draw_line(Vector2.ZERO, facing * 10.0, Color(1, 1, 0), 2.0)
