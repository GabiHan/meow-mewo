# A person drawn as a layered paper doll (looks.gd): one Sprite2D per layer, back to front, tinted.
# The origin is between the feet; scale it with Looks.WORLD_SCALE in the world. Used by npc.gd, the key art,
# the HUD passport and the character creator (creator.gd). show_look() only rebuilds when the look changed.
extends Node2D

const Looks = preload("res://scripts/looks.gd")

var shown := {}
var grown := true  # beards only on grown-ups


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # smooth when it's drawn small


func show_look(look: Dictionary, p_grown := true) -> void:
	if look == shown and p_grown == grown and get_child_count() > 0:
		return
	shown = look.duplicate()
	grown = p_grown
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for part in Looks.PARTS:
		var n := int(look.get(part.key, 0))
		if part.get("grown", false) and not grown:
			continue
		var tex := Looks.texture(part.key, n)
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.name = part.key
		s.texture = tex
		s.centered = false
		s.position = Looks.offset(part.key, n)
		s.modulate = Looks.tint(look, part)
		add_child(s)
