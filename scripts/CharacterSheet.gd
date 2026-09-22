extends CanvasLayer

const SPEND_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const STAT_NAMES := ["ENDURANCE", "STAMINA", "DEXTERITY", "INTELLIGENCE"]

const PANEL := Rect2(20, 10, 440, 300)
const SPLIT := 224.0
const LEFT := 34.0
const RIGHT := 240.0

const BAG_COLUMNS := 5
# Sized to hold the 32px item art at full size rather than shrinking it, which
# also lets the grid fill its column instead of hugging the left edge.
const SLOT := 34.0
const SLOT_GAP := 7.0
const GEAR_SLOT := 34.0

# Shown faintly in the empty gear slots so each one reads as the kind of thing
# it takes, rather than as an anonymous hole.
const GEAR_HINTS := [
	preload("res://assets/items/sword.png"),
	preload("res://assets/items/leather.png"),
]
const GEAR_LABELS := ["WEAPON", "ARMOUR"]

@onready var sheet: Control = $Sheet

var player: Node
var is_open := false

var _toggle_was_down := false
var _spend_was_down := [false, false, false, false]

func _ready() -> void:
	sheet.draw.connect(_draw_sheet)
	sheet.visible = false

func bind(target: Node) -> void:
	player = target

func _process(_delta: float) -> void:
	_poll_toggle()
	if is_open:
		_poll_spend()
		sheet.queue_redraw()

func _poll_toggle() -> void:
	var down := Input.is_physical_key_pressed(KEY_I)
	if is_open and Input.is_physical_key_pressed(KEY_ESCAPE):
		down = true
	if down and not _toggle_was_down:
		# Another window already owns the pause, so stay out of its way.
		if is_open or not get_tree().paused:
			_set_open(not is_open)
	_toggle_was_down = down

func _set_open(open: bool) -> void:
	is_open = open
	sheet.visible = open
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

func _draw_sheet() -> void:
	if not is_instance_valid(player):
		return
	_draw_frame()
	_draw_left()
	_draw_right()

func _draw_frame() -> void:
	UiTheme.panel(sheet, PANEL)
	var title_bottom := PANEL.position.y + 30.0
	sheet.draw_rect(Rect2(PANEL.position.x + 4.0, PANEL.position.y + 4.0,
		PANEL.size.x - 8.0, 26.0), Color(0.16, 0.18, 0.22, 0.85))
	UiTheme.rule(sheet, PANEL.position.x + 4.0, PANEL.end.x - 4.0, title_bottom)
	UiTheme.text(sheet, Vector2(LEFT, PANEL.position.y + 9.0), "CHARACTER",
		UiTheme.SIZE_TITLE, UiTheme.ACCENT, true)
	UiTheme.text_right(sheet, PANEL.end.x - 14.0, PANEL.position.y + 13.0,
		"[I] OR [ESC] TO CLOSE", UiTheme.SIZE_HEAD, UiTheme.DIM)
	sheet.draw_rect(Rect2(SPLIT, title_bottom + 6.0, 1.0, PANEL.end.y - title_bottom - 16.0),
		UiTheme.EDGE_DIM)

func _draw_left() -> void:
	var health: Health = player.health
	UiTheme.text(sheet, Vector2(LEFT, 52.0), "LV %d" % player.level, UiTheme.SIZE_TITLE,
		UiTheme.TEXT, true)

	UiTheme.text(sheet, Vector2(LEFT, 78.0), "HEALTH", UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.text_right(sheet, SPLIT - 18.0, 78.0, "%d / %d" % [health.current, health.max_health],
		UiTheme.SIZE_BODY, UiTheme.TEXT)
	UiTheme.bar(sheet, Rect2(LEFT, 90.0, SPLIT - LEFT - 18.0, 9.0),
		float(health.current) / maxf(health.max_health, 1), UiTheme.HP_FILL)

	UiTheme.text(sheet, Vector2(LEFT, 108.0), "EXPERIENCE", UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.text_right(sheet, SPLIT - 18.0, 108.0, "%d / %d" % [player.xp, player.xp_to_next],
		UiTheme.SIZE_BODY, UiTheme.TEXT)
	UiTheme.bar(sheet, Rect2(LEFT, 120.0, SPLIT - LEFT - 18.0, 6.0),
		float(player.xp) / maxf(player.xp_to_next, 1), UiTheme.XP_FILL)

	UiTheme.rule(sheet, LEFT, SPLIT - 18.0, 138.0)
	var spendable: int = player.stat_points
	UiTheme.text(sheet, Vector2(LEFT, 146.0), "ATTRIBUTES", UiTheme.SIZE_HEAD, UiTheme.ACCENT)
	if spendable > 0:
		UiTheme.text_right(sheet, SPLIT - 18.0, 146.0, "%d TO SPEND" % spendable,
			UiTheme.SIZE_HEAD, UiTheme.ACCENT)

	var values := [player.endurance, player.stamina, player.dexterity, player.intelligence]
	for i in STAT_NAMES.size():
		var row_y := 164.0 + i * 18.0
		# Rows alternate a faint wash so the eye tracks across to the value.
		if i % 2 == 0:
			sheet.draw_rect(Rect2(LEFT - 4.0, row_y - 3.0, SPLIT - LEFT - 12.0, 16.0),
				Color(1, 1, 1, 0.03))
		var key_colour := UiTheme.ACCENT if spendable > 0 else UiTheme.DIM
		UiTheme.text(sheet, Vector2(LEFT, row_y), "%d" % (i + 1), UiTheme.SIZE_BODY, key_colour)
		UiTheme.text(sheet, Vector2(LEFT + 14.0, row_y), STAT_NAMES[i], UiTheme.SIZE_BODY,
			UiTheme.TEXT)
		UiTheme.text_right(sheet, SPLIT - 18.0, row_y, "%d" % values[i], UiTheme.SIZE_BODY,
			UiTheme.TEXT)

	# Gold sits in a footer across both columns; on the left alone it left the
	# bottom third of the panel empty.
	UiTheme.rule(sheet, LEFT, PANEL.end.x - 14.0, 282.0)
	UiTheme.text(sheet, Vector2(LEFT, 291.0), "GOLD", UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.text_right(sheet, PANEL.end.x - 14.0, 291.0, "%d" % player.loot_count,
		UiTheme.SIZE_TITLE, UiTheme.ACCENT)

func _draw_right() -> void:
	UiTheme.text(sheet, Vector2(RIGHT, 46.0), "EQUIPMENT", UiTheme.SIZE_HEAD, UiTheme.ACCENT)
	UiTheme.rule(sheet, RIGHT, PANEL.end.x - 14.0, 58.0)
	for i in GEAR_HINTS.size():
		var at := Vector2(RIGHT + i * (GEAR_SLOT + 16.0), 66.0)
		UiTheme.slot(sheet, at, GEAR_SLOT)
		sheet.draw_texture_rect(GEAR_HINTS[i], Rect2(at + Vector2(1.0, 1.0),
			Vector2(GEAR_SLOT - 2.0, GEAR_SLOT - 2.0)), false, Color(1, 1, 1, 0.18))
		UiTheme.text(sheet, Vector2(at.x, at.y + GEAR_SLOT + 6.0), GEAR_LABELS[i],
			UiTheme.SIZE_HEAD, UiTheme.DIM)

	var bag: Array = player.bag
	var capacity: int = player.BAG_CAPACITY
	UiTheme.text(sheet, Vector2(RIGHT, 122.0), "BAG", UiTheme.SIZE_HEAD, UiTheme.ACCENT)
	UiTheme.text_right(sheet, PANEL.end.x - 14.0, 122.0, "%d / %d" % [bag.size(), capacity],
		UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.rule(sheet, RIGHT, PANEL.end.x - 14.0, 134.0)
	for i in capacity:
		var at := Vector2(
			RIGHT + (i % BAG_COLUMNS) * (SLOT + SLOT_GAP),
			142.0 + (i / BAG_COLUMNS) * (SLOT + SLOT_GAP))
		UiTheme.slot(sheet, at, SLOT, i < bag.size())
		if i < bag.size():
			sheet.draw_texture_rect(Items.icon(bag[i]),
				Rect2(at + Vector2(1.0, 1.0), Vector2(SLOT - 2.0, SLOT - 2.0)), false)
