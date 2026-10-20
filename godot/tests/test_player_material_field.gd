extends SceneTree

# Exercise the real extension binding and immutable copied receipts. The field
# acts on native cells; a render-only particle swarm cannot satisfy these tests.
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYER_MATERIAL_FIELD: " + message)


func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads", 1)
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("PLAYER_MATERIAL_FIELD requires the source-matched native extension")
		quit(1)
		return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.has_method("apply_player_material_field"):
		push_error("PLAYER_MATERIAL_FIELD requires its rebuilt native method")
		quit(1)
		return
	_test_motion(world)
	_test_refusal(world)
	_test_water(world)
	_test_capacity(world)
	print("PLAYER_MATERIAL_FIELD: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)


func _test_motion(world: Variant) -> void:
	expect(world.diagnostic_reset({"workers": 1}), "fresh native world")
	expect(world.diagnostic_fill_rect(Vector2i(120, 120), Vector2i(8, 8), 2, 17),
		"seed native Sand with nondefault state")
	var original: Dictionary = world.diagnostic_snapshot(Vector2i(64, 64), Vector2i(128, 128))
	var before_revision: int = world.revision
	var receipt: Dictionary = world.apply_player_material_field(Vector2i(124, 124), Vector2.RIGHT, 2, 1, 0)
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(64, 64), Vector2i(128, 128))
	expect(receipt.accepted and receipt.reason == "applied", "native field admitted")
	expect(int(receipt.moved_cells) > 0 and int(receipt.quantity) == 64,
		"receipt observes actual moved native grains")
	expect(Vector2(receipt.centroid).x > 123.5, "surge advances native material centroid")
	expect(int(original.counts[2]) == int(after.counts[2]) and int(after.counts[2]) == 64,
		"field neither creates nor consumes native Sand")
	expect(str(original.hash) != str(after.hash) and int(world.revision) > before_revision,
		"actual changed cells invalidate the render revision")
	expect(int(receipt.scanned_cells) == 4225 and int(receipt.movement_steps) <= 2048,
		"native binding exposes bounded work")
	var retained: Dictionary = receipt.duplicate(true)
	world.apply_player_material_field(Vector2i(receipt.centroid), Vector2.LEFT, 2, 3, 1)
	expect(receipt == retained, "later commands cannot mutate a retained receipt")
	var empty: Dictionary = world.apply_player_material_field(Vector2i(800, 800), Vector2.ZERO, 2, 0, 2)
	expect(empty.accepted and int(empty.quantity) == 0 and int(empty.moved_cells) == 0,
		"empty field has explicit zero material and motion")


func _test_refusal(world: Variant) -> void:
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(64, 64), Vector2i(128, 128))
	var before_revision: int = world.revision
	var cases: Array = [
		[Vector2i(124, 124), Vector2(NAN, 0), 2, 0, 0],
		[Vector2i(124, 124), Vector2(0, INF), 2, 0, 0],
		[Vector2i(124, 124), Vector2(2, 0), 2, 0, 0],
		[Vector2i(124, 124), Vector2.ONE, 2, 0, 0],
		[Vector2i(-1, 124), Vector2.ZERO, 2, 0, 0],
		[Vector2i(1024, 124), Vector2.ZERO, 2, 0, 0],
		[Vector2i(124, 124), Vector2.ZERO, 1, 0, 0],
		[Vector2i(124, 124), Vector2.ZERO, 258, 0, 0],
		[Vector2i(124, 124), Vector2.ZERO, 2, -1, 0],
		[Vector2i(124, 124), Vector2.ZERO, 2, 4, 0],
		[Vector2i(124, 124), Vector2.ZERO, 2, 0, -1],
		[Vector2i(124, 124), Vector2.ZERO, 2, 0, 2147483648],
	]
	for arguments: Array in cases:
		var result: Dictionary = world.callv("apply_player_material_field", arguments)
		expect(not bool(result.accepted) and result.reason == "invalid_command",
			"invalid values refuse before narrow native fields")
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(64, 64), Vector2i(128, 128))
	expect(str(before.hash) == str(after.hash) and int(world.revision) == before_revision,
		"all invalid commands leave native cells and render revision unchanged")


func _test_water(world: Variant) -> void:
	expect(world.diagnostic_reset({"workers": 1}), "reset for Water")
	expect(world.water_experiment_fill_rect(Vector2i(120, 120), Vector2i(8, 8), 64, 7),
		"partial Water state fixture")
	var before: Dictionary = world.water_experiment_observation(Vector2i(64, 64), Vector2i(128, 128))
	var center := Vector2i(124, 124)
	for tick: int in range(12):
		var receipt: Dictionary = world.apply_player_material_field(center, Vector2.RIGHT, 3, tick % 4, tick)
		expect(receipt.accepted and int(receipt.quantity) == int(before.water_integer),
			"all liquid modes retain exact fractional native mass")
		center = Vector2i(Vector2(receipt.centroid).round())
		var after: Dictionary = world.water_experiment_observation(Vector2i(64, 64), Vector2i(128, 128))
		expect(int(after.water_integer) == int(before.water_integer)
			and int(after.water_cells) == int(before.water_cells),
			"the field moves complete Water parcels without splitting/merging")
	# Ordinary simulation resumes with ordinary Water splitting/flow. The field
	# stores no persistent native input that could move it after cancellation.
	expect(world.simulation_tick(), "ordinary Water kernel still executes")
	var settled: Dictionary = world.water_experiment_observation(Vector2i(64, 64), Vector2i(128, 128))
	expect(int(settled.water_integer) == int(before.water_integer),
		"post-field native simulation conserves exact Water quantity")


func _test_capacity(world: Variant) -> void:
	expect(world.diagnostic_reset({"workers": 1}), "reset for saturation")
	expect(world.diagnostic_fill_rect(Vector2i(112, 112), Vector2i(32, 32), 2),
		"saturated population fixture")
	var receipt: Dictionary = world.apply_player_material_field(Vector2i(128, 128), Vector2.RIGHT, 2, 1, 9)
	expect(receipt.accepted and receipt.truncated and int(receipt.observed_cells) == 1024,
		"oversized local population reports saturation")
	expect(int(receipt.controlled_cells) == 512 and int(receipt.moved_cells) <= 512
		and int(receipt.movement_steps) <= 2048, "saturation respects all native work budgets")
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(64, 64), Vector2i(128, 128))
	expect(int(after.counts[2]) == 1024, "unselected native parcels survive saturation")
