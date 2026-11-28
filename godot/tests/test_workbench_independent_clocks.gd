extends SceneTree

# PRESENTATION-TIME-001: exercise independently configurable clocks through real
# Main callbacks and the existing Engine Lab controls; preserve physical defaults.
# A fixed-step free-flight comparison isolates presentation policy from physics.
const Setup = preload("res://scripts/workbench_setup.gd")
const STEPS: int = 120
const WAIT_MS: int = 90000

class ClockHost extends "res://scripts/main.gd":
	var clock_capture: bool = false
	var clock_samples: Array = []
	var clock_finished_usec: int = 0
	func _physics_process(delta: float) -> void:
		var before: int = physical_actor_session.tick if physical_actor_session != null else -1
		super._physics_process(delta)
		if not clock_capture or physical_actor_session == null or physical_actor_session.tick <= before: return
		var direct := PhysicsServer2D.body_get_direct_state(physical_actor_session.bridge._body_rids[0])
		clock_samples.append([direct.transform.origin.x,direct.transform.origin.y,
			direct.transform.get_rotation(),direct.linear_velocity.x,direct.linear_velocity.y,
			direct.angular_velocity])
		if clock_samples.size() >= 120:
			clock_capture = false
			clock_finished_usec = Time.get_ticks_usec()
			paused = true
			update_worker_frame_state()

var host: Control
var checks: int = 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var output: String = ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--independent-clock-evidence="):
			output = argument.trim_prefix("--independent-clock-evidence=")
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("INDEPENDENT_CLOCKS: "+label)
	return ok

func until(predicate: Callable, limit: int=WAIT_MS) -> bool:
	var deadline: int = Time.get_ticks_msec()+limit
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func _case(mode: String, camera: String) -> void:
	var label: String = mode+"-"+camera
	print("INDEPENDENT_CLOCK_STAGE ",label," mount")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy" if mode=="original" else "coherent")
	host = load("res://main.tscn").instantiate()
	host.set_script(ClockHost)
	root.add_child(host)
	var ui: Control = host.shared_workbench
	if not check(await until(func() -> bool: return ui!=null and not ui.applied.is_empty()),
		label+" mounted normal Workbench"): return
	check(host.engine_lab_wait_native_sample and host.simulation_worker.engine_lab_pixel_pacing().sample_wake,
		label+" ordinary launcher retains established physical pacing before explicit configuration")
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors = [Setup.instance("needle",1,Vector2(256,96))]
	setup.next_id = 2
	setup.selected = 1
	var old_epoch: int = host._physical_epoch
	print("INDEPENDENT_CLOCK_STAGE ",label," install")
	if not check(ui.apply(setup),label+" native empty flight World requested"): return
	if not check(await until(func() -> bool:
		return host._physical_epoch>old_epoch and host.pending_microscenario_apply.is_empty() \
			and host.physical_actor_session!=null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		label+" actual native material, terrain collider and actor receipt installed"): return
	ui._camera.select(1 if camera=="follow" else 0)
	ui._set_view(Vector2(120,20),Vector2i(240,135))
	var free_origin: Vector2 = host.camera_origin
	# UI callbacks are the human entry point for independently adjustable rates.
	ui.engine_lab._widgets["wait_sample"].button_pressed = false
	ui.engine_lab._widgets["sample_wake"].button_pressed = false
	ui.engine_lab._widgets["pixel"].value = 2
	ui.engine_lab._widgets["rapier"].value = 120
	check(not host.engine_lab_wait_native_sample and not host.simulation_worker.engine_lab_pixel_pacing().sample_wake,
		label+" rate changes do not secretly enable handshake or early sample wake")
	check(is_equal_approx(host.rapier_bridge.fixed_delta(),1.0/60.0),
		label+" existing fixed simulation step is preserved")
	var native_before: int = host.latest_snapshot.tick_index
	var started_usec: int = Time.get_ticks_usec()
	print("INDEPENDENT_CLOCK_STAGE ",label," fly")
	var observed: Dictionary = {"max_follow_residual":0.0,"frames":0,"visible_frames":0,"follow_frames":0}
	host.clock_capture = true
	host.paused = false
	host.update_worker_frame_state()
	var finished: bool = await until(func() -> bool:
		var presentation: Dictionary = host.workbench_presentation_frame
		if presentation.get("poses",{}).has(0): observed.visible_frames += 1
		if mode=="coherent" and camera=="follow" and presentation.get("poses",{}).has(0):
			observed.follow_frames += 1
			observed.max_follow_residual = maxf(observed.max_follow_residual,
				Vector2(presentation.follow_target).distance_to(presentation.poses[0].origin))
		observed.frames += 1
		return not host.clock_capture,10000)
	check(finished and host.clock_samples.size()==STEPS,label+" completes 120 Rapier steps at slow native cadence")
	var elapsed: float = float((host.clock_finished_usec if finished else Time.get_ticks_usec())-started_usec)/1000000.0
	var native_after: int = host.simulation_worker.take_latest_snapshot(0).tick_index
	var native_steps: int = native_after-native_before
	check(host.clock_samples.size()>maxi(4*native_steps,12),label+" Rapier advances repeatedly between native publications")
	check(native_steps<=ceili(elapsed*2.0)+2,label+" native timer is not accelerated by 120 Hz body samples")
	check(not host.simulation_worker.has_failed(),label+" independent clocks preserve native owner")
	check(observed.visible_frames>1,label+" independent flight actually presents the actor")
	check(host.workbench_presentation_frame.policy==("legacy_guarded" if mode=="original" else "coherent"),
		label+" requested presentation arm ran")
	if mode=="coherent" and camera=="follow":
		check(observed.follow_frames>1 and observed.max_follow_residual<0.01,label+" Follow targets chosen display pose")
	if camera=="free":
		check(host.camera_origin.is_equal_approx(free_origin),label+" Free camera remains independent of physics")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(host.clock_samples))
	cases.append({"name":label,"mode":mode,"camera":camera,"wall_seconds":elapsed,
		"native_steps":native_steps,"rapier_steps":host.clock_samples.size(),
		"native_hz":float(native_steps)/maxf(elapsed,0.000001),
		"rapier_hz":float(host.clock_samples.size())/maxf(elapsed,0.000001),
		"observed_frames":observed.frames,"visible_frames":observed.visible_frames,
		"follow_frames":observed.follow_frames,"max_follow_target_residual_cells":observed.max_follow_residual,
		"physics_sha256":digest.finish().hex_encode(),"samples":host.clock_samples.duplicate(true)})

func _run() -> void:
	var saved_mode: String = OS.get_environment("CYBERSAND_DIAG_PRESENTATION")
	var saved_fps: int = Engine.max_fps
	var saved_physics_hz: int = Engine.physics_ticks_per_second
	Engine.max_fps = 60
	set_meta("cybersand_feature","shared_workbench")
	for camera: String in ["free","follow"]:
		for mode: String in ["original","coherent"]:
			await _case(mode,camera)
			if is_instance_valid(host):
				host.paused = true
				host.update_worker_frame_state()
				host.queue_free()
				await process_frame
				await process_frame
	var max_physics_delta: float = 0.0
	if cases.size()==4:
		for pair: int in [0,2]:
			var first: Array = cases[pair].samples
			var second: Array = cases[pair+1].samples
			check(first.size()==STEPS and second.size()==STEPS,"paired physical-step trajectory has complete coverage")
			for index: int in range(mini(first.size(),second.size())):
				for component: int in range(6):
					max_physics_delta = maxf(max_physics_delta,absf(float(first[index][component])-float(second[index][component])))
		check(max_physics_delta<0.000001,"original and coherent presentation leave identical physical-step trajectories")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION",saved_mode)
	Engine.max_fps = saved_fps
	Engine.physics_ticks_per_second = saved_physics_hz
	var result: Dictionary = {"schema":"presentation-independent-clocks-v1","checks":checks,"failures":failures,
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"engine":Engine.get_version_info().string,
		"platform":OS.get_name(),"display":DisplayServer.get_name(),"max_physics_component_delta":max_physics_delta,
		"scope":"Real Main callbacks at 2 Hz native / 120 Hz Rapier targets; independently selected through Engine Lab, with established launcher defaults preserved. Empty-space same-step physics comparison, not async material-contact or physical GPU acceptance.",
		"cases":cases}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var writer: FileAccess = FileAccess.open(output.path_join("independent-clocks.json"),FileAccess.WRITE)
		if writer!=null: writer.store_string(JSON.stringify(result,"  ")+"\n");writer.close()
		else: check(false,"clock evidence file can be written")
	var summary: Dictionary = result.duplicate(true)
	for row: Dictionary in summary.cases: row.erase("samples")
	print("INDEPENDENT_CLOCKS_RESULT ",JSON.stringify(summary))
	quit(int(not failures.is_empty()))
