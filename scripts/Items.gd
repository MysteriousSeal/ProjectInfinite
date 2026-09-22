class_name Items
extends RefCounted

# The catalogue every item index refers to. Bags and pouches store indices
# into this, so an item is a single int wherever it travels.
const CATALOG := [
	{"name": "SHORT SWORD", "icon": preload("res://assets/items/sword.png")},
	{"name": "BATTLE AXE", "icon": preload("res://assets/items/axe.png")},
	{"name": "WOODEN SPEAR", "icon": preload("res://assets/items/spear.png")},
	{"name": "LEATHER VEST", "icon": preload("res://assets/items/leather.png")},
	{"name": "CHAINMAIL", "icon": preload("res://assets/items/chain.png")},
	{"name": "IRON PLATE", "icon": preload("res://assets/items/plate.png")},
]

static func count() -> int:
	return CATALOG.size()

static func random_index() -> int:
	return randi() % CATALOG.size()

static func item_name(index: int) -> String:
	return CATALOG[index]["name"]

static func icon(index: int) -> Texture2D:
	return CATALOG[index]["icon"]
