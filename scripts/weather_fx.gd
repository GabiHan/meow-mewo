# What the weather and the time of day look like on screen (a CanvasLayer under the HUD). Moves on real time, so
# it looks the same at any game speed. The weather itself is world.gd `weather` (weather.gd); how far you see is
# vision.gd; the sky colour is world.gd sky_color().
#
# Weather (outdoors; lightning flashes reach indoors too): rain streaks, a storm's heavier slanted rain and
# lightning, snowflakes, leaves (petals in spring) blowing past when it's windy, drifting cloud shadows, a cream
# haze in fog, a warm shimmer in a heatwave.
# Atmosphere (parts of the day, so each has its own mood): a honey haze from the morning sun (top left), a bright
# warm wash in the afternoon, amber golden-hour light from the west (right) with floating dust, and at night a
# plum-blue vignette with fireflies in spring and summer (indoors: a warm lamplit vignette instead).
extends CanvasLayer

const GameTime = preload("res://scripts/game_time.gd")

const DROPS := 320  # the storm uses all of them, rain half
const FLAKES := 140
const LEAVES := 26
const FIREFLIES := 18
const MOTES := 30
const RAIN_COLOR := Color(0.62, 0.68, 0.92, 0.45)  # periwinkle streaks (ui_theme.gd ACCENTS, softened)
const FOG_HAZE := Color(1.0, 0.97, 0.95, 0.28)  # cream
const HEAT_HAZE := Color(1.0, 0.82, 0.6, 0.1)
const CLOUD_SHADOW := Color(0.25, 0.22, 0.35, 0.1)
const FLASH := Color(0.95, 0.95, 1.0)
const MORNING_HAZE := Color(1.0, 0.9, 0.7, 0.26)
const AFTERNOON_WASH := Color(1.0, 0.97, 0.82, 0.12)
const GOLDEN_LIGHT := Color(1.0, 0.6, 0.3, 0.32)
const NIGHT_VIGNETTE := Color(0.08, 0.05, 0.2, 0.6)
const LAMP_VIGNETTE := Color(0.22, 0.1, 0.04, 0.35)
const FIREFLY := Color(0.93, 1.0, 0.55)
const MOTE := Color(1.0, 0.9, 0.65)

var world: Node2D
var canvas: Control
var drops := []  # Vector2 positions (0..1 of the screen)
var flakes := []
var leaves := []
var flies := []
var motes := []
var clouds := []
var last := 0
var time := 0.0  # real seconds
var flash := 0.0  # lightning: 1 at the strike, fades out
var next_flash := 4.0
var vignette: GradientTexture2D  # clear in the middle, solid at the edges
var blob: GradientTexture2D  # solid in the middle, clear at the edge (glows, cloud shadows)
var side: GradientTexture2D  # solid on the left, clear on the right


func setup(p_world: Node2D) -> CanvasLayer:
	world = p_world
	return self


func _ready() -> void:
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(paint)
	add_child(canvas)
	for n in DROPS:
		drops.append(Vector2(randf(), randf()))
	for n in FLAKES:
		flakes.append(Vector3(randf(), randf(), randf_range(1.2, 3.0)))
	for n in LEAVES:
		leaves.append(Vector3(randf(), randf(), randf() * TAU))
	for n in FIREFLIES:
		flies.append(Vector3(randf(), randf(), randf() * TAU))
	for n in MOTES:
		motes.append(Vector3(randf(), randf(), randf() * TAU))
	for n in 4:
		clouds.append(Vector2(randf(), randf()))
	vignette = gradient(GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 1.0), [0.0, 0.45, 1.0], [0.0, 0.0, 1.0])
	blob = gradient(GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 0.5), [0.0, 1.0], [1.0, 0.0])
	side = gradient(GradientTexture2D.FILL_LINEAR, Vector2(0.0, 0.0), Vector2(1.0, 0.0), [0.0, 1.0], [1.0, 0.0])
	last = Time.get_ticks_msec()


static func gradient(fill: int, from: Vector2, to: Vector2, offsets: Array, alphas: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(alphas.map(func(a): return Color(1, 1, 1, a)))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = fill
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	return tex


func outdoors() -> bool:
	return world.player != null and world.player.building < 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := minf((now - last) / 1000.0, 0.1)
	last = now
	time += dt
	var kind: String = world.weather
	if kind in ["Rain", "Storm"]:
		var fall := Vector2(0.08, 1.1) if kind == "Rain" else Vector2(0.3, 1.6)
		for n in drops.size():
			drops[n] += fall * dt
			if drops[n].y > 1.0:
				drops[n] = Vector2(randf() - 0.2, 0.0)
	if kind == "Storm":
		next_flash -= dt
		if next_flash <= 0.0:
			flash = 1.0
			next_flash = randf_range(3.0, 9.0)
	flash = maxf(0.0, flash - dt * 2.5)
	if kind == "Snow":
		for n in flakes.size():
			var f: Vector3 = flakes[n]
			f.y += dt * 0.05 * f.z
			f.x += dt * 0.01 * sin(time + n)
			flakes[n] = Vector3(randf(), 0.0, f.z) if f.y > 1.0 else f
	if kind in ["Windy", "Storm"]:
		for n in leaves.size():
			var l: Vector3 = leaves[n]
			l.x += dt * (0.35 + 0.1 * sin(n))
			l.y += dt * 0.04 * sin(time * 2.0 + n)
			l.z += dt * 4.0
			leaves[n] = Vector3(-0.05, randf(), l.z) if l.x > 1.05 else l
	for n in clouds.size():
		clouds[n].x = fmod(clouds[n].x + dt * 0.01, 1.4)
	canvas.queue_redraw()


# How much of each part of the day it is now (0..1): a bell around its hours.
func parts(t: float) -> Dictionary:
	var h := GameTime.hours(t)
	var sun: Array = GameTime.SUN[GameTime.season(t)]
	var bell := func(centre: float, width: float) -> float: return clampf(1.0 - absf(h - centre) / width, 0.0, 1.0)
	return {"morning": bell.call(sun[0] + 1.5, 2.5), "afternoon": bell.call(14.5, 2.5),
		"golden": bell.call(sun[1] - 0.6, 1.6), "night": 1.0 - GameTime.daylight(t)}


func paint() -> void:
	if world.player == null:
		return
	var size := canvas.size
	var full := Rect2(Vector2.ZERO, size)
	var t: float = world.now()
	var p := parts(t)
	var kind: String = world.weather
	var sunny: float = 1.0 if kind in ["Clear", "Heatwave", "Windy"] else 0.4  # clouds hide the sun's glow
	if not outdoors():
		paint_tint(vignette, full, LAMP_VIGNETTE, p.night)
		if flash > 0.0:
			canvas.draw_rect(full, Color(FLASH, flash * 0.2))
		return
	# The time of day
	paint_tint(blob, Rect2(-size * 0.45, size * 1.1), MORNING_HAZE, p.morning * sunny)
	paint_tint(side, Rect2(0, 0, size.x, size.y * 0.6).abs(), AFTERNOON_WASH, p.afternoon * sunny)
	paint_tint(side, Rect2(size.x, 0, -size.x * 0.8, size.y), GOLDEN_LIGHT, p.golden * sunny)
	if p.golden * sunny > 0.05:  # dust in the golden light
		for m: Vector3 in motes:
			var at := Vector2(fmod(m.x + time * 0.01, 1.0) * size.x * 0.5 + size.x * 0.5,
				fmod(m.y - time * 0.015 + 1.0, 1.0) * size.y)
			canvas.draw_circle(at, 1.6, Color(MOTE, 0.5 * p.golden * sunny * (0.5 + 0.5 * sin(time * 1.5 + m.z))))
	paint_tint(vignette, full, NIGHT_VIGNETTE, p.night)
	if p.night > 0.5 and GameTime.season(t) in ["Spring", "Summer"] and kind in ["Clear", "Cloudy", "Windy", "Heatwave"]:
		for f: Vector3 in flies:
			var at := Vector2(f.x + 0.03 * sin(time * 0.7 + f.z), f.y + 0.03 * cos(time * 0.5 + f.z)) * size
			var glow: float = maxf(0.0, sin(time * 1.3 + f.z)) * p.night
			canvas.draw_circle(at, 6.0, Color(FIREFLY, 0.12 * glow))
			canvas.draw_circle(at, 2.0, Color(FIREFLY, 0.9 * glow))
	# The weather
	if kind in ["Cloudy", "Storm", "Rain"]:
		for c: Vector2 in clouds:
			var at: Vector2 = (c - Vector2(0.2, 0.0)) * size
			paint_tint(blob, Rect2(at - size * 0.35, size * 0.7), CLOUD_SHADOW, 1.0 if kind == "Cloudy" else 1.5)
	match kind:
		"Fog":
			canvas.draw_rect(full, FOG_HAZE)
		"Heatwave":
			canvas.draw_rect(full, Color(HEAT_HAZE, HEAT_HAZE.a * (0.8 + 0.2 * sin(time * 2.0))))
		"Rain", "Storm":
			var count := DROPS if kind == "Storm" else DROPS / 2
			var streak := Vector2(3, 14) if kind == "Rain" else Vector2(7, 20)
			for n in count:
				var at: Vector2 = drops[n] * size
				canvas.draw_line(at, at + streak, RAIN_COLOR, 1.2)
		"Snow":
			for f: Vector3 in flakes:
				canvas.draw_circle(Vector2(f.x, f.y) * size, f.z, Color(1, 1, 1, 0.85))
	if kind in ["Windy", "Storm"]:
		var leaf: Color = GameTime.LEAVES[GameTime.season(t)].darkened(0.1)
		for l: Vector3 in leaves:
			var at := Vector2(l.x, l.y) * size
			canvas.draw_set_transform(at, l.z, Vector2(1.0, 0.45))
			canvas.draw_circle(Vector2.ZERO, 4.0, Color(leaf, 0.85))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		canvas.draw_rect(full, Color(FLASH, flash * 0.55))


func paint_tint(tex: Texture2D, rect: Rect2, color: Color, amount: float) -> void:
	if amount > 0.01:
		canvas.draw_texture_rect(tex, rect, false, Color(color, color.a * amount))
