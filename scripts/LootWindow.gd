extends CanvasLayer

# A dialog rather than a full screen panel: it keeps a fixed size and is
# centred, so its text stays the same physical size at any resolution.
const PANEL_SIZE := Vector2(248, 196)
const PAD := 16.0
const SLOT := 34.0
# One row per item: the icon on the left, its name and rolled numbers beside it,
# because two identical-looking swords can now carry very different stats.
const ROW_HEIGHT := 40.0
const TAKE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

@onready var window: Control = $Window

var player: Node
var pouch: Node
var is_open := false

var _close_was_down := false
var _take_all_was_down := false
var _take_was_down := [false, false, false, false]

func _ready() -> void:
	window.draw.connect(_draw_window)
	window.visible = false

func bind(target: Node) -> void:
	player = target
	player.pouch_opened.connect(_open)

func _open(from: Node) -> void:
	# Another menu already owns the pause, so stay out of its way.
	if is_open or get_tree().paused:
		return
	pouch = from
	is_open = true
	window.visible = true
	get_tree().paused = true
	_close_was_down = true
	_take_all_was_down = true

func _close() -> void:
	is_open = false
	window.visible = false
	get_tree().paused = false
	pouch = null

func _process(_delta: float) -> void:
	if not is_open:
		return
	if not is_instance_valid(pouch) or not is_instance_valid(player):
		_close()
		return
	_poll_input()
	window.queue_redraw()

func _poll_input() -> void:
	var close_down := Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_I)
	if close_down and not _close_was_down:
		_close()
		return
	_close_was_down = close_down

	var take_down := Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_ENTER)
	if take_down and not _take_all_was_down:
		_take_all()
		return
	_take_all_was_down = take_down

	for i in TAKE_KEYS.size():
		var down := Input.is_physical_key_pressed(TAKE_KEYS[i])
		if down and not _take_was_down[i] and i < pouch.items.size():
			_take_item(i)
		_take_was_down[i] = down

func _take_item(slot: int) -> void:
	if player.add_item(pouch.items[slot]):
		pouch.items.remove_at(slot)
		_close_if_emptied()

func _take_all() -> void:
	if pouch.gold > 0:
		player.add_loot(pouch.gold)
		pouch.gold = 0
	# Walks backwards so removing a taken item cannot skip the next one.
	for i in range(pouch.items.size() - 1, -1, -1):
		if player.add_item(pouch.items[i]):
			pouch.items.remove_at(i)
	_close_if_emptied()

func _close_if_emptied() -> void:
	if pouch.is_empty():
		pouch.consume()
		_close()

func _draw_window() -> void:
	if not is_instance_valid(pouch) or not is_instance_valid(player):
		return
	var view := window.get_viewport_rect().size
	var panel := Rect2(((view - PANEL_SIZE) * 0.5).round(), PANEL_SIZE)
	UiTheme.panel(window, panel)
	var left := panel.position.x + PAD
	var right := panel.end.x - PAD

	window.draw_rect(Rect2(panel.position.x + 4.0, panel.position.y + 4.0,
		panel.size.x - 8.0, 24.0), Color(0.16, 0.18, 0.22, 0.85))
	UiTheme.rule(window, panel.position.x + 4.0, panel.end.x - 4.0, panel.position.y + 28.0)
	UiTheme.text(window, Vector2(left, panel.position.y + 9.0), "POUCH", UiTheme.SIZE_TITLE,
		UiTheme.ACCENT, true)

	var y := panel.position.y + 40.0
	UiTheme.text(window, Vector2(left, y), "GOLD", UiTheme.SIZE_HEAD, UiTheme.DIM)
	UiTheme.text_right(window, right, y - 4.0, "%d" % pouch.gold, UiTheme.SIZE_TITLE,
		UiTheme.ACCENT if pouch.gold > 0 else UiTheme.DIM)

	y += 22.0
	UiTheme.rule(window, left, right, y)
	y += 8.0
	UiTheme.text(window, Vector2(left, y), "ITEMS", UiTheme.SIZE_HEAD, UiTheme.DIM)
	y += 14.0
	if pouch.items.is_empty():
		UiTheme.text(window, Vector2(left, y + 10.0), "NOTHING ELSE INSIDE", UiTheme.SIZE_BODY,
			UiTheme.DIM)
	for i in pouch.items.size():
		var item: ItemInstance = pouch.items[i]
		var at := Vector2(left, y + i * ROW_HEIGHT)
		UiTheme.slot(window, at, SLOT)
		window.draw_texture_rect(item.icon(),
			Rect2(at + Vector2(1.0, 1.0), Vector2(SLOT - 2.0, SLOT - 2.0)), false)
		var text_x := at.x + SLOT + 8.0
		UiTheme.text(window, Vector2(text_x, at.y + 2.0), "%d" % (i + 1), UiTheme.SIZE_HEAD,
			UiTheme.ACCENT)
		UiTheme.text(window, Vector2(text_x + 12.0, at.y + 2.0), item.item_name(),
			UiTheme.SIZE_BODY, UiTheme.TEXT)
		UiTheme.text(window, Vector2(text_x + 12.0, at.y + 16.0), item.summary(),
			UiTheme.SIZE_HEAD, UiTheme.DIM)

	var hint_y := panel.end.y - 30.0
	UiTheme.rule(window, left, right, hint_y - 8.0)
	if player.bag_is_full() and not pouch.items.is_empty():
		UiTheme.text(window, Vector2(left, hint_y), "BAG FULL", UiTheme.SIZE_HEAD, UiTheme.ACCENT)
	else:
		UiTheme.text(window, Vector2(left, hint_y), "[E] TAKE ALL", UiTheme.SIZE_HEAD, UiTheme.TEXT)
	UiTheme.text_right(window, right, hint_y, "[ESC] LEAVE", UiTheme.SIZE_HEAD, UiTheme.DIM)
