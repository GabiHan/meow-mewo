# Life stages and age. Pure helpers with no other dependencies, so every script can use them.
# Ageing, pregnancy and births are in life.gd. Full documentation: docs/LIFE.md.
#
# Characters have `age_days` (game days lived) and `sex` ("F" or "M"). The stage comes from age_days;
# each stage also maps to an age in years for display (linear within the stage).
const STAGES := [
	{"name": "Baby", "days": 3, "years": [0, 1]},
	{"name": "Toddler", "days": 7, "years": [1, 4]},
	{"name": "Child", "days": 14, "years": [4, 13]},
	{"name": "Teen", "days": 14, "years": [13, 18]},
	{"name": "Young adult", "days": 22, "years": [18, 26]},
	{"name": "Adult", "days": 30, "years": [26, 61]},
	{"name": "Old", "days": 30, "years": [61, 90]},  # keeps ageing ~1 year a day after 90, until they die (life.gd)
]
const BABY := 0
const TODDLER := 1
const CHILD := 2
const TEEN := 3
const YOUNG_ADULT := 4
const ADULT := 5
const OLD := 6

const MENOPAUSE_YEARS := 50.0  # women can't get pregnant from this age

# What each stage changes. speed: walking ×; decay: {need: ×} how fast needs drop. Babies and toddlers
# can't look after themselves: grown-ups must feed, change and rock them (social.gd care interactions).
const EFFECTS := [
	{"speed": 0.0, "decay": {"hunger": 2.0, "thirst": 2.0, "bladder": 2.0, "hygiene": 2.0}},
	{"speed": 0.5, "decay": {"hunger": 1.5, "thirst": 1.5, "bladder": 1.5, "hygiene": 1.5}},
	{"speed": 0.85},
	{"speed": 1.0},
	{"speed": 1.0},
	{"speed": 1.0},
	{"speed": 0.8, "decay": {"energy": 1.2}},
]


# Game days at which stage i starts.
static func stage_start(i: int) -> float:
	var total := 0.0
	for n in i:
		total += STAGES[n].days
	return total


static func stage(c: Node2D) -> int:
	for i in range(STAGES.size() - 1, -1, -1):
		if c.age_days >= stage_start(i):
			return i
	return 0


static func stage_name(c: Node2D) -> String:
	return STAGES[stage(c)].name


static func years(c: Node2D) -> float:
	var i := stage(c)
	var y: Array = STAGES[i].years
	var into: float = (c.age_days - stage_start(i)) / STAGES[i].days
	if i < STAGES.size() - 1:
		into = clampf(into, 0.0, 1.0)  # the last stage keeps going (90, 91, ...)
	return y[0] + (y[1] - y[0]) * into


# age_days for someone `y` years old (for setting up characters).
static func days_for_years(y: float) -> float:
	for i in STAGES.size():
		var r: Array = STAGES[i].years
		if i == STAGES.size() - 1:
			return stage_start(i) + maxf(0.0, (y - r[0]) / (r[1] - r[0])) * STAGES[i].days
		if y < r[1]:
			return stage_start(i) + clampf((y - r[0]) / (r[1] - r[0]), 0.0, 1.0) * STAGES[i].days
	return 0.0


static func is_grown_up(c: Node2D) -> bool:  # Young adult, Adult or Old
	return stage(c) >= YOUNG_ADULT


# Can this person have a baby now? Young adults and adults; women until menopause.
static func fertile(c: Node2D) -> bool:
	var s := stage(c)
	if s < YOUNG_ADULT:
		return false
	if c.sex == "F":
		return s <= ADULT and years(c) < MENOPAUSE_YEARS
	return true


static func describe(c: Node2D) -> String:  # "Young adult, 20, female"
	return "%s, %d, %s" % [stage_name(c), int(years(c)), "female" if c.sex == "F" else "male"]


# Parents, children and siblings.
static func family(a: Node2D, b: Node2D) -> bool:
	if a.npc_name in b.parents or b.npc_name in a.parents:
		return true
	for p in a.parents:
		if p in b.parents:
			return true
	return false
