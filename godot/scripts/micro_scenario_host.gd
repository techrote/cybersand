class_name CyberMicroScenarioHost
extends RefCounted

# Owned by the existing simulation owner. This object neither owns a thread nor
# calls World.tick, scene nodes or Rapier. Native candidate/swap remains authority.
const Contract = preload("res://scripts/micro_scenario_contract.gd")
var _definition: Dictionary = {}
var definition_hash: String = ""
var mode: String = "inspect"
var instrumentation: bool = true
var last_error: String = ""
var event_failed: bool = false
var event_index: int = 0
var history: Array = []
var observations: Array = []
var objectives: Dictionary = {}
var initial_integer: int = 0
var initial_requested_numerator_255: int = 0
var initial_quantization_error_numerator_255: int = 0
var current_integer: int = 0
var explicit_source: int = 0
var explicit_sink: int = 0

func definition() -> Dictionary:
	return _definition.duplicate(true)

func reset(world: Variant, raw: Variant, selected_mode: String = "inspect",
		observers: bool = true) -> bool:
	last_error = ""
	if not selected_mode in Contract.MODES:
		last_error = "Unknown scenario mode"; return false
	var checked: Dictionary = Contract.validate(raw)
	if not checked.get("ok", false):
		last_error = str(checked.error); return false
	if world == null or not world.has_method(&"get_water_experiment_policy") \
		or not ClassDB.class_exists(&"CyberDemoBridge"):
		last_error = "MicroScenarios require the current native backend"; return false
	var d: Dictionary = checked.definition
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var built: bool
	if d.water_policy.is_empty():
		built = bridge.build_tuned_world(world, PackedInt32Array(d.rectangles), checked.transport.packed)
	else:
		built = bridge.build_water_feel_world(world, PackedInt32Array(d.rectangles),
			checked.transport.packed, checked.water.semantic, PackedInt32Array(d.partial_water_fills))
	if not built:
		last_error = str(bridge.get_last_error()); return false
	# Nothing below can reject a definition. A failed reset leaves BOTH the old
	# World and run cursor/objective/provenance state untouched (apart from error).
	_definition = d.duplicate(true)
	definition_hash = str(checked.hash)
	mode = selected_mode
	instrumentation = observers
	event_failed = false
	event_index = 0
	history.clear(); observations.clear(); objectives.clear()
	explicit_source = 0; explicit_sink = 0
	initial_integer = int(observe(world).get("water_integer", 0))
	current_integer = initial_integer
	initial_requested_numerator_255 = 0
	for i: int in range(0, d.partial_water_fills.size(), 6):
		initial_requested_numerator_255 += int(d.partial_water_fills[i+2]) \
			* int(d.partial_water_fills[i+3]) * int(d.partial_water_fills[i+4]) \
			* int(checked.water.derived.maximum)
	initial_quantization_error_numerator_255 = initial_integer * 255 - initial_requested_numerator_255
	for c: Dictionary in d.conditions: objectives[str(c.id)] = "pending"
	return true

static func observe(world: Variant, action: Dictionary = {}) -> Dictionary:
	var origin: Vector2i = Vector2i.ZERO
	var size: Vector2i = Vector2i(1024, 1024)
	if not action.is_empty():
		origin = Vector2i(int(action.x), int(action.y))
		size = Vector2i(int(action.width), int(action.height))
	return world.water_experiment_observation(origin, size)

# One adapter implementation is shared by the legacy owner wrappers and generic
# runner. The caller must only pass events from a validated, frozen definition.
static func _apply_event(world: Variant, action: Dictionary, coherence_ticks: int) -> Dictionary:
	if world.has_failed(): return {"ok": false, "error": "World is quarantined"}
	var before: Dictionary = observe(world, action)
	if before.is_empty(): return {"ok": false, "error": "Observation region rejected"}
	var ok: bool = true
	var origin: Vector2i = Vector2i(int(action.x), int(action.y))
	var size: Vector2i = Vector2i(int(action.width), int(action.height))
	match str(action.kind):
		"fill":
			var coherence: int = int((2 * int(action.coherence) * coherence_ticks + 12) / 24)
			ok = bool(world.water_experiment_fill_rect(origin, size, int(action.normalized_mass), coherence))
		"erase":
			ok = bool(world.water_experiment_erase_rect(origin, size))
		"sample":
			if action.get("count_material", false):
				var count: int = 0
				for y: int in range(origin.y, origin.y + size.y):
					for x: int in range(origin.x, origin.x + size.x):
						if world.material_at(x, y) == int(action.material): count += 1
				before["sampled_material_cells"] = count
				before["material_sampling_scope"] = "occupancy-query; body masks may occlude"
		_:
			ok = false
	if not ok: return {"ok": false, "error": "Scenario event rejected; explicit reset required"}
	var after: Dictionary = observe(world, action)
	return {"ok": true, "before": before, "after": after}

func apply_due(world: Variant) -> bool:
	if _definition.is_empty(): return true
	if event_failed or world.has_failed(): return false
	while event_index < _definition.events.size():
		var action: Dictionary = _definition.events[event_index]
		if int(action.tick) > int(world.get_tick_index()): break
		var policy: Dictionary = _definition.water_policy
		var result: Dictionary = _apply_event(world, action, int(policy.get("coherence_ticks", 12)))
		if not result.get("ok", false):
			last_error = str(result.error); event_failed = true; return false
		var before_mass: int = int(result.before.water_integer)
		var after_mass: int = int(result.after.water_integer)
		explicit_source += maxi(0, after_mass - before_mass)
		explicit_sink += maxi(0, before_mass - after_mass)
		current_integer += after_mass - before_mass
		history.append({"tick": int(world.get_tick_index()), "action": action.duplicate(true),
			"before_water_integer": before_mass, "after_water_integer": after_mass})
		if action.kind == "sample":
			# Objective evaluations are mandatory and independent of optional
			# inspection retention. Disabling observers never disables gameplay.
			_evaluate_conditions(event_index, result.before)
			if instrumentation:
				observations.append({"action_index": event_index, "region": action.duplicate(true),
					"observation": result.before.duplicate(true)})
		event_index += 1
	return true

func _evaluate_conditions(index: int, observation: Dictionary) -> void:
	for c: Dictionary in _definition.conditions:
		if int(c.event_index) != index: continue
		var actual: int = int(observation.get(str(c.metric), -1))
		var threshold: int = int(c.value)
		var met: bool = actual == threshold
		if c.comparison == "ge": met = actual >= threshold
		elif c.comparison == "le": met = actual <= threshold
		objectives[str(c.id)] = str(c.outcome) if met else "not-met"

func summary() -> Dictionary:
	return {"id": str(_definition.get("id", "")), "definition_hash": definition_hash,
		"mode": mode, "instrumentation": instrumentation, "event_index": event_index,
		"event_failed": event_failed, "objectives": objectives.duplicate(true),
		"error": last_error, "tools": _definition.get("tools", []).duplicate(),
		"player_enabled": _definition.get("player_start") != null}

func capture(world: Variant, owner_config: Dictionary = {}) -> Dictionary:
	var quarantined: bool = bool(world.has_failed())
	var result: Dictionary = summary()
	result.merge({"schema_version": 1, "definition": definition(),
		"runtime": runtime_identity(), "state_status": "failed-diagnostic-only" if quarantined or event_failed else "completed-boundary",
		"persistence": "observation-and-recipe; not exact replay or a continuation save",
		"live_input_capture": "not complete; scheduled events are complete and bounded",
		"history": history.duplicate(true), "observations": observations.duplicate(true),
		"world": {} if quarantined or event_failed else observe(world),
		"effective_config": {"workers": int(world.get_worker_threads()),
			"owner": owner_config.duplicate(true),
			"liquid_surface_adhesion_enabled": bool(world.get_liquid_surface_adhesion_enabled()),
			"transport_hash": CyberTransportProfiles.resolve(_definition.transport).get("hash", "") if not _definition.is_empty() else "",
			"water_policy_hash": JSON.stringify(Contract.canonical(world.get_water_experiment_policy())).sha256_text(),
			"simulation_window_enabled": bool(world.simulation_window_enabled),
			"cadence_lod_enabled": bool(world.cadence_lod_enabled),
			"water_policy": world.get_water_experiment_policy()},
		"accounting": {"initial_integer": initial_integer, "explicit_source": explicit_source,
			"explicit_sink": explicit_sink, "scope": "scheduled edit ledger; excludes reactions/live inputs",
			"requested_fill_numerator_255": initial_requested_numerator_255,
			"initial_minus_requested_numerator_255": initial_quantization_error_numerator_255}}, true)
	return result

static func runtime_identity() -> Dictionary:
	var native_path: String = "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	if OS.get_name() == "Windows":
		native_path = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
	var files: Dictionary = {}
	for path: String in ["res://scripts/micro_scenario_contract.gd", "res://scripts/micro_scenario_host.gd",
		"res://scripts/micro_scenario_catalogue.gd", "res://scripts/experiment_tower.gd",
		"res://scripts/water_feel_scenarios.gd", "res://scripts/transport_profiles.gd",
		"res://scripts/water_experiment_profiles.gd", "res://scripts/cell_world.gd",
		"res://scripts/main.gd", "res://scripts/simulation_worker.gd",
		"res://scripts/web_demo_controller.gd", "res://scripts/sampled_character.gd",
		"res://tools/micro_scenario_benchmark.gd"]:
		files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "unavailable"
	var manifest_path: String = "res://addons/cybersand_native/runtime-provenance.linux.json" if OS.get_name() == "Linux" else "res://addons/cybersand_native/runtime-provenance.json"
	var native_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) if FileAccess.file_exists(manifest_path) else {}
	if not native_manifest is Dictionary: native_manifest = {}
	var source: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	return {"platform": OS.get_name(), "godot": Engine.get_version_info().get("string", "unknown"),
		"source_revision": source if not source.is_empty() else "unavailable; use source file hashes",
		"source_files": files, "native_artifact_path": native_path,
		"retained_native_manifest": native_manifest,
		"manifest_scope": "retained build record, not a new validation claim; compare actual artifact hash",
		"material_catalogue_identity": native_manifest.get("source_inputs", {}).get("native/include/cybersand/material.hpp", "unavailable; use native artifact identity"),
		"native_artifact_sha256": FileAccess.get_sha256(native_path) if not OS.has_feature("web") \
			and FileAccess.file_exists(native_path) else "unavailable; Web requires export manifest",
		"native_seed_scope": "existing owner WorldConfig; recipe seed does not reseed physics",
		"interaction_profile": "built-in current source; INT-000 not implemented"}
