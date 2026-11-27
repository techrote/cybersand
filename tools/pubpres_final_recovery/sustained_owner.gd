extends "res://tests/pubpres_playability_owner_start.gd"

# Drive the actual shipped example and ordinary controls after the owner startup probe disconnects.
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const DURATION_USEC := 300000000
var exercise_started := false
var failures: Array[String] = []
var actions: Array[Dictionary] = []
var progress: Array[Array] = []
var frame_gaps: Array[int] = []
var resources: Array[Dictionary] = []


func _poll() -> void:
	super._poll()
	if not exercise_started and FileAccess.file_exists(receipt_path):
		exercise_started = true
		_exercise.call_deferred()


func _action(name: String, ok: bool) -> void:
	actions.append({"action":name,"accepted":ok,"time_usec":Time.get_ticks_usec(),
		"step":app.physical_actor_session.tick,"native_tick":app.latest_snapshot.tick_index,
		"material_revision":app.last_uploaded_revision,"message":app.shared_workbench.message})
	if not ok: failures.append(name)


func _exercise() -> void:
	var ui: Control = app.shared_workbench
	var session = app.physical_actor_session
	var world: int = app.last_uploaded_world_generation
	var point := Vector2i(230, int(app.world_extent.y) - 160)
	var output := receipt_path.get_base_dir()
	await RenderingServer.frame_post_draw
	_action("initial framebuffer", root.get_texture().get_image().save_png(output+"/before.png") == OK)
	var control := Catalog.control_for(ui.actor(ui.applied,1))
	control.source = "policy"
	control.policy = "ambient"
	control.ambient = Profile.blank("pubpres-owner-play")
	control.ambient.modules = [Profile.make_module("seek_material")]
	_action("activate AMBIENT", ui.set_actor_control(1,control))
	_action("start active Water and bodies", app.paused and ui.toggle_pause())
	var began := Time.get_ticks_usec()
	var previous := began
	var last_tick: int = session.tick
	var initial_tick := last_tick
	var pulse := 0
	var capture_end := began
	var paused_at := -1
	var phase_before := "playing"
	while capture_end - began < DURATION_USEC and failures.is_empty():
		await process_frame
		capture_end = Time.get_ticks_usec()
		if session != app.physical_actor_session or world != app.last_uploaded_world_generation or app.simulation_worker.has_failed():
			failures.append("native or physical owner changed while playing")
			break
		if frame_gaps.size() >= 40000:
			failures.append("frame observation capacity exceeded")
			break
		frame_gaps.append(capture_end-previous)
		previous = capture_end
		var tick: int = session.tick
		if tick != last_tick:
			if tick < last_tick or tick != session.bridge.manual_step_count() or tick != app._workbench_completed_step:
				failures.append("physical owner, completed step and Rapier manual-step counters diverged")
				break
			progress.append([tick,app._workbench_completed_step_usec,capture_end,app.latest_snapshot.tick_index,
				app.last_uploaded_revision,app.last_uploaded_render_snapshot_serial,phase_before])
			last_tick = tick
		if capture_end-began >= (resources.size()+1)*5000000:
			var material: Dictionary = app.material_publication_status()
			resources.append({"time_usec":capture_end,"physical_step":tick,"native_tick":app.latest_snapshot.tick_index,
				"epoch":session.epoch,"world":world,"static_bytes":OS.get_static_memory_usage(),
				"video_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
				"texture_rids":[app.texture.get_rid().get_id(),app.previous_texture.get_rid().get_id()],
				"backend":material.backend,"active_slots":material.get("full_image_slots",-1),
				"hard_queue":app.rapier_bridge.pending_hard_surface_chunks()})
		if pulse < 30 and capture_end-began >= (pulse+1)*10000000:
			var index := pulse
			pulse += 1
			var camera := 0 if index % 2 == 0 else 1
			ui._camera.select(camera)
			ui.set_camera(camera)
			ui.zoom_by(1 if camera == 0 else -1)
			if camera == 0: ui._set_view(Vector2(50+index*2,70), app.current_view_size)
			var cell := point + Vector2i((index % 8)*10, 0)
			_action("paint-%02d" % index, ui.paint(cell,[CyberCellWorld.SAND,3,58,0][index % 4]))
			match index:
				2, 17:
					_action("pilot takeover",ui.pilot_instance(1))
				3, 18:
					_action("pilot flight",session.submit_workbench_action(1,{"move":Vector2.UP},
						{"q":false,"e":false,"s":false,"boost":false},false))
				4, 19:
					_action("hand back to AMBIENT",ui.hand_back_pilot())
					_action("AMBIENT policy restored",Catalog.control_for(ui.actor(ui.applied,1)).policy == "ambient")
				10:
					_action("pause",not app.paused and ui.toggle_pause())
					paused_at = tick
					phase_before = "paused"
				11:
					_action("manual step",app.paused and tick == paused_at and ui.step_once())
					phase_before = "manual"
				12:
					_action("resume",app.paused and tick == paused_at+1 and ui.toggle_pause())
					phase_before = "resuming"
		elif phase_before == "resuming" and tick > paused_at+1:
			phase_before = "playing"
	var ended := Time.get_ticks_usec()
	if not app.paused: _action("stop simulation",ui.toggle_pause())
	await RenderingServer.frame_post_draw
	_action("terminal framebuffer",root.get_texture().get_image().save_png(output+"/after.png") == OK)
	var report := {"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"scene":scene_name,
		"process_id":OS.get_process_id(),"began_usec":began,"ended_usec":ended,"failures":failures,
		"world":world,"epoch":session.epoch,"initial_tick":initial_tick,"actions":actions,"frames_usec":frame_gaps,
		"physical_observations":progress,"resources":resources,"pulses":pulse,
		"before_sha256":FileAccess.get_sha256(output+"/before.png"),"after_sha256":FileAccess.get_sha256(output+"/after.png")}
	var file := FileAccess.open(output+"/session.json",FileAccess.WRITE)
	if file == null:
		quit(5)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	quit(0 if failures.is_empty() else 1)
