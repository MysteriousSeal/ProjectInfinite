class_name Items
extends RefCounted

# The catalogue every item index refers to. Bags and pouches store indices
# into this, so an item is a single int wherever it travels.
# Every icon is 16x16, so the UI can upscale them all by the same whole factor
# and keep the pixel grid of the rest of the art.
const CATALOG := [
	{"name": "IRON SWORD", "icon": preload("res://assets/items/sword_iron.png")},
	{"name": "STEEL SWORD", "icon": preload("res://assets/items/sword_steel.png")},
	{"name": "SILVER SWORD", "icon": preload("res://assets/items/sword_silver.png")},
	{"name": "JADE SWORD", "icon": preload("res://assets/items/sword_jade.png")},
	{"name": "EMERALD SWORD", "icon": preload("res://assets/items/sword_emerald.png")},
	{"name": "GILDED SWORD", "icon": preload("res://assets/items/sword_gilded.png")},
	{"name": "SHADOW SWORD", "icon": preload("res://assets/items/sword_shadow.png")},
	{"name": "OBSIDIAN SWORD", "icon": preload("res://assets/items/sword_obsidian.png")},
	{"name": "BLACKSTEEL SWORD", "icon": preload("res://assets/items/sword_blacksteel.png")},
]

static func count() -> int:
	return CATALOG.size()

static func random_index() -> int:
	return randi() % CATALOG.size()

static func item_name(index: int) -> String:
	return CATALOG[index]["name"]

static func icon(index: int) -> Texture2D:
	return CATALOG[index]["icon"]
