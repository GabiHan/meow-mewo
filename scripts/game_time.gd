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

# Screen tint (CanvasModulate). Full daylight is no tint; indoors at night the lamps are on.
const NIGHT_TINT := Color(0.62, 0.6, 0.86)  # a soft lavender night
const DUSK_TINT := Color(1.0, 0.84, 0.82)
const INDOOR_NIGHT_TINT := Color(1.0, 0.9, 0.86)

# Season colours for terrain and trees (world.gd).
const GRASS := {"Spring": Color(0.72, 0.9, 0.74), "Summer": Color(0.78, 0.92, 0.66),
	"Fall": Color(0.98, 0.86, 0.68), "Winter": Color(0.95, 0.96, 1.0)}
const LEAVES := {"Spring": Color(1.0, 0.76, 0.86), "Summer": Color(0.6, 0.86, 0.62),  # cherry blossom in spring
	"Fall": Color(1.0, 0.7, 0.45), "Winter": Color(0.97, 0.98, 1.0)}


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
	var d := daylight(t)
	if indoors:
		return INDOOR_NIGHT_TINT.lerp(Color.WHITE, d)
	var c := NIGHT_TINT.lerp(Color.WHITE, d)
	return c.lerp(c * DUSK_TINT, 1.0 - absf(d * 2.0 - 1.0))  # warm at dawn and dusk


# "Monday 08:15:00", "Spring, day 1 of 7, year 1"
static func date_text(t: float) -> String:
	return "%s, day %d of %d, year %d" % [season(t), season_day(t), DAYS_PER_SEASON, year(t)]
