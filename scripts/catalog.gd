# Build mode catalog: what you can buy, and the rules for placing, selling and moving it. Static.
# The UI is build_mode.gd. Full documentation: docs/BUILD.md.
#
# An item is decor (a prop: looks nice, blocks its tile unless flat) or usable furniture (a smart
# object that people use, with `object`: its name, advertisements, minutes and extras like any row
# of OBJECTS in main.gd). Sprites are baked by tools/bake_furniture.gd in 4 rotations.
#
# Where you can build: inside your own home (the household of the person you control), on the floor
# you're on, on free floor tiles (not walls, the stairs, the doorway or the tile inside the door), and
# never so that something becomes unreachable (every object's front tile and the stairs must still be
# reachable from the door).
#
# Build category: a **Wall** (a cut-down wall on one tile, blocks movement and sight; build_mode.gd lets you
# drag to draw a straight line of them), **Remove walls** (a tool: drag over walls you built to sell them) and **Stairs** (only in a one-storey house, on the ground floor: adds an empty upper floor, world.gd
# add_upper_floor; removable while that floor is empty, refunding SELL_BACK).
const Furniture = preload("res://scripts/furniture.gd")
const Actions = preload("res://scripts/actions.gd")

const SELL_BACK := 0.75  # selling refunds this share of the price

const CATEGORIES := ["Build", "Seating", "Tables", "Beds", "Kitchen", "Bathroom", "Lighting", "Plants", "Rugs", "Storage", "Fun"]

const BED := {"name": "Bed", "ads": {"energy": 100}, "minutes": 420.0, "extras": {"verb": "Sleeping", "moodlet": "Well rested"}}
const COUCH := {"name": "Couch", "ads": {"fun": 20, "energy": 10}, "minutes": 30.0, "extras": {"verb": "Relaxing"}}
const CHAIR := {"name": "Chair", "ads": {"energy": 5}, "minutes": 10.0}  # what you can do with each is in actions.gd

# id: {name, category, price, model, flat?, object?}
const ITEMS := {
	"wall": {"name": "Wall", "category": "Build", "price": 70, "model": "", "wall": true},
	"stairs": {"name": "Stairs + upper floor", "category": "Build", "price": 1500, "model": "", "stairs": true},
	"wall_erase": {"name": "Remove walls", "category": "Build", "price": 0, "model": "", "tool": true},
	"chair_wood": {"name": "Wooden chair", "category": "Seating", "price": 40, "model": "Chair_1", "object": CHAIR},
	"chair_modern": {"name": "Modern chair", "category": "Seating", "price": 60, "model": "Chair_2", "object": CHAIR},
	"chair_arm": {"name": "Dining armchair", "category": "Seating", "price": 75, "model": "Chair_3", "object": CHAIR},
	"stool": {"name": "Stool", "category": "Seating", "price": 25, "model": "Stool", "object": CHAIR},
	"armchair": {"name": "Armchair", "category": "Seating", "price": 180, "model": "Couch_Small1", "object": COUCH},
	"loveseat": {"name": "Loveseat", "category": "Seating", "price": 260, "model": "Couch_Medium1", "object": COUCH},
	"sofa": {"name": "Sofa", "category": "Seating", "price": 350, "model": "Couch_Large1", "object": COUCH},
	"corner_sofa": {"name": "Corner sofa", "category": "Seating", "price": 480, "model": "Couch_L", "object": COUCH},
	"table_small": {"name": "Round dining table", "category": "Tables", "price": 120, "model": "Table_RoundSmall",
		"object": {"name": "Table", "ads": {}, "minutes": 0.0}},
	"table_large": {"name": "Large table", "category": "Tables", "price": 220, "model": "Table_RoundLarge",
		"object": {"name": "Table", "ads": {}, "minutes": 0.0}},
	"coffee_table": {"name": "Coffee table", "category": "Tables", "price": 90, "model": "Table_Coffee"},
	"desk": {"name": "Desk", "category": "Tables", "price": 150, "model": "Desk"},
	"nightstand": {"name": "Nightstand", "category": "Tables", "price": 60, "model": "NightStand_1"},
	"nightstand2": {"name": "Bedside table", "category": "Tables", "price": 70, "model": "NightStand_2"},
	"bed_single": {"name": "Single bed", "category": "Beds", "price": 300, "model": "Bed_Single", "object": BED},
	"bed_king": {"name": "King bed", "category": "Beds", "price": 650, "model": "Bed_King", "object": BED},
	"bed_bunk": {"name": "Bunk bed", "category": "Beds", "price": 420, "model": "Bed_Bunk", "object": BED},
	"fridge": {"name": "Fridge", "category": "Kitchen", "price": 500, "model": "Kitchen_Fridge", "object": {"name": "Fridge", "ads": {}, "minutes": 0.0}},
	"oven": {"name": "Oven", "category": "Kitchen", "price": 400, "model": "Kitchen_Oven", "object": {"name": "Stove", "ads": {}, "minutes": 0.0}},
	"counter": {"name": "Counter", "category": "Kitchen", "price": 150, "model": "Kitchen_2Drawers", "object": {"name": "Counter", "ads": {}, "minutes": 0.0}},
	"kitchen_sink": {"name": "Kitchen sink", "category": "Kitchen", "price": 200, "model": "Kitchen_Sink", "object": {"name": "Sink", "ads": {}, "minutes": 0.0}},
	"cabinet": {"name": "Kitchen cabinet", "category": "Kitchen", "price": 110, "model": "Kitchen_Cabinet1"},
	"drawers3": {"name": "Kitchen drawers", "category": "Kitchen", "price": 130, "model": "Kitchen_3Drawers"},
	"toilet": {"name": "Toilet", "category": "Bathroom", "price": 250, "model": "Bathroom_Toilet",
		"object": {"name": "Toilet", "ads": {"bladder": 90}, "minutes": 3.0}},
	"bathtub": {"name": "Bathtub", "category": "Bathroom", "price": 500, "model": "Bathroom_Bathtub",
		"object": {"name": "Shower", "ads": {"hygiene": 80}, "minutes": 10.0, "extras": {"verb": "Bathing", "moodlet": "Freshened up"}}},
	"bath_sink": {"name": "Bathroom sink", "category": "Bathroom", "price": 120, "model": "Bathroom_Sink",
		"object": {"name": "Bathroom sink", "ads": {"hygiene": 10}, "minutes": 2.0}},
	"washer": {"name": "Washing machine", "category": "Bathroom", "price": 350, "model": "Bathroom_WashingMachine"},
	"lamp_floor": {"name": "Floor lamp", "category": "Lighting", "price": 60, "model": "Light_Floor1"},
	"lamp_reading": {"name": "Reading lamp", "category": "Lighting", "price": 70, "model": "Light_Floor3"},
	"lamp_shade": {"name": "Shade lamp", "category": "Lighting", "price": 90, "model": "Light_Stand1"},
	"lamp_stand": {"name": "Standing lamp", "category": "Lighting", "price": 85, "model": "Light_Stand2"},
	"plant_fern": {"name": "Fern", "category": "Plants", "price": 25, "model": "Houseplant_1"},
	"plant_cactus": {"name": "Cactus", "category": "Plants", "price": 20, "model": "Houseplant_3"},
	"plant_palm": {"name": "Small palm", "category": "Plants", "price": 30, "model": "Houseplant_5"},
	"plant_big": {"name": "Big leafy plant", "category": "Plants", "price": 45, "model": "Houseplant_7"},
	"rug": {"name": "Rug", "category": "Rugs", "price": 60, "model": "Carpet_1", "flat": true},
	"rug_dark": {"name": "Dark rug", "category": "Rugs", "price": 70, "model": "Carpet_2", "flat": true},
	"rug_round": {"name": "Round rug", "category": "Rugs", "price": 80, "model": "Carpet_Round", "flat": true},
	"bookshelf": {"name": "Bookshelf", "category": "Storage", "price": 250, "model": "Bookshelf",
		"object": {"name": "Bookshelf", "ads": {"fun": 35}, "minutes": 45.0, "extras": {"verb": "Reading", "skill": "Logic", "moodlet": "Learned something"}}},
	"shelf_small": {"name": "Wall shelf", "category": "Storage", "price": 50, "model": "Shelf_Small1"},
	"shelf_large": {"name": "Tall shelf", "category": "Storage", "price": 140, "model": "Shelf_Large"},
	"dresser": {"name": "Dresser", "category": "Storage", "price": 160, "model": "Drawer_2"},
	"dresser_tall": {"name": "Tall dresser", "category": "Storage", "price": 190, "model": "Drawer_4"},
	"coat_rack": {"name": "Coat rack", "category": "Storage", "price": 35, "model": "Coat_Rack"},
	"bin": {"name": "Bin", "category": "Storage", "price": 15, "model": "Trashcan_Small1"},
	"bin_large": {"name": "Large bin", "category": "Storage", "price": 30, "model": "Trashcan_Large"},
	"tv": {"name": "TV", "category": "Fun", "price": 350, "model": "TV",
		"object": {"name": "TV", "ads": {"fun": 60}, "minutes": 30.0, "color": Color(0.3, 0.3, 0.35), "height": 28,
			"extras": {"verb": "Watching TV", "skill": "Comedy"}}},
	"radio": {"name": "Radio", "category": "Fun", "price": 45, "model": "Radio"},
	"teddy": {"name": "Teddy bear", "category": "Fun", "price": 20, "model": "Teddy"},
	"fireplace": {"name": "Fireplace", "category": "Fun", "price": 800, "model": "",  # no fireplace in the kit: a placeholder box
		"object": {"name": "Fireplace", "ads": {"fun": 25, "social": 5}, "minutes": 30.0, "color": Color(0.78, 0.6, 0.6), "height": 30, "extras": {"verb": "Relaxing by the fire"}}},
}

const FACING := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]  # rotation -> front tile direction


static func sprite(id: String, rot: int) -> String:
	var model: String = ITEMS[id].model
	return "" if model == "" else "%s_r%d" % [model, rot]


static func in_category(category: String) -> Array:
	return ITEMS.keys().filter(func(id): return ITEMS[id].category == category)


# Is `cell` (floor f) a free floor tile inside building b where something could stand?
static func free_tile(world: Node2D, b: int, f: int, cell: Vector2i) -> bool:
	var r: Rect2i = world.BUILDINGS[b].rect
	if world.building_at(cell, f) != b or world.is_edge(r, cell):
		return false
	if world.BUILDINGS[b].get("stairs") == cell or (f == 0 and cell == world.door_inside(b)):
		return false
	return world.is_walkable(cell, f)


# Quick check while hovering: "" if it fits here, else why not.
static func why_not(c: Node2D, id: String, cell: Vector2i, rot: int, f: int) -> String:
	var world: Node2D = c.world
	var b: int = c.home
	if b < 0:
		return "You have no home"
	if ITEMS[id].get("stairs", false):
		if world.BUILDINGS[b].floors > 1:
			return "This house already has an upper floor"
		if f != 0:
			return "Stairs go on the ground floor"
	if not free_tile(world, b, f, cell):
		return "Not here"
	if ITEMS[id].has("object") and not ITEMS[id].object.name in Actions.SEATS and not free_tile(world, b, f, cell + FACING[rot]):
		return "The front must be free"
	return ""


# Full check: everything in the house must still be reachable from the door afterwards.
static func keeps_house_reachable(world: Node2D, b: int, f: int, cell: Vector2i, flat: bool) -> bool:
	if flat:
		return true
	var walls: Dictionary = world.solid.get_or_add(f, {})
	walls[cell] = true  # pretend it's there
	var ok := true
	var door: Vector2i = world.door_inside(b)
	for o in world.get_tree().get_nodes_in_group("smart_objects"):
		if ok and o.building == b and world.find_path(door, 0, o.use_cell(), o.floor).is_empty():
			ok = false
	if ok and world.BUILDINGS[b].has("stairs"):
		ok = not world.find_path(door, 0, world.BUILDINGS[b].stairs, 0).is_empty()
	walls.erase(cell)
	return ok


# Buy and place. `free` (moving something you own) skips the price. Returns the new node, or null.
static func place(c: Node2D, id: String, cell: Vector2i, rot: int, f: int, free := false) -> Node2D:
	var item: Dictionary = ITEMS[id]
	if why_not(c, id, cell, rot, f) != "" or (not free and c.money < item.price):
		return null
	if item.get("stairs", false):  # the stairs tile stays walkable: nothing gets blocked
		c.world.add_upper_floor(c.home, cell)
		c.money -= item.price
		return c.world.floor_nodes[c.home][0]
	if not keeps_house_reachable(c.world, c.home, f, cell, item.get("flat", false)):
		return null
	var node: Node2D
	if item.get("wall", false):
		node = load("res://scripts/prop.gd").new().setup("", cell, false, true)
		node.catalog_id = id
		c.world.add_prop(node, c.home, f)
	elif item.has("object"):
		var o: Dictionary = item.object
		var extras: Dictionary = o.get("extras", {}).duplicate()
		if item.model != "":
			extras.sprite = sprite(id, rot)
		node = load("res://scripts/smart_object.gd").new().setup(o.name, Vector2(cell), o.ads, o.minutes,
			o.get("color", Color(0.6, 0.6, 0.6)), o.get("height", 24))
		node.facing = rot
		node.with_extras(extras)
		node.catalog_id = id
		c.world.add_object(node, c.home, f)
	else:
		node = load("res://scripts/prop.gd").new().setup(sprite(id, rot), cell, item.get("flat", false))
		node.catalog_id = id
		node.rotation_index = rot
		c.world.add_prop(node, c.home, f)
	if not free:
		c.money -= item.price
	return node


# What's on this tile of your home (floor f) that you could sell or move: an object or a prop.
static func thing_at(c: Node2D, cell: Vector2i, f: int) -> Node2D:
	for n in c.world.floor_nodes[c.home][f].get_children():
		var at: Vector2i = n.cell if "flat" in n else (Vector2i(n.grid_pos) if "grid_pos" in n else Vector2i(-1, -1))
		if at == cell and ("flat" in n or "advertisements" in n):
			return n
	return null


# Catalog id of something placed (older furniture is matched by its sprite's model).
static func id_of(thing: Node2D) -> String:
	if thing.catalog_id != "":
		return thing.catalog_id
	var model: String = thing.sprite.substr(0, thing.sprite.rfind("_r")) if thing.sprite != "" else ""
	for id in ITEMS:
		if ITEMS[id].model == model and model != "":
			return id
	if "object_name" in thing:
		for id in ITEMS:
			if ITEMS[id].has("object") and ITEMS[id].object.name == thing.object_name:
				return id
	return ""


static func sell_price(thing: Node2D) -> int:
	var id := id_of(thing)
	return int(ITEMS[id].price * SELL_BACK) if id != "" else 20


# Remove it from the world (sold or picked up to move). False if someone is using it.
static func remove(c: Node2D, thing: Node2D) -> bool:
	if "user" in thing and thing.user != null:
		return false
	var f: int = thing.floor if "advertisements" in thing else c.world.floor_nodes[c.home].find(thing.get_parent())
	var cell: Vector2i = thing.cell if "flat" in thing else Vector2i(thing.grid_pos)
	if not ("flat" in thing and thing.flat):
		c.world.solid.get(f, {}).erase(cell)
	if "wall" in thing and thing.wall:
		c.world.walls.get(f, {}).erase(cell)
	if thing.is_in_group("smart_objects"):
		thing.remove_from_group("smart_objects")
	thing.queue_free()
	return true


static func sell(c: Node2D, thing: Node2D) -> int:
	var money := sell_price(thing)
	if not remove(c, thing):
		return -1
	c.money += money
	return money


# Turn something in place to the next direction. Usable furniture needs its new front tile free,
# and nothing in the house may become unreachable. Returns false (and leaves it) if not allowed.
# Built stairs come out again (with their empty upper floor). Returns the refund, or -1 if not allowed.
static func remove_stairs(c: Node2D) -> int:
	if c.home < 0 or not c.world.BUILDINGS[c.home].get("built_stairs", false) or not c.world.upper_floor_empty(c.home):
		return -1
	c.world.remove_upper_floor(c.home)
	var refund := int(ITEMS.stairs.price * SELL_BACK)
	c.money += refund
	return refund


static func rotate(c: Node2D, thing: Node2D) -> bool:
	if "user" in thing and thing.user != null:
		return false
	if "flat" in thing:
		thing.rotate_to((thing.rotation_index + 1) % 4)
		return true
	var old: int = thing.facing
	var r := (old + 1) % 4
	if not thing.is_seat():
		var front: Vector2i = Vector2i(thing.grid_pos) + FACING[r]
		if not free_tile(c.world, thing.building, thing.floor, front):
			return false
	thing.rotate_to(r)
	var door: Vector2i = c.world.door_inside(thing.building)
	if c.world.find_path(door, 0, thing.use_cell(), thing.floor).is_empty():
		thing.rotate_to(old)
		return false
	return true
