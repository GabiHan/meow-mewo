# Isometric helpers. Game logic works in grid space (tiles); rendering uses screen space.
const TILE_W := 64.0
const TILE_H := 32.0


static func to_screen(grid: Vector2) -> Vector2:
	return Vector2((grid.x - grid.y) * TILE_W / 2.0, (grid.x + grid.y) * TILE_H / 2.0)


static func to_grid(screen: Vector2) -> Vector2:
	var gx := (screen.x / (TILE_W / 2.0) + screen.y / (TILE_H / 2.0)) / 2.0
	var gy := (screen.y / (TILE_H / 2.0) - screen.x / (TILE_W / 2.0)) / 2.0
	return Vector2(gx, gy)
