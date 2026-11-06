# Prepares the character-creator art (assets/doll, the "build a character" paper doll: every layer is a
# 444×700 picture on the same canvas) for the game: each layer is scaled to half size, cropped to what it
# draws and saved to art/doll/<part>/<n>.png; where it goes on the canvas is written to art/doll/doll.cfg.
# Headless is fine:  godot --headless -s res://tools/import_doll.gd   (then godot --headless --import)
#
#   WHITEN parts (mouth, eyebrows, beard) become white so the game can tint them (lips, hair colour).
#   doll.cfg [tone] n = the skin colour of body n (sampled on the cheek), used to tint the figure layers.
#   doll.cfg [canvas] feet = the point between the feet, the doll's origin in the game.
extends SceneTree

const SRC := "res://assets/doll/"
const OUT := "res://art/doll/"
const SCALE := 0.5
const PARTS := ["skin", "figure", "hair", "bangs", "back", "bonus", "eyes", "mouth", "brows", "lashes", "beard",
	"top", "bottom", "dress", "shoes", "gloves"]
const WHITEN := ["mouth", "brows", "beard"]


func _init() -> void:
	var cfg := ConfigFile.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for part in PARTS:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + part))
		var n := 1
		while FileAccess.file_exists(SRC + "%s/%d.png" % [part, n]):
			var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "%s/%d.png" % [part, n]))
			img.convert(Image.FORMAT_RGBA8)
			if part in WHITEN:
				whiten(img)
			img.resize(int(img.get_width() * SCALE), int(img.get_height() * SCALE), Image.INTERPOLATE_LANCZOS)
			var used := img.get_used_rect()
			if part == "skin":
				cfg.set_value("tone", str(n), cheek(img))
				if n == 1:
					cfg.set_value("canvas", "feet", Vector2(used.position.x + used.size.x / 2.0, used.end.y - 4))
					cfg.set_value("canvas", "body", used)
			img.get_region(used).save_png(ProjectSettings.globalize_path(OUT + "%s/%d.png" % [part, n]))
			cfg.set_value(part, str(n), used.position)
			n += 1
		cfg.set_value("count", part, n - 1)
		print("%s: %d" % [part, n - 1])
	cfg.set_value("canvas", "size", Vector2i(int(444 * SCALE), int(700 * SCALE)))
	cfg.save(OUT + "doll.cfg")
	quit()


# Keep the shape (alpha), make every pixel white: the game tints it.
func whiten(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, c.a))


# The skin colour: the most common opaque colour of the head (the cheek area, away from outlines).
func cheek(img: Image) -> Color:
	var counts := {}
	var used := img.get_used_rect()
	for y in range(used.position.y + 20, used.position.y + 60):
		for x in range(used.position.x + 20, used.end.x - 20):
			var c := img.get_pixel(x, y)
			if c.a > 0.99:
				var key := c.to_html(false)
				counts[key] = counts.get(key, 0) + 1
	var best := "ffffff"
	for key in counts:
		if counts[key] > counts.get(best, 0):
			best = key
	return Color.html(best)
