# A car (traffic.gd): parked, driving around the roads (`traffic`), or following a `route` (a home car driving
# someone to work and back). Baked sprites car_<model>_r<0-3> (tools/bake_neighbourhood.gd), r0 heading +y.
# Moves in grid space at SPEED tiles a second (scaled by game speed), stopping for people and cars ahead
# (Traffic.blocked). Parked cars fill two tiles along their heading (cells()).
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Furniture = preload("res://scripts/furniture.gd")

const SPEED := 5.0  # tiles per second
const HEADINGS := [Vector2(0, 1), Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0)]  # sprite r0..r3

var kind := "car"  # vision.gd tints chunk things that have a `kind` and a `cell`
var model := "sedan"
var grid_pos := Vector2.ZERO
var cell := Vector2i.ZERO
var dir := Vector2(1, 0)  # heading in grid space
var mode := "parked"  # parked | traffic | route | away (a home car out with its driver: hidden)
var route := []  # "route": waypoints (Vector2) still to drive to
var on_arrive := Callable()  # "route": called at the last waypoint
var turn_at := Vector2.INF  # "traffic": the point where it turns (or goes on) at the next crossroads
var turn_to := Vector2.ZERO
var home := -1  # a home car: its building (World.BUILDINGS)
var park_cell := Vector2i.ZERO  # a home car's parking space: this cell and the next one along park_dir
var park_dir := Vector2(1, 0)
var driver: Node2D = null  # who's driving it (or about to)
var id := 0  # lower ids have the right of way at crossroads
var waited := 0.0  # seconds stopped for another car
var sprite: Sprite2D


func setup(p_model: String, p_pos: Vector2, p_dir: Vector2) -> Node2D:
	model = p_model
	grid_pos = p_pos
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	set_dir(p_dir)
	place()
	return self


# Parked on `a` and the next tile along `d`.
func park_at(a: Vector2i, d: Vector2) -> Node2D:
	park_cell = a
	park_dir = d
	grid_pos = Vector2(a) + d * 0.5
	set_dir(d)
	mode = "parked"
	place()
	return self


func cells() -> Array:
	var a := Vector2i((grid_pos - dir * 0.5).round())
	return [a, a + Vector2i(dir.round())]


func set_dir(d: Vector2) -> void:
	if d.length() < 0.001:
		return
	dir = d.normalized()
	var best := 0
	for r in 4:
		if dir.dot(HEADINGS[r]) > dir.dot(HEADINGS[best]):
			best = r
	var name := "car_%s_r%d" % [model, best]
	if Furniture.has(name, Furniture.SCENERY):
		sprite.texture = Furniture.texture(name, Furniture.SCENERY)
		sprite.offset = -Furniture.anchor(name, Furniture.SCENERY)


func place() -> void:
	cell = Vector2i(grid_pos.round())
	position = Iso.to_screen(grid_pos)


# The side of the road a car heading `d` keeps to (right-hand traffic).
static func right(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x)


# One frame of driving. `traffic` is the Traffic node (who's in the way, the next turn).
func drive(delta: float, traffic: Node) -> void:
	if mode not in ["traffic", "route"]:
		return
	if traffic.blocked(self):
		waited += delta
		return
	var step := SPEED * delta
	if mode == "route":
		while step > 0.0 and not route.is_empty():
			var to: Vector2 = route[0] - grid_pos
			if to.length() > 0.001:
				set_dir(to)
			if to.length() <= step:
				grid_pos = route.pop_front()
				step -= to.length()
			else:
				grid_pos += to.normalized() * step
				step = 0.0
		if route.is_empty():
			place()
			var done := on_arrive
			on_arrive = Callable()
			if done.is_valid():
				done.call()
			return
	elif turn_at != Vector2.INF and grid_pos.distance_to(turn_at) <= step:
		grid_pos = turn_at
		if turn_to.dot(dir) < -0.9:  # turning round at the map's edge: over to the other lane
			grid_pos += right(turn_to) * traffic.LANE * 2.0
		set_dir(turn_to)
		traffic.plan_turn(self)
	else:
		grid_pos += dir * step
	waited = 0.0
	place()
