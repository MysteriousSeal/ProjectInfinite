extends CanvasLayer

const BAG_SLOTS := 20
const BAG_COLUMNS := 5
const SLOT_SIZE := Vector2(18, 18)
const SPEND_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

@onready var panel: Panel = $Panel
@onready var names_label: Label = $Panel/Margin/Rows/StatRows/Names
@onready var values_label: Label = $Panel/Margin/Rows/StatRows/Values
@onready var grid: GridContainer = $Panel/Margin/Rows/Bag

var player: Node
var is_open := false

var _toggle_was_down := false
var _spend_was_down := [false, false, false, false]

func _ready() -> void:
	grid.columns = BAG_COLUMNS
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.16, 0.18, 0.16)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.45, 0.45, 0.38)
	for i in BAG_SLOTS:
		var slot := Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.add_theme_stylebox_override("panel", slot_style)
		grid.add_child(slot)
	panel.visible = false

func bind(target: Node) -> void:
	player = target

func _process(_delta: float) -> void:
	_poll_toggle()
	if is_open:
		_poll_spend()
		_refresh()

func _poll_toggle() -> void:
	var down := Input.is_physical_key_pressed(KEY_I)
	if is_open and Input.is_physical_key_pressed(KEY_ESCAPE):
		down = true
	if down and not _toggle_was_down:
		_set_open(not is_open)
	_toggle_was_down = down

func _set_open(open: bool) -> void:
	is_open = open
	panel.visible = open
	get_tree().paused = open

func _poll_spend() -> void:
	if not is_instance_valid(player):
		return
	for i in SPEND_KEYS.size():
		var key: int = SPEND_KEYS[i]
		var down := Input.is_physical_key_pressed(key)
		if down and not _spend_was_down[i]:
			player.spend_stat_point(i)
		_spend_was_down[i] = down

func _refresh() -> void:
	if not is_instance_valid(player):
		return
	names_label.text = "\n".join([
		"Level", "XP", "HP",
		"[1] Endurance", "[2] Stamina", "[3] Dexterity", "[4] Intelligence",
		"Points to spend", "Gold",
	])
	values_label.text = "\n".join([
		str(player.level),
		"%d/%d" % [player.xp, player.xp_to_next],
		"%d/%d" % [player.health.current, player.health.max_health],
		str(player.endurance), str(player.stamina),
		str(player.dexterity), str(player.intelligence),
		str(player.stat_points), str(player.loot_count),
	])
