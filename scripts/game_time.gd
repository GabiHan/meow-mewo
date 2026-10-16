# Game time: clock, calendar, seasons and daylight. Static helpers; the running clock is
# world.clock (real seconds of simulation, affected by game speed). World.now() turns it into
# game seconds since the start of day 1 at 00:00.
#
# 1 real second = MINUTES_PER_SECOND game minutes, so a day lasts 24 real minutes at 1x speed
# (72 s at 20x). The game starts on day 1 (Monday, Spring, year 1) at START_HOUR.
# A year is 4 seasons of DAYS_PER_SEASON days.
const MINUTES_PER_SECOND := 1.0
const START_HOUR := 8.0
const DAYS_PER_SEASON := 7
const SEASONS := ["Spring", "Summer", "Fall", "Winter"]
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

# Sunrise and sunset (hours) per season: summer days are long, winter days short.
const SUN := {"Spring": [6.0, 20.0], "Summer": [5.5, 21.5], "Fall": [7.0, 19.0], "Winter": [8.0, 17.0]}
const TWILIGHT_HOURS := 1.0  # dawn and dusk fade over this long, centred on sunrise/sunset

# Screen tint (CanvasModulate). The HUD is never tinted.
# Indoors keeps the palette: no tint by day, soft pink lamplight at night.
const INDOOR_NIGHT_TINT := Color(0.953, 0.868, 0.896)
# Outdoors follows the sky (keyframes in sky_keys(), placed around the season's sunrise and sunset):
# deep night -> pink-lilac dawn -> cool blue morning -> bright afternoon -> golden hour -> sunset -> violet dusk.
const SKY := {
	"night": Color(0.36, 0.38, 0.62),
	"dawn": Color(0.86, 0.76, 0.9),
	"morning": Color(0.8, 0.87, 1.0),
	"late_morning": Color(0.92, 0.95, 1.0),
	"afternoon": Color.WHITE,
	"golden": Color(1.0, 0.84, 0.68),
	"sunset": Color(1.0, 0.72, 0.76),
	"dusk": Color(0.64, 0.54, 0.8),
}

# Season colours for terrain and trees (world.gd).
# Palette shades (ui_theme.gd): the ground is blue-lavender, changing gently with the seasons.
const GRASS := {"Spring": Color("#d0dbef"), "Summer": Color("#c9def4"),
	"Fall": Color("#e6d2df"), "Winter": Color(0.931, 0.931, 0.961)}
const LEAVES := {"Spring": Color(0.884, 0.736, 0.765), "Summer": Color(0.821, 0.714, 0.749),  # blossom pinks
	"Fall": Color(0.767, 0.700, 0.743), "Winter": Color(0.924, 0.924, 0.957)}


static func game_seconds(clock: float) -> float:
	return START_HOUR * 3600.0 + clock * MINUTES_PER_SECOND * 60.0


static func day_index(t: float) -> int:  # 0 = day 1
	return floori(t / 86400.0)


static func hours(t: float) -> float:  # 0..24
	return fmod(t, 86400.0) / 3600.0


static func clock_text(t: float) -> String:
	var s := int(fmod(t, 86400.0))
	return "%02d:%02d:%02d" % [s / 3600, s / 60 % 60, s % 60]


static func weekday(t: float) -> String:
	return WEEKDAYS[day_index(t) % 7]


static func season(t: float) -> String:
	return SEASONS[day_index(t) / DAYS_PER_SEASON % SEASONS.size()]


static func season_day(t: float) -> int:  # 1..DAYS_PER_SEASON
	return day_index(t) % DAYS_PER_SEASON + 1


static func year(t: float) -> int:
	return day_index(t) / (DAYS_PER_SEASON * SEASONS.size()) + 1


# 1 in full daylight, 0 at night, in between at dawn/dusk.
static func daylight(t: float) -> float:
	var sun: Array = SUN[season(t)]
	var h := hours(t)
	var half := TWILIGHT_HOURS / 2.0
	return smoothstep(sun[0] - half, sun[0] + half, h) * (1.0 - smoothstep(sun[1] - half, sun[1] + half, h))


static func is_night(t: float) -> bool:
	return daylight(t) < 0.5


static func part_of_day(t: float) -> String:
	if is_night(t):
		return "Night"
	var h := hours(t)
	if h < 12.0:
		return "Morning"
	if h < 17.0:
		return "Afternoon"
	return "Evening"


static func tint(t: float, indoors: bool) -> Color:
	if indoors:
		return INDOOR_NIGHT_TINT.lerp(Color.WHITE, daylight(t))
	var h := hours(t)
	var keys := sky_keys(season(t))
	for i in keys.size() - 1:
		if h <= keys[i + 1][0]:
			var w: float = inverse_lerp(keys[i][0], keys[i + 1][0], h)
			return (SKY[keys[i][1]] as Color).lerp(SKY[keys[i + 1][1]], smoothstep(0.0, 1.0, w))
	return SKY.night


# The outdoor sky through a day: [[hour, SKY key], ...] in order, from 0 to 24.
static func sky_keys(season_name: String) -> Array:
	var rise: float = SUN[season_name][0]
	var set_h: float = SUN[season_name][1]
	return [[0.0, "night"], [rise - 1.0, "night"], [rise, "dawn"], [rise + 1.0, "morning"],
		[maxf(rise + 2.0, 10.5), "late_morning"], [12.0, "afternoon"], [maxf(12.5, set_h - 2.0), "afternoon"],
		[set_h - 0.75, "golden"], [set_h, "sunset"], [set_h + 0.75, "dusk"], [set_h + 1.5, "night"], [24.0, "night"]]


# "Monday 08:15:00", "Spring, day 1 of 7, year 1"
static func date_text(t: float) -> String:
	return "%s, day %d of %d, year %d" % [season(t), season_day(t), DAYS_PER_SEASON, year(t)]
