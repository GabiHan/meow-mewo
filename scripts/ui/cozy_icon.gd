# Icons in the Cozy Paws style: flat token fills, a cocoa outline with round joins, a tiny white highlight.
# Drawn with primitives in a 24×24 box scaled to the control's size, so they follow day/dusk (UiTheme.REDRAW_GROUP).
#   var icon := CozyIcon.make("drop", 20)
# Names: NAMES below. Needs use: hunger apple, thirst drop, energy bolt, fun sparkle, bladder roll, hygiene bubbles,
# social heart.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const NAMES := ["bolt", "drop", "heart", "sparkle", "apple", "roll", "bubbles", "smile", "coin", "moon", "gift", "paw",
	"sprout", "flower", "fish", "strawberry", "star"]
const STROKE := 1.8

var icon := "sparkle"


static func make(name: String, size := 24) -> Control:
	var i := new()
	i.icon = name
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _ready() -> void:
	add_to_group(UiTheme.REDRAW_GROUP)


func set_icon(name: String) -> void:
	icon = name
	queue_redraw()


func _draw() -> void:
	var k := minf(size.x, size.y) / 24.0
	draw_set_transform(Vector2((size.x - 24.0 * k) / 2.0, (size.y - 24.0 * k) / 2.0), 0.0, Vector2(k, k))
	match icon:
		"bolt":
			shape(PackedVector2Array([Vector2(13.5, 2.5), Vector2(5, 13.5), Vector2(11, 13.5), Vector2(9.8, 21.5),
				Vector2(18.5, 10), Vector2(12.5, 10)]), "leaf")
		"drop":
			shape(drop_points(Vector2(12, 15), 6.0, 2.8), "sky")
			draw_circle(Vector2(9.6, 14.5), 1.1, UiTheme.c("white"))
		"heart":
			shape(heart_points(Vector2(12, 12.5), 0.52), "petal")
		"sparkle", "star":
			shape(star_points(Vector2(12, 12), 9.5, 3.0, 4), "butter")
		"apple":
			shape(circle_points(Vector2(12, 14), 7.0, 18, 1.0, 0.92), "peach")
			draw_line(Vector2(12, 7.5), Vector2(13, 4), UiTheme.c("outline"), STROKE, true)
			shape(ellipse_points(Vector2(15.5, 5.5), 2.6, 1.3, -0.5), "leaf")
			draw_circle(Vector2(9, 11.5), 1.1, UiTheme.c("white"))
		"roll":
			shape(rounded_rect(Rect2(6, 5, 12, 15), 2.5), "aqua")
			shape(ellipse_points(Vector2(12, 5), 6, 2.2, 0.0), "white")
			draw_circle(Vector2(12, 5), 1.2, UiTheme.c("outline"))
		"bubbles":
			shape(circle_points(Vector2(9, 14), 5.2, 18), "bubble")
			shape(circle_points(Vector2(16.5, 9), 3.8, 16), "bubble")
			shape(circle_points(Vector2(17, 17.5), 2.4, 12), "bubble")
			draw_circle(Vector2(7.5, 12.3), 1.1, UiTheme.c("white"))
		"smile":
			shape(circle_points(Vector2(12, 12), 9.0, 22), "butter")
			draw_circle(Vector2(9, 10.5), 1.1, UiTheme.c("outline"))
			draw_circle(Vector2(15, 10.5), 1.1, UiTheme.c("outline"))
			draw_arc(Vector2(12, 12.5), 3.6, 0.35, PI - 0.35, 10, UiTheme.c("outline"), STROKE, true)
		"coin":
			shape(circle_points(Vector2(12, 12), 9.0, 22), "butter")
			draw_arc(Vector2(12, 12), 5.0, 0, TAU, 20, UiTheme.c("outline"), STROKE, true)
			draw_circle(Vector2(8.4, 8.6), 1.1, UiTheme.c("white"))
		"moon":
			shape(crescent_points(Vector2(12, 12.5), 8.5, Vector2(16.5, 8), 7.0), "butter")
		"gift":
			shape(rounded_rect(Rect2(4, 10, 16, 10), 2.5), "petal")
			shape(rounded_rect(Rect2(3, 7, 18, 4), 2.0), "petal_strong")
			draw_line(Vector2(12, 7), Vector2(12, 20), UiTheme.c("outline"), STROKE, true)
			shape(ellipse_points(Vector2(9.5, 5.5), 2.6, 1.5, 0.4), "butter")
			shape(ellipse_points(Vector2(14.5, 5.5), 2.6, 1.5, -0.4), "butter")
		"paw":
			var ink := UiTheme.c("petal_strong")
			draw_colored_polygon(ellipse_points(Vector2(12, 15.5), 5.0, 4.2, 0.0), ink)
			for p in [Vector2(6, 10), Vector2(9.5, 6.5), Vector2(14.5, 6.5), Vector2(18, 10)]:
				draw_circle(p, 2.0, ink)
		"sprout":
			draw_line(Vector2(12, 20), Vector2(12, 12), UiTheme.c("outline"), STROKE, true)
			shape(ellipse_points(Vector2(8, 10.5), 4.2, 2.2, 0.5), "leaf")
			shape(ellipse_points(Vector2(16, 8.5), 4.2, 2.2, -0.5), "leaf")
			draw_line(Vector2(5.5, 20.5), Vector2(18.5, 20.5), UiTheme.c("outline"), STROKE, true)
		"flower":
			for n in 5:
				var a := -PI / 2.0 + n * TAU / 5.0
				shape(circle_points(Vector2(12, 12) + Vector2(cos(a), sin(a)) * 5.2, 3.6, 14), "sky")
			shape(circle_points(Vector2(12, 12), 3.0, 14), "butter")
		"fish":
			shape(PackedVector2Array([Vector2(16.5, 12), Vector2(21, 8), Vector2(21, 16)]), "sky")
			shape(ellipse_points(Vector2(10, 12), 7.2, 4.2, 0.0), "sky")
			draw_circle(Vector2(6.5, 11.3), 1.0, UiTheme.c("outline"))
		"strawberry":
			shape(drop_points(Vector2(12, 12.5), 6.8, 1.3, true), "petal_strong")
			shape(star_points(Vector2(12, 7), 4.2, 1.6, 5), "leaf")
			for p in [Vector2(10, 12), Vector2(14, 13), Vector2(12, 16)]:
				draw_circle(p, 0.7, UiTheme.c("white"))
		_:
			shape(star_points(Vector2(12, 12), 9.5, 3.0, 4), "butter")


# A filled polygon in a token colour with the outline around it.
func shape(points: PackedVector2Array, token: String) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, UiTheme.c(token))
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, UiTheme.c("outline"), STROKE, true)


static func circle_points(center: Vector2, r: float, n := 20, sx := 1.0, sy := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(center + Vector2(cos(a) * r * sx, sin(a) * r * sy))
	return pts


static func ellipse_points(center: Vector2, rx: float, ry: float, angle: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts


# A teardrop: round bottom around `center`, a point `tip` radii above (`down`: the point at the bottom).
static func drop_points(center: Vector2, r: float, tip: float, down := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var apex := Vector2(0, (r * tip) * (1 if down else -1))
	pts.append(center + apex)
	var start := deg_to_rad(-30.0) if not down else deg_to_rad(150.0)
	for i in 17:
		var a := start + i * deg_to_rad(240.0) / 16.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


# The part of circle (c1, r1) outside circle (c2, r2): a crescent.
static func crescent_points(c1: Vector2, r1: float, c2: Vector2, r2: float, n := 48) -> PackedVector2Array:
	var outer := []
	for i in n:
		var a := i * TAU / n
		var p := c1 + Vector2(cos(a), sin(a)) * r1
		outer.append([p, p.distance_to(c2) > r2])
	var start := 0
	while not (outer[start][1] and not outer[(start - 1 + n) % n][1]):
		start += 1
	var pts := PackedVector2Array()
	var i := start
	while outer[i % n][1]:
		pts.append(outer[i % n][0])
		i += 1
	var a_end := (pts[pts.size() - 1] - c2).angle()
	var a_start := (pts[0] - c2).angle()
	var sweep := wrapf(a_start - a_end, -PI, PI)
	var mid := c2 + Vector2.from_angle(a_end + sweep / 2.0) * r2
	if mid.distance_to(c1) > r1:
		sweep = sweep - TAU if sweep > 0.0 else sweep + TAU
	for k in range(1, 16):
		pts.append(c2 + Vector2.from_angle(a_end + sweep * k / 16.0) * r2)
	return pts


static func heart_points(center: Vector2, k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var t := i * TAU / 28.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(center + Vector2(x, y) * k)
	return pts


static func star_points(center: Vector2, outer: float, inner: float, tips: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in tips * 2:
		var a := -PI / 2.0 + i * PI / tips
		pts.append(center + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return pts


static func rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[r.position + Vector2(r.size.x - radius, radius), -PI / 2.0], [r.end - Vector2(radius, radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2.0], [r.position + Vector2(radius, radius), PI]]
	for corner in corners:
		for i in 5:
			var a: float = corner[1] + i * (PI / 2.0) / 4.0
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * radius)
	return pts
