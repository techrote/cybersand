extends SceneTree

# LCB-FEEL #360 single-execution harness. One process constructs one registered
# arm through the ordinary controlled prepared-liquid route, advances the real
# native World, records copied observations and retires the owner. Results are
# raw observations only: tools/lcb/feel_preflight.py independently reduces them.
# Exit codes: 0 receipt written (including a recorded refusal or fault),
# 2 harness/argument error (no physics claim).
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Probe = preload("res://scripts/liquid_feel_probe.gd")
const RECEIPT_SCHEMA: String = "lcb-feel-case-receipt-v1"

var _options: Dictionary = {"mode":"arm", "registration":"", "scenario":"", "family":"", "variant":"reference",
	"radius":"3", "workers":"1", "horizon":"", "output":"", "case-id":"", "lane":"", "source-sha":"unavailable"}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or pair.size() != 2 or not _options.has(pair[0]):
			_finish_error("unknown argument " + argument)
			return
		_options[pair[0]] = pair[1]
	if str(_options.output).is_empty() or str(_options.registration).is_empty():
		_finish_error("--registration and --output are required")
		return
	var registration: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(_options.registration)))
	if not registration is Dictionary or registration.get("schema", "") != "lcb-feel-registration-v1":
		_finish_error("registration unavailable or wrong schema")
		return
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		_finish_error("native extension unavailable")
		return
	var receipt: Dictionary = _negative(registration) if _options.mode == "negative" else _arm(registration)
	receipt["schema"] = RECEIPT_SCHEMA
	receipt["registration_id"] = registration.id
	receipt["registration_sha256"] = Probe.identity_digest(FileAccess.get_file_as_string(str(_options.registration)))
	receipt["source_sha_argument"] = str(_options["source-sha"])
	receipt["godot_version"] = Engine.get_version_info()
	receipt["os"] = {"name":OS.get_name(), "processor_count":OS.get_processor_count(),
		"processor_name":OS.get_processor_name(), "logical_processors":int(ClassDB.class_call_static(&"CyberNativeCellWorld", &"logical_processor_count"))}
	var file := FileAccess.open(str(_options.output), FileAccess.WRITE)
	if file == null:
		_finish_error("cannot write " + str(_options.output))
		return
	file.store_string(JSON.stringify(receipt, "  ", false) + "\n")
	file.close()
	print("LCB_FEEL_CASE ", receipt.get("case_id", "negative"), " ", receipt.get("outcome", ""))
	quit(0)

func _finish_error(message: String) -> void:
	printerr("LCB_FEEL_CASE_ERROR: ", message)
	quit(2)

func _scenario(registration: Dictionary, id: String) -> Dictionary:
	for scenario: Dictionary in registration.scenarios:
		if scenario.id == id: return scenario
	return {}

func _choice(bridge: Variant, request: PackedInt32Array, material: int, family: String, variant: String) -> Dictionary:
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, material):
		if choice.family == family and choice.variant == variant: return choice
	return {}

func _definition(scenario: Dictionary) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(str(scenario.fixture))
	var checked: Dictionary = Contract.parse(text)
	if not checked.get("ok", false): return {"ok":false, "error":"fixture rejected: " + str(checked.get("error", ""))}
	if checked.hash != scenario.definition_hash or checked.definition.id != scenario.fixture_id:
		return {"ok":false, "error":"fixture identity differs from registration"}
	return {"ok":true, "definition":checked.definition, "hash":checked.hash, "transport_hash":checked.transport.hash}

func _assignments(policy: Dictionary) -> Array:
	var out: Array = []
	for assignment: Dictionary in policy.get("assignments", []):
		out.append({"material":int(assignment.material), "name":str(assignment.get("name", "")),
			"applied_family":str(assignment.applied_family), "applied_variant":str(assignment.applied_variant)})
	return out

func _arm(registration: Dictionary) -> Dictionary:
	var workers: int = int(_options.workers)
	var radius: int = int(_options.radius)
	var horizon: int = int(_options.horizon) if str(_options.horizon).is_valid_int() else int(registration.horizon_ticks)
	var receipt: Dictionary = {"kind":"arm", "case_id":str(_options["case-id"]), "lane":str(_options.lane),
		"scenario":str(_options.scenario), "requested":{"material":int(registration.material),
		"family":str(_options.family), "variant":str(_options.variant), "radius":radius, "workers":workers,
		"normalization":str(registration.normalization), "horizon":horizon}}
	var scenario: Dictionary = _scenario(registration, str(_options.scenario))
	if scenario.is_empty():
		receipt.outcome = "refused"; receipt.error = "scenario not registered"; return receipt
	# Campaign scenarios keep each reused fixture's own registered horizon.
	if not str(_options.horizon).is_valid_int():
		horizon = int(scenario.get("horizon_ticks", registration.horizon_ticks))
		receipt.requested.horizon = horizon
	var hash_interval: int = maxi(1, int(registration.get("hash_interval_ticks", 1)))
	# JSON numbers parse as floats; compare checkpoints as exact integers.
	var checkpoints: Array[int] = []
	for value: Variant in scenario.get("checkpoint_ticks", []): checkpoints.append(int(value))
	var void_values: Array = scenario.get("void_region", [])
	var void_region := Rect2i()
	if void_values.size() == 4: void_region = Rect2i(int(void_values[0]), int(void_values[1]), int(void_values[2]), int(void_values[3]))
	var parsed: Dictionary = _definition(scenario)
	if not parsed.ok:
		receipt.outcome = "refused"; receipt.error = parsed.error; return receipt
	receipt.fixture = {"id":parsed.definition.id, "definition_hash":parsed.hash, "transport_hash":parsed.transport_hash}
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var defaults: PackedInt32Array = bridge.default_liquid_policy()
	receipt.default_policy = _assignments(bridge.validate_liquid_policy(defaults).get("receipt", {}))
	var choice: Dictionary = _choice(bridge, defaults, int(registration.material), str(_options.family), str(_options.variant))
	if choice.is_empty() or not choice.accepted:
		receipt.outcome = "refused"
		receipt.error = "family/variant not offered" if choice.is_empty() else str(choice.refusal)
		return receipt
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var retired: WeakRef = weakref(world)
	if not world.diagnostic_reset({"workers":workers}):
		receipt.outcome = "refused"; receipt.error = "native worker configuration rejected"; return receipt
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	var setup: Dictionary = {"intent":"controlled", "normalization":str(registration.normalization), "maximum_rule_radius":radius}
	var build_started: int = Time.get_ticks_usec()
	var installed: bool = host.install(world, parsed.definition, "Benchmark", true, choice.request, setup)
	receipt.construction_us = Time.get_ticks_usec() - build_started
	if not installed:
		receipt.outcome = "refused"
		receipt.error = host.last_error
		receipt.policy_refusal = host.last_liquid_policy_refusal
		return receipt
	var applied: Dictionary = world.get_liquid_solver_policy()
	var construction: Dictionary = world.get_applied_liquid_construction_receipt()
	receipt.applied = {"policy_hash":str(applied.policy_hash), "session_generation":int(applied.session_generation),
		"assignments":_assignments(applied), "family_parameters":applied.get("family_parameters", {}).duplicate(true),
		"minimum_rule_radius":int(applied.minimum_rule_radius), "maximum_rule_radius":int(applied.maximum_rule_radius),
		"physical_state_hash_version":int(applied.physical_state_hash_version),
		"configured_workers":int(world.get_worker_threads()), "backend":str(world.get_backend_name())}
	receipt.construction = {"receipt_hash":str(construction.receipt_hash), "run_intent":str(construction.run_intent),
		"worker_threads":int(construction.worker_threads), "maximum_rule_radius":int(construction.maximum_rule_radius),
		"prepared_setup_hash":str(construction.prepared_setup_hash), "prepared_payload_hash":str(construction.prepared_payload_hash),
		"physical_state_hash":str(construction.physical_state_hash),
		"eligible_for_full_matched_evidence":construction.get("eligible_for_full_matched_evidence", null),
		"normalization":construction.get("normalization", {}).duplicate(true)}
	var host_identity: Dictionary = host.liquid_host_observation()
	receipt.host_observation = {"digest":str(host_identity.get("digest", "")),
		"host_eligible_for_full_matched_evidence":host_identity.get("host_eligible_for_full_matched_evidence", null),
		"mapped_module_binding":host_identity.get("mapped_module_binding", "unavailable")}
	var region_values: Array = scenario.census_region
	var region := Rect2i(int(region_values[0]), int(region_values[1]), int(region_values[2]), int(region_values[3]))
	receipt.initial = Probe.census(world, region)
	var void_samples: Array = []
	if void_values.size() == 4: void_samples.append(Probe.voids(world, void_region))
	var ticks: Array = []
	var outcome: String = "completed"
	for index: int in horizon:
		var started: int = Time.get_ticks_usec()
		var advanced: bool = host.advance()
		var wall: int = Time.get_ticks_usec() - started
		var completed: int = index + 1
		ticks.append(Probe.tick_sample(world, bridge, wall, completed % hash_interval == 0 or completed == horizon))
		if void_values.size() == 4 and completed in checkpoints: void_samples.append(Probe.voids(world, void_region))
		if not advanced:
			outcome = "faulted"
			receipt.error = host.last_error
			break
	receipt.ticks = ticks
	receipt.hash_interval_ticks = hash_interval
	receipt.voids = void_samples
	receipt.final = Probe.census(world, region)
	var captured: Dictionary = host.capture()
	var ledger: Dictionary = captured.get("water_ledger", {})
	receipt.host_ledger = {"initial":int(ledger.get("initial_integer", -1)), "source":int(ledger.get("explicit_source", -1)),
		"sink":int(ledger.get("explicit_sink", -1)), "current":ledger.get("observed_current_integer", null),
		"events_applied":int(captured.get("events_applied", -1)), "action_history":captured.get("action_history", []),
		"host_outcome":str(captured.get("outcome", "")), "budget_outcome":str(captured.get("budget_outcome", "")),
		"scope":str(ledger.get("scope", ""))}
	receipt.declared_observations = captured.get("observations", [])
	receipt.native_timing = captured.get("timing", {})
	receipt.outcome = outcome
	# Retirement: release the exclusive owner and confirm no reference remains.
	host.clear()
	host = null
	world = null
	receipt.retirement = {"world_released":retired.get_ref() == null}
	return receipt

# Construction-time negative controls. Each control records the exact refusal
# and whether the previously accepted World/receipt remained byte-identical.
func _negative(registration: Dictionary) -> Dictionary:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var defaults: PackedInt32Array = bridge.default_liquid_policy()
	# The controls are defined over the dam fixture's 192x96 reservoir fill; every
	# registration that runs them registers that unchanged fixture.
	var scenario: Dictionary = {}
	for candidate: Dictionary in registration.scenarios:
		if candidate.fixture_id == "lcb.dam.water.freemass.depth-96.v1": scenario = candidate
	if scenario.is_empty(): return {"kind":"negative", "outcome":"refused", "error":"negative controls require the registered dam fixture"}
	var parsed: Dictionary = _definition(scenario)
	var controls: Array = []
	if not parsed.ok: return {"kind":"negative", "outcome":"refused", "error":parsed.error}
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.diagnostic_reset({"workers":1})
	world.set_simulation_window_enabled(false)
	var host: CyberMicroScenarioHost = Host.new()
	var baseline_ok: bool = host.install(world, parsed.definition, "Benchmark", true, defaults,
		{"intent":"controlled", "normalization":"water-normalize-v1", "maximum_rule_radius":2})
	var retained_hash: String = world.get_physical_state_hash()
	var retained_receipt: PackedByteArray = world.get_applied_liquid_construction_receipt().canonical_bytes
	var retained_policy: String = str(world.get_liquid_solver_policy().policy_hash)
	var retained: Callable = func() -> bool:
		return world.get_physical_state_hash() == retained_hash \
			and world.get_applied_liquid_construction_receipt().canonical_bytes == retained_receipt \
			and str(world.get_liquid_solver_policy().policy_hash) == retained_policy
	# 1. IN at radius 2.
	var inertial: Dictionary = _choice(bridge, defaults, 3, "inertial_cellular_v1", "reference")
	var accepted: bool = host.install(world, parsed.definition, "Benchmark", true, inertial.request,
		{"intent":"controlled", "normalization":"water-normalize-v1", "maximum_rule_radius":2})
	controls.append({"id":"inertial-water-radius-2", "expected":"refused", "accepted":accepted,
		"error":host.last_error, "refusal":host.last_liquid_policy_refusal.duplicate(true), "previous_world_retained":retained.call()})
	# 2/3. Fractional Water under each whole-cell family without and with normalization.
	var fractional: Dictionary = parsed.definition.duplicate(true)
	fractional.partial_water_fills = [40, 160, 192, 96, 128, 0]
	fractional.observations = []
	fractional.conditions = []
	for family: String in ["cellular_yield_v1", "inertial_cellular_v1"]:
		var choice: Dictionary = _choice(bridge, defaults, 3, family, "reference")
		accepted = host.install(world, fractional, "Benchmark", true, choice.request,
			{"intent":"controlled", "normalization":"", "maximum_rule_radius":3})
		controls.append({"id":"fractional-without-normalization-" + family, "expected":"refused", "accepted":accepted,
			"error":host.last_error, "refusal":host.last_liquid_policy_refusal.duplicate(true), "previous_world_retained":retained.call()})
	var cellular: Dictionary = _choice(bridge, defaults, 3, "cellular_yield_v1", "reference")
	accepted = host.install(world, fractional, "Benchmark", true, cellular.request,
		{"intent":"controlled", "normalization":"water-normalize-v1", "maximum_rule_radius":3})
	var normalization: Dictionary = world.get_applied_liquid_construction_receipt().get("normalization", {}) if accepted else {}
	controls.append({"id":"fractional-with-normalization-cellular_yield_v1", "expected":"accepted", "accepted":accepted,
		"error":host.last_error, "normalization":normalization.duplicate(true),
		"requested_fill_numerator_per_cell":128, "cells":192 * 96, "maximum":255})
	# 4/5. Pressure variants for Oil and Brine; cached variants on non-pressure families.
	for material: int in [16, 24]:
		var offered: Array = []
		for choice: Dictionary in bridge.liquid_policy_assignment_choices(defaults, material):
			if choice.family == "pressure_flow_v1":
				offered.append({"variant":choice.variant, "accepted":choice.accepted,
					"refusal":choice.get("refusal", {}).duplicate(true) if choice.get("refusal", null) is Dictionary else choice.get("refusal", null)})
		controls.append({"id":"pressure-for-material-%d" % material, "expected":"refused_or_absent", "offered":offered})
	var variants: Array = []
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(defaults, 3):
		variants.append({"family":choice.family, "variant":choice.variant, "accepted":choice.accepted})
	controls.append({"id":"water-variant-catalogue", "expected":"cached variants only for pressure_flow_v1", "offered":variants})
	host.clear()
	return {"kind":"negative", "case_id":"negative-controls", "outcome":"completed", "baseline_installed":baseline_ok, "controls":controls}
