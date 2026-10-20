# Money and jobs. Static like social.gd. Full documentation: docs/WORK.md.
#
# Every character has `money` ($). Money comes from jobs and goes on food (kitchen.gd costs) and
# weekly bills (BILL every Monday at 00:00, per grown-up resident). Below $0 you feel "Broke" (Tense).
#
# Jobs are "rabbit holes", like The Sims: on a workday at the start time the worker walks to their home
# car and drives off (grown-ups with a job, if the car is free: traffic.gd) or to the Bus stop (main.gd
# OBJECTS), disappears to work (state "working", hidden, `at_work`), and comes
# back at the end time with the pay: hours worked × pay for their level. NPCs and the player in Auto
# mode go by themselves; in Manual mode you get a reminder and go via the Bus stop menu.
#
# Performance (0-100) changes at the end of each shift (shift_result) and on missed shifts. At 100,
# with enough skill for the next level, you're promoted (performance back to 0). A bad shift (or a
# missed one) that leaves performance at WARN_BELOW or less gets a warning; the next one gets you fired.
#
# Schools use the same machinery (`school: true`): no pay, performance is shown as a grade, and they're
# assigned by life stage (school_for_stage): Kindergarten (toddlers), School (children), High school
# (teens). College is optional for young adults; COLLEGE_DAYS attended days earn a degree, and with a
# degree new jobs start one level up. Jobs are for young adults and up (docs/LIFE.md).
const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Skills = preload("res://scripts/skills.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Ages = preload("res://scripts/ages.gd")
const Mind = preload("res://scripts/mind.gd")

# days: 0 = Monday … 6 = Sunday. start/end: hours. levels: [title, $ per hour, skill needed].
const JOBS := {
	"Café": {"skill": "Charisma", "days": [0, 1, 2, 3, 4], "start": 8, "end": 14,
		"levels": [["Barista", 15, 0], ["Shift lead", 22, 2], ["Café manager", 32, 4]]},
	"Restaurant": {"skill": "Cooking", "days": [2, 3, 4, 5, 6], "start": 16, "end": 22,
		"levels": [["Line cook", 18, 0], ["Sous-chef", 26, 4], ["Head chef", 40, 7]]},
	"Office": {"skill": "Logic", "days": [0, 1, 2, 3, 4], "start": 9, "end": 17,
		"levels": [["Intern", 16, 0], ["Analyst", 28, 3], ["Manager", 45, 6]]},
	"Gym": {"skill": "Fitness", "days": [0, 1, 2, 3, 4, 5], "start": 6, "end": 12,
		"levels": [["Assistant", 14, 0], ["Trainer", 22, 3], ["Head coach", 34, 6]]},
	"Comedy club": {"skill": "Comedy", "days": [3, 4, 5, 6], "start": 19, "end": 23,
		"levels": [["Open-mic comic", 12, 0], ["Opener", 25, 4], ["Headliner", 50, 7]]},
	# Schools: stage = who goes (ages.gd).
	"Kindergarten": {"school": true, "stage": 1, "skill": "Charisma", "days": [0, 1, 2, 3, 4], "start": 9, "end": 12,
		"levels": [["Kindergartner", 0, 0]]},
	"School": {"school": true, "stage": 2, "skill": "Logic", "days": [0, 1, 2, 3, 4], "start": 8, "end": 14,
		"levels": [["Pupil", 0, 0]]},
	"High school": {"school": true, "stage": 3, "skill": "Logic", "days": [0, 1, 2, 3, 4], "start": 8, "end": 15,
		"levels": [["Student", 0, 0]]},
	"College": {"school": true, "stage": 4, "skill": "Logic", "days": [0, 1, 2, 3], "start": 10, "end": 15,
		"levels": [["College student", 0, 0]]},
}
const COLLEGE_DAYS := 14  # attended days to graduate
const WARN_BELOW := 25.0
const SCHOOL_START := 50.0  # a new pupil's performance (grade C)

const BILL := 80  # per resident, every Monday at 00:00
const LATE_MINUTES := 30.0  # arriving later than this after the start counts as late
const SHIFT_BASE := 10.0  # performance per shift, before the modifiers below
const SKILL_PERFORMANCE := 2.0  # + this per level of the job's skill
const LATE_PENALTY := 10.0
const MISSED_PENALTY := 20.0
const EMOTION_PERFORMANCE := {"Happy": 5.0, "Confident": 8.0, "Focused": 8.0, "Energized": 5.0, "Playful": 3.0,
	"Sad": -5.0, "Angry": -8.0, "Tense": -5.0, "Uncomfortable": -5.0, "Embarrassed": -3.0, "Bored": -2.0}
const WORK_PRACTICE := 0.25  # the job's skill improves at this fraction of normal practice while at work


static func is_school(job: String) -> bool:
	return job != "" and JOBS[job].get("school", false)


# Report-card letter for a school performance.
static func grade(performance: float) -> String:
	if performance >= 90.0:
		return "A"
	if performance >= 75.0:
		return "B"
	if performance >= 60.0:
		return "C"
	if performance >= 40.0:
		return "D"
	return "F"


static func title(c: Node2D) -> String:
	return JOBS[c.job].levels[c.job_level][0] if c.job != "" else "Unemployed"


static func hourly(c: Node2D) -> int:
	return JOBS[c.job].levels[c.job_level][1]


static func schedule_text(job: String) -> String:
	var j: Dictionary = JOBS[job]
	var days: Array = j.days.map(func(d): return GameTime.WEEKDAYS[d].substr(0, 3))
	return "%s %02d:00–%02d:00" % [", ".join(days) if days.size() < 5 else "%s–%s" % [days[0], days[-1]], j.start, j.end]


static func is_workday(job: String, t: float) -> bool:
	return GameTime.day_index(t) % 7 in JOBS[job].days


# Is it time to be at work (and they haven't been yet today)?
static func should_work(c: Node2D, t: float) -> bool:
	if c.job == "" or not is_workday(c.job, t) or c.shift_day == GameTime.day_index(t):
		return false
	var h := GameTime.hours(t)
	return h >= JOBS[c.job].start and h < JOBS[c.job].end - 0.5


# When the next shift starts (game seconds), for the HUD.
static func next_shift(c: Node2D, t: float) -> float:
	var day := GameTime.day_index(t)
	for n in 8:
		var d := day + n
		var start: float = d * 86400.0 + JOBS[c.job].start * 3600.0
		if (d % 7) in JOBS[c.job].days and start + 3600.0 > t and c.shift_day != d:
			return start
	return -1.0


# --- Shifts ---

static func start_shift(c: Node2D) -> void:
	var t: float = c.world.now()
	c.at_work = true
	c.state = "working"
	c.shift_day = GameTime.day_index(t)
	c.shift_started = t
	c.late = GameTime.hours(t) * 60.0 > JOBS[c.job].start * 60.0 + LATE_MINUTES
	c.activity = ("At school (%s)" if is_school(c.job) else "At work (%s)") % c.job


# Called every frame while at work: practise the job's skill, and come home at the end time. Someone who
# drove (commute_car) comes home when the car has driven back and parked (traffic.gd parked_back).
static func working(c: Node2D, game_minutes: float) -> void:
	if c.commute_car and c.commute_car.mode != "away":
		return  # on the way: driving off, or already driving back
	c.practice(JOBS[c.job].skill, game_minutes * WORK_PRACTICE)
	if GameTime.hours(c.world.now()) >= JOBS[c.job].end:
		if c.commute_car:
			c.world.traffic.come_back(c.commute_car)
		else:
			finish_shift(c)


static func finish_shift(c: Node2D) -> void:
	var t: float = c.world.now()
	var day_end: float = GameTime.day_index(t) * 86400.0 + JOBS[c.job].end * 3600.0
	var hours := maxf(0.0, (minf(t, day_end) - c.shift_started) / 3600.0)
	var pay := int(round(hours * hourly(c)))
	var job: String = c.job
	c.work_log.append([t, hours])
	c.money += pay
	c.at_work = false
	c.state = "idle"
	c.activity = "Back from school" if is_school(job) else "Back from work"
	if pay > 0:
		Emotions.add(c, "Payday")
		Social.log_event("{a} earned $%d at the %s" % [pay, job], c, c)
	change_performance(c, shift_result(c))
	if job == "College" and c.job == "College":
		c.college_days += 1
		if c.college_days >= COLLEGE_DAYS:
			c.degree = true
			c.job = ""
			Emotions.add(c, "Graduated")
			Social.log_event("{a} graduated from college!", c, c)


# How a shift went: base + skill + emotion − lateness.
static func shift_result(c: Node2D) -> float:
	var result := SHIFT_BASE + SKILL_PERFORMANCE * Skills.level(c, JOBS[c.job].skill)
	result += EMOTION_PERFORMANCE.get(Emotions.emotion(c), 0.0) + Mind.bonus(c, "performance")
	if c.late:
		result -= LATE_PENALTY
	return result


static func change_performance(c: Node2D, amount: float) -> void:
	c.performance = clampf(c.performance + amount, 0.0, 100.0)
	if is_school(c.job):
		return  # grades only: no promotions, no firing
	if amount < 0.0 and c.performance <= WARN_BELOW:
		if c.warned:
			fire(c)
			return
		c.warned = true
		Emotions.add(c, "Warned at work")
		c.show_emote("\"One more slip and you're out.\"", null)
		Social.log_event("{a} got a warning at the %s" % c.job, c, c)
	elif c.performance > 50.0:
		c.warned = false
	var levels: Array = JOBS[c.job].levels
	if c.performance >= 100.0 and c.job_level + 1 < levels.size() \
			and Skills.level(c, JOBS[c.job].skill) >= levels[c.job_level + 1][2]:
		c.job_level += 1
		c.performance = 0.0
		Emotions.add(c, "Promoted")
		c.show_emote("Promoted to %s!" % title(c), null)
		Social.log_event("{a} was promoted to %s" % title(c), c, c)


# Checked every frame: a shift ended without them showing up.
static func check_missed(c: Node2D, t: float) -> void:
	if c.job == "" or c.at_work or not is_workday(c.job, t):
		return
	var day := GameTime.day_index(t)
	if c.shift_day != day and c.missed_day != day and GameTime.hours(t) >= JOBS[c.job].end - 0.5:
		c.missed_day = day
		change_performance(c, -MISSED_PENALTY)
		var school := is_school(c.job)
		Emotions.add(c, "Skipped school" if school else "Missed work")
		Social.log_event("{a} %s the %s" % ["skipped" if school else "missed work at", c.job], c, c)


static func fire(c: Node2D) -> void:
	Social.log_event("{a} was fired from the %s" % c.job, c, c)
	c.show_emote("Fired...", null)
	Emotions.add(c, "Fired")
	c.job = ""
	c.job_level = 0
	c.performance = 0.0
	c.warned = false


# Who may take this job: jobs and College are for young adults and up (College: once, no degree yet).
static func can_take(c: Node2D, job: String) -> bool:
	if job == "College":
		return Ages.stage(c) >= Ages.YOUNG_ADULT and not c.degree
	return not is_school(job) and Ages.is_grown_up(c)


static func take_job(c: Node2D, job: String) -> void:
	c.job = job
	c.job_level = mini(1, JOBS[job].levels.size() - 1) if c.degree and not is_school(job) else 0
	c.performance = SCHOOL_START if is_school(job) else 0.0
	c.warned = false
	c.shift_day = GameTime.day_index(c.world.now()) if should_work(c, c.world.now()) else -1  # start tomorrow, not mid-shift
	if is_school(job):
		Social.log_event("{a} enrolled in %s" % job, c, c)
	else:
		Social.log_event("{a} got a job: %s at the %s" % [title(c), job], c, c)


# Growing up changes school: toddlers → Kindergarten, children → School, teens → High school;
# young adults leave school (College is their choice).
static func school_for_stage(c: Node2D) -> void:
	var s := Ages.stage(c)
	for job in JOBS:
		if JOBS[job].get("school", false) and JOBS[job].stage == s and job != "College":
			c.job = job
			c.performance = SCHOOL_START
			c.shift_day = -1
			return
	if is_school(c.job) and c.job != "College":
		c.job = ""


static func quit_job(c: Node2D) -> void:
	Social.log_event("{a} quit the job at the %s" % c.job, c, c)
	c.job = ""


# --- Money ---

static func can_afford(c: Node2D, amount: int) -> bool:
	return c.money >= amount


# Pay for something; false (and nothing taken) if they can't afford it.
static func spend(c: Node2D, amount: int) -> bool:
	if c.money < amount:
		return false
	c.money -= amount
	return true


# Grown-up NPCs without a job look for one each morning: the job that best fits their skills
# (you choose your own at the Bus stop).
static func find_work(c: Node2D) -> void:
	if c.controlled or c.job != "" or not Ages.is_grown_up(c) or c.dead:
		return
	var best := ""
	var best_level := -1
	for name in JOBS:
		if not is_school(name) and Skills.level(c, JOBS[name].skill) > best_level:
			best = name
			best_level = Skills.level(c, JOBS[name].skill)
	take_job(c, best)


# Weekly bills, Monday 00:00 (world.gd calls this when a new day starts).
static func new_day(world: Node2D, day: int) -> void:
	for c in world.get_tree().get_nodes_in_group("characters"):
		find_work(c)
	if day % 7 != 0 or day == 0:
		return
	for c in world.get_tree().get_nodes_in_group("characters"):
		if c.home >= 0 and Ages.is_grown_up(c):  # parents pay, kids don't
			c.money -= BILL
			Social.log_event("{a} paid $%d in bills" % BILL, c, c)
