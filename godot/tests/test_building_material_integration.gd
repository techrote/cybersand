extends SceneTree

# Exercise the catalogue through public constructors, saves, diagnostics and
# gameplay consumers. These checks need the matching native extension; a UI
# palette row alone cannot establish that a material works in a real World.
const Cell = preload("res://scripts/cell_world.gd")
const Codec = preload("res://scripts/demo_save_codec.gd")
const Identity = preload("res://scripts/microscenario_identity.gd")
const Characterisation = preload("res://scripts/physics_characterisation.gd")
const Effects = preload("res://scripts/actor_rig_effects.gd")
const Rig = preload("res://scripts/actor_rig_motor.gd")

var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("BUILDING_MATERIAL_INTEGRATION: " + message)


func _metadata(material: Variant) -> Dictionary:
	return {"demo": "material_lab", "player": [24.0, 24.0, 0.0, 0.0],
		"material": material, "quality": 1, "coherent": false,
		"adhesion": true, "glow": true, "bodies": []}


func _run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		push_error("Source-matched native extension is required")
		quit(1)
		return
	_test_metadata()
	_test_native_construction_and_save()
	_test_diagnostics()
	_test_fallback_and_tools()
	print("BUILDING_MATERIAL_INTEGRATION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)


func _test_metadata() -> void:
	_expect(Cell.FIRST_BUILDING_MATERIAL == 81 and Cell.LAST_MATERIAL == 131,
		"authored building catalogue range changed")
	_expect(int(Identity.current().material_catalogue.count) == 132,
		"MicroScenario evidence advertises the old material catalogue")
	for id: int in range(81, 132):
		_expect(Codec.validate_metadata(_metadata(id)).is_empty(),
			"save metadata rejects selected building material %d" % id)
	for invalid: Variant in [-1, 0, 10, 132, 255, 65536, 131.5, INF, NAN, "131", true]:
		_expect(not Codec.validate_metadata(_metadata(invalid)).is_empty(),
			"save metadata accepted invalid selected material %s" % str(invalid))


func _test_native_construction_and_save() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var rectangles := PackedInt32Array()
	for id: int in range(81, 132):
		rectangles.append_array(PackedInt32Array([16 + (id - 81) * 2, 48, 1, 1, id]))
	var constructed: bool = bridge.build_world(world, rectangles)
	_expect(constructed, "native rectangle constructor rejects the building catalogue")
	if not constructed:
		return
	for id: int in range(81, 132):
		_expect(int(world.material_at(16 + (id - 81) * 2, 48)) == id,
			"constructor changed material %d" % id)
	var original: PackedByteArray = bridge.export_level(world)
	_expect(original.size() == Codec.WORLD_BYTES, "native level export length changed")
	var encoded: Dictionary = Codec.encode(original, _metadata(131))
	_expect(bool(encoded.ok), "CYSD1 cannot encode a building selection")
	if not bool(encoded.ok):
		return
	var decoded: Dictionary = Codec.decode_text(str(encoded.text))
	_expect(bool(decoded.ok), "CYSD1 cannot decode its building selection")
	if not bool(decoded.ok):
		return
	_expect(decoded.world == original and int(decoded.metadata.material) == 131,
		"CYSD1 changed the payload or selected building material")
	_expect(bridge.build_world(world, PackedInt32Array([16, 48, 1, 1, 1])),
		"old material constructor control failed")
	_expect(bridge.import_level(world, decoded.world), "native restore rejects building IDs")
	_expect(bridge.export_level(world) == original, "building restore is not byte exact")
	for invalid: int in [10, 132, 255]:
		var corrupt: PackedByteArray = original.duplicate()
		corrupt[0] = invalid
		_expect(not bridge.import_level(world, corrupt), "native import accepts material %d" % invalid)
		_expect(bridge.export_level(world) == original, "rejected import mutated the active level")
	for invalid: int in [-1, 10, 132, 65536, 2147483647]:
		_expect(not bridge.build_world(world, PackedInt32Array([16, 48, 1, 1, invalid])),
			"native constructor accepts material %d" % invalid)
		_expect(bridge.export_level(world) == original, "rejected constructor mutated the active level")


func _test_diagnostics() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(world.diagnostic_reset({"workers": 1}), "diagnostic reset failed")
	for id: int in range(81, 132):
		_expect(world.diagnostic_fill_rect(Vector2i(16 + id - 81, 48), Vector2i.ONE, id),
			"diagnostic constructor rejects material %d" % id)
	var snapshot: Dictionary = world.diagnostic_snapshot(Vector2i(16, 48), Vector2i(51, 1))
	_expect(snapshot.counts.size() == 132, "native diagnostic count extent differs from catalogue")
	for id: int in range(81, 132):
		_expect(int(snapshot.counts[id]) == 1, "native histogram loses material %d" % id)
	var before: String = str(snapshot.hash)
	for invalid: int in [-1, 10, 132, 65536, 4294967296]:
		_expect(not world.diagnostic_fill_rect(Vector2i(16, 48), Vector2i.ONE, invalid),
			"diagnostics accept invalid or narrowing-wrapped ID %d" % invalid)
	_expect(str(world.diagnostic_snapshot(Vector2i(16, 48), Vector2i(51, 1)).hash) == before,
		"invalid diagnostic material changed stored cells")

	# Four distinct movable materials isolate face-major indexing independently
	# of the renderer and of the new immovable building materials.
	_expect(world.diagnostic_reset({"workers": 1}), "face diagnostic reset failed")
	var positions: Array[Vector2i] = [Vector2i(100, 99), Vector2i(101, 100),
		Vector2i(100, 101), Vector2i(99, 100)]
	var materials: Array[int] = [3, 2, 14, 33]
	for face: int in range(4):
		_expect(world.diagnostic_fill_rect(positions[face], Vector2i.ONE, materials[face]),
			"face contact fixture failed")
	world.prepare_rigid_body_coupling(PackedFloat32Array([1, 100.5, 100.5, 0, 1, 1, 0, 0, 0, 1, 1]), true)
	var metrics: Array = world.diagnostic_body_metrics()
	_expect(metrics.size() == 1, "missing body diagnostic row")
	if metrics.size() == 1:
		var faces: Array = metrics[0][16]
		_expect(faces.size() == 4 * 132, "face histogram has the wrong catalogue stride")
		if faces.size() == 4 * 132:
			for index: int in range(faces.size()):
				var face: int = index / 132
				var expected: int = 1 if index % 132 == materials[face] else 0
				_expect(int(faces[index]) == expected,
					"face/material histogram misattributes bin %d" % index)


func _test_fallback_and_tools() -> void:
	var world = Cell.new()
	world.cells.fill(Cell.EMPTY)
	for id: int in range(81, 132):
		world.set_cell(16 + id - 81, 48, id)
	var sampled: Dictionary = Characterisation.sample(world, Vector2i(16, 48), Vector2i(51, 1), false)
	_expect(sampled.has("counts") and sampled.counts.size() == 132,
		"fallback diagnostic histogram does not cover the building catalogue")
	if sampled.has("counts") and sampled.counts.size() == 132:
		for id: int in range(81, 132):
			_expect(int(sampled.counts[id]) == 1, "fallback histogram loses material %d" % id)
	var effects = Effects.new()
	for id: int in range(81, 132):
		_expect(Rig._hard_material(id), "actor anchor ray ignores hard building material %d" % id)
		_expect(Effects.protected_material(id), "new hard building material lacks tool protection")
		# A protected one-cell barrier must prevent a tool reaching Sand behind it.
		for y: int in range(96, 105):
			world.set_cell(102, y, id)
		world.set_cell(101, 100, Cell.SAND)
		world.set_cell(103, 100, Cell.SAND)
		effects.clear()
		effects.apply(world, Effects.DIG, Vector2(101, 100), 4)
		_expect(world.material_at(101, 100) == Cell.EMPTY, "dig positive control did not execute")
		_expect(world.material_at(102, 100) == id and world.material_at(103, 100) == Cell.SAND,
			"tool crossed protected building material %d" % id)
		_expect(effects.reads_last <= Effects.MAX_READS and effects.writes_last <= Effects.MAX_WRITES,
			"building occlusion bypassed the bounded tool budget")
