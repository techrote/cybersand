extends SceneTree

# Identical observational harness for accepted main, the previous integrated
# application and a repaired application. Every callback delegates once to its
# source Main/worker. Only the fixture and tick-addressed user input are supplied
# here: no tick, physics step, admission rule, renderer or source policy is replaced.
const Setup = preload("res://scripts/workbench_setup.gd")
const Reference = preload("res://scripts/engine_lab_reference_fixture.gd")
const TAPE: Array[Dictionary] = [
	{"tick":0,"move":[0.0,0.0]}, {"tick":2,"move":[1.0,0.0]},
	{"tick":4,"move":[0.0,-1.0]}, {"tick":6,"move":[-1.0,0.0]},
	{"tick":8,"move":[0.0,1.0]}, {"tick":10,"move":[0.0,0.0]},
	{"tick":12,"move":[0.70710678,-0.70710678]}, {"tick":14,"move":[0.0,0.0]},
	{"tick":30,"move":[1.0,0.0]}, {"tick":90,"move":[0.0,-1.0]},
	{"tick":120,"move":[1.0,0.0]}
]
const MAX_EVENTS := 30000
const TARGET_STEPS := 144
const MIN_CAPTURE_USEC := 10000000
const MAX_CAPTURE_USEC := 90000000
const SETUP_MSEC := 240000

class ObservedWorker extends "res://scripts/simulation_worker.gd":
	var common_active := false
	var common_events: Array[Dictionary] = []
	var common_overflow := false
	var common_last_tick := -1
	var common_last_participation := -1
	var common_properties: Dictionary = {}

	func begin_common_probe() -> void:
		_mutex.lock()
		common_events.clear()
		common_overflow = false
		common_last_participation = -1
		common_last_tick = _published_snapshot.tick_index if _published_snapshot != null else -1
		common_properties.clear()
		if _published_snapshot != null:
			for item: Dictionary in _published_snapshot.get_property_list():
				common_properties[str(item.name)] = true
		common_active = true
		_mutex.unlock()

	func end_common_probe() -> Dictionary:
		_mutex.lock()
		common_active = false
		var result := {"events":common_events.duplicate(),"overflow":common_overflow}
		_mutex.unlock()
		return result

	func _common_append_locked(row: Dictionary) -> void:
		if common_events.size() >= 30000:
			common_overflow = true
		else:
			common_events.append(row)

	func _capture_workbench_result() -> void:
		var observed_usec := Time.get_ticks_usec()
		super._capture_workbench_result()
		_mutex.lock()
		if common_active and not _workbench_display.is_empty():
			var tick := int(_workbench_display.tick)
			if tick > common_last_tick:
				common_last_tick = tick
				# Timestamp at the existing post-tick result-capture entry. It is
				# an upper bound on native completion, not a hardware completion.
				_common_append_locked({"event":"native_completion_observed",
					"time_usec":observed_usec,"result_captured_usec":Time.get_ticks_usec(),
					"tick_index":tick,"world_generation":_workbench_display.world_generation,
					"body_sample":_workbench_prepared_sample,
					"clock":"existing_post_tick_result_capture_entry"})
		_mutex.unlock()

	func _publish_snapshot(worker_step_time_ms: float, paused_value: bool,
			render_snapshot_interval_usec: int, force_render_full_refresh: bool = false,
			rigid_body_states: PackedFloat32Array = PackedFloat32Array(),
			rigid_body_epoch: int = 0) -> void:
		var entered := Time.get_ticks_usec()
		super._publish_snapshot(worker_step_time_ms, paused_value, render_snapshot_interval_usec,
			force_render_full_refresh, rigid_body_states, rigid_body_epoch)
		var completed := Time.get_ticks_usec()
		_mutex.lock()
		if common_active and _published_snapshot != null:
			var item: CyberSimulationSnapshot = _published_snapshot
			var spray: Dictionary = item.lab_context.get("water_spray",{})
			var participation: Dictionary = item.native_worker_participation
			if int(participation.get("sequence",-1)) > common_last_participation:
				common_last_participation = int(participation.sequence)
				_common_append_locked({"event":"worker_participation","time_usec":completed,
					"sample":participation.duplicate(true)})
			var exact_completed: Variant = item.get("last_native_tick_completed_usec") \
				if common_properties.has("last_native_tick_completed_usec") else null
			var physics_handoff: Variant = item.get("physics_handoff_usec") \
				if common_properties.has("physics_handoff_usec") else null
			_common_append_locked({"event":"worker_snapshot","start_usec":entered,
				"time_usec":completed,"snapshot_serial":item.serial,
				"tick_index":item.tick_index,"world_generation":item.render_world_generation,
				"completed_body_sample":item.lab_context.get("workbench_completed_sample",-1),
				"native_completed_usec":exact_completed,"physics_handoff_usec":physics_handoff,
				"native_tick_ms":item.simulation_time_ms,"worker_step_ms":worker_step_time_ms,
				"copy_ms":item.snapshot_copy_time_ms,"publication_ms":item.snapshot_publication_time_ms,
				"render_serial":item.render_snapshot_serial,"render_generated_usec":item.render_generated_usec,
				"render_patch_count":item.render_patch_rectangles.size()/6,
				"render_patch_bytes":item.render_patch_cells.size(),"full_refresh":item.render_full_refresh,
				"hard_surface_revision":item.hard_surface_revision,
				"required_hard_revision":item.lab_context.get("workbench_hard_surface_revision",-1),
				"water_ledger":spray.get("water",{}).duplicate(),
				"water_ledger_healthy":spray.get("healthy",false),
				"failed":item.simulation_failed})
		_mutex.unlock()

class ObservedMain extends "res://scripts/main.gd":
	var common_active := false
	var common_events: Array[Dictionary] = []
	var common_overflow := false
	var common_tape: Array[Dictionary] = []
	var common_tape_events: Array[Dictionary] = []
	var common_tape_index := -1
	var common_tick_zero := 0
	var common_epoch := -1
	var common_generation := -1
	var common_input_error := ""
	var common_physics_started := 0
	var common_applied_snapshot: CyberSimulationSnapshot
	var common_uploaded_generated_usec := -1
	var common_uploaded_native_tick := -1
	var common_snapshot_properties: Dictionary = {}

	func _ready() -> void:
		# Same sole worker owner and production implementation. The subclass
		# observes existing completion/publication seams on its owning thread.
		simulation_worker = ObservedWorker.new()
		super._ready()

	func append_common(row: Dictionary) -> void:
		if not common_active: return
		if common_events.size() >= 30000:
			common_overflow = true
		else:
			common_events.append(row)

	func _publish_workbench_keyboard() -> void:
		if not common_active:
			super._publish_workbench_keyboard()
			return
		if paused: return
		if physical_actor_session == null or latest_snapshot == null \
				or physical_actor_session.epoch != common_epoch \
				or latest_snapshot.render_world_generation != common_generation:
			common_input_error = "source owner changed during tape"
			return
		var relative := physical_actor_session.tick-common_tick_zero
		var selected := -1
		for index: int in common_tape.size():
			if int(common_tape[index].tick) <= relative: selected = index
			else: break
		if selected < 0:
			common_input_error = "input clock preceded tape"
			return
		var row: Dictionary = common_tape[selected]
		var accepted: bool = physical_actor_session.submit_workbench_action(1,
			{"move":Vector2(float(row.move[0]),float(row.move[1]))},
			{"q":false,"e":false,"s":false,"boost":false},false)
		if not accepted:
			common_input_error = "ordinary input refused: "+str(physical_actor_session.last_error)
		elif selected != common_tape_index:
			common_tape_index = selected
			common_tape_events.append({"input_index":selected,"requested_physical_tick":row.tick,
				"accepted_physical_tick":relative,"time_usec":Time.get_ticks_usec(),"move":row.move})

	func _physics_process(delta: float) -> void:
		common_physics_started = Time.get_ticks_usec()
		var before: int = physical_actor_session.tick if physical_actor_session != null else -1
		super._physics_process(delta)
		append_common({"event":"physics_callback","start_usec":common_physics_started,
			"time_usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames(),
			"physics_frame":Engine.get_physics_frames(),"before_step":before,
			"after_step":physical_actor_session.tick if physical_actor_session != null else -1,
			"waiting_body_sample":_workbench_wait_sample,
			"pending_hard_chunks":rapier_bridge.pending_hard_surface_chunks()})

	func apply_latest_rigid_body_results(snapshot: CyberSimulationSnapshot = null) -> void:
		common_applied_snapshot = snapshot
		super.apply_latest_rigid_body_results(snapshot)

	func _record_completed_playable_course_step() -> void:
		var completed_usec := Time.get_ticks_usec()
		super._record_completed_playable_course_step()
		if not common_active or physical_actor_session == null: return
		var item: CyberSimulationSnapshot = common_applied_snapshot
		var bridge: Variant = physical_actor_session.bridge
		var bodies: Array[Dictionary] = []
		for slot: int in bridge._members.size():
			var pose: Transform2D = bridge.body_transform(slot)
			var velocity: Vector2 = bridge.body_linear_velocity(slot)
			var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(bridge._body_rids[slot])
			bodies.append({"slot":slot,"instance_id":bridge._members[slot].instance_id,
				"xy":[pose.origin.x,pose.origin.y],"angle":pose.get_rotation(),
				"velocity":[velocity.x,velocity.y],"contacts":direct.get_contact_count() if direct != null else -1})
		append_common({"event":"rapier_step","start_usec":common_physics_started,
			"time_usec":completed_usec,"observer_usec":Time.get_ticks_usec()-completed_usec,
			"step":physical_actor_session.tick,
			"manual_steps":rapier_bridge.manual_step_count(),"fixed_delta":rapier_bridge.fixed_delta(),
			"solver_usec":roundi(rapier_bridge.last_step_time_ms()*1000.0),
			"session":bridge._session,"epoch":bridge._epoch,"bodies":bodies,
			"native_tick_used":item.tick_index if item != null else -1,
			"native_snapshot_serial":item.serial if item != null else -1,
			"native_completed_usec":item.get("last_native_tick_completed_usec") if item != null and common_snapshot_properties.has("last_native_tick_completed_usec") else null,
			"physics_handoff_usec":item.get("physics_handoff_usec") if item != null and common_snapshot_properties.has("physics_handoff_usec") else null,
			"completed_body_sample":item.lab_context.get("workbench_completed_sample",-1) if item != null else -1,
			"required_hard_revision":item.lab_context.get("workbench_hard_surface_revision",-1) if item != null else -1,
			"packet_hard_revision":item.hard_surface_revision if item != null else -1,
			"installed_hard_revision":last_hard_surface_revision,
			"pending_hard_chunks":rapier_bridge.pending_hard_surface_chunks(),
			"response_accepted":bridge.last_application.get("accepted",false),
			"response_refusal":bridge.last_application.get("refusal",""),
			"accepted_samples":Array(bridge._accepted_samples)})

	func consume_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
		var started := Time.get_ticks_usec()
		var before := last_uploaded_render_snapshot_serial
		super.consume_render_snapshot(snapshot)
		var completed_usec := Time.get_ticks_usec()
		if last_uploaded_render_snapshot_serial != before:
			common_uploaded_generated_usec = snapshot.render_generated_usec
			common_uploaded_native_tick = snapshot.render_tick_index
			var material: Variant = call("material_publication_status") if has_method("material_publication_status") else null
			append_common({"event":"texture_upload","start_usec":started,"time_usec":completed_usec,
				"observer_usec":Time.get_ticks_usec()-completed_usec,"material":material,
				"process_frame":Engine.get_process_frames(),
				"render_serial":last_uploaded_render_snapshot_serial,"tick_index":snapshot.render_tick_index,
				"snapshot_serial":snapshot.serial,"generated_usec":snapshot.render_generated_usec,
				"patch_bytes":snapshot.render_patch_cells.size(),"patch_count":snapshot.render_patch_rectangles.size()/6,
				"full_refresh":snapshot.render_full_refresh,"world_generation":last_uploaded_world_generation})

	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		append_common({"event":"main_callback","start_usec":started,"time_usec":Time.get_ticks_usec(),
			"process_frame":Engine.get_process_frames(),
			"snapshot_serial":latest_snapshot.serial if latest_snapshot != null else -1,
			"native_tick":latest_snapshot.tick_index if latest_snapshot != null else -1,
			"uploaded_render_serial":last_uploaded_render_snapshot_serial,
			"uploaded_generated_usec":common_uploaded_generated_usec,
			"uploaded_native_tick":common_uploaded_native_tick})

var host: ObservedMain
var output := ""
var fixture_name := "reference2048"
var camera := "follow"
var workers := 4
var wave := true
var problems: Array[String] = []
var capture_start := 0
var capture_end := 0
var images: Array[Dictionary] = []
var fixture_identity: Dictionary = {}
var wave_before: Dictionary = {}
var source_before: Dictionary = {}
var selectors_before: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="): output = arg.trim_prefix("--receipt=")
		if arg.begins_with("--fixture="): fixture_name = arg.trim_prefix("--fixture=")
		if arg.begins_with("--camera="): camera = arg.trim_prefix("--camera=")
		if arg.begins_with("--workers="): workers = int(arg.trim_prefix("--workers="))
		if arg == "--water-law=freemass_v1": wave = false
	if output.is_empty() or fixture_name not in ["reference2048","landscape2048x1024"] \
			or camera not in ["free","follow"] or workers not in [1,4]:
		push_error("PUBPRES_SOURCE: explicit receipt, registered fixture/camera/workers required")
		quit(2)
		return
	ProjectSettings.set_setting("cybersand/native_worker_threads",workers)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	set_meta("cybersand_feature","shared_workbench")
	_run.call_deferred()

func check(value: bool, reason: String) -> bool:
	if not value:
		problems.append(reason)
		push_error("PUBPRES_SOURCE: "+reason)
	return value

func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec()+SETUP_MSEC
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func identity() -> Dictionary:
	var result := {"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"files":{}}
	for path: String in ["res://scripts/main.gd","res://scripts/simulation_worker.gd",
		"res://scripts/workbench_physics_bridge.gd","res://scripts/rapier_physics_bridge.gd",
		"res://tests/pubpres_source_gameplay.gd","res://scripts/engine_lab_reference_fixture.gd",
		"res://shaders/material_palette.gdshader","res://project.godot"]:
		result.files[path] = FileAccess.get_sha256(path)
	for path: String in ["res://scripts/blit_material_publisher.gd",
		"res://scripts/workbench_presentation_coherence.gd","res://scripts/workbench_presentation_history.gd",
		"res://scripts/workbench_material_timeline.gd","res://scripts/workbench_native_rendezvous.gd",
		"res://scripts/shared_workbench.gd","res://tests/fixtures/engine_lab/setup-gate-canvas.json"]:
		result.files[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else null
	for path: String in ["res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
		"res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
		"res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
		"res://addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"]:
		if FileAccess.file_exists(path): result.files[path] = FileAccess.get_sha256(path)
	return result

func effective_selectors() -> Dictionary:
	var requested := {}
	for key: String in ["CYBERSAND_MATERIAL_PUBLICATION","CYBERSAND_DIAG_PHYSICS_PUBLICATION",
		"CYBERSAND_DIAG_PRESENTATION","CYBERSAND_DIAG_MATERIAL_TIMING","CYBERSAND_DIAG_RENDER_CADENCE",
		"CYBERSAND_DIAG_NATIVE_RENDEZVOUS"]:
		requested[key] = OS.get_environment(key)
	var properties := {}
	for item: Dictionary in host.get_property_list(): properties[str(item.name)] = true
	var presentation: Variant = host.get("workbench_presentation_frame") if properties.has("workbench_presentation_frame") else null
	return {"requested":requested,
		"material":host.call("material_publication_status") if host.has_method("material_publication_status") else null,
		"physics":host.simulation_worker.call("physics_publication_mode") if host.simulation_worker.has_method("physics_publication_mode") else null,
		"presentation":presentation.get("policy") if presentation is Dictionary else null,
		"material_timing":presentation.get("material_timing",{}).get("timing_source") if presentation is Dictionary else null,
		"cadence":("legacy" if host.call("_legacy_render_cadence") else "repaired") if host.has_method("_legacy_render_cadence") else null,
		"rendezvous":host.call("native_rendezvous_status") if host.has_method("native_rendezvous_status") else null,
		"pixel_pacing":host.simulation_worker.call("engine_lab_pixel_pacing") if host.simulation_worker.has_method("engine_lab_pixel_pacing") else null,
		"render_snapshot_hz":host.render_snapshot_hz,"cadence_lod_enabled":host.cadence_lod_enabled,
		"null_meaning":"source has no diagnostic selector/status API; inspect hashed original source, not a substituted implementation"}

func hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func water_identity() -> Dictionary:
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	var spray: Dictionary = snapshot.lab_context.get("water_spray",{}) if snapshot != null else {}
	return {"wave_flow":host.tower_context.get("wave_flow",{}).duplicate(true),
		"construction":host.tower_context.get("liquid_construction_receipt",{}).duplicate(true),
		"policy":host.tower_context.get("liquid_solver_policy",{}).duplicate(true),
		"water_ledger":spray.get("water",{}).duplicate(),"water_ledger_healthy":spray.get("healthy",false),
		"water_ledger_tick":snapshot.tick_index if snapshot != null else -1}

func check_water_ledger(state: Dictionary, label: String) -> void:
	var water: Dictionary = state.get("water_ledger",{})
	check(state.get("water_ledger_healthy",false) and not water.is_empty(),label+" native Water ledger healthy")
	if water.is_empty(): return
	check(int(water.get("total",-1)) == int(water.get("expected",-2))
		and int(water.get("visible",-1))+int(water.get("overfill",-1))+int(water.get("ballistic",-1)) == int(water.get("total",-2)),
		label+" grid and ballistic Water match baseline plus produced minus consumed")

func policy(ui: Control) -> PackedInt32Array:
	var api: Variant = ui._liquids.bridge
	var original: PackedInt32Array = api.default_liquid_policy()
	for row: Dictionary in api.liquid_policy_assignment_choices(original,3):
		if str(row.get("family","")) == "freemass_v1" and str(row.get("variant","")) == "reference" \
				and row.get("accepted",false): return row.request
	check(false,"accepted FreeMass Water carrier unavailable")
	return PackedInt32Array()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path := output.trim_suffix(".json")+"-"+label+".png"
	if check(image != null and not image.is_empty() and image.save_png(path) == OK,"framebuffer "+label):
		images.append({"label":label,"path":path,"sha256":FileAccess.get_sha256(path),
			"width":image.get_width(),"height":image.get_height(),"outside_timing":true})

func draw_observed() -> void:
	if host == null: return
	host.append_common({"event":"framebuffer_draw","time_usec":Time.get_ticks_usec(),
		"process_frame":Engine.get_process_frames(),"rendered_frames":Engine.get_frames_drawn(),
		"render_serial":host.last_uploaded_render_snapshot_serial,
		"inline_main":RenderingServer.is_on_render_thread()})

func _run() -> void:
	await process_frame
	source_before = identity()
	root.size = Vector2i(1600,900)
	if DisplayServer.get_name() != "headless":
		RenderingServer.call_on_render_thread(Callable(DisplayServer,"window_set_vsync_mode").bind(DisplayServer.VSYNC_DISABLED))
	var loaded: Control = load("res://main.tscn").instantiate()
	loaded.set_script(ObservedMain)
	host = loaded
	root.add_child(host)
	if not check(await until(func() -> bool: return host.shared_workbench != null \
		and not host.shared_workbench.applied.is_empty()),"ordinary initial Workbench admitted"):
		await finish()
		return
	var ui: Control = host.shared_workbench
	var carrier := policy(ui)
	if carrier.is_empty():
		await finish()
		return
	var setup: Dictionary
	var packet: Dictionary = {}
	if fixture_name == "reference2048":
		var reference := Reference.new()
		var materialized: Dictionary = await reference.materialize(self)
		if not check(materialized.get("ok",false),"exact owner reference generated"):
			await finish()
			return
		setup = materialized.setup.duplicate(true)
		packet = materialized.packet
		fixture_identity = {"name":fixture_name,"json_sha256":Reference.FILE_SHA256,
			"generated_sha256":Reference.OUTPUT_SHA256,"receipts":materialized.generation_receipt_count}
	else:
		setup = Setup.fresh(carrier,Vector2i(2048,1024))
		setup.actors = [Setup.instance("needle",1,Vector2(200,200))]
		setup.next_id = 2
		setup.selected = 1
		# Separately registered authored landscape. Its tall Water column
		# spreads into an actual finite basin under unchanged Wave semantics.
		setup.edits = [[0,1008,2048,16,58],[0,0,16,1024,58],[2032,0,16,1024,58],
			[32,528,480,480,3],[528,880,448,128,3],[1024,920,992,88,3],
			[768,816,16,192,58],[1296,872,16,136,58],[256,320,320,8,58]]
		fixture_identity = {"name":fixture_name,"source":"authored_setup_v2","extent":[2048,1024]}
	setup.liquid_policy = Array(carrier)
	setup.rule_radius = 2
	fixture_identity["setup_sha256"] = JSON.stringify(setup).sha256_text()
	host.workbench_water_options["workbench_wave_flow"] = wave
	var epoch := host._physical_epoch
	if not check(ui.apply(setup,false,0,false,false,packet),"fixture submitted through ordinary Apply") \
		or not check(await until(func() -> bool: return host.pending_microscenario_apply.is_empty() \
			and host._physical_epoch > epoch and host.physical_actor_session != null \
			and host._physical_terrain_ready),"matching native World, actor and complete terrain adopted") \
		or not check(await until(func() -> bool: return host.latest_snapshot != null \
			and host.last_uploaded_revision == host.latest_snapshot.world_revision \
			and not host.workbench_display_frame().is_empty()),"current material and actor sample published"):
		await finish()
		return
	ui._camera.select(1 if camera == "follow" else 0)
	ui.set_camera(1 if camera == "follow" else 0)
	var state: Dictionary = ui.body_state(1)
	ui._set_view(Vector2(state.position)-Vector2(240,135),Vector2i(480,270))
	await process_frame
	await process_frame
	wave_before = water_identity()
	check_water_ledger(wave_before,"Initial")
	if wave:
		check(wave_before.wave_flow.get("enabled",false) and wave_before.policy.get("effective_water_solver","") == "wave_flow_v1",
			"actual Wave Flow selected through native construction")
	await capture("before")
	selectors_before = effective_selectors()
	host.common_tape = TAPE.duplicate(true)
	host.common_tick_zero = host.physical_actor_session.tick
	host.common_epoch = host.physical_actor_session.epoch
	host.common_generation = host.latest_snapshot.render_world_generation
	for item: Dictionary in host.latest_snapshot.get_property_list(): host.common_snapshot_properties[str(item.name)] = true
	host.simulation_worker.set_worker_participation_sampling(true)
	host.simulation_worker.call("begin_common_probe")
	host.common_active = true
	RenderingServer.frame_post_draw.connect(draw_observed)
	capture_start = Time.get_ticks_usec()
	check(ui.toggle_pause(),"native and Rapier unpaused through ordinary control")
	while Time.get_ticks_usec()-capture_start < MAX_CAPTURE_USEC:
		var elapsed := Time.get_ticks_usec()-capture_start
		if elapsed >= MIN_CAPTURE_USEC and host.physical_actor_session.tick-host.common_tick_zero >= TARGET_STEPS: break
		if host.simulation_worker.has_failed() or not host.common_input_error.is_empty(): break
		await process_frame
	capture_end = Time.get_ticks_usec()
	host.common_active = false
	check(host.physical_actor_session.tick-host.common_tick_zero >= TARGET_STEPS,"144 real Rapier completions")
	check(host.common_tape_events.size() == TAPE.size(),"all registered input segments admitted")
	for row: Dictionary in host.common_tape_events:
		check(row.requested_physical_tick == row.accepted_physical_tick,"input segment used exact completed-step index")
	check(host.common_input_error.is_empty(),"ordinary input owner remained valid")
	check(not host.simulation_worker.has_failed(),"native health preserved")
	await finish()

func finish() -> void:
	var worker := {"events":[],"overflow":false}
	var final_water: Dictionary = {}
	var history: Dictionary = {}
	if host != null and is_instance_valid(host):
		host.common_active = false
		worker = host.simulation_worker.call("end_common_probe")
		if RenderingServer.frame_post_draw.is_connected(draw_observed): RenderingServer.frame_post_draw.disconnect(draw_observed)
		if host.shared_workbench != null and not host.paused: host.shared_workbench.toggle_pause()
		await process_frame
		await process_frame
		final_water = water_identity()
		check_water_ledger(final_water,"Final")
		if wave and not wave_before.is_empty():
			var before: Dictionary = wave_before.wave_flow
			var after: Dictionary = final_water.wave_flow
			check(after.get("enabled",false) and after.get("healthy",false)
				and after.get("session_generation",-1) == before.get("session_generation",-2),
				"same healthy Wave World retained")
			# Only the authored Water/steel basin is a closed Water fixture.
			# The exact owner reference also contains Lava and Acid, whose
			# registered native reactions consume Water. Its quantity ledger
			# above still must balance every native source and sink exactly.
			if fixture_name == "landscape2048x1024":
				check(after.get("water_quantity") == before.get("water_quantity"),"Closed Wave Water quantity conserved")
			check(int(after.get("ticks",0)) > int(before.get("ticks",0))
				and int(after.get("rounds",0))-int(before.get("rounds",0))
				== (int(after.get("ticks",0))-int(before.get("ticks",0)))*int(after.get("substeps",0)),
				"native Wave ticks and substeps actually completed")
			check(final_water.construction.get("receipt_hash") == wave_before.construction.get("receipt_hash")
				and final_water.policy.get("effective_water_solver","") == "wave_flow_v1",
				"native construction and Water policy unchanged")
		await capture("after")
		if DisplayServer.get_name() != "headless" and host.texture != null and host.previous_texture != null:
			var current: Image = host.texture.get_image()
			var previous: Image = host.previous_texture.get_image()
			if current != null: current.convert(Image.FORMAT_RG8)
			if previous != null: previous.convert(Image.FORMAT_RG8)
			var expected: PackedByteArray = host.image.get_data()
			history = {"current_matches_cpu":current != null and current.get_data() == expected,
				"native_tick":host.common_uploaded_native_tick,"render_serial":host.last_uploaded_render_snapshot_serial,
				"world_generation":host.last_uploaded_world_generation,"world_revision":host.last_uploaded_revision,
				"current_sha256":hash_bytes(current.get_data()) if current != null else "",
				"previous_sha256":hash_bytes(previous.get_data()) if previous != null else "",
				"previous_verified":false,"scope":"current GPU against source CPU; prior plane hash retained; transition oracle separately verifies both histories"}
			check(history.current_matches_cpu,"actual final material framebuffer matches current CPU bytes")
		check(not host.common_overflow and not worker.overflow,"bounded observational trace retained every event")
		check(source_before == identity(),"source and runtime hashes unchanged during case")
	var trace_path := output.trim_suffix(".json")+"-events.jsonl"
	var writer := FileAccess.open(trace_path,FileAccess.WRITE)
	if writer != null:
		writer.store_line(JSON.stringify({"event":"identity","source":source_before,"fixture":fixture_identity,
			"clock_notice":"Main frame_post_draw delivery is not GPU completion; native completion is observed at post-tick capture entry. Exact legacy completion timestamps unavailable."}))
		if host != null:
			for row: Dictionary in host.common_events: writer.store_line(JSON.stringify(row))
		for row: Dictionary in worker.events: writer.store_line(JSON.stringify(row))
		writer.close()
	else:
		check(false,"trace file could not be written")
	var result := {"schema":"pubpres-source-gameplay-v1","complete":problems.is_empty(),"failures":problems,
		"fixture":fixture_identity,"camera":camera,"workers":workers,"water_law":"wave_flow_v1" if wave else "freemass_v1",
		"capture_start_usec":capture_start,"capture_end_usec":capture_end,"input_tape":TAPE,
		"capture_physical_tick_start":host.common_tick_zero if host != null else -1,
		"target_physical_steps":TARGET_STEPS,"minimum_capture_usec":MIN_CAPTURE_USEC,
		"input_events":host.common_tape_events if host != null else [],"source_identity":source_before,
		"trace_path":trace_path,"trace_sha256":FileAccess.get_sha256(trace_path),
		"water_before":wave_before,"water_after":final_water,"gpu_history":history,"framebuffers":images,
		"engine":Engine.get_version_info(),"platform":OS.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"process_id":OS.get_process_id(),"profile":OS.get_user_data_dir(),
		"case_nonce":OS.get_environment("CYBERSAND_SHADER_NONCE"),
		"cache_state":OS.get_environment("CYBERSAND_SHADER_CACHE_STATE"),
		"selectors_before":selectors_before,"selectors_after":effective_selectors() if host != null else {},
		"adapter":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),
		"logical_processors":OS.get_processor_count(),"static_memory_peak_bytes":OS.get_static_memory_peak_usage(),
		"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"display":{"window":[root.size.x,root.size.y],"fps_cap":Engine.max_fps,"physics_callbacks_hz":Engine.physics_ticks_per_second,
			"server":DisplayServer.get_name(),"vsync_mode":DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1},
		"observation_scope":"identical test subclass delegates each Main/worker callback once; production scheduling, native health and physics fences unchanged"}
	writer = FileAccess.open(output,FileAccess.WRITE)
	if writer != null:
		writer.store_string(JSON.stringify(result,"  ")+"\n")
		writer.close()
	print("PUBPRES_SOURCE_GAMEPLAY_RESULT ",JSON.stringify({"complete":result.complete,"failures":problems}))
	if host != null: host.queue_free()
	await process_frame
	await process_frame
	quit(int(not problems.is_empty()))
