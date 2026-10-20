# The game's look: cozy, like a paper planner in soft light. Two palettes and a calm serif theme. Static.
#   PALETTE  the atmosphere (soft blue → lavender grey → pink): the world (ground, houses, floors, sky,
#            the home screen) and the paper the UI is printed on.
#   ACCENTS  periwinkle → lilac: the UI's accent (thin borders, the active button, the mood line, bars,
#            skill chips, Today's dots).
# Cards and buttons are flat with thin borders and small corners. Text is EB Garamond (assets/fonts, SIL Open
# Font License), also for the labels in the world (npc.gd, smart_object.gd, block.gd set it on theirs).
# Apply with `control.theme = UiTheme.get_theme()` on top-level controls (HUD, build mode, menus).
const PALETTE := [
	Color("#c9def4"),  # 0 baby blue
	Color("#d0dbef"),  # 1
	Color("#d8d8e9"),  # 2 lavender grey
	Color("#dfd5e4"),  # 3
	Color("#e6d2df"),  # 4
	Color("#eecfd9"),  # 5
	Color("#f5ccd4"),  # 6 pink
]
const ACCENTS := [
	Color("#9ba9ff"),  # 0 periwinkle: borders of what's active, filled bars, dots
	Color("#a5adff"),
	Color("#afb1ff"),
	Color("#b9b5ff"),
	Color("#c4baff"),  # 4 soft borders
	Color("#cebeff"),
	Color("#d8c2ff"),
	Color("#e2c6ff"),  # 7 hover
	Color("#eccaff"),  # 8 pressed / active fill
	Color("#f4ccff"),  # 9 lightest lilac
]
const ACCENT := Color("#9ba9ff")
const ACCENT_SOFT := Color("#c4baff")
const ACTIVE_FILL := Color("#f3ecff")  # #eccaff over paper: the button that's on
const HOVER_FILL := Color("#f7f1ff")
const PAPER := Color("#f8f7fc")  # cards: the lavender grey, almost white
const PAPER_GLASS := Color(0.973, 0.969, 0.988, 0.95)
const LINE := Color("#dcd9ea")  # thin borders and separators
const INK := Color("#4a4766")  # text
const INK_SOFT := Color(0.29, 0.278, 0.4, 0.65)
const ROSE := Color("#ef9fb4")  # a need that's running low
const FONT := "res://assets/fonts/EBGaramond.ttf"
const FONT_ITALIC := "res://assets/fonts/EBGaramond-Italic.ttf"

static var theme: Theme
static var fonts := {}


static func shade(i: int) -> Color:
	return PALETTE[i]


# EB Garamond (or its italic), falling back to the system font for symbols it doesn't have (▶ ☰ ●).
static func font(italic := false) -> Font:
	if not fonts.has(italic):
		var f: Font = load(FONT_ITALIC if italic else FONT)
		f.fallbacks = [SystemFont.new()]
		fonts[italic] = f
	return fonts[italic]


# Let go of the fonts before the window closes (otherwise the renderer reports their glyph textures as leaked).
static func release() -> void:
	ThemeDB.fallback_font = null
	fonts.clear()
	theme = null


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


static func get_theme() -> Theme:
	if theme:
		return theme
	theme = Theme.new()
	theme.default_font = font()
	theme.default_font_size = 16
	ThemeDB.fallback_font = font()
	for type in ["Label", "Button", "LineEdit", "OptionButton", "PopupMenu", "CheckBox", "MenuButton", "ItemList"]:
		theme.set_color("font_color", type, INK)
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, Color(INK, 0.4))
		theme.set_stylebox("normal", type, flat(PAPER, LINE))
		theme.set_stylebox("hover", type, flat(HOVER_FILL, ACCENT_SOFT))
		theme.set_stylebox("pressed", type, flat(ACTIVE_FILL, ACCENT))
		theme.set_stylebox("hover_pressed", type, flat(ACTIVE_FILL, ACCENT))
		theme.set_stylebox("disabled", type, flat(Color(PAPER, 0.6), Color(LINE, 0.6)))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", box(PAPER_GLASS, 4))
	theme.set_stylebox("panel", "PopupMenu", box(PAPER, 4, LINE))
	theme.set_stylebox("hover", "PopupMenu", flat(ACTIVE_FILL, ACTIVE_FILL))
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", INK_SOFT)
	theme.set_color("font_separator_color", "PopupMenu", ACCENT)
	theme.set_stylebox("normal", "LineEdit", flat(Color.WHITE, LINE))
	theme.set_stylebox("focus", "LineEdit", flat(Color.WHITE, ACCENT))
	theme.set_stylebox("background", "ProgressBar", flat(LINE, LINE, 0, 2))
	theme.set_stylebox("fill", "ProgressBar", flat(ACCENT, ACCENT, 0, 2))
	theme.set_stylebox("panel", "TooltipPanel", box(PAPER, 4, LINE))
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_stylebox("separator", "HSeparator", line(false))
	theme.set_stylebox("separator", "VSeparator", line(true))
	theme.set_stylebox("panel", "AcceptDialog", box(PAPER, 4, LINE))
	var track := flat(LINE, LINE, 0, 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", flat(ACCENT, ACCENT, 0, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(ACCENT, ACCENT, 0, 2))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	return theme


# A flat button-ish rectangle: thin border, small corners.
static func flat(color: Color, border: Color, width := 1, radius := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


# A card: paper, small corners, an optional thin border and a soft lavender shadow.
static func box(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(mini(radius, 4))
	s.corner_detail = 6
	s.set_content_margin_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
	s.shadow_color = Color(0.45, 0.42, 0.7, 0.12)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s


static func line(vertical: bool) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = LINE
	s.vertical = vertical
	s.thickness = 1
	return s
