# Headless simulation checks. Run from the project folder:
#   godot --headless --fixed-fps 60 -s res://tests/check_sim.gd
# --fixed-fps makes every frame exactly 1/60 s of game time and runs as fast as the CPU allows,
# so 15 simulated minutes take a few seconds. Exits with code 1 if any check fails.
extends SceneTree

const Social = preload("res://scripts/social.gd")
const Perception = preload("res://scripts/perception.gd")
const Kitchen = preload("res://scripts/kitchen.gd")
const GameTime = preload("res://scripts/game_time.gd")
const World = preload("res://scripts/world.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Skills = preload("res://scripts/skills.gd")
const Traits = preload("res://scripts/traits.gd")
const Ownership = preload("res://scripts/ownership.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Ages = preload("res://scripts/ages.gd")
const Life = preload("res://scripts/life.gd")
const Romance = preload("res://scripts/romance.gd")
const Mind = preload("res://scripts/mind.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Actions = preload("res://scripts/actions.gd")
const Looks = preload("res://scripts/looks.gd")
const Llm = preload("res://scripts/llm.gd")
const Talk = preload("res://scripts/talk.gd")
const Body = preload("res://scripts/body.gd")
const BuildMode = preload("res://scripts/build_mode.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Session = preload("res://scripts/session.gd")
const DAY := 24 * 60.0  # real seconds (world.clock) per game day
const Iso = preload("res://scripts/iso.gd")
const Furniture = preload("res://scripts/furniture.gd")
const Block = preload("res://scripts/block.gd")
const SIM_SECONDS := 900.0

var main: Node2D
var player: Node2D
var t := 0.0
var failures := 0
var conflicts := 0
var wait_time := {}  # character -> how long the current wait has lasted
var max_overrun := 0.0  # worst (time waited - that wait's wait_limit)
var view_errors := 0  # frames where something visible shouldn't have been
var went_upstairs := {}  # npc_name -> true for anyone who reached floor 1
var went_outside := {}
var slept := {}  # npc_name -> "day"/"night" for anyone who slept
var emotions_seen := {}  # emotion -> true, felt by anyone during the run
var start_xp := {}  # npc_name -> total skill xp at the start
var last_building := {}  # character -> building last frame
var trespasses := 0  # times someone walked into a building they weren't allowed in
var knocks := 0
var went_to_work := {}  # npc_name -> true
var start_needs := {}
var start_pos := Vector2.ZERO
var phase := 0
var friendship_before := 0.0
var checked_unknown := false


func _initialize() -> void:
	seed(12345)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func object_named(name: String, b: int) -> Node2D:
	for o in main.get_tree().get_nodes_in_group("smart_objects"):
		if o.object_name == name and o.building == b:
			return o
	return null


# Pathfinding, walls, doors and stairs, checked once at the start.
func check_world() -> void:
	var w: Node2D = main.world
	check(not w.is_walkable(Vector2i(482, 503), 0), "house walls are solid")
	check(w.is_walkable(Vector2i(485, 508), 0), "the front door is walkable")
	check(not w.is_walkable(Vector2i(488, 511), 1), "there is no upper floor outside a building")
	check(not w.is_walkable(Vector2i(500, 504), 1), "Alex's one-storey house has no floor 1")

	var bed := object_named("Bed", 0)
	var up: Array = w.find_path(Vector2i(488, 504), 0, bed.use_cell(), 1)
	var all_walkable := up.all(func(p): return w.is_walkable(Vector2i(p.x, p.y), p.z))
	check(not up.is_empty() and up[-1] == Vector3i(488, 501, 1) and all_walkable,
		"path from the living room to your bed upstairs (%d steps, all walkable: %s)" % [up.size(), all_walkable])
	check(up.has(Vector3i(483, 500, 0)) and up.has(Vector3i(483, 500, 1)), "that path goes up the stairs")

	var across: Array = w.find_path(Vector2i(488, 504), 0, Vector2i(490, 521), 0)
	check(across.has(Vector3i(485, 508, 0)) and across.has(Vector3i(495, 522, 0)),
		"path to Riley's house leaves through your door and enters through Riley's")
	check(w.find_path(Vector2i(488, 504), 0, Vector2i(482, 503), 0).is_empty(), "no path into a wall")
	var blocked := []
	for o in main.get_tree().get_nodes_in_group("smart_objects"):
		if o.building >= 0 and w.find_path(w.door_inside(o.building), 0, o.use_cell(), o.floor).is_empty():
			blocked.append("%s in %s" % [o.object_name, w.BUILDINGS[o.building].name])
	check(blocked.is_empty(), "furniture doesn't block anything: every object can be reached from its front door %s" % [blocked])
	var sprites := main.get_tree().get_nodes_in_group("smart_objects").filter(func(o): return o.sprite != "")
	check(sprites.size() >= 20 and main.world.floor_nodes[0][0].get_children().any(func(n): return "flat" in n),
		"3D furniture sprites are used (%d objects) and your house is decorated" % sprites.size())


# Everything on screen must belong where the player is (checked every frame).
func check_view() -> void:
	var inside: int = player.building
	var vision: Node2D = main.world.vision
	for c in npcs():  # people only when your sim sees them, never inside another house
		if c.visible and (not vision.sees(c.cell(), c.floor) or (c.building >= 0 and c.building != inside)):
			view_errors += 1
	for o in main.get_tree().get_nodes_in_group("smart_objects"):  # no furniture of other houses or floors
		if o.building >= 0 and o.is_visible_in_tree() and (o.building != inside or o.floor != player.floor):
			view_errors += 1
	if not main.world.chunk_root.visible:  # the neighbourhood is always there
		view_errors += 1


# Terrain streaming: move the player around outside and look at which chunks exist.
func check_streaming() -> void:
	var w: Node2D = main.world
	player.cancel_current()
	player.floor = 0
	player.grid_pos = Vector2(500, 513)  # on the road
	player.building = -1
	w.update_view()
	check(w.chunk_root.visible and w.chunks.has(Vector2i(31, 32)), "outside: the chunk you stand in is loaded")
	check(not object_named("Fridge", 0).is_visible_in_tree() and w.exteriors[0].visible,
		"outside: houses show their exterior, not their contents")
	player.grid_pos = Vector2(300, 300)
	w.update_view()
	var near: bool = w.chunks.keys().all(func(k): return absi(k.x - 18) <= 3 and absi(k.y - 18) <= 3)
	check(w.chunks.has(Vector2i(18, 18)) and not w.chunks.has(Vector2i(31, 32)) and near,
		"after walking away, old chunks are freed and new ones loaded (%d loaded)" % w.chunks.size())
	check(not object_named("Bench", -1).visible, "outdoor objects beyond VIEW_RADIUS are hidden")
	w._process(0.0)  # catch up with clock jumps from earlier checks
	var old_season: String = w.season
	var old_grass: Color = w.chunks[Vector2i(18, 18)].get_child(-1).tiles[0][1]
	w.clock += 7 * DAY
	w._process(0.0)
	var new_grass: Color = w.chunks[Vector2i(18, 18)].get_child(-1).tiles[0][1] if w.chunks.has(Vector2i(18, 18)) else old_grass
	check(w.season != old_season and new_grass != old_grass, "a new season (%s → %s) rebuilds the terrain in its colours" % [old_season, w.season])
	check(World.terrain_color(Vector2i(5, 5), "Winter").v > 0.8, "winter grass is snowy")

	var sam: Node2D = npcs().filter(func(c): return c.npc_name == "Sam")[0]
	var bed := object_named("Bed", 0)
	w.clock = 4 * 60.0  # noon
	var sleep: Dictionary = Actions.for_object(bed)[0]
	var day_factor: float = sam.time_factor(sleep)
	w.clock = 16 * 60.0  # midnight
	check(sam.time_factor(sleep) > 1.0 and day_factor < 1.0 and sam.time_factor(Actions.for_object(bed)[1]) == 1.0,
		"beds are more attractive at night than by day")


# Put an NPC somewhere, doing nothing (for the scripted checks at the end).
func reset(c: Node2D, pos: Vector2) -> void:
	c.end_social()
	c.drop_task()
	c.at_work = false
	c.pending_work = false
	c.job = ""  # scripted checks jump around in time; no surprise shifts
	c.path = []
	c.state = "idle"
	c.floor = 0
	c.grid_pos = pos
	c.building = main.world.building_at(c.cell(), 0)


# Clock, calendar, seasons, daylight (pure functions of world.clock).
func check_time() -> void:
	var start := GameTime.game_seconds(0.0)
	check(GameTime.clock_text(start) == "08:00:00" and GameTime.weekday(start) == "Monday"
		and GameTime.date_text(start) == "Spring, day 1 of 7, year 1", "the game starts Monday 08:00:00, Spring day 1, year 1")
	check(GameTime.clock_text(GameTime.game_seconds(90.5)) == "09:30:30", "1 real second = 1 game minute")
	var tue := GameTime.game_seconds(DAY)
	check(GameTime.weekday(tue) == "Tuesday" and GameTime.season_day(tue) == 2, "24 real minutes later it's Tuesday, day 2")
	check(GameTime.season(GameTime.game_seconds(7 * DAY)) == "Summer" and GameTime.season(GameTime.game_seconds(21 * DAY)) == "Winter"
		and GameTime.year(GameTime.game_seconds(28 * DAY)) == 2 and GameTime.season(GameTime.game_seconds(28 * DAY)) == "Spring",
		"7 days per season: Summer on day 8, Winter on day 22, year 2 on day 29")
	var noon := GameTime.game_seconds(4 * 60.0)
	var midnight := GameTime.game_seconds(16 * 60.0)
	check(GameTime.daylight(noon) == 1.0 and GameTime.daylight(midnight) == 0.0 and GameTime.is_night(midnight),
		"noon is full daylight, midnight is night")
	var summer_evening := GameTime.game_seconds(7 * DAY + 10.5 * 60.0)  # 18:30
	var winter_evening := GameTime.game_seconds(21 * DAY + 10.5 * 60.0)
	check(GameTime.daylight(summer_evening) > 0.9 and GameTime.daylight(winter_evening) < 0.1,
		"at 18:30 it's still light in summer but dark in winter")
	check(GameTime.tint(midnight, false).v < 0.9 and GameTime.tint(midnight, true).v > GameTime.tint(midnight, false).v
		and GameTime.tint(noon, false) == Color.WHITE, "night darkens the screen; indoors the lamps are on")
	var spring_at := func(h: float) -> Color: return GameTime.tint(GameTime.game_seconds((h - 8.0) * 60.0), false)
	var morning: Color = spring_at.call(8.0)
	var sunset: Color = spring_at.call(20.0)
	check(morning.b > morning.r and spring_at.call(15.0) == Color.WHITE and sunset.r > sunset.b and sunset.r > 0.9
		and spring_at.call(23.0).v < 0.7 and GameTime.tint(GameTime.game_seconds(0.0), true) == Color.WHITE,
		"outside: blue morning, bright afternoon, sunset at dusk, dark night; indoors stays untinted by day")
	for season_name in GameTime.SEASONS:
		var keys: Array = GameTime.sky_keys(season_name)
		var ordered := true
		for i in keys.size() - 1:
			ordered = ordered and keys[i][0] <= keys[i + 1][0]
		check(ordered, "%s sky keyframes are in order" % season_name)


func person(name: String) -> Node2D:
	return main.get_tree().get_nodes_in_group("characters").filter(func(c): return c.npc_name == name)[0]


func interaction(name: String) -> Dictionary:
	return Social.INTERACTIONS.filter(func(i): return i.name == name)[0]


func set_needs(c: Node2D, value: float) -> void:
	for need in c.needs:
		c.needs[need] = value


# Traits, emotions, memories, skills and greetings (scripted, after the run).
func check_people() -> void:
	var w: Node2D = main.world
	var sam := person("Sam")
	var alex := person("Alex")
	var riley := person("Riley")
	for c in [sam, alex, riley]:
		reset(c, c.home_cell)
		c.moodlets.clear()
		c.memories.clear()
		set_needs(c, 50.0)  # no need moodlets either way

	check(sam.decay.social > player.decay.social and riley.decay.social < player.decay.social,
		"traits: Outgoing Sam gets lonely faster, Loner Riley slower")
	check(Traits.like(riley, "Bookshelf") > 1.0 and Traits.like(sam, "Bookshelf") == 1.0, "traits: Bookworm Riley likes the bookshelf")

	check(Emotions.emotion(sam) == "Fine", "no moodlets: feeling Fine")
	set_needs(sam, 80.0)
	Emotions.update(sam)
	check(Emotions.emotion(sam) == "Happy" and Emotions.has(sam, "Content"), "all needs high: Content → Happy")
	sam.needs.hunger = 10.0
	Emotions.update(sam)
	check(Emotions.emotion(sam) == "Uncomfortable" and Emotions.has(sam, "Hungry"), "hungry: Uncomfortable")
	Emotions.add(sam, "Argued")
	check(Emotions.emotion(sam) == "Angry" and Social.available_interactions(sam, alex).any(func(i): return i.name == "Argue"),
		"after an argument: Angry, and arguing becomes possible")
	w.clock += 4 * 60.0
	Emotions.update(sam)
	check(not Emotions.has(sam, "Argued") and Emotions.emotion(sam) == "Uncomfortable", "moodlets wear off (Argued lasts 3 h)")
	Emotions.add(riley, "Good conversation")
	check(riley.moodlets[-1].strength > 1.0, "traits: Cheerful Riley feels Happy moodlets more strongly")

	set_needs(sam, 50.0)
	sam.moodlets.clear()
	alex.relationships["Sam"] = 30.0
	var comfort := interaction("Comfort")
	var could_before := Social.available_interactions(alex, sam).has(comfort)
	Emotions.add(sam, "Insulted")
	check(not could_before and Emotions.emotion(sam) == "Sad" and Social.available_interactions(alex, sam).has(comfort),
		"you can only Comfort someone who is Sad")
	Social.finish(alex, sam, comfort)
	check(not Emotions.has(sam, "Insulted") and Emotions.emotion(sam) == "Happy", "being comforted replaces Sad with Happy")

	var chat := interaction("Chat")
	riley.moodlets.clear()
	var before := Social.accept_chance(sam, riley, chat)
	Social.remember(riley, sam, "insulted me", -3.0)
	var grudge := Social.accept_chance(sam, riley, chat)
	w.clock += 4 * DAY
	check(grudge < before and Social.recent_feeling(riley, sam) == 0.0,
		"a fresh grudge makes Riley less likely to accept (%.2f → %.2f), and it fades after 3 days" % [before, grudge])

	alex.moodlets.clear()
	Social.finish(sam, alex, interaction("Argue"))
	var mem: Array = Social.memories_of(alex, sam)
	check(Emotions.emotion(alex) == "Angry" and not mem.is_empty() and mem[-1].text == "argued with me",
		"after an argument both are Angry and Alex remembers it")
	Perception.greet(sam, alex)
	check(sam.emote.begins_with("*glares"), "you glare at someone you just argued with")

	sam.greeted.clear()
	sam.moodlets.clear()
	riley.relationships["Sam"] = 20.0
	sam.relationships["Riley"] = 20.0
	sam.known["Riley"] = true
	Perception.greet(sam, riley)
	var first: String = sam.emote
	sam.emote = ""
	Perception.greet(sam, riley)
	check(first.contains("{who}!") and sam.emote == "", "greeting a friend once, not again right away (%s)" % first)

	for c in [player, alex, riley]:
		c.moodlets.clear()
		set_needs(c, 50.0)
	Skills.set_level(player, "Cooking", 0)
	player.practice("Cooking", 10.0)
	check(Skills.level(player, "Cooking") == 1 and Emotions.has(player, "Skill level up")
		and Social.event_log[-1].text.contains("reached Cooking level 1"), "10 minutes of cooking: Cooking level 1, Confident, logged")
	check(menu_entry(player, object_named("Fridge", 0), "Pasta").disabled, "Pasta needs Cooking 2")
	Skills.set_level(player, "Cooking", 2)
	var xp_alex: float = alex.skills.get("Cooking", 0.0)
	var xp_riley: float = riley.skills.get("Cooking", 0.0)
	Skills.add_xp(alex, "Cooking", 10.0)
	Skills.add_xp(riley, "Cooking", 10.0)
	check(is_equal_approx(alex.skills.Cooking - xp_alex, 1.5 * (riley.skills.Cooking - xp_riley)), "Foodie Alex learns cooking 1.5× faster")

	var rolls := {0: {"Burnt": 0, "Good": 0, "Delicious": 0}, 8: {"Burnt": 0, "Good": 0, "Delicious": 0}}
	for lvl in rolls:
		Skills.set_level(riley, "Cooking", lvl)
		for n in 500:
			rolls[lvl][Skills.cooking_quality(riley)] += 1
	check(rolls[0].Burnt > 100 and rolls[8].Burnt == 0 and rolls[8].Delicious > rolls[0].Delicious * 5,
		"skilled cooks burn nothing and make delicious food (%s)" % [rolls])
	Skills.set_level(sam, "Comedy", 10)
	Skills.set_level(riley, "Comedy", 0)
	Skills.set_level(riley, "Fitness", 10)
	check(Skills.joke_chance(sam) > Skills.joke_chance(riley) and Skills.speed_multiplier(riley) > 1.2,
		"Comedy makes jokes land, Fitness makes you faster")


# Life stages, schools, growing up, fertility, babies, college, getting fired.
func check_life() -> void:
	var w: Node2D = main.world
	var mia := person("Mia")
	var lily := person("Lily")
	var noah := person("Noah")
	var alex := person("Alex")
	var sam := person("Sam")
	check([Ages.stage_name(lily), Ages.stage_name(mia), Ages.stage_name(noah), Ages.stage_name(player), Ages.stage_name(alex)]
		== ["Toddler", "Child", "Teen", "Young adult", "Adult"], "life stages: toddler Lily, child Mia, teen Noah, young adult you, adult Alex")
	check(Ages.years(mia) > 7.9 and Ages.years(mia) < 13.0 and Ages.years(player) > 19.9 and Ages.years(player) < 26.0,
		"ages in years (after a few days of ageing): Mia %.1f, you %.1f" % [Ages.years(mia), Ages.years(player)])
	check(Ages.family(alex, mia) and Ages.family(mia, lily) and not Ages.family(alex, sam) and Social.friendship(alex, mia) >= 50.0,
		"families: Alex is Mia's mother, Mia and Lily are sisters, and they love each other")
	check(not Kitchen.options(lily, 1).size() and Kitchen.options(mia, 1).all(func(o): return o.name != "Coffee" and not (o.name in Kitchen.RECIPES and Kitchen.RECIPES[o.name].station == "Stove")),
		"toddlers don't cook; children can't use the stove or make coffee")
	check(not Jobs.can_take(noah, "Café") and Jobs.can_take(player, "Café") and Jobs.can_take(player, "College"),
		"teens can't take jobs; young adults can work or go to college")

	# Growing up.
	for c in [mia, lily, noah, sam, player]:
		reset(c, c.home_cell)
		c.moodlets.clear()
		set_needs(c, 60.0)
	lily.age_days = Ages.stage_start(Ages.CHILD) - 0.5
	lily.job = "Kindergarten"
	noah.age_days = Ages.stage_start(Ages.YOUNG_ADULT) - 0.5
	noah.job = "High school"
	var lily_traits: int = lily.traits.size()
	for c in main.get_tree().get_nodes_in_group("characters"):
		if not c in [lily, noah]:
			c.age_days -= Life.AGING_SPEED  # keep everyone else's age the same
	Life.new_day(w)
	check(Ages.stage_name(lily) == "Child" and lily.job == "School" and Emotions.has(lily, "Birthday") and lily.traits.size() == lily_traits + 1,
		"Lily grows into a Child: Birthday, starts School, gains a trait")
	check(Ages.stage_name(noah) == "Young adult" and noah.job == "", "Noah grows into a Young adult and leaves high school")

	# Fertility.
	var old_alex: float = alex.age_days
	check(Ages.fertile(alex) and Ages.fertile(sam) and not Ages.fertile(mia), "fertile: adult woman and young man yes, child no")
	alex.age_days = Ages.days_for_years(52)
	check(not Ages.fertile(alex) and Ages.stage(alex) == Ages.ADULT, "menopause: a 52-year-old woman can't get pregnant")
	alex.age_days = old_alex

	# Trying for a baby: you (F) and Sam (M), close friends, at home.
	player.relationships["Sam"] = 80.0
	sam.relationships[player.npc_name] = 80.0
	player.known["Sam"] = true
	sam.known[player.npc_name] = true
	var baby_i := interaction("Try for a baby")
	check(Social.available_interactions(player, sam).has(baby_i), "close friends of opposite sexes at home: Try for a baby is possible")
	player.relationships["Mia"] = 90.0
	player.relationships["Alex"] = 90.0
	check(not Social.available_interactions(player, mia).has(baby_i) and not Social.available_interactions(player, alex).has(baby_i),
		"never with a child, nor between two women")
	reset(sam, Vector2(500, 513))
	check(not Social.available_interactions(player, sam).has(baby_i), "not outside: only at home")
	reset(sam, Vector2(489, 505))
	var tries := 0
	while player.pregnant_until < 0.0 and tries < 40:
		Life.try_for_baby(player, sam)
		tries += 1
	check(player.pregnant_until > w.now() and Emotions.has(player, "Expecting") and not Life.can_have_baby(player, sam),
		"you got pregnant (after %d tries); no second pregnancy meanwhile" % tries)
	var before_people: int = main.get_tree().get_nodes_in_group("characters").size()
	w.clock += Life.PREGNANCY_DAYS * 24 * 60.0 + 1.0
	player._process(0.0)
	var people: Array = main.get_tree().get_nodes_in_group("characters")
	var baby: Node2D = people[-1]
	check(people.size() == before_people + 1 and Ages.stage(baby) == Ages.BABY and baby.parents == [player.npc_name, "Sam"]
		and baby.home == 0 and Social.friendship(baby, player) >= 50.0 and Emotions.has(sam, "New baby"),
		"after 3 days the baby is born at home: %s, parents %s and Sam" % [baby.npc_name, player.npc_name])
	var spot: Vector2 = baby.grid_pos
	baby.needs.hunger = 10.0
	baby._process(0.5)
	baby.look_around()
	baby._process(0.5)
	check(baby.grid_pos == spot and baby.needs.hunger < 11.0 and Emotions.has(baby, "Crying") and baby.activity == "Crying",
		"babies stay put, can't feed themselves, and cry when hungry")
	Social.finish(player, baby, interaction("Feed"))
	baby.look_around()
	check(baby.needs.hunger >= 79.0 and not Emotions.has(baby, "Crying"), "feeding the baby fills hunger and stops the crying")
	var with_baby: Array = Social.available_interactions(player, baby).map(func(i): return i.name)
	check(with_baby.has("Feed") and with_baby.has("Hug") and not with_baby.has("Chat") and not with_baby.has("Flirt"),
		"with a baby you can hug, play, feed, change and rock, nothing else (%s)" % [with_baby])

	# College and a degree.
	reset(player, Vector2(488, 504))
	Jobs.take_job(player, "College")
	player.college_days = Jobs.COLLEGE_DAYS - 1
	player.shift_started = w.now() - 3600.0
	player.at_work = true
	Jobs.finish_shift(player)
	check(player.degree and player.job == "" and Emotions.has(player, "Graduated"), "14 days of college: graduated")
	Jobs.take_job(player, "Office")
	check(player.job_level == 1 and Jobs.title(player) == "Analyst", "with a degree you start a level up (Analyst)")

	# Fired.
	player.performance = 20.0
	Jobs.change_performance(player, -5.0)
	var warned: bool = player.warned and player.job == "Office"
	Jobs.change_performance(player, -5.0)
	check(warned and player.job == "" and Emotions.has(player, "Fired"), "a bad shift at low performance: warning; the next one: fired")
	check(Jobs.grade(95) == "A" and Jobs.grade(65) == "C" and Jobs.grade(20) == "F", "school grades A–F")
	mia.money = 0
	player.money = 100
	Jobs.new_day(w, 28)  # a Monday
	check(mia.money == 0 and player.money == 100 - Jobs.BILL, "only grown-ups pay the bills")
	check(Social.format_event({"text": "{a} grew up into a Young adult", "a": noah, "b": noah}, null).ends_with("Young adult")
		and Social.format_event({"text": "{a} → {b}: Chat", "a": sam, "b": player}, null).ends_with(player.npc_name + ": Chat"),
		"log text uses real names ('Young adult' stays intact)")


func names(a: Node2D, b: Node2D) -> Array:
	return Social.available_interactions(a, b).map(func(i): return i.name)


# Flirting → dating → engaged → married (moving in) → jealousy → divorce.
func check_romance() -> void:
	var riley := person("Riley")
	var sam := person("Sam")
	var alex := person("Alex")
	var mia := person("Mia")
	for c in [player, riley, sam, alex]:
		reset(c, Vector2(488 + randi_range(0, 3), 504))
		c.moodlets.clear()
		set_needs(c, 70.0)
		c.romance.clear()
		c.lover = ""
		c.lover_status = ""
	player.money = 100
	player.relationships["Riley"] = 40.0
	riley.relationships[player.npc_name] = 40.0
	player.known["Riley"] = true
	riley.known[player.npc_name] = true
	check(Romance.possible(player, alex) and not Romance.possible(player, mia) and not Romance.possible(alex, mia),
		"romance: any two grown-ups (also two women), never with children or family")
	check(names(player, riley).has("Flirt") and not names(player, riley).has("Kiss"), "you can flirt; kissing needs romance 30")
	for n in 5:
		Social.finish(player, riley, interaction("Flirt"))
	check(Romance.romance(player, riley) >= 30.0 and names(player, riley).has("Kiss") and Emotions.has(player, "Flirted"),
		"after flirting: romance %d, Flirty, and kissing unlocks" % Romance.romance(player, riley))
	for n in 2:
		Social.finish(player, riley, interaction("Kiss"))
	Social.finish(player, riley, interaction("Ask to be partners"))
	player.look_around()
	check(Romance.are_lovers(player, riley) and player.lover_status == "Dating" and Emotions.has(player, "In a relationship"),
		"Ask to be partners: dating (and happy about it)")
	check(not names(sam, riley).has("Ask to be partners"), "someone who's taken can't be asked out")
	Romance.change(player, riley, 30.0)
	Social.finish(player, riley, interaction("Propose"))
	check(player.lover_status == "Engaged" and riley.lover_status == "Engaged", "Propose (romance 70+): engaged")
	check(names(player, riley).has("Get married"), "engaged and at home: you can get married")
	Social.finish(player, riley, interaction("Get married"))
	check(player.lover_status == "Married" and riley.home == player.home and riley.original_home == 2,
		"married: Riley moves into your house")

	var flirt := interaction("Flirt")
	sam.relationships[player.npc_name] = 40.0
	sam.romance[player.npc_name] = 20.0
	var taken := Social.accept_chance(sam, player, flirt)
	riley.seen = [player]
	Social.finish(player, sam, flirt)
	var mems: Array = Social.memories_of(riley, player)
	check(Emotions.has(riley, "Jealous") and Romance.romance(riley, player) < 60.0 and mems[-1].text == "was romantic with someone else",
		"Riley saw you flirting with Sam: jealous, less romance, remembers it")
	riley.lover = ""
	var free := Social.accept_chance(sam, player, flirt)
	riley.lover = player.npc_name
	check(taken < free, "people who are taken accept romance less (%.2f vs %.2f)" % [taken, free])
	riley.romance[player.npc_name] = -10.0
	check(names(riley, player).has("Divorce"), "angry and out of love: divorce becomes possible")
	Social.finish(riley, player, interaction("Divorce"))
	check(player.lover == "" and riley.lover == "" and riley.home == 2 and Emotions.has(player, "Heartbroken"),
		"divorced: single again, Riley moves back home, you're heartbroken")


# Apologize, prank, gift, caring decisions, the baby panel.
func check_everyday() -> void:
	var sam := person("Sam")
	var alex := person("Alex")
	var lily := person("Lily")
	for c in [player, sam, alex, lily]:
		reset(c, c.home_cell)
		c.moodlets.clear()
		set_needs(c, 70.0)
	alex.memories.clear()
	check(not names(player, alex).has("Apologize"), "nothing to apologize for: no Apologize")
	Social.remember(alex, player, "insulted me", -3.0)
	check(names(player, alex).has("Apologize"), "Alex holds a grudge: you can apologize")
	Social.finish(player, alex, interaction("Apologize"))
	check(Social.recent_feeling(alex, player) >= 0.0 and Emotions.has(alex, "Made up"), "apology accepted: the grudge is gone")

	player.money = 100
	Social.finish(player, sam, interaction("Give a gift"))
	check(player.money == 80 and Emotions.has(sam, "Got a gift"), "a gift costs $20 and makes Sam happy")
	var pranked := false
	var before := Social.friendship(sam, player)
	for n in 60:
		Social.finish(player, sam, interaction("Prank"))
		if Emotions.has(sam, "Pranked"):
			pranked = true
			break
	check(pranked, "pranks sometimes backfire (Sam got angry)")

	var baby: Node2D = main.get_tree().get_nodes_in_group("characters").filter(func(c): return Ages.stage(c) == Ages.BABY)[0]
	set_needs(baby, 70.0)
	baby.needs.hunger = 5.0
	var feed := Social.interaction_score(sam, baby, interaction("Feed"))
	var play := Social.interaction_score(sam, baby, interaction("Play with"))
	check(feed > 50.0 and feed > play and names(sam, baby).has("Feed") and not names(alex, baby).has("Feed"),
		"Sam wants to feed his hungry baby (score %d > play %d); Alex isn't family" % [feed, play])
	check(Social.choose_interaction(sam, baby).name in ["Feed", "Hug", "Play with", "Change & clean", "Rock to sleep"],
		"what Sam does with the baby is a caring thing")

	var hud: CanvasLayer = main.hud
	hud.show_child(baby)
	hud.update_child_panel()
	check(hud.child_panel.visible and not hud.child_buttons["Feed"].disabled and absf(hud.child_bars["hunger"][0].value - baby.needs.hunger) < 1.0,
		"clicking your baby shows their needs on the left, with care buttons")
	lily.age_days = Ages.stage_start(Ages.TODDLER) + 1.0  # make her a toddler again for this check
	hud.show_child(lily)
	hud.update_child_panel()
	check(hud.child_buttons["Feed"].disabled, "you can't feed someone else's toddler")
	hud.child_panel.visible = false


# Depression, anxiety, isolation, burn-out, support, recovery, and learning from experience.
func check_mind() -> void:
	var w: Node2D = main.world
	var sam := person("Sam")
	var alex := person("Alex")
	for c in [sam, alex]:
		reset(c, c.home_cell)
		c.moodlets.clear()
		c.mood_samples.clear()
		c.learned.clear()
		set_needs(c, 60.0)
		c.last_social = w.now()
		c.work_log.clear()
	var chat := interaction("Chat")
	var accept_before := Social.accept_chance(alex, sam, chat)
	Emotions.add(sam, "Heartbroken")
	for n in 30:
		Mind.sample(sam)
	check(Emotions.has(sam, "Depressed") and Emotions.emotion(sam) == "Sad",
		"30 sad hours in a row: Sam becomes Depressed")
	var logic: float = sam.skills.get("Logic", 0.0)
	Skills.add_xp(sam, "Logic", 10.0)
	var learned_xp: float = sam.skills.Logic - logic
	check(Social.accept_chance(alex, sam, chat) < accept_before and Mind.bonus(sam, "performance") < 0.0 and learned_xp < 40.0,
		"depression: less open to others, worse at work, learns slower (%.0f xp instead of 40)" % learned_xp)

	alex.relationships["Sam"] = 40.0
	check(names(alex, sam).has("Talk about feelings"), "a friend can talk Sam through it")
	Social.finish(alex, sam, interaction("Talk about feelings"))
	check(Emotions.has(sam, "Supported") and Mind.share(sam, ["Sad"]) < 1.0, "support helps: Supported, and the worst hours weigh less")
	sam.moodlets = sam.moodlets.filter(func(m): return m.name != "Heartbroken")
	Emotions.add(sam, "Just married")
	for n in 30:
		Mind.sample(sam)
	check(not Emotions.has(sam, "Depressed"), "after many good hours the depression lifts")

	Emotions.add(alex, "Warned at work")
	Emotions.add(alex, "Missed work")
	for n in 30:
		Mind.sample(alex)
	check(Emotions.has(alex, "Anxious") and Mind.multiplier(alex, "sleep") < 1.0, "tense for days: Alex becomes Anxious and sleeps worse")
	alex.last_social = w.now() - 50.0 * 3600.0
	alex.work_log = [[w.now(), 9.0], [w.now(), 9.0], [w.now(), 9.0]]
	Mind.update(alex)
	check(Emotions.has(alex, "Isolated") and Emotions.has(alex, "Burned out"), "no real conversation for 2 days: Isolated; 27 h of work in 3 days: Burned out")

	sam.moodlets.clear()
	Emotions.add(sam, "Got a gift")
	for n in 4:
		Mind.learn_from_feeling(sam, "TV")
	var likes_tv := Mind.learned(sam, "TV")
	Emotions.add(sam, "Heartbroken")
	Mind.learn_from_feeling(sam, "Bookshelf")
	check(likes_tv >= 1.19 and Mind.learned(sam, "Bookshelf") < 1.0 and Mind.tastes(sam).contains("likes TV"),
		"learning from experience: things that felt good become favourites (%s)" % Mind.tastes(sam))


# Build mode: catalog rules, buying, rotating, blocking, selling, moving, and people using what you buy.
func check_build() -> void:
	var w: Node2D = main.world
	reset(player, Vector2(488, 504))
	player.money = 1000
	check(Catalog.why_not(player, "sofa", Vector2i(482, 503), 0, 0) != "" and Catalog.why_not(player, "plant_fern", w.door_inside(0), 0, 0) != ""
		and Catalog.why_not(player, "plant_fern", Vector2i(483, 500), 0, 0) != "" and Catalog.why_not(player, "sofa", Vector2i(500, 504), 0, 0) != "",
		"you can't build in walls, the doorway, on the stairs, or outside your home")
	var sofa: Node2D = Catalog.place(player, "sofa", Vector2i(489, 506), 1, 0)
	check(sofa != null and player.money == 650 and sofa.is_in_group("smart_objects") and sofa.use_cell() == Vector2i(489, 506)
		and w.is_walkable(Vector2i(489, 506), 0), "buying a sofa ($350): placed and usable; you sit on it (its tile stays walkable)")
	var sam := person("Sam")
	check(sam.may_use(sofa) and sofa.advertisements.has("fun"), "your housemates can relax on it")
	check(Catalog.place(player, "plant_fern", Vector2i(485, 501), 0, 0) == null, "you can't put a plant in front of the fridge (it would block it)")
	check(Catalog.place(player, "rug", Vector2i(485, 501), 0, 0) != null, "a rug is fine there (you can walk on it)")
	player.money = 10
	check(Catalog.place(player, "bed_king", Vector2i(490, 504), 0, 0) == null, "you can't buy what you can't afford")
	player.money = 650
	var back := Catalog.sell(player, sofa)
	check(back == 262 and player.money == 912 and not sofa.is_in_group("smart_objects") and w.is_walkable(Vector2i(489, 506), 0),
		"selling the sofa gives 75%% back ($%d) and frees the tile" % back)
	var plant := Catalog.thing_at(player, Vector2i(492, 500), 0)
	check(plant != null and Catalog.id_of(plant) == "plant_fern", "the fern in your house is recognised as a catalog item")
	Catalog.remove(player, plant)
	var moved := Catalog.place(player, "plant_fern", Vector2i(490, 506), 0, 0, true)
	check(moved != null and player.money == 912, "moving it somewhere else is free")
	var bookshelf := Catalog.place(player, "bookshelf", Vector2i(484, 505), 1, 0)
	check(bookshelf != null and bookshelf.use_cell() == Vector2i(485, 505) and bookshelf.skill == "Logic",
		"a bought bookshelf works like the others (reading, Logic)")
	# Walls and stairs (Build category).
	var wall: Node2D = Catalog.place(player, "wall", Vector2i(490, 502), 0, 0)
	check(wall != null and wall.wall and not w.is_walkable(Vector2i(490, 502), 0) and w.blocks_sight(Vector2i(490, 502), 0),
		"building a wall: it blocks the tile and the view")
	check(Catalog.sell(player, wall) > 0 and w.is_walkable(Vector2i(490, 502), 0) and not w.blocks_sight(Vector2i(490, 502), 0),
		"selling the wall frees the tile and the view")
	check(Catalog.why_not(player, "stairs", Vector2i(490, 502), 0, 0) == "This house already has an upper floor",
		"no second stairs in a house that has an upper floor")
	var alex := person("Alex")
	alex.money = 2000
	var stair_cell := Vector2i(505, 507)
	check(w.BUILDINGS[1].floors == 1 and Catalog.place(alex, "stairs", stair_cell, 0, 0) != null and w.BUILDINGS[1].floors == 2
		and w.floor_nodes[1].size() == 2 and alex.money == 500, "building stairs in Alex's one-storey house adds an upper floor ($1500)")
	check(not w.find_path(w.door_inside(1), 0, Vector2i(504, 502), 1, alex).is_empty(), "the new upper floor can be reached by the stairs")
	var saved: Array = w.building_state()
	var upstairs_plant: Node2D = Catalog.place(alex, "plant_fern", Vector2i(504, 502), 0, 1)
	check(Catalog.remove_stairs(alex) == -1, "the stairs can't be removed while something is upstairs")
	Catalog.remove(alex, upstairs_plant)
	check(Catalog.remove_stairs(alex) == 1125 and w.BUILDINGS[1].floors == 1 and w.floor_nodes[1].size() == 1,
		"once upstairs is empty, the stairs come out again (75% back)")
	w.apply_building_state(saved)
	check(w.BUILDINGS[1].floors == 2 and w.BUILDINGS[1].stairs == stair_cell, "a saved house gets its built stairs back")
	w.apply_building_state(World.START_BUILDINGS.map(func(b): return {"floors": b.floors, "stairs": b.get("stairs", Vector2i(-1, -1)), "built_stairs": false}))
	check(w.BUILDINGS[1].floors == 1, "and loses them again with the start state")

	var toilet := object_named("Toilet", 0)
	check(Actions.for_object(toilet).map(func(a): return a.name) == ["Pee", "Poo"]
		and Actions.for_object(object_named("Bed", 0)).map(func(a): return a.name) == ["Sleep", "Nap", "Relax in bed"],
		"furniture has its own interactions: toilet Pee/Poo, bed Sleep/Nap/Relax")
	player.needs.bladder = 10.0
	player.use_object(toilet, Actions.for_object(toilet)[1])
	var seen := run_task(player)
	check(seen.has("Pooping") and player.needs.bladder >= 85.0, "you can choose Poo: 'Pooping', bladder %d" % player.needs.bladder)
	var chair := object_named("Chair", 0)
	player.use_object(chair)
	until_using(player)
	check(player.cell() == Vector2i(chair.grid_pos) and w.is_walkable(chair.use_cell(), 0), "you sit on a chair (on its own tile)")
	player.cancel_current()
	var nap: Dictionary = Actions.for_object(object_named("Bed", 0))[1]
	reset(player, Vector2(488, 504))
	player.use_object(object_named("Bed", 0), nap)
	until_using(player)
	check(not Perception.is_awake(player) and main.is_sleeping(player), "napping counts as sleeping")
	player.cancel_current()
	var picked := {}
	for n in 60:
		player.needs.bladder = 30.0
		var options := Actions.for_object(toilet).map(func(a): return [a.name, player.advertisement_score(a.ads) * randf_range(0.85, 1.15)])
		options.sort_custom(func(a, b): return a[1] > b[1])
		picked[options[0][0]] = true
	check(picked.has("Pee") and picked.has("Poo"), "people sometimes pee, sometimes poo")

	var fridge := object_named("Fridge", 0)
	var couch := object_named("Couch", 0)
	var couch_sprite: String = couch.sprite
	check(not Catalog.rotate(player, fridge) and fridge.facing == 0, "you can't turn the fridge to face the counter")
	check(Catalog.rotate(player, couch) and couch.facing == 3 and couch.sprite != couch_sprite, "rotating the couch turns its sprite")
	var corner_plant := Catalog.thing_at(player, Vector2i(483, 507), 0)
	check(corner_plant != null and Catalog.rotate(player, corner_plant) and corner_plant.rotation_index == 1, "decor can be rotated too")
	main.build.toggle()
	var opened: bool = main.build.active and main.paused
	main.build.toggle()
	check(opened and not main.build.active and not main.paused, "B opens build mode (paused) and closes it again")


# Character sprites (looks.gd): everyone has a sheet; frames follow what they do.
func check_looks() -> void:
	var people: Array = main.get_tree().get_nodes_in_group("characters")
	var grown := people.filter(func(c): return Ages.stage(c) != Ages.BABY)
	check(grown.all(func(c): return c.body_sprite != null and c.body_sprite.texture != null and c.body_sprite.visible),
		"everyone (except babies) is drawn with a baked 3D character sheet")
	var babies := people.filter(func(c): return Ages.stage(c) == Ages.BABY)
	check(babies.all(func(c): return not c.body_sprite.visible and c.look in ["girl_a", "girl_b", "boy_a", "boy_b"]),
		"babies are drawn as a bundle and already have a look for when they grow up")
	reset(player, Vector2(488, 504))
	player.walk_to(Vector2i(491, 504), 0)
	for n in 5:
		player._process(0.1)
	var f: int = player.body_sprite.frame
	check(f / Looks.FRAMES == 2 and f % Looks.FRAMES >= Looks.WALK and f % Looks.FRAMES < Looks.WALK + 4,
		"walking towards +x: the +x row, a walk frame (%d)" % f)
	player.cancel_current()
	var chair := object_named("Chair", 0)
	player.use_object(chair)
	until_using(player)
	player._process(0.0)
	check(player.body_sprite.frame % Looks.FRAMES == Looks.SIT, "sitting on a chair uses the sitting frame")
	player.cancel_current()
	player.use_object(object_named("Bed", 0))
	until_using(player)
	player._process(0.0)
	check(player.body_sprite.frame % Looks.FRAMES == Looks.LIE and player.body_sprite.position != Vector2.ZERO,
		"sleeping: lying down, drawn on the bed")
	player.cancel_current()
	check(Looks.direction(Vector2(0, 1)) == 0 and Looks.direction(Vector2(-1, 0)) == 6 and Looks.direction(Vector2(1, -1)) == 3,
		"facing directions map to sheet rows")


func check_death() -> void:
	var riley := person("Riley")
	var noah := person("Noah")
	noah.moodlets.clear()
	riley.age_days = Ages.days_for_years(riley.death_years) - 0.5
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c != riley:
			c.age_days -= Life.AGING_SPEED
	Life.new_day(main.world)
	var graves := main.get_tree().get_nodes_in_group("smart_objects").filter(func(o): return o.object_name == "Grave of Riley")
	check(riley.dead and not riley.is_in_group("characters") and graves.size() == 1 and Emotions.has(noah, "Grieving"),
		"Riley died of old age at %d: gone, a grave appears, his son Noah grieves" % int(riley.death_years))
	check(Social.event_log.any(func(e): return e.text.contains("passed away")), "the death is in the social log")
	var me := player
	var sam := person("Sam")
	var ctrl: Node = main.controller
	var family: Array = ctrl.household().map(func(c): return c.npc_name)
	check(family.has(me.npc_name) and family.has("Sam") and not family.has("Alex"), "your household: the people in your home %s" % [family])
	ctrl.take_control(sam)
	var switched: bool = main.player == sam and sam.controlled and not me.controlled and ctrl.camera.get_parent() == sam \
		and sam.is_in_group("player") and not me.is_in_group("player")
	check(switched, "switching control to Sam: camera, HUD and view follow him")
	ctrl.take_control(me)
	me.auto_mode = false
	Life.die(me)
	var my_grave := main.get_tree().get_nodes_in_group("smart_objects").filter(func(o): return o.object_name == "Grave of " + me.npc_name)
	check(me.dead and my_grave.size() == 1 and main.player == sam and sam.controlled and not me.controlled and main.world.player == sam,
		"no game over: you die, become a grave, and carry on as %s from your household" % main.player.npc_name)


# Replace the running game with a fresh one started the way the session says.
func restart_game() -> void:
	root.remove_child(main)
	main.free()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.player


# Save → load round trip, deleting saves, a new household, choosing a household, the creator's rules.
func check_saving() -> void:
	var slot := "check_sim_test"
	var before := {}
	for c in main.get_tree().get_nodes_in_group("characters"):
		before[c.npc_name] = [c.money, c.relationships.duplicate(), Ages.stage(c), c.look, c.skills.duplicate()]
	var objects_before: int = main.get_tree().get_nodes_in_group("smart_objects").size()
	var clock_before: float = main.world.clock
	var me: String = main.player.npc_name
	var log_before: int = Social.event_log.size()
	check(SaveGame.save(main, slot) and SaveGame.list().any(func(s): return s.slot == slot), "the game saves, and the save is listed")
	Session.reset()
	Session.mode = "load"
	Session.save_data = SaveGame.read(slot)
	restart_game()
	var after := {}
	for c in main.get_tree().get_nodes_in_group("characters"):
		after[c.npc_name] = [c.money, c.relationships, Ages.stage(c), c.look, c.skills]
	check(after.keys().size() == before.keys().size() and after.keys().all(func(n): return before.has(n) and str(before[n]) == str(after[n])),
		"loading brings everyone back with their money, relationships, age, look and skills (%d people)" % after.size())
	check(main.player.npc_name == me and main.world.clock == clock_before
		and main.get_tree().get_nodes_in_group("smart_objects").size() == objects_before and Social.event_log.size() == log_before,
		"same person controlled, same time, same furniture (%d objects), same social log" % objects_before)
	SaveGame.delete(slot)
	check(not SaveGame.list().any(func(s): return s.slot == slot), "deleting a save removes it")

	Session.reset()
	Session.mode = "new"
	Session.new_household = {"name": "The Meows", "members": [
		{"name": "Mimi", "sex": "F", "stage": "Adult", "look": "girl_b", "traits": ["Cheerful"]},
		{"name": "Tom", "sex": "M", "stage": "Child", "look": "boy_a", "traits": []}]}
	restart_game()
	var tom := person("Tom")
	check(main.player.npc_name == "Mimi" and main.player.home == main.STARTER_HOUSE and main.player.money == main.STARTING_FUNDS
		and tom.parents == ["Mimi"] and tom.job == "School" and main.household_name == "The Meows",
		"a new household moves into the starter house: Mimi ($%d) and her son Tom (at school)" % main.player.money)
	check(main.controller.household().size() == 2 and person("Jo") != null, "your household is Mimi and Tom; Jo still lives on the street")

	Session.reset()
	Session.household = 1
	restart_game()
	check(main.player.npc_name == "Alex" and main.household_name == "Alex's family", "choosing Alex's family: you play Alex")

	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	menu.show_create()
	menu.members[0].name.text = "Sam"
	menu.household_edit.text = "The Meows"
	var taken: Dictionary = menu.read_household()
	menu.members[0].name.text = "Mimi"
	menu.members[0].age.select(0)  # a child alone
	var no_adult: Dictionary = menu.read_household()
	menu.members[0].age.select(3)
	var ok: Dictionary = menu.read_household()
	check(taken.is_empty() and no_adult.is_empty() and ok.get("name") == "The Meows" and ok.members[0].stage == "Adult",
		"the household creator refuses taken names and households without a grown-up")
	menu.free()
	Session.reset()


# Set the clock to `hour` on game day `day` (0 = day 1, a Monday).
func set_time(day: int, hour: float) -> void:
	main.world.clock = (day * 86400.0 + hour * 3600.0 - GameTime.START_HOUR * 3600.0) / 60.0 / GameTime.MINUTES_PER_SECOND


# Jobs, shifts, pay, performance, promotion, prices and bills.
func check_jobs() -> void:
	var w: Node2D = main.world
	reset(player, Vector2(488, 504))
	player.auto_mode = false
	player.money = 300
	player.moodlets.clear()
	set_needs(player, 60.0)
	set_time(15, 6.0)  # a Tuesday morning, before work
	Jobs.take_job(player, "Café")
	check(player.job == "Café" and Jobs.title(player) == "Barista" and Jobs.hourly(player) == 15, "you can take a job: Barista at the Café")

	set_time(15, 8.2)
	player._process(0.0)
	check(Jobs.should_work(player, w.now()) and player.reminded_day == 15 and player.state == "idle",
		"Manual mode: at 08:00 you get a reminder, you don't go by yourself")
	player.go_to_work()
	player.follow_path(100.0)
	w.update_view()
	check(player.at_work and player.state == "working" and not player.visible, "at the bus stop you leave for work (hidden)")
	set_time(15, 14.0)
	player._process(0.0)
	check(not player.at_work and player.money == 300 + int(round(5.8 * 15)) and Emotions.has(player, "Payday") and player.performance > 0.0,
		"at 14:00 you come back paid for the hours worked ($%d) with better performance (%d)" % [player.money - 300, player.performance])
	check(not Jobs.should_work(player, w.now()), "one shift per day")

	var perf: float = player.performance
	set_time(16, 13.6)
	player._process(0.0)
	check(player.performance < perf and Emotions.has(player, "Missed work"), "missing a shift costs performance and makes you Tense")

	player.performance = 95.0
	Skills.set_level(player, "Charisma", 2)
	Jobs.change_performance(player, 10.0)
	check(player.job_level == 1 and Jobs.title(player) == "Shift lead" and Emotions.has(player, "Promoted"), "performance 100 + Charisma 2: promoted to Shift lead")
	player.performance = 95.0
	Jobs.change_performance(player, 10.0)
	check(player.job_level == 1 and player.performance == 100.0, "no promotion to manager without Charisma 4")

	player.auto_mode = true
	set_time(17, 8.1)
	player._process(0.0)
	check(player.pending_work and player.state == "walking", "Auto mode: you go to work by yourself")
	player.auto_mode = false
	reset(player, Vector2(488, 504))

	w.kitchens[0] = {"plate": Kitchen.PLATES, "cup": Kitchen.CUPS}
	var fridge := object_named("Fridge", 0)
	player.money = 3
	var pasta := menu_entry(player, fridge, "Pasta")
	check(pasta.disabled and "can't afford" in pasta.label and not Kitchen.options(player, 0).any(func(o): return o.name == "Pasta")
		and not menu_entry(player, object_named("Sink", 0), "Water").get("disabled", true),
		"with $3 you can't buy pasta ($8), but tap water is free")
	player.money = 20
	player.do_task(Kitchen.cook_steps(player, 0, "Pasta"))
	run_task(player)
	check(player.money == 12, "cooking pasta costs $8 (left: $%d)" % player.money)

	player.money = 100
	Jobs.new_day(w, 21)  # a Monday
	var after_bills: int = player.money
	Jobs.new_day(w, 22)
	check(after_bills == 100 - Jobs.BILL and player.money == after_bills, "bills: $%d every Monday, not other days" % Jobs.BILL)
	player.money = -5
	player.look_around()
	check(Emotions.has(player, "Broke"), "below $0 you feel Broke")


# Homes, invitations, knocking, guests leaving, and the relationships drawer.
func check_ownership() -> void:
	var w: Node2D = main.world
	var alex := person("Alex")
	var sam := person("Sam")
	for c in [player, alex, sam]:
		reset(c, c.home_cell)
		c.moodlets.clear()
		set_needs(c, 60.0)
	player.building = 0
	w.guests.clear()

	var inside_alex := Vector2i(504, 503)
	check(not w.can_enter(player, 1) and w.can_enter(alex, 1) and w.can_enter(player, 0), "you may enter your home, not Alex's")
	check(w.find_path(Vector2i(500, 513), 0, inside_alex, 0, player).is_empty()
		and not w.find_path(Vector2i(500, 513), 0, inside_alex, 0, alex).is_empty(),
		"paths: you can't walk into Alex's house, Alex can")

	player.cancel_current()
	player.grid_pos = Vector2(w.door_outside(1))
	player.building = -1
	alex.known[player.npc_name] = true
	alex.relationships[player.npc_name] = -60.0
	var low := Ownership.answer_chance(alex, player)
	alex.relationships[player.npc_name] = 60.0
	var high := Ownership.answer_chance(alex, player)
	alex.known.erase(player.npc_name)
	var stranger := Ownership.answer_chance(alex, player)
	alex.known[player.npc_name] = true
	check(low < 0.2 and high > 0.9 and stranger == Ownership.STRANGER_CHANCE,
		"letting you in depends on friendship (%.2f / %.2f), strangers rarely (%.2f)" % [low, high, stranger])

	Ownership.knock(player, 1)
	check(w.can_enter(player, 1) or player.activity == "Turned away", "knocking: Alex answers")
	w.guests.clear()
	player.cancel_current()
	Ownership.knock(player, 1)
	if player.state == "knocking":  # turned away by bad luck: answer again, yes
		Ownership.answer(alex, player, 1, true)
	check(w.can_enter(player, 1) and player.state == "walking" and player.walk_target == Vector2(w.door_inside(1)),
		"let in: you're invited and walk inside")
	check(not w.find_path(player.cell(), 0, inside_alex, 0, player).is_empty(), "invited: now there's a path in")

	player.cancel_current()
	player.grid_pos = Vector2(inside_alex)
	player.building = 1
	w.clock += (Ownership.INVITE_HOURS + 1.0) * 60.0
	player._process(0.0)
	check(not w.can_enter(player, 1) and player.state == "walking" and player.walk_target == Vector2(w.door_outside(1)),
		"when the invitation runs out you walk out (%s)" % player.activity)

	player.cancel_current()
	reset(alex, Vector2(502, 509))  # just outside his own door
	alex.relationships[player.npc_name] = 40.0
	player.relationships["Alex"] = 40.0
	player.known["Alex"] = true
	var invite := interaction("Invite over")
	check(Social.available_interactions(player, alex).has(invite) and not Social.available_interactions(player, sam).has(invite),
		"you can invite Alex over, not Sam (he lives with you)")
	Social.finish(player, alex, invite)
	check(w.can_enter(alex, 0), "after Invite over, Alex may come into your house")

	reset(player, Vector2(488, 504))
	reset(alex, Vector2(489, 505))  # visiting you
	var ask := interaction("Ask to leave")
	check(Social.available_interactions(player, alex).has(ask), "you can ask a guest in your home to leave")
	Social.finish(player, alex, ask)
	alex.think_delay = 0.0
	alex._process(0.0)
	check(not w.can_enter(alex, 0) and alex.activity.begins_with("Leaving"), "asked to leave: Alex walks out (%s)" % alex.activity)

	var riley := person("Riley")
	reset(riley, Vector2(w.door_outside(0)))
	player.known["Riley"] = true
	player.auto_mode = false
	Ownership.knock(riley, 0)
	var menu: PopupMenu = main.controller.menu
	var asked: bool = menu.item_count > 0 and menu.get_item_text(0).contains("knocking")
	menu.hide()
	Ownership.answer(player, riley, 0, false)
	check(asked and riley.state == "idle" and riley.activity == "Turned away" and Emotions.has(riley, "Rejected"),
		"an NPC knocks on your door: you're asked, and turning them away hurts")

	var hud: CanvasLayer = main.hud
	hud.toggle_relationships()
	hud.fill_drawer()
	check(hud.drawer.visible and hud.drawer_list.get_child_count() == npcs().size(), "the relationships drawer lists everyone (%d)" % hud.drawer_list.get_child_count())
	hud.toggle_relationships()


# Pause and speeds (Engine.time_scale), and fast-forward while you sleep.
func check_speed() -> void:
	main.set_speed(0)
	main.toggle_pause()
	var paused_scale := Engine.time_scale
	main.toggle_pause()
	check(paused_scale == 0.0 and Engine.time_scale == 1.0 and not main.paused, "pause stops time; unpausing resumes 1x")
	main.set_speed(3)
	main.toggle_pause()
	main.toggle_pause()
	check(Engine.time_scale == 60.0, "unpausing returns to the chosen speed (Ultra 60x)")
	main.set_speed(1)
	check(Engine.time_scale == 5.0 and main.speed_text() == "Fast (5x)", "speed 2 is Fast 5x")

	main.auto_sleep_speed = true
	player.cancel_current()
	player.step = {"verb": "Sleeping", "seconds": 1.0, "asleep": true}
	player.state = "using"
	main._process(0.0)
	var asleep_scale := Engine.time_scale
	var asleep_text: String = main.speed_text()
	player.state = "idle"
	player.step = {}
	main._process(0.0)
	check(asleep_scale == 60.0 and "sleep" in asleep_text and Engine.time_scale == 5.0,
		"time runs at Ultra while you sleep, then back to your speed (%s)" % asleep_text)
	main.auto_sleep_speed = false
	main.set_speed(0)


# Step one character (and the world clock) by hand until its task is done. Returns the activities seen.
func run_task(c: Node2D, max_seconds := 120.0) -> Array:
	var seen := []
	var n := 0
	while (c.state != "idle" or not c.steps.is_empty()) and n < max_seconds * 10:
		c._process(0.1)
		main.world.clock += 0.1
		if seen.is_empty() or seen[-1] != c.activity:
			seen.append(c.activity)
		n += 1
	return seen


# Step a character by hand until they start using something (or a minute of game time passes).
func until_using(c: Node2D) -> void:
	for n in 600:
		if c.state == "using":
			return
		c._process(0.1)
		main.world.clock += 0.1


func menu_entry(c: Node2D, obj: Node2D, starts_with: String) -> Dictionary:
	for e in Kitchen.menu(c, obj, c.do_task):
		if e.has("label") and e.label.begins_with(starts_with):
			return e
	return {}


# Cooking, eating, washing, drinks, spoiling, leftovers, running out of plates, NPCs eating.
func check_kitchen() -> void:
	var w: Node2D = main.world
	var sam: Node2D = npcs().filter(func(c): return c.npc_name == "Sam")[0]
	reset(sam, Vector2(490, 503))
	player.cancel_current()
	player.auto_mode = false
	player.floor = 0
	player.grid_pos = Vector2(488, 504)
	player.building = 0
	for o in main.get_tree().get_nodes_in_group("smart_objects"):
		o.items.clear()
		o.user = null
	w.kitchens[0] = {"plate": Kitchen.PLATES, "cup": Kitchen.CUPS}
	player.money = 300
	var fridge := object_named("Fridge", 0)
	var counter := object_named("Counter", 0)
	var table := object_named("Table", 0)

	check(not menu_entry(player, fridge, "Pasta").is_empty() and not menu_entry(player, fridge, "Juice").is_empty(),
		"the fridge menu lists food and drinks")
	player.needs.hunger = 20.0
	player.do_task(Kitchen.cook_steps(player, 0, "Pasta"))
	var seen := run_task(player)
	var order := ["Getting ingredients", "Making pasta", "Eating pasta", "Washing the plate"]
	check(order.all(func(v): return seen.has(v)) and seen.find("Washing the plate") > seen.find("Eating pasta"),
		"cooking pasta: fridge → stove → eat at the table → wash the plate (%s)" % [seen])
	var q: String = counter.items[0].quality if not counter.items.is_empty() else "Good"
	check(player.needs.hunger >= minf(100.0, 20.0 + 65.0 * Kitchen.QUALITY[q].hunger) - 5.0,
		"eating fresh %s pasta filled hunger (%.0f)" % [q.to_lower(), player.needs.hunger])
	check(w.kitchens[0].plate == Kitchen.PLATES - 1 and counter.items.size() == 1 and counter.items[0].recipe == "Pasta",
		"pasta makes 2 servings: one leftover on the counter, one plate washed (%d clean plates)" % w.kitchens[0].plate)
	check(player.held.is_empty(), "hands are empty after washing up")

	var item: Dictionary = counter.items[0]
	var fresh := Kitchen.freshness(item, w.now())
	w.clock += 7 * 60.0  # 7 game hours: pasta spoils after 12
	var stale := Kitchen.freshness(item, w.now())
	w.clock += 6 * 60.0
	var spoiled := Kitchen.freshness(item, w.now())
	var ads := Kitchen.eat_ads(item, w.now())
	var quality: float = Kitchen.QUALITY[item.quality].hunger
	check([fresh, stale, spoiled] == ["Fresh", "Stale", "Spoiled"] and is_equal_approx(ads.hunger, 65 * 0.3 * quality) and ads.bladder == -20,
		"leftover pasta goes fresh → stale → spoiled, and spoiled food is worth less and hurts (%s, %s)" % [[fresh, stale, spoiled], ads])
	check(not Kitchen.options(sam, 0).any(func(o): return o.name.begins_with("leftover")), "NPCs don't consider spoiled leftovers")

	menu_entry(player, counter, "Throw away").action.call()
	run_task(player)
	check(counter.items.is_empty() and w.kitchens[0].plate == Kitchen.PLATES, "throwing away food, then washing the plate")

	player.needs.thirst = 20.0
	player.do_task(Kitchen.drink_steps(player, 0, "Juice"))
	run_task(player)
	check(player.needs.thirst >= 65.0 and w.kitchens[0].cup == Kitchen.CUPS,
		"juice filled thirst (%.0f) and the cup was washed" % player.needs.thirst)

	w.kitchens[0].plate = 0
	var pasta := menu_entry(player, fridge, "Pasta")
	check(pasta.disabled and "no clean plates" in pasta.label, "no clean plates: you can't cook")
	w.kitchens[0].plate = Kitchen.PLATES

	player.do_task(Kitchen.cook_steps(player, 0, "Sandwich"))
	for n in 600:
		if player.held.get("kind") == "food":
			break
		player._process(0.1)
		w.clock += 0.1
	player.cancel_current()
	var put: Array = table.items + counter.items
	check(player.held.is_empty() and put.size() == 1 and put[0].recipe == "Sandwich",
		"interrupted after cooking: the sandwich is put down, not lost")

	for need in sam.needs:
		sam.needs[need] = 100.0
	sam.needs.hunger = 10.0
	var meals: int = Kitchen.meals_eaten
	for n in 900:
		sam._process(0.1)
		w.clock += 0.1
	check(Kitchen.meals_eaten > meals and sam.needs.hunger > 25.0,
		"hungry Sam makes or finds food and eats on his own (hunger %.0f)" % sam.needs.hunger)
	run_task(sam, 60.0)
	check(sam.held.is_empty() and sam.state != "using", "Sam finishes his meal and washes up (not stuck: %s)" % sam.activity)


# Doors, windows, peeking, line of sight and NPC reactions, around Alex's house.
# The language model (llm.gd) with a fake server: written lines, thoughts, wishes, typing to someone.
# Headless runs never contact a real server, so `fake` answers every request.
var llm_requests := []


func fake_llm(request: Dictionary) -> String:
	llm_requests.append(request)
	var props: Dictionary = request.schema.get("properties", {})
	if props.has("line"):
		return '{"line": "Rough day, huh? Want some tea?", "reply": "Tea fixes everything."}'
	if props.has("choice"):
		return JSON.stringify({"choice": "TV" if "TV" in props.choice.enum else props.choice.enum[0], "why": "Too tired for anything else"})
	if props.has("reply"):
		return '{"reply": "Hey you! Nice to see a friendly face.", "tone": "nice"}'
	return "<think></think>\"I really need a nap.\""


func check_llm() -> void:
	var llm: Node = main.llm
	var sam := person("Sam")
	var alex := person("Alex")
	reset(sam, Vector2(484, 503))
	player.cancel_current()
	player.floor = 0
	player.grid_pos = Vector2(485, 503)
	player.building = main.world.building_at(player.cell(), 0)
	main.world.update_view()
	var chat := interaction("Chat")

	check(not llm.online and llm.status_text().begins_with("AI: off"), "AI: offline in tests until a fake server is set")
	check(not llm.ask([], 10, {}, func(_t): pass), "AI offline: requests are refused, so the scripted lines stay")
	llm.online = true
	llm.fake = fake_llm

	check(Llm.clean_line("Sam: \"Hi there!\"\n") == "Hi there!" and Llm.strip_thinking("<think>hm</think>Yo") == "Yo",
		"AI: model text is cleaned (no name prefix, quotes, thinking)")
	player.known.erase("Alex")
	var stranger := Llm.who(alex, player)
	check(stranger.begins_with("a stranger") and not "Alex" in stranger and "Alex" in Llm.who(alex),
		"AI: a stranger's name isn't given to the model (%s)" % stranger.substr(0, 40))
	check("Outgoing" in Llm.who(sam) and "sees Jo as" in Llm.relation(sam, player), "AI: prompts carry traits and how they see each other")

	# A conversation near you gets a written line and a reply.
	for pair in [[sam, player], [player, sam]]:
		pair[0].partner = pair[1]
		pair[0].state = "talking"
	sam.is_initiator = true
	sam.interaction = chat
	sam.talk_timer = chat.duration
	llm.conversation(sam, player, chat, "How's your day going?")
	llm.pump()
	check(sam.emote.begins_with("\"Rough day") and sam.emote_with == player, "AI: Sam says the written line (%s)" % sam.emote.replace("\n", " "))
	llm.replied(player, sam, "Tea fixes everything.")
	check(player.emote == "\"Tea fixes everything.\"", "AI: the partner replies with the written reply")
	sam.end_social()
	sam.emote = ""
	llm.said(sam, player, {"line": "Too late", "reply": ""})
	check(sam.emote == "", "AI: a line that arrives after the conversation ended is dropped")
	var fast := chat.duplicate()
	fast.duration = 2.0
	var before := llm_requests.size()
	llm.conversation(sam, player, fast, "Hi")
	check(llm_requests.size() == before and llm.queue.is_empty(), "AI: conversations too short for a line to arrive aren't sent")

	# Thoughts and wishes.
	sam.emote_timer = 0.0
	main.world.update_view(true)  # sight is worked out every 150 ms of real time: now
	check(llm.think(sam), "AI: asked for Sam's thought")
	llm.pump()
	check(sam.thought == "I really need a nap." and sam.emote.begins_with("~ I really"), "AI: Sam thinks (%s)" % sam.thought)
	check(llm.wish(sam), "AI: asked what Sam feels like doing")
	llm.pump()
	var options: Array = llm_requests[-1].schema.properties.choice.enum
	check("social" in options and not "Fridge" in options and not "Bus stop" in options and sam.wish in options and Llm.wish_factor(sam, sam.wish) == Llm.WISH_BOOST
		and Llm.wish_factor(sam, "nothing") == 1.0, "AI: Sam wants to %s (×%.1f): one of %s" % [Llm.wish_text(sam), Llm.WISH_BOOST, options])
	sam.wish_until = main.world.now() - 1.0
	check(Llm.wish_factor(sam, sam.wish) == 1.0 and Llm.wish_text(sam) == "", "AI: wishes wear off after %d hours" % Llm.WISH_HOURS)
	llm.wished(sam, {"choice": "Rocket ship", "why": ""}, {"TV": ""})
	check(sam.wish_until < main.world.now(), "AI: a choice that isn't one of the options is ignored")

	# Typing to someone.
	reset(alex, Vector2(486, 503))
	alex.known.erase(player.npc_name)
	player.known.erase("Alex")
	alex.relationships[player.npc_name] = 0.0
	alex.memories.clear()
	var hud: CanvasLayer = main.hud
	check(Llm.can_talk(player, alex) and not Llm.can_talk(player, person("Lily")), "AI: you can talk to Alex next to you, not to a far-away toddler")
	hud.talk.open(player, alex)
	check(hud.talk.visible and alex.state == "talking" and alex.partner == player and player.partner == alex,
		"talk panel: you and Alex stop to talk")
	hud.talk.send("Hi! I just moved in next door.")
	llm.pump()
	check(llm_requests[-1].messages[-1].content == "Hi! I just moved in next door." and not "Jo" in llm_requests[-1].messages[0].content.get_slice("The other person:", 1),
		"talk panel: your words are sent, and Alex doesn't know your name yet")
	check(Social.friendship(alex, player) == Llm.TONE.nice and hud.talk.history.size() == 2 and alex.emote.begins_with("\"Hey you!"),
		"talk panel: Alex answers, and a nice message raises friendship (%d)" % Social.friendship(alex, player))
	hud.talk.close()
	check(not hud.talk.visible and alex.state == "idle" and player.partner == null and player.known.has("Alex")
		and Social.memories_of(alex, player).any(func(m): return m.text == "talked with me" and m.feeling > 0),
		"talk panel: closing it, you've met, and Alex remembers a nice talk")
	check(Social.event_log[-1].text == "{a} talked with {b}", "talk panel: the talk is logged")

	# The HUD: Today (left tab) and Passport (right tab) are hidden until you open them.
	check(not hud.today_panel.visible and not hud.passport.visible and hud.today_tab.text == ">" and hud.passport_tab.text == "<",
		"HUD: Today and Passport start hidden behind their tabs")
	hud.today_tab.pressed.emit()
	hud.passport_tab.pressed.emit()
	var tv: Node2D = object_named("TV", 0)
	player.use_object(tv)
	player.state = "using"
	player.target_object = tv
	player.step = {"object": tv, "verb": "Watching TV", "seconds": 30.0}
	player.use_timer = 12.0
	player.activity = "Watching TV"
	var today: Array = hud.today_items(player)
	hud.update_passport()
	check(hud.today_panel.visible and hud.passport.visible and today[0].now and today[0].title == "Watching TV" and today[0].sub == "TV · 12 min",
		"HUD: the tabs open them; Today starts with what you're doing (%s, %s)" % [today[0].title, today[0].sub])
	check(hud.name_label.text == player.npc_name and hud.activity_pct.text == "60%" and hud.bars.size() == 7,
		"HUD: the passport shows you, your needs and how far along you are (%s)" % hud.activity_pct.text)
	hud.today_tab.pressed.emit()
	hud.passport_tab.pressed.emit()
	check(not hud.today_panel.visible and not hud.passport.visible, "HUD: clicking the tabs again hides them")
	player.cancel_current()

	# Talking to a real person (online: another player): no AI, your words are passed on.
	reset(alex, Vector2(486, 503))
	alex.controlled = true  # pretend someone is playing Alex
	var asked := llm_requests.size()
	var before_f := Social.friendship(alex, player)
	check(Talk.open(player, alex) and alex.partner == player, "talk with a real person: you both stop to talk")
	Talk.say(player, "Hey neighbour!", [{"you": true, "text": "Hey neighbour!"}])
	check(llm_requests.size() == asked and Social.friendship(alex, player) == before_f + Llm.TONE[Talk.HUMAN_TONE],
		"talk with a real person: no AI answer, a little friendship")
	Talk.close(player)
	alex.controlled = false
	check(alex.partner == null and player.partner == null and Social.memories_of(alex, player)[-1].text == "talked with me",
		"talk with a real person: closing ends it and they remember it")

	# Labels show only "Name - Mood"; what people say goes to the chat feed.
	check(alex.label_text() == "Alex - " + Emotions.describe(alex) and player.label_text() == "Jo - " + Emotions.describe(player),
		"labels: only name and mood (%s)" % alex.label_text())
	alex.known.erase(player.npc_name)
	player.known.erase("Alex")
	check(alex.label_text() == "", "labels: nothing over a stranger's head")
	check(not hud.ours_event({"a": alex, "b": person("Riley")}) and hud.ours_event({"a": alex, "b": player}),
		"events: only those involving your household show")
	hud.chat.clear()
	main.world.update_view(true)
	alex.show_emote("Good morning, {who}!", player)
	alex.show_emote("Good morning, {who}!", player)
	sam.show_emote("~ I really need a nap. ~", null)
	var far := person("Lily")
	far.show_emote("Waaah!", null)
	check(hud.chat.size() == 2 and hud.chat_text(hud.chat[0]) == "Unknown: Good morning, you!"
		and hud.chat_text(hud.chat[1]) == "Sam thinks: I really need a nap.",
		"chat feed: what you hear, once, names as you know them (%s)" % [hud.chat.map(hud.chat_text)])
	llm.fake = Callable()
	llm.online = false


# Seeing like your sim (vision.gd): walls, the cone, the dark, lamps, fog.
func check_vision() -> void:
	var w: Node2D = main.world
	var v: Node2D = w.vision
	w.weather = "Clear"
	w.weather_until = w.now() + 99999.0
	set_time(2, 12.0)
	reset(player, Vector2(488, 504))  # in the living room, facing the back wall (-y, no windows there)
	player.facing_dir = 4
	w.update_view(true)
	check(v.sees(Vector2i(488, 501), 0) and v.sees(Vector2i(488, 499), 0) and not v.sees(Vector2i(488, 497), 0),
		"vision: you see your room and its wall, not through the wall")
	check(v.sees(Vector2i(488, 502), 0) and v.remembers(Vector2i(488, 502), 0), "vision: what you see is remembered")
	reset(player, Vector2(492, 514))  # outside on the road, facing along it (+x)
	player.facing_dir = 2
	w.update_view(true)
	check(v.sees(Vector2i(512, 514), 0), "vision: by day you see far down the road")
	check(v.sees(Vector2i(490, 514), 0) and not v.sees(Vector2i(480, 514), 0), "vision: behind you, only close by")
	w.weather = "Fog"
	w.update_view(true)
	check(not v.sees(Vector2i(512, 514), 0) and v.sees(Vector2i(498, 514), 0), "vision: in fog you see much less (%.0f tiles)" % v.sight_range(true))
	w.weather = "Clear"
	set_time(2, 23.5)
	w.update_view(true)
	check(not v.sees(Vector2i(500, 514), 0) and v.sees(Vector2i(494, 514), 0), "vision: at night only a few tiles (%.1f)" % v.sight_range(true))
	var sam := person("Sam")
	reset(sam, Vector2(502, 514))
	w.update_view(true)
	check(not sam.visible, "vision: someone in the dark further away isn't shown")
	set_time(2, 12.0)
	w.update_view(true)
	check(sam.visible, "vision: by day you see them")
	reset(sam, sam.home_cell)
	reset(player, Vector2(488, 504))
	w.update_view(true)


# The body (body.gd): running and tripping, passing out, fainting, accidents, farts, illness, throwing up.
func check_body() -> void:
	var sam := person("Sam")
	var riley := person("Riley")
	for c in [sam, riley]:
		reset(c, Vector2(486, 503))
		c.moodlets.clear()
		set_needs(c, 60.0)
		c.illness = ""
		c.next_fart = main.world.now() + 99999.0
	riley.grid_pos = Vector2(488, 503)
	riley.building = 0
	sam.seen = [riley]
	riley.seen = [sam]

	sam.needs.bladder = 10.0
	check(Body.wants_to_run(sam) and not Body.wants_to_run(riley), "body: bursting Sam runs, Riley (fine) walks")
	sam.running = true
	var run_speed: float = sam.walk_speed()
	sam.running = false
	check(is_equal_approx(run_speed, sam.walk_speed() * Body.RUN_SPEED), "body: running is %.1f× faster" % Body.RUN_SPEED)
	sam.needs.bladder = 60.0

	Body.go_down(sam, "tripped", "Tripped")
	sam.cancel_current()
	check(sam.state == "down" and sam.pose == "down" and Emotions.has(sam, "Tripped") and not sam.is_available(),
		"body: tripping puts you on the floor (embarrassed, busy, orders can't pick you up)")
	sam.pose_until = main.world.now() - 1.0
	Body.update(sam, 1.0)
	check(sam.pose == "" and sam.state == "idle", "body: and you get back up")

	sam.needs.energy = 0.0
	Body.update(sam, 1.0)
	check(sam.pose_reason == "passed out", "body: energy at 0: passed out on the floor")
	Body.update(sam, 60.0)
	check(sam.needs.energy > 10.0, "body: sleeping it off on the floor brings some energy back (%d)" % sam.needs.energy)
	Body.get_up(sam)
	sam.needs.energy = 60.0

	sam.needs.hunger = 0.0
	Body.update(sam, 1.0)
	check(sam.pose_reason == "fainted", "body: hunger at 0: fainted")
	sam.pose_until = main.world.now() - 1.0
	Body.update(sam, 1.0)
	check(sam.pose == "" and sam.needs.hunger >= Body.FAINT_HUNGER, "body: wakes up, still hungry (%d)" % sam.needs.hunger)

	riley.moodlets.clear()
	sam.needs.bladder = 0.0
	sam.needs.hygiene = 80.0
	Body.update(sam, 1.0)
	check(sam.needs.bladder == 100.0 and sam.needs.hygiene <= 30.0 and Emotions.has(sam, "Had an accident") and Emotions.has(riley, "Grossed out"),
		"body: bladder at 0: an accident (hygiene %d), and Riley saw it" % sam.needs.hygiene)

	riley.moodlets.clear()
	riley.grid_pos = Vector2(487, 503)
	Body.fart(sam)  # Sam is a Goofball: finds it funny
	check(Emotions.has(sam, "Funny fart") and Emotions.has(riley, "Grossed out") and sam.next_fart > main.world.now(),
		"body: Goofball Sam farts and laughs; Riley is grossed out; the next one is planned")

	for n in 50:
		Body.ate(riley, "Spoiled")
	check(riley.illness == "Food poisoning" and riley.ill_until > main.world.now(), "body: spoiled food: food poisoning")
	var hunger_before: float = riley.needs.hunger
	Body.throw_up(riley)
	check(riley.pose == "bent" and riley.needs.hunger < hunger_before and Emotions.has(riley, "Threw up"), "body: throwing up (bent over, hungrier)")
	Body.get_up(riley)
	Emotions.update(riley, {"Sick": riley.illness != ""})
	var sick_speed: float = riley.walk_speed()
	riley.illness = ""
	var well_speed: float = riley.walk_speed()
	riley.illness = "Food poisoning"
	check(Emotions.has(riley, "Sick") and sick_speed < well_speed and Body.energy_decay(riley) > 1.0,
		"body: sick: feels Sick, walks slower, tires faster")
	riley.ill_until = main.world.now() - 1.0
	Body.illness_update(riley, 1.0, false)
	check(riley.illness == "" and Emotions.has(riley, "Feeling better"), "body: and gets better")
	riley.moodlets.clear()

	# Drawing walls: a drag is a straight line along the longer direction.
	check(BuildMode.line_cells(Vector2i(0, 0), Vector2i(3, 1)) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
		and BuildMode.line_cells(Vector2i(2, 5), Vector2i(2, 3)).size() == 3, "build: dragging walls draws a straight line")
	for c in [sam, riley]:
		Body.get_up(c)
		reset(c, c.home_cell)


# Kenney art: every catalog sprite and look is baked, houses are sprite strips over click boxes, trees have sprites.
func check_art() -> void:
	var w: Node2D = main.world
	var missing := []
	for id in Catalog.ITEMS:
		for r in 4:
			var sprite := Catalog.sprite(id, r)
			if sprite != "" and not Furniture.has(sprite):
				missing.append(sprite)
	for look in Looks.LOOKS:
		if Looks.sheet(look) == null or Looks.face(look) == null:
			missing.append(look)
	check(missing.is_empty(), "every catalog item is baked in 4 rotations and every look has a sheet and a face (missing: %s)" % [missing])
	var strips: Array = w.exteriors[1].get_children().filter(func(n): return n is Sprite2D)
	var boxes: Array = w.exteriors[1].get_children().filter(func(n): return not n is Sprite2D)
	check(strips.size() > 10 and boxes.all(func(b): return b.under_sprite), "a house is its baked sprite in strips, over invisible click boxes")
	var front := Iso.to_screen(Vector2(w.door_outside(1)))
	var near: Array = strips.filter(func(s): return absf(s.position.x + 8.0 - front.x) < 24.0)
	check(not near.is_empty() and near.all(func(s): return s.position.y < front.y),
		"strips by the door sort behind someone standing outside it")
	var season: String = w.season
	w.season = "Winter"
	w.build_exterior(1)
	var snowy: Sprite2D = w.exteriors[1].get_children().filter(func(n): return n is Sprite2D)[0]
	check(snowy.texture.resource_path.ends_with("house_1_1_winter.png"), "winter rebuilds a house with a snowy roof")
	w.season = season
	w.build_exterior(1)
	var trees := []
	for k in w.chunks:
		trees += w.chunks[k].get_children().filter(func(n): return n.get("kind") == "tree")
	check(not trees.is_empty() and trees.all(func(t): return t.has_sprite), "trees show their baked sprites (%d)" % trees.size())


func check_peeking() -> void:
	var w: Node2D = main.world
	var alex: Node2D = npcs().filter(func(c): return c.npc_name == "Alex")[0]
	var window := Vector2i(500, 508)
	reset(alex, Vector2(500, 505))
	player.cancel_current()
	player.floor = 0
	player.grid_pos = Vector2(500, 511)
	player.building = -1
	w.update_view()

	var door_hit: Dictionary = w.exterior_hit(Iso.to_screen(Vector2(502, 508)) + Block.face_point("left", 0.5, 20.0))
	var hit: Dictionary = w.exterior_hit(Iso.to_screen(Vector2(window)) + Block.face_point("left", 0.5, 30.0))
	var roof: Dictionary = w.exterior_hit(Iso.to_screen(Vector2(503, 503)) + Vector2(0, -56))
	check(door_hit.get("kind") == "door" and hit.get("kind") == "window" and hit.get("cell") == window
		and roof.get("kind") == "wall", "clicking a house finds its door, a window, or plain wall")
	player.click_building(roof)
	check(player.state == "idle", "clicking a wall doesn't take you inside")
	check(w.has_line_of_sight(Vector2i(500, 510), Vector2i(500, 505), 0)
		and not w.has_line_of_sight(Vector2i(501, 510), Vector2i(501, 505), 0), "windows let sight through, walls don't")

	player.click_building(hit)
	player.follow_path(10.0)
	w.update_view()
	check(player.state == "peeking" and player.grid_pos == Vector2(500, 509), "clicking a window walks you there to peek")
	check(not w.exteriors[1].visible and w.floor_nodes[1][0].visible, "peeking shows the inside instead of the exterior")
	check(object_named("Fridge", 1).visible and not object_named("TV", 1).visible,
		"peeking: only objects in line of sight show (Fridge yes, TV around the corner no)")
	check(alex.visible, "peeking: Alex, in front of the window, is visible")
	alex.grid_pos = Vector2(506, 501)
	w.update_view()
	check(not alex.visible, "peeking: Alex, out of sight in the corner, is hidden")
	alex.grid_pos = Vector2(500, 505)
	check(Perception.can_see(alex, player), "Alex can see you through the window")

	for n in 50:
		Perception.notice(alex, player)
	check(alex.caught_peeks.size() == 1, "Alex notices one peek only once")

	alex.caught_peeks.clear()
	alex.relationships[player.npc_name] = 100.0
	alex.known[player.npc_name] = true
	for need in alex.needs:
		alex.needs[need] = 90.0
	var kind := Perception.react_to_peek(alex, player)
	check(kind == "wave" and alex.partner == player and player.state == "waiting",
		"a happy good friend waves and comes out to chat (%s)" % kind)

	alex.end_social()
	player.start_peeking(window)
	var shower := object_named("Shower", 1)
	alex.target_object = shower
	shower.user = alex
	alex.state = "using"
	alex.relationships[player.npc_name] = -50.0
	kind = Perception.react_to_peek(alex, player)
	w.update_view()
	check(kind == "yell" and w.is_window_closed(window) and alex.relationships[player.npc_name] <= -70.0,
		"caught at the shower by someone they dislike: yells, closes the curtains, friendship −20 (%s)" % kind)
	check(player.state != "peeking" and w.exteriors[1].visible, "closed curtains end your peek")
	alex.release_object()
	alex.target_object = object_named("Bed", 1)
	alex.step = {"verb": "Sleeping", "seconds": 60.0, "asleep": true}
	alex.state = "using"
	check(not Perception.is_awake(alex), "someone asleep in bed notices nothing")


func npcs() -> Array:
	return main.get_tree().get_nodes_in_group("characters").filter(func(c): return c != player)


func _process(delta: float) -> bool:
	t += delta
	if main.get_script() == null or (player == null and t > 5.0):
		print("FAILED: the main scene didn't load (see SCRIPT ERROR above)")
		quit(1)
		return true
	if player == null:
		player = main.player
		if player == null:
			return false
		main.auto_sleep_speed = false  # keep the simulation at 1x; checked separately in check_speed()
		start_needs = player.needs.duplicate()
		start_pos = player.grid_pos
		for c in main.get_tree().get_nodes_in_group("characters"):
			start_xp[c.npc_name] = c.skills.values().reduce(func(a, b): return a + b, 0.0)
		check_world()
		check_time()
		return false

	if not checked_unknown and t >= 1.0:
		checked_unknown = true
		for c in npcs():
			var housemate: bool = c.home == player.home
			var shown: String = c.npc_name if housemate else "Unknown"
			var label_ok: bool = c.label.text.begins_with(shown) if housemate else c.label.text == ""
			check(Social.display_name(player, c) == shown and label_ok,
				"%s shows as %s at the start (%s)" % [c.npc_name, shown, "your housemate" if housemate else "not met yet: nothing over their head"])
		check(object_named("Fridge", 0).is_visible_in_tree() and not object_named("Bed", 0).is_visible_in_tree(),
			"inside on the ground floor: the Fridge shows, the Bed upstairs doesn't")
		check(not main.world.exteriors[0].visible and main.world.chunk_root.visible and main.world.exteriors[1].visible,
			"inside: your house opens up, the neighbourhood and the other houses are still there")
		check(not npcs().filter(func(c): return c.npc_name == "Alex")[0].visible, "Alex (in his own house) is hidden")

	# Every frame: no object claimed twice, and track how long anyone waits for a conversation.
	var chars: Array = main.get_tree().get_nodes_in_group("characters")
	for obj in main.get_tree().get_nodes_in_group("smart_objects"):
		var claim := chars.filter(func(a): return a.target_object == obj)
		if claim.size() > 1 or (claim.size() == 1 and obj.user != claim[0]):
			conflicts += 1
	for c in chars:
		wait_time[c] = wait_time.get(c, 0.0) + delta if c.state == "waiting" else 0.0
		if c.state == "waiting":
			max_overrun = maxf(max_overrun, wait_time[c] - c.wait_limit)
		if c.floor > 0:
			went_upstairs[c.npc_name] = true
		if c.building < 0:
			went_outside[c.npc_name] = true
		emotions_seen[Emotions.emotion(c)] = true
		if c.building >= 0 and last_building.get(c, c.building) != c.building and not main.world.can_enter(c, c.building):
			trespasses += 1
		last_building[c] = c.building
		if c.at_work:
			went_to_work[c.npc_name] = true
		if c.state == "knocking" and c.knock_timer == Ownership.KNOCK_WAIT:
			knocks += 1
		if c.state == "using" and c.step.get("verb") == "Sleeping":
			slept[c.npc_name] = "night" if GameTime.is_night(main.world.now()) else "day"
	if t > 0.5:
		check_view()

	# Phase 0 (0-30s): manual player standing idle. Needs nobody refills drop at their own DECAY_HOURS rate.
	if phase == 0 and t >= 30.0:
		phase = 1
		for need in ["hunger", "thirst", "energy", "bladder", "hygiene"]:
			var dropped: float = start_needs[need] - player.needs[need]
			var expected: float = 30.0 * 100.0 / (player.DECAY_HOURS[need] * 60.0)
			check(absf(dropped - expected) < 0.05, "%s dropped by %.2f in 30 game minutes (empties in %dh; got %.3f)" % [
				need, expected, player.DECAY_HOURS[need], dropped])
		check(start_needs.thirst - player.needs.thirst > start_needs.energy - player.needs.energy,
			"thirst drops faster than energy")
		check(player.grid_pos == start_pos, "manual player did not walk on its own")

	# Phase 1: player orders a chat with an NPC.
	if phase == 1 and player.state == "idle":
		var free := npcs().filter(func(c): return c.partner == null and c.state in ["idle", "walking"] and main.world.can_enter(player, c.building) and Ages.is_grown_up(c))
		if not free.is_empty():
			var npc: Node2D = free[0]
			phase = 2
			friendship_before = Social.friendship(player, npc)
			player.order_interaction(npc, Social.INTERACTIONS[0])
			check(player.partner == npc and npc.state == "waiting", "ordering a chat makes %s wait for you" % npc.npc_name)

	# Phase 2: conversation resolves (completed or rejected) and friendship changes.
	if phase == 2 and player.partner == null:
		phase = 3
		var changed := false
		for c in npcs():
			changed = changed or Social.friendship(player, c) != 0.0
		check(changed, "player-initiated chat changed a friendship value")
		for c in npcs():
			var met: bool = player.known.has(c.npc_name)
			var expected: String = c.npc_name if met else "Unknown"
			check(Social.display_name(player, c) == expected,
				"%s shows as '%s' after the chat (met: %s)" % [c.npc_name, expected, met])
		player.toggle_mode()  # rest of the run: player lives on auto too

	if t >= SIM_SECONDS:
		var met_someone := false
		for c in npcs():
			var met: bool = player.known.has(c.npc_name)
			met_someone = met_someone or met
			check(Social.display_name(player, c) == (c.npc_name if met else "Unknown"),
				"end: %s's name is %s (met: %s)" % [c.npc_name, "shown" if met else "hidden", met])
		check(met_someone, "the player met at least one NPC in 15 minutes")
		check(conflicts == 0, "no object was ever claimed by two characters (%d conflicts)" % conflicts)
		check(max_overrun <= 0.05, "nobody waited longer than their wait_limit (worst overrun %.2fs)" % max_overrun)
		check(view_errors == 0, "people showed only when you could see them; other houses' rooms stayed hidden (%d errors)" % view_errors)
		check(not went_upstairs.is_empty(), "someone used the stairs: %s" % [went_upstairs.keys()])
		check(not went_outside.is_empty(), "someone went outside: %s" % [went_outside.keys()])
		check(not slept.is_empty(), "someone went to sleep: %s" % [slept])
		check(went_to_work.has("Mia") and went_to_work.has("Noah") and went_to_work.has("Lily"),
			"the kids went to School, High school and Kindergarten on Monday: %s" % [went_to_work.keys()])
		var riley := person("Riley")
		check(went_to_work.has("Riley") and not riley.at_work and riley.money > 600,
			"Riley went to the office (Mon 9-17) by herself and came back paid ($%d)" % riley.money)
		check(chars.all(func(c): return c.mood_samples.size() >= 12 or Ages.stage(c) <= Ages.TODDLER),
			"everyone's mind kept track of how they felt every hour (%s samples)" % [chars.map(func(c): return c.mood_samples.size())])
		check(trespasses == 0, "nobody ever walked into a home they weren't invited to (%d)" % trespasses)
		print("  (knocks during the run: %d)" % knocks)
		check(emotions_seen.size() >= 3, "people felt different emotions during the day: %s" % [emotions_seen.keys()])
		var learned := chars.filter(func(c): return c.skills.values().reduce(func(a, b): return a + b, 0.0) > start_xp[c.npc_name])
		check(not learned.is_empty(), "people practised skills on their own: %s" % [learned.map(func(c): return c.npc_name)])
		var remembered := chars.filter(func(c): return not c.memories.is_empty())
		check(not remembered.is_empty(), "people remember things about each other: %s" % [remembered.map(func(c): return c.npc_name)])
		var completed := Social.event_log.filter(func(e): return "→" in e.text)
		check(completed.size() > 0, "NPCs completed social interactions (%d in last log)" % completed.size())
		print("\nLast social events:\n  " + "\n  ".join(Social.event_log.map(func(e): return Social.format_event(e, null))))
		print("\nFinal state after %d simulated minutes:" % int(SIM_SECONDS / 60))
		for c in chars:
			var n := []
			for need in c.needs:
				n.append("%s %d" % [need.substr(0, 3), c.needs[need]])
			print("  %-5s %-28s %s  %s  rel=%s" % [c.npc_name, c.activity, ", ".join(n), main.world.location_name(c), c.relationships])
			print("        feeling %s (%s); skills %s; %d memories" % [Emotions.describe(c), Emotions.reasons(c, 3), Skills.summary(c), c.memories.size()])
		check(Kitchen.meals_eaten + Kitchen.drinks_drunk > 0,
			"people ate or drank on their own (%d meals, %d drinks)" % [Kitchen.meals_eaten, Kitchen.drinks_drunk])
		check_speed()
		check_people()
		check_ownership()
		check_jobs()
		check_life()
		check_romance()
		check_everyday()
		check_mind()
		check_build()
		check_looks()
		check_kitchen()
		check_streaming()
		check_art()
		check_peeking()
		check_llm()
		check_vision()
		check_body()
		check_death()  # you die in it
		check_saving()  # replaces the game several times: keep it last
		print("\n%s (%d failure%s)" % ["ALL PASSED" if failures == 0 else "FAILED", failures, "" if failures == 1 else "s"])
		quit(1 if failures > 0 else 0)
	return false
