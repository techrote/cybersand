extends SceneTree

const Catalog = preload("res://scripts/usable_catalog.gd")
const Runtime = preload("res://scripts/usable_runtime.gd")

class FakeWorld:
	extends RefCounted
	var cells: Dictionary = {}
	var failed: bool = false

	func has_failed() -> bool:
		return failed

	func material_at(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= 1024 or y >= 1024:
			return 1
		return int(cells.get(Vector2i(x,y), 0))

	func emit_disc(x: int, y: int, radius: int, material: int, _flags: int = 0) -> void:
		for yy: int in range(y - radius, y + radius + 1):
			for xx: int in range(x - radius, x + radius + 1):
				if Vector2(xx - x, yy - y).length() <= float(radius) + 0.25:
					cells[Vector2i(xx,yy)] = material

var failures: int = 0
var assertions: int = 0
var runtime := Runtime.new()
var world := FakeWorld.new()
var centres := PackedVector2Array([Vector2(100,100)])
var bounds: Array[Rect2] = [Rect2(96,93,8,14)]

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)

func _action(index: int, trigger: bool = false, pressed: bool = false, alternate_pressed: bool = false, power: float = 1.0) -> Dictionary:
	return {
		"usable_index": index, "aim": Vector2.RIGHT, "power": power,
		"trigger": trigger, "trigger_pressed": pressed,
		"alternate": false, "alternate_pressed": alternate_pressed, "cancel": false,
	}

func _step(action: Dictionary, dt: float = 1.0 / 60.0) -> void:
	runtime.step(dt, world, centres, bounds, [action])

func _equip(index: int) -> void:
	_step(_action(index))

func _count_material(material: int) -> int:
	var count: int = 0
	for value in world.cells.values():
		if int(value) == material:
			count += 1
	return count

func _catalogue() -> void:
	_expect(Catalog.count() == 32, "catalogue no longer contains 32 usables")
	_expect(Catalog.TOOL_IDS.size() == 12, "tool count changed")
	_expect(Catalog.PROJECTILE_IDS.size() == 10, "projectile count changed")
	_expect(Catalog.OBJECT_IDS.size() == 10, "object count changed")
	_expect(Catalog.USABLE_IDS[0] == &"sand_scatter" and Catalog.USABLE_IDS[31] == &"firewarden", "stable U01/U32 identities changed")
	var seen: Dictionary = {}
	for index: int in range(Catalog.count()):
		var definition: Dictionary = Catalog.entry(index)
		_expect(not definition.is_empty(), "missing catalogue definition " + str(index))
		_expect(Catalog.index_for(StringName(str(definition.id))) == index, "catalogue ID/index round-trip failed")
		_expect(not seen.has(definition.id), "duplicate usable id")
		seen[definition.id] = true
		_expect(float(definition.get("cost", -1.0)) >= 0.0, "negative/missing charge cost")
		_expect(float(definition.get("cooldown", -1.0)) >= 0.0, "negative/missing cooldown")
	_expect(Catalog.entry(&"brine_splitter").inputs == [[24,2]], "Brine Splitter input recipe drifted")
	_expect(Catalog.entry(&"brine_splitter").outputs == [[3,1],[23,1]], "Brine Splitter output recipe drifted")
	_expect(Catalog.entry(&"glass_kiln").catalyst_any == [6,8], "Glass Kiln catalyst drifted")
	_expect(int(Catalog.entry(&"firewarden").stock) == 12, "Firewarden stock drifted")

func _tools() -> void:
	runtime.configure(1)
	world.cells.clear()
	_equip(Catalog.index_for(&"sand_scatter"))
	_step(_action(Catalog.index_for(&"sand_scatter"), true, true))
	_expect(_count_material(2) > 5, "Sand Scatter did not deposit a broad fan")
	var primary_furthest_x: int = 0
	for point: Vector2i in world.cells.keys():
		if int(world.cells[point]) == 2:
			primary_furthest_x = maxi(primary_furthest_x, point.x)
	world.cells.clear()
	_step(_action(Catalog.index_for(&"sand_scatter")), 1.0 / 15.0)
	_step(_action(Catalog.index_for(&"sand_scatter")), 1.0 / 15.0)
	_step(_action(Catalog.index_for(&"sand_scatter"), false, false, true, 1.0))
	_expect(int(runtime.snapshot().write_count_last) > 0, "tool secondary precision pulse did not apply")
	var precision_furthest_x: int = 0
	for point: Vector2i in world.cells.keys():
		if int(world.cells[point]) == 2:
			precision_furthest_x = maxi(precision_furthest_x, point.x)
	_expect(
		precision_furthest_x > 100 and precision_furthest_x < primary_furthest_x,
		"precision pulse did not reduce Sand Scatter reach"
	)

	runtime.configure(1)
	world.cells.clear()
	for x: int in [107,110,114]:
		world.cells[Vector2i(x,100)] = 13
	world.cells[Vector2i(110,100)] = 1
	_equip(Catalog.index_for(&"line_cutter"))
	_step(_action(Catalog.index_for(&"line_cutter"), true, true))
	_expect(world.material_at(107,100) == 0, "Line Cutter did not remove exposed editable material")
	_expect(world.material_at(110,100) == 1, "Line Cutter removed protected Wall")
	_expect(world.material_at(114,100) == 13, "Line Cutter reached through a protected Wall")

	runtime.configure(1)
	world.cells.clear()
	world.cells[Vector2i(122,100)] = 35
	world.cells[Vector2i(126,100)] = 13
	_equip(Catalog.index_for(&"glass_scorer"))
	_step(_action(Catalog.index_for(&"glass_scorer"), true, true))
	_expect(world.material_at(122,100) == 0, "Glass Scorer did not remove supported Glass")
	_expect(world.material_at(126,100) == 13, "Glass Scorer removed non-glass material")

func _projectiles() -> void:
	runtime.configure(1)
	world.cells.clear()
	world.cells[Vector2i(120,100)] = 13
	_equip(Catalog.index_for(&"impact_slug"))
	_step(_action(Catalog.index_for(&"impact_slug"), true, true))
	_expect(runtime.snapshot().projectiles.size() == 1, "Impact Slug did not launch")
	for _i: int in range(3):
		_step(_action(Catalog.index_for(&"impact_slug")), 1.0 / 15.0)
	_expect(world.material_at(120,100) == 0, "Impact Slug did not chip editable contact")

	runtime.configure(1)
	world.cells.clear()
	_equip(Catalog.index_for(&"timer_airburst"))
	_step(_action(Catalog.index_for(&"timer_airburst"), true, true))
	for _i: int in range(7):
		_step(_action(Catalog.index_for(&"timer_airburst")), 1.0 / 15.0)
	_expect(runtime.snapshot().projectiles.size() == 5, "Timer Airburst did not create exactly five children")

	runtime.configure(1)
	world.cells.clear()
	world.cells[Vector2i(115,100)] = 1
	_equip(Catalog.index_for(&"sticky_delay_charge"))
	_step(_action(Catalog.index_for(&"sticky_delay_charge"), true, true))
	for _i: int in range(3):
		_step(_action(Catalog.index_for(&"sticky_delay_charge")), 1.0 / 15.0)
	var stuck: Array = runtime.snapshot().projectiles
	_expect(stuck.size() == 1 and str(stuck[0].state) == "stuck", "Sticky Delay Charge did not arm on contact")
	_step(_action(Catalog.index_for(&"sticky_delay_charge"), false, false, true))
	_expect(runtime.snapshot().projectiles.is_empty(), "Sticky Delay Charge alternate did not activate oldest owned charge")
	_expect(world.material_at(115,100) == 1, "Sticky burst removed protected Wall")

	runtime.configure(1)
	world.cells.clear()
	world.cells[Vector2i(115,100)] = 13
	_equip(Catalog.index_for(&"water_contact_charge"))
	_step(_action(Catalog.index_for(&"water_contact_charge"), true, true))
	for _i: int in range(3):
		_step(_action(Catalog.index_for(&"water_contact_charge")), 1.0 / 15.0)
	var armed: Array = runtime.snapshot().projectiles
	_expect(armed.size() == 1 and str(armed[0].state) == "armed", "Water Contact Charge did not arm")
	var at := Vector2i(Vector2(armed[0].position).round())
	world.cells[at + Vector2i(0,1)] = 24
	_step(_action(Catalog.index_for(&"water_contact_charge")), 1.0 / 60.0)
	_expect(runtime.snapshot().projectiles.is_empty(), "Water/Brine condition did not activate charge")

func _processors() -> void:
	runtime.configure(1)
	world.cells.clear()
	var splitter: int = Catalog.index_for(&"brine_splitter")
	_equip(splitter)
	_step(_action(splitter, true, true))
	var objects: Array = runtime.snapshot().objects
	_expect(objects.size() == 1, "Brine Splitter did not deploy")
	var center := Vector2i(Vector2(objects[0].position).round())
	var in_a := center + Vector2i(-2,-1)
	var in_b := center + Vector2i(-2,1)
	var out_a := center + Vector2i(2,-1)
	var out_b := center + Vector2i(2,1)
	world.cells[in_a] = 24
	world.cells[in_b] = 24
	world.cells[out_a] = 13
	_step(_action(splitter), 1.0 / 15.0)
	_expect(world.material_at(in_a.x,in_a.y) == 24 and world.material_at(in_b.x,in_b.y) == 24, "blocked output consumed Brine")
	world.cells[out_a] = 0
	_step(_action(splitter), 1.0 / 15.0)
	_expect(world.material_at(out_a.x,out_a.y) == 3 and world.material_at(out_b.x,out_b.y) == 23, "Brine Splitter outputs are wrong")
	_expect(world.material_at(in_a.x,in_a.y) == 0 and world.material_at(in_b.x,in_b.y) == 0, "Brine Splitter did not consume two input slots")

	runtime.configure(1)
	world.cells.clear()
	var kiln: int = Catalog.index_for(&"glass_kiln")
	_equip(kiln)
	_step(_action(kiln, true, true))
	objects = runtime.snapshot().objects
	center = Vector2i(Vector2(objects[0].position).round())
	in_a = center + Vector2i(-2,-1)
	out_a = center + Vector2i(2,-1)
	world.cells[in_a] = 2
	_step(_action(kiln), 1.0 / 15.0)
	_expect(world.material_at(in_a.x,in_a.y) == 2, "Glass Kiln processed without Fire/Lava catalyst")
	world.cells[center + Vector2i(0,-3)] = 6
	_step(_action(kiln), 1.0 / 15.0)
	_expect(world.material_at(out_a.x,out_a.y) == 36, "Glass Kiln did not produce Molten Glass with Fire catalyst")

	runtime.configure(1)
	world.cells.clear()
	var warden: int = Catalog.index_for(&"firewarden")
	_equip(warden)
	_step(_action(warden, true, true))
	objects = runtime.snapshot().objects
	center = Vector2i(Vector2(objects[0].position).round())
	out_a = center + Vector2i(2,-1)
	world.cells[center + Vector2i(0,3)] = 6
	_step(_action(warden), 1.0 / 15.0)
	_expect(world.material_at(out_a.x,out_a.y) == 3, "Firewarden did not emit Water near Fire")
	_expect(int(runtime.snapshot().objects[0].stock) == 11, "Firewarden stock did not decrement")

func _limits_and_copy() -> void:
	var snapshot: Dictionary = runtime.snapshot()
	_expect(int(snapshot.capacities.projectiles) == 64 and int(snapshot.capacities.objects) == 16, "published capacities drifted")
	_expect(str(snapshot.accounting_unit) == "authored-cell-slots", "accounting unit changed")
	if not snapshot.objects.is_empty():
		var old_stock: int = int(runtime.snapshot().objects[0].stock)
		snapshot.objects[0].stock = -999
		_expect(int(runtime.snapshot().objects[0].stock) == old_stock, "snapshot aliases mutable runtime object state")

func _run() -> void:
	_catalogue()
	_tools()
	_projectiles()
	_processors()
	_limits_and_copy()
	print("USABLES: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
