# What the weather looks like on screen (a CanvasLayer under the HUD): rain falling and a white haze in
# fog, only while you're outdoors. Moves on real time, so it looks the same at any game speed.
# The weather itself is world.gd `weather` (weather.gd); how far you see is vision.gd.
extends CanvasLayer

const DROPS := 160
const RAIN_COLOR := Color(0.62, 0.68, 0.92, 0.45)  # periwinkle streaks (ui_theme.gd ACCENTS, softened)
const FOG_HAZE := Color(0.97, 0.97, 1.0, 0.28)

var world: Node2D
var canvas: Control
var drops := []  # Vector2 positions (0..1 of the screen)
var last := 0


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
	last = Time.get_ticks_msec()


func outdoors() -> bool:
	return world.player != null and world.player.building < 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := (now - last) / 1000.0
	last = now
	if world.weather == "Rain":
		for n in drops.size():
			drops[n] += Vector2(0.08, 1.1) * dt
			if drops[n].y > 1.0:
				drops[n] = Vector2(randf(), 0.0)
	canvas.queue_redraw()


func paint() -> void:
	if not outdoors():
		return
	var size := canvas.size
	if world.weather == "Fog":
		canvas.draw_rect(Rect2(Vector2.ZERO, size), FOG_HAZE)
	elif world.weather == "Rain":
		for d in drops:
			var at: Vector2 = d * size
			canvas.draw_line(at, at + Vector2(3, 14), RAIN_COLOR, 1.2)
