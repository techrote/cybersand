extends SceneTree

# Pure V1 presentation checks. They exercise only normalized RG8 snapshot
# values and never instantiate or mutate the authoritative native World.
const CyberWaterPresentationModel = preload("res://scripts/water_presentation_model.gd")

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_four_level_counts_and_error()
	_test_fixed_coverage_order()
	_test_axial_interfaces()
	_test_diagonal_and_concave_interfaces()
	_test_registered_fallbacks()
	_test_seam_scale_and_temporal_determinism()
	_test_input_is_immutable()
	_test_shader_loads_with_experiment_uniform()
	if _failures == 0:
		print("Water presentation model: 8 focused groups passed")
	quit(_failures)


func _test_four_level_counts_and_error() -> void:
	var expected_levels: Dictionary = {
		0: 0, 1: 1, 63: 1, 64: 2, 127: 2,
		128: 3, 191: 3, 192: 4, 254: 4, 255: 4,
	}
	for condition_byte: int in expected_levels:
		var expected: int = expected_levels[condition_byte]
		var mask: int = CyberWaterPresentationModel.coverage_mask(condition_byte)
		_expect(
			CyberWaterPresentationModel.covered_sample_count(mask) == expected,
			"condition %d did not select %d samples" % [condition_byte, expected]
		)
		_expect(
			CyberWaterPresentationModel.coverage_error(condition_byte) >= 0.0,
			"coverage error became negative"
		)
	for condition_byte: int in range(256):
		var expected: int = 0 if condition_byte == 0 else (condition_byte * 4 + 254) / 255
		_expect(
			CyberWaterPresentationModel.coverage_samples(condition_byte) == expected,
			"exhaustive level mismatch at %d" % condition_byte
		)


func _test_fixed_coverage_order() -> void:
	_expect(CyberWaterPresentationModel.coverage_mask(1) == 0x1, "quarter mask changed")
	_expect(CyberWaterPresentationModel.coverage_mask(64) == 0x3, "half mask changed")
	_expect(CyberWaterPresentationModel.coverage_mask(128) == 0x7, "three-quarter mask changed")
	_expect(CyberWaterPresentationModel.coverage_mask(192) == 0xF, "full mask changed")


func _test_axial_interfaces() -> void:
	var top_surface: PackedByteArray = _neighborhood(0, 0, 0, 40, 64, 40, 220, 220, 220)
	var underside: PackedByteArray = _neighborhood(220, 220, 220, 40, 64, 40, 0, 0, 0)
	var left_edge: PackedByteArray = _neighborhood(0, 20, 220, 0, 64, 220, 0, 20, 220)
	var right_edge: PackedByteArray = _neighborhood(220, 20, 0, 220, 64, 0, 220, 20, 0)
	_expect(
		CyberWaterPresentationModel.oriented_mask(64, top_surface, Vector2i.ZERO) == 0x3,
		"top surface did not fill upward from the fuller lower side"
	)
	_expect(
		CyberWaterPresentationModel.oriented_mask(64, underside, Vector2i.ZERO) == 0xC,
		"underside did not fill downward from the fuller upper side"
	)
	_expect(
		CyberWaterPresentationModel.oriented_mask(1, left_edge, Vector2i.ZERO) == 0x2,
		"left boundary did not start on its fuller right side"
	)
	_expect(
		CyberWaterPresentationModel.oriented_mask(1, right_edge, Vector2i.ZERO) == 0x0 + 0x1,
		"right boundary did not start on its fuller left side"
	)
	# Use an odd cell to prove tied axial samples remain deterministic while
	# taking the alternate parity branch.
	_expect(
		CyberWaterPresentationModel.oriented_mask(1, left_edge, Vector2i(1, 0)) == 0x8,
		"odd-cell vertical-edge tie did not use stable parity"
	)


func _test_diagonal_and_concave_interfaces() -> void:
	var lower_right: PackedByteArray = _neighborhood(0, 20, 80, 0, 64, 120, 20, 80, 180)
	var lower_left_concave: PackedByteArray = _neighborhood(80, 0, 0, 180, 64, 20, 220, 100, 20)
	_expect(
		CyberWaterPresentationModel.oriented_mask(1, lower_right, Vector2i.ZERO) == 0x2,
		"diagonal did not start at the fuller lower-right corner"
	)
	_expect(
		CyberWaterPresentationModel.oriented_mask(1, lower_left_concave, Vector2i.ZERO) == 0x1,
		"concave boundary did not start at the fuller lower-left corner"
	)
	_expect(
		CyberWaterPresentationModel.oriented_mask(64, lower_right, Vector2i.ZERO) == 0xA,
		"diagonal half mask did not retain the dominant right component"
	)


func _test_registered_fallbacks() -> void:
	var isolated: PackedByteArray = _neighborhood(0, 0, 0, 0, 64, 0, 0, 0, 0)
	var uniform_pool: PackedByteArray = _neighborhood(64, 64, 64, 64, 64, 64, 64, 64, 64)
	var symmetric_cross: PackedByteArray = _neighborhood(0, 80, 0, 80, 64, 80, 0, 80, 0)
	var equal_diagonal: PackedByteArray = _neighborhood(0, 0, 80, 0, 64, 80, 80, 80, 160)
	var weak_gradient: PackedByteArray = _neighborhood(0, 20, 0, 20, 64, 22, 0, 22, 0)
	for entry: PackedByteArray in [isolated, uniform_pool, symmetric_cross, equal_diagonal, weak_gradient]:
		_expect(
			CyberWaterPresentationModel.oriented_mask(64, entry, Vector2i(7, 9)) == 0x3,
			"ambiguous or weak neighborhood did not use coverage fallback"
		)


func _test_seam_scale_and_temporal_determinism() -> void:
	var boundary: PackedByteArray = _neighborhood(0, 0, 20, 0, 64, 180, 0, 0, 20)
	var seam_cells: Array[Vector2i] = [
		Vector2i(63, 63), Vector2i(64, 63),
		Vector2i(255, 255), Vector2i(256, 255),
		Vector2i(511, 511), Vector2i(512, 511),
	]
	for cell: Vector2i in seam_cells:
		var first: int = CyberWaterPresentationModel.oriented_mask(128, boundary, cell)
		var repeated: int = CyberWaterPresentationModel.oriented_mask(128, boundary, cell)
		_expect(first == repeated, "storage/activity/core seam result changed on repeat")
		_expect(
			CyberWaterPresentationModel.covered_sample_count(first) == 3,
			"seam cell lost its registered sample count"
		)
	var ordinary_pair: Array[int] = [
		CyberWaterPresentationModel.oriented_mask(128, boundary, Vector2i(11, 11)),
		CyberWaterPresentationModel.oriented_mask(128, boundary, Vector2i(12, 11)),
	]
	for seam_x: int in [64, 256, 512]:
		var seam_pair: Array[int] = [
			CyberWaterPresentationModel.oriented_mask(
				128, boundary, Vector2i(seam_x - 1, seam_x - 1)
			),
			CyberWaterPresentationModel.oriented_mask(
				128, boundary, Vector2i(seam_x, seam_x - 1)
			),
		]
		_expect(
			seam_pair == ordinary_pair,
			"world-anchored parity reset at the %d seam" % seam_x
		)

	var world_sample: Vector2 = Vector2(91.75, 37.25)
	var expected_subcell: int = CyberWaterPresentationModel.SUBCELL_TOP_RIGHT
	for scale: int in [1, 2, 4, 8]:
		# The logical world sample is invariant even when a renderer emits a
		# different number of physical fragments for that same location.
		var physical_sample: Vector2 = world_sample * float(scale)
		var reconstructed_world_sample: Vector2 = physical_sample / float(scale)
		_expect(
			CyberWaterPresentationModel.subcell_at_world_sample(reconstructed_world_sample)
				== expected_subcell,
			"subcell changed at %dx display scale" % scale
		)
	_expect(
		CyberWaterPresentationModel.subcell_at_world_sample(Vector2(479.75, 269.25))
			== expected_subcell,
		"480x270 Tower view changed the world-anchored subcell"
	)

	var frozen_mask: int = CyberWaterPresentationModel.oriented_mask(128, boundary, Vector2i(64, 64))
	_expect(
		CyberWaterPresentationModel.changed_sample_count(frozen_mask, frozen_mask) == 0,
		"identical frozen frames reported presentation flicker"
	)
	var changed_mask: int = CyberWaterPresentationModel.oriented_mask(64, boundary, Vector2i(64, 64))
	_expect(
		CyberWaterPresentationModel.changed_sample_count(frozen_mask, changed_mask) == 1,
		"changed authoritative mass did not report its one-sample presentation delta"
	)


func _test_input_is_immutable() -> void:
	var snapshot: PackedByteArray = _neighborhood(0, 10, 20, 30, 128, 180, 80, 120, 240)
	var before: PackedByteArray = snapshot.duplicate()
	var before_hash: int = hash(snapshot)
	for _repeat: int in range(32):
		CyberWaterPresentationModel.presentation_mask(128, snapshot, Vector2i(12, 18), true)
	_expect(snapshot == before, "presentation model mutated immutable RG8-derived input")
	_expect(hash(snapshot) == before_hash, "presentation model changed snapshot identity")


func _test_shader_loads_with_experiment_uniform() -> void:
	var shader: Shader = load("res://shaders/material_palette.gdshader") as Shader
	_expect(shader != null, "Water presentation shader did not compile/load")
	if shader == null:
		return
	var uniform_names: Array[StringName] = []
	for uniform: Dictionary in shader.get_shader_uniform_list():
		uniform_names.append(uniform.get("name", &""))
	_expect(
		&"water_presentation_mode" in uniform_names,
		"shader does not expose water_presentation_mode"
	)


func _neighborhood(
	top_left: int, top: int, top_right: int,
	left: int, centre: int, right: int,
	bottom_left: int, bottom: int, bottom_right: int
) -> PackedByteArray:
	return PackedByteArray([
		top_left, top, top_right,
		left, centre, right,
		bottom_left, bottom, bottom_right,
	])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
