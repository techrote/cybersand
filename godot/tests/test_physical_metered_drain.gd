extends SceneTree

# IN-TOOLS #361-A: the actual native World, construction receipt, physical U10
# runtime and mutex admission route. Diagnostic snapshots independently count
# stored quantities, including material hidden by real native body masks. This
# is headless owner/API qualification, not graphical or physical-device proof.
const Runtime = preload("res://scripts/physical_usable_runtime.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalog = preload("res://scripts/usable_catalog.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const PROFILE: String = "metered-drain-v1"
const EPOCH: int = 361
const DT: float = 1.0 / 60.0
const METERED_FIELDS: Array[String] = ["profile", "material", "native_generation",
	"policy_hash", "world_instance_id", "quantity_budget"]
var checks: int = 0
var failures: int = 0
var bridge: Object
var world: Object
var runtime = Runtime.new()
var frame: Dictionary = {}
var sequence: int = 0
var profile: PackedInt32Array
var reports: Array = []
var commands: Array = []
var selected_material: int = 3
var fixture: Dictionary = {}
var fixture_digest: String = ""


class MaterialWorkProbe:
	extends "res://scripts/metered_liquid_drain.gd"
	# Every hook forwards to the actual native-backed implementation. These
	# observations cover helper material work, not every native getter in a step.
	var preflight_inspections: int = 0
	var post_inspections: int = 0
	var erase_attempts: int = 0
	var pre_identity_checks: int = 0
	var post_identity_checks: int = 0
	var lifecycle_refreshes: int = 0
	var apply_refreshes: int = 0
	var first_write: Dictionary = {}
	var post_readbacks: Array = []
	var corrupt_post_copy: bool = false
	var _preflight_points: Dictionary = {}
	var _applying: bool = false
	var _observed_owner: int = -1
	var _available_reads: int = 0
	var _available_writes: int = 0

	func clear_trace() -> void:
		preflight_inspections = 0
		post_inspections = 0
		erase_attempts = 0
		pre_identity_checks = 0
		post_identity_checks = 0
		lifecycle_refreshes = 0
		apply_refreshes = 0
		first_write.clear()
		post_readbacks.clear()
		_preflight_points.clear()

	func refresh(value: Object) -> Dictionary:
		if _applying:
			apply_refreshes += 1
		else:
			lifecycle_refreshes += 1
		return super.refresh(value)

	func apply(value: Object, pose: Dictionary, request: Dictionary, effective_power: float,
		reads_available: int, writes_available: int, frame_tick: int) -> Dictionary:
		_observed_owner = int(request.actor_id)
		_available_reads = reads_available
		_available_writes = writes_available
		_applying = true
		var result: Dictionary = super.apply(value, pose, request, effective_power,
			reads_available, writes_available, frame_tick)
		_applying = false
		return result

	func _inspect(value: Object, point: Vector2i) -> Dictionary:
		var copied: Dictionary = super._inspect(value, point)
		if erase_attempts == 0:
			preflight_inspections += 1
			_preflight_points[point] = true
		else:
			post_inspections += 1
			post_readbacks.append(copied.duplicate(true))
			if corrupt_post_copy:
				return {"ok":false,"test_injection":"invalid-copy-after-forwarded-native-post-read"}
		return copied

	func _identity_matches(value: Object, request: Dictionary, revision: int) -> bool:
		if erase_attempts == 0:
			pre_identity_checks += 1
		else:
			post_identity_checks += 1
		return super._identity_matches(value, request, revision)

	func _erase(value: Object, point: Vector2i) -> void:
		if erase_attempts == 0:
			first_write = {"terminal":terminal,"status":terminal_evidence.get("status"),
				"reason":terminal_evidence.get("reason"),
				"preflight_complete":terminal_evidence.get("preflight_complete"),
				"planned_targets":terminal_evidence.get("eligible_target_count",0),
				"writes_attempted":terminal_evidence.get("writes_attempted",0),
				"observed_preflight_inspections":preflight_inspections,
				"observed_pre_identity_checks":pre_identity_checks,
				"material_work_units_before_write":_reads,
				"reads_available":_available_reads,"writes_available":_available_writes,
				"stock_before":_stock_for(_observed_owner).duplicate(true)}
		erase_attempts += 1
		super._erase(value, point)

	func trace() -> Dictionary:
		var points: Array = []
		for point: Vector2i in _preflight_points:
			points.append([point.x,point.y])
		return {"scope":"forwarded helper hooks; not an all-native-getter census",
			"preflight_inspections":preflight_inspections,"unique_preflight_points":points,
			"post_inspections":post_inspections,"erase_attempts":erase_attempts,
			"pre_identity_checks":pre_identity_checks,"post_identity_checks":post_identity_checks,
			"lifecycle_refreshes":lifecycle_refreshes,"apply_refreshes":apply_refreshes,
			"first_write":first_write.duplicate(true),"post_readbacks":post_readbacks.duplicate(true),
			"corrupt_post_copy":corrupt_post_copy}


class InvalidPreflightRead:
	extends "res://scripts/metered_liquid_drain.gd"

	func _inspect(_world: Object, _point: Vector2i) -> Dictionary:
		return {"ok": false, "test_injection": "invalid-preflight-readback"}


class FractionalWholeCellRead:
	extends "res://scripts/metered_liquid_drain.gd"

	func _inspect(value: Object, point: Vector2i) -> Dictionary:
		var copied: Dictionary = super._inspect(value, point)
		if copied.get("material") == 3:
			copied.state_a = 1
		return copied


class InterruptedErase:
	extends "res://scripts/metered_liquid_drain.gd"
	var attempted: int = 0

	func _erase(value: Object, point: Vector2i) -> void:
		attempted += 1
		if attempted == 1:
			super._erase(value, point)


class InvalidPostRead:
	extends "res://scripts/metered_liquid_drain.gd"
	var wrote: bool = false

	func _erase(value: Object, point: Vector2i) -> void:
		super._erase(value, point)
		wrote = true

	func _inspect(value: Object, point: Vector2i) -> Dictionary:
		if wrote:
			return {"ok": false, "test_injection": "invalid-post-write-readback"}
		return super._inspect(value, point)


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("METERED_DRAIN: " + message)


func _actor() -> Dictionary:
	var descriptor: Dictionary = fixture.actor
	var center := Vector2(descriptor.center[0], descriptor.center[1])
	var half := Vector2(descriptor.half_extents[0], descriptor.half_extents[1])
	return {"actor_id": 0, "generation": 0, "equipment_epoch": 1,
		"instance_id": "metered-physical-u10", "usable_index": 9, "state": "held",
		"body_id": int(descriptor.body_id), "position": center, "rotation": 0.0, "half_extents": half,
		"muzzle": center + Vector2(descriptor.muzzle_offset[0], descriptor.muzzle_offset[1]),
		"direction": Vector2(descriptor.aim[0], descriptor.aim[1]),
		"owner_origin": center + Vector2(descriptor.owner_origin_offset[0], descriptor.owner_origin_offset[1]),
		"active": true, "lease_deadline": 100000,
		"parts": [{"body_id": int(descriptor.body_id), "position": center, "rotation": 0.0,
			"half_extents": half}]}


func _states(extra: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for actor: Dictionary in frame.actors:
		for part: Dictionary in actor.parts:
			Coupling.append_input(values, int(part.body_id), part.position, float(part.rotation),
				Vector2(part.half_extents) * 2.0, Vector2.ZERO, 0.0, 1.0, int(frame.tick) + 1)
	values.append_array(extra)
	return values


func _masks(extra: PackedFloat32Array = PackedFloat32Array()) -> void:
	world.prepare_rigid_body_coupling(_states(extra), false)


func _setup(material: int = 3, family: int = 4, bits: int = 8, workers: int = 1,
	options: Dictionary = {}) -> bool:
	selected_material = material if material in [3, 24] else 3
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers": workers}), "fresh diagnostic worker configuration")
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	if material == 3:
		policy[21] = family
	elif material == 24:
		policy[39] = family
	if options.get("pressure_elsewhere", false):
		policy[21] = 3
	var rectangles := PackedInt32Array(fixture.wall_rectangles)
	var liquid: Array = fixture.liquid_rectangle
	if not options.get("empty", false):
		rectangles.append_array(PackedInt32Array([liquid[0],liquid[1],liquid[2],liquid[3],material]))
	var fills := PackedInt32Array()
	if options.get("fractional", false):
		fills = PackedInt32Array([liquid[0],liquid[1],liquid[2],liquid[3],fixture.partial_freemass_units,0])
	var semantics := PackedInt32Array([1,bits,12,0])
	var radius: int = int(options.get("radius", 3))
	var setup_claim: String = JSON.stringify({"version": 1, "fixture_sha256": fixture_digest, "rectangles": rectangles,
		"fills": fills, "semantics": semantics, "policy": policy, "radius": radius}).sha256_text()
	var token: int = bridge.prepare_liquid_world(world, rectangles, profile, semantics, fills, policy,
		{"definition_hash": setup_claim, "region": PackedInt32Array([0,0,1024,1024]),
		"simulation_window_enabled": false, "intent": "exploratory", "maximum_rule_radius": radius,
		"cadence_lod_enabled": false, "liquid_surface_adhesion_enabled": false})
	var installed: bool = token > 0 and bridge.commit_liquid_world(world, token)
	expect(installed, "prepared source installs: " + str(bridge.get_last_error()))
	if not installed:
		return false
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(receipt.canonical_bytes)
	expect(digest.finish().hex_encode() == receipt.receipt_hash and receipt.completed_tick == 0,
		"actual native construction bytes bind the fresh source")
	var applied: Dictionary = world.get_liquid_solver_policy()
	var water_policy: Dictionary = world.get_water_experiment_policy()
	expect(int(applied.maximum_rule_radius) == radius and int(water_policy.mass_bits) == bits
		and receipt.session_generation == world.get_liquid_policy_session_generation(),
		"applied native radius, quantity precision and construction generation match fixture")
	if material in [3,24]:
		var expected_family: String = {1:"freemass_v1",2:"cellular_yield_v1",4:"inertial_cellular_v1"}.get(family,"")
		var found: bool = false
		for assignment: Dictionary in applied.assignments:
			if assignment.material == material:
				found = assignment.applied_family == expected_family and assignment.applied_variant == "reference"
		expect(found,"requested material actually runs the registered solver family without fallback")
	runtime = Runtime.new()
	sequence = 0
	frame = {"version": 1, "run_id": "in-tools-361a-native-fixture", "epoch": EPOCH,
		"tick": 0, "suspended": false, "actors": [_actor()], "devices": []}
	_masks()
	_step()
	return true


func _context() -> Dictionary:
	for actor: Dictionary in runtime.snapshot().get("actors", []):
		if int(actor.get("actor_id", -1)) == 0:
			return actor.get("metered_drain", {}).duplicate(true)
	return {}


func _request(metered: bool = true, operation: String = "use", power: float = 1.0) -> Dictionary:
	sequence += 1
	var request: Dictionary = {"version": 2 if metered else 1, "run_id": frame.run_id,
		"epoch": frame.epoch, "sequence": sequence, "request_id": "drain-%d" % sequence,
		"operation": operation, "power": power}
	var actor: Dictionary = frame.actors[0]
	for key: String in ["actor_id", "generation", "equipment_epoch", "instance_id", "usable_index", "body_id"]:
		request[key] = actor[key]
	if metered:
		var context: Dictionary = _context()
		request.merge({"profile": PROFILE, "material": selected_material,
			"native_generation": context.get("native_generation", -1),
			"policy_hash": context.get("policy_hash", ""),
			"world_instance_id": context.get("world_instance_id", -1),
			"quantity_budget": 16 * int(context.get("maximum", 255)) if selected_material == 3 else 16})
		for key: String in METERED_FIELDS:
			actor[key] = request[key]
		actor["metered_request_id"] = request.request_id
	return request


func _step(requests: Array = [], delta: float = DT) -> Dictionary:
	frame.tick = int(frame.tick) + 1
	return runtime.step(delta, world, frame, requests)


func _cool_down() -> void:
	for _tick: int in range(8):
		_step()


func _receipt(result: Dictionary, request: Dictionary) -> Dictionary:
	for row: Dictionary in result.get("receipts", []):
		if row.get("request_id") == request.get("request_id"):
			commands.append({"outcome_index":commands.size()+1,"world_instance_observed":world.get_instance_id(),
				"native_generation_observed":world.get_liquid_policy_session_generation(),
				"completed_tick_observed":world.get_tick_index(),"receipt":row.duplicate(true)})
			return row
	return {}


func _census() -> Dictionary:
	var water: int = 0
	var brine: int = 0
	var walls: int = 0
	# Diagnostic-only, real stored-material census. Water render bytes are
	# deliberately NOT counted: copy_material_cells dithers fractional Water.
	for origin: Vector2i in [Vector2i.ZERO, Vector2i(512,0), Vector2i(0,512), Vector2i(512,512)]:
		var actual: Dictionary = world.diagnostic_snapshot(origin, Vector2i(512,512), false)
		if actual.is_empty():
			expect(false, "authoritative native census unavailable")
			return {}
		water += int(actual.water_mass)
		brine += int(actual.counts[24])
		walls += int(actual.counts[1])
	var water_readback: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024,1024))
	expect(water == int(water_readback.water_integer), "independent native Water quantities agree")
	return {"water": water, "brine": brine, "walls": walls}


func _wall_positions() -> PackedByteArray:
	var bytes := PackedByteArray()
	var walls: Array = fixture.wall_rectangles
	for index: int in range(0,walls.size(),5):
		for y: int in range(int(walls[index+1]),int(walls[index+1])+int(walls[index+3])):
			for x: int in range(int(walls[index]),int(walls[index])+int(walls[index+2])):
				bytes.append(int(bridge.inspect_cell(world,Vector2i(x,y)).material))
	return bytes


func _expect_refusal(label: String, request: Dictionary, allowed_reasons: Array = []) -> Dictionary:
	var before: Dictionary = _census()
	var hash_before: String = world.get_physical_state_hash()
	var context: Dictionary = _context()
	var prior: Dictionary = runtime.snapshot()
	var resource: Dictionary = prior.actors[0]
	var result: Dictionary = _step([request])
	var receipt: Dictionary = _receipt(result, request)
	expect(not receipt.is_empty() and not bool(receipt.get("accepted", true)), label + " explicit refusal")
	expect(not str(receipt.get("reason", "")).is_empty(), label + " carries reason")
	if not allowed_reasons.is_empty():
		expect(receipt.get("reason") in allowed_reasons, label + " deterministic reason: " + str(receipt))
	expect(world.get_physical_state_hash() == hash_before and _census() == before,
		label + " preserves exact native quantity/motion/content")
	var metered: Dictionary = receipt.get("metered_drain", {})
	expect(int(metered.get("water_units_removed", 0)) == 0 and int(metered.get("brine_cells_removed", 0)) == 0,
		label + " reports no fabricated sink")
	var advance: bool = not bool(frame.suspended) and not world.has_failed()
	var charge_expected: float = minf(100.0,float(resource.charge) + (6.0 * DT if advance else 0.0))
	var cooldown_expected: float = maxf(0.0,float(resource.cooldown) - (DT if advance else 0.0))
	expect(is_equal_approx(float(receipt.get("charge",-1)),charge_expected)
		and is_equal_approx(float(receipt.get("cooldown",-1)),cooldown_expected),
		label + " preserves ordinary recharge/cooldown aging without new activation cost")
	expect(result.get("effects",[]).size() <= prior.get("effects",[]).size(),
		label + " emits no phantom drain event")
	var later: Dictionary = _context()
	for key: String in ["water_units_remaining", "water_units_removed", "brine_cells_remaining", "brine_cells_removed"]:
		expect(later.get(key) == context.get(key), label + " retains " + key)
	reports.append({"case": label, "status": "refused", "reason": receipt.get("reason"),
		"physical_hash_before": hash_before, "physical_hash_after": world.get_physical_state_hash(),
		"initial":before,"final":_census(),"receipt":receipt.duplicate(true),
		"context_before":context,"context_after":later})
	return result


func _quantities_and_workers() -> void:
	for configuration: Array in fixture.quantity_axes:
		var hashes: Array[String] = []
		for workers: int in fixture.workers:
			if not _setup(configuration[0],configuration[1],configuration[2],workers,{"fractional":configuration[3]}):
				continue
			var initial: Dictionary = _census()
			var initial_context: Dictionary = _context()
			expect(initial_context.get("available", false), "actual prepared policy enables metered context: " + str(initial_context))
			expect(int(initial_context.get("maximum", -1)) == (1 << int(configuration[2])) - 1,
				"context carries actual native quantity precision")
			var protected_walls: PackedByteArray = _wall_positions()
			var request: Dictionary = _request()
			var start: int = Time.get_ticks_usec()
			var result: Dictionary = _step([request])
			var command_usec: int = Time.get_ticks_usec() - start
			var receipt: Dictionary = _receipt(result, request)
			var measured: Dictionary = receipt.get("metered_drain", {})
			var after: Dictionary = _census()
			var removed_water: int = int(initial.water) - int(after.water)
			var removed_brine: int = int(initial.brine) - int(after.brine)
			expect(receipt.get("accepted", false) and measured.get("status") == "applied",
				"real U10 metered effect applies: " + str(receipt))
			expect(measured.get("provenance") == "host-local-native-observation-v1",
				"outcome truthfully labels native observations and host authorship")
			expect(measured.get("world_instance_id") == world.get_instance_id()
				and measured.get("native_generation") == world.get_liquid_policy_session_generation()
				and measured.get("applied_policy",{}).get("policy_hash") == world.get_liquid_solver_policy().policy_hash,
				"outcome binds actual native instance, generation and applied policy")
			expect(removed_water == int(measured.get("water_units_removed", -1))
				and removed_brine == int(measured.get("brine_cells_removed", -1)),
				"complete native inventory closes both independent sink dimensions")
			expect(int(receipt.get("changed_cells", 0)) > 0 and int(receipt.get("changed_cells", 99)) <= 16,
				"bounded activation removes actual one-to-sixteen cells")
			var quantum: int = (1 << int(configuration[2])) - 1
			if configuration[0] == 3:
				var per_cell: int = int(fixture.partial_freemass_units) if configuration[3] else quantum
				expect(removed_water == int(receipt.get("changed_cells", -1)) * per_cell and removed_brine == 0,
					"Water uses stored native units, including partial FreeMass")
			else:
				expect(removed_brine == int(receipt.get("changed_cells", -1)) and removed_water == 0,
					"Brine counts cells even though its state_a is zero")
			expect(is_equal_approx(float(receipt.get("charge", 0.0)), 99.15)
				and is_equal_approx(float(receipt.get("cooldown", 0.0)), 0.10),
				"exact accepted 0.85 charge and 0.10 second cooldown")
			expect(measured.get("completed_tick_before", -1) == 0 and measured.get("completed_tick_after", -2) == 0,
				"before/after observations share one completed native tick")
			var actual_context: Dictionary = _context()
			expect(int(actual_context.get("water_units_removed", -1)) == removed_water
				and int(actual_context.get("brine_cells_removed", -1)) == removed_brine,
				"owner ledger matches actual accepted quantity")
			expect(int(actual_context.get("water_units_initial", -1)) - removed_water == int(actual_context.get("water_units_remaining", -2))
				and int(actual_context.get("brine_cells_initial", -1)) - removed_brine == int(actual_context.get("brine_cells_remaining", -2)),
				"finite experimental budget closes independently for Water and Brine")
			expect(_wall_positions() == protected_walls, "every protected Wall position remains intact")
			# Continue normal native transport after a shut-off. No more runtime
			# requests are supplied; post-drain motion is legitimate internal flow.
			var max_claimants: int = 0
			var tick_costs: Array = []
			var transport_observations: Array = []
			for _tick: int in range(int(fixture.transport_after_shutoff_ticks)):
				expect(world.simulation_tick(), "post-drain native transport completes")
				var statistics: Dictionary = bridge.inspect_statistics(world)
				max_claimants = maxi(max_claimants, int(statistics.values.worker_threads_observed))
				tick_costs.append(world.get_simulation_time_ms())
				var current_census: Dictionary = _census()
				expect(current_census == after, "each stopped-sink tick conserves full stored quantity")
				transport_observations.append({"completed_tick":world.get_tick_index(),
					"quantity":current_census,"actual_phase_claimants":statistics.values.worker_threads_observed,
					"phase_jobs":statistics.get("phase_jobs_last_tick",[]),
					"native_tick_ms":world.get_simulation_time_ms()})
			expect(_wall_positions() == protected_walls, "transport preserves positional terrain")
			var forbidden: Array = fixture.forbidden_side_region
			var outside: Dictionary = world.diagnostic_snapshot(Vector2i(forbidden[0],forbidden[1]),
				Vector2i(forbidden[2],forbidden[3]),false)
			expect(int(outside.counts[3]) == 0 and int(outside.counts[24]) == 0,
				"no selected liquid crosses the forbidden side of the hard barrier")
			expect(max_claimants >= 1 and max_claimants <= workers, "record actual bounded pool claimants")
			hashes.append(world.get_physical_state_hash())
			reports.append({"case":"quantity-and-shutoff","material":configuration[0],"family":configuration[1],
				"bits":configuration[2],"fractional":configuration[3],"configured_workers":workers,
				"actual_claimants_max":max_claimants,"initial":initial,"final":after,"command":receipt,
				"command_owner_usec":command_usec,"native_tick_ms":tick_costs,
				"transport_observations":transport_observations,
				"construction_receipt_hash":world.get_applied_liquid_construction_receipt().receipt_hash,
				"physical_hash":world.get_physical_state_hash()})
		if hashes.size() == 2:
			expect(hashes[0] == hashes[1], "one/four-worker exact native continuation parity")


func _refusals_and_resources() -> void:
	_setup(3,4,8,1,{"empty":true})
	_expect_refusal("empty-intake", _request())
	_setup(24,2)
	selected_material = 3
	_expect_refusal("wrong-material", _request())
	_setup(24,2,8,1,{"pressure_elsewhere":true})
	_expect_refusal("unsupported-global-pressure-policy", _request())
	_setup()
	var unsupported: Dictionary = _request()
	unsupported.material = 16
	_expect_refusal("unsupported-requested-material",unsupported)
	_setup()
	_request()
	_expect_refusal("selected-profile-rejects-legacy-request",_request(false),["metered_version_required"])
	_setup()
	var masks := PackedFloat32Array()
	var blocker: Dictionary = fixture.blocked_source_body
	Coupling.append_input(masks,int(blocker.body_id),Vector2(blocker.center[0],blocker.center[1]),0.0,
		Vector2(blocker.size[0],blocker.size[1]),Vector2.ZERO,0.0,1.0,1)
	_masks(masks)
	expect(bridge.inspect_cell(world,Vector2i(118,100)).material == 3
		and world.rigid_body_id_at(118,100) == 2, "masked source stores real Water below the native mask")
	_expect_refusal("body-masked-intake", _request())
	_setup()
	var occluder: Array = fixture.hard_occluder
	for y: int in range(int(occluder[1]),int(occluder[1])+int(occluder[3])):
		for x: int in range(int(occluder[0]),int(occluder[0])+int(occluder[2])):
			world.emit_disc(x,y,0,1)
	_expect_refusal("hard-terrain-occlusion", _request())
	_setup()
	var actor: Dictionary = frame.actors[0]
	actor.position = Vector2(1010.5,100.5)
	actor.parts[0].position = actor.position
	actor.owner_origin = Vector2(1002.5,100.5)
	actor.muzzle = Vector2(1014.5,100.5)
	_masks()
	_expect_refusal("outside-adapter-bounds", _request())
	_setup()
	var paused: Dictionary = _request()
	frame.suspended = true
	_expect_refusal("paused-frame", paused)
	for field: String in ["native_generation","world_instance_id","equipment_epoch","generation","instance_id","policy_hash"]:
		_setup()
		var stale: Dictionary = _request()
		stale[field] = str(stale[field]) + "-old" if field in ["instance_id","policy_hash"] else int(stale[field]) - 1
		_expect_refusal("stale-" + field, stale)
	_setup()
	var cancelled: Dictionary = _request()
	frame.actors[0].active = false
	_expect_refusal("cancelled-control", cancelled)
	_setup()
	var expired: Dictionary = _request()
	frame.actors[0].lease_deadline = int(frame.tick) + 1
	_expect_refusal("expired-control-lease", expired)
	_setup()
	runtime._engine._actors[0].charge = 0.0
	_expect_refusal("insufficient-charge", _request())
	_cool_down()
	var recharged: Dictionary = _request()
	var recharge_receipt: Dictionary = _receipt(_step([recharged]),recharged)
	expect(recharge_receipt.get("accepted",false)
		and is_equal_approx(float(recharge_receipt.get("charge",0)),0.15),
		"actual six-charge-per-second recovery enables one fixed-cost activation")
	_setup()
	var first: Dictionary = _request()
	expect(_receipt(_step([first]),first).get("accepted",false), "resource fixture first effect accepted")
	_expect_refusal("duplicate-consumed-command",first)
	_expect_refusal("cooldown-not-elapsed",_request())
	for bad: Variant in [0,-1,INF,NAN,true,1.5]:
		_setup()
		var malformed: Dictionary = _request()
		malformed.quantity_budget = bad
		_expect_refusal("invalid-quantity-" + str(bad),malformed)
	_setup(3,1,8,1,{"fractional":true})
	var too_small: Dictionary = _request()
	too_small.quantity_budget = 62
	frame.actors[0].quantity_budget = 62
	_expect_refusal("budget-cannot-fit-whole-partial-cell",too_small)
	_setup()
	var precision: Dictionary = _request(true,"alternate")
	var precision_receipt: Dictionary = _receipt(_step([precision]),precision)
	expect(precision_receipt.get("accepted",false) and int(precision_receipt.get("changed_cells",99)) <= 6,
		"35 percent precision pulse bounds accepted effect")
	expect(is_equal_approx(float(precision_receipt.get("charge",0.0)),99.15),
		"precision does not discount fixed U10 charge")
	_setup()
	# Lowest power has a shorter intake reach. Move this explicitly registered
	# variant one cell closer, without changing its source inventory or power.
	var offset := Vector2(fixture.low_power_actor_offset[0], fixture.low_power_actor_offset[1])
	for key: String in ["position", "muzzle", "owner_origin"]:
		frame.actors[0][key] += offset
	frame.actors[0].parts[0].position += offset
	_masks()
	var low_power: Dictionary = _request(true,"use",0.0625)
	var small_receipt: Dictionary = _receipt(_step([low_power]),low_power)
	expect(small_receipt.get("accepted",false) and int(small_receipt.get("changed_cells",99)) == 1,
		"one-cell low-power pulse is exactly metered")
	expect(is_equal_approx(float(small_receipt.get("charge",0.0)),99.15), "low power retains fixed activation charge")


func _budget_and_reconstruction() -> void:
	_setup(24,4)
	var brine_initial: Dictionary = _census()
	for _pulse: int in range(2):
		var brine_command: Dictionary = _request()
		expect(_receipt(_step([brine_command]),brine_command).get("accepted",false),
			"Brine pulse consumes its own finite population budget")
		_cool_down()
	expect(int(_context().brine_cells_remaining) == 0 and int(_context().water_units_remaining) == 32 * 255
		and int(brine_initial.brine) - int(_census().brine) == 32,
		"Brine budget closes separately without consuming Water-unit stock")
	_expect_refusal("exhausted-brine-budget",_request())
	_setup()
	var initial: Dictionary = _census()
	for _pulse: int in range(2):
		var command: Dictionary = _request()
		var receipt: Dictionary = _receipt(_step([command]),command)
		expect(receipt.get("accepted",false) and int(receipt.get("changed_cells",-1)) == 16,
			"each full-power pulse consumes sixteen measured cells")
		_cool_down()
	var spent: Dictionary = _context()
	expect(int(spent.get("water_units_remaining",-1)) == 0
		and int(initial.water) - int(_census().water) == 32 * 255,
		"two full pulses exhaust exactly the 32Q experiment budget")
	_expect_refusal("exhausted-water-budget",_request())
	# A new physical selection/control incarnation is not a new native World.
	for key: String in METERED_FIELDS + ["metered_request_id"]:
		frame.actors[0].erase(key)
	frame.actors[0].usable_index = 0
	frame.actors[0].equipment_epoch += 1
	_step()
	frame.actors[0].usable_index = 9
	frame.actors[0].equipment_epoch += 1
	_step()
	_expect_refusal("reselection-does-not-refill",_request())
	runtime.reset(EPOCH)
	_step()
	_expect_refusal("owner-runtime-reset-does-not-refill-native-world",_request())
	var delayed: Dictionary = _request()
	var old_generation: int = world.get_liquid_policy_session_generation()
	var old_instance: int = world.get_instance_id()
	_setup()
	expect(world.get_instance_id() != old_instance, "fresh reconstruction replaces actual native instance")
	_expect_refusal("old-world-delayed-command",delayed)
	var fresh: Dictionary = _request()
	expect(_receipt(_step([fresh]),fresh).get("accepted",false),
		"fresh World has a fresh finite experiment budget")
	reports.append({"case":"fresh-owner","previous_native_generation":old_generation,
		"current_native_generation":world.get_liquid_policy_session_generation(),
		"previous_world_instance":old_instance,"current_world_instance":world.get_instance_id()})


func _ordinary_u10_compatibility() -> void:
	_setup(16,2,8,1,{"radius":2})
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(80,70),Vector2i(96,80),false)
	var command: Dictionary = _request(false)
	var receipt: Dictionary = _receipt(_step([command]),command)
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(80,70),Vector2i(96,80),false)
	expect(receipt.get("accepted",false) and int(before.counts[16]) > int(after.counts[16]),
		"ordinary v1 U10 retains its existing Oil removal")
	expect(int(receipt.get("changed_cells",0)) > 16, "ordinary U10 is not silently limited to metered profile cap")
	expect(world.get_liquid_solver_policy().maximum_rule_radius == 2,
		"ordinary Current policy keeps original radius two")
	expect(is_equal_approx(float(receipt.get("charge",0.0)),99.15), "ordinary U10 charge unchanged")
	_setup(3,1,8,1,{"fractional":true,"radius":2})
	var quantity_before: Dictionary = _census()
	command = _request(false)
	receipt = _receipt(_step([command]),command)
	var quantity_after: Dictionary = _census()
	expect(receipt.get("accepted",false)
		and int(quantity_before.water)-int(quantity_after.water) == int(receipt.get("changed_cells",-1))*63,
		"ordinary FreeMass fractional removal stays exact and unchanged")


func _install_material_probe() -> MaterialWorkProbe:
	var probe := MaterialWorkProbe.new()
	runtime._engine.metered = probe
	_step()
	return probe


func _material_work_case(label: String, probe: MaterialWorkProbe, prior_reads: int = 0) -> Dictionary:
	probe.clear_trace()
	var request: Dictionary = _request()
	# Synchronize the real physical frame before the deliberate direct-execute
	# seam. Its ordinary observation work is recorded separately, then replaced
	# by the explicitly synthetic prior-consumption value below.
	_step()
	var frame_sync_reads: int = runtime._engine.read_count_last
	var initial: Dictionary = _census()
	var context_before: Dictionary = _context()
	var hash_before: String = world.get_physical_state_hash()
	runtime._engine.active_world = world
	runtime._engine.read_count_last = prior_reads
	runtime._engine.write_count_last = 0
	runtime._engine.metered_outcome = {}
	runtime._engine._execute(request,world)
	var receipt: Dictionary = _receipt(runtime.snapshot(),request)
	var outcome: Dictionary = receipt.get("metered_drain",{})
	var command_reads: int = runtime._engine.read_count_last - prior_reads
	# Independent forwarded inspections plus the documented conservative
	# reservation contract. Do not read the helper's accounting constants here.
	var derived_helper_units: int = probe.preflight_inspections + probe.post_inspections \
		+ 10 * probe.apply_refreshes + 6 * probe.pre_identity_checks + 8 * probe.post_identity_checks
	var source_units: int = command_reads - int(outcome.get("reads_used",0))
	expect(outcome.get("read_accounting") == "material-work-units-v1",
		label + " explicitly identifies the narrower material-work contract")
	expect(int(outcome.get("reads_used",-1)) == derived_helper_units,
		label + " forwarded inspection events and identity reservations reconstruct helper units")
	expect(probe.preflight_inspections == probe._preflight_points.size(),
		label + " shared preflight coordinates are inspected once through the cache")
	expect(int(outcome.get("writes_attempted",-1)) == probe.erase_attempts
		and probe.post_inspections == probe.erase_attempts,
		label + " every attempted real erase has a fresh forwarded native post-read")
	if not probe.first_write.is_empty():
		var first: Dictionary = probe.first_write
		expect(first.terminal and first.status == "fault" and first.reason == "interrupted_execution"
			and first.preflight_complete and int(first.writes_attempted) == 1,
			label + " terminal uncertainty is latched before the first real writer")
		expect(int(first.material_work_units_before_write) == 10 + probe.preflight_inspections + 6
			and int(first.observed_pre_identity_checks) == 1,
			label + " first writer follows complete unique preflight and reserved identity validation")
		expect(int(first.reads_available) - int(first.material_work_units_before_write)
			>= int(first.planned_targets) + 8 and int(first.writes_available) >= int(first.planned_targets),
			label + " first writer has reserved every target post-read, final identity and erase capacity")
		for key: String in ["water_units_remaining","water_units_removed","brine_cells_remaining","brine_cells_removed"]:
			expect(first.stock_before.get(key) == context_before.get(key),
				label + " first writer has not prematurely debited " + key)
	for copied: Dictionary in probe.post_readbacks:
		expect(copied.get("ok",false) and copied.get("material") == 0,
			label + " forwarded post-read sees actual Empty, independently of cached preflight")
	var before_observation: int = runtime._engine.read_count_last
	var observation_attempted: bool = not runtime.metered_terminal()
	if observation_attempted:
		runtime._engine._observe_local(world)
	var observation_units: int = runtime._engine.read_count_last - before_observation
	runtime._engine.active_world = null
	var final: Dictionary = _census()
	var row: Dictionary = {"case":"material-work-"+label,
		"scope":"real native direct _execute; fixture-seeded prior material-work counter; queue coverage is separate",
		"prior_material_work_units":prior_reads,"prior_units_origin":"fixture seed, not claimed executed native calls",
		"frame_sync_material_work_units":frame_sync_reads,"command_material_work_units":command_reads,
		"source_clearance_units_from_parent_counter":source_units,"derived_helper_units":derived_helper_units,
		"identity_reservations":{"initial":10,"pre_write":6,"post_write":8},
		"optional_observation_attempted":observation_attempted,"optional_observation_units":observation_units,
		"optional_patch_empty":runtime._engine._actors[0].get("cell_patch",{}).is_empty(),
		"final_shared_material_work_units":runtime._engine.read_count_last,
		"final_shared_writes":runtime._engine.write_count_last,
		"initial":initial,"final":final,"physical_hash_before":hash_before,
		"physical_hash_after":world.get_physical_state_hash(),"receipt":receipt,
		"context_before":context_before,"context_after":_context(),"trace":probe.trace(),"request":request}
	expect(runtime._engine.read_count_last <= int(fixture.equipment.maximum_reads_per_step)
		and runtime._engine.write_count_last <= int(fixture.equipment.maximum_writes_per_step),
		label + " preserves the original ordinary U10 shared step limits")
	if not receipt.get("accepted",false) and not runtime.metered_terminal():
		expect(probe.erase_attempts == 0 and initial == final
			and row.physical_hash_after == hash_before,
			label + " ordinary refusal attempts no destructive write and preserves whole native state")
	reports.append(row)
	return row


func _material_work_accounting() -> void:
	_setup()
	var probe: MaterialWorkProbe = _install_material_probe()
	var baseline: Dictionary = _material_work_case("full-q255",probe)
	expect(baseline.receipt.accepted and probe.erase_attempts == 16
		and int(baseline.initial.water) - int(baseline.final.water) == 16 * 255,
		"accounting baseline performs the real registered sixteen-target Q255 pulse")
	expect(probe.pre_identity_checks == 1 and probe.post_identity_checks == 1
		and probe.apply_refreshes == 1 and probe.lifecycle_refreshes == 1,
		"accounting separates effect identity work from frame lifecycle refresh")
	expect(int(baseline.optional_observation_units) == 81 and not baseline.optional_patch_empty,
		"ordinary optional material observation retains its separate 81-cell charge")
	var exact_prior: int = int(fixture.equipment.maximum_reads_per_step) \
		- int(baseline.source_clearance_units_from_parent_counter) - int(baseline.derived_helper_units)
	expect(exact_prior > 0,"measured fixture leaves room for an adversarial prior-consumption seed")
	for extra: int in [0,1]:
		_setup()
		probe = _install_material_probe()
		var row: Dictionary = _material_work_case("exact-capacity" if extra == 0 else "one-unit-short",
			probe,exact_prior+extra)
		row["boundary_derived_from"] = "material-work-full-q255"
		row["exact_fit_prior_material_units"] = exact_prior
		if extra == 0:
			expect(row.receipt.accepted and probe.erase_attempts == 16
				and int(row.final_shared_material_work_units) == int(fixture.equipment.maximum_reads_per_step),
				"exact shared material-work capacity completes all sixteen erases and post-readbacks")
		else:
			expect(not row.receipt.accepted and row.receipt.reason == "read_capacity"
				and probe.erase_attempts == 0 and probe.first_write.is_empty()
				and probe.pre_identity_checks == 0 and not runtime.metered_terminal(),
				"one missing reserved material-work unit refuses before any identity-to-write transition")
			expect(row.initial == row.final and row.physical_hash_before == row.physical_hash_after
				and int(row.context_after.water_units_removed) == 0
				and is_equal_approx(float(row.receipt.charge),100.0)
				and is_zero_approx(float(row.receipt.cooldown)),
				"near-capacity refusal preserves full census/hash, stock, charge and cooldown")
		expect(int(row.optional_observation_units) == 0 and row.optional_patch_empty,
			"optional 81-cell observation skips when the remaining shared allowance is insufficient")
	_setup(3,1,8,1,{"fractional":true})
	probe = _install_material_probe()
	var partial: Dictionary = _material_work_case("fractional-freemass",probe)
	expect(partial.receipt.accepted and probe.erase_attempts == 16
		and int(partial.initial.water) - int(partial.final.water) == 16 * int(fixture.partial_freemass_units)
		and int(partial.receipt.metered_drain.water_units_removed) == 16 * int(fixture.partial_freemass_units),
		"instrumented FreeMass pulse meters actual fractional native units")
	_setup(3,4,8,1,{"empty":true})
	probe = _install_material_probe()
	var empty: Dictionary = _material_work_case("empty-intake",probe)
	expect(empty.receipt.reason == "empty_intake" and probe.preflight_inspections > 0
		and probe.pre_identity_checks == 0 and probe.post_identity_checks == 0,
		"empty-intake accounting contains inspection work without write identity or post-readback work")
	_setup()
	probe = _install_material_probe()
	# Aim diagonally into the unchanged liquid rectangle. The Wall is one of
	# the two side cells touched at the first grid corner, beyond the muzzle;
	# the diagonal cell itself stays Empty and source clearance remains valid.
	var offset := Vector2(0.0,-12.0)
	for key: String in ["position","muzzle","owner_origin"]:
		frame.actors[0][key] += offset
	frame.actors[0].parts[0].position += offset
	frame.actors[0].direction = Vector2.ONE.normalized()
	_masks()
	var corner := Vector2i(105,88)
	world.emit_disc(corner.x,corner.y,0,1)
	expect(bridge.inspect_cell(world,corner).material == 1
		and bridge.inspect_cell(world,Vector2i(105,89)).material == 0
		and bridge.inspect_cell(world,Vector2i(116,100)).material == 3,
		"diagonal fixture has an actual hard side-cell blocker and unobstructed diagonal/target witnesses")
	var blocked: Dictionary = _material_work_case("supercover-corner",probe)
	expect(blocked.receipt.reason == "wrong_material" and probe._preflight_points.has(corner)
		and not probe._preflight_points.has(Vector2i(105,89)) and probe.erase_attempts == 0,
		"supercover inspects and refuses the hard corner side cell before reaching the diagonal")
	blocked["corner_blocker"] = [corner.x,corner.y]
	_setup()
	probe = _install_material_probe()
	for _pulse: int in range(2):
		probe.clear_trace()
		var request: Dictionary = _request()
		expect(_receipt(_step([request]),request).get("accepted",false),
			"instrumented exhausted-stock preparation performs real accepted removal")
		_cool_down()
	var exhausted: Dictionary = _material_work_case("exhausted-stock",probe)
	expect(exhausted.receipt.reason == "budget_exhausted" and probe.preflight_inspections == 0
		and probe.erase_attempts == 0 and int(exhausted.context_before.water_units_remaining) == 0,
		"exhausted stock refuses after metadata admission without cell inspections or erases")
	_setup()
	probe = _install_material_probe()
	probe.corrupt_post_copy = true
	var fault: Dictionary = _material_work_case("injected-post-copy-fault",probe)
	expect(fault.receipt.metered_drain.status == "fault"
		and fault.receipt.reason == "post_readback_mismatch"
		and not fault.receipt.metered_drain.quantity_complete
		and int(fault.receipt.metered_drain.sink_debit) == 0
		and int(fault.initial.water) - int(fault.final.water) == 255
		and probe.erase_attempts == 1 and probe.post_inspections == 1 and runtime.metered_terminal(),
		"corrupted copied post-read retains unknown actual first-erase quantity and terminal quarantine")
	expect(not fault.optional_observation_attempted and int(fault.optional_observation_units) == 0,
		"faulted direct owner follows the caller's terminal boundary before optional observation")
	var attempted: int = probe.erase_attempts
	_step([fault.request])
	expect(probe.erase_attempts == attempted and runtime.metered_terminal()
		and world.get_physical_state_hash() == fault.physical_hash_after and _census() == fault.final,
		"real step refuses retry of a possibly applied instrumented command")
	fault["trace_after_blocked_retry"] = probe.trace()


func _capacity_and_fault_discrimination() -> void:
	for channel: String in ["reads", "writes"]:
		_setup()
		var request: Dictionary = _request()
		_step()
		var before: Dictionary = _census()
		var physical: String = world.get_physical_state_hash()
		# Deliberately exhaust the existing shared per-step allowance before
		# the real operation executes. This fixture-only seam bypasses queue
		# admission, not native preflight or native reads/writes.
		runtime._engine.active_world = world
		runtime._engine.read_count_last = 1984 if channel == "reads" else 0
		runtime._engine.write_count_last = 120 if channel == "writes" else 0
		runtime._engine._execute(request,world)
		runtime._engine.active_world = null
		var receipt: Dictionary = _receipt(runtime.snapshot(),request)
		expect(not receipt.get("accepted",true) and receipt.get("reason") == ("read_capacity" if channel == "reads" else "write_capacity"),
			"exhausted " + channel + " capacity refuses before the real native writer")
		expect(_census() == before and world.get_physical_state_hash() == physical,
			"capacity refusal preserves complete actual World")
		expect(int(_context().water_units_removed) == 0 and is_equal_approx(float(receipt.get("charge",0)),100.0),
			"capacity refusal consumes no effect stock or activation charge")
		expect(runtime.snapshot().read_count_last <= 2048 and runtime.snapshot().write_count_last <= 128,
			"bounded transaction never exceeds general U10 step allowances")
		reports.append({"case":"capacity-"+channel,"scope":"fixture-exhausted shared runtime allowance",
			"receipt":receipt,"initial":before,"final":_census()})
	_setup()
	runtime._engine.metered = InvalidPreflightRead.new()
	_step()
	_expect_refusal("injected-invalid-preflight-readback",_request(),["invalid_readback"])
	expect(not runtime.metered_terminal(),"incomplete nonmutating preflight is ordinary refusal")
	_setup()
	runtime._engine.metered = FractionalWholeCellRead.new()
	_step()
	_expect_refusal("injected-fractional-IN-readback",_request(),["fractional_whole_cell_input"])
	reports.append({"case":"fractional-IN-guard","scope":"deliberately corrupted copied quantity; native source remains whole",
		"native_cell":bridge.inspect_cell(world,Vector2i(116,100))})
	for injection: String in ["skip-second-erase","invalid-post-read"]:
		_setup()
		runtime._engine.metered = InterruptedErase.new() if injection == "skip-second-erase" else InvalidPostRead.new()
		_step()
		var before: Dictionary = _census()
		var request: Dictionary = _request()
		var receipt: Dictionary = _receipt(_step([request]),request)
		var actual: Dictionary = _census()
		var outcome: Dictionary = receipt.get("metered_drain",{})
		expect(not receipt.get("accepted",true) and outcome.get("status") == "fault"
			and outcome.get("reason") == "post_readback_mismatch",
			"unexpected post-mutation failure is a fault, never a clean refusal")
		expect(int(before.water) - int(actual.water) == 255 and runtime.metered_terminal(),
			"actual first native erase remains visible and owner becomes terminal")
		var verified: int = 255 if injection == "skip-second-erase" else 0
		expect(int(outcome.get("water_units_removed",-1)) == verified
			and int(outcome.get("sink_debit",-1)) == verified and outcome.get("quantity_complete") == false,
			"fault preserves verified partial sink and explicitly incomplete quantity")
		expect(outcome.get("writes_attempted") == (2 if injection == "skip-second-erase" else 1),
			"execution stops immediately at first unverified write")
		expect(is_equal_approx(float(receipt.get("charge",0)),100.0) and float(receipt.get("cooldown",-1)) == 0.0,
			"unexpected fault does not fabricate accepted activation charge")
		var frozen: String = world.get_physical_state_hash()
		_step([request])
		expect(world.get_physical_state_hash() == frozen and _census() == actual,
			"potentially applied command is never retried")
		runtime.reset(EPOCH)
		_step()
		expect(runtime.metered_terminal(),"equipment/session runtime reset cannot clear terminal native owner")
		reports.append({"case":injection,"scope":"bounded helper fault injection with real native first erase",
			"initial":before,"final":actual,"receipt":receipt,"terminal":runtime.metered_terminal()})
		# Explicit native reconstruction creates a new generation on the same
		# adapter object; no liquid repaint/velocity rollback is attempted.
		expect(world.diagnostic_reset({"workers":1}),"explicit clear reconstructs failed owner")
		runtime.refresh_metered_owner(world)
		expect(not runtime.metered_terminal(),"fresh native generation retires terminal fault")


func _native_persistence_and_failure() -> void:
	_setup()
	var command: Dictionary = _request()
	expect(_receipt(_step([command]),command).get("accepted",false),"persistence fixture removes actual Water")
	var quantity: Dictionary = _census()
	var saved: PackedByteArray = bridge.export_physical_state(world)
	var old_generation: int = world.get_liquid_policy_session_generation()
	expect(bridge.import_physical_state(world,saved),"native saved state restores through existing adapter")
	expect(world.get_liquid_policy_session_generation() != old_generation
		and world.get_applied_liquid_construction_receipt().is_empty(),
		"import retires original native construction identity")
	_masks()
	_cool_down()
	expect(_census() == quantity,"native save/restore retains actually removed quantity")
	expect(not _context().available and _context().reason == "fresh_inertial_construction_required",
		"restored IN state without genuine initial construction receipt is unavailable")
	# Physical-state import does not reinstall the body's transient-mask region.
	# The normal source-owner check can therefore refuse before profile preflight.
	_expect_refusal("restored-IN-needs-fresh-construction",_request(),
		["fresh_inertial_construction_required","source_blocked"])
	# Deliberately use the production capacity setting before construction.
	# Diagnostic reset would replace it with its own larger capacity, so this
	# control uses the public full-domain Water observation and physical hash.
	var configured: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity",null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1)
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",configured)
	expect(bridge.build_world(world,PackedInt32Array([20,20,2,1,1,160,20,1,1,2,116,94,24,13,3])),
		"real low-capacity native source constructs")
	runtime = Runtime.new()
	sequence = 0
	frame = {"version":1,"run_id":"failed-native-drain-fixture","epoch":EPOCH,"tick":0,
		"suspended":false,"actors":[_actor()],"devices":[]}
	selected_material = 3
	_masks()
	_step()
	command = _request()
	bridge.queue_explosion(world,20,20,1)
	expect(not world.simulation_tick() and world.has_failed(),"actual active-core exhaustion quarantines native tick")
	var failed_hash: String = world.get_physical_state_hash()
	var failed_quantity: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))
	var failed_receipt: Dictionary = _receipt(_step([command]),command)
	expect(not failed_receipt.get("accepted",true) and failed_receipt.get("reason") == "world_unavailable"
		and failed_receipt.get("metered_drain",{}).get("status") == "refused",
		"real failed native World explicitly refuses metered activation")
	expect(world.get_physical_state_hash() == failed_hash
		and world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)) == failed_quantity,
		"failed-owner refusal preserves available native content and quantity evidence")
	expect(int(failed_receipt.metered_drain.water_units_removed) == 0
		and is_equal_approx(float(failed_receipt.charge),100.0),"failed native refusal consumes no sink or charge")
	reports.append({"case":"actual-native-capacity-failure","attempted_tick":world.get_attempted_tick_index(),
		"completed_tick":world.get_tick_index(),"native_error":world.get_last_tick_error(),
		"receipt":failed_receipt,"water_observation":failed_quantity,"physical_hash":failed_hash})


func _fixture_worker() -> CyberSimulationWorker:
	_setup()
	var worker := Worker.new()
	worker._world = world
	worker.set_physical_actor_epoch(EPOCH)
	# This deterministic fixture has no worker thread. It becomes the only
	# native owner and explicitly enables the ordinary running admission bit.
	worker._running = true
	runtime = worker._physical_usables
	frame.tick += 1
	var admitted: Dictionary = worker.set_physical_usable_state(frame,[],_states())
	expect(admitted.get("reason","").is_empty(),"empty worker frame seeds actual owner identity")
	worker._consume_physical_usables([],EPOCH,true,frame)
	return worker


func _extract(worker: CyberSimulationWorker) -> Array:
	var extracted: Array = worker._pending_physical_usables.duplicate(true)
	worker._pending_physical_usables.clear()
	return extracted


func _worker_ownership() -> void:
	var worker: CyberSimulationWorker = _fixture_worker()
	var request: Dictionary = _request()
	var first: Dictionary = _census()
	var accepted: Dictionary = worker.set_physical_usable_state(frame,[request],_states())
	expect(accepted.get("status") == "queued" and accepted.get("queued") == 1,
		"actual running worker mutex admits metered packet")
	var extracted: Array = _extract(worker)
	var inflight: Dictionary = worker.set_physical_usable_state(frame,[request],_states())
	expect(inflight.get("reason") == "actor_inflight","extracted request still owns in-flight activation slot")
	worker._consume_physical_usables(extracted,EPOCH,true,frame)
	var receipt: Dictionary = _receipt(runtime.snapshot(),request)
	expect(receipt.get("accepted",false) and int(first.water) - int(_census().water) == int(receipt.metered_drain.water_units_removed),
		"accepted queued packet produces exact actual native sink")
	expect(worker._physical_usable_inflight.is_empty(),"accepted operation releases in-flight reservation exactly once")
	worker._publish_snapshot(0.0,false,Worker.DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC,true,_states(),EPOCH)
	var publication: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	expect(publication != null and publication.physical_usables.receipts == runtime.snapshot().receipts,
		"existing immutable publication contains exact host-local outcome")
	var retained: Dictionary = publication.physical_usables.duplicate(true)
	var physical: String = world.get_physical_state_hash()
	worker._consume_physical_usables(extracted,EPOCH,true,frame)
	expect(world.get_physical_state_hash() == physical and publication.physical_usables == retained,
		"duplicated extracted delivery neither replays sink nor changes published outcome")
	reports.append({"case":"actual-worker-admission","initial":first,"final":_census(),"receipt":receipt})
	worker._running = false
	worker.stop_worker()
	for cancellation: String in ["cancel","release","pause","stop","reset","retire"]:
		worker = _fixture_worker()
		request = _request()
		var initial: Dictionary = _census()
		var exact: String = world.get_physical_state_hash()
		expect(worker.set_physical_usable_state(frame,[request],_states()).get("status") == "queued",
			"cancellation fixture queued real v2 request")
		extracted = _extract(worker)
		var captured: Dictionary = frame.duplicate(true)
		match cancellation:
			"cancel":
				expect(worker.cancel_physical_actor_effects(EPOCH,0),"focus/blocking-style cancellation accepted")
			"release":
				frame.tick += 1
				frame.actors[0].metered_request_id = ""
				worker.set_physical_usable_state(frame,[],_states())
			"pause":
				worker.set_frame_state(0.0,false,true,Vector2i.ZERO,Vector2i.ZERO,Vector2i(320,180),0,0,false,false,false)
			"stop":
				worker._running = false
				worker.stop_worker()
			"reset":
				worker.queue_reset(Vector2(100.5,100.5),false,false)
			"retire":
				worker.set_physical_actor_epoch(EPOCH+1)
		worker._consume_physical_usables(extracted,EPOCH,true,captured)
		expect(world.get_physical_state_hash() == exact and _census() == initial,
			cancellation + " cancels already-extracted uncommitted native effect")
		expect(int(_context().get("water_units_removed",0)) == 0,
			cancellation + " consumes no experimental stock")
		worker._running = false
		worker.stop_worker()
		reports.append({"case":"worker-cancel-"+cancellation,"initial":initial,"final":_census(),
			"physical_hash":exact,"completed_tick":world.get_tick_index()})
	worker = _fixture_worker()
	request = _request()
	worker._running = false
	var stopped: Dictionary = worker.set_physical_usable_state(frame,[request],_states())
	expect(stopped.get("status") == "refused" and stopped.get("reason") == "stopped",
		"stopped owner explicitly refuses new metered packets")
	worker.stop_worker()
	# Fault branch exercises the production worker's quarantine and failure
	# snapshot using a real partial native erase, with deliberate test injection.
	worker = _fixture_worker()
	runtime._engine.metered = InterruptedErase.new()
	worker._consume_physical_usables([],EPOCH,true,frame)
	request = _request()
	worker._publish_snapshot(0.0,false,Worker.DEFAULT_RENDER_SNAPSHOT_INTERVAL_USEC,true,_states(),EPOCH)
	var before_fault: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	var prior_cells: PackedByteArray = before_fault.render_patch_cells.duplicate()
	worker.set_physical_usable_state(frame,[request],_states())
	worker._consume_physical_usables(_extract(worker),EPOCH,true,frame)
	expect(worker._simulation_failed and worker._paused and not worker._experimental_owner_fault.is_empty(),
		"worker latches partial metered fault despite healthy native flag")
	expect(not world.has_failed() and runtime.metered_terminal(),
		"host quarantine is distinct from native tick-health flag")
	worker._publish_failure_snapshot()
	var failed: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	expect(failed.simulation_failed and failed.paused and failed.render_patch_cells == prior_cells
		and failed.rigid_body_results.is_empty(),"failure publication retains last valid cells and no body impulses")
	expect(failed.physical_usables.metered_terminal
		and failed.physical_usables.metered_fault.water_units_removed == 255,
		"failure publication exposes actual verified partial sink separately")
	expect(not worker.queue_emit_disc(120,100,0,3),"terminal published owner rejects ordinary material emissions")
	physical = world.get_physical_state_hash()
	worker._running = false
	worker.stop_worker()
	var retained_fault: Dictionary = worker._experimental_owner_fault.duplicate(true)
	# Put the legacy lab dispatch in its active state so release/floor work
	# would reach its native mutation path without the terminal-owner fence.
	worker._lab_active = true
	var legacy_command := {"release":0,"floor":1,"scenario_capture":true}
	worker.queue_lab(legacy_command)
	expect(worker.start_worker(Vector2(100.5,100.5)) == OK,
		"terminal owner thread can restart only to wait for explicit reconstruction")
	await create_timer(0.06).timeout
	worker.stop_worker()
	# Authoritative inspection resumes only after the exclusive worker drains.
	expect(world.get_physical_state_hash() == physical and worker.take_latest_snapshot(0).simulation_failed
		and world.get_tick_index() == 0,
		"terminal restart neither ticks, mutates nor republishes partial authority")
	expect(worker._lab_status.contains("terminal") and worker._lab_inputs.is_empty() and worker._lab_floor == 0
		and worker._experimental_owner_fault == retained_fault,
		"queued legacy release/floor/capture refuses before touching terminal authority or evidence")
	reports.append({"case":"terminal-owner-rejects-legacy-lab","scope":"real queued worker dispatch after partial-fault injection",
		"command":legacy_command,"reason":worker._lab_status,"physical_hash_before":physical,
		"physical_hash_after":world.get_physical_state_hash(),"fault_evidence_unchanged":worker._experimental_owner_fault == retained_fault})
	reports.append({"case":"worker-partial-fault","scope":"test-injected skipped second native erase",
		"fault":failed.physical_usables.metered_fault,"physical_hash":physical,"native_failed":world.has_failed()})
	var retired_generation: int = world.get_liquid_policy_session_generation()
	worker.queue_reset(Vector2(100.5,100.5),false,false)
	expect(worker.start_worker(Vector2(100.5,100.5)) == OK,
		"existing reset may restart terminal owner for explicit reconstruction")
	var recovery_deadline: int = Time.get_ticks_msec() + Watchdogs.milliseconds("operation_seconds")
	while worker.has_failed() and Time.get_ticks_msec() < recovery_deadline:
		await process_frame
	worker.stop_worker()
	# The owner has joined; read actual replacement identity only now.
	expect(not worker.has_failed() and not runtime.metered_terminal()
		and world.get_liquid_policy_session_generation() != retired_generation
		and worker._experimental_owner_fault.is_empty(),
		"actual worker reset replaces native generation and retires terminal evidence")
	frame.run_id = "metered-fresh-owner-after-fault"
	frame.tick += 1
	frame.actors[0].generation += 1
	frame.actors[0].equipment_epoch += 1
	frame.actors[0].instance_id = "reconstructed-metered-equipment"
	for key: String in METERED_FIELDS + ["metered_request_id"]:
		frame.actors[0].erase(key)
	_masks()
	worker._running = true # Nonthreaded exclusive fixture ownership resumes.
	expect(worker.set_physical_usable_state(frame,[],_states()).get("reason","").is_empty(),
		"new physical control generation can publish after explicit native recovery")
	worker._consume_physical_usables([],EPOCH,true,frame)
	var fresh_context: Dictionary = _context()
	expect(fresh_context.get("available",false) and int(fresh_context.get("water_units_remaining",-1)) == 32 * 255
		and int(fresh_context.get("water_units_removed",-1)) == 0,
		"only actual worker reconstruction restores finite experiment stock")
	_request() # Select the profile using the new authoritative owner context.
	var restored_hash: String = world.get_physical_state_hash()
	var old_admission: Dictionary = worker.set_physical_usable_state(frame,[request],_states())
	expect(old_admission.get("status") == "refused" and not str(old_admission.get("reason","")).is_empty()
		and worker._pending_physical_usables.is_empty() and world.get_physical_state_hash() == restored_hash,
		"old potentially-applied request cannot enter reconstructed native owner")
	worker._running = false
	worker.stop_worker()
	reports.append({"case":"actual-worker-terminal-reconstruction","previous_native_generation":retired_generation,
		"native_generation":world.get_liquid_policy_session_generation(),"context":fresh_context,
		"old_command_admission":old_admission,"physical_hash":restored_hash,"completed_tick":world.get_tick_index()})


func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false,"actual source-matched native extension required")
		quit(1)
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	var fixture_text: String = FileAccess.get_file_as_string("res://tests/fixtures/in-tools-metered-drain.v1.json")
	var parsed_fixture: Variant = JSON.parse_string(fixture_text)
	expect(parsed_fixture is Dictionary, "versioned executable fixture parses")
	if not parsed_fixture is Dictionary:
		quit(1)
		return
	fixture = parsed_fixture
	fixture_digest = fixture_text.sha256_text()
	expect(fixture.schema == "in-tools-metered-drain-physical-fixture-v1" and fixture.profile == PROFILE
		and fixture.version == 1 and fixture.initial_liquid_cells == 312,
		"fixture schema/profile and exact source raster are versioned")
	var checked: Dictionary = Contract.parse(FileAccess.get_file_as_string(
		"res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"))
	expect(checked.get("ok",false),"protected reference transport profile parses")
	if not checked.get("ok",false):
		quit(1)
		return
	profile = checked.transport.packed
	var definition: Dictionary = Catalog.entry(9)
	expect(definition.id == &"liquid_drain" and definition.range == 29 and definition.radius == 4
		and is_equal_approx(float(definition.cost),0.85) and is_equal_approx(float(definition.cooldown),0.10),
		"live U10 catalogue contract preserved")
	_quantities_and_workers()
	_refusals_and_resources()
	_budget_and_reconstruction()
	_ordinary_u10_compatibility()
	_material_work_accounting()
	_capacity_and_fault_discrimination()
	_native_persistence_and_failure()
	await _worker_ownership()
	var performance_rows: Array = []
	for report: Dictionary in reports:
		if report.get("case") == "quantity-and-shutoff" and report.get("material") == 3 \
			and report.get("bits") == 8 and not bool(report.get("fractional", false)) \
			and int(report.get("family", 0)) in [1, 4]:
			performance_rows.append({
				"family": int(report.family),
				"configured_workers": int(report.configured_workers),
				"command_owner_usec": int(report.command_owner_usec),
				"native_tick_ms": report.native_tick_ms,
				"changed_cells": int(report.command.get("changed_cells", 0)),
			})
	print("IN_TOOLS_361_DRAIN_PERF: " + JSON.stringify({
		"schema":"in-tools-361-drain-performance-v1",
		"comparison":"same U10 geometry/power, full-cell Water, FreeMass family=1 versus IN family=4",
		"rows":performance_rows,
		"claim":"measurement only; single-command owner timing plus eight post-shutoff native ticks; no hard performance threshold"
	}))
	var packet: String = JSON.stringify({"schema":"in-tools-metered-drain-native-host-v1",
		"fixture_id":fixture.id,"fixture_sha256":fixture_digest,
		"scope":"real native World and physical owner; headless; no physical input/graphical qualification",
		"checks":checks,"failures":failures,"rows":reports,"commands":commands},"\t")
	var packet_file := FileAccess.open("user://metered-drain-native-host.json",FileAccess.WRITE)
	expect(packet_file != null,"qualification packet is writable")
	if packet_file != null:
		packet_file.store_string(packet + "\n")
		packet_file.close()
		print("METERED_DRAIN_PACKET path=",ProjectSettings.globalize_path("user://metered-drain-native-host.json"),
			" sha256=",(packet + "\n").sha256_text()," rows=",reports.size())
	print("METERED_DRAIN_RESULT checks=%d failures=%d native=executed" % [checks,failures])
	quit(1 if failures else 0)
