# The quick-slot row (Cozy Paws "Hotbar"): numbered InventorySlots on a panel. Click selects (selected(index)).
# Not used by the game yet. Number keys 1-4 are game speeds, so a hotbar would need other keys (or the wheel).
#   var h := Hotbar.make([["sprout", 8], ["strawberry", 12], [], []])
extends PanelContainer

signal selected(index: int)

const UiTheme = preload("res://scripts/ui_theme.gd")
const InventorySlot = preload("res://scripts/ui/inventory_slot.gd")

var slots := []
var current := 0


static func make(items: Array, first := 0) -> PanelContainer:
	var h := new()
	h.build(items, first)
	return h


func build(items: Array, first: int) -> void:
	var style := UiTheme.panel()
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in items.size():
		var it: Array = items[i]
		var slot: Button = InventorySlot.make(it[0] if it.size() > 0 else "", it[1] if it.size() > 1 else 1, str(i + 1))
		slot.pressed.connect(func(): select(i))
		row.add_child(slot)
		slots.append(slot)
	select(first, false)


func select(i: int, notify := true) -> void:
	if i < 0 or i >= slots.size():
		return
	slots[current].set_selected(false)
	current = i
	slots[i].set_selected(true)
	if notify:
		selected.emit(i)
