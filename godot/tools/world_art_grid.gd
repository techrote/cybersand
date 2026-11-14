extends Control
## Pixel-anchored native-cell inspection grid; drawing is UI-only.
var native_size := Vector2i.ZERO
var world_origin := Vector2.ZERO
var world_zoom := 1.0

func _draw() -> void:
	if world_zoom < 6.0 or native_size.x <= 0 or native_size.y <= 0:
		return
	var first_x: int = maxi(0, floori(world_origin.x))
	var first_y: int = maxi(0, floori(world_origin.y))
	var last_x: int = mini(native_size.x, ceili(world_origin.x + size.x / world_zoom))
	var last_y: int = mini(native_size.y, ceili(world_origin.y + size.y / world_zoom))
	var shade := Color(0.43, 0.68, 0.75, 0.25)
	if last_x - first_x > 500 or last_y - first_y > 500:
		return
	for x: int in range(first_x, last_x + 1):
		var sx: float = (float(x) - world_origin.x) * world_zoom
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), shade, 1.0)
	for y: int in range(first_y, last_y + 1):
		var sy: float = (float(y) - world_origin.y) * world_zoom
		draw_line(Vector2(0, sy), Vector2(size.x, sy), shade, 1.0)
