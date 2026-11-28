extends "res://tests/pubpres_playability_owner_start.gd"

# Observes the ordinary owner scene and the real Place/Reset/Restore handlers.
# The host override supplies focus for an unattended private display. The
# recording-off adapter also works on the frozen reference, whose collector
# predates the separate recording flag; the independent startup receipt remains.
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool: return true
	func _ready() -> void:
		var receipt := OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_RECEIPT")
		var disabled := OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_RECORDING") == "0"
		if disabled: OS.set_environment("CYBERSAND_PLAYABILITY_OWNER_RECEIPT","")
		super._ready()
		if disabled: OS.set_environment("CYBERSAND_PLAYABILITY_OWNER_RECEIPT",receipt)

var underway := false
var observations: Array[Dictionary] = []
var failures: Array[String] = []
var draw_times: Array[int] = []
var completion_times: Array[int] = []
var completion_id := ""
var graphical := false
var recording := true
var active_case: Dictionary = {}


func _start() -> void:
	graphical = DisplayServer.get_name() != "headless"
	recording = OS.get_environment("CYBERSAND_PLAYABILITY_OWNER_RECORDING") != "0"
	app = load("res://main.tscn").instantiate()
	app.set_script(FocusHost)
	root.add_child(app)
	if not recording and app._owner_gameplay != null:
		push_error("Recording-off request left a live owner recorder")
		quit(4)
		return
	deadline_msec = Time.get_ticks_msec()+240000
	process_frame.connect(_poll)
	process_frame.connect(_observe)
	if graphical: RenderingServer.frame_post_draw.connect(_draw)


func _poll() -> void:
	super._poll()
	if not underway and FileAccess.file_exists(receipt_path):
		underway = true
		_exercise.call_deferred()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _draw() -> void:
	if draw_times.size() < 20000: draw_times.append(Time.get_ticks_usec())
	if active_case.is_empty() or not active_case.get("accepted",false) \
			or active_case.first_coherent_draw_observed_usec >= 0 or app.physical_actor_session == null: return
	var session: Variant = app.physical_actor_session
	if session.epoch <= int(active_case.before_epoch): return
	var frame: Dictionary = app.workbench_presentation_frame
	var actor_slot: int = session.slot_for_instance(int(active_case.actor_instance))
	var slot: int = session.bridge.actor_body_index(actor_slot)
	if frame.get("valid",false) and frame.get("epoch",-1) == session.epoch \
			and frame.get("world_generation",-1) == app.last_uploaded_world_generation \
			and frame.get("poses",{}).has(slot):
		active_case.first_coherent_draw_observed_usec = Time.get_ticks_usec()
		active_case.coherent_draw_identity = {"epoch":frame.epoch,"world":frame.world_generation,
			"physical_step":frame.selected_steps.get(slot,-1),"material_serial":frame.upload_serial,
			"inline_render":RenderingServer.is_on_render_thread(),"frames_drawn":Engine.get_frames_drawn()}


func _observe() -> void:
	if app == null or app.physical_actor_session == null: return
	var id := "%d:%d" % [app._physical_epoch,app._workbench_completed_step]
	if id != completion_id and app._workbench_completed_step_usec > 0:
		completion_id = id
		if completion_times.size() < 20000:
			completion_times.append(app._workbench_completed_step_usec)


func _until(deadline: int) -> void:
	while Time.get_ticks_usec() < deadline:
		await process_frame


func _case(label: String, kind: String, position: Vector2, fire: bool) -> void:
	var ui: Control = app.shared_workbench
	ui._fire.button_pressed = fire
	var old_epoch: int = app._physical_epoch
	var actor_id: int = int(ui.applied.next_id) if kind == "place" else ui.selected_id()
	var begin := Time.get_ticks_usec()
	var request: int = app._microscenario_request_serial+1
	var native_tick: int = app.latest_snapshot.tick_index
	var previous_step: int = app._workbench_completed_step
	var accepted: bool
	if kind == "place": accepted = ui.place("needle",position)
	elif kind == "restore": accepted = ui.restore_start()
	else: accepted = ui.reset_selected()
	var returned := Time.get_ticks_usec()
	var row := {"label":label,"kind":kind,"fire":fire,"position":[position.x,position.y],
		"request_serial":request,"actor_instance":actor_id,"request_usec":begin,
		"request_return_usec":returned,"accepted":accepted,"before_epoch":old_epoch,
		"before_native_tick":native_tick,"before_physical_step":previous_step,
		"admitted_usec":-1,"first_observed_step_usec":-1,"first_input_usec":-1,
		"input_accepted_observed_usec":-1,"input_applied_observed_usec":-1,"first_coherent_draw_observed_usec":-1}
	observations.append(row)
	active_case = row
	if not accepted:
		failures.append(label+": request refused: "+ui.message)
		return
	var deadline := begin+120000000
	while Time.get_ticks_usec() < deadline:
		if not ui.busy() and app._physical_epoch > old_epoch and app.physical_actor_session != null \
				and app._physical_terrain_ready and app.last_uploaded_world_generation == app.latest_snapshot.render_world_generation:
			row.admitted_usec = Time.get_ticks_usec()
			row.epoch = app._physical_epoch
			row.world = app.last_uploaded_world_generation
			row.admission_physical_step = app.physical_actor_session.tick
			row.admission_rapier_steps = app.physical_actor_session.bridge.manual_step_count()
			row.physical_delta_seconds = app.physical_actor_session.bridge.fixed_delta()
			row.admission_native_tick = app.latest_snapshot.tick_index
			break
		await process_frame
	if row.admitted_usec < 0:
		failures.append(label+": owner admission timed out")
		return
	if not ui.pilot_instance(actor_id):
		failures.append(label+": pilot refused")
		return
	if app.paused and not ui.toggle_pause():
		failures.append(label+": Play refused")
		return
	ui._camera.select(1)
	ui.set_camera(1)
	var session: Variant = app.physical_actor_session
	var actor_slot: int = session.slot_for_instance(actor_id)
	var slot: int = session.bridge.actor_body_index(actor_slot)
	# Ordinary input requires the real neutral handoff after a new owner.
	for neutral in range(3): await process_frame
	row.first_input_usec = Time.get_ticks_usec()
	var commands_before: int = session.accepted_commands
	var input_step: int = session.tick
	var input_pose: Transform2D = session.bridge.body_transform(slot)
	row.input_response_observed_usec = -1
	_key(KEY_W,true)
	_key(KEY_C,true)
	var move_released := false
	var settle_end := Time.get_ticks_usec()+3000000
	while Time.get_ticks_usec() < settle_end:
		if graphical: await RenderingServer.frame_post_draw
		else: await process_frame
		if session != app.physical_actor_session or app.simulation_worker.has_failed():
			failures.append(label+": owner changed or native failed during observation")
			break
		if app.paused or not str(app.tower_context.get("workbench_refusal", "")).is_empty():
			failures.append(label+": observation stopped: "+str(app.tower_context.get("workbench_refusal",app.microscenario_error)))
			break
		if row.first_observed_step_usec < 0 and session.tick > 0:
			row.first_observed_step_usec = app._workbench_completed_step_usec
		if row.input_accepted_observed_usec < 0 and session.accepted_commands > commands_before \
				and Vector2(session._commands[actor_slot].get("move",Vector2.ZERO)).y < 0:
			row.input_accepted_observed_usec = Time.get_ticks_usec()
		if row.input_applied_observed_usec < 0 and session.tick > input_step \
				and Vector2(session._rigs[actor_slot]._action.get("move",Vector2.ZERO)).y < 0:
			row.input_applied_observed_usec = Time.get_ticks_usec()
		if row.input_response_observed_usec < 0 and row.input_applied_observed_usec >= 0 \
				and session.bridge.body_transform(slot).origin.y < input_pose.origin.y-0.01:
			row.input_response_observed_usec = Time.get_ticks_usec()
		# A short real keyboard pulse observes admission without driving the
		# Needle through the finite world's top boundary during the cadence tail.
		# Native material work, actor configuration and source fixture are unchanged.
		if not move_released and Time.get_ticks_usec()-int(row.first_input_usec) >= 100000 \
				and row.input_applied_observed_usec >= 0:
			_key(KEY_W,false)
			move_released = true
	_key(KEY_W,false)
	_key(KEY_C,false)
	row.end_usec = Time.get_ticks_usec()
	row.final_physical_steps = session.tick
	row.final_rapier_steps = session.bridge.manual_step_count()
	row.final_native_tick = app.latest_snapshot.tick_index
	row.final_static_bytes = OS.get_static_memory_usage()
	row.final_paused = app.paused
	row.final_refusal = str(app.tower_context.get("workbench_refusal",""))
	row.nozzle_write_receipts = app.tower_context.get("workbench_emitters",[]).size()
	active_case = {}
	if row.final_rapier_steps-row.admission_rapier_steps != row.final_physical_steps-row.admission_physical_step:
		failures.append(label+": session completion count differs from actual Rapier completion")
	if row.first_observed_step_usec < 0: failures.append(label+": no real physical completion")
	if row.input_accepted_observed_usec < 0: failures.append(label+": no accepted keyboard command")
	if row.input_applied_observed_usec < 0: failures.append(label+": keyboard command did not reach a completed physical step")
	if graphical and row.first_coherent_draw_observed_usec < 0: failures.append(label+": no coherent draw observation")


func _exercise() -> void:
	var ui: Control = app.shared_workbench
	if app.paused: ui.toggle_pause()
	await _until(Time.get_ticks_usec()+1000000)
	await _case("first-air-fire-off","place",Vector2(280,120),false)
	await _case("warm-air-fire-off","reset",Vector2(280,120),false)
	await _case("warm-air-fire-on","reset",Vector2(280,120),true)
	await _case("near-material-fire-on","place",Vector2(190,app.world_extent.y-110),true)
	await _case("scene-replacement","restore",Vector2.ZERO,false)
	await _case("post-replacement-spawn","place",Vector2(320,160),false)
	if not app.paused: ui.toggle_pause()
	var report := {"schema":"pubpres-spawn-latency-v1","source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scene":scene_name,"process_id":OS.get_process_id(),"graphical":graphical,"recording":recording,
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
			if OS.get_name() == "Linux" else "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"),
		"cases":observations,"draw_callback_usec":draw_times,"observed_completion_usec":completion_times,
		"failures":failures,"pass":failures.is_empty(),
		"scope":"CPU application request/admission/input and actual Rapier completion observations. Graphical draws require coherent accepted identity; they are not physical scanout or GPU duration. Process-frame completion sampling may miss intermediate completions; existing recorder retains each actual step when enabled."}
	var output := receipt_path.get_base_dir().path_join("spawn.json")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(5); return
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print("PUBPRES_SPAWN_LATENCY ",output," pass=",failures.is_empty())
	quit(0 if failures.is_empty() else 1)
