# The game's look: the PALETTE (soft blue → lavender → pink) used for the world and the UI, and the
# bubbly UI theme (pill buttons with a candy "3D" bottom edge that squish when pressed). Static.
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
const INK := Color(0.36, 0.29, 0.48)  # text
const INK_SOFT := Color(0.36, 0.29, 0.48, 0.7)

static var theme: Theme


static func shade(i: int) -> Color:
	return PALETTE[i]


static func get_theme() -> Theme:
	if theme:
		return theme
	theme = Theme.new()
	theme.default_font_size = 14
	for type in ["Label", "Button", "LineEdit", "OptionButton", "PopupMenu", "CheckBox", "MenuButton", "ItemList"]:
		theme.set_color("font_color", type, INK)
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, Color(INK, 0.4))
		theme.set_stylebox("normal", type, bubble(PALETTE[6], false))
		theme.set_stylebox("hover", type, bubble(PALETTE[6].lightened(0.25), false))
		theme.set_stylebox("pressed", type, bubble(PALETTE[0], true))
		theme.set_stylebox("hover_pressed", type, bubble(PALETTE[0], true))
		theme.set_stylebox("disabled", type, bubble(PALETTE[2].lightened(0.35), false))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	var panel := box(PALETTE[2].lightened(0.7), 22, PALETTE[5])
	panel.bg_color.a = 0.94
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupMenu", box(PALETTE[2].lightened(0.75), 16, PALETTE[5]))
	theme.set_stylebox("hover", "PopupMenu", box(PALETTE[6], 12))
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", INK_SOFT)
	theme.set_color("font_separator_color", "PopupMenu", PALETTE[6].darkened(0.35))
	theme.set_stylebox("normal", "LineEdit", box(Color.WHITE, 18, PALETTE[5]))
	theme.set_stylebox("focus", "LineEdit", box(Color.WHITE, 18, PALETTE[0].darkened(0.15)))
	theme.set_stylebox("background", "ProgressBar", box(PALETTE[2].lightened(0.3), 8))
	theme.set_stylebox("panel", "TooltipPanel", box(PALETTE[2].lightened(0.75), 12, PALETTE[5]))
	theme.set_color("font_color", "TooltipLabel", INK)
	return theme


# A bubbly pill: round ends, a lighter top rim and a deeper bottom edge so it looks raised.
# Pressed, it sinks: the bottom edge shrinks and the text moves down.
static func bubble(color: Color, pressed: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(40)
	s.corner_detail = 12
	s.anti_aliasing = true
	s.border_color = color.darkened(0.14)
	s.border_width_bottom = 2 if pressed else 5
	s.border_width_top = 2
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_blend = true
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8 if pressed else 6
	s.content_margin_bottom = 4 if pressed else 8
	s.shadow_color = Color(0.55, 0.45, 0.7, 0.18 if pressed else 0.28)
	s.shadow_size = 2 if pressed else 5
	s.shadow_offset = Vector2(0, 1 if pressed else 3)
	return s


static func box(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.set_content_margin_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(2)
	s.shadow_color = Color(0.55, 0.45, 0.7, 0.14)
	s.shadow_size = 4
	return s
