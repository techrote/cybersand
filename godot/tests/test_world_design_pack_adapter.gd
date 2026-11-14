extends SceneTree
# Deterministic, executable Godot geometry-contract tests (no renderer required).
# godot --headless --path godot --script res://tests/test_world_design_pack_adapter.gd

const Adapter = preload("res://tools/world_design_pack_adapter.gd")
const EXPECTED_SHA256: String = "e4492800f8ed466035c0550663602445a3bb7d81d65f177a04b8710e60a8055e"
var assertions: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	assertions += 1
	if value:
		return
	failures += 1
	push_error("WORLD_PACK_ADAPTER: " + message)


func _fixture() -> Dictionary:
	return {"schema_id": "cybersand.world-feature-pack.proposal",
		"features": [
			{"id": "a", "size": [4, 3], "rectangles": [
				[0, 0, 4, 3, 1], [1, 1, 2, 1, 77],
				[2, 1, 1, 1, 0], [0, 0, 1, 1, 43]],
				"variants": [{"id": "amber", "swap": {"77": 79}},
					{"id": "hollow", "swap": {"43": 0}}]},
			{"id": "b", "size": [2, 2], "rectangles": [[0, 0, 2, 2, 80]],
				"variants": []}
		],
		"scene": {"size": [12, 7], "rectangles": [
			[0, 5, 12, 2, 100], [1, 1, 4, 2, 49], [8, 0, 1, 1, 3]],
			"placements": [
				{"feature": "a", "x": 2, "y": 1, "variant": "amber"},
				{"feature": "b", "x": 4, "y": 2, "variant": null}
			]}}


func _cell(data: PackedByteArray, width: int, x: int, y: int) -> Vector2i:
	var at: int = (y * width + x) * 2
	return Vector2i(data[at], data[at + 1])


func _oracle() -> PackedByteArray:
	# Independent expected-cell layout: literal rows, not an invocation of
	# geometry/rectangle iteration or variant-swapping code under test.
	var rows: Array = [
		[0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0],
		[0, 49, 43, 1, 1, 1, 0, 0, 0, 0, 0, 0],
		[0, 49, 1, 79, 80, 80, 0, 0, 0, 0, 0, 0],
		[0, 0, 1, 1, 80, 80, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100],
		[100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
	]
	var bytes: PackedByteArray = PackedByteArray()
	for row: Array in rows:
		for material_id: int in row:
			bytes.append(material_id)
			bytes.append(255 if material_id == 3 else 0)
	return bytes


func _reject(pack: Dictionary, substring: String) -> void:
	var result: Dictionary = Adapter.inspect(pack)
	_expect(not result.ok and substring in str(result.get("error", "")),
		"expected explicit rejection containing '%s', got: %s" % [substring, str(result)])


func _run() -> void:
	var pack: Dictionary = _fixture()
	var parsed: Dictionary = Adapter.inspect(pack)
	_expect(parsed.ok, "valid scene-family fixture must inspect")
	var output: Dictionary = Adapter.build_combined(pack)
	_expect(output.ok, "valid scene-family fixture must build")
	if output.ok:
		_expect(output["size"] == Vector2i(12, 7) and output.rg8_bytes == 168,
			"native scene size/byte count")
		_expect(output.data == _oracle(), "independent literal 12x7 oracle, including overwrite order")
		_expect(output.rg8_sha256 == EXPECTED_SHA256, "independent precomputed SHA-256")
		_expect(_cell(output.data, 12, 8, 0) == Vector2i(3, 255),
			"native ID=3 and synthetic initial Water condition")
		_expect(_cell(output.data, 12, 4, 2) == Vector2i(80, 0),
			"last placement overwrites explicit Empty and terrain")
		_expect(_cell(output.data, 12, 3, 2) == Vector2i(79, 0),
			"selected variant remaps native 77 to native 79")
		_expect(_cell(output.data, 12, 11, 0) == Vector2i.ZERO,
			"unassigned space remains Empty, not fabricated ground")
		_expect(Adapter.build_combined(pack).rg8_sha256 == EXPECTED_SHA256,
			"repeat construction uses identical RG8 bytes/hash")
		var image: Image = Image.create_from_data(12, 7, false, Image.FORMAT_RG8, output.data)
		_expect(image.get_format() == Image.FORMAT_RG8 and image.get_data() == output.data,
			"Godot RG8 texture construction retains exact bytes")
	var original: Dictionary = Adapter.build_feature(pack, "a")
	var amber: Dictionary = Adapter.build_feature(pack, "a", "amber")
	var hollow: Dictionary = Adapter.build_feature(pack, "a", "hollow")
	_expect(original.ok and amber.ok and hollow.ok, "base and two named variants build")
	if original.ok and amber.ok and hollow.ok:
		_expect(_cell(original.data, 4, 1, 1).x == 77 and _cell(amber.data, 4, 1, 1).x == 79,
			"standalone variant swap changes native ID only when requested")
		_expect(_cell(original.data, 4, 2, 1) == Vector2i.ZERO,
			"explicit material ID 0 can overwrite existing material")
		_expect(_cell(hollow.data, 4, 0, 0) == Vector2i.ZERO,
			"variant swap to ID 0 is an explicit erasure")
		_expect(original["size"] == Vector2i(4, 3), "individual geometry is native-cell sized")
	var combined: Dictionary = pack.duplicate(true)
	combined.erase("scene")
	combined["combined_scene"] = {"size": [1370, 7], "baseline_y": 5,
		"placements": [{"feature_id": "a", "origin": [1300, 2], "variant": null}]}
	var wide: Dictionary = Adapter.build_combined(combined)
	_expect(wide.ok, "combined_scene supports >1024-cell width and origin-offset placement")
	if wide.ok:
		_expect(wide["size"] == Vector2i(1370, 7) and wide.rg8_bytes == 1370 * 7 * 2,
			"full large width retained without clipping")
		_expect(_cell(wide.data, 1370, 1300, 2).x == 43,
			"combined_scene feature_id/origin places exact native cell")
		_expect(_cell(wide.data, 1370, 1299, 2) == Vector2i.ZERO,
			"baseline_y does not become terrain or erasure")
		_expect(_cell(wide.data, 1370, 1301, 3).x == 77,
			"null variant selects native base material")
		_expect(wide.geometry.baseline_y_instantiated == false,
			"baseline metadata remains non-material")
	var mutation: Dictionary
	mutation = pack.duplicate(true)
	mutation.scene.rectangles[0] = [-1, 5, 12, 2, 100]
	_reject(mutation, "negative")
	mutation = pack.duplicate(true)
	mutation.scene.rectangles[0] = [0, 5, 13, 2, 100]
	_reject(mutation, "exceeds declared bounds")
	mutation = pack.duplicate(true)
	mutation.scene.rectangles[0] = [0, 5, 0, 2, 100]
	_reject(mutation, "non-positive")
	mutation = pack.duplicate(true)
	mutation.scene.rectangles[0] = [0, 5, 12, 2, 10]
	_reject(mutation, "native material")
	mutation = pack.duplicate(true)
	mutation.features[0].rectangles[0] = [0, 0, 4, 3, 255]
	_reject(mutation, "native material")
	mutation = pack.duplicate(true)
	mutation.features[0].rectangles[0] = [3, 0, 2, 1, 1]
	_reject(mutation, "exceeds declared bounds")
	mutation = pack.duplicate(true)
	mutation.scene.placements[0].x = -1
	_reject(mutation, "exceeds combined scene")
	mutation = pack.duplicate(true)
	mutation.scene.placements[0].x = 11
	_reject(mutation, "exceeds combined scene")
	mutation = pack.duplicate(true)
	mutation.scene.placements[0].feature = "missing"
	_reject(mutation, "missing feature")
	mutation = pack.duplicate(true)
	mutation.scene.placements[0].variant = "typo"
	_reject(mutation, "unknown variant")
	mutation = pack.duplicate(true)
	mutation.features[0].variants[0].swap = {"77": 250}
	_reject(mutation, "invalid native ID")
	mutation = pack.duplicate(true)
	mutation.scene.size = [16385, 7]
	_reject(mutation, "size")
	mutation = pack.duplicate(true)
	mutation.scene.rectangles[0] = [0.5, 5, 12, 2, 100]
	_reject(mutation, "integer")
	mutation = pack.duplicate(true)
	mutation.scene.terrain_rectangles = []
	_reject(mutation, "ambiguous")
	mutation = pack.duplicate(true)
	mutation.combined_scene = {}
	_reject(mutation, "exactly one")
	print("WORLD_PACK_ADAPTER assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)
