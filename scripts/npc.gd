# A character driven by needs + utility AI. Any character can be the one you control
# (`controlled`, set by controller.gd): then it only acts on its own in Auto mode, takes your clicks
# (click_tile, click_building, order_interaction), can peek through windows, and doesn't react
# automatically to what it sees (you decide).
#
# Every need decays at its own rate (DECAY_HOURS, in game time). When idle, the character scores every option:
#   - each free smart object it may use (its home's, or outdoor ones) within CONSIDER_RADIUS,
#   - each kitchen option in its home (Kitchen.options: recipes, drinks, leftovers), and
#   - each available character within SOCIAL_RADIUS (by the social interaction it would pick with them),
# discounted by distance, then does the best one. If nothing scores above ACT_THRESHOLD it wanders
# near home.
#
# Movement: walk_to() asks the world for a path (Vector3i cells: x, y, floor) and follows it; passing
# the stairs cell changes `floor`. `building` is the building the character is in (-1 = outside).
#
# State machine (`state`):
#   idle     -> think() picks something to do
#   walking  -> following `path`; at the end: start the current step / start conversation / go idle
#   using    -> doing the current step at target_object; needs change gradually by the step's ads
#   queueing -> the next step's object is busy; wait for it (gives up after QUEUE_TIMEOUT)
#   waiting  -> someone is walking over to talk to us; we stand still (gives up after wait_limit)
#   talking  -> in a conversation; the initiator's talk_timer ends it via Social.finish()
#   knocking -> at someone's door waiting for an answer (ownership.gd)
#   working  -> away at their job (hidden; jobs.gd). They walk to the Bus stop first ("pending_work").
#
# Tasks are lists of steps (run_steps). A step is {object, verb, seconds, ads?, start?, done?}:
# walk to the object, call start, spend `seconds` there gaining `ads`, call done, next step.
# Using a TV is one step; cooking a meal is four (see kitchen.gd). `held` is what you're carrying.
#
# Homes: you may only go into your own home or one you're invited to (world.can_enter; paths go
# around the others). If you're inside somewhere you may no longer be, you walk out (leave_building).
# Wanting to talk to someone inside a home you can't enter means knocking on its door first.
#
# Being human (docs/PEOPLE.md): `traits` (traits.gd) change needs and preferences, `moodlets` give an
# emotion (emotions.gd) that changes behaviour, `skills` (skills.gd) grow with practice, and
# `memories` (social.gd) of what others did shape later conversations.
#
# Perception (perception.gd): every LOOK_INTERVAL the character looks around; `seen` lists who is in
# sight, and notice() reacts to anything interesting (e.g. someone peeking in through the window).
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Social = preload("res://scripts/social.gd")
const Perception = preload("res://scripts/perception.gd")
const Kitchen = preload("res://scripts/kitchen.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Skills = preload("res://scripts/skills.gd")
const Traits = preload("res://scripts/traits.gd")
const Ownership = preload("res://scripts/ownership.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Ages = preload("res://scripts/ages.gd")
const Life = preload("res://scripts/life.gd")
const Mind = preload("res://scripts/mind.gd")
const Actions = preload("res://scripts/actions.gd")
const Looks = preload("res://scripts/looks.gd")

const ACT_THRESHOLD := 5.0  # below this score nothing is worth doing, so wander
const NEEDS := ["hunger", "thirst", "energy", "fun", "bladder", "hygiene", "social"]
# Game hours for each need to drop from 100 to 0 when nothing refills it, so people drink and use
# the toilet several times a day, eat 2-3 times, and must sleep every night.
# Per real second at 1x: 100 / (hours × 60 / GameTime.MINUTES_PER_SECOND).
const DECAY_HOURS := {
	"bladder": 10.0,
	"thirst": 16.0,
	"energy": 18.0,  # hours awake before exhausted
	"fun": 20.0,
	"hunger": 24.0,
	"social": 30.0,
	"hygiene": 36.0,
}
const NIGHT_SLEEP_BONUS := 3.0  # beds (anything giving energy) score ×3 at night...
const DAY_SLEEP_PENALTY := 0.4  # ...and ×0.4 by day, so people sleep at night unless exhausted
const CONSIDER_RADIUS := 30.0  # objects farther than this (tiles) are ignored
const SOCIAL_RADIUS := 20.0  # people farther than this are ignored
const FLOOR_COST := 8.0  # a floor change counts as this many tiles when judging distance
const WANDER_RADIUS := 5
const HOME_LEASH := 12.0  # when wandering farther than this from home, head back
const WAIT_SLACK := 5.0  # a partner waits for the initiator's walking time plus this
const RETHINK_DELAY := 1.0  # after a plan fails (no path), wait this long before thinking again
const EMOTE_SECONDS := 4.0
const QUEUE_TIMEOUT := 15.0  # seconds to wait for a busy object before giving up the task

# Toggled with F3 in main.gd: shows every need value above each NPC.
static var show_details := false

var npc_name := "Sam"
var body_color := Color(0.95, 0.65, 0.35)
var grid_pos := Vector2(5, 5)
var floor := 0
var building := -1  # updated every frame from grid_pos + floor
var home := -1  # index in World.BUILDINGS; the only building whose objects this character uses
var home_cell := Vector2i.ZERO
var speed := 2.0  # tiles per second

var needs := {}  # need name -> 0..100 (100 = fully satisfied)
var decay := {}  # need name -> points lost per second
var relationships := {}  # other character's npc_name -> friendship -100..100 (see social.gd)
var known := {}  # npc_names this character has completed an interaction with (names are hidden until then)
var traits := []  # names from Traits.TRAITS
var skills := {}  # skill -> total xp (Skills)
var moodlets := []  # Emotions: {name, emotion, strength, until}
var memories := []  # Social.remember: {who, text, feeling, when}
var greeted := {}  # npc_name -> game time of the last greeting (Perception)
var mood_samples := []  # Mind: one emotion per game hour, the last 48
var next_sample := 0.0
var last_social := 0.0  # game time of the last completed interaction
var work_log := []  # [game time, hours] per shift (Mind: burn-out)
var learned := {}  # Mind: activity -> how much they've come to like it (×0.5..1.6)

var state := "idle"
var target_object: Node2D = null
var walk_target := Vector2.ZERO
var path := []  # Vector3i cells still to walk through
var pending_knock := -1  # building whose door we're walking to, to knock
var knock_building := -1  # building we're knocking at (state "knocking")
var knock_timer := 0.0
var knock_cooldown := {}  # building -> game time before which we won't knock again

# Life (ages.gd, life.gd)
var age_days := 40.0  # game days lived; decides the life stage
var sex := "F"
var parents := []  # npc_names of the parents
var pregnant_until := -1.0  # game time of the birth, -1 = not pregnant
var baby_father := ""
var death_years := 0.0  # age at which they die of old age (life.gd)
var dead := false
var napping := false  # babies sleep where they are

# Romance (romance.gd)
var romance := {}  # npc_name -> -100..100
var lover := ""  # npc_name of their partner/fiancé(e)/spouse
var lover_status := ""  # "Dating", "Engaged", "Married"
var original_home := -1  # where a spouse lived before moving in
var last_romance := -100000.0  # game time of the last romantic moment

# Money and work (jobs.gd)
var money := 0
var job := ""  # key of Jobs.JOBS, "" = unemployed
var job_level := 0
var performance := 0.0  # 0-100; promotion at 100
var at_work := false
var pending_work := false  # walking to the bus stop
var shift_day := -1  # game day of the last shift attended
var missed_day := -1
var shift_started := 0.0
var late := false
var reminded_day := -1  # the player gets one "time for work" reminder per day
var warned := false  # one more bad shift and you're fired
var degree := false  # graduated from college: new jobs start a level up
var college_days := 0
var use_timer := 0.0
var steps := []  # steps still to do after the current one
var step := {}  # the current step
var held := {}  # item being carried (kitchen.gd), {} if empty-handed
var queue_timer := 0.0
var think_delay := 0.0
var activity := "Idle"  # may contain "{who}", replaced by activity_with's name as the player knows it
var activity_with: Node2D = null

# Conversation state
var partner: Node2D = null
var interaction := {}
var is_initiator := false
var talk_timer := 0.0
var wait_timer := 0.0
var wait_limit := 0.0  # how long this wait was allowed to last

# Perception
var seen := []  # characters in sight at the last look
var look_timer := randf() * Perception.LOOK_INTERVAL  # spread looks over frames
var caught_peeks := {}  # peek ids already reacted to
var emote := ""  # short reaction shown in the label, may contain "{who}" (emote_with)
var emote_with: Node2D = null
var emote_timer := 0.0

var world: Node2D
var label: Label

# Appearance (looks.gd): a baked sprite sheet, animated by what they're doing
var look := ""
var body_sprite: Sprite2D
var overlay: Node2D  # draws on top of the sprite: progress bar, carried plate
var facing_dir := 0  # sheet row (direction)
var last_move := Vector2(0, 1)
var anim_time := 0.0


# Draws the things that go on top of the body sprite (see draw_overlay).
class Overlay:
	extends Node2D
	var person: Node2D
	func _draw() -> void:
		person.draw_overlay(self)

# Control (controller.gd)
const NO_WINDOW := Vector2i(-1, -1)
static var peek_count := 0  # gives every peek a unique id, so NPCs react to each one once
var controlled := false
var auto_mode := false  # when controlled: decide by yourself like an NPC
var peek_window := NO_WINDOW  # the window you're peeking through (state "peeking")
var pending_peek := NO_WINDOW  # the window you're walking to
var peek_id := 0


func _init() -> void:
	for need in NEEDS:
		needs[need] = randf_range(40.0, 90.0)
		decay[need] = 100.0 / (DECAY_HOURS[need] * 60.0 / GameTime.MINUTES_PER_SECOND)


# p_home: index in World.BUILDINGS (-1 = homeless). p_traits: trait names. p_skills: {skill: starting level}.
func setup(p_name: String, p_grid: Vector2, p_color: Color, p_home := -1, p_traits := [], p_skills := {}) -> Node2D:
	npc_name = p_name
	grid_pos = p_grid
	home_cell = Vector2i(p_grid)
	body_color = p_color
	home = p_home
	traits = p_traits
	for s in p_skills:
		Skills.set_level(self, s, p_skills[s])
	for need in NEEDS:
		decay[need] *= Traits.decay(self, need)
	return self


func _ready() -> void:
	add_to_group("characters")
	world = get_tree().get_first_node_in_group("world")
	building = world.building_at(cell(), floor)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.position = Vector2(-45, -95)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.48))
	label.z_index = 10  # character info draws above object names
	add_child(label)
	if look == "":
		look = Looks.random_for(sex)
	var sheet := Looks.sheet(look)
	if sheet:
		body_sprite = Sprite2D.new()
		body_sprite.texture = sheet
		body_sprite.hframes = Looks.FRAMES
		body_sprite.vframes = 8
		body_sprite.centered = false
		body_sprite.offset = -Looks.FEET
		add_child(body_sprite)
	overlay = Overlay.new()
	overlay.person = self
	add_child(overlay)


func cell() -> Vector2i:
	return Vector2i(grid_pos.round())


func _process(delta: float) -> void:
	if dead:
		return
	var fx: Dictionary = Ages.EFFECTS[Ages.stage(self)]
	for need in needs:
		var rate: float = decay[need] * fx.get("decay", {}).get(need, 1.0)
		if need == "energy":
			rate *= Mind.multiplier(self, "energy_decay") * (1.3 if pregnant_until >= 0.0 else 1.0)
		needs[need] = maxf(0.0, needs[need] - rate * delta)
	if Ages.stage(self) == Ages.BABY:
		baby_update(delta)
	if world.now() >= next_sample and Ages.stage(self) > Ages.TODDLER:
		next_sample = world.now() + 3600.0
		Mind.sample(self)
	if pregnant_until >= 0.0:
		Life.check_birth(self)
	think_delay -= delta
	emote_timer -= delta / maxf(Engine.time_scale, 1.0)  # emotes stay ~4 real seconds at any speed
	look_timer -= delta
	if look_timer <= 0.0:
		look_timer = Perception.LOOK_INTERVAL
		look_around()

	update_work(delta)
	match state:
		"idle":
			if building >= 0 and not world.can_enter(self, building) and think_delay <= 0.0:
				leave_building()
			elif think_delay <= 0.0:
				think()
		"knocking":
			knock_timer -= delta * GameTime.MINUTES_PER_SECOND
			if knock_timer <= 0.0:
				Ownership.give_up(self)
		"walking":
			follow_path(delta)
		"using":
			if step.is_empty():  # put into "using" from outside without a task (tests)
				release_object()
				state = "idle"
				return
			use_timer -= delta
			if step.has("skill"):
				practice(step.skill, delta * GameTime.MINUTES_PER_SECOND)
			var ads: Dictionary = step.get("ads", {})
			if step.seconds > 0.0:
				var sleep_quality: float = Mind.multiplier(self, "sleep") if step.verb == "Sleeping" else 1.0
				for need in ads:
					var gain: float = ads[need] / step.seconds * delta * (sleep_quality if need == "energy" else 1.0)
					needs[need] = clampf(needs[need] + gain, 0.0, 100.0)
			if use_timer <= 0.0:
				if step.has("done"):
					step.done.call()
				if step.has("moodlet"):
					Emotions.add(self, step.moodlet)
				if steps.is_empty() and step.has("object"):  # task done: did they enjoy it?
					var obj_name: String = step.object.object_name
					Mind.learn_from_feeling(self, "cooking" if obj_name in Kitchen.KITCHEN_OBJECTS else obj_name)
				next_step()
		"queueing":
			queue_timer -= delta
			if step.object.user == null:
				begin_step()
			elif queue_timer <= 0.0:
				drop_task()
				state = "idle"
				activity = "Gave up waiting"
		"waiting":
			wait_timer -= delta
			if wait_timer <= 0.0:
				end_social()
		"talking":
			if is_initiator:
				talk_timer -= delta
				if talk_timer <= 0.0:
					Social.finish(self, partner, interaction)

	building = world.building_at(cell(), floor)
	position = Iso.to_screen(grid_pos)
	animate(delta)
	label.text = label_text()
	queue_redraw()


# --- Movement ---

# Plan a route to `target` on floor `f` and start walking. False (and nothing changes) if unreachable.
func walk_to(target: Vector2i, f: int) -> bool:
	var new_path: Array = world.find_path(cell(), floor, target, f, self)
	if new_path.is_empty():
		return false
	path = new_path
	walk_target = Vector2(target)
	state = "walking"
	return true


# Tiles per second: base speed × Fitness × life stage (toddlers waddle, old people slow down).
func walk_speed() -> float:
	return speed * Skills.speed_multiplier(self) * Ages.EFFECTS[Ages.stage(self)].speed


func follow_path(delta: float) -> void:
	var budget := walk_speed() * delta
	while budget > 0.0 and not path.is_empty():
		var p: Vector3i = path[0]
		if p.z != floor:
			floor = p.z  # on the stairs: change floor in place
			path.pop_front()
			continue
		var to := Vector2(p.x, p.y) - grid_pos
		if to.length() > 0.01:
			last_move = to
		if to.length() <= budget:
			grid_pos = Vector2(p.x, p.y)
			budget -= to.length()
			path.pop_front()
		else:
			grid_pos += to.normalized() * budget
			budget = 0.0
	if path.is_empty():
		arrive()


func arrive() -> void:
	if pending_peek != NO_WINDOW:
		start_peeking(pending_peek)
	elif pending_work:
		pending_work = false
		Jobs.start_shift(self)
	elif pending_knock >= 0:
		var b := pending_knock
		pending_knock = -1
		Ownership.knock(self, b)
	elif target_object:
		state = "using"
		if step.has("start"):
			step.start.call(step)
		use_timer = step.seconds
		activity = step.verb
	elif partner:
		Social.begin(self, partner, interaction)
	else:
		state = "idle"
		activity = "Idle"


func wander() -> void:
	var anchor := cell()
	if floor == 0 and grid_pos.distance_to(Vector2(home_cell)) > HOME_LEASH:
		anchor = home_cell
	if walk_to(world.random_walkable_near(anchor, floor, WANDER_RADIUS), floor):
		activity = "Wandering"
	else:
		think_delay = RETHINK_DELAY


# --- Deciding ---

# Called whenever the character is idle. NPCs always decide for themselves; the player overrides this.
func think() -> void:
	if Ages.stage(self) == Ages.BABY:
		return  # babies stay where they are put (baby_update)
	if controlled and not auto_mode:
		return  # you decide
	choose_action()


func label_text() -> String:
	if controlled:
		return "%s (%s) — %s" % [npc_name, "Auto" if auto_mode else "Manual", shown_activity(self)]
	var viewer := get_tree().get_first_node_in_group("player")
	var text := "%s — %s" % [Social.display_name(viewer, self), shown_activity(viewer)]
	if emote_timer > 0.0:
		var who := "" if emote_with == null else "you" if emote_with == viewer else Social.display_name(viewer, emote_with)
		text += "\n" + emote.replace("{who}", who)
	text += "\nFeeling: " + Emotions.describe(self)
	if show_details:
		text += " (%s)" % Emotions.reasons(self, 3)
		text += "\n%s\nTraits: %s\nSkills: %s" % [Ages.describe(self), ", ".join(traits), Skills.summary(self)]
		text += "\nMind: %s · learned: %s" % [", ".join(Mind.states(self)) if not Mind.states(self).is_empty() else "ok", Mind.tastes(self)]
		text += "\nHun %d Thi %d Ene %d Fun %d\nBla %d Hyg %d Soc %d" % [
			needs.hunger, needs.thirst, needs.energy, needs.fun, needs.bladder, needs.hygiene, needs.social]
		text += "\nSees: " + (", ".join(seen.map(func(c): return Social.display_name(viewer, c))) if not seen.is_empty() else "nobody")
	return text


# Practise a skill for `minutes` of game time. A level-up gives a moodlet, an emote and a log line.
func practice(skill: String, minutes: float) -> void:
	var new_level := Skills.add_xp(self, skill, minutes)
	if new_level > 0:
		Emotions.add(self, "Skill level up")
		show_emote("Level up! %s %d" % [skill, new_level], null)
		Social.log_event("{a} reached %s level %d" % [skill, new_level], self, self)


# Dirty dishes lying around at home (for "Messy home").
func messy_home() -> bool:
	if home < 0 or building != home:
		return false
	var dirty := Kitchen.items_in(self, home).filter(func(p): return p[1].kind == "dirty").size()
	return dirty >= Traits.mess_tolerance(self)


func show_emote(text: String, with: Node2D) -> void:
	emote = text
	emote_with = with
	emote_timer = EMOTE_SECONDS


# --- Perception ---

func look_around() -> void:
	Emotions.update(self, {"Messy home": messy_home(), "Broke": money < 0 and Ages.is_grown_up(self),
		"Pregnant": pregnant_until >= 0.0, "In a relationship": lover != "", "Crying": is_crying()})
	if is_crying() and emote_timer <= 0.0:
		show_emote("Waaah!", null)
	seen = []
	if not Perception.is_awake(self):
		return
	for other in get_tree().get_nodes_in_group("characters"):
		if other != self and Perception.can_see(self, other):
			seen.append(other)
			if Ages.stage(self) > Ages.BABY:
				notice(other)


# Hook: react to someone in sight. The player overrides this (you decide for yourself).
func notice(other: Node2D) -> void:
	if controlled:
		return  # you decide how to react
	Perception.notice(self, other)


# The activity text with "{who}" filled in as `viewer` knows that person (name or "Unknown").
func shown_activity(viewer: Node2D) -> String:
	if activity_with == null:
		return activity
	return activity.replace("{who}", Social.display_name(viewer, activity_with))


func choose_action() -> void:
	var best_score := 0.0
	var best_object: Node2D = null
	var best_partner: Node2D = null
	var best_interaction := {}
	var best_steps := Callable()
	var best_action := {}

	for obj in get_tree().get_nodes_in_group("smart_objects"):
		if obj.user != null or not may_use(obj):
			continue  # someone else is using or heading to it, or it's in someone else's home
		var d := travel_distance(obj.grid_pos, obj.floor)
		if d > CONSIDER_RADIUS:
			continue
		for action in Actions.for_object(obj):  # each thing you can do with it (actions.gd)
			var score := advertisement_score(action.ads) / distance_factor(d) * time_factor(action) * Traits.like(self, obj.object_name) \
				* Mind.learned(self, obj.object_name) * randf_range(0.85, 1.15)  # a little variety (Pee or Poo...)
			if score > best_score:
				best_score = score
				best_object = obj
				best_action = action
				best_partner = null
				best_steps = Callable()

	for option in Kitchen.options(self, home):
		var d := travel_distance(option.anchor.grid_pos, option.anchor.floor)
		if d > CONSIDER_RADIUS:
			continue
		# Longer tasks are a bit less attractive; the random factor gives some variety in meals.
		var score: float = advertisement_score(option.ads) / distance_factor(d) / (1.0 + option.seconds / 60.0) * randf_range(0.85, 1.15)
		if option.get("cooking", false):
			score *= Traits.like(self, "cooking") * Mind.learned(self, "cooking")
		if score > best_score:
			best_score = score
			best_steps = option.steps
			best_object = null
			best_partner = null

	for other in get_tree().get_nodes_in_group("characters"):
		if other == self or not other.is_available():
			continue
		var d := travel_distance(other.grid_pos, other.floor)
		if d > SOCIAL_RADIUS:
			continue
		var behind_door: bool = other.building >= 0 and not world.can_enter(self, other.building)
		if behind_door and knock_cooldown.get(other.building, -INF) > world.now():
			continue  # they turned us away recently
		var i := Social.choose_interaction(self, other)
		if i.is_empty():
			continue
		var score := Social.interaction_score(self, other, i) / distance_factor(d) * Traits.like(self, "social") * Mind.learned(self, "social")
		if behind_door:
			score *= 0.7  # knocking first is more effort
		if score > best_score:
			best_score = score
			best_partner = other
			best_interaction = i
			best_object = null
			best_steps = Callable()

	var ok := true
	if best_score < ACT_THRESHOLD:
		wander()
	elif best_partner and best_partner.building >= 0 and not world.can_enter(self, best_partner.building):
		ok = go_knock(best_partner.building)
	elif best_partner:
		ok = start_social(best_partner, best_interaction)
	elif best_steps.is_valid():
		ok = run_steps(best_steps.call())
	else:
		ok = use_object(best_object, best_action)
	if not ok:
		think_delay = RETHINK_DELAY


# Sleep is for the night.
func time_factor(action: Dictionary) -> float:
	if not action.get("night", false):
		return 1.0
	return NIGHT_SLEEP_BONUS if GameTime.is_night(world.now()) else DAY_SLEEP_PENALTY


# --- Babies ---

# Babies and toddlers cry when any need is low (only grown-ups can fix it: Feed, Change & clean, Rock to sleep).
func is_crying() -> bool:
	if Ages.stage(self) > Ages.TODDLER:
		return false
	for need in needs:
		if needs[need] < 20.0:
			return true
	return false


# Babies nap where they are when tired, and wake up rested.
func baby_update(delta: float) -> void:
	if state != "idle":
		return
	if needs.energy < 25.0:
		napping = true
	if napping:
		needs.energy = minf(100.0, needs.energy + 100.0 / 240.0 * delta * GameTime.MINUTES_PER_SECOND)  # 4 h nap
		napping = needs.energy < 95.0
	activity = "Napping" if napping else ("Crying" if is_crying() else "Being a baby")


# --- Work (jobs.gd) ---

func update_work(delta: float) -> void:
	if job == "":
		return
	var t: float = world.now()
	if at_work:
		Jobs.working(self, delta * GameTime.MINUTES_PER_SECOND)
		return
	Jobs.check_missed(self, t)
	if Jobs.should_work(self, t) and not pending_work and state not in ["talking", "knocking"]:
		time_for_work()


# Hook: NPCs just go. The player overrides this (only goes by themselves in Auto mode).
func time_for_work() -> void:
	if not controlled or auto_mode:
		go_to_work()
	elif reminded_day != GameTime.day_index(world.now()):
		reminded_day = GameTime.day_index(world.now())
		var school := Jobs.is_school(job)
		show_emote("Time for %s! (click the Bus stop)" % ("school" if school else "work"), null)
		Social.log_event("{a} should leave for %s: click the Bus stop" % ("school" if school else "work"), self, self)


# Drop everything and head for the bus stop.
func go_to_work() -> bool:
	if partner:
		end_social()
	drop_task()
	var stop := bus_stop()
	if stop == null or not walk_to(stop.use_cell(), 0):
		return false
	pending_work = true
	activity = "Going to school" if Jobs.is_school(job) else "Going to work"
	return true


func bus_stop() -> Node2D:
	for obj in get_tree().get_nodes_in_group("smart_objects"):
		if obj.object_name == "Bus stop":
			return obj
	return null


# Give someone a job and money (main.gd).
func set_look(p_look: String) -> Node2D:
	look = p_look
	return self


func set_life(p_money: int, p_job := "") -> Node2D:
	money = p_money
	job = p_job
	return self


# Sex ("F"/"M"), age in years, and parents' names. Children get their school from their stage.
func set_age(p_sex: String, p_years: float, p_parents := []) -> Node2D:
	death_years = randf_range(Life.DEATH_YEARS[0], Life.DEATH_YEARS[1])
	sex = p_sex
	age_days = Ages.days_for_years(p_years)
	parents = p_parents
	if Ages.stage(self) in [Ages.TODDLER, Ages.CHILD, Ages.TEEN]:
		Jobs.school_for_stage(self)
	return self


# --- Homes and visiting (ownership.gd) ---

# Walk to building b's door from outside and knock.
func go_knock(b: int) -> bool:
	if not walk_to(world.door_outside(b), 0):
		return false
	pending_knock = b
	activity = "Going to knock at " + world.BUILDINGS[b].name
	return true


# Inside a building we're no longer allowed in: head out the door.
func leave_building() -> void:
	var b := building
	if walk_to(world.door_outside(b), 0):
		activity = "Leaving " + world.BUILDINGS[b].name
	else:
		think_delay = RETHINK_DELAY


# Someone let us in after a knock. NPCs simply decide again (now that the door is open to them).
func on_invited(b: int) -> void:
	think_delay = 0.0
	if controlled and walk_to(world.door_inside(b), 0):
		activity = "Going into " + world.BUILDINGS[b].name


# Objects in your own home, or outdoors, are fair game. Other people's fridges are not.
func may_use(obj: Node2D) -> bool:
	if Ages.stage(self) <= Ages.TODDLER and not obj.object_name in ["Bed", "Crib", "TV"]:
		return false  # little ones only sleep and watch TV by themselves
	return obj.building < 0 or obj.building == home


func travel_distance(target: Vector2, f: int) -> float:
	return grid_pos.distance_to(target) + absf(f - floor) * FLOOR_COST


# How much an advertisement {need: amount} is worth to this character right now.
func advertisement_score(ads: Dictionary) -> float:
	var score := 0.0
	for need in ads:
		if needs.has(need):
			score += ads[need] * urgency(needs[need]) * Emotions.need_weight(self, need) * Mind.multiplier(self, "needs", need)
	return score


func distance_factor(distance: float) -> float:
	return 1.0 + distance * 0.05


# Low needs matter disproportionately more (squared curve), like The Sims' motive curves.
func urgency(value: float) -> float:
	var missing := (100.0 - value) / 100.0
	return missing * missing


# --- Objects ---

# Use an object that does one thing (TV, Bed...): a single step. False if it can't be reached.
# Do one of the object's actions (actions.gd); without one, its first action.
func use_object(obj: Node2D, action := {}) -> bool:
	if action.is_empty():
		action = Actions.for_object(obj)[0]
	var step := {"object": obj, "verb": action.verb, "seconds": action.minutes, "ads": action.ads}
	for key in ["skill", "moodlet", "asleep"]:
		if action.has(key):
			step[key] = action[key]
	return run_steps([step])


# Start a task. False (and nothing is done) if the list is empty or the first object can't be reached.
func run_steps(list: Array) -> bool:
	if list.is_empty():
		return false
	steps = list.duplicate()
	return next_step()


func next_step() -> bool:
	release_object()
	if steps.is_empty():
		step = {}
		state = "idle"
		activity = "Idle"
		return true
	step = steps.pop_front()
	queue_timer = QUEUE_TIMEOUT
	return begin_step()


# Go to the current step's object, reserving it, or queue if someone else has it.
func begin_step() -> bool:
	var obj: Node2D = step.object
	if obj.user != null and obj.user != self:
		state = "queueing"
		activity = "Waiting for the " + obj.object_name
		return true
	if not walk_to(obj.use_cell(), obj.floor):
		drop_task()
		state = "idle"
		return false
	target_object = obj
	obj.user = self  # reserve it so nobody else grabs it
	activity = "Going to the " + obj.object_name
	return true


# Abandon the current task. Anything carried is put down in the kitchen (Kitchen.put_down).
func drop_task() -> void:
	steps.clear()
	step = {}
	release_object()
	Kitchen.put_down(self)


func release_object() -> void:
	if target_object:
		target_object.user = null
		target_object = null


# --- Social ---

# Can someone start a conversation with us right now? (Wandering counts as available.)
func is_available() -> bool:
	if controlled and not auto_mode:  # NPCs only approach you when you stand still, so they never cancel your orders
		return partner == null and target_object == null and state == "idle"
	return partner == null and target_object == null and steps.is_empty() and state in ["idle", "walking"]


func start_social(other: Node2D, i: Dictionary) -> bool:
	if not walk_to(world.free_neighbor(other.cell(), other.floor, cell()), other.floor):
		return false
	partner = other
	interaction = i
	is_initiator = true
	other.begin_waiting(self, path.size() * 1.5 / maxf(walk_speed(), 0.1) + WAIT_SLACK)
	activity = "Going to talk to {who}"
	activity_with = other
	return true


func begin_waiting(initiator: Node2D, limit: float) -> void:
	stop_peeking()
	drop_task()
	path = []
	partner = initiator
	is_initiator = false
	wait_limit = limit
	wait_timer = limit
	activity = "{who} is coming over"
	activity_with = initiator
	state = "waiting"


# Ends the conversation for both sides (finished, rejected, timed out, or interrupted).
func end_social() -> void:
	var other := partner
	partner = null
	interaction = {}
	is_initiator = false
	if state in ["waiting", "talking", "walking"]:
		state = "idle"
		activity = "Idle"
		path = []
	if other and other.partner == self:
		other.end_social()


const BODY_SCALE := [0.35, 0.5, 0.7, 0.9, 1.0, 1.0, 0.95]  # by life stage


func _draw() -> void:
	if controlled and state == "walking":  # destination marker for the character you control
		var marker := Iso.to_screen(walk_target) - position
		draw_set_transform(marker, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.6, 0.8), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if controlled:  # a ring under whoever you control
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.6, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var s: float = BODY_SCALE[Ages.stage(self)]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 12.0 * s, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if body_sprite and Ages.stage(self) != Ages.BABY:
		return  # the sprite (and the overlay on top of it) draw the rest
	if Ages.stage(self) == Ages.BABY:  # a bundle
		draw_circle(Vector2(0, -6), 7.0, body_color.lightened(0.3))
		draw_circle(Vector2(0, -12), 4.5, Color(1.0, 0.85, 0.7))
	else:
		draw_rect(Rect2(-8 * s, -34 * s - 4, 16 * s, 30 * s), body_color)
		draw_circle(Vector2(0, -42 * s - 4), 9.0 * s, Color(1.0, 0.85, 0.7))
		if Ages.stage(self) == Ages.OLD:
			draw_arc(Vector2(0, -42 * s - 4), 9.0 * s, PI, TAU, 12, Color(0.85, 0.85, 0.88), 4.0)  # grey hair
		if sex == "F":
			draw_circle(Vector2(0, -51 * s - 4), 4.0 * s, Color(0.35, 0.22, 0.15))  # hair bun



# On top of the body: pregnancy bump (placeholder bodies only), progress bar, what they're carrying.
func draw_overlay(canvas: Node2D) -> void:
	if pregnant_until >= 0.0:
		canvas.draw_circle(Vector2(6, -22), 5.0, Color(1.0, 0.85, 0.75, 0.9))
	if state == "using" and step.get("seconds", 0.0) > 0.0:  # progress bar for the current action
		var done := clampf(1.0 - use_timer / step.seconds, 0.0, 1.0)
		canvas.draw_rect(Rect2(-19, -73, 38, 6), Color(0, 0, 0, 0.6))
		canvas.draw_rect(Rect2(-18, -72, 36 * done, 4), Color(0.45, 0.85, 0.5))
	if not held.is_empty():  # carried plate or cup, in front of the body
		var dish := Color(0.92, 0.92, 0.95) if held.kind != "dirty" else Color(0.7, 0.66, 0.6)
		if held.get("dish", "") == "cup" or held.kind == "drink":
			canvas.draw_rect(Rect2(8, -32, 7, 9), dish)
		else:
			canvas.draw_set_transform(Vector2(12, -28), 0.0, Vector2(1.0, 0.5))
			canvas.draw_circle(Vector2.ZERO, 7.0, dish)
			if held.kind == "food":
				canvas.draw_circle(Vector2.ZERO, 4.0, Kitchen.RECIPES[held.recipe].color)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Pick the sheet frame: walking (4-step cycle, facing the way they move), sitting on seats and the
# toilet, lying in bed (or napping on the couch), facing who they talk to, standing otherwise.
func animate(delta: float) -> void:
	overlay.queue_redraw()
	if body_sprite == null:
		return
	var stage := Ages.stage(self)
	body_sprite.visible = stage != Ages.BABY
	body_sprite.scale = Vector2.ONE * BODY_SCALE[stage]
	body_sprite.position = Vector2.ZERO
	var frame := Looks.IDLE
	if state == "walking":
		anim_time += delta
		facing_dir = Looks.direction(last_move)
		frame = Looks.WALK + int(anim_time * 6.0) % 4
	elif state == "using" and target_object:
		var at: Vector2 = target_object.grid_pos
		if step.get("asleep", false) and target_object.object_name in ["Bed", "Crib", "Couch"]:
			frame = Looks.LIE
			body_sprite.position = Iso.to_screen(at) - position + Vector2(0, -10)
			facing_dir = target_object.facing * 2
		elif target_object.is_seat() or target_object.object_name in ["Toilet", "Table"]:
			frame = Looks.SIT
			if target_object.is_seat():
				facing_dir = target_object.facing * 2
			else:
				facing_dir = Looks.direction(at - grid_pos)
				if target_object.object_name == "Toilet":
					body_sprite.position = Iso.to_screen(at) - position
					facing_dir = target_object.facing * 2
		else:
			facing_dir = Looks.direction(at - grid_pos)
	elif state in ["talking", "waiting"] and partner:
		facing_dir = Looks.direction(partner.grid_pos - grid_pos)
	body_sprite.frame = facing_dir * Looks.FRAMES + frame


# --- Being controlled (controller.gd) ---

func toggle_mode() -> void:
	auto_mode = not auto_mode


func click_tile(clicked: Vector2i) -> void:
	cancel_current()
	var obj := object_at(clicked)
	var stairs_to: int = world.stairs_destination(clicked, floor)
	if obj and obj.user == null:
		if not use_object(obj):
			activity = "Can't reach the " + obj.object_name
	elif obj:
		if walk_to(obj.use_cell(), obj.floor):
			activity = obj.object_name + " is busy"
	elif stairs_to >= 0:
		if walk_to(clicked, stairs_to):
			activity = "Taking the stairs"
	elif walk_to(clicked, floor):
		activity = "Walking"
	else:
		activity = "Can't go there"


# Clicked a house from outside: its door takes you in (or you knock), a ground-floor window lets you peek.
func click_building(hit: Dictionary) -> void:
	cancel_current()
	var house: String = world.BUILDINGS[hit.building].name
	if hit.kind == "door" and not world.can_enter(self, hit.building):
		if go_knock(hit.building):
			activity = "Going to knock at " + house
	elif hit.kind == "door":
		if walk_to(hit.cell - hit.dir, 0):  # the tile just inside the door
			activity = "Going into " + house
	elif hit.kind == "window" and world.windows.has(hit.cell):
		if walk_to(hit.cell + hit.dir, 0):  # the tile just outside the window
			pending_peek = hit.cell
			activity = "Going to peek into " + house
	else:
		activity = house + " (click the door to go in)"


func start_peeking(window: Vector2i) -> void:
	peek_count += 1
	peek_id = peek_count
	peek_window = window
	pending_peek = NO_WINDOW
	path = []
	state = "peeking"
	activity = "Peeking into " + world.BUILDINGS[world.windows[window].building].name


func stop_peeking(reason := "Idle") -> void:
	peek_window = NO_WINDOW
	pending_peek = NO_WINDOW
	if state == "peeking":
		state = "idle"
		activity = reason


# Your order: start an interaction. You can interrupt someone walking somewhere, but not someone
# using an object or already in a conversation.
func order_interaction(other: Node2D, i: Dictionary) -> void:
	if other.partner != null or other.state not in ["idle", "walking"]:
		activity = "{who} is busy"
		activity_with = other
		return
	cancel_current()
	if other.building >= 0 and not world.can_enter(self, other.building):
		activity = "{who} is inside %s: knock first" % world.BUILDINGS[other.building].name
		activity_with = other
	elif not start_social(other, i):
		activity = "Can't reach {who}"
		activity_with = other


# Drop whatever you were doing and stand still.
func cancel_current() -> void:
	if partner:
		end_social()
	drop_task()
	stop_peeking()
	pending_knock = -1
	knock_building = -1
	path = []
	state = "idle"
	activity = "Idle"


# A task chosen from a menu: drop what you're doing and start it.
func do_task(list: Array) -> void:
	cancel_current()
	if not run_steps(list):
		activity = "Can't do that right now"


func object_at(tile: Vector2i) -> Node2D:
	for obj in get_tree().get_nodes_in_group("smart_objects"):
		if Vector2i(obj.grid_pos) == tile and obj.floor == floor and obj.is_visible_in_tree():
			return obj
	return null
