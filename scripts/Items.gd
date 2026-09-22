class_name Items
extends RefCounted

# The catalogue of item kinds. An item that exists in the world is an
# ItemInstance pointing back at one of these by index.
#
# Ordered weakest to strongest: the index doubles as the tier a drop rolls its
# numbers from, so a blacksteel sword beats an iron one however each rolls.
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

# Indices match Player.Stat, so an item's attribute can be spent straight
# against the player's own attributes.
const ATTRIBUTE_NAMES := ["ENDURANCE", "STAMINA", "DEXTERITY", "INTELLIGENCE"]
const ATTRIBUTE_SHORT := ["END", "STA", "DEX", "INT"]

# Attack climbs with the tier, and the spread is wide enough that a good roll
# on one tier overlaps the next, so a drop is worth reading rather than being
# settled by its name alone.
const ATTACK_BASE := 3
const ATTACK_PER_TIER := 2
const ATTACK_SPREAD := 1
const SPEED_BASE := 2
const ATTRIBUTE_CHANCE := 0.55
const ATTRIBUTE_BONUS_BASE := 1

static func count() -> int:
	return CATALOG.size()

static func random_index() -> int:
	return randi() % CATALOG.size()

static func item_name(index: int) -> String:
	return CATALOG[index]["name"]

static func icon(index: int) -> Texture2D:
	return CATALOG[index]["icon"]

# Rolls one physical item of the given kind, or of a random kind.
static func roll(type := -1) -> ItemInstance:
	var item := ItemInstance.new()
	item.type = random_index() if type < 0 else type
	var tier := item.type
	item.attack = maxi(ATTACK_BASE + tier * ATTACK_PER_TIER
		+ randi_range(-ATTACK_SPREAD, ATTACK_SPREAD), 1)
	item.speed = randi_range(0, SPEED_BASE + tier / 2)
	if randf() < ATTRIBUTE_CHANCE:
		item.attribute = randi() % ATTRIBUTE_NAMES.size()
		item.attribute_bonus = randi_range(ATTRIBUTE_BONUS_BASE, ATTRIBUTE_BONUS_BASE + tier / 4)
	return item
