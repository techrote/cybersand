extends SceneTree

# Actual GDExtension Worlds at configured1/4 workers. The diagnostic projections
# and copied optimization dictionaries never authorize skipping simulation work.
# Parallel dispatch below does not claim four distinct task-claiming threads.
const Profiles = preload("res://scripts/transport_profiles.gd")
const VARIANTS: Array[String] = ["reference", "cached", "cached_dormant"]
const SECTIONS: Array[String] = ["native_variants", "readback_encoding", "exact_parity",
	"gas_invalidation", "cold_restore", "default_preservation"]
const OBSERVED: Array[String] = ["index_incarnation", "indexed_chunks", "column_groups", "row_groups",
	"dirty_column_groups", "dirty_row_groups", "index_chunk_capacity", "head_repair_cell_budget",
	"derived_capacity_bytes", "worker_counter_capacity_bytes", "common_counter_bytes", "certificate_buffer_capacity_bytes", "gas_components",
	"gas_valid_components", "gas_members", "gas_member_capacity", "gas_dirty_chunks", "gas_capacity_bytes",
	"gas_invalidation_pair_budget"]
const COUNTERS: Array[String] = ["water_material_calls", "water_motion_calls", "other_liquid_calls",
	"certificate_attempts", "certificate_reuses", "certificate_saved_calls", "certificate_declines",
	"certificate_work_charged", "certificate_work_credited", "certificate_work_windows", "certificate_work_suspensions",
	"certificate_unavailable_ticks", "certificate_suspended_ticks", "certificate_cold_resets", "certificate_cold_reset_cells",
	"certificate_layer_activations",
	"index_rebuilds", "invalidation_rects", "columns_recomputed", "rows_recomputed", "base_cells_written",
	"final_cells_written", "gas_reuses", "gas_reference_passes", "reference_fallbacks", "fallback_resident_cells",
	"certificate_invalidation_cells", "preparation_nanoseconds", "gas_nanoseconds", "head_nanoseconds",
	"gas_seed_cells", "gas_seed_probes", "gas_bfs_cells", "gas_bfs_probes", "gas_bfs_nodes",
	"gas_member_validations", "gas_member_stamps", "gas_component_reuses", "gas_index_chunks",
	"gas_cache_build_cells", "gas_cache_builds", "gas_component_proof_checks", "gas_member_initializations",
	"gas_member_builds", "gas_invalidation_pairs", "gas_component_invalidations", "gas_dirty_chunks_queued",
	"gas_capacity_fallbacks", "gas_budget_fallbacks", "gas_restart_fallbacks", "gas_relabel_cells",
	"gas_identity_nodes", "gas_stamp_clear_cells"]
const CONFIG: Array[String] = ["index_chunk_capacity", "head_repair_cell_budget", "gas_member_capacity",
	"gas_invalidation_pair_budget"]
var assertions: int = 0
var failures: int = 0
var completed: Dictionary = {}
var work_observations: Array[Dictionary] = []
var bridge: Variant
var defaults: PackedInt32Array
var profile: PackedInt32Array

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("LCB_PRESSURE_OPTIMIZATION: " + message)
	return value

func _initialize() -> void:
	for section: String in SECTIONS: completed[section] = false
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false, "current native extension unavailable")
		_finish()
		return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	defaults = bridge.default_liquid_policy()
	var resolved: Dictionary = Profiles.resolve(Profiles.preset(0))
	if not expect(resolved.get("ok", false), "baseline transport profile unavailable"):
		_finish()
		return
	profile = resolved.packed
	var sections_ok: bool = true
	for workers: int in [1, 4]:
		sections_ok = _cohort(workers) and sections_ok
		sections_ok = _gas_cohort(workers) and sections_ok
		sections_ok = _defaults_preserved(workers) and sections_ok
	# Each cohort must finish every required group; a partial cohort cannot set
	# any positive completion flag or substitute a skipped/default field.
	for section: String in SECTIONS: completed[section] = sections_ok
	_finish()

func _finish() -> void:
	print("LCB_PRESSURE_OPTIMIZATION_WORK: " + JSON.stringify(work_observations))
	print("LCB_PRESSURE_OPTIMIZATION: %d assertions; %d failures; completed=%s" % [
		assertions, failures, JSON.stringify(completed)])
	quit(1 if failures > 0 else 0)

func _request(variant: int, gas: bool) -> PackedInt32Array:
	var words: PackedInt32Array = defaults.slice(0, defaults.size() - 2)
	words[21] = 3
	words[22] = variant
	words.append_array(PackedInt32Array([1, 3, 1, 2, 1 if gas else 0, 32, 0]))
	return words

func _rectangles(gas: bool) -> PackedInt32Array:
	if gas:
		return PackedInt32Array([8, 8, 12, 1, 1, 8, 20, 12, 1, 1,
			8, 8, 1, 13, 1, 19, 8, 1, 13, 1, 9, 19, 10, 1, 3])
	var out := PackedInt32Array()
	for offset: int in [0, 128, 256, 384]:
		out.append_array(PackedInt32Array([offset + 1, 1, 14, 14, 1,
			offset + 3, 11, 4, 2, 3, offset + 11, 12, 1, 1, 16]))
	return out

func _build(workers: int, variant: int, gas: bool) -> Variant:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not expect(world.diagnostic_reset({"workers":workers}), "native configured worker count refused"): return null
	world.set_simulation_window_enabled(false)
	var request: PackedInt32Array = _request(variant, gas)
	var validation: Dictionary = bridge.validate_liquid_policy(request)
	if not expect(validation.accepted and validation.refusal == null, "native variant refused"): return null
	if not expect(bridge.build_liquid_policy_world(world, _rectangles(gas), profile,
		PackedInt32Array([1, 8, 12, 0]), PackedInt32Array(), request),
		"native variant construction failed: " + str(bridge.get_last_error())): return null
	var receipt: Dictionary = world.get_liquid_solver_policy()
	expect(receipt.envelope == request and receipt.policy_hash == validation.receipt.policy_hash,
		"constructor must retain the actual admitted policy")
	var water: Dictionary = {}
	for row: Dictionary in receipt.assignments:
		if int(row.material) == 3: water = row
	expect(water.get("applied_family", "") == "pressure_flow_v1"
		and water.get("applied_variant", "") == VARIANTS[variant], "actual variant readback differs")
	expect(int(world.get_worker_threads()) == workers and int(world.get_physical_state_hash_version()) == 2,
		"native constructor lost configured workers/hash2 identity")
	if not gas:
		for offset: int in [0, 128, 256, 384]:
			expect(world.diagnostic_fill_rect(Vector2i(offset + 11, 12), Vector2i.ONE, 16, 200),
				"real unrelated Oil lifecycle could not be primed")
	return world

func _decimal(value: Variant) -> bool:
	if not value is String: return false
	var text: String = value
	if text.is_empty() or text.length() > 20: return false
	if text.length() > 1 and text.unicode_at(0) == 48: return false
	for i: int in range(text.length()):
		if text.unicode_at(i) < 48 or text.unicode_at(i) > 57: return false
	return text.length() < 20 or text <= "18446744073709551615"

func _encoded_fields(values: Dictionary, names: Array[String], label: String) -> void:
	expect(values.size() == names.size(), label + " field set differs")
	for field: String in names:
		expect(values.has(field) and _decimal(values.get(field)), label + "." + field + " must be an exact unsigned decimal string")

func _inspection(world: Variant, variant: int) -> Dictionary:
	var facts: Dictionary = world.inspect_pressure_optimization()
	expect(facts.get("schema_version", 0) == 1 and facts.get("unsigned_encoding", "") == "decimal_string"
		and facts.get("execution_version", 0) == 3 and facts.get("certificate_warmup_visits", 0) == 1
		and facts.get("certificate_backoff_visits", 0) == 8, "readback schema/derived admission version differs")
	expect(facts.get("available", false) and bool(facts.cached) == (variant > 0)
		and bool(facts.dormant) == (variant == 2), "readback does not distinguish the actual implementation")
	_encoded_fields(facts.get("requested_config", {}), CONFIG, "requested_config")
	_encoded_fields(facts.get("observed", {}), OBSERVED, "observed")
	_encoded_fields(facts.get("counters", {}), COUNTERS, "counters")
	var admission: Dictionary = facts.get("certificate_admission", {})
	expect(admission.get("model", "") == "certificate_work_credits_v1"
		and admission.get("enabled") is bool and admission.get("contents_cold") is bool
		and int(admission.get("trial_ticks", 0)) == 8 and int(admission.get("suspension_ticks", 0)) == 32
		and int(admission.get("window_ticks", -1)) >= 0 and int(admission.get("window_ticks", 9)) <= 8
		and int(admission.get("suspend_remaining", -1)) >= 0 and int(admission.get("suspend_remaining", 33)) <= 32,
		"whole-layer admission must expose its actual bounded model/state")
	for field: String in ["window_charge", "window_credit", "last_window_charge", "last_window_credit",
		"invalidation_charge", "proof_charge", "reuse_charge", "saved_call_credit"]:
		expect(_decimal(admission.get(field)), "certificate_admission." + field + " must preserve unsigned work credits")
	expect(admission.invalidation_charge == "1" and admission.proof_charge == "40"
		and admission.reuse_charge == "1" and admission.saved_call_credit == "8", "work-credit weights differ")
	if variant != 2:
		expect(not admission.enabled and facts.observed.certificate_buffer_capacity_bytes == "0"
			and facts.counters.certificate_invalidation_cells == "0", "non-dormant arms must not maintain unused certificates")
	expect(facts.requested_config == {"index_chunk_capacity":"4096", "head_repair_cell_budget":"4194304",
		"gas_member_capacity":"1048576", "gas_invalidation_pair_budget":"4194304"}, "requested native budget values differ")
	var identity: String = str(facts.get("extension_identity_sha256", ""))
	expect(int(facts.get("extension_identity_version", -1)) == (1 if variant > 0 else 0)
		and identity.length() == (64 if variant > 0 else 0), "execution identity presence/encoding differs")
	return facts

func _snapshot(world: Variant) -> Dictionary:
	var observation: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(512, 128))
	var ledger: Dictionary = world.get_pressure_flow_ledger()
	# The authoritative ledger is exact; last_tick counts actual preparation work
	# and legitimately differs when caches avoid gas/head passes.
	ledger.erase("last_tick")
	return {"projection":world.get_liquid_comparison_hash(1), "quiescent":world.get_liquid_comparison_hash(2),
		"quantity":int(observation.water_integer), "gas":world.inspect_gas_compartments(),
		"pressure_ledger":ledger}

func _equal(worlds: Array, label: String) -> void:
	var reference: Dictionary = _snapshot(worlds[0])
	expect(str(reference.projection).length() == 16 and str(reference.quiescent).length() == 16,
		label + ": diagnostic hashes absent")
	for variant: int in [1, 2]: expect(_snapshot(worlds[variant]) == reference, label + ": exact allarm authority diverged")

func _advance(worlds: Array, count: int, label: String) -> void:
	for step: int in range(count):
		for world: Variant in worlds: expect(world.simulation_tick(), label + ": native tick faulted")
		_equal(worlds, label + " +" + str(step + 1))

func _getter_isolation(world: Variant, variant: int) -> void:
	var raw: String = world.get_physical_state_hash()
	var bytes: PackedByteArray = bridge.export_physical_state(world)
	var same: String = world.get_liquid_comparison_hash(1)
	var quiet: String = world.get_liquid_comparison_hash(2)
	expect(same.length() == 16 and quiet.length() == 16 and same != quiet and raw != same and raw != quiet,
		"raw/same-tick/quiescent domains must be distinct")
	for invalid: int in [-1, 0, 3, 9223372036854775807]:
		expect(world.get_liquid_comparison_hash(invalid) == "", "unknown projection must return no hash")
	var copy: Dictionary = _inspection(world, variant)
	copy.counters["water_material_calls"] = "tampered"
	copy.observed["indexed_chunks"] = "tampered"
	copy.requested_config["index_chunk_capacity"] = "tampered"
	var later: Dictionary = world.inspect_pressure_optimization()
	expect(later.counters.water_material_calls != "tampered" and later.observed.indexed_chunks != "tampered"
		and later.requested_config.index_chunk_capacity == "4096", "copied readback mutation leaked into the World")
	expect(world.get_physical_state_hash() == raw and bridge.export_physical_state(world) == bytes,
		"diagnostic readback changed authoritative continuation")

func _cohort(workers: int) -> bool:
	var before: int = failures
	var worlds: Array = []
	for variant: int in range(3):
		var world: Variant = _build(workers, variant, false)
		if world == null: return false
		worlds.append(world)
		var cold: Dictionary = _inspection(world, variant)
		expect(cold.status == ("cold" if variant > 0 else "disabled"), "fresh derived state is not cold/disabled")
		_getter_isolation(world, variant)
	_equal(worlds, "native configured%d cold" % workers)
	var raw_hashes: Array = []
	for world: Variant in worlds: raw_hashes.append(world.get_physical_state_hash())
	expect(raw_hashes[0] != raw_hashes[1] and raw_hashes[1] != raw_hashes[2], "raw hash must retain implementation policy identity")
	_advance(worlds, 24, "native configured%d awake" % workers)
	var reference: Dictionary = _inspection(worlds[0], 0)
	var cached: Dictionary = _inspection(worlds[1], 1)
	var dormant: Dictionary = _inspection(worlds[2], 2)
	for variant: int in range(3):
		work_observations.append({"workers":workers, "stage":"awake", "variant":VARIANTS[variant],
			"counters":worlds[variant].inspect_pressure_optimization().counters,
			"last_tick":worlds[variant].get_pressure_flow_ledger().last_tick})
	expect(cached.extension_identity_sha256 != dormant.extension_identity_sha256,
		"cached and dormant execution identities must remain distinct")
	expect(int(dormant.counters.certificate_reuses) > 0 and int(dormant.counters.certificate_saved_calls) > 0
		and int(dormant.counters.water_motion_calls) < int(reference.counters.water_motion_calls)
		and cached.counters.certificate_saved_calls == "0", "dormancy must remove real motion beyond the cached arm")
	expect(dormant.counters.water_material_calls == reference.counters.water_material_calls
		and dormant.counters.other_liquid_calls == reference.counters.other_liquid_calls
		and int(dormant.counters.other_liquid_calls) >= 24
		and int(bridge.inspect_cell(worlds[0], Vector2i(11, 12)).state_b) < 200,
		"mandatory stages/actual Oil lifecycle were lost")
	if workers == 4:
		expect(int(worlds[2].get_scheduler_parallel_phases_last_tick()) > 0,
			"configured4 fixture must actually dispatch a parallel phase")
	var copies: Array = []
	for variant: int in range(3):
		var restored: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(restored.diagnostic_reset({"workers":workers}), "restore execution configuration refused")
		var bytes: PackedByteArray = bridge.export_physical_state(worlds[variant])
		expect(bridge.import_physical_state(restored, bytes), "CYPS2 restore failed: " + str(bridge.get_last_error()))
		var state: Dictionary = _inspection(restored, variant)
		expect(state.status == ("cold" if variant > 0 else "disabled")
			and state.counters.certificate_saved_calls == "0", "restore retained derived certificate authority")
		expect(restored.get_physical_state_hash() == worlds[variant].get_physical_state_hash(), "restored authority differs")
		copies.append(restored)
	for step: int in range(8):
		_advance(worlds, 1, "warm continuation")
		_advance(copies, 1, "cold continuation")
		for variant: int in range(3):
			expect(copies[variant].get_physical_state_hash() == worlds[variant].get_physical_state_hash(),
				"cold/warm exact continuation differs")
		if step == 0:
			expect(copies[2].inspect_pressure_optimization().counters.certificate_saved_calls == "0",
				"first restored visit must execute ordinary motion before expensive proof")
	for world: Variant in worlds:
		for offset: int in [0, 128, 256, 384]:
			expect(world.diagnostic_fill_rect(Vector2i(offset + 11, 12), Vector2i.ONE, 1, 0), "quiet control wall edit failed")
	_advance(worlds, 8, "ordinary sleep control")
	for variant: int in [1, 2]: expect(_inspection(worlds[variant], variant).status == "ready", "quiet derived snapshot never becomes ready")
	var quiet: String = worlds[0].get_liquid_comparison_hash(2)
	var raw: String = worlds[0].get_physical_state_hash()
	_advance(worlds, 8, "quiescent diagnostic")
	expect(worlds[0].get_liquid_comparison_hash(2) == quiet and worlds[0].get_physical_state_hash() != raw,
		"quiescent diagnostic must preserve static content without erasing the complete clock")
	return failures == before

func _gas_cohort(workers: int) -> bool:
	var before: int = failures
	var worlds: Array = []
	for variant: int in range(3):
		var world: Variant = _build(workers, variant, true)
		if world == null: return false
		worlds.append(world)
	_advance(worlds, 8, "native gas fixed point")
	var sealed: Dictionary = worlds[0].inspect_gas_compartments()
	for variant: int in range(3):
		work_observations.append({"workers":workers, "stage":"sealed_gas", "variant":VARIANTS[variant],
			"counters":worlds[variant].inspect_pressure_optimization().counters,
			"last_tick":worlds[variant].get_pressure_flow_ledger().last_tick})
	expect(sealed.compartments.size() == 1 and int(sealed.compartments[0].volume) == 100,
		"actual sealed compartment control missing")
	for variant: int in [1, 2]: expect(int(_inspection(worlds[variant], variant).counters.gas_reuses) > 0, "gas fixed point not reused")
	for world: Variant in worlds:
		expect(world.water_experiment_erase_rect(Vector2i(13, 8), Vector2i.ONE), "native vent edit failed")
	_advance(worlds, 2, "native vent invalidation")
	expect(worlds[0].inspect_gas_compartments().compartments.is_empty(), "remote vent did not retire the sealed identity")
	for world: Variant in worlds:
		expect(world.diagnostic_fill_rect(Vector2i(13, 8), Vector2i.ONE, 1, 0), "native reseal edit failed")
	_advance(worlds, 4, "native reseal invalidation")
	expect(worlds[0].inspect_gas_compartments().compartments.size() == 1, "native reseal did not rebuild a compartment")
	return failures == before

func _defaults_preserved(workers: int) -> bool:
	var before: int = failures
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":workers}), "Current reset failed")
	var receipt: Dictionary = world.get_liquid_solver_policy()
	expect(receipt.policy_hash == bridge.validate_liquid_policy(defaults).receipt.policy_hash
		and receipt.envelope == defaults and receipt.admission == "current_defaults_only", "Current default identity changed")
	for row: Dictionary in receipt.assignments:
		expect(row.applied_family == ("freemass_v1" if int(row.material) == 3 else "cellular_yield_v1")
			and row.applied_variant == "reference", "existing material default changed")
	var facts: Dictionary = world.inspect_pressure_optimization()
	expect(not facts.available and not facts.cached and not facts.dormant and facts.status == "disabled"
		and facts.observed.derived_capacity_bytes == "0" and facts.extension_identity_sha256 == "",
		"Current World acquired pressure optimization storage/identity")
	expect(world.get_liquid_comparison_hash(0) == "" and str(world.get_liquid_comparison_hash(1)).length() == 16
		and int(world.get_physical_state_hash_version()) == 2, "default diagnostic/hash identity differs")
	return failures == before
