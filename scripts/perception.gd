# Perception: what characters notice about their surroundings, and how they react.
# Static like social.gd. npc.gd calls look_around() every LOOK_INTERVAL seconds; for each character
# in sight (same floor, within SIGHT_RADIUS, no wall in between; windows and doors don't block)
# it calls notice(), which hands the interesting cases to a reaction.
#
# Reactions so far:
#   Greeting: seeing someone you've met (and don't hate) for the first time in GREET_HOURS: a hello
#   ("Good morning, Sam!") or a glare for enemies, big recent grudges, or while
#   Angry with a recent bad memory of them. Only when not busy talking.
#   Peeking: someone outside is peeking through a window into the building you're in. Each look you
#   have NOTICE_CHANCE to catch them (once per peek). You can't notice anything while asleep.
#     score = your friendship toward them / 100 + (your mood - 50) / 100 - PEEK_WEIRDNESS ± PEEK_RANDOMNESS
#             - STRANGER_PENALTY if you've never met
#             - PRIVACY_PENALTY if you're using a private object (Shower, Toilet)
#     score > WAVE_ABOVE -> wave (and come outside to chat, if you're free)
#     score < YELL_BELOW -> yell, and close the curtains on that window for CURTAIN_SECONDS
#     otherwise          -> stare back
#   Every peek reaction also gives moodlets (emotions.gd) and a memory (social.gd): the person caught
#   peeking feels "Got caught peeking" unless waved at; yelling makes the NPC "Caught a peeper" (Angry).
#   Traits change the score (Hot-headed: −0.2).
const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Traits = preload("res://scripts/traits.gd")
const GameTime = preload("res://scripts/game_time.gd")

const SIGHT_RADIUS := 10.0  # tiles
const LOOK_INTERVAL := 0.5  # seconds between looks
const NOTICE_CHANCE := 0.35  # per look, for someone peeking in
const PEEK_WEIRDNESS := 0.15
const PEEK_RANDOMNESS := 0.25
const STRANGER_PENALTY := 0.2
const PRIVACY_PENALTY := 1.0
const PRIVATE_OBJECTS := ["Shower", "Toilet"]
const WAVE_ABOVE := 0.25
const YELL_BELOW := -0.15
const GREET_HOURS := 3.0  # greet the same person at most once per this many game hours
const ENEMY_BELOW := -30.0  # glare instead of greeting

# emote: shown above the NPC for a few seconds. friendship: the NPC's opinion of the peeker
# (doubled when caught at a private moment and negative). text: social log ({a} = NPC, {b} = peeker).
const PEEK_REACTIONS := {
	"wave": {"emote": "Waves at {who}", "text": "{a} waved at {b} through the window", "friendship": 2, "social": 5, "curtains": false},
	"stare": {"emote": "Stares at {who}", "text": "{a} caught {b} peeking and stared back", "friendship": -3, "social": 0, "curtains": false},
	"yell": {"emote": "Yells at {who}: \"Creep!\"", "text": "{a} yelled at {b} for peeking", "friendship": -10, "social": 0, "curtains": true},
}


# Asleep people notice nothing.
static func is_awake(c: Node2D) -> bool:
	return not (c.state == "using" and c.step.get("asleep", false))


static func can_see(c: Node2D, other: Node2D) -> bool:
	return not other.at_work and not c.at_work and other.floor == c.floor and c.grid_pos.distance_to(other.grid_pos) <= SIGHT_RADIUS \
		and c.world.has_line_of_sight(c.cell(), other.cell(), c.floor)


# `c` sees `other` this look. Decide whether anything about it is worth reacting to.
static func notice(c: Node2D, other: Node2D) -> void:
	if other.state == "peeking" and c.building >= 0 and c.floor == 0 \
			and c.world.windows[other.peek_window].building == c.building \
			and not c.caught_peeks.has(other.peek_id) and randf() < NOTICE_CHANCE:
		c.caught_peeks[other.peek_id] = true
		react_to_peek(c, other)
	elif c.known.has(other.npc_name) and c.state in ["idle", "walking", "using"] and other.state != "peeking":
		greet(c, other)
	if Emotions.has(other, "Crying") and c.building >= 0 and c.building == other.building and c.age_days > other.age_days:
		Emotions.add(c, "Baby crying")  # hard to ignore


static func greet(c: Node2D, other: Node2D) -> void:
	var now: float = c.world.now()
	if now - c.greeted.get(other.npc_name, -INF) < GREET_HOURS * 3600.0:
		return
	c.greeted[other.npc_name] = now
	var bad := Social.recent_feeling(c, other)
	if Social.friendship(c, other) < ENEMY_BELOW or bad <= -3.0 or (bad < 0.0 and Emotions.emotion(c) == "Angry"):
		c.show_emote("*glares at {who}*", other)
		return
	var hello: String = {"Morning": "Good morning", "Afternoon": "Hi", "Evening": "Good evening", "Night": "Hey"}[GameTime.part_of_day(now)]
	c.show_emote("\"%s, {who}!\"" % hello, other)


static func peek_score(c: Node2D, peeker: Node2D) -> float:
	var score := Social.friendship(c, peeker) / 100.0 + (Social.mood(c) - 50.0) / 100.0 - PEEK_WEIRDNESS
	score += randf_range(-PEEK_RANDOMNESS, PEEK_RANDOMNESS)
	if not c.known.has(peeker.npc_name):
		score -= STRANGER_PENALTY
	if in_private(c):
		score -= PRIVACY_PENALTY
	return score + Traits.bonus(c, "peek") + Emotions.accept_bonus(c)


static func in_private(c: Node2D) -> bool:
	return c.state == "using" and c.target_object and c.target_object.object_name in PRIVATE_OBJECTS


# Returns the reaction name ("wave", "stare" or "yell").
static func react_to_peek(c: Node2D, peeker: Node2D) -> String:
	var score := peek_score(c, peeker)
	var kind := "wave" if score > WAVE_ABOVE else ("yell" if score < YELL_BELOW else "stare")
	var r: Dictionary = PEEK_REACTIONS[kind]
	var amount: float = r.friendship * (2 if in_private(c) and r.friendship < 0 else 1)
	Social.change_friendship(c, peeker, amount)
	c.needs.social = clampf(c.needs.social + r.social, 0.0, 100.0)
	c.show_emote(r.emote, peeker)
	Social.log_event(r.text, c, peeker)
	if r.curtains:
		c.world.close_curtains(peeker.peek_window)
	if kind == "wave":
		Emotions.add(c, "Friend at the window")
		Social.remember(c, peeker, "waved at me through the window", 0.5)
	else:
		Emotions.add(peeker, "Got caught peeking")
		Social.remember(c, peeker, "peeked through my window", -1.0 if kind == "stare" else -3.0)
	if kind == "yell":
		Emotions.add(c, "Caught a peeper")
	if kind == "wave" and c.is_available():
		c.start_social(peeker, Social.INTERACTIONS[0])  # come outside and say hi
	return kind
