# A placeholder shape that fills one tile, drawn in _draw(): walls, house exteriors, trees and stairs.
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const HW := Iso.TILE_W / 2.0
const HH := Iso.TILE_H / 2.0

var kind := "box"  # box | tree | stairs
var height := 24.0
var color := Color.WHITE
var top_color := Color.TRANSPARENT  # roof color; transparent = same as color
var door_face := ""  # "left" (the tile's +y side) or "right" (+x side)
var window_faces := []
var storeys := 1  # one row of windows per storey
var storey_height := 56.0
var cell := Vector2i.ZERO
var curtains := false  # ground-floor windows show closed curtains


func setup(p_kind: String, p_cell: Vector2i, p_height: float, p_color: Color) -> Node2D:
	kind = p_kind
	cell = p_cell
	height = p_height
	color = p_color
	position = Iso.to_screen(Vector2(p_cell))
	return self


func _ready() -> void:
	if kind == "stairs":
		var label := Label.new()
		label.text = "Stairs"
		label.add_theme_font_size_override("font_size", 12)
		label.position = Vector2(-20, -40)
		label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.48, 0.8))
		add_child(label)


func _draw() -> void:
	match kind:
		"tree":
			draw_rect(Rect2(-3, -20, 6, 20), Color(0.612, 0.585, 0.626))
			draw_circle(Vector2(0, -34), 16.0, color.darkened(0.2))
			draw_circle(Vector2(-4, -38), 11.0, color)
		"stairs":
			var t := Vector2(0, -HH)
			var r := Vector2(HW, 0)
			var b := Vector2(0, HH)
			var l := Vector2(-HW, 0)
			draw_colored_polygon(PackedVector2Array([t, r, b, l]), color)
			for i in range(1, 5):
				var k := i / 5.0
				draw_line(t.lerp(l, k), r.lerp(b, k), color.lightened(0.35), 2.0)
		_:
			draw_box()


func draw_box() -> void:
	var top := -height
	draw_colored_polygon(PackedVector2Array([Vector2(-HW, top), Vector2(0, top + HH), Vector2(0, HH), Vector2(-HW, 0)]), color.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(HW, top), Vector2(0, top + HH), Vector2(0, HH), Vector2(HW, 0)]), color.darkened(0.18))
	var roof := color if top_color.a == 0.0 else top_color
	draw_colored_polygon(PackedVector2Array([Vector2(0, top - HH), Vector2(HW, top), Vector2(0, top + HH), Vector2(-HW, top)]), roof)
	for face in window_faces:
		for s in storeys:
			var glass := Color("#f5ccd4") if curtains and s == 0 else Color(0.862, 0.916, 0.972)
			draw_on_face(face, 0.3, 0.7, s * storey_height + 22.0, s * storey_height + 40.0, glass)
	if door_face != "":
		draw_on_face(door_face, 0.25, 0.75, 0.0, 40.0, Color(0.631, 0.576, 0.612))


# Outline of the box on screen (local coordinates), for mouse picking.
func contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(-HW, 0), Vector2(0, HH),
		Vector2(HW, 0), Vector2(HW, -height), Vector2(0, -height - HH), Vector2(-HW, -height)]))


# "door", "window" (ground floor only) or "wall" for a point on this box. Click areas are a bit
# bigger than the drawings so they're easy to hit.
func feature_at(p: Vector2) -> String:
	if door_face != "" and Geometry2D.is_point_in_polygon(p, face_quad(door_face, 0.15, 0.85, 0.0, 48.0)):
		return "door"
	for face in window_faces:
		if Geometry2D.is_point_in_polygon(p, face_quad(face, 0.15, 0.85, 12.0, 50.0)):
			return "window"
	return "wall"


func face_quad(face: String, u0: float, u1: float, v0: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([face_point(face, u0, v0), face_point(face, u1, v0),
		face_point(face, u1, v1), face_point(face, u0, v1)])


# A quad on a side face. u runs along the bottom edge (0..1), v is pixels up from the ground.
func draw_on_face(face: String, u0: float, u1: float, v0: float, v1: float, c: Color) -> void:
	draw_colored_polygon(face_quad(face, u0, u1, v0, v1), c)


static func face_point(face: String, u: float, v: float) -> Vector2:
	if face == "left":
		return Vector2(-HW + HW * u, HH * u - v)
	return Vector2(HW * u, HH - HH * u - v)
