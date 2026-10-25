extends SceneTree

# LCB-001 (#200) liquid solver policy through the real threaded desktop owner
# (CyberSimulationWorker): an explicit request on scenario_reset, the native
# receipt forwarded unchanged in lab_context, refusal without replacing the
# running World, receipt refresh only on a new committed generation, and
# isolation of a published receipt from consumer mutation.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
const BASE_PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
const ASSIGNMENTS_AT: int = 20 # magic, versions, two 8-word digests, count
const LIQUIDS: Array[int] = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var worker: CyberSimulationWorker
var definition: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("LIQUID_POLICY_WORKER: " + message)

func wait_for(predicate: Callable, timeout: int = 20000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func _with(request: PackedInt32Array, material: int, family: int, variant: int = 0) -> PackedInt32Array:
	var words: PackedInt32Array = request.duplicate()
	var row: int = LIQUIDS.find(material)
	words[ASSIGNMENTS_AT + row * 3 + 1] = family
	words[ASSIGNMENTS_AT + row * 3 + 2] = variant
	return words

func _latest() -> CyberSimulationSnapshot:
	return worker.take_latest_snapshot(0)

# Queue one scenario_reset and return the first snapshot published for it.
func _reset(serial: int, policy: Variant, include_policy: bool = true) -> CyberSimulationSnapshot:
	var command: Dictionary = {"scenario_reset":definition, "scenario_request_serial":serial,
		"scenario_mode":"Benchmark", "sampled_character_enabled":false}
	if include_policy: command["liquid_policy"] = policy
	worker.queue_lab(command)
	var seen: bool = await wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = _latest()
		return snapshot != null and int(snapshot.lab_context.get("scenario_request_serial", -1)) == serial)
	expect(seen, "worker never published scenario request %d" % serial)
	return _latest()

func _receipt(snapshot: CyberSimulationSnapshot) -> Dictionary:
	return {} if snapshot == null else snapshot.lab_context.get("liquid_solver_policy", {})

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false, "current native extension unavailable")
		_finish()
		return
	var source: Dictionary = Runner.read_text(BASE_PATH)
	var checked: Dictionary = Contract.parse(source.get("text", "")) if source.ok else {}
	expect(checked.get("ok", false), "protected Dam Break definition must validate")
	if not checked.get("ok", false):
		_finish()
		return
	definition = checked.definition
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var request: PackedInt32Array = bridge.default_liquid_policy()
	var default_hash: String = str(bridge.validate_liquid_policy(request).receipt.policy_hash)
	worker = Worker.new()
	worker.set_frame_state(0, false, true, Vector2i(512, 512), Vector2i(462, 492),
		Vector2i(100, 100), 0, 0, true, true, true)
	expect(worker.start_worker(Vector2(512, 512)) == OK, "threaded owner starts")
	expect(await wait_for(func() -> bool: return not _receipt(_latest()).is_empty()),
		"first publication carries the native liquid policy receipt")
	var initial: Dictionary = _receipt(_latest())
	expect(initial.get("policy_hash", "") == default_hash and initial.get("admission", "") == "current_defaults_only",
		"initial owner World reports the default policy")
	completed["initial"] = true

	# 1. Explicit default request is forwarded and read back normalized.
	var applied: CyberSimulationSnapshot = await _reset(1, request)
	var receipt: Dictionary = _receipt(applied)
	expect(bool(applied.lab_context.get("scenario_request_applied", false)), "explicit default request was not applied")
	expect(receipt.get("policy_hash", "") == default_hash and receipt.get("envelope", PackedInt32Array()) == request
		and int(receipt.get("session_generation", -1)) > int(initial.get("session_generation", -1)),
		"receipt after the explicit request is not the applied normalized policy with a new generation")
	expect(receipt.get("assignments", [{}])[0].get("requested_family", "") == "freemass_v1",
		"Water requested family was not forwarded")
	var applied_generation: int = int(receipt.get("session_generation", -1))
	var applied_definition: String = str(applied.lab_context.microscenario.get("definition_hash", ""))
	completed["explicit"] = true

	# 2. A published receipt is a copy: mutating it cannot reach later publications.
	receipt["policy_hash"] = "tampered"
	receipt["assignments"][0]["applied_family"] = "tampered"
	receipt["envelope"].set(0, 0)
	expect(await wait_for(func() -> bool:
		var later: CyberSimulationSnapshot = _latest()
		return later != null and later.serial > applied.serial), "owner published no later snapshot")
	var later_receipt: Dictionary = _receipt(_latest())
	expect(later_receipt.get("policy_hash", "") == default_hash
		and later_receipt.get("assignments", [{}])[0].get("applied_family", "") == "freemass_v1"
		and later_receipt.get("envelope", PackedInt32Array()) == request,
		"consumer mutation leaked into a later publication")
	completed["isolation"] = true

	# 3. Refusals keep the running World, its receipt and its generation.
	var refusals: Array = [
		# Cached Water is admitted; an unsupported Oil/PF assignment still refuses.
		[2, _with(request, 16, 3, 1), "combination_rejected"],
		[3, _with(request, 16, 4), "combination_rejected"],
		[4, [3, 1, 0], "PackedInt32Array"],
	]
	for item: Array in refusals:
		var refused: CyberSimulationSnapshot = await _reset(item[0], item[1])
		var kept: Dictionary = _receipt(refused)
		expect(not bool(refused.lab_context.get("scenario_request_applied", true)),
			"request %d replaced the World" % item[0])
		expect(str(refused.lab_context.get("status", "")).contains(item[2]),
			"request %d status hides the refusal: %s" % [item[0], refused.lab_context.get("status", "")])
		expect(kept.get("policy_hash", "") == default_hash and int(kept.get("session_generation", -1)) == applied_generation,
			"request %d changed the receipt or generation" % item[0])
		expect(str(refused.lab_context.microscenario.get("definition_hash", "")) == applied_definition,
			"request %d disturbed the running MicroScenario" % item[0])
	completed["refusals"] = refusals.size()

	# 4. Request-only code 0 commits a new World; the receipt refreshes with it.
	var zeros: PackedInt32Array = request.duplicate()
	for row: int in range(LIQUIDS.size()): zeros[ASSIGNMENTS_AT + row * 3 + 1] = 0
	var normalized: CyberSimulationSnapshot = await _reset(5, zeros)
	var normalized_receipt: Dictionary = _receipt(normalized)
	expect(bool(normalized.lab_context.get("scenario_request_applied", false))
		and normalized_receipt.get("policy_hash", "") == default_hash
		and normalized_receipt.get("envelope", PackedInt32Array()) == request
		and int(normalized_receipt.get("session_generation", -1)) > applied_generation
		and normalized_receipt.get("assignments", [{}])[0].get("requested_family", "") == "material_default",
		"material-default request did not commit a refreshed receipt")
	completed["normalized"] = true

	# 5. No request keeps defaults on the ordinary builder.
	var plain: CyberSimulationSnapshot = await _reset(6, null, false)
	var plain_receipt: Dictionary = _receipt(plain)
	expect(bool(plain.lab_context.get("scenario_request_applied", false))
		and plain_receipt.get("policy_hash", "") == default_hash
		and int(plain_receipt.get("session_generation", -1)) > int(normalized_receipt.get("session_generation", -1))
		and plain_receipt.get("assignments", [{}])[0].get("requested_family", "") == "freemass_v1",
		"request without a policy did not run defaults")
	completed["no_request"] = true
	worker.stop_worker()
	_finish()

func _finish() -> void:
	if worker != null: worker.stop_worker()
	print("LIQUID_POLICY_WORKER: %d assertions; %d failures; completed=%s" % [
		assertions, failures, JSON.stringify(completed)])
	quit(1 if failures > 0 else 0)
