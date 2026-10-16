# The open world: a SIZE×SIZE tile map (1 tile = 1 m, so about 1 km across) with a road grid, trees
# and buildings. Owns pathfinding, terrain streaming and deciding what the player can see.
#
# What you see (update_view, every frame):
#   inside a building -> only the floor you're on: its floor tiles, walls, objects and the people on it.
#                        Other floors and the outside are hidden.
#   outside           -> terrain, trees, outdoor objects, house exteriors and people outside within
#                        VIEW_RADIUS tiles. Interiors stay hidden.
# Terrain is streamed: CHUNK×CHUNK pieces around the player exist as nodes; the rest are freed.
#
#   peeking           -> outside view, but the house you're peeking into shows its ground floor
#                        instead of its exterior. Rooms out of sight are dimmed, and only the objects
#                        and people in line of sight through the window are shown.
#
# Floors: every character and object has a `floor` (0 = ground). A building's floors are joined by
# its stairs cell; a path that changes floor goes through it (find_path).
#
# Sight: walls block line of sight; doors and windows (unless their curtains are closed) don't.
# Ground-floor windows are on the walls facing the camera, every other tile (`windows`).
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Block = preload("res://scripts/block.gd")
const Ground = preload("res://scripts/ground.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Life = preload("res://scripts/life.gd")

const SIZE := 1024
const CHUNK := 16
const VIEW_RADIUS := 40  # tiles visible around you outside
const ROAD_EVERY := 64  # a road every 64 tiles in both directions
const ROAD_WIDTH := 3
const TREE_COUNT := 12000
const CLEARING := Rect2i(470, 490, 60, 45)  # no trees around the starting street
const STOREY_HEIGHT := 56.0  # pixels of exterior wall per floor
const INNER_WALL_HEIGHT := 22.0  # interior walls are cut down so you can see into rooms
const CURTAIN_SECONDS := 60.0  # how long curtains stay closed after someone yells at a peeper
const PATH_MARGIN := 10  # A* searches the box around start and goal, grown by this many tiles
const MAX_PATH_SPAN := 160  # longer trips are refused

const ROOF_COLOR := Color(0.788, 0.656, 0.682)  # default; buildings can set "roof" (palette: ui_theme.gd)
const SNOW_ROOF_COLOR := Color(0.98, 0.98, 1.0)  # roofs in winter
const WOOD_COLOR := Color(0.950, 0.859, 0.888)  # floors
const INNER_WALL_COLOR := Color(0.925, 0.890, 0.935)  # #dfd5e4 lightened: lavender walls

# rect includes the outer walls. door is on floor 0 and must be on the bottom (+y) or right (+x)
# wall so it faces the camera. stairs (optional) is one interior cell shared by every floor.
const BUILDINGS := [
	{"name": "Your house", "rect": Rect2i(482, 499, 12, 10), "floors": 2, "door": Vector2i(487, 508),
		"stairs": Vector2i(483, 500), "color": Color("#f5ccd4"), "roof": Color(0.769, 0.640, 0.665)},
	{"name": "Alex's house", "rect": Rect2i(498, 499, 10, 10), "floors": 1, "door": Vector2i(502, 508),
		"color": Color("#c9def4"), "roof": Color(0.631, 0.696, 0.765)},
	{"name": "Riley's house", "rect": Rect2i(486, 518, 10, 9), "floors": 1, "door": Vector2i(495, 522),
		"color": Color("#dfd5e4"), "roof": Color(0.682, 0.652, 0.697)},
	{"name": "Starter house", "rect": Rect2i(498, 518, 10, 9), "floors": 1, "door": Vector2i(507, 522),
		"color": Color("#eecfd9"), "roof": Color(0.747, 0.649, 0.681)},  # for new households (Play → Create)
]

var player: Node2D
var trees := {}  # Vector2i -> true (floor 0 only)
var solid := {0: {}}  # floor -> {Vector2i: true}: walls and objects
var walls := {}  # floor -> {Vector2i: true}: walls only (they block sight, objects don't)
var windows := {}  # ground-floor window cell -> {building, dir (outward), block, closed_until}
var clock := 0.0  # real seconds of simulation since start (scaled by game speed); see now()
var season := ""  # current season; terrain is rebuilt in its colours when it changes
var day := 0  # current game day index; Jobs.new_day runs when it changes (bills)
var daylight: CanvasModulate  # tints the whole world by time of day (not the HUD)
var kitchens := {}  # building -> {"plate": clean plates, "cup": clean cups} (kitchen.gd)
var guests := {}  # building -> {npc_name: game time the invitation ends} (ownership.gd)
var chunks := {}  # chunk coordinate -> Node2D
var chunk_root: Node2D
var outdoors: Node2D  # outdoor smart objects
var exteriors := []  # per building: the house seen from outside
var floor_nodes := []  # per building: one Node2D per floor (floor tiles, walls, stairs, objects)
var floor_grounds := []  # per building: the Ground node of each floor (dimmed while peeking)
var peek_sight := {}  # cells in sight of the window the player is peeking through
var last_chunk := Vector2i(-1, -1)


func _ready() -> void:
	add_to_group("world")
	y_sort_enabled = true
	process_priority = 100  # update the view after everyone has moved this frame
	chunk_root = sorted_node()
	outdoors = sorted_node()
	daylight = CanvasModulate.new()
	add_child(daylight)
	season = ""  # set (and roofs coloured) on the first frame
	plant_trees()
	for i in BUILDINGS.size():
		build(i)


# A child that y-sorts its children together with everything else in the scene.
func sorted_node() -> Node2D:
	var n := Node2D.new()
	n.y_sort_enabled = true
	add_child(n)
	return n


func plant_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in TREE_COUNT:
		var c := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		if is_road(c) or CLEARING.has_point(c) or building_index_at(c, 2) >= 0:
			continue
		trees[c] = true


func build(i: int) -> void:
	var b: Dictionary = BUILDINGS[i]
	var r: Rect2i = b.rect
	var floors := []
	var grounds := []
	for f in b.floors:
		var blocked: Dictionary = solid.get_or_add(f, {})
		var wall_cells: Dictionary = walls.get_or_add(f, {})
		var node := sorted_node()
		var tiles := []
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var c := Vector2i(x, y)
				if f == 0 and c == b.door:
					tiles.append([c, WOOD_COLOR.lightened(0.3)])
				elif is_edge(r, c):
					blocked[c] = true
					wall_cells[c] = true
					node.add_child(Block.new().setup("box", c, INNER_WALL_HEIGHT, INNER_WALL_COLOR))
				else:
					tiles.append([c, WOOD_COLOR.darkened(0.04 if (x + y) % 2 == 0 else 0.0)])
		var ground: Node2D = Ground.new().setup(tiles)
		node.add_child(ground)
		grounds.append(ground)
		if b.has("stairs"):
			node.add_child(Block.new().setup("stairs", b.stairs, 0.0, WOOD_COLOR.darkened(0.15)))
		floors.append(node)
	floor_nodes.append(floors)
	floor_grounds.append(grounds)

	# Exterior: one full-height box per tile, y-sorted so people walking past are drawn correctly.
	var ext := sorted_node()
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var c := Vector2i(x, y)
			var blk: Node2D = Block.new().setup("box", c, STOREY_HEIGHT * b.floors, b.color)
			blk.top_color = b.get("roof", ROOF_COLOR)
			blk.set_meta("roof", blk.top_color)
			blk.storeys = b.floors
			blk.storey_height = STOREY_HEIGHT
			var face := ""
			if y == r.end.y - 1:
				face = "left"  # the +y side of a tile is its lower-left face on screen
			elif x == r.end.x - 1:
				face = "right"
			if c == b.door:
				blk.door_face = face
			elif face != "" and (x + y) % 2 == 0:
				blk.window_faces = [face]
				windows[c] = {"building": i, "dir": face_dir(face), "block": blk, "closed_until": 0.0}
			ext.add_child(blk)
	exteriors.append(ext)


# The outward direction of a wall face: "left" faces +y, "right" faces +x.
static func face_dir(face: String) -> Vector2i:
	return Vector2i(0, 1) if face == "left" else Vector2i(1, 0)


static func is_edge(r: Rect2i, c: Vector2i) -> bool:
	return c.x == r.position.x or c.y == r.position.y or c.x == r.end.x - 1 or c.y == r.end.y - 1


# --- Queries ---

static func is_road(c: Vector2i) -> bool:
	return c.x % ROAD_EVERY < ROAD_WIDTH or c.y % ROAD_EVERY < ROAD_WIDTH


# Index of the building whose rect (grown by `margin`) contains c, or -1.
static func building_index_at(c: Vector2i, margin := 0) -> int:
	for i in BUILDINGS.size():
		if BUILDINGS[i].rect.grow(margin).has_point(c):
			return i
	return -1


# The building you're in at this cell and floor, or -1 when outside.
static func building_at(c: Vector2i, f: int) -> int:
	var b := building_index_at(c)
	return b if b >= 0 and f < BUILDINGS[b].floors else -1


func is_walkable(c: Vector2i, f: int) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= SIZE or c.y >= SIZE:
		return false
	if solid.get(f, {}).has(c):
		return false
	if f == 0:
		return not trees.has(c)
	return building_at(c, f) >= 0  # upper floors only exist inside buildings


# If c is a stairs cell on floor f, the floor it leads to (up if possible, else down). Otherwise -1.
static func stairs_destination(c: Vector2i, f: int) -> int:
	var b := building_at(c, f)
	if b < 0 or not BUILDINGS[b].has("stairs") or BUILDINGS[b].stairs != c:
		return -1
	return f + 1 if f + 1 < BUILDINGS[b].floors else f - 1


# Game seconds since day 1 00:00 (see game_time.gd).
func now() -> float:
	return GameTime.game_seconds(clock)


# --- Sight ---

func blocks_sight(c: Vector2i, f: int) -> bool:
	if f == 0 and windows.has(c):
		return is_window_closed(c)
	return walls.get(f, {}).has(c)


# Can someone on cell a see cell b (same floor)? Walls in between block it; the end cells don't.
func has_line_of_sight(a: Vector2i, b: Vector2i, f: int) -> bool:
	var line := Geometry2D.bresenham_line(a, b)
	for n in range(1, line.size() - 1):
		if blocks_sight(line[n], f):
			return false
	return true


# Interior cells of building b's floor f that can be seen from `from` (e.g. through a window).
func cells_in_sight(from: Vector2i, b: int, f: int) -> Dictionary:
	var seen := {}
	var r: Rect2i = BUILDINGS[b].rect
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			if has_line_of_sight(from, Vector2i(x, y), f):
				seen[Vector2i(x, y)] = true
	return seen


func is_window_closed(c: Vector2i) -> bool:
	return windows[c].closed_until > clock


func close_curtains(c: Vector2i) -> void:
	windows[c].closed_until = clock + CURTAIN_SECONDS
	windows[c].block.curtains = true
	windows[c].block.queue_redraw()


# What's on the house exterior at a screen position: {} if nothing, else
# {building, cell, kind: "door" | "window" | "wall", dir}. The front-most block wins.
func exterior_hit(screen: Vector2) -> Dictionary:
	var best := {}
	var best_y := -INF
	for i in BUILDINGS.size():
		if not exteriors[i].visible:
			continue
		for blk in exteriors[i].get_children():
			var local: Vector2 = screen - blk.position
			if blk.position.y > best_y and blk.contains(local):
				best_y = blk.position.y
				var kind: String = blk.feature_at(local)
				var face: String = blk.door_face if kind == "door" else ("" if blk.window_faces.is_empty() else blk.window_faces[0])
				best = {"building": i, "cell": blk.cell, "kind": kind, "dir": face_dir(face) if face != "" else Vector2i.ZERO}
	return best


# --- Ownership (see ownership.gd) ---

# May `c` go into building b? Residents always; others only with a current invitation.
func can_enter(c: Node2D, b: int) -> bool:
	return b < 0 or c.home == b or guests.get(b, {}).get(c.npc_name, -INF) > now()


func invite(b: int, c: Node2D, hours: float) -> void:
	guests.get_or_add(b, {})[c.npc_name] = now() + hours * 3600.0


func uninvite(b: int, c: Node2D) -> void:
	guests.get(b, {}).erase(c.npc_name)


func invitation_left(b: int, c: Node2D) -> float:  # game seconds, 0 if none
	return maxf(0.0, guests.get(b, {}).get(c.npc_name, 0.0) - now())


static func door_dir(b: int) -> Vector2i:  # outward
	var r: Rect2i = BUILDINGS[b].rect
	return Vector2i(0, 1) if BUILDINGS[b].door.y == r.end.y - 1 else Vector2i(1, 0)


static func door_outside(b: int) -> Vector2i:
	return BUILDINGS[b].door + door_dir(b)


static func door_inside(b: int) -> Vector2i:
	return BUILDINGS[b].door - door_dir(b)


func location_name(c: Node2D) -> String:
	if c.at_work:
		return ("At school (%s)" if Jobs.is_school(c.job) else "At work (%s)") % c.job
	if c.building < 0:
		return "Outside"
	return "%s, %s" % [BUILDINGS[c.building].name, "ground floor" if c.floor == 0 else "floor %d" % c.floor]


# --- Pathfinding ---

# Cells to walk through, as Vector3i(x, y, floor), including the start. Empty if there's no way.
# With `who`, buildings they may not enter are walls (except the one they're in, so they can leave).
func find_path(from: Vector2i, from_floor: int, to: Vector2i, to_floor: int, who: Node2D = null) -> Array:
	var closed := []
	if who:
		for i in BUILDINGS.size():
			if not can_enter(who, i) and not BUILDINGS[i].rect.has_point(from):
				closed.append(BUILDINGS[i].rect)
	if from_floor == to_floor:
		return path_on_floor(from, to, from_floor, closed)
	var b := building_index_at(to if to_floor > 0 else from)
	if b < 0 or not BUILDINGS[b].has("stairs"):
		return []
	var stairs: Vector2i = BUILDINGS[b].stairs
	var path := path_on_floor(from, stairs, from_floor, closed)
	var rest := path_on_floor(stairs, to, to_floor, closed)
	if path.is_empty() or rest.is_empty():
		return []
	var step := 1 if to_floor > from_floor else -1
	for f in range(from_floor + step, to_floor, step):
		path.append(Vector3i(stairs.x, stairs.y, f))
	path.append_array(rest)  # rest starts on the stairs cell of to_floor
	return path


func path_on_floor(a: Vector2i, b: Vector2i, f: int, closed := []) -> Array:
	if not is_walkable(b, f):
		return []
	var region := Rect2i(a, Vector2i.ONE).merge(Rect2i(b, Vector2i.ONE)).grow(PATH_MARGIN)
	region = region.intersection(Rect2i(0, 0, SIZE, SIZE))
	if region.size.x > MAX_PATH_SPAN or region.size.y > MAX_PATH_SPAN:
		return []
	var astar := AStarGrid2D.new()
	astar.region = region
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			if not is_walkable(Vector2i(x, y), f):
				astar.set_point_solid(Vector2i(x, y))
	for rect in closed:
		var r: Rect2i = rect.intersection(region)
		if r.has_area():
			astar.fill_solid_region(r)
	astar.set_point_solid(a, false)  # you can always leave the cell you're standing on
	return Array(astar.get_id_path(a, b)).map(func(c): return Vector3i(c.x, c.y, f))


func random_walkable_near(center: Vector2i, f: int, radius: int) -> Vector2i:
	for n in 20:
		var c := center + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if is_walkable(c, f):
			return c
	return center


# A walkable cell next to c (to stand at when talking to someone there), closest to `from`.
func free_neighbor(c: Vector2i, f: int, from: Vector2i) -> Vector2i:
	var best := c
	var best_d := INF
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var n: Vector2i = c + d
		if is_walkable(n, f) and Vector2(n).distance_to(Vector2(from)) < best_d:
			best = n
			best_d = Vector2(n).distance_to(Vector2(from))
	return best


# --- Objects ---

# Decorative furniture (prop.gd). Solid unless flat (rugs).
func add_prop(prop: Node2D, b: int, f: int) -> void:
	if not prop.flat:
		solid.get_or_add(f, {})[prop.cell] = true
	(outdoors if b < 0 else floor_nodes[b][f]).add_child(prop)


func add_object(obj: Node2D, b: int, f: int) -> void:
	obj.building = b
	obj.floor = f
	if not obj.is_seat():  # you sit on seats, so their tile stays walkable
		solid.get_or_add(f, {})[Vector2i(obj.grid_pos)] = true
	(outdoors if b < 0 else floor_nodes[b][f]).add_child(obj)


# --- What's on screen ---

func _process(delta: float) -> void:
	clock += delta
	var t := now()
	if GameTime.day_index(t) != day:
		day = GameTime.day_index(t)
		Jobs.new_day(self, day)
		Life.new_day(self)
	if GameTime.season(t) != season:  # new season: rebuild the terrain in its colours
		season = GameTime.season(t)
		for k in chunks:
			chunks[k].queue_free()
		chunks.clear()
		last_chunk = Vector2i(-1, -1)
		for ext in exteriors:
			for blk in ext.get_children():
				blk.top_color = SNOW_ROOF_COLOR if season == "Winter" else blk.get_meta("roof", ROOF_COLOR)
				blk.queue_redraw()
	if player:
		daylight.color = GameTime.tint(t, player.building >= 0)
	for c in windows:
		var w: Dictionary = windows[c]
		if w.block.curtains and not is_window_closed(c):
			w.block.curtains = false
			w.block.queue_redraw()
	update_view()


func update_view() -> void:
	if player == null:
		return
	var here: Vector2 = player.grid_pos
	var inside: int = player.building
	var outside := inside < 0
	if player.state == "peeking" and is_window_closed(player.peek_window):
		player.stop_peeking("The curtains are closed")
	var peek := -1  # building being peeked into
	peek_sight = {}
	if outside and player.state == "peeking":
		peek = windows[player.peek_window].building
		peek_sight = cells_in_sight(player.cell(), peek, 0)

	chunk_root.visible = outside
	outdoors.visible = outside
	for i in BUILDINGS.size():
		exteriors[i].visible = outside and i != peek
		for f in floor_nodes[i].size():
			floor_nodes[i][f].visible = (i == inside and f == player.floor) or (i == peek and f == 0)
			floor_grounds[i][f].set_lit(peek_sight, i == peek)
	for obj in get_tree().get_nodes_in_group("smart_objects"):
		if obj.building < 0:
			obj.visible = here.distance_to(obj.grid_pos) <= VIEW_RADIUS
		else:
			obj.visible = obj.building != peek or peek_sight.has(Vector2i(obj.grid_pos))
	for c in get_tree().get_nodes_in_group("characters"):
		if c == player:
			c.visible = not c.at_work
			continue
		if c.at_work:
			c.visible = false
		elif outside:
			c.visible = (c.building < 0 and here.distance_to(c.grid_pos) <= VIEW_RADIUS) \
				or (c.building == peek and c.floor == 0 and peek_sight.has(c.cell()))
		else:
			c.visible = c.building == inside and c.floor == player.floor
	if outside:
		stream_chunks(Vector2i(here.round()))


# Keep the chunks around `cell` loaded and free the rest.
func stream_chunks(cell: Vector2i) -> void:
	var center := cell / CHUNK
	if center == last_chunk:
		return
	last_chunk = center
	var r := ceili(float(VIEW_RADIUS) / CHUNK)
	var wanted := {}
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var k := center + Vector2i(dx, dy)
			if k.x < 0 or k.y < 0 or k.x * CHUNK >= SIZE or k.y * CHUNK >= SIZE:
				continue
			wanted[k] = true
			if not chunks.has(k):
				chunks[k] = make_chunk(k)
	for k in chunks.keys():
		if not wanted.has(k):
			chunks[k].queue_free()
			chunks.erase(k)


func make_chunk(k: Vector2i) -> Node2D:
	var node := Node2D.new()
	node.y_sort_enabled = true
	chunk_root.add_child(node)
	var tiles := []
	for x in range(k.x * CHUNK, k.x * CHUNK + CHUNK):
		for y in range(k.y * CHUNK, k.y * CHUNK + CHUNK):
			var c := Vector2i(x, y)
			tiles.append([c, terrain_color(c, season)])
			if trees.has(c):
				node.add_child(Block.new().setup("tree", c, 0.0, GameTime.LEAVES[season]))
	node.add_child(Ground.new().setup(tiles))
	return node


static func terrain_color(c: Vector2i, p_season: String) -> Color:
	var shade := (hash(c) % 5) * 0.006
	if is_road(c):
		var lane := c.x % ROAD_EVERY == 1 or c.y % ROAD_EVERY == 1
		var dash := (c.x + c.y) % 4 < 2 and not (c.x % ROAD_EVERY < ROAD_WIDTH and c.y % ROAD_EVERY < ROAD_WIDTH)
		if lane and dash:
			return Color(0.939, 0.939, 0.965)  # lane dashes
		return Color(0.840, 0.802, 0.858) + Color(shade, shade, shade, 0.0)  # roads
	var grass: Color = GameTime.GRASS[p_season]
	return Color(grass.r + shade, grass.g + shade * 2.0, grass.b + shade)
