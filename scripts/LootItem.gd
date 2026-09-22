extends Area2D

const MIN_GOLD := 3
const MAX_GOLD := 12
# Most pouches are coin only; a minority carry a piece of gear, and a few
# carry two, so opening one is worth the stop.
const ONE_ITEM_CHANCE := 0.45
const TWO_ITEM_CHANCE := 0.12

var gold := 0
var items: Array[ItemInstance] = []

func _ready() -> void:
	gold = randi_range(MIN_GOLD, MAX_GOLD)
	var roll := randf()
	if roll < ONE_ITEM_CHANCE:
		items.append(Items.roll())
	if roll < TWO_ITEM_CHANCE:
		items.append(Items.roll())
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("pouch_in_range"):
		body.pouch_in_range(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("pouch_out_of_range"):
		body.pouch_out_of_range(self)

func is_empty() -> bool:
	return gold <= 0 and items.is_empty()

func consume() -> void:
	queue_free.call_deferred()
