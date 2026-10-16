# The pastel, cutesy UI look: rounded light panels, candy-coloured buttons, soft lilac text. Static.
# Apply with `control.theme = UiTheme.get_theme()` on top-level controls (HUD, build mode, menus).
const INK := Color(0.36, 0.29, 0.48)  # text
const INK_SOFT := Color(0.36, 0.29, 0.48, 0.7)
const PANEL := Color(1.0, 0.97, 0.99, 0.93)
const PANEL_BORDER := Color(0.98, 0.78, 0.88)
const PINK := Color(1.0, 0.84, 0.9)
const PINK_HOVER := Color(1.0, 0.9, 0.94)
const MINT := Color(0.78, 0.94, 0.87)
const LILAC := Color(0.88, 0.85, 0.98)
const DISABLED := Color(0.94, 0.93, 0.96)

static var theme: Theme


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
		theme.set_stylebox("normal", type, box(PINK, 12))
		theme.set_stylebox("hover", type, box(PINK_HOVER, 12))
		theme.set_stylebox("pressed", type, box(MINT, 12))
		theme.set_stylebox("disabled", type, box(DISABLED, 12))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, 16, PANEL_BORDER))
	theme.set_stylebox("panel", "PopupMenu", box(PANEL, 12, PANEL_BORDER))
	theme.set_stylebox("hover", "PopupMenu", box(PINK, 8))
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", INK_SOFT)
	theme.set_color("font_separator_color", "PopupMenu", Color(0.75, 0.45, 0.65))
	theme.set_stylebox("normal", "LineEdit", box(Color.WHITE, 10, PANEL_BORDER))
	theme.set_stylebox("focus", "LineEdit", box(Color.WHITE, 10, Color(0.75, 0.6, 0.95)))
	theme.set_stylebox("background", "ProgressBar", box(Color(0.92, 0.89, 0.96), 6))
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL, 8, PANEL_BORDER))
	theme.set_color("font_color", "TooltipLabel", INK)
	return theme


static func box(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(2)
	s.shadow_color = Color(0.6, 0.45, 0.7, 0.12)
	s.shadow_size = 3
	return s
