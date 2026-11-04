extends SceneTree

# Actual native owner context -> physical runtime snapshot -> real Rapier
# equipment readback. Adversarial copies are labelled controls, not native
# mutation or physical-device evidence. Main's genuine refusal/debited-ledger
# path is separately exercised by test_physical_metered_desktop.gd.
const Retention = preload("res://tests/support/physical_retention_readback.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Runtime = preload("res://scripts/physical_usable_runtime.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const DT: float = 1.0 / 60.0
const LEDGER_FIELDS: Array[String] = ["water_units_initial", "water_units_remaining", "water_units_removed",
	"brine_cells_initial", "brine_cells_remaining", "brine_cells_removed"]
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession
var runtime: CyberPhysicalUsableRuntime
var world: Object
var bridge: Object
var scenario: RefCounted
var epoch: int = 2000
var publication_serial: int = 0
var publication: Dictionary = {}
var expected: Dictionary = {}
var reports: Array = []
var native_context_executed: bool = false


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_RETENTION_READBACK: " + message)
	return value


func view() -> Dictionary:
	return session._view(0, false)


func current() -> Dictionary:
	return {"publication_serial": publication_serial, "frame": session.equipment_frame(),
		"publication": publication.duplicate(true), "view": view()}


func next_publication() -> Dictionary:
	publication_serial += 1
	var result: Dictionary = runtime.step(DT, world, session.equipment_frame(), []).duplicate(true)
	if not result.get("actors", []).is_empty() and result.actors[0].get("metered_drain") is Dictionary:
		native_context_executed = true
	return result


func deliver(value: Dictionary) -> void:
	publication = value.duplicate(true)
	session.accept_equipment_feedback(publication)


func fresh(hydrate: bool = true) -> bool:
	if session != null:
		session.close()
		session.free()
	epoch += 1
	session = Session.new()
	owner.add_child(session)
	if not expect(session.configure([
		{"model": &"gyrocrate", "producer": &"policy", "position": Vector2(100, 100), "usable_index": 4}],
		owner.get_world_2d().space, epoch), "actual ordinary physical equipment configures"):
		return false
	for body: RigidBody2D in session.bodies(): body.gravity_scale = 0.0
	runtime = Runtime.new()
	publication_serial = 0
	publication = {}
	var frame: Dictionary = session.equipment_frame()
	var row: Dictionary = frame.actors[0]
	var policy: Dictionary = world.get_liquid_solver_policy()
	var water: Dictionary = world.get_water_experiment_policy()
	expected = {"run_id": session.run_id, "epoch": session.epoch, "actor_id": 0,
		"instance_id": row.instance_id, "equipment_epoch": row.equipment_epoch,
		"usable_index": row.usable_index, "body_id": row.body_id,
		"native_generation": int(world.get_liquid_policy_session_generation()), "policy_hash": policy.policy_hash,
		"minimum_publication_serial": 1, "minimum_control_generation": int(row.generation),
		"completed_tick": int(world.get_tick_index()),
		"context": {"mass_bits": water.mass_bits, "maximum": water.maximum,
			"coherence_ticks": water.coherence_ticks, "allowed_materials": [3, 24],
			"initial_construction_receipt_available": true},
		"ledgers": {"water_units_initial": 32 * int(water.maximum), "water_units_remaining": 32 * int(water.maximum),
			"water_units_removed": 0, "brine_cells_initial": 32, "brine_cells_remaining": 32, "brine_cells_removed": 0}}
	if hydrate:
		deliver(next_publication())
		var ready: Dictionary = Retention.evaluate(expected, current())
		if not expect(ready.ready, "actual native/runtime/session pipeline supplies matching owner context: " + ready.reason):
			return false
		expected.world_instance_id = ready.world_instance_id
	return true


func _hydration_without_refusal() -> void:
	if not fresh(false): return
	var early: Dictionary = view().equipment
	var early_bytes: PackedByteArray = var_to_bytes(early)
	var missing: Dictionary = Retention.evaluate(expected, current())
	expect(not missing.ready, "missing worker readback cannot satisfy readiness")
	var native: Dictionary = next_publication()
	publication = native.duplicate(true)
	var undelivered: Dictionary = Retention.evaluate(expected, current())
	expect(not undelivered.ready, "a valid native publication alone cannot satisfy undelivered main equipment")
	deliver(native)
	var ready: Dictionary = Retention.evaluate(expected, current())
	expect(ready.ready and ready.world_instance_id == int(world.get_instance_id()),
		"ordinary no-refusal hydration binds actual native World identity")
	expect(view().equipment.profile == "" and not session.equipment_frame().actors[0].has("profile"),
		"receiving native context does not opt ordinary equipment into metered execution")
	expect(var_to_bytes(early) == early_bytes and early.get("metered_drain", {}).is_empty(),
		"retained early observation remains byte-exact and empty after later hydration")
	var first: Dictionary = view().equipment
	var first_bytes: PackedByteArray = var_to_bytes(first)
	var retained_publication: Dictionary = publication.duplicate(true)
	var retained_publication_bytes: PackedByteArray = var_to_bytes(retained_publication)
	expected.world_instance_id = ready.world_instance_id
	expected.minimum_publication_serial = publication_serial + 1
	deliver(next_publication())
	var later: Dictionary = view().equipment
	expect(Retention.evaluate(expected, current()).ready
		and var_to_bytes(first.metered_drain) == var_to_bytes(later.metered_drain)
		and first.charge == later.charge and first.cooldown == later.cooldown
		and int(later.cell_patch.tick) > int(first.cell_patch.tick),
		"later no-refusal readback refreshes its observation clock and preserves complete native context/resources")
	expect(var_to_bytes(first) == first_bytes,
		"the first delivered observation is immutable across a later real runtime publication")
	expect(var_to_bytes(retained_publication) == retained_publication_bytes,
		"later runtime snapshots and delivery do not mutate retained publication payload")
	var delivered_bytes: PackedByteArray = var_to_bytes(later)
	var returned: Dictionary = Retention.evaluate(expected, current())
	returned.context.water_units_remaining = -1
	expect(Retention.equipment_unchanged(delivered_bytes, view().equipment), "readiness returns an independent copied context")
	reports.append({"case": "ordinary-native-hydration-no-refusal", "missing": missing.reason,
		"undelivered": undelivered.reason, "context": ready.context, "early_bytes": early_bytes.size()})


func _outer_stale_controls() -> void:
	for field: String in ["run_id", "epoch", "actor_id", "generation", "instance_id", "equipment_epoch", "usable_index", "body_id"]:
		if not fresh(): return
		var before: PackedByteArray = var_to_bytes(view().equipment)
		var bad: Dictionary = next_publication()
		var row: Dictionary = bad.actors[0]
		if field in ["run_id", "instance_id"]: row[field] = str(row[field]) + "-stale"
		else: row[field] = int(row[field]) + 1
		if field in ["run_id", "epoch"]: bad[field] = row[field]
		deliver(bad)
		var refused: Dictionary = Retention.evaluate(expected, current())
		expect(not refused.ready, "stale copied " + field + " cannot reuse retained healthy context as fresh readback")
		expect(Retention.equipment_unchanged(before, view().equipment),
			"actual production delivery rejects stale " + field + " without changing retained equipment")
		reports.append({"case": "outer-identity-negative", "field": field, "reason": refused.reason})
	if not fresh(): return
	var stale_serial: Dictionary = current()
	stale_serial.publication_serial = 0
	expect(not Retention.evaluate(expected, stale_serial).ready, "old snapshot serial cannot satisfy the accepted-publication barrier")
	var missing_rows: Dictionary = current()
	missing_rows.publication.actors = []
	expect(not Retention.evaluate(expected, missing_rows).ready, "missing actor readback cannot borrow the cached equipment context")
	var duplicate: Dictionary = current()
	duplicate.publication.actors.append(duplicate.publication.actors[0].duplicate(true))
	expect(not Retention.evaluate(expected, duplicate).ready, "ambiguous duplicate actor publication is refused")


func _control_generation_windows() -> void:
	if not fresh(): return
	var accepted: Dictionary = publication.duplicate(true)
	expect(session.cancel_input(0, session.epoch, &"policy"), "actual cancellation advances the retained physical control generation")
	var lagged: Dictionary = current()
	expect(int(lagged.frame.actors[0].generation) > int(accepted.actors[0].generation),
		"current main control is newer than the genuinely produced and delivered readback")
	expect(Retention.evaluate(expected, lagged).ready,
		"already delivered owner metadata remains valid within the accepted-to-current control window")
	var future: Dictionary = lagged.duplicate(true)
	future.publication.actors[0].generation = int(future.frame.actors[0].generation) + 1
	expect(not Retention.evaluate(expected, future).ready,
		"a future control generation cannot satisfy readiness from an older current frame")
	if not fresh(false): return
	var preaccepted: Dictionary = next_publication()
	expect(session.cancel_input(0, session.epoch, &"policy"), "a real cancellation separates preaccepted and accepted control generations")
	expected.minimum_control_generation = int(session.equipment_frame().actors[0].generation)
	deliver(next_publication())
	var ready: Dictionary = Retention.evaluate(expected, current())
	expect(ready.ready, "accepted baseline hydrates from the newer genuine control generation")
	expected.world_instance_id = ready.world_instance_id
	var retained: PackedByteArray = var_to_bytes(view().equipment)
	publication_serial += 1 # Harness arrival sequence, not a native execution receipt.
	deliver(preaccepted)
	expect(not Retention.evaluate(expected, current()).ready,
		"a delayed genuine packet older than the accepted control boundary cannot borrow the current cache")
	expect(Retention.equipment_unchanged(retained, view().equipment),
		"production feedback rejects the delayed preaccepted control packet without changing equipment")
	reports.append({"case": "control-generation-window", "minimum": expected.minimum_control_generation,
		"delayed_generation": preaccepted.actors[0].generation, "current_generation": view().control_generation})


func _context_change(key: String, source: Dictionary) -> Variant:
	match key:
		"profile": return "metered-drain-v2"
		"available": return false
		"terminal": return true
		"reason": return "native_owner_unavailable"
		"policy_hash": return "f".repeat(64) if source.policy_hash != "f".repeat(64) else "0".repeat(64)
		"allowed_materials": return [3]
		"initial_construction_receipt_available": return not source.initial_construction_receipt_available
		"world_instance_id": return -17 if int(source.world_instance_id) != -17 else -19
	return int(source[key]) + 1


func _context_and_full_retention_controls() -> void:
	if not fresh(): return
	var authoritative: Dictionary = view().equipment.metered_drain.duplicate(true)
	var actual_baseline: Dictionary = view().equipment
	var actual_baseline_bytes: PackedByteArray = var_to_bytes(actual_baseline)
	# These adversarial packets begin with a real native-produced context. Every
	# original context field is covered; the exact comparator cannot omit a
	# field merely because it is observational metadata.
	for key: String in authoritative.keys():
		var altered: Dictionary = actual_baseline.duplicate(true)
		altered.metered_drain[key] = _context_change(key, authoritative)
		expect(not Retention.equipment_unchanged(actual_baseline_bytes, altered),
			"complete retention detects copied native context mutation: " + key)
		if not fresh(): return
		var bad: Dictionary = next_publication()
		bad.actors[0].metered_drain[key] = _context_change(key, authoritative)
		deliver(bad)
		var refused: Dictionary = Retention.evaluate(expected, current())
		expect(not refused.ready, "mutated delivered context cannot satisfy pinned native readiness: " + key)
		reports.append({"case": "context-negative", "field": key, "reason": refused.reason})
	for key: String in ["charge", "cooldown"]:
		if not fresh(): return
		var before: PackedByteArray = var_to_bytes(view().equipment)
		var changed: Dictionary = next_publication()
		changed.actors[0][key] = 99.0 if key == "charge" else 0.1
		deliver(changed)
		expect(float(view().equipment[key]) == float(changed.actors[0][key]),
			"production resource readback actually delivers the " + key + " negative control")
		expect(not Retention.equipment_unchanged(before, view().equipment),
			"complete retention detects delivered " + key + " change")
		expect(Retention.evaluate(expected, current()).ready,
			"readiness is separate from exact retained resource equality for " + key)
	if not fresh(): return
	var missing_field: Dictionary = next_publication()
	missing_field.actors[0].metered_drain.erase("native_generation")
	deliver(missing_field)
	expect(not Retention.evaluate(expected, current()).ready, "malformed delivered context missing native identity is refused")
	if not fresh(): return
	var wrong_type: Dictionary = next_publication()
	wrong_type.actors[0].metered_drain.native_generation = true
	deliver(wrong_type)
	expect(not Retention.evaluate(expected, current()).ready, "boolean native generation is not an integer identity")


func _opaque_world_identity_controls() -> void:
	if not fresh(): return
	var initial: Dictionary = view().equipment.metered_drain.duplicate(true)
	var zero: Dictionary = next_publication()
	zero.actors[0].metered_drain.world_instance_id = 0
	deliver(zero)
	expect(not Retention.evaluate(expected, current()).ready, "zero World identity is unavailable, never a valid native owner")
	if not fresh(): return
	# This is a signed-type adversarial control, not a claim that -7 identifies
	# the actual native World above. Producer provenance remains separate.
	var negative: Dictionary = next_publication()
	negative.actors[0].metered_drain.world_instance_id = -7
	expected.world_instance_id = -7
	deliver(negative)
	expect(Retention.evaluate(expected, current()).ready and int(view().equipment.metered_drain.world_instance_id) == -7,
		"production readback and readiness accept a pinned nonzero negative opaque identity")
	var repinned: Dictionary = next_publication()
	repinned.actors[0].metered_drain.world_instance_id = -9
	deliver(repinned)
	expect(not Retention.evaluate(expected, current()).ready, "a different World cannot replace an already pinned signed owner")
	reports.append({"case": "opaque-world-identity-controls", "actual_native_owner": initial.world_instance_id,
		"synthetic_signed_ids": [-7, -9], "native_owner_claimed_for_synthetic_ids": false})


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	if not expect(ClassDB.class_exists("RapierPhysicsServer2D") and ClassDB.class_exists("CyberNativeCellWorld"),
		"actual native and Rapier runtimes are required"):
		finish()
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not expect(world.diagnostic_reset({"workers": 1}), "fresh native owner uses the one-worker configuration"):
		finish()
		return
	var checked: Dictionary = Contract.parse(FileAccess.get_file_as_string(DAM))
	if not expect(checked.get("ok", false), "unchanged canonical native reference fixture parses"):
		finish()
		return
	scenario = Host.new()
	if not expect(scenario.install(world, checked.definition, "Inspect", false,
		bridge.default_liquid_policy(), {"intent": "controlled", "normalization": ""}),
		"actual native preparation supplies applied construction identity without a mocked World"):
		finish()
		return
	_hydration_without_refusal()
	_outer_stale_controls()
	_control_generation_windows()
	_context_and_full_retention_controls()
	_opaque_world_identity_controls()
	finish()


func finish() -> void:
	if session != null:
		session.close()
		session.free()
	if owner != null: owner.queue_free()
	print("PHYSICAL_RETENTION_READBACK_RESULT assertions=%d failures=%d native_context=%s physical_devices=false" \
		% [assertions, failures, "executed" if native_context_executed else "not-executed"])
	var directory: String = OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR")
	if not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK:
		var file: FileAccess = FileAccess.open(directory.path_join("physical-retention-readback.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"schema": "physical-retention-readback-regressions-v1",
				"assertions": assertions, "failures": failures, "reports": reports,
				"native_context_executed": native_context_executed,
				"scope": "actual native context and real Rapier session readback; synthetic adverse packets; no physical-device qualification"}, "\t") + "\n")
			file.close()
	quit(1 if failures else 0)
