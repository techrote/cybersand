extends Node

# Main-thread lifecycle and game-time owner for the opt-in three-area profile.
# All World calls go through the existing simulation worker. Blocking profile
# I/O is serialized on a separate thread, while the native lease keeps its
# authoritative source frozen. No material/seed reconstruction occurs on load.
const Fixtures = preload("res://scripts/persistent_area_fixtures.gd")
const AreaClock = preload("res://scripts/persistent_area_clock.gd")
const AreaStore = preload("res://scripts/persistent_area_store.gd")
const AreaPanel = preload("res://scripts/persistent_areas_panel.gd")
const PROFILE_ID := "gen006-three-areas-v1"
const DOMAIN_ID := "gen006-current-freemass-512-cyps2-v1"
const MAX_OPERATION_TICKS := 600
const MAX_CATCH_UP_MSEC := 3000
const MAX_NATIVE_SLICE_TICKS := 32
const MAX_NATIVE_SLICE_USEC := 100000
const OWNER_WAIT_MSEC := 30000

var host: Control
var panel: Control
var active_ready := false
var busy := false
var active_area := ""
var lifecycle := "Loading"
var message := "Opening the persistent-area profile…"
var profile_path := ""
var manifest: Dictionary = {}
var clock: Dictionary = AreaClock.fresh()
var operation: Dictionary = {}
var last_result: Dictionary = {}
# Qualification-only observation. Empty in the product. A test may request at
# most five seconds of yielding at a proven durable boundary so an external
# process can terminate the application there; no simulated tick is credited.
var qualification_boundary_hook := Callable()
# Observation-only tag supplied by qualification fixtures; never saved as area state.
var qualification_measurement_tag := ""
# Optional qualification-only payload/disk observations; no inventory I/O or
# serialization occurs in normal interactive execution.
var qualification_resource_hook := Callable()
var metrics: Dictionary = {"capture_ms":[],"durable_ms":[],"restore_ms":[],"operation_ms":[],
	"native_capture_us":[],"native_step_us":[],"completed_ticks":[],"max_main_frame_ms":0.0,
	"operation_records":[],"native_slices":[]}
var _store := AreaStore.new()
var _io_thread: Thread
var _io_busy := false
var _cancel_requested := false
var _resume_play := false
var _recovery_available := false
var _quarantined := false
var _candidate_durable := false
var _candidate_committed := false
var _current_worker_token := 0
var _unresolved_worker: Dictionary = {}
var _owner_cleanup_required := false
var _owner_recovery_requires_restore := false
var _last_world_generation := -1
var _last_clock_snapshot_serial := -1
var _last_ui_msec := 0
var _last_process_usec := 0
var _events: Array[Dictionary] = []
var _resource_samples: Array[Dictionary] = []
var _measurement_terminal_sequence := 0
var _measurement_slice_sequence := 0
var _native_library := ""
var _exit_destination := ""
var _profile_open := false
var _lease_held := false
var _start_paused := false
var _publication_uncertain := false
var _force_profile_reopen := false


func setup(controller: Control) -> void:
	host = controller
	name = "PersistentAreasController"
	panel = AreaPanel.new()
	var layout: Control = host.get_node("Layout")
	layout.add_child(panel)
	layout.move_child(panel,0)
	panel.travel_requested.connect(request_travel)
	panel.ahead_requested.connect(request_ahead)
	panel.catch_up_requested.connect(request_catch_up)
	panel.save_requested.connect(request_save)
	panel.exit_requested.connect(func() -> void: request_exit("launcher"))
	panel.cancel_requested.connect(request_cancel)
	panel.retry_requested.connect(request_retry)
	panel.recovery_requested.connect(request_recovery)
	_configure_profile_controls()
	profile_path = ProjectSettings.globalize_path("user://persistent-areas/three-areas-v1")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--persistent-profile="):
			profile_path = ProjectSettings.globalize_path(argument.trim_prefix("--persistent-profile="))
	_start_paused = "--persistent-start-paused" in OS.get_cmdline_user_args()
	_native_library = "res://addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so")
	_begin("open","a")
	_open_profile.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_process_usec > 0:
		metrics.max_main_frame_ms = maxf(float(metrics.max_main_frame_ms),float(now-_last_process_usec)/1000.0)
	_last_process_usec = now
	if active_ready and not busy and host.latest_snapshot != null \
			and int(host.latest_snapshot.serial) > _last_clock_snapshot_serial:
		_last_clock_snapshot_serial = int(host.latest_snapshot.serial)
		var generation: int = int(host.latest_snapshot.render_world_generation)
		if _last_world_generation >= 0 and generation != _last_world_generation:
			host.paused = true
			host.update_worker_frame_state()
			active_ready = false
			_quarantined = true
			_set_phase("Failed / quarantined","The native World changed outside the persistent-area transaction. The World is paused; retry the retained profile.")
		else:
			var observed := AreaClock.active(clock,active_area,int(host.latest_snapshot.tick_index))
			if observed.get("ok",false): clock = observed.clock
			else:
				active_ready = false
				_quarantined = true
				host.paused = true
				host.update_worker_frame_state()
				_set_phase("Failed / quarantined",str(observed.error))
	if Time.get_ticks_msec()-_last_ui_msec >= 100:
		_last_ui_msec = Time.get_ticks_msec()
		_refresh_panel()


func status() -> Dictionary:
	var areas := {}
	for id: String in Fixtures.IDS:
		areas[id] = {"accounted_tick":int(clock.areas[id].accounted_ticks),
			"debt_ticks":AreaClock.debt(clock,id),
			"state":"Active" if id == active_area and active_ready else ("Inactive / durable" if manifest.get("areas",{}).has(id) else "Not initialized")}
	return {"ready":active_ready,"busy":busy,"active_area":active_area,"state":lifecycle,"message":message,
		"profile":profile_path,"session_id":manifest.get("session_id",""),
		"durable_generation":int(manifest.get("revision",0)),"game_tick":int(clock.game_ticks),
		"accounted_tick":int(clock.areas.get(active_area,{}).get("accounted_ticks",0)),
		"debt_ticks":maxi(0,AreaClock.debt(clock,active_area)),"areas":areas,
		"operation":operation.duplicate(true),"recovery_available":_recovery_available,
		"quarantined":_quarantined,"publication_uncertain":_publication_uncertain,
		"owner_cleanup_required":_owner_cleanup_required,"unresolved_worker":_unresolved_worker.duplicate(true)}


func evidence() -> Dictionary:
	return {"status":status(),"clock":clock.duplicate(true),"manifest":manifest.duplicate(true),
		"metrics":metrics.duplicate(true),"last_result":last_result.duplicate(true),"events":_events.duplicate(true),
		"retained_area_resources":_resource_samples.duplicate(true)}


func operation_allowed(action: String, _payload: Dictionary = {}) -> String:
	if busy: return "Persistent-area " + lifecycle.to_lower() + " is in progress; wait or cancel at the safe boundary."
	if not active_ready: return "The persistent profile is not active: " + message
	if action in ["authoring","paint","art","flatten","save","camera","pause","step"]: return ""
	return "This fixed persistent-area profile admits material edits, Art, Flatten and editor/camera travel. Native replacement, solver changes, actors and host emitters require the ordinary Workbench."


func request_travel(area_id: String) -> bool:
	if not area_id in Fixtures.IDS: return _refuse("Unknown persistent area.")
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	if area_id == active_area: return _refuse("This area is already active; use Pay catch-up debt or Simulate Ahead.")
	_begin("travel",area_id)
	_run_operation.call_deferred(0)
	return true


func request_ahead(ticks: int) -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	if ticks < 1 or ticks > AreaClock.MAX_AHEAD_TICKS: return _refuse("Choose a finite Simulate Ahead duration within ten minutes.")
	_begin("ahead",active_area)
	_run_operation.call_deferred(ticks)
	return true


func request_catch_up() -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	if AreaClock.debt(clock,active_area) <= 0: return _refuse("The active area has no catch-up debt.")
	_begin("catch_up",active_area)
	_run_operation.call_deferred(0)
	return true


func request_save() -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	_begin("save",active_area)
	_run_operation.call_deferred(0)
	return true


func request_exit(destination: String) -> bool:
	if not destination in ["launcher","quit"]: return false
	if busy: return _refuse("Finish or cancel the current operation before leaving the persistent profile.")
	if _owner_cleanup_required or not _unresolved_worker.is_empty():
		return _refuse("The native owner has an unresolved completion. Retry its acknowledgement before leaving; the World remains paused.")
	if not active_ready:
		if not active_area.is_empty() and not _candidate_durable:
			return _refuse("The live area is quarantined and has no newly confirmed durable checkpoint. Retry or repair the profile before leaving; the current World remains available.")
		# A refused profile must never be replaced with seed data during exit.
		# Existing durable bytes are untouched; there is no active editable area.
		_begin("close",active_area)
		_exit_destination = destination
		_close_without_save.call_deferred()
		return true
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	_exit_destination = destination
	_begin("exit",active_area)
	_run_operation.call_deferred(0)
	return true


func request_cancel() -> void:
	if not busy: return
	_cancel_requested = true
	operation.cancel_requested = true
	operation.detail = "Cancelling at the next safe boundary. A durable publication already in progress must finish."
	_refresh_panel()


func request_retry() -> bool:
	if busy or active_ready: return false
	if _owner_cleanup_required or not _unresolved_worker.is_empty():
		# Keep the old identity until its exact request has completed and its
		# lease has been retired. A new operation cannot clean up an old owner.
		busy = true
		_set_phase("Loading","Checking the retained native operation before retrying…")
		_retry_owner.call_deferred()
		return true
	_begin("retry",str(manifest.get("active_area","a")))
	_retry_profile.call_deferred()
	return true


func request_recovery() -> bool:
	if busy or active_ready or not _recovery_available: return false
	if _owner_cleanup_required or not _unresolved_worker.is_empty():
		return _refuse("Retry the unresolved native owner before selecting a different durable checkpoint.")
	_begin("recover",str(manifest.get("active_area","a")))
	_recover_profile.call_deferred()
	return true


func _begin(kind: String, target: String) -> void:
	busy = true
	_cancel_requested = false
	_candidate_durable = false
	_candidate_committed = false
	_resume_play = not host.paused if active_ready else not _start_paused
	operation = {"kind":kind,"operation_id":AreaStore.new_nonce(),"source_area":active_area,
		"target_area":target,"requested_ticks":0,"completed_ticks":0,"remaining_future_ticks":0,
		"started_msec":Time.get_ticks_msec(),"cancellable":kind not in ["open","close","recover","retry"],
		"cancel_requested":false,"detail":"Freezing the active owner at a native boundary…",
		"measurement_tag":qualification_measurement_tag,"measurement_totals":{},
		"native_ticks_executed":0,"native_slice_count":0,
		"game_tick_before":int(clock.game_ticks),"debt_before_ticks":AreaClock.debt(clock,target),
		"target_native_tick_before":int(clock.areas.get(target,{}).get("native_ticks",-1))}
	host.paused = true
	if host.shared_workbench != null: host.shared_workbench.cancel_stroke()
	host.update_worker_frame_state()
	_set_phase("Transition requested",operation.detail)


func _open_profile() -> void:
	_set_phase("Loading","Opening the isolated profile and verifying its runtime and storage identities…")
	var opened := await _io("_open_with_identity",[profile_path,_native_library])
	if not opened.get("ok",false):
		_recovery_available = bool(opened.get("recovery_available",false))
		if opened.get("manifest") is Dictionary: manifest = opened.manifest
		await _fail(str(opened.get("error","Persistent profile could not be opened.")),true)
		return
	_profile_open = true
	_publication_uncertain = false
	_force_profile_reopen = false
	_accept_manifest(opened.manifest)
	_recovery_available = bool(opened.get("recovery_available",false))
	if opened.get("fresh",false):
		var seeded := await _seed_profile()
		if not seeded.get("ok",false):
			await _fail(str(seeded.error),true)
			return
	var activated := await _restore_target(str(manifest.active_area),0,true)
	if not activated.get("ok",false):
		await _fail(str(activated.error),true)
		return
	await _finish("All three areas are durable. Edit this area, travel, and return to its retained native state.")
	if active_ready:
		print("PERSISTENT_AREAS_READY ",JSON.stringify({"session":manifest.session_id,"area":active_area,"revision":manifest.revision}))


func _seed_profile() -> Dictionary:
	if host.shared_workbench == null or host.shared_workbench._liquids == null \
		or host.shared_workbench._liquids.bridge == null:
		return _error("Native Workbench policy interface is unavailable.")
	var policy: PackedInt32Array = host.shared_workbench._liquids.bridge.default_liquid_policy()
	var updates := {}
	for id: String in Fixtures.IDS:
		_set_phase("Loading","Preparing initial area %s; simulation and authoring remain paused until all three are durable…" % id.to_upper())
		var authoring := {"setup":Fixtures.create(id,policy),"definition":{},"generated_packet":{},"material_baseline":{},
			"camera":{"origin":[0,0],"size":[512,512],"zoom":1,"mode":2}}
		var installed := await _install(authoring,{},id,false)
		if not installed.get("ok",false): return installed
		var captured := await _capture_live()
		if not captured.get("ok",false): return captured
		var capsule: Dictionary = captured.result.capsule
		if int(capsule.completed_tick) != 0:
			return _error("Initial persistent area advanced before its first durable checkpoint.")
		updates[id] = {"capture":capsule,"authoring":host.persistent_authoring_state(),
			"mutation_generation":maxi(1,int(captured.result.mutation_generation)),"incarnation":AreaStore.new_nonce()}
		await _qualification_resources("bootstrap_captured",updates,id)
		# A captured immutable capsule remains retained in updates until the
		# complete first manifest is durable. No editable state or elapsed time
		# exists yet, and an interrupted incomplete profile never reseeds.
		if id != Fixtures.IDS.back():
			var released := await _worker({"kind":"release","operation_id":operation.operation_id})
			if not released.get("ok",false): return released
	var stored := await _publish(AreaClock.fresh(),updates,"a")
	if not stored.get("ok",false): return stored
	await _qualification_resources("bootstrap_first_durable",updates,Fixtures.IDS.back())
	return {"ok":true}


func _run_operation(requested_future_ticks: int) -> void:
	var captured := await _capture_live()
	if not captured.get("ok",false):
		await _fail(str(captured.error))
		return
	var capsule: Dictionary = captured.result.capsule
	var accounted := AreaClock.active(clock,active_area,int(capsule.completed_tick))
	if not accounted.get("ok",false):
		await _fail(str(accounted.error),true)
		return
	clock = accounted.clock
	var previous: Dictionary = manifest.areas[active_area]
	var updates := {active_area:{"capture":capsule,"authoring":host.persistent_authoring_state(),
		"mutation_generation":maxi(int(previous.mutation_generation)+1,int(captured.result.mutation_generation)),
		"incarnation":previous.incarnation}}
	var saved := await _publish(clock,updates,active_area)
	if not saved.get("ok",false):
		await _fail(str(saved.error))
		return
	await _qualification_boundary("source_durable")
	if _cancel_requested:
		await _finish("Cancelled after preserving the active area's durable checkpoint.")
		return
	if operation.kind in ["save","exit"]:
		if operation.kind == "exit":
			await _finish_exit()
		else:
			await _finish("All three areas are saved. Inactive areas already have independent durable checkpoints.")
		return
	var result := await _restore_target(str(operation.target_area),requested_future_ticks,false)
	if not result.get("ok",false):
		await _fail(str(result.error),_candidate_durable and operation.target_area == operation.source_area)
		return
	var remaining := int(operation.get("remaining_future_ticks",0))
	var detail := "Completed %d native ticks; remaining area debt %.2f s." % [
		int(operation.completed_ticks),float(AreaClock.debt(clock,active_area))/AreaClock.TICKS_PER_SECOND]
	if remaining > 0: detail += " %.2f s of requested future time was not simulated." % (float(remaining)/AreaClock.TICKS_PER_SECOND)
	if _cancel_requested: detail = "Cancelled safely. " + detail
	await _finish(detail)


func _capture_live() -> Dictionary:
	_set_phase("Capturing","Capturing the complete admitted native continuation and its mutation fence…")
	var started := Time.get_ticks_usec()
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while Time.get_ticks_msec()<deadline:
		var owner: Dictionary = host.simulation_worker.paint_state()
		var captured := await _worker({"kind":"capture","operation_id":operation.operation_id,
			"expected_generation":int(owner.get("generation",-1))})
		if captured.get("ok",false):
			_record_metric("capture_ms",float(Time.get_ticks_usec()-started)/1000.0)
			_record_metric("native_capture_us",float(captured.result.get("capture_us",0)))
			return captured
		if not captured.get("retryable",false): return captured
		# Native admission leaves its lease unacquired while queued pause/Stop
		# work drains. Only this explicit retryable result permits another try;
		# actors, malformed state and actual capture failures remain refusals.
		operation.detail = "Waiting for the native pause and already queued host commands to drain…"
		await get_tree().process_frame
	return _error("The native owner did not reach its paused capture boundary within the deadline.")


func _restore_target(target: String, requested_future_ticks: int, startup: bool) -> Dictionary:
	operation.target_area = target
	_set_phase("Loading","Reading and validating area %s's durable native checkpoint…" % target.to_upper())
	var loaded := await _io("read_area",[target])
	if not loaded.get("ok",false):
		_note_storage_refusal(loaded)
		return loaded
	if not _lease_held:
		var leased: Dictionary
		if host.shared_workbench.applied.is_empty():
			# Main's initial demo can own real generic body masks. Retire them
			# through its normal acknowledged actor-free constructor first;
			# weakening native body-mask refusal would lose authority. This
			# empty preparation owner is never assigned or saved as an area.
			# The existing profile has already been validated, and its saved
			# area is restored exclusively from the retained continuation.
			var policy: PackedInt32Array = host.shared_workbench._liquids.bridge.default_liquid_policy()
			var preparation_authoring := {"setup":Fixtures.Setup.fresh(policy,Fixtures.EXTENT),"definition":{},
				"generated_packet":{},"material_baseline":{},
				"camera":{"origin":[0,0],"size":[512,512],"zoom":1,"mode":2}}
			var preparation := await _install(preparation_authoring,{},"preparation",false)
			if not preparation.get("ok",false): return preparation
			leased = await _capture_live()
		else:
			# Retry can retain an older still-visible World while loading its
			# newer durable checkpoint. Capture freezes it; it receives no time
			# credit and never overwrites the retained checkpoint here.
			leased = await _capture_live()
		if not leased.get("ok",false): return leased
	var planned := AreaClock.plan(clock,target,"ahead" if operation.kind == "ahead" else "catch_up",
		requested_future_ticks,MAX_OPERATION_TICKS)
	if not planned.get("ok",false): return planned
	var plan: Dictionary = planned.plan
	# Bind observations to the actual admitted native interval, after live capture.
	operation["plan_source_native_tick"] = int(plan.source_native_tick)
	operation["plan_source_debt_ticks"] = int(plan.source_debt_ticks)
	operation["requested_future_ticks"] = requested_future_ticks
	operation.requested_ticks = int(plan.work_ticks)
	operation.remaining_future_ticks = requested_future_ticks
	var restore_started := Time.get_ticks_usec()
	var prepared := await _install(loaded.authoring,loaded.capture,target,true)
	_record_metric("restore_ms",float(Time.get_ticks_usec()-restore_started)/1000.0)
	if not prepared.get("ok",false): return prepared
	if _cancel_requested and operation.kind == "travel":
		return await _discard_candidate()
	_set_phase("Catching up","Running bounded native steps; skipped time remains explicit debt…")
	var advance_started := Time.get_ticks_msec()
	var completed := 0
	while completed < int(plan.work_ticks) and not _cancel_requested \
		and Time.get_ticks_msec()-advance_started < MAX_CATCH_UP_MSEC:
		var step := await _worker({"kind":"advance","operation_id":operation.operation_id,
			"max_ticks":mini(MAX_NATIVE_SLICE_TICKS,int(plan.work_ticks)-completed),"max_us":MAX_NATIVE_SLICE_USEC})
		if not step.get("ok",false): return step
		var actual := int(step.result.get("completed_ticks",-1))
		if actual < 0 or actual > mini(MAX_NATIVE_SLICE_TICKS,int(plan.work_ticks)-completed):
			return _error("Native catch-up returned an invalid completed-tick count.")
		if int(step.result.get("current_tick",-1)) != int(loaded.capture.completed_tick)+completed+actual:
			return _error("Native catch-up time does not match its retained checkpoint and completed steps.")
		completed += actual
		operation.completed_ticks = completed
		operation.detail = "%d / %d admitted native ticks completed. Each worker slice is bounded to 32 ticks / 100 ms." % [completed,int(plan.work_ticks)]
		var native_elapsed_us := int(step.result.get("elapsed_us",0))
		_record_metric("native_step_us",float(native_elapsed_us))
		operation.native_ticks_executed = int(operation.native_ticks_executed)+actual
		operation.native_slice_count = int(operation.native_slice_count)+1
		_measurement_slice_sequence += 1
		_record_metric("native_slices",{"sequence":_measurement_slice_sequence,
			"operation_id":operation.operation_id,"kind":operation.kind,
			"source_area":operation.source_area,"target_area":target,
			"measurement_tag":operation.measurement_tag,"ticks":actual,"elapsed_us":native_elapsed_us,
			"observed_workers":int(step.result.get("observed_workers",0)),
			"start_completed_tick":int(loaded.capture.completed_tick)+completed-actual,
			"end_completed_tick":int(step.result.current_tick)})
		_refresh_panel()
		if actual == 0: break
	var accounted := AreaClock.complete(clock,plan,completed)
	if not accounted.get("ok",false): return accounted
	operation.remaining_future_ticks = int(accounted.remaining_future_ticks)
	_set_phase("Capturing","Capturing the privately advanced candidate before durable publication…")
	var captured := await _worker({"kind":"capture_prepared","operation_id":operation.operation_id})
	if not captured.get("ok",false): return captured
	var candidate: Dictionary = captured.result.capsule
	if int(candidate.completed_tick) != int(accounted.clock.areas[target].native_ticks):
		return _error("Prepared native checkpoint and accounted game time disagree.")
	var updates := {target:{"capture":candidate,"authoring":loaded.authoring,
		"mutation_generation":maxi(int(loaded.record.mutation_generation)+1,int(captured.result.mutation_generation)),
		"incarnation":loaded.record.incarnation}}
	var durable := await _publish(accounted.clock,updates,str(manifest.active_area))
	if not durable.get("ok",false): return durable
	_candidate_durable = true
	_record_metric("completed_ticks",completed)
	await _qualification_boundary("candidate_durable")
	if _cancel_requested and operation.kind == "travel":
		return await _discard_candidate()
	_set_phase("Ready for activation","The target continuation is durable; accepting the existing native preparation and Main acknowledgement…")
	var committed := await _worker({"kind":"commit","operation_id":operation.operation_id})
	if not committed.get("ok",false): return committed
	var accepted := await _wait_install_ack(int(prepared.serial),int(prepared.previous_generation))
	if not accepted.get("ok",false): return accepted
	_candidate_committed = true
	active_area = target
	_last_world_generation = int(host.latest_snapshot.render_world_generation)
	var selection := await _publish(clock,{},target)
	if not selection.get("ok",false): return selection
	active_ready = true
	_quarantined = false
	if startup: _resume_play = not _start_paused
	return {"ok":true,"completed_ticks":completed}


func _install(authoring: Dictionary, capsule: Dictionary, target: String, stage: bool) -> Dictionary:
	var identity := {"session_id":str(manifest.session_id),"area_id":target,
		"generation":int(manifest.get("areas",{}).get(target,{}).get("generation",0))+1,
		"operation_id":str(operation.operation_id)}
	var previous_generation := int(host.latest_snapshot.render_world_generation) if host.latest_snapshot != null else -1
	if not host.persistent_install_area(authoring,capsule,identity,stage):
		return _error(str(host.microscenario_error))
	var serial := int(host.pending_microscenario_apply.get("serial",-1))
	if not stage: return await _wait_install_ack(serial,previous_generation)
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var observed := await _worker({"kind":"status","operation_id":operation.operation_id})
		if not observed.get("ok",false): return observed
		if observed.result.get("prepared",false):
			return {"ok":true,"serial":serial,"previous_generation":previous_generation}
		if not str(observed.result.get("error","")).is_empty(): return _error(str(observed.result.error))
		if host.pending_microscenario_apply.is_empty():
			return _error("The continuation was not prepared: " + str(host.microscenario_error))
		await get_tree().process_frame
	return _error("Native continuation preparation exceeded the bounded owner acknowledgement deadline.")


func _wait_install_ack(serial: int, previous_generation: int) -> Dictionary:
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while not host.pending_microscenario_apply.is_empty() and Time.get_ticks_msec() < deadline:
		if int(host.pending_microscenario_apply.get("serial",-1)) != serial:
			return _error("A newer Workbench installation superseded the persistent-area request.")
		await get_tree().process_frame
	if not host.pending_microscenario_apply.is_empty(): return _error("Main did not acknowledge the native area installation within its deadline.")
	if not str(host.microscenario_error).is_empty(): return _error(str(host.microscenario_error))
	if host.latest_snapshot == null or int(host.latest_snapshot.render_world_generation) <= previous_generation:
		return _error("An empty request is not an acknowledgement: the native World generation did not advance.")
	return {"ok":true,"serial":serial,"previous_generation":previous_generation}


func _publish(next_clock: Dictionary, updates: Dictionary, selected: String) -> Dictionary:
	_set_phase("Durable","Publishing validated checkpoints and their game-time frontiers atomically…")
	var started := Time.get_ticks_usec()
	var before := await _worker({"kind":"status","operation_id":operation.operation_id})
	if not before.get("ok",false): return before
	var fence: Dictionary = before.result.get("owner_fence",{})
	if fence.is_empty(): return _error("Native owner did not provide the frozen persistence fence.")
	var prepared := await _io("prepare_commit",[{"active_area":selected,"clock":next_clock},updates,
		int(manifest.revision),AreaStore.new_nonce(),fence])
	if not prepared.get("ok",false):
		_note_storage_refusal(prepared)
		return prepared
	var current := await _worker({"kind":"status","operation_id":operation.operation_id})
	if not current.get("ok",false) or current.result.get("owner_fence",{}) != fence:
		await _io("abort_prepared",[prepared.receipt])
		_force_profile_reopen = true
		_quarantined = true
		return _error("The native owner changed during checkpoint I/O; stale publication was refused.")
	var committed := await _io("commit_prepared",[prepared.receipt,current.result.owner_fence])
	if not committed.get("ok",false):
		_note_storage_refusal(committed)
		if not _publication_uncertain and not bool(committed.get("quarantined",false)):
			# A definitely unpublished stage can be retired while its source is
			# still frozen. Leaving it pending would prevent every later retry.
			var aborted := await _io("abort_prepared",[prepared.receipt])
			if not aborted.get("ok",false):
				_note_storage_refusal(aborted)
				committed["cleanup_warning"] = str(aborted.get("error","Checkpoint cleanup failed."))
				committed.error = str(committed.error)+" Cleanup warning: "+str(committed.cleanup_warning)
		return committed
	_accept_manifest(committed.manifest)
	_record_metric("durable_ms",float(Time.get_ticks_usec()-started)/1000.0)
	return committed


func _worker(command: Dictionary) -> Dictionary:
	if not _unresolved_worker.is_empty():
		return _error("The previous native request is still unresolved; Retry must acknowledge its exact token first.")
	if not host.simulation_worker.has_method("persistent_request"):
		return _error("The installed Workbench worker has no persistent-area owner interface.")
	var admitted: Dictionary = host.simulation_worker.persistent_request(command)
	if not admitted.get("ok",false):
		return {"ok":false,"error":str(admitted.get("error",admitted.get("reason","Native persistent operation refused."))),
			"retryable":bool(admitted.get("retryable",false))}
	var token := int(admitted.get("token",0))
	if token <= 0: return _error("Native persistent request returned no operation token.")
	_current_worker_token = token
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var observed: Dictionary = host.simulation_worker.persistent_poll(token)
		var ownership_error := _observe_worker_owner(observed,str(command.operation_id))
		if not ownership_error.is_empty():
			_retain_unresolved_worker(token,command)
			return _error(ownership_error)
		var phase := str(observed.get("status",""))
		if phase == "complete":
			_current_worker_token = 0
			if command.kind == "commit" and observed.get("result",{}).get("committed",false):
				_candidate_committed = true
			return observed if observed.get("ok",false) else _error(str(observed.get("error","Native operation failed.")))
		if phase == "failed" or not observed.get("ok",true):
			_current_worker_token = 0
			return {"ok":false,"error":str(observed.get("error","Native persistent operation failed.")),
				"retryable":bool(observed.get("retryable",false))}
		await get_tree().process_frame
	# A host deadline does not cancel native work. In particular, a late capture
	# still owns the live World. Retain its token and identity until Retry has
	# consumed the actual completion; never claim that a timeout released it.
	_retain_unresolved_worker(token,command)
	return _error("Native persistent operation exceeded its owner deadline. The World remains paused; Retry checks the same outstanding completion.")


func _observe_worker_owner(observed: Dictionary, expected_operation: String) -> String:
	if not observed.has("lease_held") or not observed.has("operation_id"):
		return "The native request has no matching owner acknowledgement. Its retained token must be resolved before editing resumes."
	if bool(observed.lease_held) and str(observed.operation_id) != expected_operation:
		return "The native request acknowledged a different owner identity; the retained World remains quarantined."
	_lease_held = bool(observed.lease_held)
	return ""


func _retain_unresolved_worker(token: int, command: Dictionary) -> void:
	_unresolved_worker = {"token":token,"operation_id":str(command.operation_id),"kind":str(command.kind)}
	_owner_cleanup_required = true
	_current_worker_token = token


func _io(method: String, arguments: Array) -> Dictionary:
	if _io_busy: return _error("Overlapping persistent profile I/O was refused.")
	_io_busy = true
	_io_thread = Thread.new()
	var copied := arguments.duplicate(true)
	var error := _io_thread.start(_run_io.bind(method,copied))
	if error != OK:
		_io_busy = false
		_io_thread = null
		return _error("Could not start the persistent profile I/O worker: " + str(error))
	while _io_thread.is_alive(): await get_tree().process_frame
	var result: Variant = _io_thread.wait_to_finish()
	_io_thread = null
	_io_busy = false
	if result is Dictionary: return result
	if method == "close_profile" and result == null: return {"ok":true}
	if method in ["commit_prepared","recover_previous"]:
		return {"ok":false,"quarantined":true,"publication_uncertain":true,
			"error":"Persistent publication returned no valid acknowledgement for " + method + "."}
	return _error("Persistent profile I/O returned no valid result for " + method + ".")


func _run_io(method: String, arguments: Array) -> Variant:
	if method == "_open_with_identity":
		var digest := FileAccess.get_sha256(str(arguments[1]))
		if digest.length() != 64: return _error("The installed native runtime cannot be identified; profile opening was refused.")
		return _store.open_profile(str(arguments[0]),PROFILE_ID,DOMAIN_ID+":"+digest)
	if method == "_qualification_inventory":
		if _store._io == null: return _error("No open profile storage owner for qualification inventory.")
		return _store._io.call("list_files")
	return _store.callv(method,arguments)


func _discard_candidate() -> Dictionary:
	var discarded := await _worker({"kind":"discard","operation_id":operation.operation_id})
	if not discarded.get("ok",false): return discarded
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while not host.pending_microscenario_apply.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not host.pending_microscenario_apply.is_empty(): return _error("Discarded preparation did not retire its Main request.")
	return {"ok":true}


func _finish(detail: String) -> void:
	if _owner_cleanup_required or not _unresolved_worker.is_empty():
		await _fail("The native operation still needs an acknowledged owner cleanup.",false,false)
		return
	if _lease_held:
		var released := await _worker({"kind":"release","operation_id":operation.operation_id})
		if not released.get("ok",false):
			_owner_cleanup_required = true
			await _fail(str(released.error),false,false)
			return
	active_ready = true
	busy = false
	_quarantined = false
	_owner_recovery_requires_restore = false
	if active_area.is_empty(): active_area = str(manifest.active_area)
	_last_world_generation = int(host.latest_snapshot.render_world_generation)
	_last_clock_snapshot_serial = int(host.latest_snapshot.serial)
	host.paused = not _resume_play
	host.update_worker_frame_state()
	last_result = {"ok":true,"operation":operation.duplicate(true),"active_area":active_area,
		"clock":clock.duplicate(true),"revision":manifest.revision,"message":detail}
	var area := Fixtures.description(active_area)
	host.shared_workbench.message = "Area %s · %s. Paint or erase materials; use the area controls above to travel or advance game time." % [
		str(area.get("letter",active_area)),str(area.get("label",""))]
	_record_metric("operation_ms",Time.get_ticks_msec()-int(operation.started_msec))
	_record_operation_terminal(str(operation.get("measurement_outcome","completed")))
	_set_phase("Active",detail)


func _finish_exit() -> void:
	var released := await _worker({"kind":"release","operation_id":operation.operation_id})
	if not released.get("ok",false):
		_owner_cleanup_required = true
		await _fail(str(released.error),false,false)
		return
	await _close_without_save()


func _close_without_save() -> void:
	_set_phase("Durable","Closing the persistent profile after its last completed publication…")
	await _io("close_profile",[])
	_profile_open = false
	host.finish_persistent_exit(_exit_destination)


func _retry_profile() -> void:
	if _profile_open and not _force_profile_reopen and int(manifest.get("revision",0)) > 0:
		var restored := await _restore_target(str(manifest.active_area),0,true)
		if restored.get("ok",false): await _finish("The durable profile was restored without regenerating any area.")
		else: await _fail(str(restored.error),true)
		return
	await _io("close_profile",[])
	_profile_open = false
	await _open_profile()


func _retry_owner() -> void:
	if not _unresolved_worker.is_empty():
		var retained: Dictionary = _unresolved_worker.duplicate()
		var observed: Dictionary = host.simulation_worker.persistent_poll(int(retained.token))
		var ownership_error := _observe_worker_owner(observed,str(retained.operation_id))
		if not ownership_error.is_empty():
			await _fail(ownership_error,false,false)
			return
		if str(observed.get("status","")) == "pending":
			await _fail("The retained native %s request is still completing. The World stays paused; Retry will check this same token again." % str(retained.kind),false,false)
			return
		if str(observed.get("status","")) not in ["complete","failed"]:
			await _fail("The retained native request returned no terminal completion; its owner is still unresolved.",false,false)
			return
		if retained.kind == "commit" and observed.get("result",{}).get("committed",false):
			_candidate_committed = true
		_unresolved_worker = {}
		_current_worker_token = 0
	var cleaned := await _cleanup_owner()
	if not cleaned.get("ok",false):
		await _fail(str(cleaned.error),false,false)
		return
	_owner_cleanup_required = false
	# A late capture only froze the same source; its unsaved edits remain the
	# authoritative state. Reloading an older checkpoint here would lose them.
	# A committed replacement or uncertain publication instead needs the known
	# durable manifest to establish which incarnation is authoritative.
	var needs_restore: bool = _owner_recovery_requires_restore or _publication_uncertain or _force_profile_reopen \
		or _candidate_committed or (_candidate_durable and operation.target_area == operation.source_area) \
		or active_area.is_empty() or host.simulation_worker.has_failed()
	var owner: Dictionary = host.simulation_worker.paint_state()
	needs_restore = needs_restore or int(owner.get("generation",-1)) != _last_world_generation
	_owner_recovery_requires_restore = false
	if needs_restore:
		_begin("retry",str(manifest.get("active_area","a")))
		await _retry_profile()
		return
	var accounted := AreaClock.active(clock,active_area,int(owner.get("tick",-1)))
	if not accounted.get("ok",false):
		await _fail(str(accounted.error),true,false)
		return
	clock = accounted.clock
	# Owner cleanup completes; the failed original Save still has not published.
	operation["measurement_outcome"] = "owner_recovered"
	await _finish("The late native operation was acknowledged and its lease released. The existing live area and its unsaved edits remain available; Save can be retried.")


func _cleanup_owner() -> Dictionary:
	if not _unresolved_worker.is_empty():
		return _error("A native request remains outstanding; its owner cannot yet be released.")
	if not _lease_held:
		if not host.pending_microscenario_apply.is_empty():
			return _error("Main still has an unresolved area installation; the World remains paused.")
		return {"ok":true}
	if _candidate_committed:
		# A completed native commit must receive its normal Main acknowledgement;
		# publishing a discard here would counterfeit a refused installation.
		var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
		while not host.pending_microscenario_apply.is_empty() and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
		if not host.pending_microscenario_apply.is_empty():
			return _error("The committed native area is still awaiting Main acknowledgement; Retry keeps its owner identity.")
	else:
		var observed := await _worker({"kind":"status","operation_id":operation.operation_id})
		if not observed.get("ok",false): return observed
		if observed.result.get("prepared",false) or not host.pending_microscenario_apply.is_empty():
			var discarded := await _discard_candidate()
			if not discarded.get("ok",false): return discarded
	var released := await _worker({"kind":"release","operation_id":operation.operation_id})
	if not released.get("ok",false): return released
	if _lease_held: return _error("The native completion did not acknowledge release of its owner lease.")
	return {"ok":true}


func _recover_profile() -> void:
	_set_phase("Loading","Explicitly recovering the retained previous manifest; the refused bytes remain quarantined…")
	var recovered := await _io("recover_previous",[])
	if not recovered.get("ok",false):
		_note_storage_refusal(recovered)
		await _fail(str(recovered.error),true)
		return
	_profile_open = true
	_publication_uncertain = false
	_force_profile_reopen = false
	_accept_manifest(recovered.manifest)
	var restored := await _restore_target(str(manifest.active_area),0,true)
	if restored.get("ok",false): await _finish("Recovered the explicitly selected previous durable profile. The refused current manifest remains quarantined.")
	else: await _fail(str(restored.error),true)


func _fail(reason: String, quarantine: bool = false, clean_owner: bool = true) -> void:
	_owner_recovery_requires_restore = _owner_recovery_requires_restore or quarantine \
		or _publication_uncertain or _force_profile_reopen or (_quarantined and not _owner_cleanup_required)
	quarantine = quarantine or _publication_uncertain or _force_profile_reopen or _quarantined
	if clean_owner and host.simulation_worker.has_method("persistent_request"):
		# Refusal never replaces a live World with its recipe. Prepared state is
		# abandoned; an already durable newer same-area checkpoint requires a
		# restore before this older live incarnation may resume.
		var cleaned := await _cleanup_owner()
		if not cleaned.get("ok",false):
			_owner_cleanup_required = true
			reason += " Owner cleanup remains pending: " + str(cleaned.error)
	if _owner_cleanup_required or not _unresolved_worker.is_empty(): quarantine = true
	busy = false
	_quarantined = quarantine
	active_ready = not quarantine and not active_area.is_empty() and not host.simulation_worker.has_failed()
	host.paused = true if not active_ready else not _resume_play
	host.update_worker_frame_state()
	if _publication_uncertain:
		reason += " Publication acknowledgement is uncertain. The live World stays paused; Retry reopens and validates the durable manifest before restoring."
	last_result = {"ok":false,"error":reason,"operation":operation.duplicate(true),"quarantined":quarantine,
		"publication_uncertain":_publication_uncertain,"force_profile_reopen":_force_profile_reopen,
		"owner_cleanup_required":_owner_cleanup_required,"unresolved_worker":_unresolved_worker.duplicate(true)}
	_record_operation_terminal("failed",reason)
	_set_phase("Failed / quarantined" if quarantine else "Active / operation refused",reason)
	push_warning("PERSISTENT_AREAS_REFUSED: "+reason)


func _accept_manifest(value: Dictionary) -> void:
	manifest = value.duplicate(true)
	clock = manifest.clock.duplicate(true)


func _note_storage_refusal(result: Dictionary) -> void:
	if bool(result.get("published",false)) or bool(result.get("quarantined",false)):
		_publication_uncertain = bool(result.get("published",false)) or bool(result.get("publication_uncertain",false)) or _publication_uncertain
		_force_profile_reopen = true
		_quarantined = true


func _set_phase(state: String, detail: String) -> void:
	lifecycle = state
	message = detail
	if not operation.is_empty(): operation.detail = detail
	_events.append({"state":state,"message":detail,"operation_id":str(operation.get("operation_id","")),
		"msec":Time.get_ticks_msec(),"game_tick":int(clock.game_ticks)})
	if _events.size() > 128: _events.pop_front()
	_refresh_panel()


func _record_metric(key: String, value: Variant) -> void:
	metrics[key].append(value)
	if metrics[key].size() > 256: metrics[key].pop_front()
	if not operation.is_empty() and key in ["capture_ms","native_capture_us","restore_ms","durable_ms","native_step_us"]:
		var totals: Dictionary = operation.get("measurement_totals",{})
		totals[key] = float(totals.get(key,0.0))+float(value)
		operation["measurement_totals"] = totals


func _record_operation_terminal(terminal_status: String, error: String = "") -> void:
	if operation.is_empty(): return
	var ended := Time.get_ticks_msec()
	var target: String = str(operation.target_area)
	var totals: Dictionary = operation.get("measurement_totals",{})
	_measurement_terminal_sequence += 1
	# A late-owner Retry can finish the SAME operation after a failed terminal.
	# These cumulative observations share its ID; consumers select the latest
	# terminal per ID instead of adding its native work or wall duration twice.
	# Bounded completion does not imply all requested time was simulated:
	# remaining_future_ticks and debt_after_ticks retain that separate meaning.
	_record_metric("operation_records",{"terminal_sequence":_measurement_terminal_sequence,
		"operation_id":operation.operation_id,"kind":operation.kind,
		"source_area":operation.source_area,"target_area":target,"status":terminal_status,
		"bounded_action_completed":terminal_status=="completed" and not bool(operation.cancel_requested),
		"measurement_tag":str(operation.get("measurement_tag","")),"error":error,
		"start_msec":int(operation.started_msec),"end_msec":ended,
		"elapsed_ms":ended-int(operation.started_msec),
		"actual_completed_ticks":int(operation.completed_ticks),
		"native_ticks_executed":int(operation.get("native_ticks_executed",0)),
		"native_slice_count":int(operation.get("native_slice_count",0)),
		"requested_ticks":int(operation.requested_ticks),
		"requested_future_ticks":int(operation.get("requested_future_ticks",0)),
		"remaining_future_ticks":int(operation.remaining_future_ticks),
		"cancel_requested":bool(operation.cancel_requested),
		"game_tick_before":int(operation.get("game_tick_before",0)),"game_tick_after":int(clock.game_ticks),
		"debt_before_ticks":int(operation.get("debt_before_ticks",-1)),"debt_after_ticks":AreaClock.debt(clock,target),
		"target_native_tick_before":int(operation.get("target_native_tick_before",-1)),
		"plan_source_native_tick":int(operation.get("plan_source_native_tick",-1)),
		"plan_source_debt_ticks":int(operation.get("plan_source_debt_ticks",-1)),
		"target_native_tick_after":int(clock.areas.get(target,{}).get("native_ticks",-1)),
		"native_step_us_total":float(totals.get("native_step_us",0.0)),
		"capture_ms_total":float(totals.get("capture_ms",0.0)),
		"native_capture_us_total":float(totals.get("native_capture_us",0.0)),
		"restore_ms_total":float(totals.get("restore_ms",0.0)),
		"durable_ms_total":float(totals.get("durable_ms",0.0)),
		"candidate_durable":_candidate_durable,"candidate_committed":_candidate_committed,
		"publication_uncertain":_publication_uncertain,"owner_cleanup_required":_owner_cleanup_required})


func _qualification_boundary(phase: String) -> void:
	if not qualification_boundary_hook.is_valid(): return
	var receipt := {"phase":phase,"operation_id":operation.operation_id,
		"source_area":operation.source_area,"target_area":operation.target_area,
		"session_id":manifest.session_id,"revision":manifest.revision,
		"clock":clock.duplicate(true),"areas":manifest.areas.duplicate(true),
		"candidate_committed":_candidate_committed}
	var milliseconds := clampi(int(qualification_boundary_hook.call(phase,receipt)),0,5000)
	var deadline := Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec() < deadline: await get_tree().process_frame


func _qualification_resources(phase: String, updates: Dictionary, current: String) -> void:
	if not qualification_resource_hook.is_valid(): return
	var capsule_bytes := 0
	var capsule_metadata_bytes := 0
	var authoring_bytes := 0
	var captured_native_cell_bytes := 0
	for update: Dictionary in updates.values():
		var capsule: Dictionary = update.capture
		capsule_bytes += capsule.bytes.size()
		captured_native_cell_bytes += int(capsule.native_resident_cell_bytes)
		var metadata: Dictionary = capsule.duplicate(false)
		metadata.erase("bytes")
		capsule_metadata_bytes += var_to_bytes(metadata).size()
		authoring_bytes += var_to_bytes(update.authoring).size()
	var inventory := await _io("_qualification_inventory",[])
	var checkpoint_files := 0
	var checkpoint_bytes := 0
	for file: Dictionary in inventory.get("files",[]):
		if str(file.name).ends_with(".cypa"):
			checkpoint_files += 1
			checkpoint_bytes += int(file.bytes)
	var sample := {"phase":phase,"process_id":OS.get_process_id(),"count":updates.size(),
		"msec":Time.get_ticks_msec(),"current_area":current,"live_native_worlds":1,
		"inactive_capsules":maxi(0,updates.size()-1),"capsule_bytes":capsule_bytes,
		"capsule_metadata_encoded_bytes":capsule_metadata_bytes,"authoring_encoded_bytes":authoring_bytes,
		"retained_encoded_bytes":capsule_bytes+capsule_metadata_bytes+authoring_bytes,
		"current_native_cell_bytes":int(updates[current].capture.native_resident_cell_bytes),
		"captured_native_cell_bytes_sum":captured_native_cell_bytes,
		"godot_tracked_static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"profile_file_count":inventory.get("files",[]).size(),"profile_bytes":int(inventory.get("bytes",0)),
		"checkpoint_files":checkpoint_files,"checkpoint_bytes":checkpoint_bytes,
		"inventory_ok":bool(inventory.get("ok",false)),"inventory_error":str(inventory.get("error","")),
		"scope":"Bootstrap/transient: immutable capsules and one live native World; encoded sizes are payload sizes, native cell bytes are cell capacity, and neither is process RSS or full heap allocation."}
	_resource_samples.append(sample)
	if _resource_samples.size()>4: _resource_samples.pop_front()
	qualification_resource_hook.call(sample.duplicate(true))


func _refresh_panel() -> void:
	if is_instance_valid(panel): panel.update_state(status())


func _refuse(reason: String) -> bool:
	message = reason
	_refresh_panel()
	return false


func _start_block_reason() -> String:
	if not active_ready or busy: return "Wait for the current persistent-area operation."
	if host.shared_workbench == null: return "The authored Workbench is not available."
	var workbench: Control = host.shared_workbench
	var blocked: String = workbench._save_block_reason()
	if not blocked.is_empty(): return blocked
	if workbench.paint_editor != null and (workbench.paint_editor.busy() or workbench.paint_editor.recovery_required()):
		return "Finish the current Paint transaction before capturing the area."
	if workbench.art_batches != null:
		var executor: RefCounted = workbench.art_batches.executor
		if executor.active or executor.waiting or not executor.manual.is_empty() or not executor.manual_inflight.is_empty():
			return "Finish or Stop the pending Art work before capturing the area."
	return ""


func _configure_profile_controls() -> void:
	# The inherited Workbench remains the editor, but this profile cannot own
	# arbitrary bodies, host emitters or a different World/solver. Do not invite
	# an action that is known to refuse; the owner guard still enforces it for
	# keyboard and programmatic callers. Ordinary Workbench is untouched.
	var workbench: Control = host.shared_workbench
	if workbench == null: return
	var unsupported := ["Reset selected [R]","Restore start","New blank","New from generator…","Water Lab…",
		"Actor Composition…","Place at X/Y","Focus","Replace with model","Remove","Source at X/Y",
		"Burst [B]","Save reset spawn","Use body position","Move to X/Y","Apply settings","Defaults"]
	var explanation := "Outside this persistent-area profile. Open the ordinary Workbench for actors, host sources, solver changes and replacement starts."
	for button: Node in workbench.find_children("*","Button",true,false):
		if str(button.text) in unsupported:
			button.disabled = true
			button.tooltip_text = explanation
	for picker: OptionButton in [workbench._roster,workbench._model,workbench._instances,workbench._response]:
		picker.disabled = true
		picker.tooltip_text = explanation
	for index: int in range(1,workbench._tool.item_count):
		workbench._tool.set_item_disabled(index,true)
		workbench._tool.set_item_tooltip(index,explanation)
	workbench._stream.disabled = true
	workbench._stream.tooltip_text = explanation
	workbench._fire.disabled = true
	workbench._fire.tooltip_text = "Thruster fire requires a retained actor. Authored native Fire cells remain part of Area A."


static func _error(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}
