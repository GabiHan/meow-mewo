# Builds the game: the open world (world.gd), smart objects, the residents, and you (controller.gd),
# starting as PLAYER_NAME. You can switch to anyone in your household (hud.gd household bar).
# Also owns global controls: game speed and pause (like The Sims), the NPC detail overlay (F3) and zoom.
#
# Speed: 1/2/3/4 = Normal/Fast/Faster/Ultra (SPEEDS), P/Space/0 = pause (resumes at the chosen speed).
# Pausing sets Engine.time_scale to 0, so nothing moves, but you can still click to give orders.
# While your character sleeps or is at work, time runs at Ultra automatically and returns to your speed after.
extends Node2D

const World = preload("res://scripts/world.gd")
const SmartObject = preload("res://scripts/smart_object.gd")
const Npc = preload("res://scripts/npc.gd")
const Controller = preload("res://scripts/controller.gd")
const Prop = preload("res://scripts/prop.gd")
const BuildMode = preload("res://scripts/build_mode.gd")
const PLAYER_NAME := "Jo"  # your character's name: change it here
const Hud = preload("res://scripts/hud.gd")
const Life = preload("res://scripts/life.gd")

const SPEEDS := [1.0, 5.0, 20.0, 60.0]  # time multipliers: a game day lasts 24 min / 4.8 min / 72 s / 24 s
const SPEED_NAMES := ["Normal", "Fast", "Faster", "Ultra"]
const SPEED_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const PAUSE_KEYS := [KEY_P, KEY_SPACE, KEY_0]
const ZOOM_MIN := 0.35
const ZOOM_MAX := 1.5

# Buildings are indexes into World.BUILDINGS: 0 = your house, 1 = Alex's, 2 = Riley's, -1 = outdoors.
const BOOKSHELF := {"verb": "Reading", "skill": "Logic", "moodlet": "Learned something"}

# Furniture sprites (furniture.gd, baked from assets/furniture_obj by tools/bake_furniture.gd) for each
# object type; an object's extras can override it with "sprite". Objects not listed keep a placeholder box.
const FURNITURE := {
	"Fridge": "Kitchen_Fridge_r0", "Counter": "Kitchen_2Drawers_r0", "Stove": "Kitchen_Oven_r0", "Sink": "Kitchen_Sink_r0",
	"Table": "Table_RoundSmall_r0", "Bed": "Bed_Single_r0", "Crib": "Bed_Single_r0", "Shower": "Bathroom_Bathtub_r0",
	"Toilet": "Bathroom_Toilet_r0", "Bookshelf": "Bookshelf_r0",
}

# Decoration in your house (not usable; usable furniture is in OBJECTS): [sprite, building, floor, tile, flat].
# Props block their tile, so keep doors, stairs and the tiles in front of objects free.
const PROPS := [
	["Kitchen_Cabinet1_r0", 0, 0, Vector2i(484, 500), false],
	["Carpet_1_r0", 0, 0, Vector2i(491, 502), true],
	["Houseplant_1_r0", 0, 0, Vector2i(492, 500), false],
	["Light_Stand1_r0", 0, 0, Vector2i(492, 503), false],
	["Houseplant_5_r0", 0, 0, Vector2i(483, 507), false],
	["Trashcan_Small1_r0", 0, 0, Vector2i(489, 500), false],
	["NightStand_1_r0", 0, 1, Vector2i(487, 500), false],
	["Light_Floor1_r0", 0, 1, Vector2i(489, 500), false],
	["Carpet_Round_r0", 0, 1, Vector2i(488, 503), true],
	["Couch_Small1_r2", 0, 1, Vector2i(486, 506), false],
	["Drawer_2_r0", 0, 1, Vector2i(490, 507), false],
	["Houseplant_3_r0", 0, 1, Vector2i(492, 507), false],
	["Shelf_Small1_r0", 0, 1, Vector2i(484, 507), false],
]

# [name, building, floor, tile, advertisements {need: amount restored}, seconds to use, color, box height, extras?]
# extras (optional): {"verb": shown while using, "skill": practised while using, "moodlet": given when done}
# Seconds are real seconds at 1x speed = game minutes. What you can do with each kind of object (Sleep / Nap,
# Pee / Poo...) is in actions.gd; ads and seconds here are only used for objects not listed there.
# extras may also set "facing" (0-3, the side its front is on) and "sprite".
# Negative amounts are costs.
# You use an object from the tile in front of it (tile + (0, 1)), which must be walkable.
# Kitchen objects (Fridge, Counter, Stove, Sink, Table) advertise nothing themselves: what you can do
# with them comes from kitchen.gd. Each house needs all five for its kitchen to work.
const OBJECTS := [
	["Fridge", 0, 0, Vector2(485, 500), {}, 0.0, Color(0.85, 0.9, 0.95), 40],
	["Counter", 0, 0, Vector2(486, 500), {}, 0.0, Color(0.7, 0.6, 0.5), 20],
	["Stove", 0, 0, Vector2(487, 500), {}, 0.0, Color(0.25, 0.25, 0.28), 20],
	["Sink", 0, 0, Vector2(488, 500), {}, 0.0, Color(0.75, 0.8, 0.85), 20],
	["Table", 0, 0, Vector2(486, 504), {}, 0.0, Color(0.55, 0.38, 0.25), 16],
	["TV", 0, 0, Vector2(491, 500), {"fun": 60}, 30.0, Color(0.62, 0.56, 0.75), 28, {"verb": "Watching TV", "skill": "Comedy"}],
	["Toilet", 0, 0, Vector2(492, 505), {"bladder": 90}, 3.0, Color(0.95, 0.95, 0.9), 20],
	["Chair", 0, 0, Vector2(485, 504), {"energy": 5}, 10.0, Color(0.3, 0.25, 0.2), 20, {"sprite": "Chair_1_r1", "facing": 1}],
	["Chair", 0, 0, Vector2(487, 504), {"energy": 5}, 10.0, Color(0.3, 0.25, 0.2), 20, {"sprite": "Chair_1_r3", "facing": 3}],
	["Couch", 0, 0, Vector2(491, 503), {"fun": 20, "energy": 10}, 30.0, Color(0.3, 0.2, 0.2), 20, {"sprite": "Couch_Large1_r2", "facing": 2}],
	["Bathroom sink", 0, 0, Vector2(492, 507), {"hygiene": 10}, 2.0, Color(0.8, 0.8, 0.8), 20, {"sprite": "Bathroom_Sink_r3", "facing": 3}],
	["Bathroom sink", 0, 1, Vector2(492, 500), {"hygiene": 10}, 2.0, Color(0.8, 0.8, 0.8), 20, {"sprite": "Bathroom_Sink_r0"}],
	["Bed", 0, 1, Vector2(488, 500), {"energy": 100}, 420.0, Color(0.45, 0.55, 0.85), 14, {"verb": "Sleeping", "moodlet": "Well rested", "sprite": "Bed_King_r0"}],
	["Bookshelf", 0, 1, Vector2(484, 503), {"fun": 35}, 45.0, Color(0.5, 0.33, 0.2), 44, BOOKSHELF],
	["Shower", 0, 1, Vector2(491, 500), {"hygiene": 80}, 10.0, Color(0.45, 0.8, 0.8), 36, {"verb": "Showering", "moodlet": "Freshened up"}],

	["Fridge", 1, 0, Vector2(500, 500), {}, 0.0, Color(0.85, 0.9, 0.95), 40],
	["Counter", 1, 0, Vector2(501, 500), {}, 0.0, Color(0.7, 0.6, 0.5), 20],
	["Stove", 1, 0, Vector2(502, 500), {}, 0.0, Color(0.25, 0.25, 0.28), 20],
	["Sink", 1, 0, Vector2(503, 500), {}, 0.0, Color(0.75, 0.8, 0.85), 20],
	["Table", 1, 0, Vector2(501, 504), {}, 0.0, Color(0.55, 0.38, 0.25), 16],
	["Bed", 1, 0, Vector2(505, 500), {"energy": 100}, 420.0, Color(0.45, 0.55, 0.85), 14, {"verb": "Sleeping", "moodlet": "Well rested"}],
	["Shower", 1, 0, Vector2(506, 500), {"hygiene": 80}, 10.0, Color(0.45, 0.8, 0.8), 36, {"verb": "Showering", "moodlet": "Freshened up"}],
	["Toilet", 1, 0, Vector2(499, 504), {"bladder": 90}, 3.0, Color(0.95, 0.95, 0.9), 20],
	["Bed", 1, 0, Vector2(499, 502), {"energy": 100}, 420.0, Color(0.85, 0.55, 0.7), 14, {"verb": "Sleeping", "moodlet": "Well rested"}],  # Mia's
	["Crib", 1, 0, Vector2(506, 503), {"energy": 100}, 300.0, Color(0.95, 0.9, 0.7), 18, {"verb": "Sleeping", "moodlet": "Well rested"}],  # Lily's
	["Bookshelf", 1, 0, Vector2(503, 506), {"fun": 35}, 45.0, Color(0.5, 0.33, 0.2), 44, BOOKSHELF],
	["TV", 1, 0, Vector2(505, 505), {"fun": 60}, 30.0, Color(0.62, 0.56, 0.75), 28, {"verb": "Watching TV", "skill": "Comedy"}],

	["Fridge", 2, 0, Vector2(488, 519), {}, 0.0, Color(0.85, 0.9, 0.95), 40],
	["Counter", 2, 0, Vector2(489, 519), {}, 0.0, Color(0.7, 0.6, 0.5), 20],
	["Stove", 2, 0, Vector2(490, 519), {}, 0.0, Color(0.25, 0.25, 0.28), 20],
	["Sink", 2, 0, Vector2(487, 521), {}, 0.0, Color(0.75, 0.8, 0.85), 20],
	["Table", 2, 0, Vector2(490, 523), {}, 0.0, Color(0.55, 0.38, 0.25), 16],
	["Bed", 2, 0, Vector2(492, 519), {"energy": 100}, 420.0, Color(0.45, 0.55, 0.85), 14, {"verb": "Sleeping", "moodlet": "Well rested"}],
	["Shower", 2, 0, Vector2(494, 519), {"hygiene": 80}, 10.0, Color(0.45, 0.8, 0.8), 36, {"verb": "Showering", "moodlet": "Freshened up"}],
	["Toilet", 2, 0, Vector2(488, 524), {"bladder": 90}, 3.0, Color(0.95, 0.95, 0.9), 20],
	["Bed", 2, 0, Vector2(493, 521), {"energy": 100}, 420.0, Color(0.4, 0.6, 0.5), 14, {"verb": "Sleeping", "moodlet": "Well rested"}],  # Noah's
	["Bookshelf", 2, 0, Vector2(487, 519), {"fun": 35}, 45.0, Color(0.5, 0.33, 0.2), 44, BOOKSHELF],
	["TV", 2, 0, Vector2(492, 523), {"fun": 60}, 30.0, Color(0.62, 0.56, 0.75), 28, {"verb": "Watching TV", "skill": "Comedy"}],

	["Bench", -1, 0, Vector2(500, 516), {"fun": 25}, 15.0, Color(0.98, 0.76, 0.62), 12],
	["Bus stop", -1, 0, Vector2(497, 511), {}, 0.0, Color(0.62, 0.8, 1.0), 50],  # jobs: where you leave for work
	["Pull-up bar", -1, 0, Vector2(503, 516), {"fun": 15, "energy": -10, "hygiene": -10}, 30.0, Color(0.82, 0.82, 0.95), 48,
		{"verb": "Working out", "skill": "Fitness", "moodlet": "Pumped"}],
]

var world: Node2D
var camera: Camera2D
var player: Node2D  # the character you control right now (controller.gd keeps this up to date)
var controller: Node
var build: CanvasLayer  # build mode (B)
var speed := 0  # index into SPEEDS chosen by the player
var paused := false
var sleep_boost := false  # time is at Ultra because you're asleep
var auto_sleep_speed := true  # whether sleeping speeds time up (the tests turn it off)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.96, 0.92, 0.97))  # pale lilac around everything
	y_sort_enabled = true  # things lower on screen draw in front

	world = World.new()
	add_child(world)
	for o in OBJECTS:
		var extras: Dictionary = (o[8] if o.size() > 8 else {}).duplicate()
		if not extras.has("sprite") and FURNITURE.has(o[0]):
			extras.sprite = FURNITURE[o[0]]
		var obj: Node2D = SmartObject.new().setup(o[0], o[3], o[4], o[5], o[6], o[7])
		world.add_object(obj.with_extras(extras), o[1], o[2])
	for p in PROPS:
		world.add_prop(Prop.new().setup(p[0], p[3], p[4]), p[1], p[2])

	# setup(name, tile, color, home building, traits, starting skill levels). See docs/PEOPLE.md.
	# .set_life(money, job), .set_age(sex, years, parents). See docs/WORK.md and docs/LIFE.md.
	add_child(Npc.new().setup("Sam", Vector2(490, 503), Color(0.95, 0.65, 0.35), 0,  # your roommate
		["Outgoing", "Goofball", "Slob"], {"Comedy": 3, "Charisma": 2}).set_life(200, "Comedy club").set_age("M", 23).set_look("sam"))
	add_child(Npc.new().setup("Alex", Vector2(502, 504), Color(0.75, 0.45, 0.85), 1,
		["Hot-headed", "Foodie", "Neat"], {"Cooking": 5, "Fitness": 2}).set_life(400, "Restaurant").set_age("F", 38).set_look("alex"))
	add_child(Npc.new().setup("Mia", Vector2(500, 506), Color(0.95, 0.8, 0.35), 1,  # Alex's daughter
		["Cheerful"], {"Logic": 1}).set_life(0).set_age("F", 8, ["Alex"]).set_look("mia"))
	add_child(Npc.new().setup("Lily", Vector2(504, 503), Color(0.6, 0.85, 0.95), 1,  # Alex's youngest
		["Goofball"], {}).set_life(0).set_age("F", 2.5, ["Alex"]).set_look("lily"))
	add_child(Npc.new().setup("Riley", Vector2(490, 521), Color(0.9, 0.4, 0.45), 2,
		["Loner", "Bookworm", "Cheerful"], {"Logic": 4, "Cooking": 2}).set_life(600, "Office").set_age("M", 42).set_look("riley"))
	add_child(Npc.new().setup("Noah", Vector2(492, 525), Color(0.45, 0.55, 0.9), 2,  # Riley's son
		["Active", "Goofball"], {"Fitness": 2}).set_life(20).set_age("M", 15, ["Riley"]).set_look("noah"))

	var you: Node2D = Npc.new().setup(PLAYER_NAME, Vector2(488, 504), Color(0.35, 0.8, 0.45), 0, [], {"Cooking": 2, "Charisma": 1})
	you.set_life(300).set_age("F", 20).set_look("jo")  # no job yet: get one at the Bus stop
	you.speed = 2.5
	for need in you.needs:
		you.needs[need] = 85.0
	add_child(you)
	Life.setup_families(self)

	camera = Camera2D.new()
	camera.position = Vector2(0, -30)
	controller = Controller.new().setup(self, camera)
	add_child(controller)
	controller.take_control(you)  # the camera follows whoever you control
	add_child(Hud.new().setup(player, self))
	build = BuildMode.new().setup(self)
	add_child(build)
	apply_speed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in SPEED_KEYS:
			set_speed(SPEED_KEYS.find(event.keycode))
		elif event.keycode in PAUSE_KEYS:
			toggle_pause()
		elif event.keycode == KEY_F3:
			Npc.show_details = not Npc.show_details
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = Vector2.ONE * minf(camera.zoom.x * 1.1, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = Vector2.ONE * maxf(camera.zoom.x / 1.1, ZOOM_MIN)


# --- Game speed ---

func set_speed(i: int) -> void:
	speed = i
	paused = false
	apply_speed()


func toggle_pause() -> void:
	paused = not paused
	apply_speed()


func apply_speed() -> void:
	Engine.time_scale = 0.0 if paused else SPEEDS[-1] if sleep_boost else SPEEDS[speed]


# Asleep or away at work: time can fly.
func is_sleeping(c: Node2D) -> bool:
	return c.at_work or (c.state == "using" and c.step.get("asleep", false))


func _process(_delta: float) -> void:
	if (auto_sleep_speed and is_sleeping(player)) != sleep_boost:
		sleep_boost = not sleep_boost
		apply_speed()


# What the HUD shows: "Paused", "Normal (1x)", "Ultra (60x) — sleeping".
func speed_text() -> String:
	if paused:
		return "Paused"
	if sleep_boost:
		return "%s (%dx) while you %s" % [SPEED_NAMES[-1], SPEEDS[-1], "work" if player.at_work else "sleep"]
	return "%s (%dx)" % [SPEED_NAMES[speed], SPEEDS[speed]]
