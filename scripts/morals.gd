# Morals: does a dark personality turn into crime? Static, pure. Full documentation: docs/PEOPLE.md "The path".
#
# How wicked someone is comes from their traits (`dark`, traits.gd). Whether that becomes crime depends on their
# life: `pressure()` (broke and jobless, angry or depressed, grudges, a criminal record) minus what holds them
# (thriving, a career going well, people close to them). path():
#   Criminal  dark >= CRIMINAL_DARK and pressure >= CRIMINAL_PRESSURE: steals, cons, mugs, burgles (crime.gd)
#   Ruthless  dark >= CRIMINAL_DARK but held: they put it into their career (+RUTHLESS_PERFORMANCE per shift)
#   Mean      some darkness: cruel words and fights, never crime
#   Decent    everyone else
# Kleptomaniacs pickpocket whatever their path (an urge). The path is worked out every time, never stored:
# a ruthless psychopath who loses their job and gets angry can tip into crime, and a good job pulls them back.
#
# Everyone (Teen or older) *can* commit a crime; NPCs only do the ones their path allows (would_do), and you
# decide for yourself. Afterwards their conscience (traits.gd) decides how it feels (after_crime).
const Traits = preload("res://scripts/traits.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Mind = preload("res://scripts/mind.gd")
const Ages = preload("res://scripts/ages.gd")
const Skills = preload("res://scripts/skills.gd")

const CRIMINAL_DARK := 2
const CRIMINAL_PRESSURE := 1.5
const RUTHLESS_PERFORMANCE := 3.0
const CRIMES := ["Pickpocket", "Manipulate", "Threaten", "Attack"]  # social.gd interactions that are crimes
const MEAN_ONES := ["Attack"]  # the only one a Mean person does (when angry)


# How hard life pushes them. Pure: `life` = {money, job, job_level, angry, depressed, thriving, grudges, record, close}.
static func pressure_of(life: Dictionary) -> float:
	var p := 0.0
	if life.money < 100 and life.job == "":
		p += 1.5
	elif life.money < 300:
		p += 0.5
	if life.angry:
		p += 0.75
	if life.depressed:
		p += 0.75
	if life.grudges >= 3:
		p += 0.5
	p += minf(life.record, 2) * 0.5  # once you've started...
	if life.thriving:
		p -= 1.0
	if life.job != "" and life.job_level >= 2:
		p -= 1.0
	if life.close:
		p -= 0.5
	return p


static func life_of(c: Node2D) -> Dictionary:
	var school: bool = c.job != "" and load("res://scripts/jobs.gd").is_school(c.job)
	var grudges := 0
	for m in c.memories:
		if m.feeling < -1.0:
			grudges += 1
	var close := false
	for other in c.relationships:
		if c.relationships[other] >= 60.0:
			close = true
	return {"money": c.money, "job": "" if school else c.job, "job_level": c.job_level, "angry": Emotions.emotion(c) == "Angry",
		"depressed": Emotions.has(c, "Depressed"), "thriving": Emotions.has(c, "Thriving"), "grudges": grudges,
		"record": c.record, "close": close}


static func pressure(c: Node2D) -> float:
	return pressure_of(life_of(c))


# Pure: the path from how dark they are and how hard life pushes.
static func path_of(dark: int, p: float) -> String:
	if dark >= CRIMINAL_DARK:
		return "Criminal" if p >= CRIMINAL_PRESSURE else "Ruthless"
	return "Mean" if dark >= 1 else "Decent"


static func path(c: Node2D) -> String:
	if Ages.stage(c) < Ages.TEEN:
		return "Decent"  # children aren't anything yet
	return path_of(Traits.total(c, "dark"), pressure(c))


static func describe(c: Node2D) -> String:
	var p := path(c)
	var text: String = {"Criminal": "Criminal: life pushed their dark side into crime",
		"Ruthless": "Ruthless: their dark side goes into getting ahead", "Mean": "Mean: cruel at times, but no criminal",
		"Decent": "Decent"}[p]
	if "Kleptomaniac" in c.traits:
		text += " · can't help taking things"
	if c.record > 0:
		text += " · criminal record (%d)" % c.record
	return text


# Would an NPC choose this crime (social interaction name)? You decide for yourself.
static func would_do(c: Node2D, crime: String) -> bool:
	if not crime in CRIMES:
		return true
	if crime == "Pickpocket" and Traits.TRAITS.keys().any(func(t): return t in c.traits and Traits.TRAITS[t].get("urge", false)):
		return true
	match path(c):
		"Criminal":
			return true
		"Mean":
			return crime in MEAN_ONES and Emotions.emotion(c) == "Angry"
	return false


# The NPC criminals the crime system may send as burglars (crime.gd).
static func is_criminal(c: Node2D) -> bool:
	return Ages.is_grown_up(c) and path(c) == "Criminal"


# How it feels afterwards: guilty with a conscience, a thrill without one.
static func after_crime(c: Node2D) -> void:
	var conscience := Traits.total(c, "conscience")
	if conscience > 0:
		Emotions.add(c, "Guilty")
	elif conscience <= -2:
		Emotions.add(c, "Thrill")
	else:
		Emotions.add(c, "Uneasy")


# Work: a ruthless person gets ahead.
static func performance(c: Node2D) -> float:
	return RUTHLESS_PERFORMANCE if path(c) == "Ruthless" else 0.0


# How well they'd do in a fight: Fitness, traits, age, a little luck (crime.gd uses it too).
static func fight_strength(c: Node2D) -> float:
	var s := float(Skills.level(c, "Fitness")) + randf_range(-2.0, 2.0)
	if "Hot-headed" in c.traits:
		s += 2.0
	if "Sociopath" in c.traits or "Brave" in c.traits:
		s += 1.0
	if Ages.stage(c) == Ages.OLD:
		s -= 3.0
	elif Ages.stage(c) == Ages.TEEN:
		s -= 2.0
	return s


# How scary they are when they threaten someone.
static func menace(c: Node2D) -> float:
	var m := fight_strength(c) + Skills.level(c, "Charisma") * 0.5
	if "Psychopath" in c.traits or "Sociopath" in c.traits:
		m += 2.0
	return m
