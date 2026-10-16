# Skills: levels 0-10 earned by doing things. Static like social.gd. Full documentation: docs/PEOPLE.md.
#
# Character `skills`: {skill: total xp}. Practising gives xp_per_minute per game minute of the
# activity, ×1.5 for a matching trait (traits.gd) and ×1.5 for a matching emotion (emotions.gd).
# Going from level L to L+1 takes 100 + 50 × L xp. Level-ups are handled by npc.gd practice()
# (moodlet, emote, social log).
const Traits = preload("res://scripts/traits.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Mind = preload("res://scripts/mind.gd")

const MAX_LEVEL := 10
const SKILLS := {
	"Cooking": {"xp_per_minute": 10.0, "from": "cooking"},
	"Charisma": {"xp_per_minute": 8.0, "from": "chatting, compliments, deep talks, comforting"},
	"Comedy": {"xp_per_minute": 8.0, "from": "telling jokes, watching TV"},
	"Fitness": {"xp_per_minute": 6.0, "from": "the pull-up bar"},
	"Logic": {"xp_per_minute": 4.0, "from": "reading at a bookshelf, discussing ideas"},
}


# Total xp needed to reach `lvl`.
static func xp_for(lvl: int) -> float:
	return 100.0 * lvl + 25.0 * lvl * (lvl - 1)


static func level(c: Node2D, skill: String) -> int:
	var xp: float = c.skills.get(skill, 0.0)
	var lvl := 0
	while lvl < MAX_LEVEL and xp >= xp_for(lvl + 1):
		lvl += 1
	return lvl


# 0..1 toward the next level.
static func progress(c: Node2D, skill: String) -> float:
	var lvl := level(c, skill)
	if lvl >= MAX_LEVEL:
		return 1.0
	return (c.skills.get(skill, 0.0) - xp_for(lvl)) / (xp_for(lvl + 1) - xp_for(lvl))


static func set_level(c: Node2D, skill: String, lvl: int) -> void:
	c.skills[skill] = xp_for(lvl)


# Adds xp for `minutes` of practice. Returns the new level if it went up, else -1.
static func add_xp(c: Node2D, skill: String, minutes: float) -> int:
	var before := level(c, skill)
	var xp: float = SKILLS[skill].xp_per_minute * minutes * Traits.skill(c, skill) * Emotions.skill_boost(c, skill) \
		* Mind.multiplier(c, "learning")
	c.skills[skill] = c.skills.get(skill, 0.0) + xp
	var after := level(c, skill)
	return after if after > before else -1


static func summary(c: Node2D) -> String:
	var parts := []
	for s in SKILLS:
		if c.skills.get(s, 0.0) > 0.0:
			parts.append("%s %d (%d%%)" % [s, level(c, s), progress(c, s) * 100])
	return ", ".join(parts) if not parts.is_empty() else "none yet"


# --- Effects ---

# Cooking: Burnt (less filling, Uncomfortable), Good, or Delicious (more filling, Happy).
static func cooking_quality(c: Node2D) -> String:
	var lvl := level(c, "Cooking")
	var burnt := maxf(0.0, 0.3 - 0.06 * lvl)
	var delicious := minf(0.8, 0.05 + 0.08 * lvl)
	var r := randf()
	if r < burnt:
		return "Burnt"
	return "Delicious" if r < burnt + delicious else "Good"


static func charisma_bonus(c: Node2D) -> float:  # added to others' chance of accepting you
	return 0.03 * level(c, "Charisma")


static func friendship_multiplier(c: Node2D) -> float:  # charming people make friends faster
	return 1.0 + 0.05 * level(c, "Charisma")


static func joke_chance(c: Node2D) -> float:
	return minf(0.95, 0.5 + 0.05 * level(c, "Comedy"))


static func speed_multiplier(c: Node2D) -> float:
	return 1.0 + 0.03 * level(c, "Fitness")
