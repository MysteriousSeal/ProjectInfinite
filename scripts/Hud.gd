extends CanvasLayer

const PANEL := Rect2(8, 6, 160, 48)
const PAD := 8.0
const HEALTH_BAR := Rect2(16, 30, 96, 9)
const XP_BAR := Rect2(16, 42, 144, 5)
const PROMPT_UP := 34.0

# Health shifts colour as it drops, so the bar reads at a glance without
# having to look at the numbers.
const HEALTH_STEPS := [
	{"above": 0.5, "fill": UiTheme.HP_FILL},
	{"above": 0.25, "fill": Color(0.93, 0.75, 0.25)},
	{"above": -1.0, "fill": Color(0.87, 0.30, 0.26)},
]

@onready var frame: Control = $Frame

var player: Node

func _ready() -> void:
	frame.draw.connect(_draw_frame)

func _process(_delta: float) -> void:
	frame.queue_redraw()

func bind(target: Node) -> void:
	player = target

func _draw_frame() -> void:
	if not is_instance_valid(player):
		return
	var left := PANEL.position.x + PAD
	var right := PANEL.end.x - PAD

	# Opaque: at any transparency a bright roof or lake behind the HUD showed
	# through and fought with the bars.
	_gradient(PANEL)
	frame.draw_rect(PANEL, UiTheme.EDGE, false, 1.0)

	UiTheme.text(frame, Vector2(left, PANEL.position.y + 4.0), "LV %d" % player.level,
		UiTheme.SIZE_TITLE, UiTheme.TEXT, true)
	UiTheme.text_right(frame, right, PANEL.position.y + 8.0, "%d G" % player.loot_count,
		UiTheme.SIZE_HEAD, UiTheme.ACCENT)

	var health: Health = player.health
	var ratio := float(health.current) / maxf(health.max_health, 1)
	var fill: Color = HEALTH_STEPS[0]["fill"]
	for step: Dictionary in HEALTH_STEPS:
		if ratio > step["above"]:
			fill = step["fill"]
			break
	UiTheme.bar(frame, HEALTH_BAR, ratio, fill)
	UiTheme.text_right(frame, right, HEALTH_BAR.position.y + 1.0,
		"%d/%d" % [health.current, health.max_health], UiTheme.SIZE_HEAD, UiTheme.TEXT)
	UiTheme.bar(frame, XP_BAR, float(player.xp) / maxf(player.xp_to_next, 1), UiTheme.XP_FILL)

	_draw_prompt()

func _draw_prompt() -> void:
	# Hidden while a window is up: the pouch stays in range the whole time it
	# is open, so the prompt would sit on top of its own window.
	if player.nearby_pouches.is_empty() or get_tree().paused:
		return
	var view := frame.get_viewport_rect().size
	var label := "PRESS E TO OPEN"
	var width := UiTheme.text_width(label, UiTheme.SIZE_HEAD)
	var at := Vector2(roundf((view.x - width) * 0.5), view.y - PROMPT_UP)
	var box := Rect2(at - Vector2(6.0, 4.0), Vector2(width + 12.0, 18.0))
	_gradient(box)
	frame.draw_rect(box, UiTheme.EDGE_DIM, false, 1.0)
	UiTheme.text(frame, at, label, UiTheme.SIZE_HEAD, UiTheme.TEXT)

func _gradient(rect: Rect2) -> void:
	var bands := 6
	for i in bands:
		var t := float(i) / float(bands - 1)
		frame.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * i / bands,
			rect.size.x, rect.size.y / bands + 1.0), UiTheme.BG_TOP.lerp(UiTheme.BG_BOTTOM, t))
