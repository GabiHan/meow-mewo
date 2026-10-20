# Flat floor tiles drawn once: the terrain of a world chunk, or a building's floor.
extends Node2D

const Iso = preload("res://scripts/iso.gd")

var tiles := []  # [Vector2i cell, Color]
var dimmed := false  # when true, only cells in `lit` are drawn at full brightness
var lit := {}


func setup(p_tiles: Array) -> Node2D:
	tiles = p_tiles
	z_index = -2  # always under the sight veil (vision.gd, -1), walls, objects and people
	return self


func set_lit(p_lit: Dictionary, p_dimmed: bool) -> void:
	if p_dimmed == dimmed and (not dimmed or p_lit == lit):
		return
	dimmed = p_dimmed
	lit = p_lit
	queue_redraw()


func _draw() -> void:
	for t in tiles:
		var c := Iso.to_screen(Vector2(t[0]))
		var color: Color = t[1] if not dimmed or lit.has(t[0]) else t[1].darkened(0.7)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -Iso.TILE_H / 2.0),
			c + Vector2(Iso.TILE_W / 2.0, 0),
			c + Vector2(0, Iso.TILE_H / 2.0),
			c + Vector2(-Iso.TILE_W / 2.0, 0),
		]), color)
