class_name CyberObjectShardLabPresets
extends RefCounted

# Authored material scenes, never pre-authored rigid-body motion. Additional
# fixtures use the same ordinary paused World edits as the owner's tools.
const TITLES: Array[String] = ["A · Ordinary detachment", "B · Burning Wood tree", "C · Water and Sand exchange",
	"D · Three reacting structures", "E · Perforated crown", "F · Long settling control",
	"G · Main structure and offcuts", "H · Irregular branching", "I · Diagonal / multi-support cuts",
	"J · Sustained external flame", "K · Extended play canvas"]


static func definition(number: int) -> Dictionary:
	var result: Dictionary = {"id": number, "title": TITLES[clampi(number - 1, 0, TITLES.size() - 1)],
		"scenario": number if number <= 6 else 0, "width": 192, "height": 128, "seed": 12,
		"fixture": "", "burner": false}
	match number:
		7:
			result.fixture = "offcuts"
		8:
			result.merge({"fixture": "irregular", "width": 256, "height": 160}, true)
		9:
			result.merge({"fixture": "multi_support", "width": 256, "height": 160}, true)
		10:
			result.merge({"scenario": 1, "width": 256, "height": 160, "burner": true}, true)
		11:
			result.merge({"fixture": "extended", "width": 320, "height": 192}, true)
	result["world_cells"] = int(result.width) * int(result.height)
	result["reference_carrier_bytes"] = int(result.world_cells) * 8
	return result


static func author(session: CyberObjectShardLabSession, preset: Dictionary) -> Dictionary:
	var operations: Array[Dictionary] = edits(preset)
	var counts: Dictionary = {"ok": true, "accepted_edits": 0, "refused_edits": 0}
	for offset: int in range(0, operations.size(), 32):
		var accepted: Dictionary = session.author_cells(operations.slice(offset, offset + 32))
		counts.ok = counts.ok and accepted.get("ok", false)
		counts.accepted_edits += int(accepted.get("accepted_edits", 0))
		counts.refused_edits += int(accepted.get("refused_edits", 0))
	if bool(preset.burner):
		session.set_burner(burner_band(session.frame), true)
	return counts


static func edits(preset: Dictionary) -> Array[Dictionary]:
	var writes: Dictionary = {}
	var width: int = int(preset.width)
	var floor_y: int = int(preset.height) - 18
	var fixture: String = str(preset.fixture)
	if not fixture.is_empty():
		_rect(writes, Rect2i(1, floor_y, width - 2, 1), 1)
	match fixture:
		"offcuts":
			_tree(writes, 48, floor_y, 36, 58)
			for x: int in range(94, 181, 12):
				_rect(writes, Rect2i(x, floor_y - 30, 3, 30), 7)
				_rect(writes, Rect2i(x - 2, floor_y - 32, 7, 3), 7)
		"irregular":
			_tree(writes, 128, floor_y, 44, 66)
			for index: int in range(8):
				_rect(writes, Rect2i(108 + index * 5, floor_y - 60 + (index % 3) * 3, 3, 10), 0)
			# Keep a genuine lower crown tie and join the left arm to the trunk.
			# The irregular holes must not pre-detach islands before any edit.
			_rect(writes, Rect2i(106, floor_y - 47, 44, 2), 7)
			_rect(writes, Rect2i(105, floor_y - 39, 26, 4), 7)
			_rect(writes, Rect2i(137, floor_y - 47, 17, 4), 7)
		"multi_support":
			_rect(writes, Rect2i(99, floor_y - 54, 58, 12), 7)
			_rect(writes, Rect2i(104, floor_y - 42, 5, 42), 7)
			_rect(writes, Rect2i(146, floor_y - 42, 5, 42), 7)
			_rect(writes, Rect2i(117, floor_y - 49, 20, 5), 0)
		"extended":
			for x: int in [76, 160, 244]:
				_tree(writes, x, floor_y, 34, 58)
			_rect(writes, Rect2i(71, floor_y - 5, 2, 5), 1)
			_rect(writes, Rect2i(245, floor_y - 3, 3, 3), 1)
	# Sort independently of hash insertion order; traces record every exact tuple.
	var coordinates: Array = writes.keys()
	coordinates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var operations: Array[Dictionary] = []
	for position: Vector2i in coordinates:
		operations.append({"position": position, "material": int(writes[position])})
	return operations


static func burner_band(frame: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center: int = int(frame.get("width", 192)) / 2
	var y: int = int(frame.get("height", 128)) - 18 - 29
	for x: int in range(center - 16, center + 17):
		cells.append(Vector2i(x, y))
	return cells


static func hint(number: int) -> String:
	var hints: Array[String] = [
		"Sever the Wood support and Resume. Inspect any refused component; exact material stays with its current owner.",
		"Historical burning control. Weak self-sustaining Wood combustion is unchanged. Use Ignite or the visible external burner for sustained erosion.",
		"Sand enters only through the open green pocket. Most Sand legitimately bypasses it. Water contact extinguishes Wood without transferring Water.",
		"Three reacting structures: sever supports, allow collision and wait after rest. Export an incident when motion or erosion looks wrong.",
		"Perforated geometry: preserve the holes while making horizontal and diagonal cuts. Shape capacity is independent of occupied-cell count.",
		"Chemistry-free three-body control. Let bodies settle, then use Erode resting cell to remove one real structural cell and observe contact recovery.",
		"Pause and make one horizontal cut across the supports. The main crown competes with eight smaller offcuts; watch eligibility, slots and deferred sizes.",
		"256×160 canvas with irregular branches and negative space. Check diagonal cuts, genuine remaining bonds and repeat editing after detachment.",
		"Both supports carry the same bridge. Cutting only one support should retain anchoring; sever both for genuine detachment.",
		"Visible external Fire fixture. Authored Fire is counted separately from chemistry products. Toggle the burner; the accepted Wood law decides ignition.",
		"320×192 canvas, three substantial structures and asymmetric ledges. Continue cuts, collisions, settling and resets while the bounded trace records actions."
	]
	return hints[clampi(number - 1, 0, hints.size() - 1)]


static func _tree(writes: Dictionary, x: int, floor_y: int, crown_width: int, height: int) -> void:
	_rect(writes, Rect2i(x - 2, floor_y - height + 18, 5, height - 18), 7)
	_rect(writes, Rect2i(x - crown_width / 2, floor_y - height, crown_width, 21), 7)
	_rect(writes, Rect2i(x - crown_width / 2, floor_y - height, 5, 5), 0)
	_rect(writes, Rect2i(x + 7, floor_y - height, 3, 13), 0)


static func _rect(writes: Dictionary, rectangle: Rect2i, material: int) -> void:
	for y: int in range(rectangle.position.y, rectangle.end.y):
		for x: int in range(rectangle.position.x, rectangle.end.x):
			writes[Vector2i(x, y)] = material
