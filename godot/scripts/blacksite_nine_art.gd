class_name CyberBlacksiteNineArt
extends RefCounted

# Tile-local authored geometry. The finished complex applies shared seam and
# circulation ownership after these detail layers. Everything here is native
# material geometry; framing glass, cables and grilles retain real collision.
const M = preload("res://scripts/neon_reliquary.gd")
const SIDE: int = 320
var data := PackedInt32Array()

func rect(x: int, y: int, width: int, height: int, material: int) -> void:
	var left: int = maxi(0, x)
	var top: int = maxi(0, y)
	var right: int = mini(SIDE, x + width)
	var bottom: int = mini(SIDE, y + height)
	if right > left and bottom > top:
		data.append_array(PackedInt32Array([left, top, right - left, bottom - top, material]))

func panel(x: int, y: int, width: int, height: int,
		fill: int = M.EMPTY, rim: int = M.IRON, inset: int = 3) -> void:
	rect(x, y, width, height, rim)
	rect(x + inset, y + inset, width - 2 * inset, height - 2 * inset, fill)
	rect(x + inset, y, width - 2 * inset, 1, M.RUSTED_STEEL)

func lamp(x: int, y: int, light: int = M.AMBER, width: int = 5) -> void:
	rect(x - 2, y - 2, width + 4, 7, M.IRON)
	rect(x, y, width, 2, light)
	rect(x, y + 3, width, 1, M.RUSTED_STEEL)

func console(x: int, y: int, width: int = 19, height: int = 14,
		light: int = M.CYAN) -> void:
	panel(x, y, width, height, M.DARK_GLASS, M.IRON, 2)
	rect(x + 4, y + 4, maxi(2, width - 8), 1, light)
	rect(x + 4, y + height - 4, 3, 1, M.AMBER)
	rect(x + width - 6, y + height - 4, 2, 1, M.CYAN)

func vent(x: int, y: int, width: int, height: int) -> void:
	panel(x, y, width, height, M.RUBBER, M.IRON, 2)
	for yy: int in range(y + 4, y + height - 2, 5):
		rect(x + 3, yy, width - 6, 1, M.STEEL)

func pipe(from: Vector2i, to: Vector2i, width: int = 7,
		material: int = M.RUSTED_STEEL) -> void:
	assert(from.x == to.x or from.y == to.y)
	if from.y == to.y:
		var x: int = mini(from.x, to.x)
		var length: int = absi(to.x - from.x) + 1
		rect(x, from.y - width / 2, length, width, M.RUBBER)
		rect(x, from.y - width / 2 + 1, length, width - 2, material)
		rect(x, from.y - width / 2 + 1, length, 1, M.COPPER_PIPE)
		for xx: int in range(x + 4, x + length - 3, 25):
			rect(xx, from.y - width / 2 - 1, 2, width + 2, M.IRON)
	else:
		var y: int = mini(from.y, to.y)
		var length: int = absi(to.y - from.y) + 1
		rect(from.x - width / 2, y, width, length, M.RUBBER)
		rect(from.x - width / 2 + 1, y, width - 2, length, material)
		rect(from.x - width / 2 + 1, y, 1, length, M.COPPER_PIPE)
		for yy: int in range(y + 4, y + length - 3, 25):
			rect(from.x - width / 2 - 1, yy, width + 2, 2, M.IRON)

func beam(from: Vector2i, to: Vector2i, width: int,
		material: int = M.IRON, step: int = 4) -> void:
	var count: int = maxi(1, ceili(Vector2(to - from).length() / float(step)))
	for index: int in range(count + 1):
		var point := Vector2i(Vector2(from).lerp(Vector2(to), float(index) / float(count)).round())
		rect(point.x - width / 2, point.y - width / 2, width, width, material)

func ellipse(cx: int, cy: int, rx: int, ry: int, material: int, step: int = 3) -> void:
	for dy: int in range(-ry, ry + 1, step):
		var half: int = floori(float(rx) * sqrt(maxf(0.0, 1.0 - pow(float(dy) / float(ry), 2.0))))
		rect(cx - half, cy + dy, 2 * half + 1, mini(step, ry - dy + 1), material)

func bolts(x: int, y: int, width: int, height: int) -> void:
	for point: Vector2i in [Vector2i(x + 2, y + 2), Vector2i(x + width - 4, y + 2),
		Vector2i(x + 2, y + height - 4), Vector2i(x + width - 4, y + height - 4)]:
		rect(point.x, point.y, 2, 2, M.STEEL)

func ribs(x: int, y: int, width: int, height: int, pitch: int = 12,
		material: int = M.IRON) -> void:
	for xx: int in range(x, x + width, pitch):
		rect(xx, y, 3, height, material)
		rect(xx + 3, y, 1, height, M.RUSTED_STEEL)

func rubble(x: int, y: int, width: int, height: int, seed: int) -> void:
	for index: int in range(12):
		var xx: int = x + posmod(index * 31 + seed * 7, maxi(1, width - 10))
		var yy: int = y + posmod(index * 17 + seed * 3, maxi(1, height - 6))
		rect(xx, yy, 4 + (index * 3) % 9, 3 + index % 5,
			[M.CONCRETE, M.SLATE, M.RUSTED_STEEL, M.RUBBER][index % 4])

func label(text: String, x: int, y: int, light: int = M.AMBER) -> void:
	# Sparse instrument labels reuse the original native stencil alphabet.
	for character: String in text.to_upper():
		if M.GLYPHS.has(character):
			var glyph: Array = M.GLYPHS[character]
			for row: int in range(5):
				for column: int in range(3):
					if str(glyph[row])[column] == "1": rect(x + column, y + row, 1, 1, light)
		x += 4
