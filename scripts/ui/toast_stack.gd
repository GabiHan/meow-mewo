# Small HUD notifications (Cozy Paws "Toast"): a coloured badge with an icon, a title and an optional gentle line.
# Newest at the bottom, at most MAX at once, each for `seconds` (3 by default).
#   hud.toasts.push("Got a gift from Mochi", "Check your mailbox.", "item")
# Kinds: KINDS below (berry "warning" only for things the player should act on).
extends VBoxContainer

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")
const MAX := 3
const KINDS := {"item": ["petal", "gift"], "friendship": ["petal", "heart"], "coins": ["butter", "coin"],
	"growth": ["leaf", "sprout"], "info": ["sky", "sparkle"], "night": ["sky", "moon"], "warning": ["berry", "bolt"],
	"saved": ["leaf", "sparkle"]}

var until := {}  # toast -> msec it goes away


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(title: String, body := "", kind := "info", seconds := 3.0) -> PanelContainer:
	var t := make(title, body, kind)
	add_child(t)
	until[t] = Time.get_ticks_msec() + int(seconds * 1000.0)
	while get_child_count() > MAX:
		var oldest := get_child(0)
		until.erase(oldest)
		remove_child(oldest)
		oldest.queue_free()
	return t


# The latest toast's title ("" when none is showing).
func current() -> String:
	if get_child_count() == 0:
		return ""
	return get_child(get_child_count() - 1).get_meta("title", "")


static func make(title: String, body := "", kind := "info") -> PanelContainer:
	var k: Array = KINDS.get(kind, KINDS.info)
	var t := PanelContainer.new()
	t.set_meta("title", title)
	var style := UiTheme.sticker("surface_200", UiTheme.RADIUS_LG - 6, UiTheme.STROKE_MD, UiTheme.PRESS)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_right = 16
	t.add_theme_stylebox_override("panel", style)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	t.add_child(row)
	var badge := PanelContainer.new()
	var b := UiTheme.sticker(k[0], UiTheme.RADIUS_MD - 4, UiTheme.STROKE_MD, 0)
	b.set_content_margin_all(6)
	badge.add_theme_stylebox_override("panel", b)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(CozyIcon.make(k[1], 22))
	row.add_child(badge)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 15)
	UiTheme.tint(head, "font_color", "ink")
	words.add_child(head)
	if body != "":
		var line := Label.new()
		line.text = body
		line.add_theme_font_size_override("font_size", 13)
		UiTheme.tint(line, "font_color", "ink_muted")
		words.add_child(line)
	return t


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for t in until.keys():
		if now >= until[t]:
			until.erase(t)
			if is_instance_valid(t):
				t.queue_free()
