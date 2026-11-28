extends SceneTree

# Exercises publication before and after real native fault containment, then
# an actual running Shared Workbench failure and full owner replacement.
const Worker = preload("res://scripts/simulation_worker.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const CAPACITY := "cybersand/native_active_core_capacity"

class LateFaultWorker:
	extends "res://scripts/simulation_worker.gd"
	var fault_after_copy := false
	var fault_injected := false

	func _take_native_render_snapshot(force_full: bool) -> Dictionary:
		var packet: Dictionary = super._take_native_render_snapshot(force_full)
		if fault_after_copy:
			fault_after_copy = false
			fault_injected = true
			var policy: Dictionary = _world.get_water_experiment_policy()
			_world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,3,int(policy.coherence_ticks)+1)
		return packet

var checks := 0
var failures: Array[String] = []
var sections := {"prepublication_fault":false,"late_publication_fault":false,
	"running_owner_failure":false,"restore_recovery":false}
var observations: Array[Dictionary] = []
var host: Control
var panel: Control
var recovered_ticks := 0

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("WORKBENCH_FAILURE_CONTAINMENT: "+detail)
	return ok

func publication_fault(late: bool) -> void:
	var label := "late_publication_fault" if late else "prepublication_fault"
	var before := failures.size()
	var owner: RefCounted = LateFaultWorker.new()
	require(not owner._thread.is_started(),"publication fixture has exclusive test ownership")
	require(owner._world.diagnostic_reset({"extent":Vector2i(128,128)}),"publication fixture native construction")
	owner._workbench_extent = Vector2i(128,128)
	require(owner._world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,1,0),"healthy publication contains a known cell")
	owner._publish_snapshot(0.0,true,0,true)
	var previous: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
	if not require(previous != null and not previous.simulation_failed,"last healthy publication exists"): return
	var old_cells: PackedByteArray = previous.cells.duplicate()
	var old_patches: PackedByteArray = previous.render_patch_cells.duplicate()
	require(old_patches.size() == 128 * 128 * 2,"healthy fixture has a complete retained baseline")
	var old_tick: int = previous.tick_index
	var old_revision: int = previous.world_revision
	var old_render_serial: int = previous.render_snapshot_serial
	if late:
		require(owner._world.diagnostic_fill_rect(Vector2i(30,30),Vector2i.ONE,3,0),"change is ready for partial publication")
		owner.fault_after_copy = true
	else:
		var policy: Dictionary = owner._world.get_water_experiment_policy()
		require(not owner._world.diagnostic_fill_rect(Vector2i(16,16),Vector2i.ONE,3,int(policy.coherence_ticks)+1),
			"native failure precedes publication")
	# _simulation_failed is intentionally still false: native quarantine must be
	# detected at both publication boundaries, including a fault after entry.
	require(not owner._simulation_failed,"owner had not already marked the failure")
	owner._publish_snapshot(0.0,true,0,true)
	var failed: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
	require(failed != null and failed.simulation_failed and failed.paused,label+" publishes paused failure")
	if failed == null: return
	require(owner.has_failed() and owner._world.has_failed(),label+" owner and native agree")
	require(not late or owner.fault_injected,"late exception actually occurred after render copy")
	require(failed.cells == old_cells and failed.render_patch_cells == old_patches,label+" retains last healthy cells")
	require(failed.tick_index == old_tick and failed.world_revision == old_revision
		and failed.render_snapshot_serial == old_render_serial,label+" retains last healthy identities")
	require(previous.cells == old_cells and previous.render_patch_cells == old_patches
		and not previous.simulation_failed,label+" leaves old immutable snapshot unchanged")
	require(failed.rigid_body_results.is_empty(),label+" publishes no partial body results")
	require(failed.tick_failure_count == 1 and str(failed.last_tick_error).contains("diagnostic_fill_rect failed:"),
		label+" preserves first native diagnosis")
	require(not owner.queue_emit_cells(PackedInt32Array([20,20]),3),label+" rejects new main-thread edits")
	var failure_serial: int = failed.serial
	for attempt: int in 3:
		owner._publish_snapshot(0.0,true,0,true)
		var again: CyberSimulationSnapshot = owner.take_latest_snapshot(-1)
		require(again.serial == failure_serial and again.last_tick_error == failed.last_tick_error
			and again.tick_failure_count == 1,label+" retained failure is stable")
	observations.append({"case":label,"failure_count":failed.tick_failure_count,
		"error":failed.last_tick_error,"late_fault_injected":owner.fault_injected,
		"previous_tick":old_tick,"published_tick":failed.tick_index})
	sections[label] = failures.size() == before

func idle() -> bool:
	return panel != null and not panel.applied.is_empty() and not panel.busy() \
		and host.pending_microscenario_apply.is_empty()

func generation() -> int:
	return int(host.latest_snapshot.render_world_generation) if host.latest_snapshot != null else -1

func wave() -> Dictionary:
	return host.tower_context.get("wave_flow",{})

func until(predicate: Callable, label: String, allow_failure := false) -> bool:
	var deadline := Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return require(true,label)
		if not allow_failure and is_instance_valid(host) and host.simulation_worker.has_failed(): break
		await process_frame
	return require(false,label+" / "+(str(host.microscenario_error) if is_instance_valid(host) else "no host"))

func running_owner() -> void:
	var before := failures.size()
	var previous: Variant = ProjectSettings.get_setting(CAPACITY,null)
	ProjectSettings.set_setting(CAPACITY,1)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	ProjectSettings.set_setting(CAPACITY,previous)
	root.add_child(host)
	current_scene = host
	panel = host.shared_workbench
	if not await until(idle,"capacity-one Workbench installed"): return
	panel.water_spray._set_wave(true)
	panel.water_spray._set_spill("workbench_wave_spill_parcels",true)
	panel.water_spray._set_spill("workbench_wave_spill_full_face",true)
	host.workbench_water_options.workbench_wave_spill_fall = 5
	host.workbench_water_options.workbench_wave_spill_deep_draw = 27
	host.workbench_water_options.workbench_wave_body_push = 0
	host.workbench_water_options.workbench_wave_body_push_by_mass = 0
	var recipe: Dictionary = Setup.fresh(panel._liquids.bridge.default_liquid_policy(),Vector2i(512,512))
	recipe.edits = [[20,20,8,8,Setup.SAND],[160,20,8,8,Setup.SAND],
		[0,240,256,4,Setup.WALL],[0,0,4,240,Setup.WALL],[252,0,4,240,Setup.WALL],
		[4,160,104,80,Setup.WATER],[108,220,144,20,Setup.WATER]]
	var old_generation := generation()
	if not require(panel.apply(recipe),"hybrid zero-Body-push fixture admitted"): return
	if not await until(func() -> bool: return idle() and generation()>old_generation,"hybrid fixture installed"): return
	var accepted: Dictionary = wave().duplicate(true)
	require(accepted.get("enabled",false) and accepted.get("spill",{}).get("enabled",false)
		and accepted.get("spill",{}).get("parcels",false),"actual native Wave spill and ballistic release")
	require(int(accepted.get("parameters",{}).get("body_push",-1)) == 0
		and int(accepted.get("parameters",{}).get("body_push_by_mass",-1)) == 0,"actual zero Body push configuration")
	var old_id := host.get_instance_id()
	var old_worker: RefCounted = host.simulation_worker
	require(old_worker._thread.is_started(),"real native owner thread is running")
	var healthy: CyberSimulationSnapshot = host.latest_snapshot
	var healthy_cells: PackedByteArray = healthy.cells.duplicate()
	if not require(panel.step_once(),"real failing native tick requested"): return
	if not await until(func() -> bool: return old_worker.has_failed() and host.latest_snapshot.simulation_failed,
		"native capacity failure published by running owner",true): return
	var failed: CyberSimulationSnapshot = host.latest_snapshot
	require(failed.paused and failed.tick_failure_count == 1,"running failure pauses and counts once")
	require(str(failed.last_tick_error).contains("active scheduling-core capacity exhausted"),"real capacity diagnosis retained")
	require(failed.cells == healthy_cells and healthy.cells == healthy_cells and not healthy.simulation_failed,
		"running owner retains immutable last healthy terrain")
	require(failed.rigid_body_results.is_empty(),"running owner drops body impulses")
	require(not old_worker.queue_emit_cells(PackedInt32Array([20,20]),3),"running failed owner refuses queued edits")
	panel.water_spray.refresh(host.tower_context)
	require(panel.water_spray._wave_status.text.contains("NATIVE WORLD FAILED"),"Water Lab visibly reports quarantine")
	observations.append({"case":"running_owner","error":failed.last_tick_error,"failure_count":failed.tick_failure_count,
		"native":accepted})
	sections.running_owner_failure = failures.size() == before
	before = failures.size()
	# Unsubmitted edits must not replace the accepted configuration during recovery.
	host.workbench_water_options.workbench_wave_spill_full_face = false
	host.workbench_water_options.workbench_wave_spill_fall = 3
	host.workbench_water_options.workbench_wave_spill_deep_draw = 64
	host.workbench_water_options.workbench_wave_body_push = 1024
	host.workbench_water_options.workbench_wave_flow = false
	if not require(panel.restore_start(),"Restore start requests fresh owner"): return
	if not await until(func() -> bool: return current_scene != null and current_scene.get_instance_id()!=old_id,
		"failed Main replaced",true): return
	host = current_scene
	panel = host.shared_workbench
	if not await until(idle,"recovered Workbench installed"): return
	require(not old_worker._thread.is_started(),"failed thread joined before replacement")
	require(host.simulation_worker != old_worker and not host.simulation_worker.has_failed() and host.paused,
		"replacement is a distinct healthy paused owner")
	require(wave().get("enabled",false) and wave().get("spill",{}).get("parcels",false)
		and wave().spill.get("full_face") == true and wave().spill.get("fall") == 5 and wave().spill.get("deep_draw") == 27
		and int(wave().get("parameters",{}).get("body_push",-1)) == 0,
		"recovery retains accepted full-face release, fall speed and zero Body push")
	require(host.latest_snapshot.tick_failure_count == 0 and str(host.latest_snapshot.last_tick_error).is_empty(),
		"replacement clears prior diagnosis")
	var quantity: String = wave().get("water_quantity","missing")
	for step: int in 4:
		var tick: int = host.latest_snapshot.tick_index
		if not require(panel.step_once(),"recovered step admitted"): return
		if not await until(func() -> bool: return idle() and host.latest_snapshot.tick_index>=tick+1,"recovered tick acknowledged"): return
		require(host.latest_snapshot.tick_index == tick+1,"recovered step advances exactly once")
		require(str(wave().get("water_quantity","missing")) == quantity,"recovered hybrid Water conserved")
		recovered_ticks += 1
	sections.restore_recovery = failures.size() == before

func run() -> void:
	publication_fault(false)
	publication_fault(true)
	root.size = Vector2i(1600,900)
	await running_owner()
	for key: String in sections:
		require(bool(sections[key]),"required section completed: "+key)
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame
	print("WORKBENCH_FAILURE_CONTAINMENT ",JSON.stringify({"checks":checks,"failures":failures,
		"sections":sections,"real_workbench":true,"recovered_ticks":recovered_ticks,"observations":observations}))
	quit(0 if failures.is_empty() else 1)
