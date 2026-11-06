extends SceneTree

# Public native/GDExtension refusal and applied-state regressions. Run in a
# separate watchdog-owned Godot process with --workers=1 or --workers=4.
# The exact native 520-member/six-proxy fixture follows the read-only #386 probe
# at b661a6f354f8c51e79759d22ad4573a875964b43. Reservations are synthetic values:
# this does not certify Rapier motion, penetration, source admission or gameplay.
# These assertions supplement, and never replace/reclassify, its original 122
# before/after process cases. Quarantined SOL requires native fault injection;
# no public phase is forged here. A separate real capacity failure exercises the
# existing failed-World contract without adding a production failure hook.

const PHASES: Dictionary = {
	"disabled":0, "idle":1, "prepared":2, "acknowledged":3, "committed":4,
	"restored":5, "active":6, "cancel":1, "rollback":1, "reset":0,
}
const FENCED: Array[int] = [2, 3, 4, 5, 7]
const ORIGINAL_PHASES: Array[String] = [
	"disabled", "idle", "prepared", "acknowledged", "committed", "restored",
	"active", "cancel", "rollback", "reset",
]
const BOUNDARY_SCHEMA: String = "cybersand.public-boundary.v1"
const INITIAL_ORIGIN: Vector2i = Vector2i(12, 18)
const INITIAL_SIZE: Vector2i = Vector2i(180, 140)
const MARKER: Array = [64,1000.5,1000.5,0,1,1,0,0,0,1,7]
var workers: int = 1
var report_path: String = ""
var checks: int = 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var started_usec: int = 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL SOL_FACADE ", message)
	return ok

func _phase(world: Object) -> int:
	var value: Dictionary = world.solid_detachment_command({"action":"inspect"})
	return int(value.get("phase", -1))

func _command(world: Object, request: Dictionary, label: String) -> Dictionary:
	var result: Dictionary = world.solid_detachment_command(request)
	check(bool(result.get("ok", false)), label + ": " + str(result.get("outcome", "missing")))
	return result

func _prepare(world: Object) -> Dictionary:
	var state: Dictionary = _command(world, {"action":"prepare", "domain":Rect2i(32,16,64,64),
		"anchors":Rect2i(0,67,128,13), "seed":Vector2i(51,34)}, "prepare actual native component")
	check(int(state.get("member_count", 0)) == 520 and int(state.get("shape_count", 0)) == 6,
		"native preparation is exactly 520 members and six shapes")
	check(int(state.get("native_source_members", -1)) == 520 and int(state.get("aggregate_owned", -1)) == 0,
		"Prepared evidence copy does not own the 520 native cells")
	return state

func _acknowledge(world: Object, state: Dictionary) -> Dictionary:
	return _command(world, {"action":"acknowledge", "token":state.token, "body_id":1,
		"body_generation":7, "shape_count":state.shape_count, "payload_digest":state.payload_digest,
		"shape_digest":state.shape_digest}, "source-bound synthetic reservation")

func _finish(world: Object, state: Dictionary, action: String) -> Dictionary:
	return _command(world, {"action":action, "token":state.token, "body_id":1,
		"body_generation":7, "terrain_revision":state.commit_revision, "physics_epoch":17}, action)

func _new_fixture(target: String) -> Object:
	var first_failure: int = failures.size()
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check(world != null, target + ": native class is registered"):
		return null
	if not check(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})), target + ": diagnostic reset"):
		return null
	check(int(world.get_worker_threads()) == workers, target + ": actual native worker count")
	world.set_simulation_window(INITIAL_ORIGIN, INITIAL_SIZE, 3, 5)
	world.set_simulation_window_enabled(false)
	for rectangle: Rect2i in [Rect2i(0,72,128,4), Rect2i(50,40,4,32), Rect2i(44,27,29,13),
		Rect2i(54,40,11,4), Rect2i(88,45,3,27)]:
		var material: int = 1 if rectangle.position.y == 72 else 43
		check(bool(world.diagnostic_fill_rect(rectangle.position, rectangle.size, material)), target + ": fixture fill")
	check(bool(world.diagnostic_fill_rect(Vector2i(60,32), Vector2i.ONE, 0)), target + ": real crown hole")
	check(bool(world.diagnostic_fill_rect(Vector2i(50,65), Vector2i(4,2), 0)), target + ": native support cut")
	check(bool(world.simulation_tick()), target + ": apply simulation region")
	# An ordinary mask outside the aggregate domain makes accidental mask clearing
	# observable. It is not one of the six aggregate proxy identities 1..6.
	world.prepare_rigid_body_coupling(PackedFloat32Array(MARKER), false)
	check(int(world.rigid_body_id_at(1000,1000)) == 64, target + ": independent native mask witness")
	var state: Dictionary = {}
	if target != "disabled":
		state = _command(world, {"action":"configure", "members":1024, "shapes":64}, target + ": configure")
	if target not in ["disabled", "idle"]:
		state = _prepare(world)
		if not bool(state.get("ok", false)):
			return null
		if target == "cancel":
			state = _command(world, {"action":"cancel", "token":state.token}, "cancel Prepared")
		elif target not in ["prepared", "reset"]:
			state = _acknowledge(world, state)
			if target != "acknowledged":
				state = _command(world, {"action":"commit", "token":state.token}, "commit native ownership")
				if target in ["restored", "rollback"]:
					state = _command(world, {"action":"rollback", "token":state.token}, "restore inactive native ownership")
				if target in ["active", "rollback"]:
					state = _finish(world, state, "finalize" if target == "active" else "finish_rollback")
	if target == "reset":
		check(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})), "reset retires Prepared SOL")
	state = world.solid_detachment_command({"action":"inspect"})
	check(bool(state.get("ok", false)) and int(state.get("phase", -1)) == int(PHASES[target]), target + ": actual phase readback")
	if int(PHASES[target]) in [2, 3, 4, 5, 6]:
		var expected_native: int = 0 if target in ["committed", "active"] else 520
		check(int(state.get("native_source_members", -1)) == expected_native
			and int(state.get("aggregate_owned", -1)) == 520 - expected_native,
			target + ": exactly one material owner")
	if failures.size() != first_failure:
		return null
	return world

func _ownership(world: Object) -> Dictionary:
	var state: Dictionary = world.solid_detachment_command({"action":"inspect"})
	var output: Dictionary = {}
	for key: String in ["phase", "token", "fenced", "source_tick", "world_tick", "source_revision",
		"commit_revision", "terrain_revision", "payload_digest", "shape_digest", "member_count",
		"shape_count", "aggregate_owned", "native_source_members", "body_id", "body_generation",
		"members", "rectangles"]:
		if state.has(key):
			output[key] = state[key]
	return output

func _witness(world: Object) -> Dictionary:
	var diagnostic: Dictionary = world.diagnostic_snapshot(Vector2i.ZERO, Vector2i(128,128), false)
	var receipt: Dictionary = world.get_liquid_run_receipt({})
	return {"diagnostic_hash":diagnostic.get("hash", "unavailable"),
		"cells":diagnostic.get("cells", PackedByteArray()),
		"revision":world.get_revision(), "terrain_revision":world.get_hard_surface_revision(),
		"tick":world.get_tick_index(), "attempted_tick":world.get_attempted_tick_index(),
		"has_failed":world.has_failed(), "window":world.get_simulation_window_state(),
		"adhesion":world.get_liquid_surface_adhesion_enabled(), "receipt":receipt,
		"ownership":_ownership(world), "body_results":world.rigid_body_results(),
		"marker_id":world.rigid_body_id_at(1000,1000),
		"marker_left":world.material_at(999,1000), "marker_cell":world.material_at(1000,1000)}

func _status(result: Dictionary, ok: bool, operation: String, phase: int, label: String) -> void:
	check(str(result.get("schema", "")) == BOUNDARY_SCHEMA, label + ": explicit status schema")
	check(result.has("ok") and bool(result.ok) == ok, label + ": explicit success/refusal")
	check(str(result.get("operation", "")) == operation, label + ": exact operation identity")
	check(int(result.get("phase", -1)) == phase, label + ": actual phase identity")
	check(result.has("code") and not str(result.code).is_empty(), label + ": machine-readable outcome")
	check(result.has("diagnostic"), label + ": diagnostic field")
	if not ok:
		check(not str(result.get("diagnostic", "")).is_empty(), label + ": observable refusal reason")

func _hex16(value: String) -> bool:
	if value.length() != 16:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

func _hashes(world: Object, phase: int, label: String) -> Dictionary:
	var before: Dictionary = _witness(world)
	var available: bool = phase in [0, 1]
	var values: Dictionary = {}
	for projection: int in [0, 1, 2]:
		var operation: String = "get_physical_state_hash" if projection == 0 else "get_liquid_comparison_hash"
		for repeat: int in range(2):
			var result: Dictionary = world.get_physical_state_hash_result() if projection == 0 else world.get_liquid_comparison_hash_result(projection)
			var context: String = "%s/hash%d/repeat%d" % [label, projection, repeat]
			_status(result, available, operation, phase, context)
			if available:
				check(result.has("value") and _hex16(str(result.get("value", ""))), context + ": valid full hash")
				values[str(projection)] = result.get("value", "")
			else:
				check(not result.has("value"), context + ": refusal has no fabricated hash")
				check(str(result.get("code", "")) == "native_refusal", context + ": native serialization fence remains")
			var legacy: String = world.get_physical_state_hash() if projection == 0 else world.get_liquid_comparison_hash(projection)
			var legacy_status: Dictionary = world.get_last_boundary_result()
			_status(legacy_status, available, operation, phase, context + "/legacy")
			check(legacy == str(result.value) if available and result.has("value") else legacy.is_empty(),
				context + ": legacy ABI agrees with explicit availability")
			check(_witness(world) == before, context + ": reads/refusals change no native or facade state")
			# Returned status is copied; consumers cannot change future diagnostics.
			legacy_status["ok"] = not available
			legacy_status["diagnostic"] = "consumer mutation"
			check(bool(world.get_last_boundary_result().get("ok", not available)) == available
				and str(world.get_last_boundary_result().get("diagnostic", "")) != "consumer mutation",
				context + ": public status isolates consumer mutation")
	for invalid_projection: int in [0, 3, -1]:
		var invalid: Dictionary = world.get_liquid_comparison_hash_result(invalid_projection)
		_status(invalid, false, "get_liquid_comparison_hash", phase, label + "/invalid projection")
		check(str(invalid.get("code", "")) == "invalid_argument" and not invalid.has("value"),
			label + ": invalid projection cannot become a valid hash")
		check(str(world.get_liquid_comparison_hash(invalid_projection)).is_empty(), label + ": legacy invalid projection remains empty")
	check(_witness(world) == before, label + ": invalid projection is read-only")
	return values

func _windows(world: Object, phase: int, label: String) -> void:
	var fenced: bool = phase in FENCED
	var before: Dictionary = _witness(world)
	for repeat: int in range(2):
		world.set_simulation_window_enabled(true)
		var result: Dictionary = world.get_last_boundary_result()
		_status(result, not fenced, "set_simulation_window_enabled", phase, label + "/window enable")
		if fenced:
			check(str(result.get("code", "")) == "native_refusal", label + ": enabling reaches intact native fence")
			check(_witness(world) == before, label + ": rejected enable preserves every public/native window field")
		else:
			var actual: Dictionary = world.get_simulation_window_state()
			check(bool(actual.get("available", false)) and bool(actual.get("enabled", false)), label + ": successful enable is applied")
			check(actual.get("native_region") == PackedInt64Array([9,13,186,150]), label + ": cached geometry maps to exact native region")
		world.set_simulation_window(Vector2i(70,80), Vector2i(90,60), 7, 9)
		result = world.get_last_boundary_result()
		_status(result, not fenced, "set_simulation_window", phase, label + "/window geometry")
		if fenced:
			check(str(result.get("code", "")) == "native_refusal", label + ": geometry reaches intact native fence")
			check(_witness(world) == before, label + ": rejected geometry preserves cache, membership, ownership and revisions")
		else:
			var actual: Dictionary = world.get_simulation_window_state()
			check(actual.get("view_origin") == Vector2i(70,80) and actual.get("view_size") == Vector2i(90,60)
				and int(actual.get("horizontal_buffer", -1)) == 7 and int(actual.get("vertical_buffer", -1)) == 9,
				label + ": successful geometry stores the applied request")
			check(actual.get("native_region") == PackedInt64Array([63,71,104,78])
				and actual.get("selected_cores") == PackedInt64Array([0,1,2,2]), label + ": actual native selected membership")
			check(bool(world.simulation_tick()), label + ": valid phase applies selected membership on normal tick")
			actual = world.get_simulation_window_state()
			check(actual.get("applied_cores") == PackedInt64Array([0,1,2,2]), label + ": native tick applied membership readback")
			world.set_simulation_window_enabled(false)
			_status(world.get_last_boundary_result(), true, "set_simulation_window_enabled", phase, label + "/window disable")
			world.set_simulation_window(INITIAL_ORIGIN, INITIAL_SIZE, 3, 5)
			check(world.get_simulation_window_state().get("native_region") == PackedInt64Array([0,0,1024,1024]),
				label + ": disabled window restores full native membership selection")
			check(bool(world.simulation_tick()), label + ": full membership applies")
	var copied: Dictionary = world.get_simulation_window_state()
	var retained: Dictionary = copied.duplicate(true)
	copied["enabled"] = not bool(copied.get("enabled", false))
	if copied.get("native_region", PackedInt64Array()).size() == 4:
		copied["native_region"][0] = 999
	check(world.get_simulation_window_state() == retained, label + ": copied native region is immutable to consumer")

func _coupling_and_fill(world: Object, phase: int, label: String) -> void:
	var fenced: bool = phase in FENCED
	for repeat: int in range(2):
		var before: Dictionary = _witness(world)
		world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
		var result: Dictionary = world.get_last_boundary_result()
		_status(result, not fenced, "prepare_rigid_body_coupling", phase, label + "/coupling")
		if fenced:
			check(_witness(world) == before, label + ": refused coupling retains mask, body state and native ownership")
		else:
			check(int(world.rigid_body_id_at(1000,1000)) == 0 and world.rigid_body_results().is_empty(),
				label + ": valid empty coupling clears the ordinary marker")
		before = _witness(world)
		var filled: bool = bool(world.diagnostic_fill_rect(Vector2i(5,5), Vector2i(2,2), 2))
		result = world.get_last_boundary_result()
		_status(result, not fenced, "diagnostic_fill_rect", phase, label + "/fill")
		check(filled == (not fenced), label + ": fill return describes actual application")
		if fenced:
			check(_witness(world) == before, label + ": failed fill changes no cells or revisions")
		else:
			check(int(world.material_at(5,5)) == 2 and int(world.material_at(6,6)) == 2,
				label + ": accepted repeated/no-op fill has the requested cells")

func _cyps_adhesion(world: Object, expected: bool, label: String) -> Dictionary:
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var saved: PackedByteArray = bridge.export_physical_state(world)
	if not check(not saved.is_empty(), label + ": native CYPS export after safe completion"):
		return {}
	var other: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check(bool(other.diagnostic_reset({"workers":workers, "telemetry":false})), label + ": separate adapter"):
		return {}
	# Deliberately start the independent owner at the opposite flag. Successful
	# equality must therefore arise from decoded native CYPS, not matching caches.
	other.set_liquid_surface_adhesion_enabled(not expected)
	check(bool(other.get_liquid_surface_adhesion_enabled()) == (not expected), label + ": independent contrary initial flag")
	if not check(bool(bridge.import_physical_state(other, saved)), label + ": independent CYPS import"):
		return {}
	var authority: Dictionary = other.get_liquid_surface_adhesion_result()
	check(bool(authority.get("ok", false)) and authority.has("value") and bool(authority.value) == expected,
		label + ": imported native authority matches applied adhesion")
	check(bool(other.get_liquid_surface_adhesion_enabled()) == expected
		and bool(world.get_liquid_surface_adhesion_enabled()) == expected,
		label + ": both public gets agree with independently reimported authority")
	var saved_again: PackedByteArray = bridge.export_physical_state(other)
	check(saved_again == saved, label + ": independently reimported native CYPS reexports byte-exact")
	var actual_hash: Dictionary = world.get_physical_state_hash_result()
	var imported_hash: Dictionary = other.get_physical_state_hash_result()
	check(bool(actual_hash.get("ok", false)) and bool(imported_hash.get("ok", false))
		and _hex16(str(actual_hash.get("value", ""))) and _hex16(str(imported_hash.get("value", ""))),
		label + ": independent owners expose available native physical hashes")
	# CYPS intentionally omits host masks and restores no transient mask domain.
	# The native adhesion/reexport witness above remains valid. A body publication
	# into this imported owner must refuse when native occupancy rejects it; it
	# must not claim success or alter the persisted authority. Never clear the
	# original owner's mask to manufacture full-identity equality.
	var source_mask_retained: bool = int(world.rigid_body_id_at(1000,1000)) == 64
	var imported_publication_refusals: Array[Dictionary] = []
	var full_hash_parity: String = "EXACT"
	if source_mask_retained:
		full_hash_parity = "NOT_APPLICABLE: source retains a host mask omitted by CYPS; imported mask domain is unavailable"
		check(int(other.rigid_body_id_at(1000,1000)) == 0,
			label + ": CYPS import does not pretend to persist transient masks")
		var imported_revision: int = int(other.get_revision())
		for repeat: int in range(2):
			other.prepare_rigid_body_coupling(PackedFloat32Array(MARKER), false)
			var result: Dictionary = other.get_last_boundary_result()
			_status(result, false, "prepare_rigid_body_coupling", 0, label + "/imported mask refusal")
			check(str(result.get("code", "")) == "native_refusal",
				label + ": unavailable native occupancy cannot acknowledge applied body state")
			imported_publication_refusals.append(result.duplicate(true))
			check(int(other.rigid_body_id_at(1000,1000)) == 0 and int(world.rigid_body_id_at(1000,1000)) == 64,
				label + ": refused imported mask preserves both owners' native occupancy")
			var after: Dictionary = other.get_physical_state_hash_result()
			check(bool(after.get("ok", false)) and after.get("value") == imported_hash.get("value")
				and int(other.get_revision()) == imported_revision,
				label + ": repeated imported mask refusal changes no native physical identity or revision")
			check(bridge.export_physical_state(other) == saved,
				label + ": repeated imported mask refusal preserves exact native CYPS authority")
			check(bool(other.get_liquid_surface_adhesion_enabled()) == expected,
				label + ": imported native adhesion remains authoritative after refusal")
	else:
		check(actual_hash.get("value") == imported_hash.get("value"),
			label + ": full physical identity agrees when the source has no nonpersisted mask")
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(saved)
	return {"bytes":saved.size(), "sha256":h.finish().hex_encode(), "native_adhesion":authority.value,
		"source_transient_mask_retained":source_mask_retained, "full_hash_parity":full_hash_parity,
		"imported_publication_refusals":imported_publication_refusals,
		"source_hash":actual_hash.get("value", ""), "imported_hash":imported_hash.get("value", "")}

func _adhesion(world: Object, phase: int, label: String) -> Dictionary:
	var before: Dictionary = _witness(world)
	var initial: bool = bool(world.get_liquid_surface_adhesion_enabled())
	var fenced: bool = phase in FENCED
	var expected: bool = initial if fenced else not initial
	for repeat: int in range(2):
		world.set_liquid_surface_adhesion_enabled(not initial)
		var result: Dictionary = world.get_last_boundary_result()
		_status(result, not fenced, "set_liquid_surface_adhesion_enabled", phase, label + "/adhesion")
		check(bool(world.get_liquid_surface_adhesion_enabled()) == expected, label + ": adhesion get reports applied native state")
		var actual: Dictionary = world.get_liquid_surface_adhesion_result()
		check(bool(actual.get("ok", false)) and actual.has("value") and bool(actual.value) == expected,
			label + ": explicit authoritative adhesion read")
		var receipt: Dictionary = world.get_liquid_run_receipt({})
		var suffix: String = ":adhesion" if expected else ":noadhesion"
		check(str(receipt.get("components", {}).get("execution", "")).ends_with(suffix),
			label + ": run receipt describes native applied flag")
		if fenced:
			check(_witness(world) == before, label + ": rejected adhesion preserves authoritative state and revision")
	var state: Dictionary = world.solid_detachment_command({"action":"inspect"})
	if phase in [2, 3]:
		state = _command(world, {"action":"cancel", "token":state.token}, label + ": cancel safely")
	elif phase in [4, 5]:
		if phase == 4:
			state = _command(world, {"action":"rollback", "token":state.token}, label + ": inactive rollback")
		state = _finish(world, state, "finish_rollback")
	if phase == 6:
		# Active aggregates remain unserializable. An explicit reset is a fresh
		# World, never a fabricated restoration/serialization of the aggregate.
		var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
		check(bridge.export_physical_state(world).is_empty() and not str(bridge.get_last_error()).is_empty(),
			label + ": valid Active adhesion does not admit full physical export")
		check(bool(world.reset_demo_world()), label + ": explicit demo reset")
		check(_phase(world) == 0 and bool(world.get_liquid_surface_adhesion_enabled()) == expected,
			label + ": fresh demo carries only applied adhesion")
	return _cyps_adhesion(world, expected, label)

func _record(name: String, start_checks: int, start_failures: int, details: Dictionary = {}) -> void:
	var row: Dictionary = {"case":name, "checks":checks - start_checks,
		"failures":failures.slice(start_failures), "details":details}
	records.append(row)
	print("SOL_FACADE_CASE ", JSON.stringify(row))

func _phase_case(target: String) -> void:
	var start_checks: int = checks
	var start_failures: int = failures.size()
	print("SOL_FACADE_CASE_BEGIN ", target, " workers=", workers)
	var world: Object = _new_fixture(target)
	if world == null:
		_record(target, start_checks, start_failures, {"apparatus_setup_failed":true})
		return
	var phase: int = int(PHASES[target])
	var hashes: Dictionary = _hashes(world, phase, target)
	_windows(world, phase, target)
	_coupling_and_fill(world, phase, target)
	var witness: Dictionary = _adhesion(world, phase, target)
	_record(target, start_checks, start_failures, {"native_phase":phase, "initial_hashes":hashes,
		"independent_cyps":witness, "native_cells":520, "aggregate_shapes":6})

func _failed_transactions() -> void:
	var start_checks: int = checks
	var start_failures: int = failures.size()
	var world: Object = _new_fixture("prepared")
	if world == null:
		_record("failed_transaction", start_checks, start_failures)
		return
	var before: Dictionary = _witness(world)
	var state: Dictionary = world.solid_detachment_command({"action":"inspect"})
	var bad: Dictionary = world.solid_detachment_command({"action":"acknowledge", "token":state.token,
		"body_id":1, "body_generation":7, "shape_count":state.shape_count,
		"payload_digest":"not-the-source", "shape_digest":state.shape_digest})
	check(not bool(bad.get("ok", true)) and _witness(world) == before, "invalid reservation leaves Prepared owner intact")
	_hashes(world, 2, "failed transaction")
	_windows(world, 2, "failed transaction")
	state = _acknowledge(world, state)
	before = _witness(world)
	bad = world.solid_detachment_command({"action":"commit", "token":"retired-token"})
	check(not bool(bad.get("ok", true)) and _witness(world) == before, "stale commit cannot transfer native ownership")
	state = _command(world, {"action":"commit", "token":state.token}, "valid commit remains possible after refusal")
	before = _witness(world)
	bad = world.solid_detachment_command({"action":"finalize", "token":state.token, "body_id":1,
		"body_generation":8, "terrain_revision":state.commit_revision, "physics_epoch":17})
	check(not bool(bad.get("ok", true)) and _witness(world) == before, "wrong body generation cannot activate Committed owner")
	state = _command(world, {"action":"rollback", "token":state.token}, "failed finalization permits valid inactive rollback")
	state = _finish(world, state, "finish_rollback")
	check(int(state.get("phase", -1)) == 1 and not bool(world.has_failed()), "successful rollback leaves healthy Idle")
	_record("failed_transaction", start_checks, start_failures, _cyps_adhesion(world, true, "failed transaction rollback"))

func _reset_and_masked_fill() -> void:
	var start_checks: int = checks
	var start_failures: int = failures.size()
	var world: Object = _new_fixture("prepared")
	if world == null:
		_record("reset_and_masked_fill", start_checks, start_failures)
		return
	var window: Dictionary = world.get_simulation_window_state()
	world.set_simulation_window_enabled(true)
	world.set_simulation_window(Vector2i(800,800), Vector2i(20,20), 200, 200)
	world.set_liquid_surface_adhesion_enabled(false)
	check(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})), "diagnostic reset after three refused commands")
	var after: Dictionary = world.get_simulation_window_state()
	for key: String in ["enabled", "view_origin", "view_size", "horizontal_buffer", "vertical_buffer", "native_region"]:
		check(after.get(key) == window.get(key), "diagnostic reset did not inherit rejected " + key)
	check(bool(world.get_liquid_surface_adhesion_enabled()), "diagnostic reset reflects new native default true")
	world.set_liquid_surface_adhesion_enabled(false)
	check(not bool(world.get_liquid_surface_adhesion_enabled()), "healthy owner can apply false")
	check(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})), "second diagnostic reset")
	check(bool(world.get_liquid_surface_adhesion_enabled()), "new diagnostic World reports its own true default")
	check(bool(world.reset_demo_world()) and bool(world.get_liquid_surface_adhesion_enabled()),
		"subsequent demo reset cannot resurrect stale false cache")
	var default_witness: Dictionary = _cyps_adhesion(world, true, "reset native authority")
	check(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})), "isolated masked-fill owner")
	# Native first-body occupancy is valid arbitration, not refusal. Both records
	# request the same cell; the lower body id is rasterized first by the facade.
	world.prepare_rigid_body_coupling(PackedFloat32Array([
		63,1000.5,1000.5,0,1,1,0,0,0,1,7,
		64,1000.5,1000.5,0,1,1,0,0,0,1,7]), false)
	_status(world.get_last_boundary_result(), true, "prepare_rigid_body_coupling", 0, "occupied native mask arbitration")
	check(int(world.rigid_body_id_at(1000,1000)) == 63,
		"overlapping valid bodies retain the existing first-body native occupancy")
	world.prepare_rigid_body_coupling(PackedFloat32Array([
		64,-1000.5,-1000.5,0,1,1,0,0,0,1,7]), false)
	_status(world.get_last_boundary_result(), true, "prepare_rigid_body_coupling", 0, "outside body")
	check(int(world.rigid_body_id_at(1000,1000)) == 0 and int(world.rigid_body_id_at(0,0)) == 0
		and not bool(world.has_failed()),
		"body with no in-domain raster cells remains a valid empty publication")
	world.prepare_rigid_body_coupling(PackedFloat32Array(MARKER), false)
	_status(world.get_last_boundary_result(), true, "prepare_rigid_body_coupling", 0, "ordinary marker after positive controls")
	check(int(world.rigid_body_id_at(1000,1000)) == 64, "ordinary configured owner still publishes its native marker")
	var before: Dictionary = _witness(world)
	for repeat: int in range(2):
		check(not bool(world.diagnostic_fill_rect(Vector2i(999,1000), Vector2i(2,1), 2)),
			"partially masked diagnostic rectangle refuses as one command")
		_status(world.get_last_boundary_result(), false, "diagnostic_fill_rect", 0, "masked fill")
		check(_witness(world) == before, "masked fill cannot partly write its unmasked first cell or advance revision")
	var water_policy: Dictionary = world.get_water_experiment_policy()
	check(int(water_policy.get("coherence_ticks", 255)) < 255,
		"Water coherence negative exceeds the actual applied native policy")
	for repeat: int in range(2):
		check(not bool(world.diagnostic_fill_rect(Vector2i(5,5), Vector2i(2,2), 3, 255)),
			"invalid Water coherence refuses the entire diagnostic rectangle")
		var result: Dictionary = world.get_last_boundary_result()
		_status(result, false, "diagnostic_fill_rect", 0, "invalid Water coherence")
		check(str(result.get("code", "")) == "invalid_argument",
			"invalid Water coherence has a distinguishable argument refusal")
		check(_witness(world) == before,
			"invalid Water coherence changes no native cells, masks or revisions")
	_record("reset_and_masked_fill", start_checks, start_failures, {"independent_cyps":default_witness})

func _extreme_window() -> void:
	var start_checks: int = checks
	var start_failures: int = failures.size()
	var world: Object = _new_fixture("idle")
	if world == null:
		_record("extreme_window", start_checks, start_failures)
		return
	const MAX_BUFFER: int = 9223372036854775807
	world.set_simulation_window_enabled(true)
	check(bool(world.simulation_tick()), "enabled-window control applies its native membership")
	world.set_simulation_window(Vector2i(-2147483648,2147483647),
		Vector2i(2147483647,-2147483648), MAX_BUFFER, MAX_BUFFER)
	_status(world.get_last_boundary_result(), true, "set_simulation_window", 1, "extreme window")
	var actual: Dictionary = world.get_simulation_window_state()
	check(int(actual.get("horizontal_buffer", -1)) == MAX_BUFFER
		and int(actual.get("vertical_buffer", -1)) == MAX_BUFFER,
		"extreme accepted buffers retain exact caller intent")
	check(actual.get("native_region") == PackedInt64Array([0,0,1024,1024])
		and actual.get("selected_cores") == PackedInt64Array([0,0,15,15]),
		"extreme arithmetic selects full finite domain without signed overflow")
	check(bool(world.simulation_tick()), "extreme accepted window applies full-domain native membership")
	var state: Dictionary = _prepare(world)
	var before: Dictionary = _witness(world)
	for repeat: int in range(2):
		world.set_simulation_window_enabled(false)
		_status(world.get_last_boundary_result(), false, "set_simulation_window_enabled", 2, "fenced disable")
		check(_witness(world) == before,
			"fenced enabled-to-unrestricted route changes no facade flag or native membership")
		world.set_simulation_window(Vector2i(2147483647,-2147483648),
			Vector2i(-2147483648,2147483647), MAX_BUFFER, MAX_BUFFER)
		_status(world.get_last_boundary_result(), false, "set_simulation_window", 2, "fenced extreme window")
		check(_witness(world) == before, "fenced extreme geometry changes no applied or requested state")
	state = _command(world, {"action":"cancel", "token":state.token}, "extreme-window cancellation")
	world.set_simulation_window_enabled(false)
	_status(world.get_last_boundary_result(), true, "set_simulation_window_enabled", 1, "disable after cancel")
	actual = world.get_simulation_window_state()
	check(not bool(actual.get("enabled", true)) and actual.get("native_region") == PackedInt64Array([0,0,1024,1024]),
		"successful cancellation permits the same previously refused disable command")
	world.set_simulation_window_enabled(true)
	world.set_simulation_window(Vector2i(10,20), Vector2i(30,40), -1, -MAX_BUFFER)
	_status(world.get_last_boundary_result(), true, "set_simulation_window", 1, "negative buffer clamp")
	actual = world.get_simulation_window_state()
	check(int(actual.get("horizontal_buffer", -1)) == 0 and int(actual.get("vertical_buffer", -1)) == 0
		and actual.get("native_region") == PackedInt64Array([10,20,30,40]),
		"negative buffer normalization preserves the existing zero-buffer contract")
	_record("extreme_window", start_checks, start_failures)

func _pending_liquid_commit() -> void:
	# The token is prepared while Idle. SOL prepare/acknowledge do not advance
	# adapter revision, so this reaches the previously uncaught native hash fence.
	for target: String in ["prepared", "acknowledged"]:
		var start_checks: int = checks
		var start_failures: int = failures.size()
		var world: Object = _new_fixture("idle")
		if world == null:
			_record("pending_liquid_" + target, start_checks, start_failures)
			continue
		var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
		var token: int = bridge.prepare_liquid_default_demo(world, bridge.default_liquid_policy(), {
			"region":PackedInt32Array([0,0,1024,1024]), "simulation_window_enabled":false,
			"cadence_lod_enabled":false, "liquid_surface_adhesion_enabled":true,
			"intent":"controlled", "pacing":"fixed_steps"})
		if not check(token > 0, target + ": real native liquid replacement token prepares: " + str(bridge.get_last_error())):
			_record("pending_liquid_" + target, start_checks, start_failures)
			continue
		var original_revision: int = world.get_revision()
		var original_generation: int = world.get_liquid_policy_session_generation()
		var state: Dictionary = _prepare(world)
		if target == "acknowledged":
			state = _acknowledge(world, state)
		check(int(world.get_revision()) == original_revision, target + ": SOL has not short-circuited commit with revision drift")
		var before: Dictionary = _witness(world)
		check(not bool(bridge.commit_liquid_world(world, token)), target + ": stale physical-identity validation safely refuses")
		var diagnostic: String = bridge.get_last_error()
		check(not diagnostic.is_empty(), target + ": refused prepared replacement has an observable diagnostic")
		check(_witness(world) == before and int(world.get_liquid_policy_session_generation()) == original_generation,
			target + ": refused replacement preserves retained World and all ownership")
		check(not bool(bridge.commit_liquid_world(world, token)), target + ": refused token is one-use")
		check(not str(bridge.get_last_error()).is_empty(), target + ": retired token diagnostic")
		check(bridge.prepared_liquid_world_values(world, token).is_empty(), target + ": retired candidate unavailable")
		state = _command(world, {"action":"cancel", "token":state.token}, target + ": cancellation survives liquid refusal")
		check(int(state.get("phase", -1)) == 1, target + ": cancelled owner remains usable")
		var witness: Dictionary = _cyps_adhesion(world, true, target + ": native owner after replacement refusal")
		_record("pending_liquid_" + target, start_checks, start_failures,
			{"first_refusal":diagnostic, "independent_cyps":witness})

func _failed_world() -> void:
	var start_checks: int = checks
	var start_failures: int = failures.size()
	var old_capacity: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity", null)
	var old_workers: Variant = ProjectSettings.get_setting("cybersand/native_worker_threads", null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	ProjectSettings.set_setting("cybersand/native_worker_threads", workers)
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", old_capacity)
	ProjectSettings.set_setting("cybersand/native_worker_threads", old_workers)
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	world.set_simulation_window(Vector2i.ZERO, Vector2i(320,180), 0, 0)
	check(int(world.get_worker_threads()) == workers, "failed-world actual worker count")
	if not check(bool(bridge.build_world(world, PackedInt32Array([20,20,1,1,2]))), "capacity failure owner constructs"):
		_record("failed_world", start_checks, start_failures)
		return
	check(bool(world.simulation_tick()), "capacity control has one successful native tick")
	world.paint_disc(20,20,0,1)
	world.paint_disc(21,20,0,1)
	world.paint_disc(160,20,0,2)
	check(not bool(world.simulation_tick()) and bool(world.has_failed()), "real native capacity failure is latched")
	check(int(world.get_tick_index()) == 1 and int(world.get_attempted_tick_index()) == 2,
		"capacity failure separates completed and attempted tick identity")
	var tick_error: String = world.get_last_tick_error()
	var failed_at: int = world.get_attempted_tick_index()
	var failure_count: int = world.get_tick_failure_count()
	check(not tick_error.is_empty() and failure_count == 1, "actual capacity diagnostic retained")
	# Native config/read authority intentionally remains available while failed.
	# Such calls must never clear quarantine or retry a failed tick.
	for projection: int in [0, 1, 2]:
		var value: Dictionary = world.get_physical_state_hash_result() if projection == 0 else world.get_liquid_comparison_hash_result(projection)
		check(bool(value.get("ok", false)) and _hex16(str(value.get("value", ""))), "failed owner retains defined native diagnostic hash")
	world.set_simulation_window(Vector2i(384,0), Vector2i(64,64), 0, 0)
	_status(world.get_last_boundary_result(), true, "set_simulation_window", 0, "failed-world configuration")
	check(world.get_simulation_window_state().get("native_region") == PackedInt64Array([384,0,64,64]),
		"failed owner safe region configuration is still applied")
	world.set_liquid_surface_adhesion_enabled(false)
	_status(world.get_last_boundary_result(), true, "set_liquid_surface_adhesion_enabled", 0, "failed-world adhesion")
	var adhesion: Dictionary = world.get_liquid_surface_adhesion_result()
	check(bool(adhesion.get("ok", false)) and adhesion.has("value") and not bool(adhesion.value),
		"known native adhesion remains authoritative while World is failed")
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	_status(world.get_last_boundary_result(), false, "prepare_rigid_body_coupling", 0, "failed-world coupling")
	check(str(world.get_last_boundary_result().get("code", "")) == "world_failed",
		"failed-world coupling preserves terminal quarantine diagnostic")
	check(not bool(world.diagnostic_fill_rect(Vector2i(20,20), Vector2i.ONE, 2)), "failed owner cannot acknowledge a cell write")
	check(not bool(world.simulation_tick()) and bool(world.has_failed())
		and int(world.get_attempted_tick_index()) == failed_at and int(world.get_tick_failure_count()) == failure_count,
		"configuration/readback did not revive or retry failed native World")
	check(bool(world.reset_demo_world()) and not bool(world.has_failed()) and int(world.get_tick_index()) == 0,
		"explicit replacement reset is the recovery boundary")
	check(not bool(world.get_liquid_surface_adhesion_enabled()), "demo replacement inherits applied native flag")
	_record("failed_world", start_checks, start_failures, {"native_capacity_error":tick_error,
		"attempted_tick":failed_at, "failure_count":failure_count,
		"scope":"real failed World, not SOL phase Quarantined"})

func _run() -> void:
	started_usec = Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--workers="):
			workers = arg.trim_prefix("--workers=").to_int()
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		else:
			check(false, "unknown argument: " + arg)
	if not check(workers in [1, 4], "registered worker count"):
		_finish_report()
		return
	if not check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge"),
		"actual native extension and bridge are registered"):
		_finish_report()
		return
	var api: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	for method: StringName in [&"get_physical_state_hash_result", &"get_liquid_comparison_hash_result",
		&"get_last_boundary_result", &"get_simulation_window_state", &"get_liquid_surface_adhesion_result"]:
		check(api.has_method(method), "source-matched additive public API: " + str(method))
	api = null
	if not failures.is_empty():
		_finish_report()
		return
	for target: String in ORIGINAL_PHASES:
		_phase_case(target)
		await process_frame
	_failed_transactions()
	await process_frame
	_reset_and_masked_fill()
	await process_frame
	_extreme_window()
	await process_frame
	_pending_liquid_commit()
	await process_frame
	_failed_world()
	_finish_report()

func _finish_report() -> void:
	var script_bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/test_sol_facade_refusals.gd")
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(script_bytes)
	var report: Dictionary = {"schema":"cybersand.sol-facade-refusals.v1", "platform":OS.get_name(),
		"godot":Engine.get_version_info(), "workers":workers, "checks":checks, "failures":failures,
		"cases":records, "case_count":records.size(), "elapsed_us":Time.get_ticks_usec()-started_usec,
		"script_sha256":h.finish().hex_encode(), "synthetic_body_receipts":true, "live_rapier_qualification":false,
		"original_122_matrix":"separate before/after apparatus; these are supplemental regressions",
		"not_run":[{"case":"SOL phase Quarantined through Godot",
			"reason":"no public deterministic native write-failure injection; native-only quarantine tests remain separate"}]}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			check(false, "cannot write requested report: " + str(FileAccess.get_open_error()))
			report["checks"] = checks
			report["failures"] = failures
		else:
			file.store_string(JSON.stringify(report, "\t") + "\n")
			file.close()
	print("SOL_FACADE_REFUSALS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
