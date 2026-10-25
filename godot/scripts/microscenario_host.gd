class_name CyberMicroScenarioHost
extends RefCounted

# Owned by the existing desktop simulation owner OR the synchronous Web/headless
# owner. Never pass this instance, its World, or a live scene node across threads.
const Contract = preload("res://scripts/microscenario_contract.gd")
const MAX_TIMINGS: int = 3600
const Telemetry = preload("res://scripts/microscenario_telemetry.gd")
const HostEvidence = preload("res://scripts/liquid_host_evidence.gd")
var _host_observation: RefCounted
var _host_observation_identity: Dictionary = {}
var _inspection_bridge: Variant
var _telemetry: CyberMicroScenarioTelemetry
var _before_elapsed_us: int = 0
var _material_ids: Array[int] = []
var _interaction_profile: Dictionary = {}
var _interaction_inspection: Array = []
var last_error: String = ""
# Typed LCB-001 refusal {code, material, detail} of the last rejected liquid
# solver policy request; empty after any other outcome.
var last_liquid_policy_refusal: Dictionary = {}
var _world: Variant
var _definition: Dictionary = {}
var _definition_hash: String = ""
var _transport_hash: String = ""
var _mode: String = "Inspect"
var _instrumentation: bool = true
var _failed: bool = false
var _event_index: int = 0
var _observation_index: int = 0
var _history: Array = []
var _samples: Array = []
var _observations: Array = []
var _values: Dictionary = {}
var _outcome: String = "running"
var _initial_integer: int = 0
var _requested_numerator: int = 0
var _source: int = 0
var _sink: int = 0
var _ledger_current: int = 0
var _timings: Array[float] = []
var _timing_total_ms: float = 0.0
var _timing_count: int = 0
var _last_completed_tick: int = 0

func install(world: Variant, value: Variant, mode: String = "Inspect", instrumentation: bool = true,
		liquid_policy: Variant = null, controlled_setup: Dictionary = {}, commit_guard: Callable = Callable(),
		prepared_token: int = 0) -> bool:
	# All schema/profile validation precedes the existing candidate-and-swap
	# builder. A rejected replacement leaves the old World AND host cursor intact.
	# liquid_policy: null keeps every liquid on its default; otherwise the LCB-001
	# PackedInt32Array request is validated natively before any replacement.
	last_liquid_policy_refusal = {}
	if liquid_policy != null and typeof(liquid_policy) != TYPE_PACKED_INT32_ARRAY:
		last_error = "Liquid solver policy must be a PackedInt32Array envelope"
		return false
	var checked: Dictionary = Contract.validate(value)
	if not checked.get("ok", false):
		last_error = str(checked.get("error", "Invalid definition"))
		return false
	if not mode in Contract.MODES:
		last_error = "Unknown MicroScenario mode"
		return false
	if world == null or not world.has_method(&"get_water_experiment_policy") or not ClassDB.class_exists(&"CyberDemoBridge"):
		last_error = "MicroScenarios require the current native backend"
		return false
	var candidate: Dictionary = checked.definition
	var staged_observation: RefCounted
	var staged_identity: Dictionary = {}
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if int(candidate.schema_version) == 2 and (not bridge.has_method(&"inspect_cell")
		or not bridge.has_method(&"inspect_statistics")
		or not bridge.has_method(&"inspect_interaction_profile")
		or not bridge.has_method(&"inspect_interaction")):
		last_error = "Schema 2 requires the rebuilt native observation adapter; prior world preserved"
		return false
	if not controlled_setup.is_empty():
		var intent: String = str(controlled_setup.get("intent", "controlled"))
		var physical: Dictionary = controlled_setup.get("physical_owner", {})
		if not intent in ["controlled", "exploratory"] or int(candidate.schema_version) != 2 \
			or (candidate.body_enabled and (intent != "exploratory" or physical.is_empty())):
			last_error = "Prepared liquid setup requires schema 2 and staged ownership"
			return false
		if intent == "controlled" and (candidate.player_enabled \
			or candidate.execution.policy != "fixed" or candidate.interest.policy != "fixed"):
			last_error = "Controlled liquid preparation requires a fixed actor-free schema-2 scenario"
			return false
		var owner: Dictionary = controlled_setup.get("owner_execution", {})
		if intent == "exploratory" and (owner.is_empty() or not commit_guard.is_valid()):
			last_error = "Exploratory liquid preparation requires staged owner configuration"
			return false
		if not world.has_method(&"get_applied_liquid_construction_receipt") or not bridge.has_method(&"prepare_liquid_world"):
			last_error = "Controlled liquid preparation requires the rebuilt native adapter"
			return false
		var request: PackedInt32Array = bridge.default_liquid_policy() if liquid_policy == null else liquid_policy
		var options: Dictionary = {"definition_hash":checked.hash, "seed":candidate.seed,
			"region":PackedInt32Array(candidate.interest.region),
			"cadence_lod_enabled":candidate.execution.cadence_lod_enabled,
			"liquid_surface_adhesion_enabled":candidate.execution.liquid_surface_adhesion_enabled,
			"normalization":controlled_setup.get("normalization", ""), "intent":intent,
			"maximum_rule_radius":controlled_setup.get("maximum_rule_radius",2),
			"pacing":"host_paced" if intent == "exploratory" else "fixed_steps"}
		if intent == "exploratory":
			if candidate.interest.policy == "owner":
				options.region = PackedInt32Array(owner.region)
				options.simulation_window_enabled = owner.simulation_window_enabled
			if candidate.execution.policy == "owner":
				options.cadence_lod_enabled = owner.cadence_lod_enabled
				options.liquid_surface_adhesion_enabled = owner.liquid_surface_adhesion_enabled
		if not physical.is_empty(): options.initial_bodies = physical.initial_bodies
		# Only the exclusive owner retains this opaque token between its two
		# preparation turns. Revalidation above still precedes final commit.
		var token: int = prepared_token
		if token == 0:
			token = bridge.prepare_liquid_world(world, PackedInt32Array(candidate.rectangles),
				checked.transport.packed, PackedInt32Array(candidate.water_semantics),
				PackedInt32Array(candidate.partial_water_fills), request, options)
		if token == 0:
			last_liquid_policy_refusal = bridge.get_last_liquid_policy_refusal()
			last_error = str(bridge.get_last_error())
			return false
		var observed: Dictionary = _prepare_liquid_host_observation(bridge,world,token,checked,mode,instrumentation,options)
		if not observed.get("ok",false):
			bridge.discard_liquid_world(world,token)
			last_error = str(observed.get("error","Prepared host observation refused; prior session retained"))
			return false
		staged_observation = observed.evidence
		staged_identity = observed.identity
		var result: Variant = commit_guard.call(bridge, token) if commit_guard.is_valid() else bridge.commit_liquid_world(world, token)
		if result is Dictionary and result.get("deferred", false):
			# The exclusive owner retains the candidate while main prepares its
			# permanent physics space. No host cursor or World has been installed.
			return false
		var committed: bool = result is bool and result
		if not committed:
			bridge.discard_liquid_world(world, token)
			last_error = "Controlled liquid replacement retired before commit; " + str(bridge.get_last_error())
			return false
	elif liquid_policy != null:
		if not bridge.has_method(&"build_liquid_policy_world") or not world.has_method(&"get_liquid_solver_policy"):
			last_liquid_policy_refusal = {"code":"platform_unsupported", "material":null,
				"detail":"host has no native policy handshake"}
			last_error = "Liquid solver policy refused; running world preserved: platform_unsupported"
			return false
		if not bridge.build_liquid_policy_world(world, PackedInt32Array(candidate.rectangles),
			checked.transport.packed, PackedInt32Array(candidate.water_semantics),
			PackedInt32Array(candidate.partial_water_fills), liquid_policy):
			last_liquid_policy_refusal = bridge.get_last_liquid_policy_refusal()
			last_error = str(bridge.get_last_error())
			return false
	elif not bridge.build_water_feel_world(world, PackedInt32Array(candidate.rectangles),
		checked.transport.packed, PackedInt32Array(candidate.water_semantics),
		PackedInt32Array(candidate.partial_water_fills)):
		last_error = str(bridge.get_last_error())
		return false
	_world = world
	_host_observation = staged_observation
	_host_observation_identity = staged_identity
	_inspection_bridge = bridge if int(candidate.schema_version) == 2 else null
	_telemetry = Telemetry.new()
	_before_elapsed_us = 0
	_material_ids.clear()
	for index: int in range(4, candidate.rectangles.size(), 5):
		if not int(candidate.rectangles[index]) in _material_ids: _material_ids.append(int(candidate.rectangles[index]))
	if not candidate.partial_water_fills.is_empty() and not 3 in _material_ids: _material_ids.append(3)
	for observation: Dictionary in candidate.observations:
		if not int(observation.material) in _material_ids: _material_ids.append(int(observation.material))
	for event: Dictionary in candidate.events:
		if not int(event.material) in _material_ids: _material_ids.append(int(event.material))
	_material_ids.sort()
	_interaction_profile = _inspection_bridge.inspect_interaction_profile() if _inspection_bridge != null else {}
	_interaction_inspection.clear()
	if _inspection_bridge != null:
		for left: int in range(_material_ids.size()):
			for right: int in range(left, _material_ids.size()):
				_interaction_inspection.append(_inspection_bridge.inspect_interaction(
					_material_ids[left], _material_ids[right], 0))
	_definition = candidate.duplicate(true)
	_definition_hash = str(checked.hash)
	_transport_hash = str(checked.transport.hash)
	_mode = mode
	_instrumentation = instrumentation
	_failed = false
	last_error = ""
	_event_index = 0
	_observation_index = 0
	_history.clear()
	_samples.clear()
	_observations.clear()
	_values.clear()
	_outcome = "running"
	_source = 0
	_sink = 0
	_initial_integer = int(_water_observe().get("water_integer", 0)) if instrumentation else 0
	_ledger_current = _initial_integer
	_requested_numerator = 0
	var fills: Array = _definition.partial_water_fills
	var maximum: int = (1 << int(_definition.water_semantics[1])) - 1
	for offset: int in range(0, fills.size(), 6):
		_requested_numerator += int(fills[offset+2]) * int(fills[offset+3]) * int(fills[offset+4]) * maximum
	_timings.clear()
	_timing_total_ms = 0.0
	_timing_count = 0
	_last_completed_tick = 0
	# Controlled preparation already installed these exact final selections
	# before native receipt capture. Ordinary constructors retain their old tail.
	if controlled_setup.is_empty(): apply_interest()
	_observe_due() # Tick zero describes initial state, before tick-zero events.
	if _instrumentation and _inspection_bridge != null: _telemetry.sample(_world, _inspection_bridge, false)
	# Controlled native replacement has committed. Its initial observer failure
	# is an installed session fault, never a retained-World construction refusal.
	# Preserve legacy ordinary-host return semantics outside this new route.
	return true if not controlled_setup.is_empty() else not _failed

func active() -> bool:
	return not _definition.is_empty()

# The live World's applied liquid solver policy receipt, read from native.
func liquid_solver_policy() -> Dictionary:
	if _world == null or not _world.has_method(&"get_liquid_solver_policy"): return {}
	return _world.get_liquid_solver_policy()

func _prepare_liquid_host_observation(bridge: Variant, world: Variant, token: int, checked: Dictionary,
		mode: String, instrumentation: bool, options: Dictionary) -> Dictionary:
	if not bridge.has_method(&"prepared_liquid_run_capture"):
		return {"ok":false,"error":"Prepared host observation requires the rebuilt native adapter"}
	var captured: Dictionary = bridge.prepared_liquid_run_capture(world,token)
	if captured.get("lifecycle","") != "prepared" or captured.get("token",0) != token:
		return {"ok":false,"error":"Prepared host observation token was retired"}
	var receipt: Dictionary = captured.native_run_encoding
	var owner_inputs: Dictionary = {"scope":"prepared_recipe_and_owner_inputs_v1",
		"input_owner":"exclusive_scenario_owner","definition":checked.definition,
		"definition_hash":checked.hash,"transport_hash":checked.transport.hash,
		"mode":mode,"instrumentation":instrumentation,
		"native_initial_execution":{"intent":receipt.run_intent,"pacing":receipt.pacing,
			"region":Array(receipt.region),"simulation_window_enabled":receipt.simulation_window_enabled,
			"cadence_lod_enabled":receipt.cadence_lod_enabled,"liquid_surface_adhesion_enabled":receipt.liquid_surface_adhesion_enabled,
			"worker_threads":receipt.worker_threads,"maximum_rule_radius":receipt.maximum_rule_radius},
		"native_initial_body_input":{"values":Array(options.get("initial_bodies",PackedFloat32Array())),
			"sha256":receipt.initial_body_state_sha256,"body_count":receipt.initial_body_count}}
	var result: Dictionary = HostEvidence.collect(bridge,receipt,owner_inputs)
	if not result.ok: return result
	var values: Dictionary = result.evidence.snapshot()
	var identity: Dictionary = {"schema_version":1,"kind":"qualified_liquid_host_observation_identity",
		"digest":result.evidence.digest(),"native_receipt_hash":receipt.receipt_hash,
		"session_generation":receipt.session_generation,"definition_hash":checked.hash,
		"run_intent":receipt.run_intent,"host_eligible_for_full_matched_evidence":false,
		"publication_matches_current_path_file":values.runtime.publication_manifest.artifact_matches_current_path_file,
		"mapped_module_binding":"unverified","complete_host_binding":"unverified"}
	identity.make_read_only()
	return {"ok":true,"evidence":result.evidence,"identity":identity}

func liquid_host_observation() -> Dictionary:
	if _host_observation == null or _world == null or _host_observation_identity.is_empty(): return {}
	# Accepted ordinary constructors retire native generation/typed identity.
	if _world.get_liquid_policy_session_generation() != _host_observation_identity.session_generation: return {}
	return _host_observation_identity.duplicate(true)

func liquid_host_observation_record() -> Dictionary:
	if liquid_host_observation().is_empty(): return {}
	return {"identity":liquid_host_observation(),"values":_host_observation.snapshot(),
		"canonical_bytes_hex":_host_observation.canonical_bytes().hex_encode()}

func clear() -> void:
	_world = null
	_host_observation = null
	_host_observation_identity = {}
	_inspection_bridge = null
	_telemetry = null
	_material_ids.clear()
	_interaction_profile.clear()
	_interaction_inspection.clear()
	_definition.clear()
	_history.clear()
	_samples.clear()
	_observations.clear()
	_values.clear()
	_timings.clear()
	_failed = false
	last_error = ""

func player_enabled() -> bool:
	return active() and bool(_definition.player_enabled)

func body_enabled() -> bool:
	return active() and bool(_definition.body_enabled)

func allows_tool(tool: String) -> bool:
	return active() and tool in _definition.tools

func definition() -> Dictionary:
	return _definition.duplicate(true)

func fixed_interest() -> bool:
	return active() and _definition.interest.policy == "fixed"

func fixed_execution() -> bool:
	return active() and _definition.execution.policy == "fixed"

func cadence_enabled() -> bool:
	return bool(_definition.execution.cadence_lod_enabled)

func adhesion_enabled() -> bool:
	return bool(_definition.execution.liquid_surface_adhesion_enabled)

func apply_interest() -> void:
	if fixed_execution():
		_world.set_cadence_lod_enabled(cadence_enabled())
		_world.set_liquid_surface_adhesion_enabled(adhesion_enabled())
	if not fixed_interest(): return
	var region: Array = _definition.interest.region
	_world.set_simulation_window_enabled(true)
	_world.set_simulation_window(Vector2i(region[0], region[1]), Vector2i(region[2], region[3]), 0, 0)

func before_tick() -> bool:
	var start: int = Time.get_ticks_usec() if _instrumentation else 0
	var ok: bool = _before_tick_impl()
	_before_elapsed_us = Time.get_ticks_usec() - start if _instrumentation else 0
	return ok

func _before_tick_impl() -> bool:
	if not active(): return true
	if _failed: return false
	if _world.has_failed(): return _fault("Native World is quarantined; reset required")
	apply_interest()
	var tick: int = int(_world.get_tick_index())
	while _event_index < _definition.events.size():
		var event: Dictionary = _definition.events[_event_index]
		if int(event.tick) > tick: break
		if int(event.tick) < tick:
			return _fault("Missed event boundary; no catch-up or automatic retry")
		if not _apply_event(event): return false
		_event_index += 1
	return true

func after_tick() -> bool:
	var start: int = Time.get_ticks_usec() if _instrumentation else 0
	var previous: int = _last_completed_tick
	var ok: bool = _after_tick_impl()
	if ok and _instrumentation and _inspection_bridge != null and _last_completed_tick != previous:
		_telemetry.sample(_world, _inspection_bridge, true)
		_telemetry.host_sample(float(_before_elapsed_us + Time.get_ticks_usec() - start) / 1000.0)
	return ok

func _after_tick_impl() -> bool:
	if not active(): return true
	if _failed: return false
	if _world.has_failed(): return _fault("Native tick failed; reset required")
	var tick: int = int(_world.get_tick_index())
	if tick == _last_completed_tick: return true
	if tick != _last_completed_tick + 1:
		return _fault("Owner skipped a completed-tick boundary")
	_last_completed_tick = tick
	if _instrumentation:
		var elapsed: float = float(_world.get_simulation_time_ms())
		_timing_total_ms += elapsed
		_timing_count += 1
		if _timings.size() < MAX_TIMINGS: _timings.append(elapsed)
	_observe_due()
	return not _failed

func advance() -> bool:
	# Headless convenience; desktop/Web owners retain their own character,
	# Rapier, publication and pacing order around before_tick/after_tick.
	if not active() or not before_tick(): return false
	if not _world.simulation_tick(): return _fault("Native tick failed; reset required")
	return after_tick()

func _apply_event(event: Dictionary) -> bool:
	var before: Dictionary = _water_observe(event) if _instrumentation else {}
	var origin := Vector2i(event.x, event.y)
	var size := Vector2i(event.width, event.height)
	var ok: bool = true
	match str(event.kind):
		"fill":
			var coherence: int = int((2 * int(event.coherence) * int(_definition.water_semantics[2]) + 12) / 24)
			ok = bool(_world.water_experiment_fill_rect(origin, size, int(event.normalized_mass), coherence))
		"erase":
			ok = bool(_world.water_experiment_erase_rect(origin, size))
		"sample":
			if _instrumentation:
				_samples.append({"action_index":_event_index, "region":event.duplicate(true),
					"observation":before.duplicate(true)})
	if not ok: return _fault("Scheduled %s rejected at tick %d; reset required" % [event.kind, event.tick])
	if _instrumentation:
		var after: Dictionary = _water_observe(event)
		var before_mass: int = int(before.get("water_integer", 0))
		var after_mass: int = int(after.get("water_integer", before_mass))
		_source += maxi(0, after_mass - before_mass)
		_sink += maxi(0, before_mass - after_mass)
		_ledger_current += after_mass - before_mass
		_history.append({"tick":int(_world.get_tick_index()), "action":event.duplicate(true),
			"before_water_integer":before_mass, "after_water_integer":after_mass})
	return true

func _observe_due() -> void:
	var tick: int = int(_world.get_tick_index())
	while _observation_index < _definition.observations.size():
		var specification: Dictionary = _definition.observations[_observation_index]
		if int(specification.tick) > tick: break
		if int(specification.tick) != tick:
			_fault("Missed observation boundary; result was not recorded")
			return
		# Conditions remain logical observers even when optional logs are disabled.
		var required: bool = _instrumentation
		for condition: Dictionary in _definition.conditions:
			required = required or condition.observation == specification.id
		if required:
			var region: Array = specification.region
			var amount: Variant = tick
			if specification.metric == "water_integer":
				amount = int(_world.water_experiment_observation(Vector2i(region[0], region[1]),
					Vector2i(region[2], region[3])).get("water_integer", 0))
			elif specification.metric == "material_cells":
				amount = 0
				for y: int in range(region[1], region[1] + region[3]):
					for x: int in range(region[0], region[0] + region[2]):
						if int(_world.material_at(x,y)) == int(specification.material): amount += 1
			elif specification.metric == "cell_state":
				amount = _inspection_bridge.inspect_cell(_world, Vector2i(region[0], region[1]))
				if not amount.get("ok", false):
					_fault("Cell-state observation rejected; " + str(amount.get("error", "unavailable")))
					return
			_values[specification.id] = amount
			if _instrumentation:
				_observations.append({"id":specification.id, "tick":tick,
					"metric":specification.metric, "value":amount.duplicate(true) if amount is Dictionary else amount, "region":region.duplicate()})
		_observation_index += 1
	for condition: Dictionary in _definition.conditions:
		if not _values.has(condition.observation): continue
		var measured: int = int(_values[condition.observation])
		var target: int = int(condition.value)
		var satisfied: bool = ((condition.comparison == "eq" and measured == target)
			or (condition.comparison == "le" and measured <= target)
			or (condition.comparison == "ge" and measured >= target))
		if satisfied and _outcome != "fail": _outcome = str(condition.outcome)

func _water_observe(event: Dictionary = {}) -> Dictionary:
	var origin := Vector2i.ZERO
	var size := Vector2i(Contract.SIDE, Contract.SIDE)
	if not event.is_empty():
		origin = Vector2i(event.x, event.y)
		size = Vector2i(event.width, event.height)
	return _world.water_experiment_observation(origin, size)

func legacy_water_state() -> Dictionary:
	# Compatibility projection for unchanged #19 UI/export consumers. These old
	# keys are not an alternative physics implementation or a complete replay.
	return {"action_index":_event_index, "actions":_history.duplicate(true),
		"observations":_samples.duplicate(true), "initial_integer":_initial_integer,
		"initial_requested_numerator_255":_requested_numerator,
		"initial_quantization_error_numerator_255":_initial_integer*255-_requested_numerator,
		"explicit_source":_source, "explicit_sink":_sink, "current":_ledger_current}

func summary() -> Dictionary:
	if not active(): return {}
	return {"id":_definition.id, "schema_version":_definition.schema_version,
		"liquid_host_observation":liquid_host_observation(),
		"completed_tick":int(_world.get_tick_index()),
		"presentation":_definition.get("presentation", {}).duplicate(true),
		"source_recipe":_definition.source_recipe, "source_recipe_hash":_definition.source_recipe_hash,
		"transport_hash":_transport_hash, "water_semantics":_definition.water_semantics.duplicate(),
		"material_ids":_material_ids.duplicate(), "declared_observations":_definition.observations.duplicate(true),
		"interaction_profile":{"schema_id":_interaction_profile.get("schema_id","unavailable"),
			"schema_version":_interaction_profile.get("schema_version",0),
			"profile_id":_interaction_profile.get("profile_id","unavailable"),
			"profile_version":_interaction_profile.get("profile_version",0),
			"channels":_interaction_profile.get("channels",[]).duplicate(true),
			"layer_kinds":_interaction_profile.get("layer_kinds",[]).duplicate(true),
			"authored_layers":_interaction_profile.get("authored_layers",[]).duplicate(true),
			"catalogue_validation":_interaction_profile.get("catalogue_validation",{}).duplicate(true),
			"coverage":_interaction_profile.get("coverage",[]).duplicate(true),
			"tuning_passes":_interaction_profile.get("tuning_passes",[]).duplicate(true),
			"specialized_rule_count":_interaction_profile.get("specialized_rule_count",0),
			"specialized_authority":_interaction_profile.get("specialized_authority","unavailable"),
			"specialized_migration_state":_interaction_profile.get("specialized_migration_state","unavailable")},
		"interaction_inspection":_interaction_inspection.duplicate(true),
		"kinetic_contact_baseline":{"transport_hash":_transport_hash,
			"water_semantics":_definition.water_semantics.duplicate(),
			"execution":_definition.execution.duplicate(true),
			"interest":_definition.interest.duplicate(true),
			"worker_count":int(_world.get_worker_threads()),
			"scope":"read-only baseline identity; kinetic/contact physics remains owned outside INT-000"},
		"recipe_version":_definition.recipe_version, "seed":_definition.seed,
		"definition_hash":_definition_hash, "maturity":_definition.maturity,
		"execution_policy":_definition.execution.policy, "interest_policy":_definition.interest.policy,
		"player_enabled":_definition.player_enabled, "body_enabled":_definition.body_enabled,
		"mode":_mode, "tools":_definition.tools.duplicate(), "instrumentation":_instrumentation, "failed":_failed,
		"error":last_error, "outcome":_outcome, "events_applied":_event_index,
		"event_limit":Contract.MAX_EVENTS, "observations":_observations.duplicate(true),
		"observation_limit":Contract.MAX_OBSERVATIONS}

func capture(identity: Dictionary = {}) -> Dictionary:
	if not active(): return {}
	var native: Dictionary = {} if _world.has_failed() else _water_observe()
	var sorted: Array[float] = _timings.duplicate()
	sorted.sort()
	var timing: Dictionary = {"count":_timing_count, "retained_count":sorted.size(),
		"retention":"first-3600-completed-ticks", "truncated":_timing_count > MAX_TIMINGS,
		"total_ms":_timing_total_ms, "scope":"native simulation_tick only; observer and owner costs excluded"}
	if not sorted.is_empty():
		for percentile: int in [50,95,99]:
			timing["p%d_ms" % percentile] = sorted[clampi(int(ceil(percentile * sorted.size() / 100.0)) - 1, 0, sorted.size()-1)]
		timing["max_ms"] = sorted.back()
	var report: Dictionary = summary()
	report.merge({"definition":definition(), "runtime_identity":identity.duplicate(true),
		"liquid_host_observation_record":liquid_host_observation_record(),
		"interaction_profile_full":_interaction_profile.duplicate(true),
		"interaction_inspection":_interaction_inspection.duplicate(true),
		"kinetic_contact_baseline":{"source_runtime_identity":identity.duplicate(true),
			"transport_hash":_transport_hash,
			"water_semantics":_definition.water_semantics.duplicate(),
			"effective_water_policy":_world.get_water_experiment_policy(),
			"execution":_definition.execution.duplicate(true),
			"interest":_definition.interest.duplicate(true),
			"worker_count":int(_world.get_worker_threads()),
			"scope":"identity/provenance only; INT-000 does not own contact motion"},
		"platform":OS.get_name(), "godot":Engine.get_version_info().get("string", "unknown"),
		"backend":str(_world.get_backend_name()), "worker_count":int(_world.get_worker_threads()),
		"completed_tick":int(_world.get_tick_index()), "native":native,
		"transport_hash":_transport_hash, "effective_water_policy":_world.get_water_experiment_policy(),
		"execution_settings":{"simulation_window_enabled":_world.get_simulation_window_enabled(),
			"cadence_lod_enabled":_world.get_cadence_lod_enabled(),
			"liquid_surface_adhesion_enabled":_world.get_liquid_surface_adhesion_enabled(),
			"interest":_definition.interest.duplicate(true)},
		"action_history":_history.duplicate(true), "scheduled_samples":_samples.duplicate(true),
		"water_ledger":{"available":_instrumentation, "initial_integer":_initial_integer,
			"explicit_source":_source, "explicit_sink":_sink,
			"observed_current_integer":native.get("water_integer", null),
			"scope":"scheduled edits only; reactions, user tools and ROI outflow are NOT inferred"},
		"timing":timing, "work_statistics":_telemetry.capture(),
		"budget_outcome":"quarantined" if _failed or _world.has_failed() else "admitted",
		"definition_budget":{"rectangles":_definition.rectangles.size() / 5,
			"partial_water_fills":_definition.partial_water_fills.size() / 6,
			"events":_definition.events.size(), "event_limit":Contract.MAX_EVENTS,
			"observations":_definition.observations.size(), "observation_limit":Contract.MAX_OBSERVATIONS},
		"replay_complete":false,
		"capture_kind":"definition-and-observations; not a restorable runtime snapshot",
		"utc":Time.get_datetime_string_from_system(true)}, true)
	return report

func _fault(message: String) -> bool:
	_failed = true
	last_error = message
	return false
