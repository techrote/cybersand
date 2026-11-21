extends SceneTree

# BS-001 recovered equipment command contracts. This pure script probe exercises
# all thirteen original definitions against a strict native-API-shaped fake World.
# It is NOT a substitute for source-matched native transport or physical actor tests.
const Catalog = preload("res://scripts/usable_catalog.gd")
const Kinetics = preload("res://scripts/kinetic_usables.gd")
const Runtime = preload("res://scripts/usable_runtime.gd")

class FakeWorld:
	extends RefCounted
	var cells: Dictionary = {}
	var injected: Array[Dictionary] = []
	var transferred: Array[Dictionary] = []
	var failed: bool = false

	func has_failed() -> bool:
		return failed

	func material_at(x: int, y: int) -> int:
		return int(cells.get(Vector2i(x, y), 0))

	func rigid_body_id_at(_x: int, _y: int) -> int:
		return 0

	func inject_solid_parcel(position: Vector2, velocity: Vector2, material: int) -> String:
		injected.append({"position": position, "velocity": velocity, "material": material})
		return "launched"

	func inject_water_parcel(position: Vector2, velocity: Vector2, quantity: int) -> String:
		injected.append({"position": position, "velocity": velocity, "material": 3, "quantity": quantity})
		return "launched"

	func launch_solid_parcel(cell: Vector2i, position: Vector2, velocity: Vector2) -> String:
		return _transfer(cell, position, velocity)

	func launch_water_parcel(cell: Vector2i, position: Vector2, velocity: Vector2) -> String:
		return _transfer(cell, position, velocity)

	func _transfer(cell: Vector2i, position: Vector2, velocity: Vector2) -> String:
		var material := material_at(cell.x, cell.y)
		if material == 0:
			return "not_admitted"
		cells.erase(cell)
		transferred.append({"cell": cell, "position": position, "velocity": velocity, "material": material})
		return "launched"

	func fill() -> void:
		cells.clear()
		injected.clear()
		transferred.clear()
		for y in range(62, 102):
			for x in range(64, 110):
				cells[Vector2i(x, y)] = 2

var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("BS001_DISPATCH: " + label)

func _run() -> void:
	var world := FakeWorld.new()
	check(Catalog.count() == 45, "U01-U45 catalogue size")
	check(Catalog.USABLE_IDS[31] == &"firewarden", "U32 identity preserved")
	check(Catalog.KINETIC_IDS.size() == 13 and Kinetics.ORDER.size() == 13, "all thirteen known")
	for index in range(Kinetics.ORDER.size()):
		var id: String = Kinetics.ORDER[index]
		var definition: Dictionary = Catalog.entry(Catalog.index_for(StringName(id)))
		check(not definition.is_empty() and str(definition.get("kinetic", "")) == id
			and str(definition.get("operation", "")) == "kinetic", id + " ordinary catalogue routing")
		world.fill()
		var before := world.cells.size()
		var result: Dictionary = Kinetics.fire(world, Vector2i(256, 256), Vector2(80, 80),
			Vector2.RIGHT, id, 1.0, 100 + index)
		var entry: Dictionary = Kinetics.ENTRIES[id]
		if entry.kind == "shooter":
			check(int(result.launched) == int(entry.count) and world.injected.size() == int(entry.count),
				id + " injects the original admitted burst")
			check(world.transferred.is_empty() and world.cells.size() == before,
				id + " never substitutes existing-cell transfer")
			for item: Dictionary in world.injected:
				check(int(item.material) == int(entry.material), id + " keeps native material identity")
		else:
			check(int(result.launched) > 0 and not world.transferred.is_empty(),
				id + " launches real existing cells")
			check(world.injected.is_empty() and world.cells.size() + world.transferred.size() == before,
				id + " preserves existing-cell count with no injection")
	var disabled := FakeWorld.new()
	var index := Catalog.index_for(&"stone_slug")
	var runtime := Runtime.new()
	runtime.configure(1)
	var positions := PackedVector2Array([Vector2(80, 80)])
	var bounds: Array[Rect2] = [Rect2(76, 73, 8, 14)]
	var action := {"usable_index": index, "aim": Vector2.RIGHT, "power": 1.0,
		"trigger": false, "trigger_pressed": false, "alternate": false,
		"alternate_pressed": false, "cancel": false}
	runtime.step(1.0 / 60.0, disabled, positions, bounds, [action])
	action.trigger_pressed = true
	runtime.step(1.0 / 60.0, disabled, positions, bounds, [action])
	check(disabled.injected.size() == int(Kinetics.ENTRIES.stone_slug.count),
		"ordinary actor command invokes donor stone-slug native injection API")
	print("BS001_DISPATCH %d assertions %d failures" % [assertions, failures])
	quit(int(failures > 0))
