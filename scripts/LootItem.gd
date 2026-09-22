extends Area2D

const VALUE := 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("add_loot"):
		body.add_loot(VALUE)
		queue_free.call_deferred()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.2))
