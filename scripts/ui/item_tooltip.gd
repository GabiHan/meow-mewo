# The card for an item (Cozy Paws "ItemTooltip"): name, a rarity tag, one or two cosy sentences, the sell price.
#   ItemTooltip.make("Wild strawberry", "fresh", "Sweet and sun-warm.", 40, "x12")
# Rarity: common (sky), fresh (leaf), rare (butter), special (petal). Use it as a Control's _make_custom_tooltip().
extends RefCounted

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")
const RARITY := {"common": ["sky", "Common"], "fresh": ["leaf", "Fresh"], "rare": ["butter", "Rare"], "special": ["petal", "Special"]}


static func make(name: String, rarity := "common", description := "", price := -1, meta := "") -> PanelContainer:
	var r: Array = RARITY.get(rarity, RARITY.common)
	var card := PanelContainer.new()
	var style := UiTheme.sticker("surface_200", UiTheme.RADIUS_MD, UiTheme.STROKE_MD, UiTheme.PRESS)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(240, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UiTheme.display_font())
	title.add_theme_font_size_override("font_size", 18)
	UiTheme.tint(title, "font_color", "ink")
	head.add_child(title)
	var tag := Label.new()
	tag.text = r[1]
	tag.add_theme_font_size_override("font_size", 11)
	UiTheme.tint(tag, "font_color", UiTheme.ON[r[0]])
	var tag_style := UiTheme.sticker(r[0], UiTheme.RADIUS_SM, UiTheme.STROKE_SM, 0)
	tag_style.content_margin_left = 8
	tag_style.content_margin_right = 8
	tag_style.content_margin_top = 0
	tag_style.content_margin_bottom = 1
	tag.add_theme_stylebox_override("normal", tag_style)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	if description != "":
		var desc := Label.new()
		desc.text = description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		UiTheme.tint(desc, "font_color", "ink_muted")
		column.add_child(desc)
	if price >= 0 or meta != "":
		column.add_child(HSeparator.new())
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 4)
		column.add_child(foot)
		if price >= 0:
			foot.add_child(CozyIcon.make("coin", 16))
			var p := Label.new()
			p.text = "Sells for %d" % price
			p.add_theme_font_size_override("font_size", 12)
			UiTheme.tint(p, "font_color", "ink")
			foot.add_child(p)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap)
		if meta != "":
			var m := Label.new()
			m.text = meta
			m.add_theme_font_size_override("font_size", 12)
			UiTheme.tint(m, "font_color", "ink_muted")
			foot.add_child(m)
	return card
