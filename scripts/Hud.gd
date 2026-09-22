extends CanvasLayer

const PANEL := Rect2(8, 6, 156, 46)
# The health numbers sit beside the bar rather than over it; across the fill
# boundary they were unreadable whatever the outline.
const HEALTH_BAR := Rect2(14, 24, 98, 10)
const XP_BAR := Rect2(14, 38, 144, 6)

const PANEL_FILL := Color(0.09, 0.11, 0.13, 0.94)
const PANEL_EDGE := Color(0.85, 0.80, 0.62)
const TRACK := Color(0.15, 0.16, 0.18)

# Health shifts colour as it drops, so the bar reads at a glance without
# having to look at the numbers.
const HEALTH_STEPS := [
	{"above": 0.5, "fill": Color(0.42, 0.80, 0.35), "shine": Color(0.62, 0.93, 0.52)},
	{"above": 0.25, "fill": Color(0.93, 0.75, 0.25), "shine": Color(1.0, 0.89, 0.47)},
	{"above": -1.0, "fill": Color(0.87, 0.30, 0.26), "shine": Color(0.97, 0.50, 0.44)},
]
const XP_FILL := Color(0.36, 0.66, 0.95)
const XP_SHINE := Color(0.58, 0.83, 1.0)

@onready var frame: Control = $Frame
@onready var level_label: Label = $Frame/Level
@onready var health_label: Label = $Frame/Health
@onready var gold_label: Label = $Frame/Gold
@onready var prompt: Label = $Prompt

var player: Node

func _ready() -> void:
	frame.draw.connect(_draw_frame)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Hidden while a window is up: the pouch stays in range the whole time it
	# is open, so the prompt would sit on top of its own window.
	prompt.visible = not player.nearby_pouches.is_empty() and not get_tree().paused

func bind(target: Node) -> void:
	player = target
	player.health.damaged.connect(func(_amount, _current): _refresh())
	player.health.died.connect(_refresh)
	player.loot_changed.connect(func(_count): _refresh())
	player.xp_changed.connect(func(_xp, _next): _refresh())
	player.leveled_up.connect(func(_level): _refresh())
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(player):
		return
	level_label.text = "Lv %d" % player.level
	health_label.text = "%d / %d" % [player.health.current, player.health.max_health]
	gold_label.text = "%d G" % player.loot_count
	frame.queue_redraw()

func _draw_frame() -> void:
	if not is_instance_valid(player):
		return
	frame.draw_rect(PANEL, PANEL_FILL)
	frame.draw_rect(PANEL, PANEL_EDGE, false, 1.0)
	var health: float = float(player.health.current) / maxf(player.health.max_health, 1)
	var step: Dictionary = HEALTH_STEPS[0]
	for candidate: Dictionary in HEALTH_STEPS:
		if health > candidate["above"]:
			step = candidate
			break
	_draw_bar(HEALTH_BAR, health, step["fill"], step["shine"])
	_draw_bar(XP_BAR, float(player.xp) / maxf(player.xp_to_next, 1), XP_FILL, XP_SHINE)

func _draw_bar(bar: Rect2, ratio: float, fill: Color, shine: Color) -> void:
	frame.draw_rect(bar, TRACK)
	var width := roundf(bar.size.x * clampf(ratio, 0.0, 1.0))
	if width >= 1.0:
		frame.draw_rect(Rect2(bar.position, Vector2(width, bar.size.y)), fill)
		# A lit top edge and a shaded bottom one give the fill some round,
		# rather than reading as a flat block at this size.
		frame.draw_rect(Rect2(bar.position, Vector2(width, 1.0)), shine)
		frame.draw_rect(Rect2(bar.position + Vector2(0.0, bar.size.y - 1.0),
			Vector2(width, 1.0)), fill.darkened(0.35))
	frame.draw_rect(bar, PANEL_EDGE.darkened(0.45), false, 1.0)
