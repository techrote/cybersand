extends SceneTree

# PRESENTATION-TIME-001: deterministic delivery-clock counterexamples followed
# by genuine native upload/shader wiring and a fixed-input authority control.
# Synthetic timestamps below test clock policy; they are not measured FPS.
const Timeline = preload("res://scripts/workbench_material_timeline.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var host: Control
var output: String = ""
var saved_environment: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--material-timing-evidence="):
			output = argument.trim_prefix("--material-timing-evidence=")
	for key: String in ["CYBERSAND_DIAG_PRESENTATION","CYBERSAND_DIAG_MATERIAL_TIMING",
			"CYBERSAND_DIAG_FLYER_POSE","CYBERSAND_DIAG_RENDER_CADENCE"]:
		saved_environment[key] = OS.get_environment(key)
		OS.set_environment(key,"")
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","measured")
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("MATERIAL_DELIVERY_TIMING: "+label)
	return ok


func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false


func deterministic_clock_cases() -> void:
	var clock = Timeline.new()
	var empty: Dictionary = clock.frame(1000000)
	check(empty.snapshot_blend==1.0 and not empty.previous_blend_active \
		and empty.material_age_usec==-1 and empty.current.is_empty(),"no upload invents neither material age nor a previous World")
	check(clock.accept_upload(4,10,1,40,1000000,999000,1001000),"first upload accepted")
	var initial: Dictionary = clock.frame(1001000)
	check(initial.snapshot_blend==1.0 and initial.blend_duration_usec==0 \
		and initial.previous.is_empty(),"first accepted upload never blends uninitialized history")
	check(clock.accept_upload(4,11,2,41,1045000,1044000,1048000),"ordinary measured upload accepted")
	var ordinary: Dictionary = clock.frame(1070500)
	check(ordinary.publication_interval_usec==45000 and ordinary.upload_interval_usec==47000 \
		and ordinary.blend_duration_usec==45000,"45ms native delivery supplies its real fade duration")
	check(is_equal_approx(float(ordinary.snapshot_blend),0.5) and ordinary.previous_blend_active,
		"half actual delivery interval produces half blend")
	check(ordinary.material_age_usec==25500 and ordinary.upload_age_usec==22500,
		"publication age and upload age remain distinct and measurable")
	check(ordinary.current.native_tick==41 and ordinary.current.native_completed_usec==1044000 \
		and ordinary.previous.serial==1,"native completion and texture identities survive clock selection")
	ordinary.current.serial = -999
	ordinary.previous.generated_usec = -999
	check(clock.frame(1070500).current.serial==2 and clock.frame(1070500).previous.generated_usec==1000000,
		"returned presentation frame cannot mutate retained upload identities")
	var before_rejection: Dictionary = clock.frame(1070500)
	check(not clock.accept_upload(4,11,2,41,1045000,1044000,1050000),"duplicate upload serial is refused")
	check(not clock.accept_upload(4,12,3,42,1046000,1045000,1047000),"backward upload clock is refused")
	check(clock.frame(1070500)==before_rejection,"refused upload leaves the displayed delivery timeline unchanged")
	check(clock.accept_upload(4,12,3,42,-1,1090000,1093000),"unknown producer timestamp retains valid upload")
	var unknown: Dictionary = clock.frame(1100000)
	check(unknown.timing_source=="upload_interval" and unknown.blend_duration_usec==45000 \
		and unknown.material_age_usec==-1 and unknown.current.native_completed_usec==-1,
		"unknown producer clocks use observed upload interval without fabricated material age")
	check(clock.accept_upload(4,13,4,43,1590000,1589000,1593000),"slow native upload accepted")
	var slow: Dictionary = clock.frame(1643000)
	check(slow.blend_duration_usec==100000 and is_equal_approx(float(slow.snapshot_blend),0.5),
		"500ms native gap uses explicit 100ms upper bound")
	check(clock.accept_upload(4,14,5,44,1593000,1592000,1593500),"batched delivery accepted")
	var batch: Dictionary = clock.frame(1594000)
	check(batch.upload_interval_usec==500 and batch.publication_interval_usec==3000 \
		and batch.blend_duration_usec==1000,"backlogged delivery uses actual upload spacing and 1ms floor")
	var disabled: Dictionary = clock.frame(1593500,false)
	check(disabled.snapshot_blend==1.0 and not disabled.previous_blend_active \
		and disabled.current==batch.current,"smoothing off removes old texture contribution without changing identity")
	check(clock.accept_upload(5,1,1,0,2000000,-1,2005000),"World replacement accepts its own identity")
	var replaced: Dictionary = clock.frame(2005000)
	check(replaced.blend_duration_usec==0 and replaced.snapshot_blend==1.0 \
		and replaced.previous.is_empty(),"old World never crossfades into a replacement")
	check(clock.accept_upload(5,2,2,1,3000000,2999000,2050000),"future producer stamp is treated as unknown")
	var future: Dictionary = clock.frame(2051000)
	check(future.current.generated_usec==-1 and future.current.native_completed_usec==-1 \
		and future.timing_source=="upload_interval","cross-clock timestamps cannot authorize longer history")
	for index: int in range(3,1030):
		clock.accept_upload(5,index,index,index,2100000+index*45000,2099000+index*45000,2101000+index*45000)
	var bounded: Dictionary = clock.frame(50000000)
	check(bounded.current.serial==1029 and bounded.previous.serial==1028 \
		and clock._current.size()==7 and clock._previous.size()==7,
		"more than a thousand uploads retain exactly two fixed-size material identities")
	clock.reset()
	check(clock.frame(50000000)==empty,"reset removes all previous upload ages and history")
	observations.append({"label":"deterministic-timing","ordinary":before_rejection,
		"unknown":unknown,"slow":slow,"batch":batch,"replacement":replaced,"future":future})


func mounted_upload_and_shader() -> bool:
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	root.size = Vector2i(1280,800)
	if not check(await until(func() -> bool:
		return host.shared_workbench!=null and not host.shared_workbench.applied.is_empty()),
		"ordinary Shared Workbench mounts"): return false
	host.paused = true
	host.update_worker_frame_state()
	var ui: Control = host.shared_workbench
	var setup: Dictionary = Setup.fresh(PackedInt32Array(ui.applied.liquid_policy),Vector2i(512,512))
	setup.actors = [Setup.instance("kestrel",1,Vector2(240,300))]
	setup.selected = 1
	setup.next_id = 2
	var epoch: int = host._physical_epoch
	if not check(ui.apply(setup),"ordinary native Workbench recipe accepted"): return false
	if not check(await until(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch>epoch \
			and host.physical_actor_session!=null and host._physical_terrain_ready \
			and host._valid_workbench_mask_frame(host.workbench_display_frame())),
		"real native texture and actor receipt installed"): return false
	host.set_physics_process(false)
	host.set_process(false)
	host.cadence_lod_enabled = true
	# Allow a real delivery gap while the worker and physics stay paused. The
	# next request supplies an ordinary accepted full-refresh publication.
	await create_timer(0.06).timeout
	var old_serial: int = host.last_uploaded_render_snapshot_serial
	host.simulation_worker.request_render_full_refresh()
	if not check(await until(func() -> bool:
		host.consume_worker_snapshot()
		return host.last_uploaded_render_snapshot_serial>old_serial),
		"genuine full-refresh publication reaches successful upload"): return false
	var timing: Dictionary = host.material_presentation_timeline.frame(Time.get_ticks_usec())
	check(not timing.previous.is_empty(),"real full refresh retains a previous accepted upload")
	if timing.previous.is_empty(): return false
	var current: Dictionary = timing.current
	var previous: Dictionary = timing.previous
	check(current.serial==host.last_uploaded_render_snapshot_serial \
		and current.revision==host.last_uploaded_revision and current.generation==host.last_uploaded_world_generation,
		"clock identity equals actually uploaded native material")
	check(current.uploaded_usec==host._cadence_upload.completed_usec \
		and current.generated_usec==host._cadence_upload.generated_usec \
		and current.native_tick==host._cadence_upload.native_tick,
		"clock samples the accepted upload and its exact native publication")
	var delivered: int = int(current.uploaded_usec)-int(previous.uploaded_usec)
	var published: int = int(current.generated_usec)-int(previous.generated_usec)
	var expected: int = clampi(mini(delivered,published) if published>0 else delivered,1000,100000)
	check(timing.upload_interval_usec==delivered and timing.blend_duration_usec==expected,
		"production fade comes from measured delivery intervals")
	var midpoint: int = int(current.uploaded_usec)+int(expected/2)
	host.render_snapshot_hz = 120
	var fast_request: Dictionary = host._material_presentation_state(midpoint)
	host.render_snapshot_hz = 30
	var slow_request: Dictionary = host._material_presentation_state(midpoint)
	check(fast_request==slow_request and fast_request.blend_duration_usec==expected,
		"changing nominal publication Hz cannot change an already selected measured fade")
	host.snapshot_blend_start_usec = int(current.uploaded_usec)
	host.render_snapshot_hz = 60
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","legacy")
	var legacy: Dictionary = host._material_presentation_state(midpoint)
	check(legacy.timing_source=="legacy_requested" and legacy.blend_duration_usec==16666,
		"independent legacy material switch restores requested-period diagnostic")
	check(host.material_presentation_timeline.frame(midpoint).current==current,
		"legacy comparison cannot rewrite accepted upload timing")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","measured")
	host._present_physical_actor_overlay(host.workbench_display_frame())
	var resolved: Dictionary = host.workbench_presentation_frame
	check(resolved.material_timing.current==current \
		and resolved.snapshot_blend==resolved.material_timing.snapshot_blend \
		and resolved.previous_blend_active==resolved.material_timing.previous_blend_active,
		"actor safety receives the same immutable material timing decision")
	check(is_equal_approx(float(host.world_shader.get_shader_parameter("snapshot_blend")),float(resolved.snapshot_blend)),
		"terrain shader consumes the exact already selected graphical-frame blend")
	observations.append({"label":"actual-native-upload","timing":timing,
		"requested120":fast_request,"requested30":slow_request,"legacy":legacy,
		"resolved_blend":resolved.snapshot_blend})
	return true


func fixed_input_authority_control() -> void:
	# One real physical trajectory, with both presentation modes interleaved
	# between its completed steps. This fixes native inputs and body state by
	# construction instead of comparing asynchronous contact schedules.
	var session = host.physical_actor_session
	var bridge = session.bridge
	var material: PackedByteArray = host.image.get_data()
	var native_state: Dictionary = host.simulation_worker.paint_state()
	host.paused = false # worker remains paused; no update_worker_frame_state.
	session.set_suspended(false)
	for index: int in range(6):
		session.advance(bridge.fixed_delta())
		bridge.step()
		session.complete_step()
		var physical_tick: int = session.tick
		var pose: Transform2D = bridge.body_transform(0)
		var velocity: Vector2 = bridge.body_linear_velocity(0)
		var angular: float = PhysicsServer2D.body_get_state(bridge._body_rids[0],PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
		var authoritative_history: Variant = bridge._history.duplicate(true)
		for mode: String in ["legacy","coherent"]:
			OS.set_environment("CYBERSAND_DIAG_PRESENTATION","legacy" if mode=="legacy" else "coherent")
			OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","legacy" if mode=="legacy" else "measured")
			for draw: int in range(3):
				host._present_physical_actor_overlay(host.workbench_display_frame())
				check(session.tick==physical_tick and bridge.body_transform(0)==pose \
					and bridge.body_linear_velocity(0)==velocity \
					and PhysicsServer2D.body_get_state(bridge._body_rids[0],PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)==angular,
					"draw policy "+mode+" leaves exact Rapier state unchanged at step "+str(index)+" draw "+str(draw))
				check(bridge._history==authoritative_history,
					"draw policy "+mode+" cannot rewrite native wrench authority history")
	check(host.image.get_data()==material,"all original/coherent draws preserve material bytes")
	var after_native: Dictionary = host.simulation_worker.paint_state()
	check(after_native.generation==native_state.generation and after_native.revision==native_state.revision \
		and after_native.tick==native_state.tick,"all draw policies preserve actual native World identity and tick")
	observations.append({"label":"fixed-input-authority","completed_steps":6,"draws_per_mode_per_step":3,
		"modes":["legacy","coherent"],"native_generation":native_state.generation,
		"native_revision":native_state.revision,"native_tick":native_state.tick})
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	OS.set_environment("CYBERSAND_DIAG_MATERIAL_TIMING","measured")
	host.paused = true
	host.update_worker_frame_state()


func _run() -> void:
	deterministic_clock_cases()
	if await mounted_upload_and_shader(): fixed_input_authority_control()
	var result: Dictionary = {"schema":"workbench-material-delivery-timing-v1","checks":checks,"failures":failures,
		"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"engine":Engine.get_version_info().string,
		"platform":OS.get_name(),"observations":observations,"physical_gpu_acceptance":"pending_owner"}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var writer: FileAccess = FileAccess.open(output.path_join("material-timing.json"),FileAccess.WRITE)
		if check(writer!=null,"timing evidence file opens"):
			writer.store_string(JSON.stringify(result,"  ")+"\n")
			writer.close()
	for key: String in saved_environment: OS.set_environment(key,str(saved_environment[key]))
	if host!=null:
		host.queue_free()
		await process_frame
		await process_frame
	print("MATERIAL_DELIVERY_TIMING_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"observations":observations.size()}))
	quit(int(not failures.is_empty()))
