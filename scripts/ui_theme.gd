# The game's look: Cozy Paws. Chunky rounded shapes, a cocoa outline around everything, hard "sticker" shadows and
# candy colours, in two themes: DAY (peach cream, coral petal) and DUSK (deep plum, lilac petal) after sunset.
# The design system lives in the Cozy Paws artifact; this file is its Godot side. Static.
#   PALETTE  the atmosphere (soft blue → lavender grey → pink): the world (ground, houses, floors, sky,
#            the home screen). Not part of the UI theme, unchanged.
#   DAY/DUSK the UI tokens (same names as the design system, `-` → `_`). `c("petal")` gives the current one.
#   Legacy names (ACCENT, PAPER, LINE, INK, ROSE…) are kept as the DAY values so older code still compiles; styleboxes
#            made with flat()/box()/sticker() and colours set with tint() follow set_dusk() by themselves.
# Text is Nunito (body, bold) and Fredoka (display: titles, names, numbers), both SIL Open Font License, in
# assets/fonts (OFL-Nunito.txt, OFL-Fredoka.txt). Apply with `control.theme = UiTheme.get_theme()` on top-level controls.
# Components built on this: scripts/ui/ (cozy_button, cozy_icon, need_bar, dialogue_box, toast_stack, item_tooltip,
# inventory_slot, hotbar).
const PALETTE := [
	Color("#c9def4"),  # 0 baby blue
	Color("#d0dbef"),  # 1
	Color("#d8d8e9"),  # 2 lavender grey
	Color("#dfd5e4"),  # 3
	Color("#e6d2df"),  # 4
	Color("#eecfd9"),  # 5
	Color("#f5ccd4"),  # 6 pink
]

const DAY := {
	"surface_100": Color("#fff1ec"),  # page / overlay ground
	"surface_200": Color("#fffaf6"),  # raised panels
	"surface_300": Color("#fbe1da"),  # sunken wells: bar tracks, empty slots, fields
	"line": Color("#f0d3cb"),  # soft separators inside panels
	"ink": Color("#5a3b3b"),
	"ink_muted": Color("#7a5552"),
	"outline": Color("#5a3b3b"),  # the sticker outline and hard shadow
	"petal": Color("#ee9aa0"),
	"petal_strong": Color("#e07f87"),
	"petal_soft": Color("#f7c9cb"),
	"petal_hover": Color("#fde8e4"),
	"on_petal": Color("#4a2a2a"),
	"leaf": Color("#a8d58c"),
	"on_leaf": Color("#2e4a1e"),
	"butter": Color("#f6d776"),
	"on_butter": Color("#5a4310"),
	"sky": Color("#b9ccf5"),
	"on_sky": Color("#26386b"),
	"berry": Color("#e86a6a"),
	"on_berry": Color("#4a1414"),
	"peach": Color("#f6b38a"),  # hunger
	"aqua": Color("#9fdcd0"),  # bladder
	"bubble": Color("#a9e0f0"),  # hygiene
	"focus": Color("#7e9be6"),
	"white": Color("#ffffff"),  # highlights on icons
}
const DUSK := {
	"surface_100": Color("#2a2340"),
	"surface_200": Color("#3b3355"),
	"surface_300": Color("#231d36"),
	"line": Color("#4f4470"),
	"ink": Color("#f7eeff"),
	"ink_muted": Color("#c9bce0"),
	"outline": Color("#1a1428"),
	"petal": Color("#c7b3f0"),
	"petal_strong": Color("#b39ce6"),
	"petal_soft": Color("#4f4470"),
	"petal_hover": Color("#463d63"),
	"on_petal": Color("#2a2140"),
	"leaf": Color("#8fcb7a"),
	"on_leaf": Color("#1f3514"),
	"butter": Color("#ffc86b"),
	"on_butter": Color("#4a3408"),
	"sky": Color("#7e9be6"),
	"on_sky": Color("#1b2550"),
	"berry": Color("#ff8c8c"),
	"on_berry": Color("#3a0e0e"),
	"peach": Color("#f0a77a"),
	"aqua": Color("#6fc4b4"),
	"bubble": Color("#7cc8e0"),
	"focus": Color("#ffc86b"),
	"white": Color("#ffffff"),
}
# Text on a fill: always its on_* pair, never ink or white.
const ON := {"petal": "on_petal", "petal_strong": "on_petal", "petal_soft": "ink", "leaf": "on_leaf", "butter": "on_butter",
	"sky": "on_sky", "berry": "on_berry", "peach": "on_butter", "aqua": "on_leaf", "bubble": "on_sky",
	"surface_100": "ink", "surface_200": "ink", "surface_300": "ink"}

# Shape tokens.
const RADIUS_SM := 10
const RADIUS_MD := 16
const RADIUS_LG := 24
const RADIUS_PILL := 999
const STROKE_SM := 2
const STROKE_MD := 3
const STROKE_LG := 4
const PRESS := 4  # the hard shadow under pressable things; pressed: 1
const SPACE := [0, 4, 8, 12, 16, 24, 32]  # space-1 … space-8 by index (SPACE[4] = 16)

# Legacy names (DAY values): kept so the rest of the game compiles; prefer c("token") in new code.
const ACCENTS := [
	Color("#e07f87"),  # 0 petal strong: borders of what's active, filled bars, dots
	Color("#e3878e"),
	Color("#e68f96"),
	Color("#ea949b"),
	Color("#ee9aa0"),  # 4 petal: soft borders
	Color("#f1a9ae"),
	Color("#f3b6ba"),
	Color("#f5bfc2"),  # 7 hover
	Color("#f7c9cb"),  # 8 pressed / active fill
	Color("#fbdcdd"),  # 9 lightest
]
const ACCENT := Color("#e07f87")
const ACCENT_SOFT := Color("#ee9aa0")
const ACTIVE_FILL := Color("#f7c9cb")
const HOVER_FILL := Color("#fde8e4")
const PAPER := Color("#fffaf6")
const PAPER_GLASS := Color(1.0, 0.98, 0.965, 0.96)
const LINE := Color("#f0d3cb")
const INK := Color("#5a3b3b")
const INK_SOFT := Color(0.353, 0.231, 0.231, 0.7)
const ROSE := Color("#e86a6a")  # berry: a need that's running low
const OUTLINE := Color("#5a3b3b")
const LEAF := Color("#a8d58c")
const BUTTER := Color("#f6d776")
const SKY := Color("#b9ccf5")
const FONT := "res://assets/fonts/Nunito.ttf"
const FONT_DISPLAY := "res://assets/fonts/Fredoka.ttf"
const BODY_WEIGHT := 700
const DISPLAY_WEIGHT := 600
const REDRAW_GROUP := "cozy_redraw"  # nodes that draw with c() (cozy_icon.gd): redrawn when the theme flips

static var theme: Theme
static var fonts := {}
static var dusk := false
static var _styles := []  # [WeakRef(StyleBoxFlat), bg token, border token, bg alpha, shadow token]
static var _tints := []  # [WeakRef(Control), theme colour name, token]
static var _lines := []  # WeakRef(StyleBoxLine): separators in the "line" token


# The current value of a token ("petal", "on_leaf"…).
static func c(token: String) -> Color:
	return (DUSK if dusk else DAY).get(token, Color.MAGENTA)


static func on(token: String) -> Color:
	return c(ON.get(token, "ink"))


# Which token a colour is (a DAY or DUSK value, or a legacy constant), "" if none.
static func token_of(color: Color) -> String:
	var opaque := Color(color, 1.0)
	for palette in [DAY, DUSK]:
		for key in palette:
			if palette[key].is_equal_approx(opaque):
				return key
	if opaque.is_equal_approx(Color(PAPER_GLASS, 1.0)):
		return "surface_200"
	for n in ACCENTS.size():
		if ACCENTS[n].is_equal_approx(opaque):
			return "petal_strong" if n < 4 else ("petal" if n < 7 else "petal_soft")
	return ""


static func shade(i: int) -> Color:
	return PALETTE[i]


# Nunito bold (or a slanted Nunito for `italic`), falling back to the system font for symbols it doesn't have (▶ ☰ ●).
static func font(italic := false) -> Font:
	var key := "italic" if italic else "body"
	if not fonts.has(key):
		var v := FontVariation.new()
		v.base_font = load(FONT)
		v.base_font.fallbacks = [SystemFont.new()]
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): BODY_WEIGHT}
		if italic:
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		fonts[key] = v
	return fonts[key]


# Fredoka semibold: titles, names, numbers.
static func display_font() -> Font:
	if not fonts.has("display"):
		var v := FontVariation.new()
		v.base_font = load(FONT_DISPLAY)
		v.base_font.fallbacks = [SystemFont.new()]
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): DISPLAY_WEIGHT}
		fonts["display"] = v
	return fonts["display"]


# Let go of the fonts before the window closes (otherwise the renderer reports their glyph textures as leaked).
static func release() -> void:
	ThemeDB.fallback_font = null
	fonts.clear()
	theme = null
	_styles.clear()
	_tints.clear()
	_lines.clear()


# The atmosphere behind everything: PALETTE from top (blue) to bottom (pink).
static func backdrop() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, PALETTE[0])
	gradient.set_color(1, PALETTE[6])
	for n in range(1, 6):
		gradient.add_point(n / 6.0, PALETTE[n])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = texture
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


# Day or dusk. Recolours the theme, every tracked stylebox and tint, and redraws the icons. Cheap when nothing changes.
static func set_dusk(on_: bool) -> void:
	if on_ == dusk:
		return
	dusk = on_
	_styles = _styles.filter(func(e): return e[0].get_ref() != null)
	for e in _styles:
		_paint(e[0].get_ref(), e[1], e[2], e[3], e[4])
	_tints = _tints.filter(func(e): return e[0].get_ref() != null)
	for e in _tints:
		e[0].get_ref().add_theme_color_override(e[1], c(e[2]))
	_lines = _lines.filter(func(w): return w.get_ref() != null)
	for w in _lines:
		w.get_ref().color = c("line")
	if theme:
		_theme_colors()
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group(REDRAW_GROUP, "queue_redraw")


# Give a control's theme colour (e.g. "font_color") a token that follows day/dusk.
static func tint(control: Control, color_name: String, token: String) -> void:
	control.add_theme_color_override(color_name, c(token))
	_tints.append([weakref(control), color_name, token])


static func _paint(s: StyleBoxFlat, bg: String, border: String, alpha: float, shadow: String) -> void:
	if bg != "":
		s.bg_color = Color(c(bg), alpha)
	if border != "":
		s.border_color = c(border)
	if shadow != "":
		s.shadow_color = c(shadow)


# Remember a stylebox so it follows set_dusk(). Colours that aren't tokens stay as they are.
static func track(s: StyleBoxFlat) -> StyleBoxFlat:
	var bg := token_of(s.bg_color)
	var border := token_of(s.border_color) if s.border_color.a > 0.0 else ""
	var shadow := token_of(s.shadow_color) if s.shadow_color.a > 0.0 else ""
	if bg == "" and border == "" and shadow == "":
		return s
	_styles.append([weakref(s), bg, border, s.bg_color.a, shadow])
	if dusk:
		_paint(s, bg, border, s.bg_color.a, shadow)
	return s


# The sticker look: a token fill, the cocoa outline, rounded corners and a hard shadow `press` px below.
static func sticker(fill: String, radius := RADIUS_MD, stroke := STROKE_MD, press := PRESS, border := "outline") -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c(fill)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.border_color = c(border)
	s.set_border_width_all(stroke)
	if press > 0:
		s.shadow_color = c("outline")
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, press)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	_styles.append([weakref(s), fill, border, 1.0, "outline" if press > 0 else ""])
	return s


# A panel: surface_200 (or `fill`), a thick outline, big corners and the panel shadow.
static func panel(fill := "surface_200", alpha := 1.0) -> StyleBoxFlat:
	var s := sticker(fill, RADIUS_LG - 4, STROKE_MD, 6)
	s.bg_color.a = alpha
	_styles[-1][3] = alpha
	s.set_content_margin_all(SPACE[4])
	return s


static func get_theme() -> Theme:
	if theme:
		return theme
	theme = Theme.new()
	theme.default_font = font()
	theme.default_font_size = 16
	ThemeDB.fallback_font = font()
	for type in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, button_style("surface_200"))
		theme.set_stylebox("hover", type, button_style("petal_hover"))
		theme.set_stylebox("pressed", type, button_style("petal_soft", true))
		theme.set_stylebox("hover_pressed", type, button_style("petal_soft", true))
		var off := button_style("surface_300", false, 2)
		off.border_color = Color(c("outline"), 0.4)
		theme.set_stylebox("disabled", type, off)
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_corner_radius_all(RADIUS_MD + 3)
		ring.border_color = c("focus")
		ring.set_border_width_all(3)
		ring.set_expand_margin_all(4)
		_styles.append([weakref(ring), "", "focus", 1.0, ""])
		theme.set_stylebox("focus", type, ring)
	theme.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", panel("surface_200", PAPER_GLASS.a))
	var popup := panel()
	popup.shadow_offset = Vector2(0, 4)
	popup.set_content_margin_all(8)
	theme.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover := sticker("petal_soft", RADIUS_SM, 0, 0)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	var field := sticker("surface_300", RADIUS_MD, STROKE_MD, 0)
	theme.set_stylebox("normal", "LineEdit", field)
	var field_focus := sticker("surface_200", RADIUS_MD, STROKE_MD, 0, "petal_strong")
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("background", "ProgressBar", sticker("surface_300", RADIUS_PILL, STROKE_SM, 0))
	var fill := sticker("petal", RADIUS_PILL, 0, 0)
	theme.set_stylebox("fill", "ProgressBar", fill)
	var tip := panel()
	tip.shadow_offset = Vector2(0, 3)
	tip.set_content_margin_all(10)
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_stylebox("separator", "HSeparator", line(false))
	theme.set_stylebox("separator", "VSeparator", line(true))
	theme.set_stylebox("panel", "AcceptDialog", panel())
	var track_style := sticker("surface_300", RADIUS_PILL, STROKE_SM, 0)
	track_style.content_margin_top = 3
	track_style.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track_style)
	theme.set_stylebox("grabber_area", "HSlider", sticker("petal", RADIUS_PILL, 0, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", sticker("petal_strong", RADIUS_PILL, 0, 0))
	_theme_colors()
	return theme


static func _theme_colors() -> void:
	for type in ["Label", "Button", "LineEdit", "OptionButton", "PopupMenu", "CheckBox", "MenuButton", "ItemList", "TooltipLabel"]:
		theme.set_color("font_color", type, c("ink"))
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		for name in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(name, type, c("ink"))
		theme.set_color("font_disabled_color", type, Color(c("ink"), 0.45))
	theme.set_color("font_placeholder_color", "LineEdit", c("ink_muted"))
	theme.set_color("caret_color", "LineEdit", c("ink"))
	theme.set_color("font_hover_color", "PopupMenu", c("ink"))
	theme.set_color("font_disabled_color", "PopupMenu", c("ink_muted"))
	theme.set_color("font_separator_color", "PopupMenu", c("petal_strong"))


# A button state in the sticker look; pressed sits 3 px lower (smaller shadow, text pushed down).
static func button_style(fill: String, pressed := false, stroke := STROKE_MD) -> StyleBoxFlat:
	var s := sticker(fill, RADIUS_MD, stroke, 1 if pressed else PRESS)
	s.content_margin_top = 6 + (3 if pressed else 0)
	s.content_margin_bottom = 6 - (3 if pressed else 0)
	return s


# A small flat rectangle (chips, simple buttons): a fill, a border, rounded. Follows day/dusk when the colours are tokens.
static func flat(color: Color, border: Color, width := 2, radius := RADIUS_SM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(maxi(radius, RADIUS_SM))
	s.corner_detail = 8
	s.border_color = border
	s.set_border_width_all(maxi(width, STROKE_SM) if border.a > 0.0 else 0)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return track(s)


# A card: a fill, big corners, the cocoa outline and the hard panel shadow (`border` is ignored unless it's the
# petal-strong accent: every card has the outline now).
static func box(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(maxi(radius, RADIUS_MD))
	s.corner_detail = 8
	s.set_content_margin_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.border_color = OUTLINE
	s.set_border_width_all(STROKE_MD)
	s.shadow_color = OUTLINE
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 5)
	if border.a > 0.0 and token_of(border) == "petal_strong":
		s.border_color = border  # an accent border still marks what's active
	return track(s)


static func line(vertical: bool) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = c("line")
	s.vertical = vertical
	s.thickness = 2
	_lines.append(weakref(s))
	return s
