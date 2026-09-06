class_name CyberDemoWorlds
extends RefCounted

# Construction commands only: x, y, width, height, material ID. The native
# adapter assigns the material's real initial state and runs the M11 solver.
const IDS: Array[String] = ["material_lab", "waterworks", "foundry", "neon_works", "physics_pit"]
const TITLES: Array[String] = ["Material Lab", "Waterworks", "Foundry", "Neon Works", "Physics Pit"]
const DESCRIPTIONS: Array[String] = [
	"79 materials. Paint, erase, and mix them.",
	"Reservoirs, slope films, viscosity, and rising gas.",
	"Combustion, molten materials, and blast-driven collapse.",
	"Industrial surfaces, glass, wet metal, and emissive finishes.",
	"Rapier rectangles, thin terrain, and cellular coupling.",
]

static func valid_id(id: String) -> bool:
	return id in IDS

static func title(id: String) -> String:
	var index: int = IDS.find(id)
	return TITLES[index] if index >= 0 else "Unknown demo"

static func spawn(_id: String) -> Vector2:
	return Vector2(24, 222)

static func _rect(out: PackedInt32Array, x: int, y: int, w: int, h: int, material: int) -> void:
	out.append_array(PackedInt32Array([x, y, w, h, material]))

static func _tank(out: PackedInt32Array, x: int, y: int, w: int, h: int, shell: int, liquid: int, depth: int) -> void:
	_rect(out, x, y, 3, h, shell)
	_rect(out, x + w - 3, y, 3, h, shell)
	_rect(out, x, y + h - 3, w, 3, shell)
	if depth > 0:
		_rect(out, x + 3, y + h - 3 - depth, w - 6, depth, liquid)

static func rectangles(id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not valid_id(id):
		return out
	# Closed 1024-square storage. The curated installation occupies 480x270.
	_rect(out, 0, 0, 1024, 1, 1)
	_rect(out, 0, 0, 1, 1024, 1)
	_rect(out, 1023, 0, 1, 1024, 1)
	_rect(out, 0, 1023, 1024, 1, 1)
	_rect(out, 1, 252, 638, 8, 58)
	_rect(out, 1, 260, 638, 10, 59)
	_rect(out, 4, 244, 54, 8, 62)
	_rect(out, 4, 243, 54, 1, 77)
	_rect(out, 475, 20, 4, 232, 62)
	_rect(out, 8, 8, 464, 3, 64)
	_rect(out, 8, 11, 2, 232, 68)
	match id:
		"material_lab":
			var materials: Array[int] = [2, 3, 16, 20, 21, 33]
			for i: int in range(materials.size()):
				var x: int = 66 + i * 65
				_tank(out, x, 58, 56, 53, 71, materials[i], 27)
				_rect(out, x + 3, 114, 50, 2, 77 if i % 2 == 0 else 78)
			for i: int in range(12):
				_rect(out, 66 + i * 32, 147, 24, 18, 38 + i)
				_rect(out, 66 + i * 32, 170, 24, 18, 57 + i)
			_tank(out, 75, 211, 106, 41, 62, 3, 19)
			_rect(out, 107, 233, 24, 6, 4)
			_tank(out, 205, 204, 100, 48, 58, 2, 18)
			_rect(out, 238, 196, 29, 7, 9)
			_rect(out, 344, 215, 75, 4, 7)
			_rect(out, 348, 212, 10, 3, 6)
			_rect(out, 360, 235, 34, 15, 27)
		"waterworks":
			_tank(out, 60, 30, 98, 65, 69, 3, 52)
			_rect(out, 155, 78, 3, 10, 0)
			for i: int in range(46):
				_rect(out, 157 + i * 3, 92 + i, 4, 3, 53)
			_tank(out, 278, 132, 183, 120, 71, 3, 32)
			_rect(out, 281, 191, 58, 22, 3)
			_rect(out, 392, 229, 33, 12, 4)
			_rect(out, 354, 155, 3, 76, 68)
			_tank(out, 64, 156, 90, 96, 71, 20, 39)
			_tank(out, 170, 156, 90, 96, 71, 21, 39)
			_rect(out, 151, 197, 3, 13, 0)
			_rect(out, 257, 197, 3, 13, 0)
			_rect(out, 183, 33, 83, 3, 77)
			_rect(out, 183, 40, 54, 2, 80)
			_rect(out, 325, 39, 5, 67, 68)
			_rect(out, 325, 39, 118, 5, 68)
			_rect(out, 443, 39, 5, 76, 68)
		"foundry":
			_rect(out, 60, 197, 114, 55, 43)
			_rect(out, 67, 205, 100, 37, 0)
			_rect(out, 70, 226, 93, 14, 27)
			_rect(out, 75, 217, 83, 8, 7)
			_rect(out, 76, 214, 9, 3, 6)
			_rect(out, 91, 66, 20, 127, 57)
			_rect(out, 96, 70, 10, 128, 0)
			_rect(out, 112, 69, 74, 5, 62)
			_tank(out, 190, 83, 111, 58, 58, 8, 35)
			_rect(out, 298, 116, 3, 12, 0)
			for i: int in range(24):
				_rect(out, 301 + i * 3, 138 + i, 4, 3, 62)
			_tank(out, 329, 175, 120, 77, 58, 36, 23)
			_rect(out, 190, 208, 98, 43, 1)
			_rect(out, 198, 214, 82, 23, 0)
			_rect(out, 204, 228, 69, 8, 26)
			_rect(out, 185, 248, 116, 4, 76)
			_rect(out, 197, 196, 83, 9, 46)
			_rect(out, 341, 69, 89, 3, 79)
			_rect(out, 368, 48, 34, 6, 8)
		"neon_works":
			_rect(out, 1, 252, 473, 8, 60)
			for i: int in range(5):
				var x: int = 64 + i * 79
				var roof: int = 74 + ((i * 31) % 55)
				_rect(out, x, roof, 64, 8, 62)
				_rect(out, x, roof + 8, 7, 244 - roof, 57 if i % 2 else 64)
				_rect(out, x + 57, roof + 8, 7, 244 - roof, 65)
				_rect(out, x + 8, roof + 13, 48, 42, 72)
				_rect(out, x + 12, roof + 17, 40, 3, 77 + i % 3)
				_rect(out, x + 12, roof + 24, 3, 25, 77 + i % 3)
				_rect(out, x + 21, roof + 29, 26, 2, 80)
				_rect(out, x + 21, roof + 35, 18, 2, 77 + i % 3)
				_rect(out, x + 9, roof + 63, 46, 3, 68)
				_rect(out, x + 9, 232, 46, 11, 76)
			_rect(out, 43, 39, 386, 4, 69)
			_rect(out, 43, 39, 4, 171, 69)
			_rect(out, 212, 23, 3, 42, 74)
			_rect(out, 203, 19, 62, 13, 63)
			_rect(out, 207, 22, 54, 3, 78)
			_rect(out, 284, 177, 67, 5, 62)
			_rect(out, 289, 185, 6, 58, 69)
			_rect(out, 315, 182, 26, 53, 71)
			_rect(out, 319, 199, 18, 31, 3)
			_rect(out, 362, 239, 51, 10, 16)
			_rect(out, 156, 222, 48, 13, 4)
			_rect(out, 220, 236, 45, 12, 3)
		"physics_pit":
			_rect(out, 80, 166, 88, 1, 1)
			_rect(out, 80, 167, 3, 85, 62)
			_rect(out, 165, 167, 3, 85, 62)
			_tank(out, 189, 169, 111, 83, 58, 3, 35)
			_tank(out, 322, 190, 125, 62, 58, 2, 25)
			_rect(out, 88, 58, 78, 3, 77)
			_rect(out, 200, 58, 86, 3, 78)
			_rect(out, 332, 58, 103, 3, 79)
	return out
