# The body: people are only human. Static, like emotions.gd; npc.gd calls update() every frame and
# asks wants_to_run() / speed() when walking. Full documentation: docs/PEOPLE.md (The body).
#
#   running       in a hurry (bursting, starving, parched, late for work) or when you Shift+click: faster
#                 (RUN_SPEED) with a running animation, but they can trip (TRIP_CHANCE per tile, more when
#                 tired, less for Active people) and fall flat: down for a moment, embarrassed, and anyone
#                 who sees it laughs or asks if they're okay
#   passing out   energy at 0: they drop where they stand and sleep it off on the floor (no bed)
#   fainting      hunger at 0: they faint for a while, then wake up still very hungry
#   accidents     bladder at 0: they wet themselves (embarrassed, hygiene drops), witnesses are grossed out
#   farting       now and then (more often after a meal): goofballs and slobs find it funny, others are
#                 embarrassed if someone heard, and who heard it laughs (goofballs) or is grossed out
#   illness       a cold (caught with low hygiene, or from someone sick close by), the flu (from someone
#                 sick), food poisoning (from stale or spoiled food). While sick they tire faster, walk
#                 slower, feel "Sick", sneeze or cough, and with the flu or food poisoning they throw up
#                 now and then. Sleeping makes it pass faster.
#   throwing up   bent over for a moment: hunger, thirst and hygiene drop; witnesses are grossed out
#
# While down or bent over, `state` is "down" (npc.gd): they don't think, walk or talk until `pose_until`.
const Emotions = preload("res://scripts/emotions.gd")
const Social = preload("res://scripts/social.gd")
const Traits = preload("res://scripts/traits.gd")
const Ages = preload("res://scripts/ages.gd")

const RUN_SPEED := 1.8  # × walking speed
const TRIP_CHANCE := 0.012  # per tile run
const HURRY := 15.0  # a need below this makes them run
const POSES := {  # what puts them down, and for how many game minutes
	"tripped": {"pose": "down", "minutes": 3.0},
	"passed out": {"pose": "down", "minutes": 150.0},
	"fainted": {"pose": "down", "minutes": 45.0},
	"throwing up": {"pose": "bent", "minutes": 2.0},
}
const PASSED_OUT_ENERGY := 35.0  # energy regained by sleeping it off on the floor
const FAINT_HUNGER := 12.0  # hunger after waking from a faint
const FART_HOURS := 9.0  # on average between farts...
const FULL_TUMMY_HOURS := 3.0  # ...and twice as often this long after eating
const COLD_PER_HOUR := 0.03  # chance per game hour of catching a cold while hygiene is below DIRTY
const DIRTY := 20.0
const CATCH_DISTANCE := 3.0  # tiles: close enough to catch something when they sneeze or cough
const SLEEP_HEALS := 2.0  # illness passes this much faster while asleep
const ILLNESSES := {
	# hours it lasts, energy decay ×, walking speed ×, the sound, hours between symptoms, chance a symptom is
	# throwing up, chance someone close catches it per symptom
	"Cold": {"hours": 30.0, "energy": 1.3, "speed": 0.9, "sound": "*achoo!*", "every": 1.5, "vomit": 0.0, "spread": 0.12},
	"Flu": {"hours": 54.0, "energy": 1.7, "speed": 0.75, "sound": "*cough cough*", "every": 1.0, "vomit": 0.25, "spread": 0.15},
	"Food poisoning": {"hours": 12.0, "energy": 1.4, "speed": 0.85, "sound": "*urgh, my stomach*", "every": 1.0, "vomit": 0.6, "spread": 0.0},
}


static func now(c: Node2D) -> float:
	return c.world.now()


static func is_down(c: Node2D) -> bool:
	return c.pose != ""


# Every frame (npc.gd _process), after needs decay. `minutes` = game minutes this frame.
# Returns true while they're down or bent over (npc.gd then skips thinking and walking).
static func update(c: Node2D, minutes: float) -> bool:
	if Ages.stage(c) <= Ages.BABY or c.at_work:
		return false
	if c.pose != "":
		if c.pose_reason == "passed out":
			c.needs.energy = minf(100.0, c.needs.energy + PASSED_OUT_ENERGY / POSES["passed out"].minutes * minutes)
		if now(c) >= c.pose_until:
			get_up(c)
		return c.pose != ""
	var asleep: bool = c.state == "using" and c.step.get("asleep", false)
	if c.needs.energy <= 0.0 and not asleep:
		go_down(c, "passed out", "Passed out")
		Social.log_event("{a} passed out from exhaustion", c, c)
		return true
	if c.needs.hunger <= 0.0:
		go_down(c, "fainted", "Fainted")
		Social.log_event("{a} fainted from hunger", c, c)
		return true
	if c.needs.bladder <= 0.0:
		accident(c)
	illness_update(c, minutes, asleep)
	if c.next_fart <= 0.0:
		plan_fart(c)
	elif now(c) >= c.next_fart and not asleep and Ages.stage(c) >= Ages.TODDLER:
		fart(c)
	return c.pose != ""


# --- Down and up ---

static func go_down(c: Node2D, reason: String, moodlet := "") -> void:
	c.cancel_current()
	c.state = "down"
	c.pose = POSES[reason].pose
	c.pose_reason = reason
	c.pose_until = now(c) + POSES[reason].minutes * 60.0
	c.running = false
	c.activity = reason.capitalize()
	if moodlet != "":
		Emotions.add(c, moodlet)


static func get_up(c: Node2D) -> void:
	if c.pose_reason == "fainted":
		c.needs.hunger = maxf(c.needs.hunger, FAINT_HUNGER)
	c.pose = ""
	c.pose_reason = ""
	c.state = "idle"
	c.activity = "Idle"


# People who saw it happen (awake, close, in sight at the last look).
static func witnesses(c: Node2D) -> Array:
	return c.seen.filter(func(o): return is_instance_valid(o) and not o.dead and o.pose == "" and Ages.stage(o) >= Ages.TODDLER)


# --- Running ---

static func wants_to_run(c: Node2D) -> bool:
	if Ages.stage(c) <= Ages.TODDLER or Ages.stage(c) == Ages.OLD or c.illness == "Flu":
		return false
	if c.run_order:
		return true
	if c.controlled and not c.auto_mode:
		return false  # you decide (Shift+click)
	return c.needs.bladder < HURRY or c.needs.hunger < HURRY or c.needs.thirst < HURRY or c.pending_work


# Walking speed × this (running, being sick).
static func speed(c: Node2D) -> float:
	var s := RUN_SPEED if c.running else 1.0
	if c.illness != "":
		s *= ILLNESSES[c.illness].speed
	return s


# Called by npc.gd for each tile they run onto. True if they tripped.
static func maybe_trip(c: Node2D) -> bool:
	var chance := TRIP_CHANCE * (2.0 if c.needs.energy < 25.0 else 1.0) * (0.5 if "Active" in c.traits else 1.0)
	if randf() >= chance:
		return false
	go_down(c, "tripped", "Tripped")
	c.show_emote("Whoa— oof!", null)
	for o in witnesses(c):
		if "Goofball" in o.traits or "Hot-headed" in o.traits:
			o.show_emote("Hahaha! Nice one!", c)
			Emotions.add(o, "Had a laugh")
		elif Social.friendship(o, c) >= 20.0:
			o.show_emote("Are you okay?!", c)
	Social.log_event("{a} tripped and fell flat", c, c)
	return true


# --- Accidents and farts ---

static func accident(c: Node2D) -> void:
	c.needs.bladder = 100.0
	c.needs.hygiene = maxf(0.0, c.needs.hygiene - 50.0)
	Emotions.add(c, "Had an accident")
	c.show_emote("Oh no...", null)
	for o in witnesses(c):
		Emotions.add(o, "Grossed out")
		o.show_emote("Eww!", c)
	Social.log_event("{a} had an accident", c, c)


static func plan_fart(c: Node2D) -> void:
	var hours := FART_HOURS * randf_range(0.4, 1.6)
	if now(c) - c.last_meal < FULL_TUMMY_HOURS * 3600.0:
		hours *= 0.5
	c.next_fart = now(c) + hours * 3600.0


static func fart(c: Node2D) -> void:
	plan_fart(c)
	c.show_emote("*pfffrrt*", null)
	var heard := witnesses(c).filter(func(o): return o.grid_pos.distance_to(c.grid_pos) <= 4.0)
	var shameless: bool = "Goofball" in c.traits or "Slob" in c.traits or Ages.stage(c) <= Ages.CHILD
	if shameless:
		Emotions.add(c, "Funny fart")
	elif not heard.is_empty():
		Emotions.add(c, "Farted")
		c.show_emote("...that wasn't me.", null)
	for o in heard:
		if "Goofball" in o.traits or Ages.stage(o) == Ages.CHILD:
			o.show_emote("Hahaha!", c)
			Emotions.add(o, "Had a laugh")
		else:
			o.show_emote("Ugh, gross!", c)
			Emotions.add(o, "Grossed out")


# kitchen.gd: they just ate something; stale or spoiled food can make them sick.
static func ate(c: Node2D, freshness: String) -> void:
	c.last_meal = now(c)
	var risk: float = {"Stale": 0.25, "Spoiled": 0.85}.get(freshness, 0.0)
	if randf() < risk:
		fall_ill(c, "Food poisoning")


# --- Illness ---

static func fall_ill(c: Node2D, illness: String) -> void:
	if c.illness != "" or Ages.stage(c) <= Ages.BABY:
		return
	c.illness = illness
	c.ill_until = now(c) + ILLNESSES[illness].hours * 3600.0
	c.next_symptom = now(c) + ILLNESSES[illness].every * 3600.0 * randf_range(0.3, 1.0)
	c.show_emote("I don't feel so good...", null)
	Social.log_event("{a} came down with %s" % ("food poisoning" if illness == "Food poisoning" else "a " + illness.to_lower()), c, c)


static func recover(c: Node2D) -> void:
	c.illness = ""
	c.ill_until = -1.0
	Emotions.add(c, "Feeling better")
	c.show_emote("I feel so much better!", null)


static func illness_update(c: Node2D, minutes: float, asleep: bool) -> void:
	if c.illness == "":
		if c.needs.hygiene < DIRTY and randf() < COLD_PER_HOUR * minutes / 60.0:
			fall_ill(c, "Cold")
		return
	if asleep:
		c.ill_until -= (SLEEP_HEALS - 1.0) * minutes * 60.0
	if now(c) >= c.ill_until:
		recover(c)
		return
	var ill: Dictionary = ILLNESSES[c.illness]
	if now(c) < c.next_symptom or asleep:
		return
	c.next_symptom = now(c) + ill.every * 3600.0 * randf_range(0.6, 1.4)
	if randf() < ill.vomit:
		throw_up(c)
	else:
		c.show_emote(ill.sound, null)
	for o in witnesses(c):  # sneezed or coughed on
		if o.grid_pos.distance_to(c.grid_pos) <= CATCH_DISTANCE and randf() < ill.spread:
			fall_ill(o, c.illness)


static func throw_up(c: Node2D) -> void:
	go_down(c, "throwing up", "Threw up")
	c.needs.hunger = maxf(0.0, c.needs.hunger - 25.0)
	c.needs.thirst = maxf(0.0, c.needs.thirst - 15.0)
	c.needs.hygiene = maxf(0.0, c.needs.hygiene - 25.0)
	c.show_emote("*bleurgh*", null)
	for o in witnesses(c):
		Emotions.add(o, "Grossed out")
		o.show_emote("Ewww! Are you okay?" if Social.friendship(o, c) >= 20.0 else "Eww, gross!", c)
	Social.log_event("{a} threw up", c, c)


# Energy decay × this (npc.gd): being sick is tiring.
static func energy_decay(c: Node2D) -> float:
	return ILLNESSES[c.illness].energy if c.illness != "" else 1.0
