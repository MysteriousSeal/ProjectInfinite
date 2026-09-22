extends CanvasLayer

const SPEND_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const STAT_NAMES := ["ENDURANCE", "STAMINA", "DEXTERITY", "INTELLIGENCE"]

# Margins and the column split are fractions of the screen, so the panel keeps
# its proportions whatever resolution the game runs at. Everything inside is
# then placed against the panel's own edges rather than absolute coordinates.
const MARGIN_RATIO := Vector2(0.042, 0.031)
const SPLIT_RATIO := 0.464
const PAD := 14.0

const BAG_COLUMNS := 5
# Sized to hold the 32px item art at full size rather than shrinking it.
const SLOT := 34.0
const SLOT_GAP := 7.0
const GEAR_SLOT := 34.0

# Shown faintly in the empty weapon slot so it reads as the kind of thing it
# takes. There is no armour art yet, so that slot carries its label alone.
const WEAPON_HINT := preload("res://assets/items/sword_iron.png")
const GEAR_LABELS := ["WEAPON", "ARMOUR"]

@onready var sheet: Control = $Sheet

var player: Node
var is_open := false

var _panel: Rect2
var _left: float
var _split: float
var _right: float
var _edge: float

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

func _update_layout() -> void:
	var view := sheet.get_viewport_rect().size
	var margin := Vector2(roundf(view.x * MARGIN_RATIO.x), roundf(view.y * MARGIN_RATIO.y))
	_panel = Rect2(margin, view - margin * 2.0)
	_left = _panel.position.x + PAD
	_split = roundf(_panel.position.x + _panel.size.x * SPLIT_RATIO)
	_right = _split + 16.0
	_edge = _panel.end.x - PAD

func _draw_sheet() -> void:
	if not is_instance_valid(player):
		return
	_update_layout()
	_draw_frame()
	_draw_left()
	_draw_right()

func _draw_frame() -> void:
	UiTheme.panel(sheet, _panel)
	var title_bottom := _panel.position.y + 30.0
	sheet.draw_rect(Rect2(_panel.position.x + 4.0, _panel.position.y + 4.0,
		_panel.size.x - 8.0, 26.0), Color(0.16, 0.18, 0.22, 0.85))
	UiTheme.rule(sheet, _panel.position.x + 4.0, _panel.end.x - 4.0, title_bottom)
	UiTheme.text(sheet, Vector2(_left, _panel.position.y + 9.0), "CHARACTER",
		UiTheme.SIZE_TITLE, UiTheme.ACCENT, true)
	UiTheme.text_right(sheet, _edge, _panel.position.y + 13.0,
		"[I] OR [ESC] TO CLOSE", UiTheme.SIZE_HEAD, UiTheme.DIM)
	sheet.draw_rect(Rect2(_split, title_bottom + 6.0, 1.0,
		_panel.end.y - title_bottom - 16.0), UiTheme.EDGE_DIM)

func _draw_left() -> void:
	var health: Health = player.health
	var top := _panel.position.y
	var column_edge := _split - 18.0

	UiTheme.text(sheet, Vector2(_left, top + 42.0), "LV %d" % player.level,
		UiTheme.SIZE_TITLE, UiTheme.TEXT, true)

	UiTheme.text(sheet, Vector2(_left, top + 68.0), "HEALTH", UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.text_right(sheet, column_edge, top + 68.0,
		"%d / %d" % [health.current, health.max_health], UiTheme.SIZE_BODY, UiTheme.TEXT)
	UiTheme.bar(sheet, Rect2(_left, top + 80.0, column_edge - _left, 9.0),
		float(health.current) / maxf(health.max_health, 1), UiTheme.HP_FILL)

	UiTheme.text(sheet, Vector2(_left, top + 98.0), "EXPERIENCE", UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.text_right(sheet, column_edge, top + 98.0,
		"%d / %d" % [player.xp, player.xp_to_next], UiTheme.SIZE_BODY, UiTheme.TEXT)
	UiTheme.bar(sheet, Rect2(_left, top + 110.0, column_edge - _left, 6.0),
		float(player.xp) / maxf(player.xp_to_next, 1), UiTheme.XP_FILL)

	UiTheme.rule(sheet, _left, column_edge, top + 128.0)
	var spendable: int = player.stat_points
	UiTheme.text(sheet, Vector2(_left, top + 136.0), "ATTRIBUTES", UiTheme.SIZE_HEAD,
		UiTheme.ACCENT)
	if spendable > 0:
		UiTheme.text_right(sheet, column_edge, top + 136.0, "%d TO SPEND" % spendable,
			UiTheme.SIZE_HEAD, UiTheme.ACCENT)

	var values := [player.endurance, player.stamina, player.dexterity, player.intelligence]
	for i in STAT_NAMES.size():
		var row_y := top + 154.0 + i * 18.0
		# Rows alternate a faint wash so the eye tracks across to the value.
		if i % 2 == 0:
			sheet.draw_rect(Rect2(_left - 4.0, row_y - 3.0, column_edge - _left + 8.0, 16.0),
				Color(1, 1, 1, 0.03))
		var key_colour := UiTheme.ACCENT if spendable > 0 else UiTheme.DIM
		UiTheme.text(sheet, Vector2(_left, row_y), "%d" % (i + 1), UiTheme.SIZE_BODY, key_colour)
		UiTheme.text(sheet, Vector2(_left + 14.0, row_y), STAT_NAMES[i], UiTheme.SIZE_BODY,
			UiTheme.TEXT)
		UiTheme.text_right(sheet, column_edge, row_y, "%d" % values[i], UiTheme.SIZE_BODY,
			UiTheme.TEXT)

	# Gold runs along a footer pinned to the bottom edge, under both columns.
	UiTheme.rule(sheet, _left, _edge, _panel.end.y - 28.0)
	UiTheme.text(sheet, Vector2(_left, _panel.end.y - 19.0), "GOLD", UiTheme.SIZE_HEAD,
		UiTheme.DIM)
	UiTheme.text_right(sheet, _edge, _panel.end.y - 19.0, "%d" % player.loot_count,
		UiTheme.SIZE_TITLE, UiTheme.ACCENT)

func _draw_right() -> void:
	var top := _panel.position.y
	UiTheme.text(sheet, Vector2(_right, top + 36.0), "EQUIPMENT", UiTheme.SIZE_HEAD,
		UiTheme.ACCENT)
	UiTheme.rule(sheet, _right, _edge, top + 48.0)
	for i in GEAR_LABELS.size():
		var at := Vector2(_right + i * (GEAR_SLOT + 16.0), top + 56.0)
		UiTheme.slot(sheet, at, GEAR_SLOT)
		if i == 0:
			sheet.draw_texture_rect(WEAPON_HINT, Rect2(at + Vector2(1.0, 1.0),
				Vector2(GEAR_SLOT - 2.0, GEAR_SLOT - 2.0)), false, Color(1, 1, 1, 0.18))
		UiTheme.text(sheet, Vector2(at.x, at.y + GEAR_SLOT + 6.0), GEAR_LABELS[i],
			UiTheme.SIZE_HEAD, UiTheme.DIM)

	var bag: Array = player.bag
	var capacity: int = player.BAG_CAPACITY
	UiTheme.text(sheet, Vector2(_right, top + 112.0), "BAG", UiTheme.SIZE_HEAD, UiTheme.ACCENT)
	UiTheme.text_right(sheet, _edge, top + 112.0, "%d / %d" % [bag.size(), capacity],
		UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.rule(sheet, _right, _edge, top + 124.0)
	for i in capacity:
		var at := Vector2(
			_right + (i % BAG_COLUMNS) * (SLOT + SLOT_GAP),
			top + 132.0 + (i / BAG_COLUMNS) * (SLOT + SLOT_GAP))
		UiTheme.slot(sheet, at, SLOT, i < bag.size())
		if i < bag.size():
			sheet.draw_texture_rect(Items.icon(bag[i]),
				Rect2(at + Vector2(1.0, 1.0), Vector2(SLOT - 2.0, SLOT - 2.0)), false)
