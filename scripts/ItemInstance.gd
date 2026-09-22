class_name ItemInstance
extends Resource

# One physical item, as opposed to Items.CATALOG which describes a kind of
# item. Two swords of the same kind roll different numbers, so what a bag or a
# pouch holds has to be an instance rather than a catalogue index.
var type := 0
var attack := 0
# Whole percent shaved off the attack cooldown.
var speed := 0
# Index into Items.ATTRIBUTE_NAMES, or NO_ATTRIBUTE when the roll granted none.
var attribute := NO_ATTRIBUTE
var attribute_bonus := 0

const NO_ATTRIBUTE := -1

func item_name() -> String:
	return Items.item_name(type)

func icon() -> Texture2D:
	return Items.icon(type)

func has_attribute() -> bool:
	return attribute != NO_ATTRIBUTE and attribute_bonus != 0

# "ATK 9  SPD +2%  DEX +1", for the single line the pouch has room for. Zero
# rolls are dropped rather than printed, so a plain sword reads as plain.
func summary() -> String:
	var parts := PackedStringArray(["ATK %d" % attack])
	if speed > 0:
		parts.append("SPD +%d%%" % speed)
	if has_attribute():
		parts.append("%s +%d" % [Items.ATTRIBUTE_SHORT[attribute], attribute_bonus])
	return "  ".join(parts)

# The same numbers as rows of (label, value), for the character sheet where
# there is room to lay them out in a column.
func detail_rows() -> Array:
	var rows := [PackedStringArray(["ATTACK", "%d" % attack])]
	if speed > 0:
		rows.append(PackedStringArray(["SPEED", "+%d%%" % speed]))
	if has_attribute():
		rows.append(PackedStringArray([Items.ATTRIBUTE_NAMES[attribute],
			"+%d" % attribute_bonus]))
	return rows
