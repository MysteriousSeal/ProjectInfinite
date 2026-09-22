extends CanvasLayer

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Silkscreen-Bold.ttf")
const SIZE_TITLE := 16
const SIZE_HEAD := 8
const SIZE_BODY := 8

const SPEND_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const STAT_NAMES := ["ENDURANCE", "STAMINA", "DEXTERITY", "INTELLIGENCE"]

const PANEL := Rect2(20, 10, 440, 300)
const SPLIT := 224.0
const LEFT := 34.0
const RIGHT := 240.0

const BAG_SLOTS := 20
const BAG_COLUMNS := 5
# Sized to hold the 32px item art at full size rather than shrinking it, which
# also lets the grid fill its column instead of hugging the left edge.
const SLOT := 34.0
const SLOT_GAP := 7.0
const GEAR_SLOT := 34.0

const BG_TOP := Color(0.11, 0.13, 0.16)
const BG_BOTTOM := Color(0.05, 0.06, 0.08)
const EDGE := Color(0.85, 0.78, 0.55)
const EDGE_DIM := Color(0.34, 0.31, 0.22)
const ACCENT := Color(0.98, 0.84, 0.36)
const TEXT := Color(0.90, 0.91, 0.86)
const DIM := Color(0.52, 0.55, 0.58)
const SLOT_BG := Color(0.13, 0.14, 0.17)
const SLOT_LIT := Color(0.30, 0.33, 0.38)
const SLOT_SHADE := Color(0.04, 0.04, 0.06)
const HP_FILL := Color(0.42, 0.80, 0.35)
const XP_FILL := Color(0.36, 0.66, 0.95)

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

# Text is drawn rather than placed in Labels so every baseline can be put
# exactly where the layout wants it.
func _text(at: Vector2, value: String, size: int, colour: Color, bold := false) -> void:
	var font: Font = FONT_BOLD if bold else FONT
	sheet.draw_string(font, at + Vector2(0.0, font.get_ascent(size)), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

func _text_right(right_edge: float, at_y: float, value: String, size: int, colour: Color) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(right_edge - width, at_y), value, size, colour)

func _rule(from_x: float, to_x: float, at_y: float) -> void:
	sheet.draw_rect(Rect2(from_x, at_y, to_x - from_x, 1.0), EDGE_DIM)

# A lit top-left and shaded bottom-right edge press the slot into the panel.
func _slot(at: Vector2, size: float) -> void:
	var box := Rect2(at, Vector2(size, size))
	sheet.draw_rect(box, SLOT_BG)
	sheet.draw_rect(Rect2(box.position, Vector2(size, 1.0)), SLOT_SHADE)
	sheet.draw_rect(Rect2(box.position, Vector2(1.0, size)), SLOT_SHADE)
	sheet.draw_rect(Rect2(box.position + Vector2(0.0, size - 1.0), Vector2(size, 1.0)), SLOT_LIT)
	sheet.draw_rect(Rect2(box.position + Vector2(size - 1.0, 0.0), Vector2(1.0, size)), SLOT_LIT)

func _bar(at: Rect2, ratio: float, fill: Color) -> void:
	sheet.draw_rect(at, Color(0.15, 0.16, 0.18))
	var width := roundf(at.size.x * clampf(ratio, 0.0, 1.0))
	if width >= 1.0:
		sheet.draw_rect(Rect2(at.position, Vector2(width, at.size.y)), fill)
		sheet.draw_rect(Rect2(at.position, Vector2(width, 1.0)), fill.lightened(0.35))
	sheet.draw_rect(at, EDGE_DIM, false, 1.0)

func _draw_sheet() -> void:
	if not is_instance_valid(player):
		return
	_draw_frame()
	_draw_left()
	_draw_right()

func _draw_frame() -> void:
	# Banded vertical gradient; a flat fill this large looks like dead space.
	var bands := 12
	for i in bands:
		var t := float(i) / float(bands - 1)
		sheet.draw_rect(Rect2(PANEL.position.x, PANEL.position.y + PANEL.size.y * i / bands,
			PANEL.size.x, PANEL.size.y / bands + 1.0), BG_TOP.lerp(BG_BOTTOM, t))
	sheet.draw_rect(PANEL, EDGE, false, 2.0)
	sheet.draw_rect(PANEL.grow(-4.0), EDGE_DIM, false, 1.0)
	_draw_corners()
	# Title bar
	var title_bottom := PANEL.position.y + 30.0
	sheet.draw_rect(Rect2(PANEL.position.x + 4.0, PANEL.position.y + 4.0,
		PANEL.size.x - 8.0, 26.0), Color(0.16, 0.18, 0.22, 0.85))
	_rule(PANEL.position.x + 4.0, PANEL.end.x - 4.0, title_bottom)
	_text(Vector2(LEFT, PANEL.position.y + 9.0), "CHARACTER", SIZE_TITLE, ACCENT, true)
	_text_right(PANEL.end.x - 14.0, PANEL.position.y + 13.0, "[I] OR [ESC] TO CLOSE", SIZE_HEAD, DIM)
	# Column divider
	sheet.draw_rect(Rect2(SPLIT, title_bottom + 6.0, 1.0, PANEL.end.y - title_bottom - 16.0), EDGE_DIM)

func _draw_corners() -> void:
	var arm := 10.0
	for corner in [Vector2(PANEL.position.x, PANEL.position.y), Vector2(PANEL.end.x, PANEL.position.y),
			Vector2(PANEL.position.x, PANEL.end.y), Vector2(PANEL.end.x, PANEL.end.y)]:
		var dx := 1.0 if corner.x == PANEL.position.x else -1.0
		var dy := 1.0 if corner.y == PANEL.position.y else -1.0
		sheet.draw_rect(Rect2(corner.x + (0.0 if dx > 0.0 else -arm), corner.y + (0.0 if dy > 0.0 else -2.0),
			arm, 2.0), ACCENT)
		sheet.draw_rect(Rect2(corner.x + (0.0 if dx > 0.0 else -2.0), corner.y + (0.0 if dy > 0.0 else -arm),
			2.0, arm), ACCENT)

func _draw_left() -> void:
	var health: Health = player.health
	_text(Vector2(LEFT, 52.0), "LV %d" % player.level, SIZE_TITLE, TEXT, true)

	_text(Vector2(LEFT, 78.0), "HEALTH", SIZE_HEAD, DIM)
	_text_right(SPLIT - 18.0, 78.0, "%d / %d" % [health.current, health.max_health], SIZE_BODY, TEXT)
	_bar(Rect2(LEFT, 90.0, SPLIT - LEFT - 18.0, 9.0),
		float(health.current) / maxf(health.max_health, 1), HP_FILL)

	_text(Vector2(LEFT, 108.0), "EXPERIENCE", SIZE_HEAD, DIM)
	_text_right(SPLIT - 18.0, 108.0, "%d / %d" % [player.xp, player.xp_to_next], SIZE_BODY, TEXT)
	_bar(Rect2(LEFT, 120.0, SPLIT - LEFT - 18.0, 6.0),
		float(player.xp) / maxf(player.xp_to_next, 1), XP_FILL)

	_rule(LEFT, SPLIT - 18.0, 138.0)
	var spendable: int = player.stat_points
	_text(Vector2(LEFT, 146.0), "ATTRIBUTES", SIZE_HEAD, ACCENT)
	if spendable > 0:
		_text_right(SPLIT - 18.0, 146.0, "%d TO SPEND" % spendable, SIZE_HEAD, ACCENT)

	var values := [player.endurance, player.stamina, player.dexterity, player.intelligence]
	for i in STAT_NAMES.size():
		var row_y := 164.0 + i * 18.0
		# Rows alternate a faint wash so the eye tracks across to the value.
		if i % 2 == 0:
			sheet.draw_rect(Rect2(LEFT - 4.0, row_y - 3.0, SPLIT - LEFT - 12.0, 16.0),
				Color(1, 1, 1, 0.03))
		var key_colour := ACCENT if spendable > 0 else DIM
		_text(Vector2(LEFT, row_y), "%d" % (i + 1), SIZE_BODY, key_colour)
		_text(Vector2(LEFT + 14.0, row_y), STAT_NAMES[i], SIZE_BODY, TEXT)
		_text_right(SPLIT - 18.0, row_y, "%d" % values[i], SIZE_BODY, TEXT)

	# Gold sits in a footer across both columns; on the left alone it left the
	# bottom third of the panel empty.
	_rule(LEFT, PANEL.end.x - 14.0, 282.0)
	_text(Vector2(LEFT, 291.0), "GOLD", SIZE_HEAD, DIM)
	_text_right(PANEL.end.x - 14.0, 291.0, "%d" % player.loot_count, SIZE_TITLE, ACCENT)

func _draw_right() -> void:
	_text(Vector2(RIGHT, 46.0), "EQUIPMENT", SIZE_HEAD, ACCENT)
	_rule(RIGHT, PANEL.end.x - 14.0, 58.0)
	for i in GEAR_HINTS.size():
		var at := Vector2(RIGHT + i * (GEAR_SLOT + 16.0), 66.0)
		_slot(at, GEAR_SLOT)
		sheet.draw_texture_rect(GEAR_HINTS[i], Rect2(at + Vector2(1.0, 1.0),
			Vector2(GEAR_SLOT - 2.0, GEAR_SLOT - 2.0)), false, Color(1, 1, 1, 0.18))
		_text(Vector2(at.x, at.y + GEAR_SLOT + 6.0), GEAR_LABELS[i], SIZE_HEAD, DIM)

	_text(Vector2(RIGHT, 122.0), "BAG", SIZE_HEAD, ACCENT)
	_text_right(PANEL.end.x - 14.0, 122.0, "0 / %d" % BAG_SLOTS, SIZE_HEAD, DIM)
	_rule(RIGHT, PANEL.end.x - 14.0, 134.0)
	for i in BAG_SLOTS:
		_slot(Vector2(
			RIGHT + (i % BAG_COLUMNS) * (SLOT + SLOT_GAP),
			142.0 + (i / BAG_COLUMNS) * (SLOT + SLOT_GAP)), SLOT)
