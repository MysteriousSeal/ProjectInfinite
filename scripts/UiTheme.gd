class_name UiTheme
extends RefCounted

# Shared look for every panel in the game, so a second window cannot drift
# away from the first.

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Silkscreen-Bold.ttf")
const SIZE_TITLE := 16
const SIZE_HEAD := 8
const SIZE_BODY := 8

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

# Text is drawn rather than placed in Labels so every baseline lands on an
# exact pixel. Positions are given as the top-left of the line.
static func text(ci: CanvasItem, at: Vector2, value: String, size: int, colour: Color, bold := false) -> void:
	var font: Font = FONT_BOLD if bold else FONT
	ci.draw_string(font, at + Vector2(0.0, font.get_ascent(size)), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)

static func text_right(ci: CanvasItem, right_edge: float, at_y: float, value: String,
		size: int, colour: Color, bold := false) -> void:
	var font: Font = FONT_BOLD if bold else FONT
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(right_edge - width, at_y), value, size, colour, bold)

static func text_width(value: String, size: int) -> float:
	return FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

static func rule(ci: CanvasItem, from_x: float, to_x: float, at_y: float) -> void:
	ci.draw_rect(Rect2(from_x, at_y, to_x - from_x, 1.0), EDGE_DIM)

# Banded vertical gradient with a double border; a flat fill this size reads
# as dead space.
static func panel(ci: CanvasItem, rect: Rect2) -> void:
	var bands := 12
	for i in bands:
		var t := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * i / bands,
			rect.size.x, rect.size.y / bands + 1.0), BG_TOP.lerp(BG_BOTTOM, t))
	ci.draw_rect(rect, EDGE, false, 2.0)
	ci.draw_rect(rect.grow(-4.0), EDGE_DIM, false, 1.0)
	var arm := 10.0
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end]:
		var left := corner.x == rect.position.x
		var top := corner.y == rect.position.y
		ci.draw_rect(Rect2(corner.x + (0.0 if left else -arm),
			corner.y + (0.0 if top else -2.0), arm, 2.0), ACCENT)
		ci.draw_rect(Rect2(corner.x + (0.0 if left else -2.0),
			corner.y + (0.0 if top else -arm), 2.0, arm), ACCENT)

# A lit top-left and shaded bottom-right edge press the slot into the panel.
static func slot(ci: CanvasItem, at: Vector2, size: float, highlight := false) -> void:
	var box := Rect2(at, Vector2(size, size))
	ci.draw_rect(box, SLOT_BG)
	ci.draw_rect(Rect2(box.position, Vector2(size, 1.0)), SLOT_SHADE)
	ci.draw_rect(Rect2(box.position, Vector2(1.0, size)), SLOT_SHADE)
	ci.draw_rect(Rect2(box.position + Vector2(0.0, size - 1.0), Vector2(size, 1.0)), SLOT_LIT)
	ci.draw_rect(Rect2(box.position + Vector2(size - 1.0, 0.0), Vector2(1.0, size)), SLOT_LIT)
	if highlight:
		ci.draw_rect(box, ACCENT, false, 1.0)

static func bar(ci: CanvasItem, at: Rect2, ratio: float, fill: Color) -> void:
	ci.draw_rect(at, Color(0.15, 0.16, 0.18))
	var width := roundf(at.size.x * clampf(ratio, 0.0, 1.0))
	if width >= 1.0:
		ci.draw_rect(Rect2(at.position, Vector2(width, at.size.y)), fill)
		ci.draw_rect(Rect2(at.position, Vector2(width, 1.0)), fill.lightened(0.35))
	ci.draw_rect(at, EDGE_DIM, false, 1.0)
