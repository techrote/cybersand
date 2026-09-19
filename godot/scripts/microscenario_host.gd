class_name CyberMicroScenarioHost
extends RefCounted

# Owned by the existing desktop simulation owner OR the synchronous Web/headless
# owner. Never pass this instance, its World, or a live scene node across threads.
const Contract = preload("res://scripts/microscenario_contract.gd")
const MAX_TIMINGS: int = 3600
var last_error: String = ""
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

func install(world: Variant, value: Variant, mode: String = "Inspect", instrumentation: bool = true) -> bool:
	# All schema/profile validation precedes the existing candidate-and-swap
	# builder. A rejected replacement leaves the old World AND host cursor intact.
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
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.build_water_feel_world(world, PackedInt32Array(candidate.rectangles),
		checked.transport.packed, PackedInt32Array(candidate.water_semantics),
		PackedInt32Array(candidate.partial_water_fills)):
		last_error = str(bridge.get_last_error())
		return false
	_world = world
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
	apply_interest()
	_observe_due() # Tick zero describes initial state, before tick-zero events.
	return true

func active() -> bool:
	return not _definition.is_empty()

func clear() -> void:
	_world = null
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
			var amount: int = tick
			if specification.metric == "water_integer":
				amount = int(_world.water_experiment_observation(Vector2i(region[0], region[1]),
					Vector2i(region[2], region[3])).get("water_integer", 0))
			elif specification.metric == "material_cells":
				amount = 0
				for y: int in range(region[1], region[1] + region[3]):
					for x: int in range(region[0], region[0] + region[2]):
						if int(_world.material_at(x,y)) == int(specification.material): amount += 1
			_values[specification.id] = amount
			if _instrumentation:
				_observations.append({"id":specification.id, "tick":tick,
					"metric":specification.metric, "value":amount, "region":region.duplicate()})
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
	return {"id":_definition.id, "schema_version":Contract.VERSION,
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
		"timing":timing, "replay_complete":false,
		"capture_kind":"definition-and-observations; not a restorable runtime snapshot",
		"utc":Time.get_datetime_string_from_system(true)}, true)
	return report

func _fault(message: String) -> bool:
	_failed = true
	last_error = message
	return false
