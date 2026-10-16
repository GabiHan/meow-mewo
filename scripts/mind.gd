# Mind: long-term mental states and learning from experience. Static. Full documentation: docs/PEOPLE.md.
#
# Moodlets (emotions.gd) last hours. The mind remembers how someone has felt over days: once per game
# hour it samples their emotion (`mood_samples`, the last WINDOW hours). When enough of those hours
# were sad, they become Depressed; tense or uncomfortable, Anxious; good, Thriving. These are lasting
# moodlets that only lift when the balance changes (more good hours, or support from someone).
# Also: Isolated (no real conversation for ISOLATED_HOURS) and Burned out (worked BURNOUT_HOURS in 3 days).
#
# Learning: after doing something, people remember whether it made them feel good (learn()); their
# taste for it (`learned` {activity: ×0.5..1.6}) changes the AI's scores, like traits do.
const Emotions = preload("res://scripts/emotions.gd")

const WINDOW := 48  # hours of samples kept
const MIN_SAMPLES := 24  # a day of history before any state can start
const ISOLATED_HOURS := 48.0
const BURNOUT_HOURS := 26.0  # hours at work in the last 3 days
const LEARN_STEP := 0.05
const LEARN_RANGE := [0.5, 1.6]

# state: emotions that count toward it, share of hours to start (on) and to recover (off)
const STATES := {
	"Depressed": {"emotions": ["Sad"], "on": 0.45, "off": 0.2},
	"Anxious": {"emotions": ["Tense", "Uncomfortable"], "on": 0.55, "off": 0.25},
	"Thriving": {"emotions": ["Happy", "Confident", "Playful", "Energized", "Flirty", "Focused"], "on": 0.7, "off": 0.4},
}
const MIND_MOODLETS := ["Depressed", "Anxious", "Thriving", "Isolated", "Burned out"]
# Tastes are learned for hobbies only: nobody "learns" to dislike sleep or the toilet.
const LEARNABLE := ["TV", "Bookshelf", "Pull-up bar", "Bench", "cooking", "social"]
const GOOD := ["Happy", "Confident", "Playful", "Energized", "Flirty", "Focused", "Fine"]

# What the lasting states do (added up if several):
# performance: + work/school performance per shift; learning: × skill xp; accept: + saying yes;
# needs: {need: ×} how much they care; energy_decay: ×; sleep: × energy from sleeping.
const EFFECTS := {
	"Depressed": {"performance": -6.0, "learning": 0.7, "accept": -0.15, "needs": {"fun": 0.5, "social": 0.7}, "energy_decay": 1.2},
	"Anxious": {"performance": -4.0, "learning": 0.85, "accept": -0.1, "sleep": 0.75},
	"Burned out": {"performance": -5.0, "learning": 0.8, "energy_decay": 1.15},
	"Isolated": {"needs": {"social": 1.5}},
	"Thriving": {"performance": 4.0, "learning": 1.2, "accept": 0.05},
}


# Once per game hour (npc.gd): record how they feel and update the lasting states.
static func sample(c: Node2D) -> void:
	c.mood_samples.append(Emotions.emotion(c, MIND_MOODLETS))
	if c.mood_samples.size() > WINDOW:
		c.mood_samples.pop_front()
	update(c)


static func share(c: Node2D, emotions: Array) -> float:
	if c.mood_samples.is_empty():
		return 0.0
	return c.mood_samples.filter(func(e): return e in emotions).size() / float(c.mood_samples.size())


static func update(c: Node2D) -> void:
	var enough: bool = c.mood_samples.size() >= MIN_SAMPLES
	for state in STATES:
		var s := share(c, STATES[state].emotions)
		var on := Emotions.has(c, state)
		if not on and enough and s >= STATES[state].on:
			Emotions.add(c, state)
			c.show_emote("(%s)" % state.to_lower(), null)
		elif on and s < STATES[state].off:
			Emotions.set_condition(c, state, false)
	var now: float = c.world.now()
	Emotions.set_condition(c, "Isolated", enough and now - c.last_social > ISOLATED_HOURS * 3600.0 and c.age_days > 3.0)
	c.work_log = c.work_log.filter(func(w): return w[0] > now - 3.0 * 86400.0)
	var worked := 0.0
	for w in c.work_log:
		worked += w[1]
	Emotions.set_condition(c, "Burned out", worked >= BURNOUT_HOURS)


# Someone talked them through it: the worst recent hours weigh less.
static func support(c: Node2D) -> void:
	var removed := 0
	for i in range(c.mood_samples.size() - 1, -1, -1):
		if removed < 12 and not c.mood_samples[i] in GOOD:
			c.mood_samples[i] = "Happy"
			removed += 1
	update(c)


static func bonus(c: Node2D, field: String) -> float:
	var total := 0.0
	for state in EFFECTS:
		if Emotions.has(c, state):
			total += EFFECTS[state].get(field, 0.0)
	return total


static func multiplier(c: Node2D, field: String, key := "") -> float:
	var m := 1.0
	for state in EFFECTS:
		if Emotions.has(c, state):
			m *= EFFECTS[state].get(field, {}).get(key, 1.0) if key != "" else EFFECTS[state].get(field, 1.0)
	return m


static func states(c: Node2D) -> Array:
	return MIND_MOODLETS.filter(func(s): return Emotions.has(c, s))


# --- Learning from experience ---

static func learned(c: Node2D, key: String) -> float:
	return c.learned.get(key, 1.0)


# After an activity: did it leave them feeling good? Then they'll like it a bit more next time.
static func learn(c: Node2D, key: String, good: bool) -> void:
	if not key in LEARNABLE:
		return
	c.learned[key] = clampf(learned(c, key) + (LEARN_STEP if good else -LEARN_STEP), LEARN_RANGE[0], LEARN_RANGE[1])


static func learn_from_feeling(c: Node2D, key: String) -> void:
	learn(c, key, Emotions.emotion(c, MIND_MOODLETS) in GOOD)


static func tastes(c: Node2D) -> String:
	var parts := []
	for key in c.learned:
		if absf(c.learned[key] - 1.0) >= 0.1:
			parts.append("%s %s" % ["likes" if c.learned[key] > 1.0 else "dislikes", key])
	return ", ".join(parts) if not parts.is_empty() else "nothing yet"
