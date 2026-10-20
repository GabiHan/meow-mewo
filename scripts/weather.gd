# Weather: clear, cloudy, rain or fog. Static. The world keeps the current weather (world.gd `weather`,
# changed every few game hours by next()); it changes how far you can see outdoors (vision.gd) and how
# the outside looks (weather_fx.gd: rain falling, a white veil in fog). Full documentation: docs/VIEW.md.
const KINDS := {
	# sight: × how far you can see outdoors. icon: next to the clock.
	"Clear": {"sight": 1.0, "icon": "☀"},
	"Cloudy": {"sight": 0.85, "icon": "☁"},
	"Rain": {"sight": 0.6, "icon": "☂"},
	"Fog": {"sight": 0.3, "icon": "≋"},
}
# How likely each kind is per season (weights).
const CHANCES := {
	"Spring": {"Clear": 4, "Cloudy": 3, "Rain": 3, "Fog": 1},
	"Summer": {"Clear": 7, "Cloudy": 2, "Rain": 1, "Fog": 0},
	"Fall": {"Clear": 3, "Cloudy": 3, "Rain": 3, "Fog": 3},
	"Winter": {"Clear": 3, "Cloudy": 4, "Rain": 2, "Fog": 2},
}
const MORNING_FOG := 3.0  # fog is this many times likelier before 10:00
const HOURS := [3.0, 8.0]  # how long a spell of weather lasts (game hours)


static func sight(kind: String) -> float:
	return KINDS.get(kind, KINDS.Clear).sight


static func icon(kind: String) -> String:
	return KINDS.get(kind, KINDS.Clear).icon


# The next spell of weather for this season and hour of the day.
static func next(season: String, hour: float) -> String:
	var weights: Dictionary = CHANCES.get(season, CHANCES.Spring).duplicate()
	if hour < 10.0:
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
