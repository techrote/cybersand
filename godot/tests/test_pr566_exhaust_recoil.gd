extends SceneTree

# PR #566 isolated diagnostic: real Main, manually stepped Rapier, native World,
# ordinary Workbench nozzle admission, and uploaded material/pose publication.
# This is not a renderer surrogate and never edits or supplies a fake World.
const Setup = preload("res://scripts/workbench_setup.gd")
const WATCHDOG_MS: int = 120000
const SAMPLE_TICKS: int = 220
const FIRE_BEGIN: int = 40
const FIRE_END: int = 100

class PilotHost extends "res://scripts/main.gd":
	var pilot_action: Dictionary = {}
	var pilot_ports := {"q":false,"e":false,"s":false,"boost":true}

	func _publish_workbench_keyboard() -> void:
		if pilot_action.is_empty() or paused or shared_workbench == null or physical_actor_session == null:
			return
		physical_actor_session.submit_workbench_action(shared_workbench.selected_id(),
			pilot_action,pilot_ports,shared_workbench.fire_enabled)

var host: Control
var ui: Control
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var emitter_events: Array[Dictionary] = []
var emitter_seen: Dictionary = {}
var actual_fire_inserts: int = 0
var valid_native_frames: int = 0
var recoil_suppression: bool = false
var trial: String = "nofire"


func _initialize() -> void:
	_run.call_deferred()


func verify(ok: bool, reason: String) -> bool:
	checks += 1
	if not ok:
		failures.append(reason)
		push_error("PR566_RECOIL: " + reason)
	return ok


func _xy(value: Variant) -> Array:
	if value is Vector2:
		return [float(value.x),float(value.y)]
	return [0.0,0.0]


func _wait_for(predicate: Callable, timeout_ms: int = WATCHDOG_MS) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): break
		await process_frame
	return false


func _read_emitters() -> void:
	for item: Variant in host.tower_context.get("workbench_emitters",[]):
		if not item is Dictionary or not item.has("nozzle"): continue
		var receipt: Dictionary = item
		var key: String = "%d/%d/%d/%s" % [
			int(receipt.get("epoch",-1)),int(receipt.get("sequence",-1)),
			int(receipt.get("tick",-1)),str(receipt.get("nozzle",""))]
		if emitter_seen.has(key): continue
		emitter_seen[key] = true
		var event := {"key":key,"nozzle":str(receipt.nozzle),
			"tick":int(receipt.get("tick",-1)),
			"material":int(receipt.get("material",-1)),
			"changed_cells":int(receipt.get("changed_cells",0)),
			"reason":str(receipt.get("reason",""))}
		emitter_events.append(event)
		if event.material == 6 and event.changed_cells > 0:
			actual_fire_inserts += 1


func _measure(relative_tick: int) -> Dictionary:
	var state: Dictionary = host.physical_actor_session.workbench_actor_state(1)
	var gcr: Dictionary = host.tower_context.get("workbench_gcr",{})
	var body_row: Dictionary = {}
	for item: Variant in gcr.get("rows",[]):
		if item is Dictionary and int(item.get("instance_id",-1)) == 1:
			body_row = item
			break
	if not body_row.is_empty() and bool(gcr.get("valid",false)):
		valid_native_frames += 1
	var accepted: Dictionary = {}
	var application: Dictionary = host.physical_actor_session.bridge.last_application
	for item: Variant in application.get("bodies",[]):
		if item is Dictionary and int(item.get("instance_id",-1)) == 1:
			accepted = item
			break
	var display_frame: Dictionary = host.workbench_display_frame()
	var shown: Dictionary = display_frame.get("instances",{}).get(1,{})
	var pose: Variant = shown.get("pose")
	var controller: Dictionary = state.get("controller",{})
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	return {
		"tick":relative_tick,
		"rapier_tick":host.physical_actor_session.tick,
		"timestamp_usec":Time.get_ticks_usec(),
		"fire_requested":ui.fire_enabled,
		"position":_xy(state.get("position",Vector2.ZERO)),
		"velocity":_xy(state.get("linear_velocity",Vector2.ZERO)),
		"rotation":float(state.get("rotation",0.0)),
		"angular_velocity":float(state.get("angular_velocity",0.0)),
		"controller_force":_xy(controller.get("applied_force",Vector2.ZERO)),
		"controller_thrust":float(controller.get("thrust",0.0)),
		"native_valid":bool(gcr.get("valid",false)),
		"native_sample":int(body_row.get("sample",-1)),
		"native_contacts":int(body_row.get("contacts",0)),
		"native_unresolved":int(body_row.get("unresolved",0)),
		"native_displaced":int(body_row.get("displaced",0)),
		"native_impulse":_xy(body_row.get("impulse",Vector2.ZERO)),
		"native_exhaust_fire_unresolved":int(body_row.get("diag_exhaust_unresolved_fire",-1)),
		"native_exhaust_smoke_unresolved":int(body_row.get("diag_exhaust_unresolved_smoke",-1)),
		"native_exhaust_unresolved_raw_impulse":_xy(body_row.get(
			"diag_exhaust_unresolved_raw_impulse",Vector2.ZERO)),
		"native_exhaust_recoil_suppressed":bool(body_row.get("diag_exhaust_unresolved_recoil_suppressed",false)),
		"application_sample":int(accepted.get("sample",-1)),
		"application_refusal":str(accepted.get("refusal","")),
		"applied_impulse":_xy(accepted.get("impulse",Vector2.ZERO)),
		"applied_torque":float(accepted.get("torque",0.0)),
		"camera_origin":_xy(host.presentation_camera_origin()),
		"display_frame_sample":int(shown.get("sample",-1)),
		"display_position":_xy(pose.origin if pose is Transform2D else Vector2.INF),
		"world_revision":int(snapshot.world_revision) if snapshot != null else -1,
		"uploaded_revision":int(host.last_uploaded_revision),
		"render_serial":int(host.last_uploaded_render_snapshot_serial),
		"render_hz_actual":float(host.measured_render_publication_hz)
	}


func _run() -> void:
	trial = OS.get_environment("CYBERSAND_RECOIL_TRIAL")
	if trial.is_empty(): trial = "nofire"
	recoil_suppression = OS.get_environment("CYBERSAND_DIAG_SUPPRESS_EXHAUST_UNRESOLVED_RECOIL") == "1"
	if not verify(trial in ["nofire","fire"],"trial must be nofire or fire"):
		quit(1)
		return
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(PilotHost)
	root.add_child(host)
	ui = host.shared_workbench
	if verify(await _wait_for(func() -> bool: return ui != null and not ui.applied.is_empty()),
			"default Workbench installed"):
		var config: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
		config.actors = [Setup.instance("kestrel",1,Vector2(240,260))]
		config.next_id = 2
		config.selected = 1
		config.fire = false
		if not host.paused: ui.toggle_pause()
		var old_epoch: int = host._physical_epoch
		if verify(ui.apply(config),"isolated clean native/Rapier flight prepared"):
			if verify(await _wait_for(func() -> bool:
					return host.pending_microscenario_apply.is_empty() and host._physical_epoch > old_epoch and host.physical_actor_session != null and host._physical_terrain_ready),
					"isolated native/Rapier World installed"):
				host.pilot_action = {"move":Vector2(0.0,-1.0),"trim":0.45,
					"primary":true,"effort":1.0}
				verify(ui.toggle_pause(),"begin actual 60Hz Rapier flight")
				var starting_tick: int = host.physical_actor_session.tick
				var last_seen: int = -1
				var deadline: int = Time.get_ticks_msec() + WATCHDOG_MS
				while host.physical_actor_session.tick - starting_tick < SAMPLE_TICKS and \
						Time.get_ticks_msec() < deadline and not host.simulation_worker.has_failed():
					await process_frame
					var elapsed: int = host.physical_actor_session.tick - starting_tick
					if elapsed == last_seen: continue
					last_seen = elapsed
					var should_fire: bool = trial == "fire" and elapsed >= FIRE_BEGIN and elapsed < FIRE_END
					if ui.fire_enabled != should_fire:
						ui._fire.set_pressed(should_fire)
					_read_emitters()
					var record: Dictionary = _measure(elapsed)
					observations.append(record)
					if elapsed % 30 == 0:
						print("PR566_RECOIL_SAMPLE ",JSON.stringify(record))
				host.pilot_action.clear()
				if ui.fire_enabled: ui._fire.set_pressed(false)
				verify(last_seen >= SAMPLE_TICKS,"completed controlled 220-tick real Rapier flight")
				verify(valid_native_frames > 12,"native response telemetry was actually published")
				if trial == "fire":
					verify(actual_fire_inserts > 0,"real Fire emitted by the Workbench nozzle")
				else:
					verify(actual_fire_inserts == 0,"no-Fire control emitted no Fire")
				if not observations.is_empty():
					var seen_suppression: bool = false
					for row: Dictionary in observations:
						if row.native_exhaust_fire_unresolved < 0: continue
						seen_suppression = true
						verify(row.native_exhaust_recoil_suppressed == recoil_suppression,
							"native diagnostic mode agrees with process environment")
						break
					verify(seen_suppression,"source-built native diagnostic fields present")
	host.queue_free()
	await process_frame
	await process_frame
	var report := {
		"case":"PR566_REAL_RAPIER_EXHAUST_RECOIL",
		"source_parent":"214de85adef2aaabc8e26de8612a3bf27cc1a081",
		"trial":trial,"diagnostic_suppression":recoil_suppression,
		"godot":Engine.get_version_info().string,
		"os":OS.get_name(),"checks":checks,"failures":failures,
		"fire_begin_tick":FIRE_BEGIN,"fire_end_tick":FIRE_END,
		"intended_steps":SAMPLE_TICKS,
		"native_frames":valid_native_frames,
		"actual_fire_inserts":actual_fire_inserts,
		"emitters":emitter_events,"samples":observations
	}
	var output: String = OS.get_environment("CYBERSAND_RECOIL_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		verify(file != null,"diagnostic report open")
		if file != null:
			file.store_string(JSON.stringify(report,"  "))
			file.flush()
			file.close()
	print("PR566_RECOIL_END ",JSON.stringify({
		"trial":trial,"suppressed":recoil_suppression,
		"fire_inserts":actual_fire_inserts,"samples":observations.size(),
		"native_frames":valid_native_frames,"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
