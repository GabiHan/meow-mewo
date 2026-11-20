# Weather. Static. The world keeps the current weather (world.gd `weather`, changed every few game hours by next());
# it changes how far you can see outdoors (vision.gd), the colour of the sky (tint(), world.gd), the temperature,
# how the outside looks (weather_fx.gd: rain, snow, lightning, wind, haze) and how people outdoors feel (moodlet(),
# npc.gd look_around) and what they need (decay(), npc.gd). Full documentation: docs/VIEW.md "Weather".
const KINDS := {
	# sight    × how far you can see outdoors
	# icon     next to the clock
	# tint     × the outdoor sky colour by day (GameTime.tint): grey for clouds, dark for storms, warm in a heatwave
	# temp     °C added to the season's temperature
	# outdoors moodlet for people outside in it ("" = none); indoors: moodlet for people inside while it's out there
	# decay    need decay × for people outside
	"Clear": {"sight": 1.0, "icon": "☀", "tint": Color.WHITE, "temp": 2.0, "outdoors": "Sunny day",
		"about": "Clear skies and sunshine"},
	"Cloudy": {"sight": 0.85, "icon": "☁", "tint": Color(0.9, 0.9, 0.95), "temp": -1.0,
		"about": "Grey clouds, soft light"},
	"Windy": {"sight": 0.95, "icon": "≈", "tint": Color(0.96, 0.96, 0.98), "temp": -2.0, "outdoors": "Windswept",
		"about": "Gusts blowing leaves down the street", "decay": {"hygiene": 1.3}},
	"Rain": {"sight": 0.6, "icon": "☂", "tint": Color(0.8, 0.83, 0.93), "temp": -3.0, "outdoors": "Soaked",
		"indoors": "Cozy inside", "about": "Steady rain", "decay": {"hygiene": 1.5, "energy": 1.1}},
	"Storm": {"sight": 0.45, "icon": "⚡", "tint": Color(0.62, 0.64, 0.8), "temp": -4.0, "outdoors": "Caught in a storm",
		"indoors": "Cozy inside", "about": "Thunder, lightning and pouring rain", "decay": {"hygiene": 2.0, "energy": 1.2}},
	"Snow": {"sight": 0.7, "icon": "❄", "tint": Color(0.93, 0.95, 1.0), "temp": -6.0, "outdoors": "Snow day",
		"indoors": "Cozy inside", "about": "Snow falling softly", "decay": {"energy": 1.2, "hunger": 1.15}},
	"Fog": {"sight": 0.3, "icon": "≋", "tint": Color(0.95, 0.93, 0.94), "temp": -1.0,
		"about": "Thick fog: you can barely see"},
	"Heatwave": {"sight": 0.9, "icon": "♨", "tint": Color(1.0, 0.92, 0.82), "temp": 9.0, "outdoors": "Too hot",
		"about": "Scorching sun", "decay": {"thirst": 1.8, "energy": 1.2, "hygiene": 1.3}},
}
# How likely each kind is per season (weights).
const CHANCES := {
	"Spring": {"Clear": 4, "Cloudy": 3, "Windy": 2, "Rain": 3, "Storm": 1, "Fog": 1},
	"Summer": {"Clear": 6, "Cloudy": 2, "Windy": 1, "Rain": 1, "Storm": 1, "Heatwave": 2},
	"Fall": {"Clear": 3, "Cloudy": 3, "Windy": 3, "Rain": 3, "Storm": 1, "Fog": 3},
	"Winter": {"Clear": 3, "Cloudy": 3, "Windy": 1, "Rain": 1, "Snow": 4, "Fog": 2},
}
const MORNING_FOG := 3.0  # fog is this many times likelier before 10:00
const HOURS := [3.0, 8.0]  # how long a spell of weather lasts (game hours)
# Temperature (°C): the season's average, warmest at 15:00 and coldest at 03:00 (± SWING), plus the weather.
const SEASON_TEMP := {"Spring": 14.0, "Summer": 25.0, "Fall": 12.0, "Winter": 1.0}
const SWING := 5.0


static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS.Clear)


static func sight(kind: String) -> float:
	return info(kind).sight


static func icon(kind: String, night := false) -> String:
	return "☾" if night and kind == "Clear" else info(kind).icon


static func tint(kind: String) -> Color:
	return info(kind).tint


static func temperature(kind: String, season: String, hour: float) -> int:
	var day_curve := -cos((hour - 3.0) / 24.0 * TAU)  # −1 at 03:00, +1 at 15:00
	return roundi(SEASON_TEMP.get(season, 14.0) + day_curve * SWING + info(kind).temp)


# The moodlet the weather gives someone, outside (building −1) or inside: "" for none.
static func moodlet(kind: String, outside: bool) -> String:
	return info(kind).get("outdoors" if outside else "indoors", "")


# × how fast a need runs down for someone outside in this weather.
static func decay(kind: String, need: String, outside: bool) -> float:
	return info(kind).get("decay", {}).get(need, 1.0) if outside else 1.0


# "Rain, 9 °C — Steady rain"
static func describe(kind: String, season: String, hour: float) -> String:
	return "%s, %d °C — %s" % [kind, temperature(kind, season, hour), info(kind).about]


# The next spell of weather for this season and hour of the day.
static func next(season: String, hour: float) -> String:
	var weights: Dictionary = CHANCES.get(season, CHANCES.Spring).duplicate()
	if hour < 10.0 and weights.has("Fog"):
		weights.Fog = weights.Fog * MORNING_FOG
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return "Clear"


static func duration_seconds() -> float:
	return randf_range(HOURS[0], HOURS[1]) * 3600.0
