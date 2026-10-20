# What your sim can see, Project Zomboid style (a child of world.gd; full documentation: docs/VIEW.md).
#
# Every UPDATE_MSEC it casts RAYS rays from the person you control, on their floor, out to RADIUS tiles.
# A ray stops at a wall (world.blocks_sight: walls, closed curtains; open windows and doors let sight through).
# How far a ray sees:
#   in front (a CONE_DEGREES cone around where they face): sight_range(), from NIGHT_RANGE in the dark to
#   DAY_RANGE in daylight; outdoors × the weather (weather.gd: fog sees least)
#   behind:                                                 BEHIND_RANGE (you still notice what's right behind you)
#   lit tiles (lamps, homes with someone awake at night):   DAY_RANGE, as long as the ray reaches them
# Tiles you see are `visible`; tiles you've seen before are remembered (`remembered`, per floor).
#
# Shown as a soft veil over the ground (one pixel per tile, stretched onto the isometric grid with smooth
# filtering): clear where you see, a light veil where you remember, dark where you've never been. At night
# the veil is a deep blue, in fog it's white. Tall things (trees, house walls, furniture) are dimmed the same
# way (modulate), and people out of sight are hidden (world.gd update_view asks sees()).
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Looks = preload("res://scripts/looks.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Weather = preload("res://scripts/weather.gd")

const RADIUS := 34  # tiles around you that are worked out (and veiled)
const RAYS := 480
const STEP := 0.5  # tiles between samples along a ray
const DAY_RANGE := 28.0
const NIGHT_RANGE := 3.5
const BEHIND_RANGE := 4.5
const CONE_DEGREES := 180.0
const LAMP_RADIUS := 5.0
const UPDATE_MSEC := 150
const MEMORY_ALPHA := [0.22, 0.7]  # the veil over places you remember: [by day, at night]
const UNKNOWN_ALPHA := [0.5, 0.9]  # over places you've never seen: [by day, at night]
const DAY_VEIL := Color(0.56, 0.54, 0.68)
const NIGHT_VEIL := Color(0.07, 0.06, 0.16)
const FOG_VEIL := Color(0.96, 0.96, 0.99)

var world: Node2D
var visible_cells := {}  # Vector2i -> true: what you see right now (on your floor)
var remembered := {}  # floor -> {Vector2i: true}
var lit := {}  # Vector2i -> true: lit tiles on your floor
var floor_seen := 0
var center := Vector2i.ZERO
var next_update := 0
var image: Image
var texture: ImageTexture
var sprite: Sprite2D
var veil := DAY_VEIL


func _ready() -> void:
	world = get_parent()
	z_index = -1  # over the ground (z -2), under walls, furniture and people
	var size := RADIUS * 2 + 1
	image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # soft edges between seen and unseen
	add_child(sprite)


# Called by world.gd every frame; recalculates at most every UPDATE_MSEC (or now, with force).
func update(force := false) -> void:
	var you: Node2D = world.player
	if you == null:
		return
	if not force and Time.get_ticks_msec() < next_update:
		return
	next_update = Time.get_ticks_msec() + UPDATE_MSEC
	center = you.cell()
	floor_seen = you.floor
	find_lights(you)
	cast(you)
	draw_veil()
	dim_things(you)


func sees(cell: Vector2i, f: int) -> bool:
	return f == floor_seen and visible_cells.has(cell)


func remembers(cell: Vector2i, f: int) -> bool:
	return remembered.get(f, {}).has(cell)


# How far you see in front of you right now, indoors or out.
func sight_range(outdoors: bool) -> float:
	var t: float = world.now()
	var r := lerpf(NIGHT_RANGE, DAY_RANGE, GameTime.daylight(t))
	return r * (Weather.sight(world.weather) if outdoors else 1.0)


# Lamps light a circle around them; at night a home is lit inside while someone there is awake.
func find_lights(you: Node2D) -> void:
	lit = {}
	var f: int = you.floor
	var dark: bool = GameTime.daylight(world.now()) < 0.6
	if not dark:
		return
	for i in world.BUILDINGS.size():
		if f >= world.floor_nodes[i].size():
			continue
		var awake: bool = world.get_tree().get_nodes_in_group("characters").any(func(c): return c.building == i \
			and c.floor == f and not c.dead and not (c.state == "using" and c.step.get("asleep", false)))
		var r: Rect2i = world.BUILDINGS[i].rect
		if awake:
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					lit[Vector2i(x, y)] = true
		for n in world.floor_nodes[i][f].get_children():
			if "sprite" in n and str(n.sprite).begins_with("Light_"):
				light_circle(n.cell if "flat" in n else Vector2i(n.grid_pos), LAMP_RADIUS)


func light_circle(at: Vector2i, radius: float) -> void:
	var r := ceili(radius)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if Vector2(dx, dy).length() <= radius:
				lit[at + Vector2i(dx, dy)] = true


func cast(you: Node2D) -> void:
	visible_cells = {center: true}
	var f: int = you.floor
	var facing: Vector2 = Looks.DIRS[you.facing_dir].normalized() if "facing_dir" in you else Vector2(0, 1)
	var half_cone := deg_to_rad(CONE_DEGREES / 2.0)
	var in_range := sight_range(false)
	var out_range := sight_range(true)
	var any_light := not lit.is_empty()
	var lit_in := DAY_RANGE if any_light else 0.0
	var lit_out := DAY_RANGE * Weather.sight(world.weather) if any_light else 0.0
	var origin := Vector2(center)
	for k in RAYS:
		var angle := TAU * k / RAYS
		var dir := Vector2(cos(angle), sin(angle))
		var ahead := absf(dir.angle_to(facing)) <= half_cone
		var longest := maxf((maxf(in_range, out_range) if ahead else BEHIND_RANGE), maxf(lit_in, lit_out))
		var t := STEP
		while t <= minf(longest, RADIUS):
			var c := Vector2i((origin + dir * t).round())
			var outdoors: bool = world.building_index_at(c) < 0
			var reach := (out_range if outdoors else in_range) if ahead else BEHIND_RANGE
			if t <= reach or (lit.has(c) and t <= (lit_out if outdoors else lit_in)):
				visible_cells[c] = true
			elif t > maxf(reach, lit_out if outdoors else lit_in):
				break
			if world.blocks_sight(c, f) or (f > 0 and world.building_at(c, f) < 0):
				break  # walls stop sight (you see the wall itself)
			t += STEP
	var memory: Dictionary = remembered.get_or_add(f, {})
	memory.merge(visible_cells)


func veil_color() -> Color:
	var light := GameTime.daylight(world.now())
	if world.weather == "Fog" and world.player.building < 0:
		return NIGHT_VEIL.lerp(FOG_VEIL, light)  # white by day, still dark at night
	return NIGHT_VEIL.lerp(DAY_VEIL, light)


# How thick the veil is: thin by day (you know the neighbourhood is there), thick at night.
func alphas() -> Array:
	var dark := 1.0 - GameTime.daylight(world.now())
	return [lerpf(MEMORY_ALPHA[0], MEMORY_ALPHA[1], dark), lerpf(UNKNOWN_ALPHA[0], UNKNOWN_ALPHA[1], dark)]


func draw_veil() -> void:
	veil = veil_color()
	var thickness := alphas()
	var memory: Dictionary = remembered.get(floor_seen, {})
	var corner := center - Vector2i(RADIUS, RADIUS)
	for i in RADIUS * 2 + 1:
		for j in RADIUS * 2 + 1:
			var c := corner + Vector2i(i, j)
			var a: float = 0.0 if visible_cells.has(c) else thickness[0] if memory.has(c) else thickness[1]
			image.set_pixel(i, j, Color(veil, a))
	texture.update(image)
	# grid → screen is linear: x along (TILE_W/2, TILE_H/2), y along (-TILE_W/2, TILE_H/2); pixel (i, j) is cell corner + (i, j)
	transform = Transform2D(Vector2(Iso.TILE_W / 2.0, Iso.TILE_H / 2.0), Vector2(-Iso.TILE_W / 2.0, Iso.TILE_H / 2.0),
		Iso.to_screen(Vector2(corner) - Vector2(0.5, 0.5)))


# The tint for something standing on `cell`: full colour if seen, veiled if remembered, dark if unknown.
func tint(cell: Vector2i) -> Color:
	if visible_cells.has(cell):
		return Color.WHITE
	var memory: Dictionary = remembered.get(floor_seen, {})
	var thickness := alphas()
	return Color.WHITE.lerp(Color(veil, 1.0), thickness[0] if memory.has(cell) else thickness[1])


# Trees, house walls, furniture: dimmed like the ground under them. A house seen from outside is lit as a
# whole once you see any of its walls.
func dim_things(you: Node2D) -> void:
	for k in world.chunks:
		for n in world.chunks[k].get_children():
			if "kind" in n:
				n.modulate = tint(n.cell)
	for n in world.outdoors.get_children():
		n.modulate = tint(Vector2i(n.grid_pos)) if "grid_pos" in n else Color.WHITE
	for i in world.BUILDINGS.size():
		var r: Rect2i = world.BUILDINGS[i].rect
		var best := tint(Vector2i(-99999, -99999))
		for x in range(r.position.x, r.end.x):
			for y in [r.position.y, r.end.y - 1]:
				best = brighter(best, tint(Vector2i(x, y)))
		for y in range(r.position.y, r.end.y):
			for x in [r.position.x, r.end.x - 1]:
				best = brighter(best, tint(Vector2i(x, y)))
		world.exteriors[i].modulate = best
		if you.building == i and you.floor < world.floor_nodes[i].size():
			for n in world.floor_nodes[i][you.floor].get_children():
				if "cell" in n:
					n.modulate = tint(n.cell)
				elif "grid_pos" in n:
					n.modulate = tint(Vector2i(n.grid_pos))


static func brighter(a: Color, b: Color) -> Color:
	return a if a.v >= b.v else b
