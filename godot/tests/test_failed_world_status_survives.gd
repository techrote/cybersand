extends SceneTree

# Actual native exceptions, not a claim to reproduce the owner's crest trigger.
# The diagnostic state-domain witness aborted the baseline GDExtension process.
const CAPACITY := "cybersand/native_active_core_capacity"
const MAX_I64: int = 9223372036854775807
const MIN_I64: int = -9223372036854775807 - 1
var checks := 0
var failures: Array[String] = []
var faults: Array[Dictionary] = []
var sections := {"native_exception":false,"capacity_failure":false,
	"failed_observation":false,"failed_mutation":false,"first_error":false,
	"reset_recovery":false,"healthy_refusals":false,"numeric_boundaries":false}

func _init() -> void:
	run.call_deferred()

func require(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("FAILED_WORLD_STATUS: " + detail)
	return ok

func remains_failed(world: Variant, error: String, count: int, label: String) -> void:
	require(world.has_failed(),label+" retains quarantine")
	require(str(world.get_last_tick_error()) == error,label+" retains first error")
	require(int(world.get_tick_failure_count()) == count,label+" counts the fault once")

func probe_failed(world: Variant, label: String) -> void:
	var first_error: String = world.get_last_tick_error()
	var first_count: int = world.get_tick_failure_count()
	var revision: int = world.get_revision()
	var tick: int = world.get_tick_index()
	var window_enabled: bool = world.get_simulation_window_enabled()
	var cadence_enabled: bool = world.get_cadence_lod_enabled()
	var adhesion_enabled: bool = world.get_liquid_surface_adhesion_enabled()
	require(world.has_failed() and not first_error.is_empty() and first_count == 1,label+" has one diagnosed fault")
	var before := failures.size()
	require(world.get_wave_flow_status().get("healthy",true) == false,label+" Wave status reports failed")
	require(not world.get_water_spray().is_empty(),label+" spray status safely returns")
	for invocation: Array in [
		["get_water_experiment_policy",[],TYPE_DICTIONARY],["get_liquid_solver_policy",[],TYPE_DICTIONARY],
		["inspect_wave_flow_cell",[Vector2i(16,16)],TYPE_DICTIONARY],
		["inspect_inertial_cell",[Vector2i(16,16)],TYPE_DICTIONARY],
		["inspect_pressure_cell",[Vector2i(16,16)],TYPE_DICTIONARY],
		["inspect_pressure_optimization",[],TYPE_DICTIONARY],
		["inspect_gas_compartments",[],TYPE_DICTIONARY],["get_pressure_flow_ledger",[],TYPE_DICTIONARY],
		["get_physical_state_hash",[],TYPE_STRING],
		["get_liquid_comparison_hash",[1],TYPE_STRING],["get_liquid_run_receipt",[{}],TYPE_DICTIONARY],
		["water_experiment_observation",[Vector2i.ZERO,Vector2i(32,32)],TYPE_DICTIONARY],
		["diagnostic_snapshot",[Vector2i.ZERO,Vector2i(32,32),true],TYPE_DICTIONARY],
		["diagnostic_body_metrics",[],TYPE_ARRAY],["inspect_ballistic_parcels",[8],TYPE_PACKED_FLOAT64_ARRAY],
		["get_cells",[],TYPE_PACKED_BYTE_ARRAY],
		["get_hard_surface_rectangles",[],TYPE_PACKED_INT32_ARRAY],
		["get_hard_surface_chunk_rectangles",[],TYPE_PACKED_INT32_ARRAY],
		["diagnostic_full_hard_surface_chunk_rectangles",[],TYPE_PACKED_INT32_ARRAY],
		["diagnostic_hard_surface_packet_stats",[],TYPE_DICTIONARY],
		["get_default_demo_identity",[],TYPE_DICTIONARY],
		["get_liquid_construction_attempt",[],TYPE_DICTIONARY],
		["get_applied_liquid_construction_receipt",[],TYPE_DICTIONARY],
		["rigid_body_results",[],TYPE_PACKED_FLOAT32_ARRAY],["workbench_coupling_results",[],TYPE_DICTIONARY]]:
		var observed: Variant = world.callv(invocation[0],invocation[1])
		require(typeof(observed) == int(invocation[2]),label+" safe typed read "+str(invocation[0]))
	require(world.take_render_snapshot(true).get("failed",false),label+" refuses a new render packet")
	# ADR-010: raw material reads keep the retained evidence of a failed World.
	var retained: int = world.stored_material_at(64,64)
	require(retained >= 0 and world.material_at(64,64) == retained and world.stored_material_at(-1,-1) == 1,
		label+" failed material queries read retained cells; out of bounds stays the Wall sentinel")
	require(world.box_collides(Vector2(64,64),Vector2.ONE),label+" collision query fails closed")
	for mode: int in 3:
		require(world.character_box_collides(Vector2(64,64),Vector2.ONE,mode),label+" character query fails closed")
	remains_failed(world,first_error,first_count,label+" reads")
	sections.failed_observation = failures.size() == before and (sections.failed_observation or faults.is_empty())
	before = failures.size()
	for repeat: int in 3:
		require(not world.simulation_tick(),label+" later tick refuses")
		require(not world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,3,0),label+" diagnostic write refuses")
		require(not world.diagnostic_relocate_cell(Vector2i(16,16),Vector2i(17,16)),label+" relocate refuses")
		require(not world.water_experiment_fill_rect(Vector2i(16,16),Vector2i.ONE,255,0),label+" Water write refuses")
		require(not world.water_experiment_erase_rect(Vector2i.ZERO,Vector2i(32,32)),label+" erase refuses")
		require(str(world.inject_water_parcel(Vector2(40,40),Vector2.ZERO,10)) == "world_failed",label+" parcel refuses")
		var field: Dictionary = world.apply_player_material_field(Vector2i(16,16),Vector2.ZERO,3,0,0)
		require(not field.get("accepted",true) and field.get("reason","") == "world_failed",label+" field refuses")
		world.emit_disc(16,16,0,3)
		world.paint_disc(16,16,0,0)
		require(world.character_disturb_granular(Vector2(16,16),Vector2(4,4),80.0) == 0,
			label+" character displacement refuses")
		world.prepare_rigid_body_coupling(PackedFloat32Array(),true)
		require(not world.prepare_workbench_coupling(PackedFloat64Array(),PackedFloat64Array(),[],1,1,true),
			label+" Workbench coupling refuses")
		world.water_spray_before_tick()
		world.set_water_spray({"enabled":false,"jet_enabled":false})
		world.set_interest_center(Vector2i(64,64))
		world.set_simulation_window(Vector2i.ZERO,Vector2i(64,64),MAX_I64,MAX_I64)
		world.set_simulation_window_enabled(not window_enabled)
		world.set_cadence_lod_enabled(not cadence_enabled)
		world.set_liquid_surface_adhesion_enabled(not adhesion_enabled)
		remains_failed(world,first_error,first_count,label+" subsequent calls %d" % repeat)
	require(world.get_revision() == revision and world.get_tick_index() == tick,label+" cannot advance revision/tick")
	require(world.get_simulation_window_enabled() == window_enabled
		and world.get_cadence_lod_enabled() == cadence_enabled
		and world.get_liquid_surface_adhesion_enabled() == adhesion_enabled,label+" cannot change execution settings")
	sections.failed_mutation = failures.size() == before and (sections.failed_mutation or faults.is_empty())
	before = failures.size()
	require(not world.diagnostic_reset({"displacement":-1.0}),label+" invalid replacement refuses")
	remains_failed(world,first_error,first_count,label+" invalid replacement")
	sections.first_error = failures.size() == before and (sections.first_error or faults.is_empty())
	faults.append({"operation":label,"error":first_error,"count":first_count,
		"completed_tick":tick,"attempted_tick":int(world.get_attempted_tick_index())})
	before = failures.size()
	require(world.diagnostic_reset({"extent":Vector2i(128,128)}),label+" explicit replacement succeeds")
	require(not world.has_failed() and world.get_tick_failure_count() == 0 and str(world.get_last_tick_error()).is_empty(),
		label+" successful replacement clears fault latch")
	require(world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,3,0),label+" replacement accepts Water")
	require(world.simulation_tick() and not world.has_failed(),label+" replacement advances")
	var coherence: int = int(world.get_water_experiment_policy().coherence_ticks)
	require(not world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,3,coherence+1)
		and world.has_failed() and world.get_tick_failure_count() == 1,label+" replacement can diagnose a fresh fault")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	require(bridge.build_world(world,PackedInt32Array([20,20,1,1,2])),label+" bridge replaces failed authority")
	require(not world.has_failed() and world.get_tick_failure_count() == 0 and str(world.get_last_tick_error()).is_empty(),
		label+" bridge installation clears fault latch")
	require(world.simulation_tick(),label+" bridge replacement advances")
	sections.reset_recovery = failures.size() == before and (sections.reset_recovery or faults.size() == 1)

func diagnostic_exception() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not require(world.diagnostic_reset({"extent":Vector2i(128,128)}),"diagnostic construction"): return
	var before := failures.size()
	var original: String = world.get_physical_state_hash()
	for request: Array in [[Vector2i(-1,0),Vector2i.ONE,3,0],[Vector2i.ZERO,Vector2i.ZERO,3,0],
		[Vector2i.ZERO,Vector2i.ONE,-1,0],[Vector2i.ZERO,Vector2i.ONE,3,256]]:
		require(not world.callv("diagnostic_fill_rect",request),"ordinary invalid request refuses before mutation")
	require(not world.diagnostic_relocate_cell(Vector2i(16,16),Vector2i(17,16)),"empty relocation refuses")
	require(not world.has_failed() and world.get_tick_failure_count() == 0 and world.get_physical_state_hash() == original,
		"ordinary refusal is atomic and does not quarantine")
	sections.healthy_refusals = failures.size() == before
	before = failures.size()
	var revision: int = world.get_revision()
	for centre: int in [MIN_I64,MAX_I64]:
		world.emit_disc(centre,centre,128,3)
		world.paint_disc(centre,centre,128,3)
	for position: Vector2 in [Vector2(1.0e30,10),Vector2(-1.0e30,10),Vector2(10,1.0e30),Vector2(10,-1.0e30)]:
		require(str(world.inject_water_parcel(position,Vector2.ZERO,10)) == "invalid_request",
			"unrepresentable Q256 parcel coordinate refuses")
	require(world.get_revision() == revision and world.get_physical_state_hash() == original,
		"extreme brush/parcel requests cannot mutate authority")
	world.set_simulation_window(Vector2i.ZERO,Vector2i(128,128),MAX_I64,MAX_I64)
	world.set_simulation_window(Vector2i.ZERO,Vector2i(128,128),MIN_I64,MIN_I64)
	require(not world.has_failed() and world.get_tick_failure_count() == 0 and world.simulation_tick(),
		"extreme buffers saturate safely and retain healthy World")
	buffer_region_parity()
	sections.numeric_boundaries = failures.size() == before
	before = failures.size()
	var policy: Dictionary = world.get_water_experiment_policy()
	require(not world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,3,int(policy.coherence_ticks)+1),
		"native state-domain exception returns false instead of escaping")
	require(world.has_failed() and str(world.get_last_tick_error()).contains("diagnostic_fill_rect failed:")
		and str(world.get_last_tick_error()).contains("experimental Water state out of domain"),
		"native exception quarantines with operation and original diagnosis")
	sections.native_exception = failures.size() == before
	probe_failed(world,"diagnostic_fill_rect")

func buffer_region_parity() -> void:
	var explicit: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var buffered: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	for world: Variant in [explicit,buffered]:
		require(world.diagnostic_reset({"extent":Vector2i(128,128)}),"buffer parity construction")
		require(world.diagnostic_fill_rect(Vector2i(96,16),Vector2i(4,4),2,0),"buffer parity Sand fixture")
		require(world.diagnostic_fill_rect(Vector2i(20,16),Vector2i(4,4),3,0),"buffer parity Water fixture")
		world.set_simulation_window_enabled(true)
		world.set_cadence_lod_enabled(false)
	explicit.set_simulation_window(Vector2i.ZERO,Vector2i(128,128),0,0)
	buffered.set_simulation_window(Vector2i(300,0),Vector2i(100,100),300,300)
	for step: int in 8:
		require(explicit.simulation_tick() and buffered.simulation_tick(),"off-canvas buffered World advances")
		require(explicit.get_physical_state_hash() == buffered.get_physical_state_hash()
			and explicit.get_cells() == buffered.get_cells(),"off-canvas buffer preserves full-region semantics")

func capacity_exception() -> void:
	var previous: Variant = ProjectSettings.get_setting(CAPACITY,null)
	ProjectSettings.set_setting(CAPACITY,1)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting(CAPACITY,previous)
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var before := failures.size()
	world.set_simulation_window(Vector2i.ZERO,Vector2i(320,180),0,0)
	if not require(bridge.build_world(world,PackedInt32Array([20,20,1,1,2])),"capacity construction"): return
	require(world.simulation_tick(),"capacity World initially advances")
	world.paint_disc(20,20,0,1)
	world.paint_disc(21,20,0,1)
	world.paint_disc(160,20,0,2)
	require(not world.simulation_tick(),"real capacity failure returns false")
	require(world.has_failed() and str(world.get_last_tick_error()).contains("active scheduling-core capacity exhausted"),
		"native capacity exception is retained")
	sections.capacity_failure = failures.size() == before
	probe_failed(world,"simulation_tick")

func run() -> void:
	diagnostic_exception()
	capacity_exception()
	print("FAILED_WORLD_STATUS ",JSON.stringify({"checks":checks,"failures":failures,"sections":sections,"faults":faults}))
	quit(0 if failures.is_empty() and sections.values().all(func(value: bool) -> bool: return value) else 1)
