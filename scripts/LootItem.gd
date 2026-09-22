extends Area2D

const MIN_GOLD := 3
const MAX_GOLD := 12

var gold := 0

func _ready() -> void:
	gold = randi_range(MIN_GOLD, MAX_GOLD)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("pouch_in_range"):
		body.pouch_in_range(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("pouch_out_of_range"):
		body.pouch_out_of_range(self)

func open() -> int:
	queue_free.call_deferred()
	return gold

func _draw() -> void:
	draw_circle(Vector2(0, 2), 5.0, Color(0.55, 0.36, 0.17))
	draw_rect(Rect2(-2.0, -5.0, 4.0, 4.0), Color(0.33, 0.21, 0.10))
