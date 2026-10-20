# Cars on the roads (car.gd). A child of the world; full documentation in README "Cars and roads".
#
#   Home cars   each house has one parked on its front yard (World.BUILDINGS "car": cell, dir, model). Its two
#               tiles are solid. A grown-up with a job (not school) whose home car is free drives it to work:
#               they walk to it (npc.gd go_to_work), it drives down the street and is "away" (hidden) while they
#               work; at the end of the shift it comes back up the street, parks, and they get out (Jobs.working).
#   Street cars parked along the roads all over the map (world.gd park_cars), drawn with the terrain chunks.
#   Traffic     up to MAX_TRAFFIC cars roam the roads near you (spawned SPAWN_MIN..SPAWN_MAX tiles away, gone
#               beyond DESPAWN): right-hand lanes LANE from the centre line, at each crossroads straight on
#               (most often), left or right. They stop for people in front of them and for the car ahead;
#               at crossroads the lower id goes first (and after YIELD_SECONDS anyone goes).
# Moving cars are only shown where your sim can see (vision.gd), like people; parked ones are scenery.
extends Node2D

const Car = preload("res://scripts/car.gd")

const MAX_TRAFFIC := 5
const SPAWN_MIN := 18.0
const SPAWN_MAX := 38.0
const DESPAWN := 55.0
const LANE := 0.55  # tiles from the road's centre line to a lane's
const STOP_AHEAD := 1.8  # tiles: stop for someone this close in front
const CAR_GAP := 2.6  # tiles: keep this far behind the car ahead
const YIELD_SECONDS := 3.0
const MODELS := ["sedan", "suv", "taxi", "van", "hatchback-sports", "police", "delivery"]
const DRIVE_OFF := 45.0  # a home car leaving for work drives this far down the street, then it's away
const COME_BACK := 40.0  # ...and comes back from this far up the street

var world: Node2D
var cars := []  # every moving or home car (not the street-parked ones, which belong to chunks)
var next_id := 0
var spawn_timer := 0.0


func setup(p_world: Node2D) -> Node2D:
	world = p_world
	for i in world.BUILDINGS.size():
		var spot: Dictionary = world.BUILDINGS[i].get("car", {})
		if not spot.is_empty():
			var car := add_car(spot.model, Vector2.ZERO, Vector2(spot.dir))
			car.home = i
			car.park_at(spot.cell, Vector2(spot.dir))
			block(car, true)
	return self


func add_car(model: String, pos: Vector2, d: Vector2) -> Node2D:
	var car: Node2D = Car.new().setup(model, pos, d)
	next_id += 1
	car.id = next_id
	world.outdoors.add_child(car)
	cars.append(car)
	return car


# A parked home car's tiles are solid (people walk around it).
func block(car: Node2D, on: bool) -> void:
	for c in car.cells():
		if on:
			world.solid[0][c] = true
		else:
			world.solid[0].erase(c)


func home_car(b: int) -> Node2D:
	for car in cars:
		if car.home == b:
			return car
	return null


# The home car `c` may drive to work, or null (they take the bus).
func car_for(c: Node2D) -> Node2D:
	var Jobs: GDScript = load("res://scripts/jobs.gd")
	var Ages: GDScript = load("res://scripts/ages.gd")
	if c.home < 0 or c.job == "" or Jobs.is_school(c.job) or not Ages.is_grown_up(c):
		return null
	var car := home_car(c.home)
	return car if car and car.mode == "parked" and (car.driver == null or car.driver == c) else null


func _process(delta: float) -> void:
	if world.player == null:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = 1.0
		despawn_far()
		if cars.filter(func(c): return c.mode == "traffic").size() < MAX_TRAFFIC:
			spawn()
	for car in cars:
		car.drive(delta, self)
	show_cars()


func show_cars() -> void:
	for car in cars:
		car.visible = car.mode == "parked" or (car.mode != "away" and world.vision.sees(car.cell, 0))


# --- Traffic ---

# The centre line of the road nearest to `v` along each axis: x-roads run along x at y = yc (rows 64k..64k+2).
static func road_centre(v: float) -> float:
	return 64.0 * roundf((v - 1.0) / 64.0) + 1.0


func spawn() -> void:
	var you: Vector2 = world.player.grid_pos
	var along_x := randf() < 0.5
	var d := Vector2(1, 0) if along_x else Vector2(0, 1)
	if randf() < 0.5:
		d = -d
	var t := randf_range(SPAWN_MIN, SPAWN_MAX) * (1.0 if randf() < 0.5 else -1.0)
	var pos: Vector2
	if along_x:
		pos = Vector2(you.x + t, road_centre(you.y)) + Car.right(d) * LANE
	else:
		pos = Vector2(road_centre(you.x), you.y + t) + Car.right(d) * LANE
	if pos.x < 2.0 or pos.y < 2.0 or pos.x > world.SIZE - 3 or pos.y > world.SIZE - 3:
		return
	if world.vision.sees(Vector2i(pos.round()), 0):
		return  # don't pop up in front of you
	for car in cars:
		if car.mode != "away" and car.grid_pos.distance_to(pos) < 5.0:
			return
	var car := add_car(MODELS.pick_random(), pos, d)
	car.mode = "traffic"
	plan_turn(car)


func despawn_far() -> void:
	var you: Vector2 = world.player.grid_pos
	for car in cars.duplicate():
		if car.mode == "traffic" and car.grid_pos.distance_to(you) > DESPAWN:
			cars.erase(car)
			car.queue_free()


# Where the car turns at the next crossroads ahead, and which way it goes (never off the map).
func plan_turn(car: Node2D) -> void:
	var d: Vector2 = car.dir
	var lane_pos: Vector2 = car.grid_pos
	var centre := Vector2(road_centre(lane_pos.x), road_centre(lane_pos.y))
	# the next crossroads centre strictly ahead
	var ahead := (centre - lane_pos).dot(d)
	if ahead <= LANE + 0.01:
		centre += d * 64.0
	var choices := [d, d, d, Car.right(d), -Car.right(d)]  # straight on is likelier
	choices = choices.filter(func(n): return on_map(centre + n * 64.0))
	if choices.is_empty():
		choices = [-d]
	var n: Vector2 = choices.pick_random()
	car.turn_to = n
	if n == d:  # straight on: the next decision is just past this crossroads
		car.turn_at = centre + Car.right(d) * LANE + d * (LANE + 1.0)
	elif n == -d:  # dead end at the map's edge: turn round (car.gd moves it over to the other lane)
		car.turn_at = centre + Car.right(d) * LANE
	else:
		car.turn_at = centre + Car.right(d) * LANE + Car.right(n) * LANE


func on_map(v: Vector2) -> bool:
	return v.x >= 0.0 and v.y >= 0.0 and v.x < world.SIZE and v.y < world.SIZE


# Is something in the way: someone in front, the car ahead in the lane, or a car crossing with the right of way?
func blocked(car: Node2D) -> bool:
	var d: Vector2 = car.dir
	var side := Car.right(d)
	for c in get_tree().get_nodes_in_group("characters"):
		if c.at_work or c.floor != 0 or c.building >= 0 or c == car.driver:
			continue
		var rel: Vector2 = c.grid_pos - car.grid_pos
		var ahead := rel.dot(d)
		if ahead > 0.0 and ahead < STOP_AHEAD and absf(rel.dot(side)) < 0.8:
			return true
	if car.waited > YIELD_SECONDS:
		return false
	for other in cars:
		if other == car or other.mode not in ["traffic", "route"]:
			continue
		var rel: Vector2 = other.grid_pos - car.grid_pos
		var ahead := rel.dot(d)
		if ahead <= 0.0 or ahead > CAR_GAP or absf(rel.dot(side)) > 0.7:
			continue
		if other.dir.dot(d) > 0.9 or other.id < car.id:
			return true
	return false


# --- Driving to work (npc.gd go_to_work / arrive, Jobs.working) ---

# `c` has got in: unpark, pull into the lane and drive down the street; then the car is away.
func drive_off(car: Node2D, c: Node2D) -> void:
	block(car, false)
	car.driver = c
	var d: Vector2 = car.park_dir
	var lane := road_centre(car.grid_pos.y) + Car.right(d).y * LANE
	car.mode = "route"
	car.route = [car.grid_pos + d * 1.0, Vector2(car.grid_pos.x + d.x * 3.0, lane), Vector2(car.grid_pos.x + d.x * DRIVE_OFF, lane)]
	car.on_arrive = func(): car.mode = "away"


# The shift is over: the car comes back up the street and parks; the driver gets out and is home from work.
func come_back(car: Node2D) -> void:
	var d: Vector2 = car.park_dir
	var lane := road_centre(car.park_cell.y) + Car.right(d).y * LANE
	var spot := Vector2(car.park_cell) + d * 0.5
	car.grid_pos = Vector2(spot.x - d.x * COME_BACK, lane)
	car.mode = "route"
	car.route = [Vector2(spot.x - d.x * 2.0, lane), spot]
	car.on_arrive = func(): parked_back(car)
	car.place()


func parked_back(car: Node2D) -> void:
	car.park_at(car.park_cell, car.park_dir)
	block(car, true)
	var c: Node2D = car.driver
	car.driver = null
	if c == null or not is_instance_valid(c):
		return
	c.commute_car = null
	c.floor = 0
	c.grid_pos = Vector2(world.free_neighbor(car.park_cell, 0, car.park_cell + Vector2i(0, -1)))
	load("res://scripts/jobs.gd").finish_shift(c)
