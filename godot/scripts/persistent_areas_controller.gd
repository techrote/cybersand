extends Node

# Main-thread lifecycle and game-time owner for the opt-in three-area profile.
# All World calls go through the existing simulation worker. Blocking profile
# I/O is serialized on a separate thread, while the native lease keeps its
# authoritative source frozen. No material/seed reconstruction occurs on load.
const Fixtures = preload("res://scripts/persistent_area_fixtures.gd")
const AreaClock = preload("res://scripts/persistent_area_clock.gd")
const AreaStore = preload("res://scripts/persistent_area_store.gd")
const AreaPanel = preload("res://scripts/persistent_areas_panel.gd")
const AreaCache = preload("res://scripts/persistent_area_cache.gd")
const AreaWriteback = preload("res://scripts/persistent_area_writeback.gd")
const Connectivity = preload("res://scripts/persistent_area_connectivity.gd")
const AreaRecovery = preload("res://scripts/persistent_area_recovery.gd")
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
	"operation_records":[],"native_slices":[],"prefetch_records":[]}
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
var _cache := AreaCache.new()
var _cache_open := false
var _writeback := AreaWriteback.new()
var _writeback_state: Dictionary = {"status":"idle"}
var _cache_configuration := {"enabled":true,"budget_bytes":512*1024*1024,
	"deferred":false,"background":true,"prefetch":false}
var _pending_configuration: Dictionary = {}
var _resident_clock_dirty := false
var _runtime_sha256 := ""
var _last_background_msec := 0
var _background_requested := false
var _recent_areas: Array[String] = []
var _prefetch_intent := ""
var _prefetch_state: Dictionary = {"status":"idle","message":"Disabled"}
var _prefetch_sequence := 0
var _prefetch_cancel := false
var _prefetch_busy := false
var _prefetch_token := 0
var _prefetch_operation: Dictionary = {}
var _prefetched_handles: Dictionary = {}
var _pending_cache_failure := ""
var _last_dirty_native_revision := -1
var _last_dirty_authoring_generation := -1
var _last_camera_stamp: Array = []
var _publication_reservation_id := ""
var _resident_handoff: Dictionary = {}
var _resident_advancement: Dictionary = {}
var _resident_publication_pending: Dictionary = {}
var _resident_storage_recovery_required := false
var _recovery_save_summary: Dictionary = {}
var _recovery_save_pending: Dictionary = {}
var _uncached_authoring_dirty := false
var _last_prediction_msec := 0
var _previous_camera := Vector2.ZERO
var _io_metrics := {"profile_read_calls":0,"profile_read_bytes":0,"native_deserializations":0,
	"source_constructions":0,"synchronous_publications":0,"background_publications":0,
	"hot_handoffs":0,"prefetch_requests":0,"prefetch_completed":0,"prefetch_cancelled":0,
	"prefetch_hits":0,"prefetch_missed_deadlines":0,"prefetch_native_ticks":0,"recovery_publications":0}


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
	panel.cache_configuration_requested.connect(request_cache_configuration)
	panel.prefetch_requested.connect(request_prefetch)
	panel.eviction_requested.connect(request_eviction)
	panel.diagnostics_requested.connect(export_diagnostics)
	panel.recoverable_save_requested.connect(request_save_recoverable)
	panel.recovery_exit_requested.connect(request_recovery_exit)
	_configure_profile_controls()
	profile_path = ProjectSettings.globalize_path("user://persistent-areas/three-areas-v1")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--persistent-profile="):
			profile_path = ProjectSettings.globalize_path(argument.trim_prefix("--persistent-profile="))
	_start_paused = "--persistent-start-paused" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--persistent-cache-off": _cache_configuration.enabled = false
		if argument == "--persistent-deferred": _cache_configuration.deferred = true
		if argument == "--persistent-prefetch": _cache_configuration.prefetch = true
		if argument == "--persistent-background-off": _cache_configuration.background = false
		if argument.begins_with("--persistent-cache-mib="):
			_cache_configuration.budget_bytes = clampi(int(argument.trim_prefix("--persistent-cache-mib=")),1,8192)*1024*1024
	_native_library = "res://addons/cybersand_native/bin/" + (
		"cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "libcybersand_native.linux.x86_64.so")
	_begin("open","a")
	_open_profile.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_process_usec > 0:
		metrics.max_main_frame_ms = maxf(float(metrics.max_main_frame_ms),float(now-_last_process_usec)/1000.0)
		if busy and not operation.is_empty():
			_observe_operation_frame(now)
		if _prefetch_busy and not _prefetch_operation.is_empty():
			_observe_prediction_frame(_prefetch_operation,_last_process_usec,now)
		if not metrics.prefetch_records.is_empty():
			var previous: Dictionary = metrics.prefetch_records.back()
			if int(previous.end_usec)>=_last_process_usec:
				# Include the frame containing completion/import itself. The label
				# is interval-correlated pacing, not proof that all delay was I/O.
				_observe_prediction_frame(previous,_last_process_usec,now)
	_last_process_usec = now
	if active_ready and not busy and host.simulation_worker.has_failed():
		if host.latest_snapshot!=null and int(host.latest_snapshot.render_world_generation)==_last_world_generation:
			var completed_before_failure := AreaClock.active(clock,active_area,int(host.latest_snapshot.tick_index))
			if completed_before_failure.get("ok",false): clock = completed_before_failure.clock
		active_ready = false
		_quarantined = true
		host.paused = true
		host.update_worker_frame_state()
		_set_phase("Failed / quarantined","The active native World failed and remains retained. Ordinary Save all is unavailable. The recovery controls can preserve healthy areas or explicitly close using the last durable profile.")
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
			if observed.get("ok",false):
				clock = observed.clock
				if int(observed.get("completed_ticks",0))>0:
					_resident_clock_dirty = true
					if _cache_open and not _cache.entry(active_area).hot.is_empty():
						var entry: Dictionary = _cache.entry(active_area)
						_cache.mark_dirty(active_area,int(clock.areas[active_area].native_ticks),
							int(entry.mutation_generation)+int(observed.completed_ticks))
			else:
				active_ready = false
				_quarantined = true
				host.paused = true
				host.update_worker_frame_state()
				_set_phase("Failed / quarantined",str(observed.error))
	if Time.get_ticks_msec()-_last_ui_msec >= 100:
		_last_ui_msec = Time.get_ticks_msec()
		_observe_resident_dirty()
		_refresh_panel()
	_poll_writeback()
	if active_ready and not busy and _cache_open:
		if _cache_configuration.deferred and _cache_configuration.background \
				and not _io_busy and not _prefetch_busy and _writeback_state.status == "idle" \
				and Time.get_ticks_msec()-_last_background_msec >= 5000:
			_last_background_msec = Time.get_ticks_msec()
			if _resident_clock_dirty or int(_cache.status().dirty_count)>0:
				_background_requested = true
				_begin("background_save",active_area)
				_run_cached_operation.call_deferred(0)
		if _cache_configuration.prefetch and not _prefetch_busy and not busy \
				and Time.get_ticks_msec()-_last_prediction_msec>=1000:
			_last_prediction_msec = Time.get_ticks_msec()
			var candidates := Connectivity.rank(active_area,host.camera_origin,Vector2(host.current_view_size),
				_previous_camera,_prefetch_intent,_recent_areas)
			_previous_camera = host.camera_origin
			if not candidates.is_empty(): _request_prediction(candidates[0])


func status() -> Dictionary:
	var areas := {}
	var cache_status := _cache.status(clock) if _cache_open else {}
	var native_failed: bool = host!=null and host.simulation_worker.has_failed()
	var healthy_retained := false
	for id: String in Fixtures.IDS:
		areas[id] = {"accounted_tick":int(clock.areas[id].accounted_ticks),
			"debt_ticks":AreaClock.debt(clock,id),
			"state":"Active" if id == active_area and active_ready else ("Inactive" if manifest.get("areas",{}).has(id) else "Not initialized")}
		if cache_status.get("areas",{}).has(id):
			areas[id].merge(cache_status.areas[id],true)
		areas[id]["active"] = id==active_area and active_ready
		if native_failed and id==active_area:
			areas[id]["state"] = "Failed / retained in RAM"
			areas[id]["durability"] = "Failed; only the last acknowledged checkpoint is restorable"
		if id!=active_area and _cache_open and (not _cache.entry(id).hot.is_empty() or not _cache.entry(id).warm.is_empty()):
			healthy_retained = true
		if id==active_area and not _cache_configuration.enabled:
			areas[id]["residency"] = "Active · uncached"
			areas[id]["dirty"] = _uncached_authoring_dirty or _resident_clock_dirty
			areas[id]["durability"] = "Changes not yet saved" if areas[id].dirty else "Durably saved"
	return {"ready":active_ready,"busy":busy,"active_area":active_area,"state":lifecycle,"message":message,
		"profile":profile_path,"session_id":manifest.get("session_id",""),
		"durable_generation":int(manifest.get("revision",0)),"game_tick":int(clock.game_ticks),
		"accounted_tick":int(clock.areas.get(active_area,{}).get("accounted_ticks",0)),
		"debt_ticks":maxi(0,AreaClock.debt(clock,active_area)),"areas":areas,
		"operation":operation.duplicate(true),"recovery_available":_recovery_available,
		"quarantined":_quarantined,"publication_uncertain":_publication_uncertain,
		"owner_cleanup_required":_owner_cleanup_required,"unresolved_worker":_unresolved_worker.duplicate(true),
		"resident_handoff":_resident_handoff.duplicate(true),
		"resident_advancement":_resident_advancement.duplicate(true),
		"resident_storage_recovery_required":_resident_storage_recovery_required,
		"resident_publication_pending":_resident_publication_pending.duplicate(true),
		"recoverable_save_available":native_failed and healthy_retained and _recovery_save_summary.is_empty() and _recovery_save_pending.is_empty(),
		"recovery_save":_recovery_save_summary.duplicate(true),
		"recovery_save_pending":_recovery_save_pending.duplicate(true),
		"recovery_close":_recovery_close_state(),
		"cache":cache_status,"cache_configuration":_cache_configuration.duplicate(true),
		"writeback":_writeback_state.duplicate(true),"prefetch":_prefetch_state.duplicate(true),
		"resident_clock_dirty":_resident_clock_dirty}


func _camera_stamp() -> Array:
	if host.shared_workbench==null: return []
	return [host.camera_origin,host.current_view_size,host.shared_workbench._zoom,host.shared_workbench._camera.selected]


func _observe_resident_dirty() -> void:
	if not active_ready or busy or not _cache_open: return
	var entry: Dictionary = _cache.entry(active_area)
	var observed: Dictionary = host.simulation_worker.paint_state()
	if int(observed.get("generation",-1))!=_last_world_generation: return
	var revision := int(observed.get("revision",-1))
	var authoring := int(observed.get("authoring_generation",-1))
	var camera := _camera_stamp()
	var changed := (_last_dirty_native_revision>=0 and revision!=_last_dirty_native_revision) \
		or (_last_dirty_authoring_generation>=0 and authoring!=_last_dirty_authoring_generation) \
		or (not _last_camera_stamp.is_empty() and camera!=_last_camera_stamp)
	_last_dirty_native_revision = revision
	_last_dirty_authoring_generation = authoring
	_last_camera_stamp = camera
	if changed:
		# This is a small observation fence only. Paused Empty/Paint/Art/Flatten
		# and camera changes become visibly dirty without serializing geometry on
		# each frame. The complete envelope is captured at the owner boundary.
		if not entry.hot.is_empty() and _cache_configuration.enabled:
			_cache.mark_dirty(active_area,int(clock.areas[active_area].native_ticks),int(entry.mutation_generation)+1)
		else: _uncached_authoring_dirty = true


func evidence() -> Dictionary:
	return {"schema":"gen006-ramcache-diagnostics-v2","schema_version":2,"identity":diagnostic_identity(),
		"status":status(),"clock":clock.duplicate(true),"manifest":manifest.duplicate(true),
		"metrics":metrics.duplicate(true),"last_result":last_result.duplicate(true),"events":_events.duplicate(true),
		"retained_area_resources":_resource_samples.duplicate(true),"cache_io":_io_metrics.duplicate(true),
		"connectivity":Connectivity.metadata(),"process_id":OS.get_process_id(),
		"godot_tracked_static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"memory_scope":"Godot tracked static bytes are not process RSS. Native cache allocation estimates and growth reservations are separate; process working set/RSS is collected by the external evaluator."}


func diagnostic_identity() -> Dictionary:
	var revision := OS.get_environment("CYBERSAND_SOURCE_REVISION").strip_edges()
	var graphics := {"display_server":DisplayServer.get_name()}
	for method: String in ["get_video_adapter_name","get_video_adapter_vendor","get_video_adapter_api_version",
		"get_current_rendering_method","get_current_rendering_driver_name"]:
		graphics[method] = _diagnostic_api_observation(RenderingServer,method)
	graphics["driver_info"] = _diagnostic_api_observation(OS,"get_video_adapter_driver_info")
	if not graphics.driver_info.available:
		graphics.driver_info = _diagnostic_api_observation(RenderingServer,"get_video_adapter_driver_info")
	return {"source_revision":revision if not revision.is_empty() else "unknown",
		"source_revision_origin":"CYBERSAND_SOURCE_REVISION launcher label" if not revision.is_empty() else "unlabelled local launch",
		"native_runtime_sha256":_runtime_sha256 if not _runtime_sha256.is_empty() else "unknown",
		"native_runtime_compatibility":str(manifest.get("compatibility","unknown")),
		"engine":Engine.get_version_info(),"os_name":OS.get_name(),"os_version":OS.get_version(),
		"processor_name":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),"graphics":graphics}


func _diagnostic_api_observation(provider: Object, method: String) -> Dictionary:
	if not provider.has_method(method): return {"available":false,"method":method}
	return {"available":true,"method":method,"value":provider.call(method)}


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
	(_run_cached_operation if _cache_open and _cache_configuration.enabled else _run_operation).call_deferred(0)
	return true


func request_ahead(ticks: int) -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	if ticks < 1 or ticks > AreaClock.MAX_AHEAD_TICKS: return _refuse("Choose a finite Simulate Ahead duration within ten minutes.")
	_begin("ahead",active_area)
	(_run_cached_operation if _cache_open and _cache_configuration.enabled else _run_operation).call_deferred(ticks)
	return true


func request_catch_up() -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	if AreaClock.debt(clock,active_area) <= 0: return _refuse("The active area has no catch-up debt.")
	_begin("catch_up",active_area)
	(_run_cached_operation if _cache_open and _cache_configuration.enabled else _run_operation).call_deferred(0)
	return true


func request_save() -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	_begin("save",active_area)
	(_run_cached_operation if _cache_open and _cache_configuration.enabled else _run_operation).call_deferred(0)
	return true


func request_exit(destination: String) -> bool:
	if not destination in ["launcher","quit"]: return false
	if busy: return _refuse("Finish or cancel the current operation before leaving the persistent profile.")
	if _owner_cleanup_required or not _unresolved_worker.is_empty() or not _resident_handoff.is_empty() \
			or not _resident_advancement.is_empty():
		return _refuse("The native owner has an unresolved completion. Retry its acknowledgement before leaving; the World remains paused.")
	if host.simulation_worker.has_failed():
		return _refuse("The failed native World may contain unsaved state. Use the available recovery controls and explicit close confirmation; ordinary Save & Menu cannot discard it.")
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
	(_run_cached_operation if _cache_open and _cache_configuration.enabled else _run_operation).call_deferred(0)
	return true


func request_cancel() -> void:
	_prefetch_cancel = true
	if not busy: return
	_cancel_requested = true
	operation.cancel_requested = true
	operation.detail = "Cancelling at the next safe boundary. A durable publication already in progress must finish."
	_refresh_panel()


func request_retry() -> bool:
	if busy or active_ready: return false
	if _owner_cleanup_required or not _unresolved_worker.is_empty() or not _resident_handoff.is_empty() \
			or not _resident_advancement.is_empty():
		# Keep the old identity until its exact request has completed and its
		# lease has been retired. A new operation cannot clean up an old owner.
		busy = true
		_set_phase("Loading","Checking the retained native operation before retrying…")
		_retry_owner.call_deferred()
		return true
	if _cache_open and host.simulation_worker.has_failed():
		if not _recovery_save_pending.is_empty() or _writeback_state.get("status","")=="failed":
			_begin("retry_recoverable_storage",active_area)
			_resume_play = false
			_retry_recoverable_storage.call_deferred()
			return true
		return _refuse("The failed native World remains quarantined. Use the available recovery controls; closing requires explicit acknowledgement of its unsaved state.")
	if _cache_open and not active_area.is_empty() and not _cache.entry(active_area).hot.is_empty() \
			and (_resident_storage_recovery_required or _writeback_state.get("status","")=="failed"):
		_begin("retry_storage",active_area)
		_retry_resident_storage.call_deferred()
		return true
	_begin("retry",str(manifest.get("active_area","a")))
	_retry_profile.call_deferred()
	return true


func request_recovery() -> bool:
	if busy or active_ready or not _recovery_available: return false
	if _owner_cleanup_required or not _unresolved_worker.is_empty() or not _resident_handoff.is_empty() \
			or not _resident_advancement.is_empty():
		return _refuse("Retry the unresolved native owner before selecting a different durable checkpoint.")
	_begin("recover",str(manifest.get("active_area","a")))
	_recover_profile.call_deferred()
	return true


func request_save_recoverable() -> bool:
	if busy or not _cache_open or not host.simulation_worker.has_failed() \
			or not _unresolved_worker.is_empty() or not _resident_handoff.is_empty() \
			or not _resident_advancement.is_empty() or _owner_cleanup_required:
		return _refuse("Healthy-area recovery requires an acknowledged failed owner with no unresolved native transfer.")
	if not _recovery_save_summary.is_empty(): return _refuse("The healthy areas already have an acknowledged recovery save.")
	if not _recovery_save_pending.is_empty(): return _refuse("Retry the pending recovery publication acknowledgement before capturing another snapshot.")
	_begin("save_recoverable",active_area)
	_resume_play = false
	_run_recoverable_save.call_deferred()
	return true


func _run_recoverable_save() -> void:
	await _wait_writeback()
	await _wait_prefetch()
	var observed := await _worker({"kind":"resident_status","operation_id":operation.operation_id})
	if not observed.get("ok",false):
		await _fail(str(observed.error),true,false)
		return
	var failed: Dictionary = observed.result.get("active",{})
	var failed_area := str(failed.get("identity",{}).get("area_id",""))
	if not bool(failed.get("failed",false)) or failed_area!=active_area \
			or failed.get("identity",{})!=_area_identity(active_area):
		await _fail("The native failed-owner identity does not match this recovery profile.",true,false)
		return
	var reserved := _reserve_publication()
	if not reserved.get("ok",false):
		await _fail(str(reserved.error),true,false)
		return
	var updates := {}
	for receipt: Dictionary in observed.result.get("inactive",[]):
		var id := str(receipt.get("identity",{}).get("area_id",""))
		if bool(receipt.get("failed",false)): continue
		if not id in Fixtures.IDS or id==failed_area or receipt.get("identity",{})!=_area_identity(id) \
				or int(_cache.entry(id).hot.get("handle",-1))!=int(receipt.get("handle",-2)):
			_release_publication()
			await _fail("A healthy inactive native owner differs from its exact cached identity.",true,false)
			return
		_set_phase("Capturing recoverable areas","Capturing healthy inactive area %s; the failed owner remains untouched…" % id.to_upper())
		var captured := await _worker({"kind":"resident_capture","operation_id":operation.operation_id,"receipt":receipt})
		if not captured.get("ok",false):
			_release_publication()
			await _fail(str(captured.error),true,false)
			return
		var entry: Dictionary = _cache.entry(id)
		updates[id] = {"capture":captured.result.capsule,"authoring":entry.authoring,
			"incarnation":entry.incarnation,"mutation_generation":int(entry.mutation_generation)}
	for id: String in Fixtures.IDS:
		var entry: Dictionary = _cache.entry(id)
		if id!=failed_area and not updates.has(id) and entry.hot.is_empty() and not entry.warm.is_empty():
			updates[id] = {"capture":entry.warm,"authoring":entry.authoring,
				"incarnation":entry.incarnation,"mutation_generation":int(entry.mutation_generation)}
	var planned := AreaRecovery.plan(manifest,clock,failed_area,updates,str(operation.operation_id))
	if not planned.get("ok",false):
		_release_publication()
		await _fail(str(planned.error),true,false)
		return
	var old_failed_record: Dictionary = manifest.areas[failed_area].duplicate(true)
	var resident_clock: Dictionary = clock.duplicate(true)
	var expected_revision := int(manifest.revision)+1
	var expected_updates := {}
	for id: String in updates:
		expected_updates[id] = {"native_sha256":str(updates[id].capture.sha256),
			"authoring_sha256":str(_cache.entry(id).authoring_sha256),
			"mutation_generation":int(updates[id].mutation_generation),"incarnation":str(updates[id].incarnation),
			"completed_tick":int(updates[id].capture.completed_tick)}
	_recovery_save_pending = {"session_id":str(manifest.session_id),"failed_area":failed_area,
		"failed_receipt":failed.duplicate(true),"previous_manifest":manifest.duplicate(true),
		"expected_revision":expected_revision,"expected_state":planned.state.duplicate(true),
		"expected_updates":expected_updates,"resident_clock":resident_clock,"summary":planned.summary.duplicate(true)}
	var started := _writeback.start(_store,planned.state,planned.updates,int(manifest.revision))
	if not started.get("ok",false):
		_recovery_save_pending = {}
		_release_publication()
		await _fail(str(started.error),true,false)
		return
	_cache.resize_publication(_publication_reservation_id,maxi(1024*1024,3*int(started.batch_bytes)))
	_writeback_state = {"status":"running","snapshot_id":started.snapshot_id,"recovery":true}
	_io_metrics.recovery_publications += 1
	_set_phase("Saving recoverable areas","Publishing the captured healthy areas and their explicitly bounded recovery clock…")
	await _wait_writeback()
	if _writeback_state.get("status","")!="idle" or int(manifest.revision)!=expected_revision \
			or manifest.areas[failed_area]!=old_failed_record or clock!=resident_clock \
			or not _recovery_manifest_error(manifest,_recovery_save_pending).is_empty():
		await _fail("Healthy-area recovery did not receive its exact durable acknowledgement. All native owners remain retained.",true,false)
		return
	_acknowledge_recoverable_save()


func _recovery_manifest_error(value: Dictionary, pending: Dictionary) -> String:
	if pending.is_empty() or str(value.get("session_id",""))!=str(pending.session_id) \
			or int(value.get("revision",-1))!=int(pending.expected_revision) \
			or str(value.get("active_area",""))!=str(pending.failed_area) or value.get("clock",{})!=pending.expected_state.clock:
		return "The recovery manifest does not match its retained session, revision or game-time frontier."
	for id: String in Fixtures.IDS:
		if not pending.expected_updates.has(id):
			if value.areas[id]!=pending.previous_manifest.areas[id]: return "Recovery changed an area outside its captured healthy set."
			continue
		for field: String in pending.expected_updates[id]:
			if value.areas[id].get(field)!=pending.expected_updates[id][field]:
				return "The recovered healthy checkpoint differs from its retained "+field+"."
	return ""


func _retry_recoverable_storage() -> void:
	await _wait_writeback()
	await _wait_prefetch()
	var observed := await _worker({"kind":"resident_status","operation_id":operation.operation_id})
	if not observed.get("ok",false) or not bool(observed.get("result",{}).get("active",{}).get("failed",false)):
		await _fail("Recovery storage retry cannot verify the unchanged failed native owner.",true,false)
		return
	if not _recovery_save_pending.is_empty():
		var failed: Dictionary = observed.result.active
		if failed.get("identity",{})!=_recovery_save_pending.failed_receipt.identity \
				or int(failed.get("handle",-1))!=int(_recovery_save_pending.failed_receipt.handle) \
				or clock!=_recovery_save_pending.resident_clock:
			await _fail("Recovery storage retry found a changed resident owner or game clock; no native state was restored.",true,false)
			return
	await _io("close_profile",[])
	var opened := await _io("_open_with_identity",[profile_path,_native_library])
	if not opened.get("ok",false) or opened.get("fresh",false) \
			or str(opened.get("manifest",{}).get("session_id",""))!=str(manifest.session_id):
		await _fail(str(opened.get("error","The existing recovery session could not be verified.")),true,false)
		return
	var matched_pending := false
	if not _recovery_save_pending.is_empty():
		matched_pending = _recovery_manifest_error(opened.manifest,_recovery_save_pending).is_empty()
		if not matched_pending and opened.manifest!=_recovery_save_pending.previous_manifest:
			await _fail("Reopened storage matches neither the pending healthy recovery snapshot nor its previous acknowledged manifest.",true,false)
			return
	var acknowledged := _cache.durable_ack(opened.manifest)
	if not acknowledged.get("ok",false):
		await _fail(str(acknowledged.error),true,false)
		return
	manifest = opened.manifest.duplicate(true)
	_profile_open = true
	_publication_uncertain = false
	_force_profile_reopen = false
	_owner_recovery_requires_restore = false
	_writeback_state = {"status":"idle"}
	if matched_pending:
		_acknowledge_recoverable_save()
		return
	# A definitely unpublished snapshot can be retried from the still-retained
	# healthy owners. Neither path captures, resets or reloads the failed World.
	_recovery_save_pending = {}
	await _run_recoverable_save()


func _acknowledge_recoverable_save() -> void:
	_recovery_save_summary = _recovery_save_pending.summary.duplicate(true)
	_recovery_save_summary["acknowledged_revision"] = int(manifest.revision)
	_recovery_save_pending = {}
	active_ready = false
	busy = false
	_quarantined = true
	host.paused = true
	host.update_worker_frame_state()
	last_result = {"ok":true,"ordinary_save_all":false,"recovery":_recovery_save_summary.duplicate(true)}
	_record_operation_terminal("healthy_areas_saved")
	_set_phase("Failed / healthy areas saved","Saved healthy areas %s. Area %s remains failed in RAM; its last durable tick is %d. The recovery save omits %d RAM-only game ticks. Close recovery profile explicitly to reopen that saved state." % [
		", ".join(_recovery_save_summary.saved_areas),str(_recovery_save_summary.failed_area).to_upper(),
		int(_recovery_save_summary.failed_area_durable_native_tick),int(_recovery_save_summary.omitted_ram_game_ticks)])


func _recovery_close_state() -> Dictionary:
	if host==null or not host.simulation_worker.has_failed() or busy or not _profile_open \
			or int(manifest.get("revision",0))<1 or not active_area in Fixtures.IDS \
			or _publication_uncertain or _force_profile_reopen or _writeback.busy() \
			or not _recovery_save_pending.is_empty() or not _unresolved_worker.is_empty() \
			or not _resident_handoff.is_empty() or not _resident_advancement.is_empty() or _owner_cleanup_required:
		return {}
	for id: String in Fixtures.IDS:
		if _cache_open and id!=active_area and bool(_cache.entry(id).dirty): return {}
	if not _recovery_save_summary.is_empty():
		if int(manifest.revision)!=int(_recovery_save_summary.acknowledged_revision): return {}
		var saved: Dictionary = _recovery_save_summary.duplicate(true)
		saved["durable_revision"] = int(manifest.revision)
		saved["has_healthy_recovery"] = true
		return saved
	# A first-visit failure may have no healthy resident entry to capture.
	# Other areas are already durable, so explicit loss acknowledgement may
	# close against the validated last profile without inventing a new Save.
	return {"failed_area":active_area,"failed_area_durable_native_tick":int(manifest.areas[active_area].completed_tick),
		"durable_revision":int(manifest.revision),"saved_areas":[],"has_healthy_recovery":false,
		"omitted_ram_game_ticks":maxi(0,int(clock.game_ticks)-int(manifest.clock.game_ticks)),"ordinary_save_all":false}


func request_recovery_exit(destination: String, expected_revision: int = 0) -> bool:
	var state := _recovery_close_state()
	if not destination in ["launcher","quit"] or state.is_empty() \
			or (expected_revision>0 and expected_revision!=int(state.durable_revision)):
		return _refuse("No matching acknowledged recovery profile is available for this explicit close; unsaved healthy areas must be preserved first.")
	_begin("close_recovery",active_area)
	_exit_destination = destination
	_close_without_save.call_deferred()
	return true


func _begin(kind: String, target: String) -> void:
	busy = true
	_cancel_requested = false
	_candidate_durable = false
	_candidate_committed = false
	_resume_play = not host.paused if active_ready else not _start_paused
	operation = {"kind":kind,"operation_id":AreaStore.new_nonce(),"source_area":active_area,
		"target_area":target,"requested_ticks":0,"completed_ticks":0,"remaining_future_ticks":0,
		"started_msec":Time.get_ticks_msec(),"started_usec":Time.get_ticks_usec(),
		"cancellable":kind not in ["open","close","close_recovery","recover","retry","retry_recoverable_storage"],
		"cancel_requested":false,"detail":"Freezing the active owner at a native boundary…",
		"measurement_tag":qualification_measurement_tag,"measurement_totals":{},
		"native_ticks_executed":0,"native_slice_count":0,
		"game_tick_before":int(clock.game_ticks),"debt_before_ticks":AreaClock.debt(clock,target),
		"target_native_tick_before":int(clock.areas.get(target,{}).get("native_ticks",-1))}
	operation["io_before"] = _io_metrics.duplicate(true)
	operation["residency"] = "COLD"
	operation["max_main_frame_ms"] = 0.0
	operation["worst_frame_start_usec"] = 0
	operation["worst_frame_end_usec"] = 0
	operation["frame_observations"] = 0
	if kind=="travel" and _prefetch_busy and target==str(_prefetch_operation.get("area_id","")):
		_io_metrics.prefetch_missed_deadlines += 1
		operation["prefetch_incomplete_on_request"] = true
	_prefetch_cancel = true
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
	if _cache_open and not _cache_configuration.enabled:
		# Cache-off restoration publications refresh their metadata ledger.
		# Reinitialize only that disabled, resource-free ledger before opening
		# the restored manifest; resident authorities must remain retained.
		var metadata: Dictionary = _cache.status()
		if int(metadata.hot_count)>0 or int(metadata.warm_count)>0 \
				or int(metadata.pending_reservations)>0 or int(metadata.essential_publication_reserved_bytes)>0:
			await _fail("The disabled cache still owns retained resources; profile reopening cannot replace its ledger.",true)
			return
		_cache = AreaCache.new()
		_cache_open = false
	var cached := _cache.open(manifest,int(_cache_configuration.budget_bytes))
	if not cached.get("ok",false):
		await _fail(str(cached.error),true)
		return
	_cache_open = true
	_cache.configure(bool(_cache_configuration.enabled),int(_cache_configuration.budget_bytes))
	_runtime_sha256 = str(manifest.compatibility).get_slice(":",str(manifest.compatibility).get_slice_count(":")-1)
	if _cache_configuration.enabled:
		var remembered := await _remember_active()
		if not remembered.get("ok",false):
			await _fail(str(remembered.error),true)
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
	await _wait_writeback()
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


func _freeze_live() -> Dictionary:
	_set_phase("Capturing","Acquiring the exclusive native handoff boundary…")
	var started := Time.get_ticks_usec()
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while Time.get_ticks_msec()<deadline:
		var owner: Dictionary = host.simulation_worker.paint_state()
		var frozen := await _worker({"kind":"freeze","operation_id":operation.operation_id,
			"expected_generation":int(owner.get("generation",-1))})
		if frozen.get("ok",false):
			operation["pause_drain_us"] = Time.get_ticks_usec()-started
			return frozen
		if not frozen.get("retryable",false): return frozen
		await get_tree().process_frame
	return _error("The active owner did not reach its bounded hot handoff boundary.")


func _area_identity(id: String) -> Dictionary:
	var record: Dictionary = manifest.get("areas",{}).get(id,{})
	return {"session_id":str(manifest.get("session_id","")),"area_id":id,
		"incarnation":str(record.get("incarnation","")),"runtime_sha256":_runtime_sha256,
		"authored_source_sha256":str(record.get("authored_source_sha256",""))}


func _remember_active(reservation_id: String = "", allow_active_over_budget: bool = true) -> Dictionary:
	if active_area.is_empty(): return _error("No active area can be admitted to the native cache.")
	var admitted := await _worker({"kind":"resident_bind","operation_id":operation.operation_id,
		"identity":_area_identity(active_area)})
	if not admitted.get("ok",false): return admitted
	var receipt: Dictionary = admitted.result.get("receipt",{})
	if receipt.is_empty(): return _error("The native resident admission returned no exact owner receipt.")
	var observed := AreaClock.active(clock,active_area,int(receipt.completed_tick))
	if not observed.get("ok",false): return observed
	clock = observed.clock
	var authoring: Dictionary = host.persistent_authoring_state()
	var before: Dictionary = _cache.entry(active_area)
	var generation := int(before.mutation_generation)
	var changed: bool = int(before.completed_tick) != int(receipt.completed_tick) \
		or (not before.hot.is_empty() and int(before.hot.mutation_generation)!=int(receipt.mutation_generation)) \
		or (not before.authoring.is_empty() and before.authoring != authoring)
	if changed: generation += 1
	generation = maxi(generation,int(receipt.mutation_generation))
	var cached: Dictionary = _cache.refresh_hot(active_area,receipt,generation,authoring) \
		if not before.hot.is_empty() else _cache.admit_hot(active_area,receipt,authoring,generation,reservation_id,allow_active_over_budget)
	if not cached.get("ok",false): return cached
	_cache.set_active(active_area)
	_resident_clock_dirty = _resident_clock_dirty or int(observed.get("completed_ticks",0))>0
	return {"ok":true,"receipt":receipt}


func _refresh_resident(id: String, receipt: Dictionary, authoring: Dictionary = {}, reservation: String = "") -> Dictionary:
	var entry: Dictionary = _cache.entry(id)
	var generation := int(entry.mutation_generation)
	if int(receipt.get("completed_tick",-1)) != int(entry.completed_tick) \
		or (not entry.hot.is_empty() and int(receipt.get("mutation_generation",-1)) != int(entry.hot.mutation_generation)):
		generation += 1
	generation = maxi(generation,int(receipt.get("mutation_generation",0)))
	if authoring.is_empty(): authoring = entry.authoring
	if not entry.hot.is_empty(): return _cache.refresh_hot(id,receipt,generation,authoring)
	return _cache.admit_hot(id,receipt,authoring,generation,reservation,id==active_area)


func _run_cached_operation(requested_future_ticks: int) -> void:
	# Any speculative thread must return its ownership before an explicit
	# transition. Completed reusable state is retained; obsolete intent yields.
	await _wait_prefetch(operation.kind=="travel")
	var frozen := await _freeze_live()
	if not frozen.get("ok",false):
		await _fail(str(frozen.error))
		return
	var remembered := await _remember_active()
	if not remembered.get("ok",false):
		await _fail(str(remembered.error),true)
		return
	if _cancel_requested:
		await _finish("Cancelled at the retained native boundary; resident state is unchanged.")
		return
	if operation.kind in ["save","exit","background_save","cache_configure","evict"]:
		var saved := await _flush_resident_state(operation.kind == "background_save")
		if not saved.get("ok",false):
			await _fail(str(saved.error),bool(saved.get("quarantined",false)))
			return
		if operation.kind == "exit":
			await _finish_exit()
			return
		if operation.kind in ["cache_configure","evict"]:
			var evicted := await _apply_cache_policy(operation.kind == "evict")
			if not evicted.get("ok",false):
				await _fail(str(evicted.error))
				return
		await _finish("Background saving is pending; current state remains in RAM." if operation.kind == "background_save"
			else "All resident area changes and the game clock are durably saved.")
		return
	if not _cache_configuration.deferred:
		var saved := await _flush_resident_state(false)
		if not saved.get("ok",false):
			await _fail(str(saved.error),bool(saved.get("quarantined",false)))
			return
		await _qualification_boundary("source_durable")
	var target := str(operation.target_area)
	var entry: Dictionary = _cache.entry(target)
	operation.residency = "HOT" if not entry.hot.is_empty() else ("WARM" if not entry.warm.is_empty() else "COLD")
	_cache.record_hit(str(operation.residency))
	if not entry.hot.is_empty():
		var advanced := await _advance_resident(target,requested_future_ticks)
		if not advanced.get("ok",false):
			await _fail(str(advanced.error))
			return
		if not _cache_configuration.deferred:
			var durable := await _flush_resident_state(false)
			if not durable.get("ok",false):
				await _fail(str(durable.error),bool(durable.get("quarantined",false)))
				return
			_candidate_durable = true
			await _qualification_boundary("candidate_durable")
		if target != active_area and not _cancel_requested:
			var activated := await _activate_hot(target)
			if not activated.get("ok",false):
				await _fail(str(activated.error),bool(activated.get("quarantined",false)))
				return
	else:
		var restored := await _restore_cached_target(target,requested_future_ticks)
		if not restored.get("ok",false):
			await _fail(str(restored.error),bool(restored.get("quarantined",false)))
			return
	if not _cache_configuration.deferred and not _cancel_requested:
		var selected := await _flush_resident_state(false)
		if not selected.get("ok",false):
			await _fail(str(selected.error),bool(selected.get("quarantined",false)))
			return
	var detail := "%s arrival · %d native ticks completed · %.2f s remaining debt." % [
		str(operation.residency),int(operation.completed_ticks),float(AreaClock.debt(clock,active_area))/AreaClock.TICKS_PER_SECOND]
	if _cache_configuration.deferred:
		detail += " Changes retained in RAM; Save all waits for durability."
	if _cancel_requested: detail = "Cancelled safely. " + detail
	await _finish(detail)


func _advance_resident(target: String, future_ticks: int) -> Dictionary:
	if not _resident_advancement.is_empty():
		return _error("The previous resident advancement still owns its native completion and game-time plan.")
	var planned := AreaClock.plan(clock,target,"ahead" if operation.kind=="ahead" else "catch_up",future_ticks,MAX_OPERATION_TICKS)
	if not planned.get("ok",false): return planned
	var plan: Dictionary = planned.plan
	operation.plan_source_native_tick = int(plan.source_native_tick)
	operation.plan_source_debt_ticks = int(plan.source_debt_ticks)
	operation.requested_future_ticks = future_ticks
	operation.requested_ticks = int(plan.work_ticks)
	operation.remaining_future_ticks = future_ticks
	if int(plan.work_ticks)==0:
		_record_metric("completed_ticks",0)
		return {"ok":true,"completed_ticks":0}
	# Native work survives a host deadline. Keep its original debt/future split
	# and admit every completed prefix before submitting another slice. A late
	# result must never be reclassified as ordinary active gameplay time.
	_resident_advancement = {"operation_id":str(operation.operation_id),"session_id":str(manifest.session_id),
		"source_area":active_area,"target_area":target,"source_clock":AreaClock.canonical(clock),
		"plan":plan.duplicate(true),"accounted_ticks":0,"pending":{},"metrics_recorded":false}
	var completed := 0
	var started := Time.get_ticks_msec()
	while completed<int(plan.work_ticks) and not _cancel_requested and Time.get_ticks_msec()-started<MAX_CATCH_UP_MSEC:
		_set_phase("Catching up","Advancing the retained native World; unfinished game time remains debt…")
		var entry: Dictionary = _cache.entry(target)
		var request := {"kind":"advance_active" if target==active_area else "resident_advance",
			"operation_id":operation.operation_id,"receipt":entry.hot,
			"max_ticks":mini(MAX_NATIVE_SLICE_TICKS,int(plan.work_ticks)-completed),"max_us":MAX_NATIVE_SLICE_USEC}
		_resident_advancement.pending = {"kind":str(request.kind),"receipt":entry.hot.duplicate(true),
			"max_ticks":int(request.max_ticks),"start_tick":int(plan.source_native_tick)+completed,"token":0}
		var stepped := await _worker(request)
		if not stepped.get("ok",false):
			if int(_resident_advancement.pending.token)==0:
				# Admission refusal performed no native work. Earlier admitted
				# prefixes remain authoritative and still guard owner release.
				_resident_advancement.pending = {}
			return stepped
		var admitted := _accept_resident_step(stepped.get("result",{}))
		if not admitted.get("ok",false): return admitted
		completed = int(_resident_advancement.accounted_ticks)
		if int(admitted.completed_ticks)==0: break
	_record_resident_advancement_completion()
	return {"ok":true,"completed_ticks":completed}


func _accept_resident_step(result: Dictionary, known_failed_active: bool = false) -> Dictionary:
	if _resident_advancement.is_empty() or str(_resident_advancement.operation_id)!=str(operation.operation_id) \
			or str(_resident_advancement.session_id)!=str(manifest.session_id):
		return _error("Resident completion no longer has its original operation and session.")
	var pending: Dictionary = _resident_advancement.get("pending",{})
	if pending.is_empty() or int(pending.get("token",0))<=0:
		return _error("Resident completion has no exact admitted native request.")
	var target := str(_resident_advancement.target_area)
	var plan: Dictionary = _resident_advancement.plan
	var prefix := int(_resident_advancement.accounted_ticks)
	var previous := AreaClock.complete(_resident_advancement.source_clock,plan,prefix)
	if not previous.get("ok",false) or AreaClock.canonical(clock)!=previous.clock:
		return _error("Resident completion is stale for its admitted game-time prefix.")
	if not result.get("completed_ticks") is int or not result.get("current_tick") is int \
			or not result.get("receipt") is Dictionary:
		return _error("Resident completion has no verified native tick interval and owner receipt.")
	var actual := int(result.completed_ticks)
	var receipt: Dictionary = result.receipt
	var expected: Dictionary = pending.receipt
	for field: String in ["resident_generation","mutation_generation","worker_threads"]:
		if not receipt.get(field) is int or not expected.get(field) is int \
				or int(receipt[field])<0 or int(expected[field])<0:
			return _error("Resident completion has an invalid native generation or execution fence.")
	if not result.get("ok") is bool or not receipt.get("failed") is bool \
			or bool(expected.get("failed",true)) \
			or (known_failed_active and (str(pending.kind)!="advance_active" or result.ok or not receipt.failed)) \
			or (not known_failed_active and (not result.ok or receipt.failed)):
		return _error("Resident completion does not prove the expected healthy or explicitly failed native outcome.")
	if actual<0 or actual>int(pending.max_ticks) \
			or int(pending.start_tick)!=int(plan.source_native_tick)+prefix \
			or int(result.current_tick)!=int(pending.start_tick)+actual \
			or int(receipt.get("completed_tick",-1))!=int(result.current_tick) \
			or int(receipt.get("handle",0))!=int(expected.get("handle",-1)) \
			or receipt.get("identity",{})!=expected.get("identity",{}) \
			or str(receipt.get("physics_profile_sha256",""))!=str(expected.get("physics_profile_sha256","")) \
			or int(receipt.resident_generation)!=int(expected.resident_generation) \
			or int(receipt.worker_threads)!=int(expected.worker_threads) \
			or int(receipt.mutation_generation)<int(expected.mutation_generation) \
			or bool(receipt.get("active",false))!=(str(pending.kind)=="advance_active"):
		return _error("Resident completion differs from its exact target and native completed-tick interval.")
	var accounted := AreaClock.complete(_resident_advancement.source_clock,plan,prefix+actual)
	if not accounted.get("ok",false): return accounted
	var refreshed := _refresh_resident(target,receipt)
	if not refreshed.get("ok",false): return refreshed
	# No await occurs between admitting the completed native receipt and its
	# corresponding accounted frontier. The original plan supplies both debt
	# repayment and any genuinely completed future ticks, including late work.
	clock = accounted.clock
	_resident_advancement.accounted_ticks = prefix+actual
	_resident_advancement.pending = {}
	_resident_clock_dirty = _resident_clock_dirty or actual>0
	operation.completed_ticks = prefix+actual
	operation.remaining_future_ticks = int(accounted.remaining_future_ticks)
	operation.native_ticks_executed = int(operation.native_ticks_executed)+actual
	operation.native_slice_count = int(operation.native_slice_count)+1
	var elapsed := int(result.get("elapsed_us",result.get("native_step_us",0)))
	_record_metric("native_step_us",float(elapsed))
	_measurement_slice_sequence += 1
	_record_metric("native_slices",{"sequence":_measurement_slice_sequence,"operation_id":operation.operation_id,
		"kind":operation.kind,"source_area":operation.source_area,"target_area":target,
		"measurement_tag":operation.measurement_tag,"ticks":actual,"elapsed_us":elapsed,
		"observed_workers":int(result.get("observed_workers",0)),
		"start_completed_tick":int(pending.start_tick),"end_completed_tick":int(result.current_tick)})
	return {"ok":true,"completed_ticks":actual,"native_failed":known_failed_active}


func _accept_resident_terminal(observed: Dictionary) -> Dictionary:
	var phase := str(observed.get("status",""))
	var failed_active: bool = phase=="failed" and not bool(observed.get("ok",true)) \
		and str(_resident_advancement.get("pending",{}).get("kind",""))=="advance_active" \
		and host.simulation_worker.has_failed()
	if not failed_active and (phase!="complete" or not observed.get("ok",false)):
		return _error("The resident interval has no verified terminal native outcome; its owner remains quarantined.")
	var accepted := _accept_resident_step(observed.get("result",{}),failed_active)
	if accepted.get("ok",false) and failed_active:
		# The receipt proves only completed ticks before the failure. The failing
		# tick is not credited or captured, and this World will never be resumed.
		_resident_advancement["terminal_failure"] = true
		_resident_advancement["native_error"] = str(observed.get("error","Native continuation failed."))
	return accepted


func _record_resident_advancement_completion() -> void:
	if not _resident_advancement.is_empty() and not bool(_resident_advancement.get("metrics_recorded",false)):
		_record_metric("completed_ticks",int(_resident_advancement.accounted_ticks))
		_resident_advancement.metrics_recorded = true


func _activate_hot(target: String) -> Dictionary:
	var entry: Dictionary = _cache.entry(target)
	var source: Dictionary = _cache.entry(active_area)
	var identity := _area_identity(target)
	identity["operation_id"] = str(operation.operation_id)
	var staged: Dictionary = host.persistent_stage_hot_area(entry.authoring,entry.hot,identity)
	if not staged.get("ok",false): return staged
	# Keep both authoritative owners and Main's exact pending serial until the
	# complete transfer acknowledges. A late completion cannot fall through to
	# the donor's disk recovery route, which may predate dirty resident edits.
	_resident_handoff = {"route":"HOT","operation_id":str(operation.operation_id),"session_id":str(manifest.session_id),
		"source_area":active_area,"target_area":target,"source_receipt":source.hot.duplicate(true),
		"target_receipt":entry.hot.duplicate(true),"serial":int(staged.serial),
		"previous_generation":int(staged.previous_generation),"started_usec":Time.get_ticks_usec()}
	operation["main_ack_serial"] = int(staged.serial)
	_set_phase("Ready for activation","Transferring the admitted resident World and waiting for Main acknowledgement…")
	var activated := await _worker({"kind":"activate_resident","operation_id":operation.operation_id,
		"target_receipt":entry.hot,"active_receipt":source.hot,"serial":int(staged.serial),"identity":identity,
		"expected_generation":int(staged.previous_generation),"worker_ticket":staged.worker_ticket})
	if not activated.get("ok",false):
		if _unresolved_worker.is_empty():
			# An acknowledged native refusal is atomic and retains the source.
			host.persistent_cancel_hot_stage(int(staged.serial),str(activated.error))
			_resident_handoff = {}
		return activated
	if not activated.result.get("committed",false):
		return {"ok":false,"error":"Resident transfer returned no native commit acknowledgement.","quarantined":true}
	_candidate_committed = true
	var source_receipt: Dictionary = activated.result.get("source_receipt",{})
	var target_receipt: Dictionary = activated.result.get("target_receipt",{})
	return await _accept_hot_handoff(source_receipt,target_receipt)


func _accept_hot_handoff(source_receipt: Dictionary, target_receipt: Dictionary) -> Dictionary:
	if _resident_handoff.is_empty() or str(_resident_handoff.operation_id)!=str(operation.operation_id) \
			or str(_resident_handoff.session_id)!=str(manifest.session_id):
		return {"ok":false,"error":"The resident handoff no longer has its original operation and session.","quarantined":true}
	var source := str(_resident_handoff.source_area)
	var target := str(_resident_handoff.target_area)
	if source_receipt.is_empty() or target_receipt.is_empty():
		return {"ok":false,"error":"Resident transfer returned incomplete ownership receipts.","quarantined":true}
	for pair: Array in [[source,source_receipt,_resident_handoff.source_receipt],[target,target_receipt,_resident_handoff.target_receipt]]:
		if pair[1].get("identity",{})!=pair[2].get("identity",{}) or int(pair[1].get("handle",-1))!=int(pair[2].get("handle",-2)) \
				or int(pair[1].get("completed_tick",-1))!=int(clock.areas[pair[0]].native_ticks):
			return {"ok":false,"error":"The resident handoff identity or completed time differs from its retained authority.","quarantined":true}
	if bool(source_receipt.get("active",true)) or not bool(target_receipt.get("active",false)):
		return {"ok":false,"error":"Native did not acknowledge one inactive source and one active target.","quarantined":true}
	var source_updated := _refresh_resident(source,source_receipt)
	var target_updated := _refresh_resident(target,target_receipt)
	if not source_updated.get("ok",false) or not target_updated.get("ok",false):
		return {"ok":false,"error":"Resident transfer cache acknowledgement failed: "+str(source_updated.get("error",target_updated.get("error",""))),"quarantined":true}
	var accepted := await _wait_install_ack(int(_resident_handoff.serial),int(_resident_handoff.previous_generation))
	if not accepted.get("ok",false):
		accepted["quarantined"] = true
		return accepted
	if not bool(_resident_handoff.get("main_acknowledged",false)):
		if str(_resident_handoff.get("route","HOT"))=="HOT":
			operation["hot_handoff_us"] = Time.get_ticks_usec()-int(_resident_handoff.started_usec)
			_io_metrics.hot_handoffs += 1
			var preparation: Dictionary = _prefetched_handles.get(target,{})
			if int(preparation.get("handle",-1))==int(target_receipt.handle) \
					and preparation.get("identity",{})==target_receipt.identity:
				_io_metrics.prefetch_hits += 1
				operation["prefetch_hit"] = true
				operation["prefetch_operation_id"] = str(preparation.operation_id)
				_prefetched_handles.erase(target)
				if _prefetch_state.get("ready_area","")==target: _prefetch_state.erase("ready_area")
		_recent_areas.erase(source)
		_recent_areas.push_front(source)
		if _recent_areas.size()>3: _recent_areas.pop_back()
	active_area = target
	_cache.set_active(target)
	_last_world_generation = int(host.latest_snapshot.render_world_generation)
	_resident_clock_dirty = true # The selected-area durable hint also changed.
	# Keep this identity until the owner lease release itself acknowledges.
	# A late release is another recoverable RAM transaction, not permission to
	# reconstruct an older durable checkpoint. Retried acceptance is idempotent.
	_resident_handoff["main_acknowledged"] = true
	return {"ok":true}


func _reconcile_hot_handoff() -> Dictionary:
	if _resident_handoff.is_empty(): return {"ok":true,"recovered":false}
	if str(_resident_handoff.operation_id)!=str(operation.operation_id) \
			or str(_resident_handoff.session_id)!=str(manifest.session_id) or host.simulation_worker.has_failed():
		return _error("The retained hot handoff cannot recover against a different or failed native owner.")
	if str(_resident_handoff.get("route","HOT"))!="HOT" and _resident_handoff.target_receipt.is_empty() and _candidate_committed:
		var admitted := await _admit_restored_handoff()
		if not admitted.get("ok",false): return admitted
	var observed := await _worker({"kind":"resident_status","operation_id":operation.operation_id})
	if not observed.get("ok",false): return observed
	var active: Dictionary = observed.result.get("active",{})
	var source := str(_resident_handoff.source_area)
	if not _resident_handoff.target_receipt.is_empty() \
			and active.get("identity",{})==_resident_handoff.target_receipt.identity \
			and int(active.get("handle",-1))==int(_resident_handoff.target_receipt.handle):
		var inactive_source := {}
		for receipt: Dictionary in observed.result.get("inactive",[]):
			if int(receipt.get("handle",-1))==int(_resident_handoff.source_receipt.handle): inactive_source = receipt
		_candidate_committed = true
		var accepted := await _accept_hot_handoff(inactive_source,active)
		if accepted.get("ok",false): accepted["recovered"] = true
		return accepted
	if active.get("identity",{})==_resident_handoff.source_receipt.identity \
			and int(active.get("handle",-1))==int(_resident_handoff.source_receipt.handle) \
			and int(active.get("completed_tick",-1))==int(clock.areas[source].native_ticks) \
			and not _candidate_committed:
		# An acknowledged late refusal never transferred ownership. Retire only
		# that Main stage; the unchanged source and its dirty edits remain live.
		if str(_resident_handoff.get("route","HOT"))=="HOT":
			host.persistent_cancel_hot_stage(int(_resident_handoff.serial),"")
		elif not host.pending_microscenario_apply.is_empty():
			var discarded := await _discard_candidate()
			if not discarded.get("ok",false): return discarded
		var refreshed := _refresh_resident(source,active)
		if not refreshed.get("ok",false): return refreshed
		active_area = source
		_cache.set_active(source)
		_resident_handoff["main_acknowledged"] = true
		_resident_handoff["source_retained"] = true
		return {"ok":true,"recovered":true,"refused":true}
	return _error("Native authority matches neither side of the retained hot handoff; both RAM owners remain quarantined.")


func _admit_restored_handoff() -> Dictionary:
	# The cold constructor has committed, but Main may not have consumed its
	# snapshot yet. Bind that exact live native target under the original lease
	# before acknowledging presentation, using the already validated envelope.
	if _resident_handoff.is_empty() or not _candidate_committed \
			or str(_resident_handoff.operation_id)!=str(operation.operation_id):
		return _error("No acknowledged restored candidate is available for resident admission.")
	if not _lease_held:
		var frozen := await _freeze_live()
		if not frozen.get("ok",false): return frozen
	var target := str(_resident_handoff.target_area)
	var bound := await _worker({"kind":"resident_bind","operation_id":operation.operation_id,
		"identity":_resident_handoff.target_identity})
	if not bound.get("ok",false): return bound
	var receipt: Dictionary = bound.result.get("receipt",{})
	if receipt.is_empty() or receipt.get("identity",{})!=_resident_handoff.target_identity \
			or int(receipt.get("completed_tick",-1))!=int(_resident_handoff.accounted_clock.areas[target].native_ticks):
		return _error("The committed restored target differs from its retained identity or completed native interval.")
	if clock!=_resident_handoff.prior_clock and clock!=_resident_handoff.accounted_clock:
		return _error("The accounted game clock changed outside the retained restored-target transaction.")
	var retained := _refresh_resident(target,receipt,_resident_handoff.authoring,str(_resident_handoff.reservation_id))
	if not retained.get("ok",false): return retained
	_resident_handoff.target_receipt = receipt.duplicate(true)
	clock = _resident_handoff.accounted_clock.duplicate(true)
	operation.remaining_future_ticks = int(_resident_handoff.remaining_future_ticks)
	_resident_clock_dirty = true
	var observed := await _worker({"kind":"resident_status","operation_id":operation.operation_id})
	if not observed.get("ok",false): return observed
	var source_receipt := {}
	for inactive: Dictionary in observed.result.get("inactive",[]):
		if int(inactive.get("handle",-1))==int(_resident_handoff.source_receipt.handle): source_receipt = inactive
	if source_receipt.is_empty(): return _error("The restored target committed without its retained source owner acknowledgement.")
	return {"ok":true,"source_receipt":source_receipt,"target_receipt":receipt}


func _restore_cached_target(target: String, future_ticks: int) -> Dictionary:
	await _wait_writeback()
	var entry: Dictionary = _cache.entry(target)
	var reserved := await _reserve_target(target)
	if not reserved.get("ok",false):
		if reserved.get("cache_exhausted",false): return await _cold_budget_fallback(target,future_ticks)
		return reserved
	var loaded: Dictionary
	if not entry.warm.is_empty():
		loaded = {"ok":true,"capture":entry.warm,"authoring":entry.authoring,"record":entry.durable}
	else:
		_set_phase("Loading","Reading the selected area's validated durable continuation…")
		loaded = await _io("read_area",[target])
		_io_metrics.profile_read_calls += 1
		if loaded.get("ok",false): _io_metrics.profile_read_bytes += loaded.capture.bytes.size()
	if not loaded.get("ok",false):
		_cache.release_reservation(str(operation.operation_id))
		_note_storage_refusal(loaded)
		return loaded
	var planned := AreaClock.plan(clock,target,"ahead" if operation.kind=="ahead" else "catch_up",future_ticks,MAX_OPERATION_TICKS)
	if not planned.get("ok",false): return planned
	var plan: Dictionary = planned.plan
	operation.plan_source_native_tick = int(plan.source_native_tick)
	operation.plan_source_debt_ticks = int(plan.source_debt_ticks)
	operation.requested_future_ticks = future_ticks
	operation.requested_ticks = int(plan.work_ticks)
	operation.remaining_future_ticks = future_ticks
	var started := Time.get_ticks_usec()
	var prepared := await _install(loaded.authoring,loaded.capture,target,true)
	_io_metrics.native_deserializations += 1
	_record_metric("restore_ms",float(Time.get_ticks_usec()-started)/1000.0)
	if not prepared.get("ok",false):
		_cache.release_reservation(str(operation.operation_id))
		return prepared
	if _cancel_requested:
		_cache.release_reservation(str(operation.operation_id))
		return await _discard_candidate()
	var completed := 0
	var step_started := Time.get_ticks_msec()
	while completed<int(plan.work_ticks) and not _cancel_requested and Time.get_ticks_msec()-step_started<MAX_CATCH_UP_MSEC:
		_set_phase("Catching up","Advancing the privately restored destination before admission…")
		var stepped := await _worker({"kind":"advance","operation_id":operation.operation_id,
			"max_ticks":mini(MAX_NATIVE_SLICE_TICKS,int(plan.work_ticks)-completed),"max_us":MAX_NATIVE_SLICE_USEC})
		if not stepped.get("ok",false): return stepped
		var actual := int(stepped.result.get("completed_ticks",-1))
		if actual<0 or actual>mini(MAX_NATIVE_SLICE_TICKS,int(plan.work_ticks)-completed) \
				or int(stepped.result.get("current_tick",-1))!=int(plan.source_native_tick)+completed+actual:
			return _error("Private destination returned an invalid native time interval.")
		completed += actual
		operation.completed_ticks = completed
		operation.native_ticks_executed = int(operation.native_ticks_executed)+actual
		operation.native_slice_count = int(operation.native_slice_count)+1
		var elapsed := float(stepped.result.get("elapsed_us",0))
		operation.native_step_us = float(operation.get("native_step_us",0))+elapsed
		_record_metric("native_step_us",elapsed)
		_measurement_slice_sequence += 1
		_record_metric("native_slices",{"sequence":_measurement_slice_sequence,"operation_id":operation.operation_id,
			"kind":operation.kind,"source_area":operation.source_area,"target_area":target,
			"measurement_tag":operation.measurement_tag,"ticks":actual,"elapsed_us":elapsed,
			"observed_workers":int(stepped.result.get("observed_workers",0)),
			"start_completed_tick":int(plan.source_native_tick)+completed-actual,
			"end_completed_tick":int(plan.source_native_tick)+completed})
		if actual==0: break
	var accounted := AreaClock.complete(clock,plan,completed)
	if not accounted.get("ok",false): return accounted
	# Strict mode preserves the donor's candidate-before-adoption durability.
	# Deferred mode may adopt because the source remains an admitted hot World.
	if not _cache_configuration.deferred:
		var captured := await _worker({"kind":"capture_prepared","operation_id":operation.operation_id})
		if not captured.get("ok",false): return captured
		if int(captured.result.capsule.completed_tick)!=int(accounted.clock.areas[target].native_ticks):
			return _error("The retained destination capture differs from its verified completed native interval.")
		var mutation := maxi(int(entry.mutation_generation)+1,int(captured.result.get("mutation_generation",0)))
		var warmed := _cache.retain_warm(target,captured.result.capsule,loaded.authoring,mutation,
			str(entry.incarnation),str(operation.operation_id),false,true)
		if not warmed.get("ok",false): return warmed
		# The complete validated WARM capsule now owns the completed target
		# interval in RAM. Keep its accounted frontier with those bytes even if
		# disk publication fails. The source HOT World stays active, and strict
		# destination activation still waits for a positive durable ACK.
		clock = accounted.clock
		_resident_clock_dirty = true
		var stored := await _publish_resident_state({target:{"capture":captured.result.capsule,
			"authoring":loaded.authoring,"mutation_generation":mutation,"incarnation":entry.incarnation}})
		if not stored.get("ok",false): return stored
		_candidate_durable = true
		await _qualification_boundary("candidate_durable")
	if _cancel_requested:
		_cache.release_reservation(str(operation.operation_id))
		return await _discard_candidate()
	_resident_handoff = {"route":str(operation.residency),"operation_id":str(operation.operation_id),
		"session_id":str(manifest.session_id),"source_area":active_area,"target_area":target,
		"source_receipt":_cache.entry(active_area).hot.duplicate(true),"target_receipt":{},
		"target_identity":_area_identity(target),"authoring":loaded.authoring.duplicate(true),
		"prior_clock":clock.duplicate(true),"accounted_clock":accounted.clock.duplicate(true),
		"remaining_future_ticks":int(accounted.remaining_future_ticks),"reservation_id":str(operation.operation_id),
		"serial":int(prepared.serial),"previous_generation":int(prepared.previous_generation),
		"started_usec":Time.get_ticks_usec()}
	operation["main_ack_serial"] = int(prepared.serial)
	var committed := await _worker({"kind":"commit","operation_id":operation.operation_id})
	if not committed.get("ok",false):
		if _unresolved_worker.is_empty(): _resident_handoff = {}
		return committed
	_candidate_committed = true
	var remembered := await _admit_restored_handoff()
	if not remembered.get("ok",false):
		remembered["quarantined"] = true
		return remembered
	var accepted := await _accept_hot_handoff(remembered.source_receipt,remembered.target_receipt)
	if not accepted.get("ok",false): return accepted
	# The native cold commit retained the previous admitted owner. Refresh its
	# inactive fence before a later swap; no full state validation is required.
	var refreshed := await _refresh_native_receipts()
	if not refreshed.get("ok",false):
		refreshed["quarantined"] = true
		return refreshed
	_resident_clock_dirty = true
	_record_metric("completed_ticks",completed)
	return {"ok":true}


func _refresh_native_receipts() -> Dictionary:
	var observed := await _worker({"kind":"resident_status","operation_id":operation.operation_id})
	if not observed.get("ok",false): return observed
	var receipts: Array = observed.result.get("inactive",[]).duplicate()
	if observed.result.get("active") is Dictionary and not observed.result.active.is_empty(): receipts.append(observed.result.active)
	for receipt: Dictionary in receipts:
		var id := str(receipt.get("identity",{}).get("area_id",""))
		if id in Fixtures.IDS and not _cache.entry(id).hot.is_empty():
			var refreshed := _refresh_resident(id,receipt)
			if not refreshed.get("ok",false): return refreshed
	return {"ok":true}


func _flush_resident_state(background: bool) -> Dictionary:
	await _wait_writeback()
	await _wait_prefetch()
	var reserved := _reserve_publication()
	if not reserved.get("ok",false): return reserved
	var result := await _capture_and_flush_residents(background)
	if not result.get("pending",false): _release_publication()
	return result


func _reserve_publication() -> Dictionary:
	if not _cache_open: return {"ok":true}
	if not _publication_reservation_id.is_empty():
		return {"ok":true} if _publication_reservation_id==str(operation.operation_id) \
			else _error("Another immutable publication still owns its bounded working headroom.")
	var reserved := _cache.reserve_publication(str(operation.operation_id),AreaCache.MAX_PUBLICATION_HEADROOM_BYTES)
	if reserved.get("ok",false): _publication_reservation_id = str(operation.operation_id)
	return reserved


func _release_publication() -> void:
	if _publication_reservation_id.is_empty(): return
	var released := _cache.release_publication(_publication_reservation_id)
	if not released.get("ok",false): _pending_cache_failure = str(released.error)
	else: _publication_reservation_id = ""


func _capture_and_flush_residents(background: bool) -> Dictionary:
	await _wait_writeback()
	if _publication_uncertain: return _error("The previous publication is uncertain; retry storage before saving.")
	var updates := {}
	for id: String in Fixtures.IDS:
		var entry: Dictionary = _cache.entry(id)
		if not entry.dirty and int(entry.durable.completed_tick)==int(clock.areas[id].native_ticks): continue
		if entry.hot.is_empty():
			if entry.warm.is_empty(): return _error("Dirty area has no retained native or warm authority: "+id)
			updates[id] = {"capture":entry.warm,"authoring":entry.authoring,
				"mutation_generation":int(entry.mutation_generation),"incarnation":entry.incarnation}
			continue
		_set_phase("Capturing","Capturing area %s for an immutable background publication…" % id.to_upper())
		var started := Time.get_ticks_usec()
		var captured := await _worker({"kind":"resident_capture","operation_id":operation.operation_id,"receipt":entry.hot})
		if not captured.get("ok",false): return captured
		var capsule: Dictionary = captured.result.get("capsule",{})
		if capsule.is_empty() or int(capsule.get("completed_tick",-1))!=int(clock.areas[id].native_ticks):
			return _error("Captured resident authority and accounted native time disagree.")
		_record_metric("capture_ms",float(Time.get_ticks_usec()-started)/1000.0)
		_record_metric("native_capture_us",float(captured.result.get("capture_us",0)))
		updates[id] = {"capture":capsule,"authoring":entry.authoring,
			"mutation_generation":int(entry.mutation_generation),"incarnation":entry.incarnation}
	if updates.is_empty() and not _resident_clock_dirty and str(manifest.active_area)==active_area:
		return {"ok":true,"unchanged":true}
	if not background:
		return await _publish_resident_state(updates)
	var started: Dictionary = _writeback.start(_store,{"active_area":active_area,"clock":clock},updates,int(manifest.revision))
	if not started.get("ok",false): return started
	_cache.resize_publication(_publication_reservation_id,maxi(1024*1024,3*int(started.batch_bytes)))
	_io_metrics.background_publications += 1
	_writeback_state = {"status":"running","snapshot_id":started.snapshot_id,"batch_bytes":started.batch_bytes,
		"clock":clock.duplicate(true),"active_area":active_area}
	_resident_clock_dirty = false
	return {"ok":true,"pending":true,"snapshot_id":started.snapshot_id}


func _publish_resident_state(updates: Dictionary) -> Dictionary:
	# Every updated interval is already retained by an admitted HOT World or
	# complete validated WARM capsule, with the matching current RAM clock.
	# Retain bounded identity metadata rather than the encoded payloads.
	var pending := _resident_publication_identity(updates)
	var published := await _publish(clock,updates,active_area)
	if published.get("ok",false):
		_resident_clock_dirty = false
	elif _publication_uncertain or _force_profile_reopen or bool(published.get("quarantined",false)):
		_resident_publication_pending = pending
		_resident_storage_recovery_required = true
	return published


func _resident_publication_identity(updates: Dictionary) -> Dictionary:
	var expected_updates := {}
	for id: String in updates:
		expected_updates[id] = {"native_sha256":str(updates[id].capture.sha256),
			"authoring_sha256":str(_cache.entry(id).authoring_sha256),
			"mutation_generation":int(updates[id].mutation_generation),"incarnation":str(updates[id].incarnation),
			"completed_tick":int(updates[id].capture.completed_tick),"generation":int(manifest.areas[id].generation)+1,
			"native_format_version":int(updates[id].capture.format_version),
			"physical_hash_version":int(updates[id].capture.physical_hash_version)}
		for field: String in ["physical_hash","policy_sha256","authored_source_sha256","physics_profile_sha256"]:
			expected_updates[id][field] = updates[id].capture[field]
	return {"session_id":str(manifest.session_id),"operation_id":str(operation.operation_id),
		"previous_manifest":manifest.duplicate(true),"expected_revision":int(manifest.revision)+1,
		"expected_state":{"active_area":active_area,"clock":clock.duplicate(true)},
		"active_receipt":_cache.entry(active_area).hot.duplicate(true),"expected_updates":expected_updates}


func _resident_publication_error(value: Dictionary, pending: Dictionary) -> String:
	if pending.is_empty() or str(value.get("session_id",""))!=str(pending.session_id) \
			or int(value.get("revision",-1))!=int(pending.expected_revision) \
			or str(value.get("active_area",""))!=str(pending.expected_state.active_area) \
			or value.get("clock",{})!=pending.expected_state.clock:
		return "The resident publication differs from its retained session, revision, selection or game-time frontier."
	for id: String in Fixtures.IDS:
		if not pending.expected_updates.has(id):
			if value.areas[id]!=pending.previous_manifest.areas[id]: return "Resident publication changed an area outside its captured set."
			continue
		for field: String in pending.expected_updates[id]:
			if value.areas[id].get(field)!=pending.expected_updates[id][field]:
				return "The resident checkpoint differs from its retained "+field+"."
	return ""


func _poll_writeback() -> void:
	var polled: Dictionary = _writeback.poll()
	if polled.status!="complete": return
	var result: Dictionary = polled.result
	_release_publication()
	if result.get("ok",false):
		var acknowledged := _cache.durable_ack(result.manifest)
		if not acknowledged.get("ok",false):
			result = {"ok":false,"error":str(acknowledged.error),"published":true,
				"publication_uncertain":true,"quarantined":true}
		else:
			manifest = result.manifest.duplicate(true)
			_writeback_state = {"status":"idle","last_ack":polled.observation}
			message = "Background save durably acknowledged. Newer edits remain marked unsaved."
	if not result.get("ok",false):
		_writeback_state = {"status":"failed","error":str(result.get("error","Background publication failed.")),
			"observation":polled.observation}
		_resident_clock_dirty = true
		_note_storage_refusal(result)
		message = "Save failed; resident Worlds remain in RAM. "+str(result.get("error",""))
		if _publication_uncertain:
			host.paused = true
			host.update_worker_frame_state()
			active_ready = false
			_quarantined = true
		_refresh_panel()


func _wait_writeback() -> void:
	while _writeback.busy():
		_poll_writeback()
		if _writeback.busy(): await get_tree().process_frame
	_poll_writeback()


func request_cache_configuration(configuration: Dictionary) -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	for key: String in ["enabled","deferred","background","prefetch"]:
		if not configuration.get(key) is bool: return _refuse("Cache controls require explicit boolean selections.")
	if not configuration.get("budget_bytes") is int or int(configuration.budget_bytes)<1 \
			or int(configuration.budget_bytes)>AreaCache.MAX_BUDGET_BYTES:
		return _refuse("Choose a cache budget from 1 MiB through 8 GiB.")
	_pending_configuration = configuration.duplicate(true)
	_begin("cache_configure",active_area)
	_run_cached_operation.call_deferred(0)
	return true


func request_eviction() -> bool:
	var blocked := _start_block_reason()
	if not blocked.is_empty(): return _refuse(blocked)
	_begin("evict",active_area)
	_run_cached_operation.call_deferred(0)
	return true


func _reserve_target(target: String) -> Dictionary:
	var current: Dictionary = _cache.entry(active_area)
	# Reservation includes a complete native owner estimate and temporary CYPS
	# decode/validation headroom. It is an admission bound, not a process RSS cap.
	var native_bound := maxi(int(current.hot.get("native_reservation_bytes",current.native_bytes)),16*1024*1024)
	var bytes := 2*native_bound+64*1024*1024
	var reserved := _cache.reserve(str(operation.operation_id),target,bytes,2)
	if reserved.get("ok",false): return reserved
	var saved := await _flush_resident_state(false)
	if not saved.get("ok",false): return saved
	var evicted := await _evict_candidates(true)
	if not evicted.get("ok",false): return evicted
	var retry := _cache.reserve(str(operation.operation_id),target,bytes,2)
	if not retry.get("ok",false): retry["cache_exhausted"] = true
	return retry


func _cold_budget_fallback(target: String, future_ticks: int) -> Dictionary:
	# The configured budget governs retained extra Worlds, not the ordinary
	# active + private-candidate working set. If retention cannot fit, retire
	# only acknowledged durable cache owners and use the donor's atomic cold
	# transition. A small budget therefore cannot force seed regeneration or
	# lose edits, and its necessary synchronous durability remains explicit.
	await _wait_prefetch()
	var enabled := bool(_cache_configuration.enabled)
	_cache_configuration.enabled = false
	var released := await _evict_candidates(true)
	_cache_configuration.enabled = enabled
	if not released.get("ok",false): return released
	_cache_open = false
	operation["cache_budget_fallback"] = true
	operation.residency = "COLD"
	var restored := await _restore_target(target,future_ticks,false)
	_cache = AreaCache.new()
	var opened := _cache.open(manifest,int(_cache_configuration.budget_bytes))
	_cache_open = bool(opened.get("ok",false))
	_cache.configure(enabled,int(_cache_configuration.budget_bytes))
	if not restored.get("ok",false): return restored
	if not opened.get("ok",false): return opened
	return await _remember_active()


func _apply_cache_policy(force_all: bool) -> Dictionary:
	if not _pending_configuration.is_empty():
		_cache_configuration = _pending_configuration.duplicate(true)
		_pending_configuration = {}
		_cache.configure(bool(_cache_configuration.enabled),int(_cache_configuration.budget_bytes))
	var result := await _evict_candidates(force_all or not bool(_cache_configuration.enabled))
	if not result.get("ok",false): return result
	if _cache_configuration.enabled and _cache.entry(active_area).hot.is_empty(): return await _remember_active()
	return result


func _evict_candidates(force_all: bool) -> Dictionary:
	# Demotion captures one immutable continuation before releasing its native
	# owner. Reserve the same explicit transient headroom used by publication;
	# the retained-cache budget does not pretend to cover serialization copies.
	var reserved := _reserve_publication()
	if not reserved.get("ok",false): return reserved
	var result := await _evict_candidates_owned(force_all)
	_release_publication()
	return result


func _evict_candidates_owned(force_all: bool) -> Dictionary:
	for candidate: Dictionary in _cache.eviction_candidates(AreaCache.MAX_BUDGET_BYTES if force_all else 0):
		var id := str(candidate.area_id)
		if not force_all and not bool(_cache.status().over_budget): break
		var entry: Dictionary = _cache.entry(id)
		if entry.dirty: return _error("Dirty cache state stays retained until its save is acknowledged.")
		if entry.hot.is_empty():
			var cold := _cache.complete_eviction(id,int(entry.resident_generation),0,false)
			if not cold.get("ok",false): return cold
			continue
		var warm := {}
		# A clean durable area may demote to a cheaper RAM checkpoint. Its
		# transient capture is bounded by the admitted native capsule maximum;
		# failure leaves the old native owner in place.
		if _cache_configuration.enabled:
			var captured := await _worker({"kind":"resident_capture","operation_id":operation.operation_id,"receipt":entry.hot})
			if not captured.get("ok",false): return captured
			warm = captured.result.get("capsule",{})
		var released := await _worker({"kind":"resident_release","operation_id":operation.operation_id,"receipt":entry.hot})
		if not released.get("ok",false): return released
		var removed := _cache.complete_eviction(id,int(entry.resident_generation),int(entry.hot.handle),false)
		if not removed.get("ok",false): return removed
		_prefetched_handles.erase(id)
		if not warm.is_empty():
			# If the replacement bytes do not fit, the acknowledged durable
			# checkpoint remains the authority and the tier correctly stays COLD.
			_cache.retain_warm(id,warm,entry.authoring,int(entry.mutation_generation),str(entry.incarnation))
	if not _cache_configuration.enabled:
		var cleared := await _worker({"kind":"resident_clear_active","operation_id":operation.operation_id})
		if not cleared.get("ok",false): return cleared
		# Off uses the original cold lifecycle. The active owner is still native;
		# it is no longer registered for automatic retention during replacement.
		_release_publication()
		_prefetched_handles = {}
		_cache = AreaCache.new()
		_cache.open(manifest,int(_cache_configuration.budget_bytes))
		_cache.configure(false,int(_cache_configuration.budget_bytes))
	return {"ok":true}


func export_diagnostics() -> void:
	var path := ProjectSettings.globalize_path("user://persistent-areas/ramcache-diagnostics-%d.json" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		_refuse("Diagnostics could not be written: "+str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(evidence(),"\t")+"\n")
	file.close()
	message = "Diagnostics exported to "+path
	_refresh_panel()


func request_prefetch(area_id: String) -> bool:
	if not area_id in Connectivity.adjacent(active_area) or area_id==active_area: return false
	_prefetch_intent = area_id
	if not _cache_configuration.enabled or not _cache_configuration.prefetch: return false
	if _prefetch_busy:
		if str(_prefetch_operation.get("area_id",""))!=area_id:
			_prefetch_cancel = true
			if _prefetch_token>0: host.simulation_worker.persistent_prefetch_cancel(_prefetch_token)
		return true
	if busy or not active_ready: return false
	_request_prediction({"area_id":area_id,"priority":100,"reason":"explicit destination intent"})
	return true


func _request_prediction(prediction: Dictionary) -> void:
	var target := str(prediction.get("area_id",""))
	if _prefetch_busy or busy or not active_ready or not _cache_open \
			or not _cache_configuration.enabled or not _cache_configuration.prefetch \
			or _io_busy or _writeback.busy() or target==active_area or not target in Connectivity.adjacent(active_area): return
	var entry: Dictionary = _cache.entry(target)
	if not entry.hot.is_empty() and AreaClock.debt(clock,target)==0: return
	_prefetch_sequence += 1
	_prefetch_busy = true
	_prefetch_cancel = false
	_prefetch_operation = {"operation_id":AreaStore.new_nonce(),"sequence":_prefetch_sequence,
		"area_id":target,"incarnation":entry.incarnation,"priority":int(prediction.get("priority",10)),
		"reason":str(prediction.get("reason","adjacency")),"started_msec":Time.get_ticks_msec(),
		"started_usec":Time.get_ticks_usec(),"active_area_at_start":active_area,
		"active_native_tick_at_start":int(clock.areas[active_area].native_ticks),"game_tick_at_start":int(clock.game_ticks),
		"frame_observations":0,"max_main_frame_ms":0.0,"reserved_bytes":0,
		"worst_frame_start_usec":0,"worst_frame_end_usec":0,"phase_timestamps":{},
		"source_residency":"HOT" if not entry.hot.is_empty() else ("WARM" if not entry.warm.is_empty() else "COLD"),
		"io_before":_io_metrics.duplicate(true),
		"source_mutation_generation":int(entry.mutation_generation),"source_tick":int(entry.completed_tick),
		"advance_only":not entry.hot.is_empty()}
	_prefetch_state = {"status":"preparing","message":"Preparing %s before travel (%s)…" % [target.to_upper(),_prefetch_operation.reason],
		"operation":_prefetch_operation.duplicate(true)}
	_io_metrics.prefetch_requests += 1
	_run_prediction.call_deferred()


func _run_prediction() -> void:
	_prediction_stamp("preparation_started_usec")
	var spec: Dictionary = _prefetch_operation.duplicate(true)
	var target := str(spec.area_id)
	var entry: Dictionary = _cache.entry(target)
	var plan_result := AreaClock.plan_background(clock,target,MAX_NATIVE_SLICE_TICKS,str(spec.operation_id))
	if not plan_result.get("ok",false):
		_finish_prediction(str(plan_result.error),false)
		return
	var plan: Dictionary = plan_result.plan
	var reservation := ""
	var request := {"identity":_area_identity(target),"operation_id":str(spec.operation_id),
		"max_ticks":int(plan.work_ticks),"max_us":MAX_NATIVE_SLICE_USEC}
	var authoring: Dictionary = entry.authoring
	if not entry.hot.is_empty():
		request["advance_only"] = true
		request["receipt"] = entry.hot
		request.max_ticks = mini(2,int(plan.work_ticks))
		request.max_us = 5000
	else:
		_prediction_stamp("resource_admission_started_usec")
		var active_entry: Dictionary = _cache.entry(active_area)
		var native_estimate := maxi(int(active_entry.hot.get("native_reservation_bytes",active_entry.native_bytes)),16*1024*1024)
		var reserved := _cache.reserve(str(spec.operation_id),target,3*native_estimate+64*1024*1024,0)
		if not reserved.get("ok",false):
			_finish_prediction("Preparation deferred: cache reservation would exceed the budget.",false)
			return
		reservation = str(spec.operation_id)
		_prefetch_operation.reserved_bytes = 3*native_estimate+64*1024*1024
		_prediction_stamp("resource_admission_finished_usec")
		var loaded: Dictionary
		_prediction_stamp("checkpoint_load_started_usec")
		if not entry.warm.is_empty():
			loaded = {"ok":true,"capture":entry.warm,"authoring":entry.authoring}
		else:
			loaded = await _io("read_area",[target])
			_io_metrics.profile_read_calls += 1
			if loaded.get("ok",false): _io_metrics.profile_read_bytes += loaded.capture.bytes.size()
		_prediction_stamp("checkpoint_load_finished_usec")
		if not loaded.get("ok",false):
			_cache.release_reservation(reservation)
			_finish_prediction("Destination read refused: "+str(loaded.get("error","unknown")),false)
			return
		authoring = loaded.authoring
		if _prefetch_cancel:
			_cache.release_reservation(reservation)
			_cache.retain_warm(target,loaded.capture,authoring,int(entry.mutation_generation),str(entry.incarnation))
			_finish_prediction("Prediction cancelled after validated loading; useful warm state retained if budget permits.",false,true)
			return
		request["authoring"] = authoring
		request["capture"] = loaded.capture
		request["reservation_bytes"] = 3*native_estimate+64*1024*1024
		request["max_native_bytes"] = native_estimate
	_prediction_stamp("worker_admission_started_usec")
	var admitted: Dictionary = host.simulation_worker.persistent_prefetch_request(request)
	_prediction_stamp("worker_admission_finished_usec")
	if not admitted.get("ok",false):
		if not reservation.is_empty(): _cache.release_reservation(reservation)
		_finish_prediction("Destination preparation refused: "+str(admitted.get("error","unavailable")),false)
		return
	_prefetch_token = int(admitted.token)
	var observed: Dictionary
	while true:
		if _prefetch_cancel: host.simulation_worker.persistent_prefetch_cancel(_prefetch_token)
		observed = host.simulation_worker.persistent_prefetch_poll(_prefetch_token)
		if str(observed.get("status",""))!="pending": break
		await get_tree().process_frame
	_prediction_stamp("native_result_observed_usec")
	if not observed.get("ok",false) or observed.get("status","")!="ready":
		if not reservation.is_empty(): _cache.release_reservation(reservation)
		_finish_prediction("Prediction stopped: "+str(observed.get("error",observed.get("status","refused"))),false,
			observed.get("status","")=="cancelled")
		return
	var receipt: Dictionary = observed.result.get("receipt",{})
	var current: Dictionary = _cache.entry(target)
	if current.incarnation!=spec.incarnation or int(current.mutation_generation)!=int(spec.source_mutation_generation) \
			or int(current.completed_tick)!=int(spec.source_tick) or target==active_area:
		if not await _retire_unadmitted_prediction(receipt,spec,bool(request.get("advance_only",false))): return
		if not reservation.is_empty(): _cache.release_reservation(reservation)
		_finish_prediction("Stale destination completion was refused without replacing resident authority.",false)
		return
	var actual := int(receipt.get("completed_tick",-1))-int(spec.source_tick)
	var accounted := AreaClock.complete_background(clock,plan,actual)
	if not accounted.get("ok",false):
		if not await _retire_unadmitted_prediction(receipt,spec,bool(request.get("advance_only",false))): return
		if not reservation.is_empty(): _cache.release_reservation(reservation)
		_finish_prediction("Destination time admission refused: "+str(accounted.error),false)
		return
	_prediction_stamp("cache_admission_started_usec")
	var retained := _refresh_resident(target,receipt,authoring,reservation)
	_prediction_stamp("cache_admission_finished_usec")
	if not retained.get("ok",false):
		if not await _retire_unadmitted_prediction(receipt,spec,bool(request.get("advance_only",false))): return
		if not reservation.is_empty(): _cache.release_reservation(reservation)
		_finish_prediction("Destination resource admission refused: "+str(retained.error),false)
		return
	clock = accounted.clock
	_resident_clock_dirty = _resident_clock_dirty or actual>0
	_io_metrics.prefetch_native_ticks += actual
	if not request.get("advance_only",false): _io_metrics.native_deserializations += 1
	# Later bounded debt slices may improve the same prepared owner. Preserve
	# its original preparation interval so arrival metrics identify the actual
	# cold/warm reconstruction instead of only the last two-tick debt payment.
	if int(_prefetched_handles.get(target,{}).get("handle",-1))!=int(receipt.handle):
		_prefetched_handles[target] = {"handle":int(receipt.handle),"identity":receipt.identity.duplicate(true),
			"operation_id":str(spec.operation_id),"prepared_native_tick":int(receipt.completed_tick)}
	_prefetch_state = {"status":"ready","ready_area":target,
		"message":"%s prepared in RAM; %d legitimate native ticks completed, %.2f s debt remains." % [
			target.to_upper(),actual,float(AreaClock.debt(clock,target))/AreaClock.TICKS_PER_SECOND],
		"operation":spec,"receipt":receipt.duplicate(true),"native_work":observed.result.duplicate(true),
		"elapsed_ms":Time.get_ticks_msec()-int(spec.started_msec)}
	_io_metrics.prefetch_completed += 1
	_record_prediction_terminal("completed",observed.result)
	_prefetch_busy = false
	_prefetch_token = 0
	_refresh_panel()


func _finish_prediction(detail: String, ready: bool, cancelled: bool = false) -> void:
	if cancelled: _io_metrics.prefetch_cancelled += 1
	_record_prediction_terminal("completed" if ready else ("cancelled" if cancelled else "deferred"),{},detail)
	_prefetch_state = {"status":"ready" if ready else ("cancelled" if cancelled else "deferred"),
		"message":detail,"operation":_prefetch_operation.duplicate(true)}
	_prefetch_busy = false
	_prefetch_token = 0
	_refresh_panel()


func _record_prediction_terminal(outcome: String, native_work: Dictionary = {}, detail: String = "") -> void:
	if _prefetch_operation.is_empty(): return
	var spec: Dictionary = _prefetch_operation
	var origin := str(spec.active_area_at_start)
	var ended := Time.get_ticks_usec()
	var current_gap := float(ended-_last_process_usec)/1000.0
	if current_gap>float(spec.max_main_frame_ms):
		spec.max_main_frame_ms = current_gap
		spec.worst_frame_start_usec = _last_process_usec
		spec.worst_frame_end_usec = ended
	var record := {"operation_id":str(spec.operation_id),"sequence":int(spec.sequence),
		"area_id":str(spec.area_id),"source_residency":str(spec.source_residency),"status":outcome,"detail":detail,
		"start_usec":int(spec.started_usec),"end_usec":ended,"elapsed_us":ended-int(spec.started_usec),
		"active_area_at_start":origin,"active_area_at_end":active_area,
		"active_native_ticks":int(clock.areas[origin].native_ticks)-int(spec.active_native_tick_at_start),
		"game_ticks_advanced":int(clock.game_ticks)-int(spec.game_tick_at_start),
		"completed_private_ticks":int(native_work.get("completed_ticks",0)),
		"remaining_debt_ticks":AreaClock.debt(clock,str(spec.area_id)),
		"max_main_frame_ms":float(spec.max_main_frame_ms),
		"worst_frame_start_usec":int(spec.worst_frame_start_usec),"worst_frame_end_usec":int(spec.worst_frame_end_usec),
		"phase_timestamps":spec.phase_timestamps.duplicate(true),
		"frame_observations":int(spec.frame_observations),"reserved_bytes":int(spec.reserved_bytes),
		"io_before":spec.io_before.duplicate(true),"io_after":_io_metrics.duplicate(true),
		"native_work":native_work.duplicate(true)}
	_record_metric("prefetch_records",record)


func _prediction_stamp(phase: String) -> void:
	_prefetch_operation.phase_timestamps[phase] = Time.get_ticks_usec()


func _observe_prediction_frame(record: Dictionary, started: int, ended: int) -> void:
	var gap_ms := float(ended-started)/1000.0
	if gap_ms>float(record.max_main_frame_ms):
		record.max_main_frame_ms = gap_ms
		record.worst_frame_start_usec = started
		record.worst_frame_end_usec = ended
	record.frame_observations = int(record.frame_observations)+1


func _wait_prefetch(explicit_transition: bool = false) -> void:
	if not _prefetch_busy: return
	_prefetch_cancel = true
	if _prefetch_token>0: host.simulation_worker.persistent_prefetch_cancel(_prefetch_token)
	if explicit_transition and str(operation.get("target_area",""))!=str(_prefetch_operation.get("area_id","")) \
			and not _prefetch_operation.get("advance_only",false):
		# The independent preparation retains its reservation until cancellation
		# is acknowledged. A hot transition to another area need not wait for its
		# obsolete decode; the worker discards the private owner after joining.
		return
	while _prefetch_busy: await get_tree().process_frame


func _retire_unadmitted_prediction(receipt: Dictionary, spec: Dictionary, advance_only: bool) -> bool:
	if advance_only:
		# Actual ticks changed an existing resident authority. They cannot be
		# discarded or pretended unexecuted if their clock admission fails.
		_pending_cache_failure = "Background progress could not be admitted to its exact area generation. Retained native state is quarantined for recovery."
		active_ready = false
		_quarantined = true
		host.paused = true
		host.update_worker_frame_state()
		_finish_prediction(_pending_cache_failure,false)
		return false
	# Cancel cannot retire a result that already imported successfully. Keep
	# its reservation until the actual exclusive native release acknowledges.
	while _lease_held or _current_worker_token>0 or _io_busy: await get_tree().process_frame
	var released: Dictionary = {}
	var deadline := Time.get_ticks_msec()+OWNER_WAIT_MSEC
	while Time.get_ticks_msec()<deadline:
		released = await _worker({"kind":"resident_release","operation_id":str(spec.operation_id),"receipt":receipt})
		if released.get("ok",false) or not released.get("retryable",false): break
		await get_tree().process_frame
	if not released.get("ok",false):
		_pending_cache_failure = "An unadmitted prepared native World could not be released: "+str(released.get("error","unknown"))
		active_ready = false
		_quarantined = true
		host.paused = true
		host.update_worker_frame_state()
		_finish_prediction(_pending_cache_failure,false)
		return false
	return true


func _retry_resident_storage() -> void:
	# This guard outlives the storage ACK until the native release ACK. A late
	# owner cleanup must never fall back to reconstructing an older checkpoint.
	_resident_storage_recovery_required = true
	await _wait_writeback()
	await _wait_prefetch()
	var frozen := await _freeze_live()
	if not frozen.get("ok",false):
		await _fail(str(frozen.error),true)
		return
	if not _resident_publication_pending.is_empty():
		var pending: Dictionary = _resident_publication_pending
		var observed := await _worker({"kind":"resident_status","operation_id":operation.operation_id})
		var actual: Dictionary = observed.get("result",{}).get("active",{})
		var expected: Dictionary = pending.active_receipt
		if not observed.get("ok",false) or clock!=pending.expected_state.clock \
				or active_area!=str(pending.expected_state.active_area) or actual.get("identity",{})!=expected.identity \
				or int(actual.get("handle",-1))!=int(expected.handle) \
				or int(actual.get("completed_tick",-1))!=int(expected.completed_tick) \
				or int(actual.get("mutation_generation",-1))!=int(expected.mutation_generation):
			await _fail("The pending resident publication no longer matches its retained native authority or game clock; no World was restored.",true)
			return
		for id: String in pending.expected_updates:
			var entry: Dictionary = _cache.entry(id)
			var expected_area: Dictionary = pending.expected_updates[id]
			if str(entry.incarnation)!=str(expected_area.incarnation) \
					or int(entry.mutation_generation)!=int(expected_area.mutation_generation) \
					or int(entry.completed_tick)!=int(expected_area.completed_tick) \
					or str(entry.authoring_sha256)!=str(expected_area.authoring_sha256) \
					or (entry.hot.is_empty() and str(entry.warm.get("sha256",""))!=str(expected_area.native_sha256)):
				await _fail("A captured resident area changed outside its pending publication; the retained authorities stay quarantined.",true)
				return
	await _io("close_profile",[])
	_profile_open = false
	var opened := await _io("_open_with_identity",[profile_path,_native_library])
	if not opened.get("ok",false) or opened.get("fresh",false):
		await _fail(str(opened.get("error","The existing durable profile is unavailable; resident Worlds remain retained.")),true)
		return
	if str(opened.manifest.session_id)!=str(manifest.session_id):
		await _fail("Storage recovery found another session; resident Worlds remain retained.",true)
		return
	if not _resident_publication_pending.is_empty() \
			and not _resident_publication_error(opened.manifest,_resident_publication_pending).is_empty() \
			and opened.manifest!=_resident_publication_pending.previous_manifest:
		await _fail("Reopened storage matches neither the retained resident publication nor its previous acknowledged manifest.",true)
		return
	var acknowledged := _cache.durable_ack(opened.manifest)
	if not acknowledged.get("ok",false):
		await _fail(str(acknowledged.error),true)
		return
	manifest = opened.manifest.duplicate(true)
	_profile_open = true
	_publication_uncertain = false
	_force_profile_reopen = false
	_owner_recovery_requires_restore = false
	_quarantined = false
	_writeback_state = {"status":"idle"}
	_resident_publication_pending = {}
	_resident_clock_dirty = clock!=manifest.clock or active_area!=str(manifest.active_area)
	var remembered := await _remember_active()
	if not remembered.get("ok",false):
		await _fail(str(remembered.error),true)
		return
	var saved := await _flush_resident_state(false)
	if not saved.get("ok",false):
		await _fail(str(saved.error),bool(saved.get("quarantined",false)))
		return
	await _finish("Storage recovered and the retained RAM authorities were durably saved without reloading an older World.")


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
	_io_metrics.profile_read_calls += 1
	if loaded.get("ok",false): _io_metrics.profile_read_bytes += loaded.capture.bytes.size()
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
	_io_metrics.native_deserializations += 1
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
	if capsule.is_empty(): _io_metrics.source_constructions += 1
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
	if int(host.tower_context.get("scenario_request_serial",-1))!=serial \
			or not bool(host.tower_context.get("scenario_request_applied",false)):
		return _error("Main acknowledged a different native installation serial.")
	return {"ok":true,"serial":serial,"previous_generation":previous_generation}


func _publish(next_clock: Dictionary, updates: Dictionary, selected: String) -> Dictionary:
	await _wait_writeback()
	var reserved := _reserve_publication()
	if not reserved.get("ok",false): return reserved
	var result := await _publish_transaction(next_clock,updates,selected)
	_release_publication()
	return result


func _publish_transaction(next_clock: Dictionary, updates: Dictionary, selected: String) -> Dictionary:
	_io_metrics.synchronous_publications += 1
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
	if _cache_open and _cache_configuration.enabled:
		var acknowledged := _cache.durable_ack(manifest)
		if not acknowledged.get("ok",false):
			return {"ok":false,"error":str(acknowledged.error),"quarantined":true,"published":true}
	elif _cache_open:
		_cache = AreaCache.new()
		_cache.open(manifest,int(_cache_configuration.budget_bytes))
		_cache.configure(false,int(_cache_configuration.budget_bytes))
	_writeback_state = {"status":"idle"}
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
	if command.kind in ["advance_active","resident_advance"] and not _resident_advancement.is_empty() \
			and str(_resident_advancement.operation_id)==str(command.operation_id) \
			and not _resident_advancement.get("pending",{}).is_empty():
		_resident_advancement.pending.token = token
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
	await _wait_writeback()
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
	if not _pending_cache_failure.is_empty():
		await _fail(_pending_cache_failure,true)
		return
	if _owner_cleanup_required or not _unresolved_worker.is_empty():
		await _fail("The native operation still needs an acknowledged owner cleanup.",false,false)
		return
	if not _resident_advancement.get("pending",{}).is_empty():
		await _fail("The resident native tick interval still needs its original completion acknowledgement.",true,false)
		return
	if _lease_held:
		if _cache_open: _cache.release_reservation(str(operation.operation_id))
		var released := await _worker({"kind":"release","operation_id":operation.operation_id})
		if not released.get("ok",false):
			_owner_cleanup_required = true
			await _fail(str(released.error),false,false)
			return
		if _lease_held:
			_owner_cleanup_required = true
			await _fail("Native release did not acknowledge retirement of its resident owner lease.",true,false)
			return
	_retire_acknowledged_handoff()
	_resident_advancement = {}
	_resident_publication_pending = {}
	_resident_storage_recovery_required = false
	active_ready = true
	busy = false
	_quarantined = false
	_owner_recovery_requires_restore = false
	if active_area.is_empty(): active_area = str(manifest.active_area)
	_last_world_generation = int(host.latest_snapshot.render_world_generation)
	_last_clock_snapshot_serial = int(host.latest_snapshot.serial)
	if _cache_open and not _cache.entry(active_area).hot.is_empty():
		_last_dirty_native_revision = int(_cache.entry(active_area).hot.mutation_generation)
		_last_dirty_authoring_generation = int(host.simulation_worker.paint_state().get("authoring_generation",-1))
		_last_camera_stamp = _camera_stamp()
	elif _cache_open:
		var observed: Dictionary = host.simulation_worker.paint_state()
		_last_dirty_native_revision = int(observed.get("revision",-1))
		_last_dirty_authoring_generation = int(observed.get("authoring_generation",-1))
		_last_camera_stamp = _camera_stamp()
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
	await _wait_writeback()
	await _wait_prefetch()
	_set_phase("Durable","Closing the explicitly confirmed recovery profile; the failed area's unsaved RAM state is omitted." \
		if operation.kind=="close_recovery" else "Closing the persistent profile after its last completed publication…")
	await _io("close_profile",[])
	_profile_open = false
	host.finish_persistent_exit(_exit_destination)


func _retry_profile() -> void:
	if not _resident_advancement.is_empty():
		await _fail("The retained resident advancement must reconcile its original game-time plan before any disk restore.",true,false)
		return
	if _resident_storage_recovery_required:
		await _fail("The retained resident publication must reconcile its storage and native release acknowledgements before any disk restore.",true,false)
		return
	if not _resident_handoff.is_empty():
		await _fail("The retained resident handoff must reconcile its original native and Main acknowledgement before any disk restore.",true,false)
		return
	if _profile_open and not _force_profile_reopen and int(manifest.get("revision",0)) > 0:
		var restored := await _restore_target(str(manifest.active_area),0,true)
		if restored.get("ok",false): await _finish("The durable profile was restored without regenerating any area.")
		else: await _fail(str(restored.error),true)
		return
	await _io("close_profile",[])
	_profile_open = false
	await _open_profile()


func _retry_owner() -> void:
	var resident_recovery := not _resident_advancement.is_empty()
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
		if retained.kind in ["advance_active","resident_advance"]:
			var pending: Dictionary = _resident_advancement.get("pending",{})
			if pending.is_empty() or int(pending.get("token",0))!=int(retained.token) \
					or str(pending.get("kind",""))!=str(retained.kind):
				await _fail("The late resident completion has lost its exact game-time request; its World remains quarantined.",true,false)
				return
			var accepted := _accept_resident_terminal(observed)
			if not accepted.get("ok",false):
				await _fail(str(accepted.error),true,false)
				return
		if retained.kind in ["commit","activate_resident"] and observed.get("result",{}).get("committed",false):
			_candidate_committed = true
		_unresolved_worker = {}
		_current_worker_token = 0
	# A terminal response can itself fail host validation. Keep its request
	# token and plan rather than allowing another request to replace authority.
	if not _resident_advancement.get("pending",{}).is_empty():
		var pending: Dictionary = _resident_advancement.pending
		var observed: Dictionary = host.simulation_worker.persistent_poll(int(pending.token))
		var ownership_error := _observe_worker_owner(observed,str(_resident_advancement.operation_id))
		if not ownership_error.is_empty():
			await _fail(ownership_error,true,false)
			return
		var accepted := _accept_resident_terminal(observed)
		if not accepted.get("ok",false):
			await _fail(str(accepted.error),true,false)
			return
	var hot_recovery := false
	if not _resident_handoff.is_empty():
		var reconciled := await _reconcile_hot_handoff()
		if not reconciled.get("ok",false):
			await _fail(str(reconciled.error),true,false)
			return
		hot_recovery = bool(reconciled.get("recovered",false))
	var cleaned := await _cleanup_owner()
	if not cleaned.get("ok",false):
		await _fail(str(cleaned.error),false,false)
		return
	_owner_cleanup_required = false
	if resident_recovery and bool(_resident_advancement.get("terminal_failure",false)):
		_record_resident_advancement_completion()
		var native_error := str(_resident_advancement.get("native_error","Native continuation failed."))
		_resident_advancement = {}
		await _fail("The failed native interval and owner release were acknowledged. Its completed prefix remains accounted, the failed World stays quarantined, and healthy-area recovery is available. "+native_error,true,false)
		return
	if _resident_storage_recovery_required:
		_owner_recovery_requires_restore = false
		_begin("retry_storage",active_area)
		await _retry_resident_storage()
		return
	if hot_recovery:
		_owner_recovery_requires_restore = false
		if _publication_uncertain or _force_profile_reopen:
			_begin("retry_storage",active_area)
			await _retry_resident_storage()
			return
		operation["measurement_outcome"] = "owner_recovered"
		await _finish("The exact resident handoff and Main serial were acknowledged. Both areas retain their unsaved RAM state; no checkpoint was loaded or simulation time repeated.")
		return
	if resident_recovery:
		_owner_recovery_requires_restore = false
		if _publication_uncertain or _force_profile_reopen:
			_begin("retry_storage",active_area)
			await _retry_resident_storage()
			return
		_record_resident_advancement_completion()
		operation["measurement_outcome"] = "owner_recovered"
		await _finish("The exact resident native interval was acknowledged once against its original debt and future-time plan. Completed work remains in RAM; unfinished work is still debt or unfulfilled Simulate Ahead time.")
		return
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
	if not _resident_advancement.get("pending",{}).is_empty():
		return _error("The resident advancement still owns an unaccounted native interval; reconcile its exact completion before release.")
	if not _resident_handoff.is_empty() and not _candidate_committed \
			and not bool(_resident_handoff.get("main_acknowledged",false)):
		return _error("The resident handoff requires its exact native receipt reconciliation before owner cleanup.")
	if not _lease_held:
		if not host.pending_microscenario_apply.is_empty():
			return _error("Main still has an unresolved area installation; the World remains paused.")
		if _cache_open: _cache.release_reservation(str(operation.operation_id))
		_retire_acknowledged_handoff()
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
	if _cache_open: _cache.release_reservation(str(operation.operation_id))
	_retire_acknowledged_handoff()
	return {"ok":true}


func _retire_acknowledged_handoff() -> void:
	if not _resident_handoff.is_empty() and bool(_resident_handoff.get("main_acknowledged",false)) \
			and not _lease_held and _unresolved_worker.is_empty():
		if _cache_open: _cache.release_reservation(str(_resident_handoff.operation_id))
		_resident_handoff = {}


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
	if _owner_cleanup_required or not _unresolved_worker.is_empty() or not _resident_advancement.is_empty(): quarantine = true
	busy = false
	_quarantined = quarantine
	active_ready = not quarantine and not active_area.is_empty() and not host.simulation_worker.has_failed()
	host.paused = true if not active_ready else not _resume_play
	host.update_worker_frame_state()
	if _publication_uncertain:
		reason += " Publication acknowledgement is uncertain. The live World stays paused; Retry validates the retained publication and durable manifest before further action."
	last_result = {"ok":false,"error":reason,"operation":operation.duplicate(true),"quarantined":quarantine,
		"publication_uncertain":_publication_uncertain,"force_profile_reopen":_force_profile_reopen,
		"owner_cleanup_required":_owner_cleanup_required,"unresolved_worker":_unresolved_worker.duplicate(true)}
	_record_operation_terminal("failed",reason)
	_set_phase("Failed / quarantined" if quarantine else "Active / operation refused",reason)
	push_warning("PERSISTENT_AREAS_REFUSED: "+reason)


func _accept_manifest(value: Dictionary) -> void:
	manifest = value.duplicate(true)
	clock = manifest.clock.duplicate(true)
	_resident_clock_dirty = false
	_uncached_authoring_dirty = false


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
	var ended_usec := Time.get_ticks_usec()
	# The completion frame has not reached _process again. Measure its tail
	# now, while its exact end is known, instead of losing it when busy clears.
	# Both ordinary frame intervals and this tail are clipped to this operation;
	# later staging or another action cannot inflate its reported frame gap.
	_observe_operation_frame(ended_usec)
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
		"start_usec":int(operation.get("started_usec",int(operation.started_msec)*1000)),"end_usec":ended_usec,
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
		"publication_uncertain":_publication_uncertain,"owner_cleanup_required":_owner_cleanup_required,
		"residency":str(operation.get("residency","COLD")),"prefetch_hit":bool(operation.get("prefetch_hit",false)),
		"prefetch_operation_id":str(operation.get("prefetch_operation_id","")),
		"hot_handoff_us":int(operation.get("hot_handoff_us",0)),"pause_drain_us":int(operation.get("pause_drain_us",0)),
		"max_main_frame_ms":float(operation.get("max_main_frame_ms",0.0)),
		"worst_frame_start_usec":int(operation.get("worst_frame_start_usec",0)),
		"worst_frame_end_usec":int(operation.get("worst_frame_end_usec",0)),
		"frame_observations":int(operation.get("frame_observations",0)),
		"frame_scope":"Frame intervals clipped to operation start/end, including the terminal tail; subsequent work excluded.",
		"io_before":operation.get("io_before",{}).duplicate(true),"io_after":_io_metrics.duplicate(true)})


func _observe_operation_frame(ended_usec: int) -> void:
	if operation.is_empty() or _last_process_usec<=0: return
	var began_usec := int(operation.get("started_usec",int(operation.started_msec)*1000))
	var interval_start := maxi(_last_process_usec,began_usec)
	if ended_usec<=interval_start: return
	var gap_ms := float(ended_usec-interval_start)/1000.0
	if gap_ms>float(operation.get("max_main_frame_ms",0.0)):
		operation.max_main_frame_ms = gap_ms
		operation.worst_frame_start_usec = interval_start
		operation.worst_frame_end_usec = ended_usec
	operation.frame_observations = int(operation.get("frame_observations",0))+1


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
	if is_instance_valid(workbench.art_batches) and workbench.art_batches.native_authoring_pending():
		return "Finish or Stop the pending Art work before capturing the area."
	if is_instance_valid(workbench.architecture_lab) and is_instance_valid(workbench.architecture_lab.workflow) \
			and workbench.architecture_lab.workflow.busy():
		return "Finish or Stop the pending Architecture stage before capturing the area."
	return ""


func _configure_profile_controls() -> void:
	# The inherited Workbench remains the editor, but this profile cannot own
	# arbitrary bodies, host emitters or a different World/solver. Do not invite
	# an action that is known to refuse; the owner guard still enforces it for
	# keyboard and programmatic callers. Ordinary Workbench is untouched.
	var workbench: Control = host.shared_workbench
	if workbench == null: return
	var unsupported := ["Reset selected [R]","Restore start","New blank","New from generator…","Water Lab…",
		"Reciprocal assembly…","Place at X/Y","Focus","Replace with model","Remove","Source at X/Y",
		"Burst [B]","Save reset spawn","Use body position","Move to X/Y","Apply settings","Defaults"]
	var explanation := "Outside this persistent-area profile. Open the ordinary Workbench for actors, host sources, solver changes and replacement starts."
	workbench._actor_configuration_button.disabled = true
	workbench._actor_configuration_button.tooltip_text = explanation
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
