extends CharacterBody2D

const SPEED := 90.0
const ATTACK_DURATION := 0.18
const ATTACK_COOLDOWN := 0.3
# Damage with bare hands; an equipped weapon adds its own attack on top.
const ATTACK_DAMAGE := 10
const HITBOX_OFFSET := 12.0
const XP_FOR_FIRST_LEVEL := 20
const MIN_ATTACK_COOLDOWN := 0.12
const BAG_CAPACITY := 20

enum Stat { ENDURANCE, STAMINA, DEXTERITY, INTELLIGENCE }

const BASE_STAT := 5
const HEALTH_PER_ENDURANCE := 10
const SPEED_PER_DEXTERITY := 4.0
const COOLDOWN_PER_DEXTERITY := 0.01

# Ordered clockwise from east so a heading maps onto a slot by angle.
const DIRECTIONS := ["east", "south", "west", "north"]
const SPRITE_PATH := "res://assets/hero/hero_%s.png"
# The feet sit ten pixels below the canvas centre, so the sprite is raised
# until they meet the bottom edge of the collision box.
const SPRITE_LIFT := -2

@onready var health: Health = $Health
@onready var sprite: Sprite2D = $Sprite
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
var bag: Array[ItemInstance] = []
var equipped: ItemInstance = null
var _attack_key_was_down := false
var _open_key_was_down := false

signal died
signal loot_changed(count: int)
signal bag_changed
signal equipment_changed
signal pouch_opened(pouch: Node)
signal xp_changed(xp: int, xp_to_next: int)
signal leveled_up(level: int)
signal stats_changed

func _ready() -> void:
	add_to_group("player")
	sprite.offset = Vector2(0, SPRITE_LIFT)
	_face_sprite()
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
	_face_sprite()

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
	if dir.x != 0.0 and dir.y != 0.0:
		# Holding two directions keeps whichever axis is already being
		# travelled, so cornering does not judder between the two.
		if absf(facing.y) > absf(facing.x):
			dir.x = 0.0
		else:
			dir.y = 0.0
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
	# The pouch is left where it is and stays in range; the window that opens
	# decides what is taken and whether anything is left behind.
	pouch_opened.emit(nearby_pouches[0])

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
		body.take_hit(attack_damage(), facing)

func take_hit(amount: int, _from_dir: Vector2) -> void:
	health.take_damage(amount)

func add_loot(amount: int) -> void:
	loot_count += amount
	loot_changed.emit(loot_count)

func bag_is_full() -> bool:
	return bag.size() >= BAG_CAPACITY

func add_item(item: ItemInstance) -> bool:
	if bag_is_full():
		return false
	bag.append(item)
	bag_changed.emit()
	return true

# Equipping swaps: what was held goes back to the slot the new item came from,
# so the bag never grows or shrinks and the swap cannot fail on a full bag.
func equip(slot: int) -> bool:
	if slot < 0 or slot >= bag.size():
		return false
	var taken: ItemInstance = bag[slot]
	if equipped == null:
		bag.remove_at(slot)
	else:
		bag[slot] = equipped
	equipped = taken
	_apply_equipment()
	return true

func unequip() -> bool:
	if equipped == null or bag_is_full():
		return false
	bag.append(equipped)
	equipped = null
	_apply_equipment()
	return true

func _apply_equipment() -> void:
	health.set_bonus_max(attribute_bonus(Stat.ENDURANCE) * HEALTH_PER_ENDURANCE)
	bag_changed.emit()
	equipment_changed.emit()
	stats_changed.emit()

# What the equipped item adds to one attribute, if anything.
func attribute_bonus(stat: Stat) -> int:
	if equipped == null or not equipped.has_attribute() or equipped.attribute != stat:
		return 0
	return equipped.attribute_bonus

func base_attribute(stat: Stat) -> int:
	match stat:
		Stat.ENDURANCE:
			return endurance
		Stat.STAMINA:
			return stamina
		Stat.DEXTERITY:
			return dexterity
		_:
			return intelligence

func effective_attribute(stat: Stat) -> int:
	return base_attribute(stat) + attribute_bonus(stat)

func attack_damage() -> int:
	return ATTACK_DAMAGE + (equipped.attack if equipped != null else 0)

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
	return SPEED + (effective_attribute(Stat.DEXTERITY) - BASE_STAT) * SPEED_PER_DEXTERITY

func attack_cooldown() -> float:
	var dex := effective_attribute(Stat.DEXTERITY)
	var cooldown := ATTACK_COOLDOWN - (dex - BASE_STAT) * COOLDOWN_PER_DEXTERITY
	# A weapon's speed is a share off whatever the attributes already earned,
	# so it stays worth the same proportion at every level.
	if equipped != null:
		cooldown *= 1.0 - equipped.speed / 100.0
	return maxf(cooldown, MIN_ATTACK_COOLDOWN)

func _on_died() -> void:
	died.emit()
	queue_free.call_deferred()

func _face_sprite() -> void:
	var slot := posmod(roundi(facing.angle() / (TAU / DIRECTIONS.size())), DIRECTIONS.size())
	sprite.texture = load(SPRITE_PATH % DIRECTIONS[slot])
