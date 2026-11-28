extends SceneTree

# Deterministic immutable-envelope controls for the same production consumer
# exercised with the native owner and Rapier by test_ambient_default_off_integration.
const Perception = preload("res://scripts/ambient/ambient_perception.gd")
const EXTENT := Vector2i(64, 64)
const EPOCH := 7
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("AMBIENT_PUBLICATION_OWNER: " + label)


func completion(serial: int, tick: int, revision: int, generation := 3) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.rigid_body_epoch = EPOCH
	snapshot.physics_world_generation = generation
	snapshot.tick_index = tick
	snapshot.simulation_world_revision = revision
	snapshot.backend_name = "native-phased"
	snapshot.render_world_generation = -1
	snapshot.render_snapshot_serial = 0
	return snapshot


func material(serial: int, tick: int, revision: int, render_serial: int, generation := 3) -> CyberSimulationSnapshot:
	var snapshot := completion(serial, tick, revision, generation)
	snapshot.render_world_generation = generation
	snapshot.render_snapshot_serial = render_serial
	snapshot.render_tick_index = tick
	snapshot.world_revision = revision
	snapshot.render_channels = 2
	snapshot.render_full_refresh = true
	snapshot.render_patch_rectangles = PackedInt32Array([0, 0, EXTENT.x, EXTENT.y, 0, EXTENT.x * 2])
	snapshot.render_patch_cells.resize(EXTENT.x * EXTENT.y * 2)
	snapshot.render_patch_cells.fill(0)
	snapshot.render_patch_cells[(32 * EXTENT.x + 32) * 2] = 16
	return snapshot


func owner(sensor: RefCounted, snapshot: CyberSimulationSnapshot) -> bool:
	# The baseline arm deliberately exercises its original material-only entry
	# point; it cannot pass the explicit new-owner admission assertion below.
	if sensor.has_method("observe_native_owner"):
		return bool(sensor.call("observe_native_owner", snapshot, EXTENT, EPOCH))
	return bool(sensor.call("ingest_snapshot", snapshot, EXTENT, EPOCH))


func sense(sensor: RefCounted) -> Dictionary:
	var view := {"representation":"articulated-rapier", "run_id":"owner-fixture", "epoch":EPOCH,
		"actor_id":0, "instance_id":101, "control_generation":1, "tick":12,
		"position":Vector2(32.5, 32.5), "velocity":Vector2.ZERO, "suspended":false, "fault":""}
	return sensor.observe(view, [{"material_id":16, "radius_cells":50.0}],
		{"bounds":Rect2(Vector2.ZERO, Vector2(EXTENT))}).materials


func run() -> void:
	var sensor := Perception.new()
	check(sensor.has_method("observe_native_owner"), "separate production native-owner observation exists")
	var early := completion(10, 10, 5)
	check(owner(sensor, early), "material-free native completion admitted")
	var state: Dictionary = sensor.diagnostics()
	check(state.current_tick == 10 and state.owner_snapshot_serial == 10 and state.world_generation == 3,
		"early owner records genuine World, native tick and owner serial")
	check(state.cache_bytes == 0 and state.ingestions == 0 and state.source_bytes == 0,
		"early completion neither allocates nor copies material")
	check(state.publication_serial == -1 and sensor.wants_full_refresh(),
		"early completion cannot mint material identity or prime coverage")
	check(not sense(sensor).available, "missing material remains unavailable after early owner admission")
	var baseline := material(10, 10, 5, 2)
	check(sensor.ingest_snapshot(baseline, EXTENT, EPOCH), "same-owner later material copy establishes full baseline")
	check(sense(sensor).available and sense(sensor).targets["16"].present, "actual retained material byte is observable")
	var bytes_before: int = int(sensor.diagnostics().source_bytes)
	var ingestions_before: int = int(sensor.diagnostics().ingestions)
	check(owner(sensor, completion(11, 10, 5)), "coupling-only completion observes unchanged native tick")
	check(sense(sensor).available, "coupling-only completion preserves genuine material authority")
	check(sensor.diagnostics().source_bytes == bytes_before and sensor.diagnostics().ingestions == ingestions_before,
		"owner freshness does not recopy unchanged material")
	check(owner(sensor, completion(13, 30, 6)), "newer completion advances changed native material revision")
	check(not sense(sensor).available and "stale" in str(sense(sensor).reason),
		"early completion exposes the retained material age deficit")
	check(sensor.diagnostics().sample_tick == 10 and sensor.diagnostics().publication_serial == 2,
		"fresh native metadata does not relabel retained material")
	var delayed := material(12, 29, 6, 3)
	check(sensor.ingest_snapshot(delayed, EXTENT, EPOCH), "genuine newer material from older envelope is admitted")
	state = sensor.diagnostics()
	check(state.owner_snapshot_serial == 13 and state.current_tick == 30,
		"delayed material never rolls current native freshness backward")
	check(state.publication_serial == 3 and state.sample_tick == 29 and sense(sensor).available,
		"material publication retains its own exact sample identity")
	check(not sensor.ingest_snapshot(baseline, EXTENT, EPOCH), "older already-consumed render envelope is ignored")
	check(sensor.diagnostics().current_tick == 30 and sensor.diagnostics().sample_tick == 29,
		"ignored older envelope changes neither native nor material clocks")
	check(owner(sensor, completion(14, 45, 7)), "later owner advances beyond material age budget")
	check(not sense(sensor).available, "later native revision cannot use stale material as absence")
	bytes_before = int(sensor.diagnostics().source_bytes)
	var future := material(12, 46, 8, 4)
	check(not sensor.ingest_snapshot(future, EXTENT, EPOCH), "older envelope cannot describe future native state")
	check(sensor.diagnostics().source_bytes == bytes_before, "rejected future envelope copies no bytes")
	var refreshed := material(15, 46, 8, 4)
	check(sensor.ingest_snapshot(refreshed, EXTENT, EPOCH), "new current material restores the genuine view")
	check(owner(sensor, completion(16, 0, 0, 4)), "new native World generation is admitted before its material")
	check(sensor.diagnostics().cache_bytes == 0 and sensor.diagnostics().publication_serial == -1,
		"World replacement retires old material immediately")
	check(sensor.wants_full_refresh() and not sense(sensor).available,
		"new World requests full baseline rather than retaining foreign material")
	check(not owner(sensor, completion(17, 47, 9, 3)), "older native World cannot return")
	check(sensor.diagnostics().world_generation == 4 and sensor.diagnostics().cache_bytes == 0,
		"old World refusal preserves current owner and absent new-world material")
	check(owner(sensor, completion(16, 0, 0, 4)), "current authentic owner clears foreign-owner refusal")
	var partial := material(16, 0, 0, 1, 4)
	partial.render_full_refresh = false
	partial.render_patch_rectangles = PackedInt32Array([0, 0, 2, 2, 0, 4])
	partial.render_patch_cells = PackedByteArray([16, 0, 0, 0, 0, 0, 0, 0])
	check(not sensor.ingest_snapshot(partial, EXTENT, EPOCH), "delta cannot bootstrap replacement World coverage")
	check(sensor.wants_full_refresh() and sensor.diagnostics().cache_bytes == 0,
		"failed delta does not allocate an alleged complete World")
	var replacement := material(16, 0, 0, 2, 4)
	check(sensor.ingest_snapshot(replacement, EXTENT, EPOCH), "complete replacement material establishes coverage")
	var foreign := completion(17, 1, 1, 4)
	foreign.rigid_body_epoch = EPOCH + 1
	check(not owner(sensor, foreign) and not sense(sensor).available, "foreign physical epoch refuses material authority")
	check(owner(sensor, completion(16, 0, 0, 4)) and sense(sensor).available,
		"authentic current owner restores its unmodified material view")
	var backend := completion(17, 1, 1, 4)
	backend.backend_name = "gdscript-serial-fallback"
	check(not owner(sensor, backend) and not sense(sensor).available, "non-native owner cannot certify native material")
	check(owner(sensor, completion(16, 0, 0, 4)), "valid native owner restores backend refusal")
	var failed := completion(17, 1, 1, 4)
	failed.simulation_failed = true
	check(not owner(sensor, failed) and "failed" in str(sense(sensor).reason), "native failure disables material authority")
	check(not sensor.ingest_snapshot(replacement, EXTENT, EPOCH), "older material cannot erase native failure")
	check("failed" in str(sense(sensor).reason), "failure remains visible after older material observation")
	check(not owner(sensor, completion(17, 1, 1, 4)), "same immutable owner cannot change failure status")
	check(owner(sensor, completion(18, 0, 0, 5)), "healthy replacement World retires failed predecessor")
	check(sensor.diagnostics().cache_bytes == 0 and sensor.wants_full_refresh(), "failure recovery still requires new-world baseline")
	check(sensor.ingest_snapshot(material(18, 0, 0, 1, 5), EXTENT, EPOCH), "new-world full baseline restores sensing")
	var wrong_material := material(19, 1, 1, 2, 5)
	wrong_material.render_world_generation = 4
	check(not sensor.ingest_snapshot(wrong_material, EXTENT, EPOCH) and not sense(sensor).available,
		"current native owner cannot bless material belonging to another World")
	check(sensor.diagnostics().current_tick == 1 and sensor.diagnostics().world_generation == 5,
		"refused material preserves true current native owner identity")
	check(sensor.ingest_snapshot(material(20, 2, 2, 3, 5), EXTENT, EPOCH), "authentic replacement material repairs material refusal")
	var regression := completion(21, 1, 1, 5)
	check(not owner(sensor, regression) and not sense(sensor).available, "newer owner serial cannot regress native tick or revision")
	check(owner(sensor, completion(20, 2, 2, 5)) and sense(sensor).available,
		"exact current owner restores refusal without fake progression")
	evidence.final = sensor.diagnostics()
	evidence.source_bytes_before_future_refusal = bytes_before
	evidence.native_simulation_executed = false
	evidence.scope = "Production consumer immutable-envelope controls; original mounted Ambient native/Rapier integration is a separate gate."
	print("AMBIENT_PUBLICATION_OWNER ", JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
