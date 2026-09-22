extends CharacterBody2D

const SPEED := 90.0
const ATTACK_DURATION := 0.18
const ATTACK_COOLDOWN := 0.3
const ATTACK_DAMAGE := 10
const HITBOX_OFFSET := 12.0
const XP_FOR_FIRST_LEVEL := 20
const MIN_ATTACK_COOLDOWN := 0.12

enum Stat { ENDURANCE, STAMINA, DEXTERITY, INTELLIGENCE }

const BASE_STAT := 5
const HEALTH_PER_ENDURANCE := 10
const SPEED_PER_DEXTERITY := 4.0
const COOLDOWN_PER_DEXTERITY := 0.01

@onready var health: Health = $Health
@onready var hitbox: Area2D = $Hitbox

var facing := Vector2.DOWN
var attacking := false
var attack_timer := 0.0
var cooldown_timer := 0.0
var loot_count := 0
var xp := 0
var level := 1
var xp_to_next := XP_FOR_FIRST_LEVEL
var endurance := BASE_STAT
var stamina := BASE_STAT
var dexterity := BASE_STAT
var intelligence := BASE_STAT
var stat_points := 0
var nearby_pouches: Array[Node] = []
var _attack_key_was_down := false
var _open_key_was_down := false

signal died
signal loot_changed(count: int)
signal xp_changed(xp: int, xp_to_next: int)
signal leveled_up(level: int)
signal stats_changed

func _ready() -> void:
	add_to_group("player")
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if _poll_open_pressed():
		_open_nearby_pouch()
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
	velocity = dir * move_speed()

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

func _poll_open_pressed() -> bool:
	var down := Input.is_physical_key_pressed(KEY_E)
	var just_pressed := down and not _open_key_was_down
	_open_key_was_down = down
	return just_pressed

func pouch_in_range(pouch: Node) -> void:
	if not nearby_pouches.has(pouch):
		nearby_pouches.append(pouch)

func pouch_out_of_range(pouch: Node) -> void:
	nearby_pouches.erase(pouch)

func _open_nearby_pouch() -> void:
	if nearby_pouches.is_empty():
		return
	var pouch: Node = nearby_pouches.pop_front()
	add_loot(pouch.open())

func _start_attack() -> void:
	attacking = true
	attack_timer = ATTACK_DURATION
	cooldown_timer = attack_cooldown()
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

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = XP_FOR_FIRST_LEVEL * level
		stat_points += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next)

func spend_stat_point(stat: Stat) -> void:
	if stat_points <= 0:
		return
	stat_points -= 1
	match stat:
		Stat.ENDURANCE:
			endurance += 1
			health.increase_max(HEALTH_PER_ENDURANCE)
		Stat.STAMINA:
			stamina += 1
		Stat.DEXTERITY:
			dexterity += 1
		Stat.INTELLIGENCE:
			intelligence += 1
	stats_changed.emit()

func move_speed() -> float:
	return SPEED + (dexterity - BASE_STAT) * SPEED_PER_DEXTERITY

func attack_cooldown() -> float:
	return maxf(ATTACK_COOLDOWN - (dexterity - BASE_STAT) * COOLDOWN_PER_DEXTERITY, MIN_ATTACK_COOLDOWN)

func _on_died() -> void:
	died.emit()
	queue_free.call_deferred()

# Movement is free 8-directional but the art is drawn for four, so a diagonal
# resolves to whichever cardinal it leans towards.
func _draw() -> void:
	draw_rect(Rect2(-6, -8, 12, 16), Color(0.2, 0.6, 1.0))
	draw_line(Vector2.ZERO, facing * 10.0, Color(1, 1, 0), 2.0)
