extends SceneTree

# Actual Main/Workbench and exclusive native worker qualification. The write
# and reopen modes must run in separate OS processes with the same isolated
# --persistent-profile path. Headless execution never claims graphical PASS.
const PersistentScene = preload("res://persistent_areas.tscn")
const Fixtures = preload("res://scripts/persistent_area_fixtures.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const AreaClock = preload("res://scripts/persistent_area_clock.gd")
var host: Control
var controller: Node
var bench: Control
var worker: RefCounted
var mode := "write"
var output := ""
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var captures: Array[String] = []
var graphical := false
var expected: Dictionary = {}
var _initial_tick := 0
var _initial_clock := 0
var crash_phase := "source_durable"
var crash_boundary_seen := false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--persistent-test-mode="): mode = argument.trim_prefix("--persistent-test-mode=")
		if argument.begins_with("--persistent-evidence="): output = argument.trim_prefix("--persistent-evidence=")
		if argument.begins_with("--persistent-crash-phase="): crash_phase = argument.trim_prefix("--persistent-crash-phase=")
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--persistent-test-workers="):
			ProjectSettings.set_setting("cybersand/native_worker_threads",int(argument.trim_prefix("--persistent-test-workers=")))
	run.call_deferred()


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PERSISTENT_AREAS_WORKBENCH: "+label)
	return ok


func until(predicate: Callable, label: String, timeout_msec: int = 90000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_msec
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(predicate.call(),label+(" / "+str(controller.message) if controller != null else ""))


func settled() -> bool:
	return controller != null and controller.active_ready and not controller.busy \
		and host.pending_microscenario_apply.is_empty() and not bench.busy() \
		and not worker.paint_state().get("busy",false)


func operation_finished(label: String) -> bool:
	if not await until(func() -> bool: return not controller.busy,label): return false
	return check(controller.active_ready and controller.last_result.get("ok",false),
		label+" has a positive acknowledged result / "+str(controller.last_result.get("error","")))


func run() -> void:
	graphical = DisplayServer.get_name() != "headless"
	phase("starting "+mode)
	if not check(mode in ["write","reopen","crash","faults","exit_fault"],"known qualification mode"):
		await _finish()
		return
	if not check(not output.is_empty(),"explicit evidence directory required"):
		await _finish()
		return
	DirAccess.make_dir_recursive_absolute(output)
	if "--persistent-require-graphics" in OS.get_cmdline_user_args() \
		and not check(graphical,"graphical execution requires a real display"):
		await _finish()
		return
	if not check("--persistent-start-paused" in OS.get_cmdline_user_args(),"qualification starts paused for exact time/hash comparisons"):
		await _finish()
		return
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	host = PersistentScene.instantiate()
	configure_host()
	root.add_child(host)
	current_scene = host
	controller = host.persistent_areas
	controller.qualification_resource_hook = func(sample: Dictionary) -> void:
		print("GEN006_RETAINED_AREAS_RESOURCE ",JSON.stringify(sample))
	bench = host.shared_workbench
	worker = host.simulation_worker
	if not await until(func() -> bool: return controller.active_ready or (not controller.busy and not controller.message.is_empty()),
		"persistent profile reaches a terminal startup state",180000):
		await _finish()
		return
	if not check(controller.active_ready,"real native three-area bootstrap/restore: "+str(controller.message)):
		await _finish()
		return
	if not await until(settled,"native Workbench settled"):
		await _finish()
		return
	check(host.paused,"qualification begins with the native area paused")
	check(host.world_extent == Vector2i(512,512),"actual installed native extent is 512 by 512")
	check(controller.manifest.areas.keys().size()==3 and controller.manifest.areas.has_all(["a","b","c"]),
		"three independent durable native checkpoints exist")
	check(host.physical_actor_session == null or host.physical_actor_session.bodies().is_empty(),
		"editor traveller owns no hidden retained actor")
	check(not bool(host.tower_context.get("wave_flow",{}).get("enabled",false)),"actual profile uses supported Current Water rather than Wave")
	var audition: Dictionary = worker.material_audition_state()
	var refused: Dictionary = worker.material_audition_request({
		"session_id":str(audition.session_id),"world_id":"0","expected_revision":0,
		"profile":{"schema_version":1,"profile_id":"persistent-refusal","materials":[],"reactions":[]}})
	check(not audition.get("ok",false) and not refused.get("accepted",false)
		and refused.get("code")=="owner_unavailable" and "default material laws" in str(refused.get("error","")),
		"persistent native owner refuses live audition before durable capture or resident travel")
	_initial_tick = int(host.latest_snapshot.tick_index)
	_initial_clock = int(controller.clock.game_ticks)
	phase("layout at 720p and 1080p")
	await layout_checks()
	await screenshot("initial-"+mode)
	match mode:
		"write": await exercise_write()
		"reopen": await exercise_reopen()
		"crash": await tagged_qualification("forced_transition_crash",exercise_crash)
		"faults": await tagged_qualification("publication_faults",publication_fault_checks)
		"exit_fault": await tagged_qualification("failed_normal_exit_save",exit_fault_checks)
	await _finish()


func configure_host() -> void:
	pass


func exercise_write() -> void:
	phase("native fire baseline and active progression")
	if not check(controller.active_area == "a" and int(controller.clock.game_ticks)==0,
		"fresh isolated profile starts in A at game tick zero"): return
	var before_fire := await native_materials(Rect2i(0,0,512,512))
	if before_fire.is_empty(): return
	var count_before := counts(before_fire.materials)
	check(count_before.get(Setup.FIRE,0)>0 and count_before.get(Setup.WOOD,0)>0 and count_before.get(Setup.OIL,0)>0,
		"Area A actually installs authored Fire, Wood and Oil native cells")
	# One ordinary Main run demonstrates active native progression; it is not
	# productive throughput inferred from waiting elapsed time.
	phase("active simulation Play requested")
	if not check(bench.toggle_pause(),"ordinary Workbench Play starts real native progression"): return
	var tick0 := int(host.latest_snapshot.tick_index)
	if not await until(func() -> bool: return int(host.latest_snapshot.tick_index)>=tick0+48,"Area A completes 48 actual native ticks"): return
	check(bench.toggle_pause(),"ordinary Workbench Pause remains available")
	phase("active simulation Pause requested")
	if not await save_current("A active progression checkpoint"): return
	var after_fire := await native_materials(Rect2i(0,0,512,512))
	if after_fire.is_empty(): return
	var count_after := counts(after_fire.materials)
	check(material_digest(before_fire.materials) != material_digest(after_fire.materials),
		"native fire/reaction/motion changes material cells while Area A is active")
	check(int(controller.clock.game_ticks)>0 and int(controller.clock.areas.a.native_ticks)==int(controller.clock.game_ticks),
		"completed active native ticks advance the global and A accounted frontiers together")
	samples.append({"area":"a","kind":"active_native_progression","before":count_before,"after":count_after,
		"completed_tick":controller.clock.areas.a.native_ticks,"physical_hash":controller.manifest.areas.a.physical_hash})
	if not await edit_area("a"): return
	var a_before: Dictionary = controller.manifest.areas.a.duplicate(true)
	if not await travel("b"): return
	var b_before := await native_materials(Rect2i(0,0,512,512))
	if b_before.is_empty(): return
	check(counts(b_before.materials).get(Setup.WATER,0)>0 and counts(b_before.materials).get(Setup.SAND,0)>0,
		"Area B contains actual native Water and Sand")
	if not await edit_area("b"): return
	phase("bounded catch-up operation starts")
	if not check(controller.request_ahead(60),"bounded native Simulate Ahead admitted in B"): return
	check(not controller.request_travel("c"),"re-entry during outstanding catch-up is refused")
	if not await operation_finished("B Simulate Ahead"): return
	phase("bounded catch-up operation completed")
	check(int(controller.operation.completed_ticks)>0,"Simulate Ahead reports actual completed native ticks")
	var b_after := await native_materials(Rect2i(0,0,512,512))
	if b_after.is_empty(): return
	check(material_digest(b_before.materials)!=material_digest(b_after.materials),"native Water/Sand placement changes during B progression")
	samples.append({"area":"b","kind":"bounded_native_progression","before":counts(b_before.materials),
		"after":counts(b_after.materials),"completed_ticks":controller.operation.completed_ticks,
		"physical_hash":controller.manifest.areas.b.physical_hash})
	phase("five-second Simulate Ahead preset and real control")
	var preset_game_before := int(controller.clock.game_ticks)
	if graphical:
		controller.panel._preset.select(0)
		if not check(controller.panel._preset.get_selected_id()==5,"visible Simulate Ahead preset selects five seconds"): return
		if not await click(controller.panel._ahead): return
	else:
		if not check(controller.request_ahead(300),"five-second Simulate Ahead duration admitted"): return
	if not await operation_finished("five-second Simulate Ahead control"): return
	var preset_completed := int(controller.operation.completed_ticks)
	check(preset_completed>0 and preset_completed<=300,"five-second control reports bounded actual native completion")
	check(int(controller.clock.game_ticks)-preset_game_before==preset_completed \
		and int(controller.operation.remaining_future_ticks)==300-preset_completed,
		"preset advances only actual future ticks and explicitly reports the remainder")
	if not await travel("c"): return
	if not await edit_area("c"): return
	check(await native_cell(Vector2i(252,312))==Setup.GLASS,"Area C's glass tower proves distinct actual installed identity")
	if not await travel("a"): return
	check(int(controller.manifest.areas.a.completed_tick)>int(a_before.completed_tick),
		"returning to A executes genuine native catch-up from its retained tick")
	check(controller.manifest.areas.a.physical_hash != a_before.physical_hash,
		"returning to the fire produces progressed full native physical state")
	if not await verify_edits("a"): return
	# Travel has a finite native work budget. A loaded machine may leave
	# legitimate debt even though the retained interval was accounted once.
	# Establish zero debt through actual completed work before testing replay.
	for attempt: int in 16:
		var debt_before := AreaClock.debt(controller.clock,"a")
		if debt_before==0: break
		var game_before := int(controller.clock.game_ticks)
		var native_before := int(controller.clock.areas.a.native_ticks)
		if not check(controller.request_catch_up(),"remaining travel debt is explicitly admitted"): return
		if not await operation_finished("bounded remaining travel debt %d" % attempt): return
		var completed := int(controller.operation.completed_ticks)
		if not check(completed>0 and completed<=debt_before \
			and int(controller.clock.game_ticks)==game_before \
			and int(controller.clock.areas.a.native_ticks)==native_before+completed \
			and AreaClock.debt(controller.clock,"a")==debt_before-completed,
			"remaining catch-up accounts only actual native ticks and never advances global time"): return
	if not check(AreaClock.debt(controller.clock,"a")==0,"finite repeated catch-up reaches the current global frontier"): return
	check(not controller.request_catch_up(),"an already accounted interval is not advanced twice")
	# Repeated Ahead commits distinct future intervals. A cancellation has a
	# bounded actual result and never credits unperformed requested duration.
	for repeat: int in 2:
		var game_before := int(controller.clock.game_ticks)
		if not check(controller.request_ahead(12),"repeatable Ahead request %d" % repeat): return
		if not await operation_finished("repeated Ahead %d" % repeat): return
		check(int(controller.clock.game_ticks)-game_before == int(controller.operation.completed_ticks),
			"only actual completed future ticks advance game time once")
	var cancellation_before := int(controller.clock.game_ticks)
	if not check(controller.request_ahead(7200),"long finite Ahead request is bounded"): return
	check(not controller.request_travel("b"),"rapid switch cannot replace the ongoing operation")
	if await until(func() -> bool: return controller.lifecycle=="Catching up" or not controller.busy,"catch-up progress becomes visible"):
		if controller.busy:
			if graphical: await click(controller.panel._cancel)
			else: controller.request_cancel()
	if not await operation_finished("cancelled Ahead safely completes its boundary"): return
	check(int(controller.operation.completed_ticks)<=controller.MAX_OPERATION_TICKS,
		"cancellation and work cap bound native ticks")
	check(int(controller.clock.game_ticks)-cancellation_before==int(controller.operation.completed_ticks),
		"cancelled Ahead credits exactly the native ticks durably committed")
	check(int(controller.operation.remaining_future_ticks)>=7200-controller.MAX_OPERATION_TICKS,
		"unperformed future time remains visible instead of being called simulated")
	await tagged_qualification("refusal_controls",rejection_checks)
	await tagged_qualification("publication_faults",publication_fault_checks)
	# Pay each area's bounded debt while paused so every durable frontier is
	# equal before exact independent-process continuation comparisons.
	for id: String in ["b","c","a"]:
		if not await travel(id): return
		while AreaClock.debt(controller.clock,id)>0:
			if not check(controller.request_catch_up(),"remaining debt retry admitted"): return
			if not await operation_finished("bounded remaining debt paid"): return
		if not await verify_edits(id): return
	if not await save_current("final all-area checkpoint"): return
	expected = {"version":1,"session_id":controller.manifest.session_id,"clock":controller.clock.duplicate(true),"areas":{}}
	for id: String in Fixtures.IDS:
		var record: Dictionary = controller.manifest.areas[id]
		expected.areas[id] = {"physical_hash":record.physical_hash,"native_sha256":record.native_sha256,
			"completed_tick":record.completed_tick,"authored_source_sha256":record.authored_source_sha256}
	write_json(output.path_join("expected-reopen.json"),expected)
	await screenshot("write-final")


func exercise_reopen() -> void:
	phase("independent-process exact continuation")
	var text := FileAccess.get_file_as_string(output.path_join("expected-reopen.json"))
	var parsed: Variant = JSON.parse_string(text)
	if not check(parsed is Dictionary,"independent-process expectation file exists"): return
	expected = parsed
	check(controller.manifest.session_id==expected.session_id,"fresh process retains the exact profile/session identity")
	check(AreaClock.canonical(controller.clock)==AreaClock.canonical(expected.clock),
		"fresh process retains every area's game-time frontier without a reset or wall-clock advancement")
	for id: String in Fixtures.IDS:
		var record: Dictionary = controller.manifest.areas[id]
		check(record.physical_hash==expected.areas[id].physical_hash and record.native_sha256==expected.areas[id].native_sha256,
			"fresh process validates %s's complete retained native identity" % id)
	for id: String in ["a","b","c","a"]:
		if id != controller.active_area and not await travel(id): return
		if not await verify_edits(id): return
		if not await save_current("reopened "+id+" checkpoint"): return
		check(controller.manifest.areas[id].physical_hash==expected.areas[id].physical_hash,
			"actual restored %s World preserves full physical identity at zero catch-up debt" % id)
		check(int(controller.clock.areas[id].native_ticks)==int(expected.areas[id].completed_tick),
			"reopening %s does not repeat an already simulated interval" % id)
	check(AreaClock.canonical(controller.clock)==AreaClock.canonical(expected.clock),
		"A to B to C to A reopening leaves completed game time unchanged while paused")
	await screenshot("reopen-final")


func exercise_crash() -> void:
	phase("external crash boundary "+crash_phase)
	if not check(FileAccess.file_exists(output.path_join("expected-reopen.json")),"crash mode requires a previously qualified durable profile"): return
	if not check(crash_phase in ["source_durable","candidate_durable"],"declared durable crash boundary"): return
	# The external qualification harness kills this real process after the
	# marker, then starts a genuinely new process. No graceful exit callback
	# runs. The product path has no callback or artificial delay.
	controller.qualification_boundary_hook = func(phase: String, receipt: Dictionary) -> int:
		if phase != crash_phase: return 0
		crash_boundary_seen = true
		receipt["pid"] = OS.get_process_id()
		receipt["mechanism"] = "external process termination after actual durable checkpoint; no graceful exit"
		write_json(output.path_join("crash-receipt-"+phase+".json"),receipt)
		print("GEN006_TRANSITION_CRASH_READY ",JSON.stringify({"pid":OS.get_process_id(),"phase":phase,
			"revision":receipt.revision,"operation_id":receipt.operation_id}))
		return 5000
	check(controller.request_travel("b" if controller.active_area != "b" else "c"),"transition admitted before abrupt termination")
	if not await until(func() -> bool: return crash_boundary_seen or not controller.busy,"actual durable crash boundary reached"): return
	await until(func() -> bool: return not controller.busy,"external crash harness terminates during its bounded hold",15000)
	check(false,"external crash harness did not terminate the application at its durable boundary")


func edit_area(id: String) -> bool:
	phase("destructive and constructive native edits in "+id)
	var fixture := Fixtures.description(id)
	var erased := Vector2i(fixture.empty_edit[0],fixture.empty_edit[1])
	var painted := Vector2i(fixture.paint_edit[0],fixture.paint_edit[1])
	# A real material mutation at a fixed site remains easy to distinguish
	# from original seed data, including where dynamic material later moves.
	if not check(bench.paint(erased,0),"native destructive Empty edit admitted in "+id): return false
	if not await until(func() -> bool: return not worker.paint_state().get("legacy_busy",false),"Empty edit drains in "+id): return false
	if not check(bench.paint(painted,Setup.WALL),"native persistent Wall mark admitted in "+id): return false
	if not await until(func() -> bool: return not worker.paint_state().get("legacy_busy",false),"Wall mark drains in "+id): return false
	if not await save_current("edited "+id+" captured"): return false
	return await verify_edits(id)


func verify_edits(id: String) -> bool:
	var fixture := Fixtures.description(id)
	var erased := Vector2i(fixture.empty_edit[0],fixture.empty_edit[1])
	var painted := Vector2i(fixture.paint_edit[0],fixture.paint_edit[1])
	# Fire can legitimately pass through the destructively edited A region,
	# and Water through the erased B gate. The persistent edit's obligation is
	# that authored Wood does not resurrect, not that all future air is frozen.
	var erased_material: int = await native_cell(erased)
	var marker_material: int = await native_cell(painted)
	return check(erased_material != Setup.WOOD,"destroyed authored material does not resurrect in "+id) \
		and check(marker_material==Setup.WALL,"independent native material mark survives in "+id)


func rejection_checks() -> void:
	phase("unsupported dependencies and native refusal atomicity")
	var generation := int(worker.paint_state().generation)
	var before: Dictionary = bench.applied.duplicate(true)
	var actor_configuration: Button
	for button: Node in bench.find_children("*","Button",true,false):
		if button.text == "Configuration…":
			actor_configuration = button
			break
	check(is_instance_valid(actor_configuration) and actor_configuration.disabled,
		"the actor-free profile disables the installed Configuration button")
	bench.open_actor_composition()
	check(not is_instance_valid(bench._actor_panel) or not bench._actor_panel.visible,
		"the actor-only inspector cannot open through a direct activation")
	if is_instance_valid(bench._actor_panel): bench._actor_panel.hide()
	bench.actor_interaction.set_mode("grab")
	check(bench.actor_interaction.mode() == "paint",
		"a disabled actor tool cannot divert the persistent painting pointer")
	bench.actor_interaction.set_mode("paint")
	var with_actor := before.duplicate(true)
	with_actor.actors = [Setup.instance(Setup.BARREL,1,Vector2(400,80))]
	with_actor.next_id = 2
	check(not bench.apply(with_actor),"unsupported retained actor creation is explicitly refused in this profile")
	check(not bench.load_ambient_example("ambient-settlement"),
		"switching to an eight-inhabitant scene requires the ordinary Workbench")
	# Between agent turns the native worker can be idle although a controller
	# still owns a future mutation. Exercise this gap before taking a snapshot.
	var art: Window = bench._ensure_art_batches()
	art.remaining_turns = 1
	check(not controller.request_travel("b") and not controller.busy,
		"outstanding Art turn refuses travel before a resident handoff")
	art.remaining_turns = 0
	bench.open_architecture_lab()
	var architecture: Window = bench.architecture_lab
	architecture.workflow._action = true
	check(not controller.request_save() and not controller.busy,
		"pending Architecture action refuses a snapshot between native stages")
	architecture.workflow._action = false
	architecture.hide()
	check(not host.workbench_source(Vector2i(60,60),Setup.SAND,"configure"),"unsupported host emitter is refused before creation")
	check(not controller.request_travel("unknown"),"incorrect area identity is refused")
	check(not controller.request_ahead(-1),"invalid future duration is refused")
	check(bench.applied==before and int(worker.paint_state().generation)==generation,
		"refused actor/emitter/identity requests retain the old World and authored state")
	if not await save_current("negative-control old World remains capturable"): return
	await native_refusal_retains_world()
	var game_before := int(controller.clock.game_ticks)
	check(controller.request_travel("b"),"cancellable travel admitted")
	controller.request_cancel()
	check(not controller.request_travel("c"),"second rapid area switch is refused while travel is outstanding")
	if not await operation_finished("cancelled travel retires safely"): return
	check(controller.active_area=="a" and int(controller.clock.game_ticks)==game_before,
		"cancelled travel retains the original area and does not create game time")


func native_refusal_retains_world() -> void:
	# Use the real owner lease and normal Main installation path. The payload
	# checksum remains correct, so this reaches the native full-state identity
	# refusal rather than merely failing host JSON/shape admission.
	controller._begin("native_refusal","a")
	var captured: Dictionary = await controller._capture_live()
	if not check(captured.get("ok",false),"native refusal fixture captures its actual old World"):
		await controller._fail(str(captured.get("error","capture failed")))
		return
	var authoring: Dictionary = host.persistent_authoring_state()
	var malformed: Dictionary = captured.result.capsule.duplicate(true)
	malformed.physical_hash = "0000000000000000" if malformed.physical_hash!="0000000000000000" else "1111111111111111"
	var generation := int(worker.paint_state().generation)
	var identity := {"session_id":controller.manifest.session_id,"area_id":"a",
		"generation":int(controller.manifest.areas.a.generation)+1,"operation_id":controller.operation.operation_id}
	check(host.persistent_install_area(authoring,malformed,identity,true),"malformed continuation reaches actual native preparation")
	if await until(func() -> bool: return host.pending_microscenario_apply.is_empty(),"native continuation identity refusal acknowledged"):
		check(not host.microscenario_error.is_empty(),"native refusal is visible to the host")
		var state: Dictionary = await controller._worker({"kind":"status","operation_id":controller.operation.operation_id})
		check(state.get("ok",false) and not state.result.get("prepared",false),"invalid candidate is not retained for commit")
		check(int(worker.paint_state().generation)==generation and state.result.owner_fence.physical_hash==captured.result.capsule.physical_hash,
			"native refusal preserves the old live World generation and complete physical identity")
		check(host.persistent_authoring_state()==authoring,"native refusal preserves the complete old authoring envelope")
	await controller._finish("Native refusal negative control retained the old World.")


func save_current(label: String) -> bool:
	phase(label)
	if not check(controller.request_save(),label+" request"): return false
	return await operation_finished(label)


func travel(id: String) -> bool:
	phase("travel to "+id)
	if not await until(settled,"before travel to "+id): return false
	if graphical:
		if not await click(controller.panel._area_buttons[id]): return false
	else:
		if not check(controller.request_travel(id),"travel request to "+id): return false
	if not await operation_finished("native travel to "+id): return false
	check(controller.active_area==id and host.world_extent==Vector2i(512,512),"actual acknowledged selected area "+id)
	if not await travel_profile_inventory(id): return false
	await screenshot("area-"+id+"-"+str(controller.manifest.revision))
	return true


func travel_profile_inventory(area_id: String) -> bool:
	# Qualification-only, after the acknowledged transition has ended. This
	# read-only bounded native inventory is excluded from its travel latency.
	var inventory: Dictionary = await controller._io("_qualification_inventory",[])
	if not check(inventory.get("ok",false),"bounded profile inventory after travel to "+area_id): return false
	var checkpoint_count := 0
	var checkpoint_bytes := 0
	for file: Dictionary in inventory.get("files",[]):
		if str(file.name).ends_with(".cypa"):
			checkpoint_count += 1
			checkpoint_bytes += int(file.bytes)
	var sample := {"kind":"travel_profile_inventory","process_id":OS.get_process_id(),
		"area_id":area_id,"operation_id":controller.operation.operation_id,
		"revision":int(controller.manifest.revision),"game_tick":int(controller.clock.game_ticks),
		"accounted_tick":int(controller.clock.areas[area_id].accounted_ticks),
		"debt_ticks":AreaClock.debt(controller.clock,area_id),
		"profile_bytes":int(inventory.get("bytes",0)),"profile_file_count":inventory.get("files",[]).size(),
		"checkpoint_files":checkpoint_count,"checkpoint_bytes":checkpoint_bytes,
		"files":inventory.get("files",[]).duplicate(true)}
	samples.append(sample)
	print("GEN006_TRAVEL_PROFILE_INVENTORY ",JSON.stringify(sample))
	return true


func native_materials(region: Rect2i) -> Dictionary:
	if region.size.x>1: phase("native material readback "+str(region))
	if not await until(settled,"native stored-material readback boundary"): return {}
	var source: Dictionary = worker.paint_state()
	var admission: Dictionary = worker.paint_queue({"kind":"capture","region":region,
		"expected_generation":int(source.generation),"expected_revision":int(source.revision),"expected_tick":int(source.tick),
		"expected_authoring_generation":int(source.authoring_generation)})
	if not check(admission.get("status","")=="queued","actual native stored-cell readback admitted: "+str(admission.get("reason",""))): return {}
	if not await until(func() -> bool: return worker.paint_state().receipt_ready,"stored-cell readback completes"): return {}
	var receipt: Dictionary = worker.paint_take_result()
	if not check(receipt.get("status","")=="completed" and receipt.get("materials",PackedInt32Array()).size()==region.get_area(),
		"complete native stored material identities returned"): return {}
	return receipt


func native_cell(point: Vector2i) -> int:
	var receipt := await native_materials(Rect2i(point,Vector2i.ONE))
	return int(receipt.materials[0]) if not receipt.is_empty() else -1


func counts(materials: Variant) -> Dictionary:
	var result := {}
	for material: int in materials: result[material] = int(result.get(material,0))+1
	return result


func material_digest(materials: Variant) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(materials))
	return hash.finish().hex_encode()


func layout_checks() -> void:
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		for frame: int in 4: await process_frame
		check(controller.panel.controls_visible_in_viewport(),"area controls fit "+str(size))
		controller.panel._open_details()
		for frame: int in 3: await process_frame
		var dialog: AcceptDialog = controller.panel._details
		check(dialog.visible and dialog.size.x<=size.x and dialog.size.y<=size.y,
			"bounded state/limits dialog fits "+str(size))
		check(dialog.get_ok_button().get_global_rect().end.y<=dialog.size.y,
			"essential dialog Close action remains reachable")
		await screenshot("layout-"+str(size.x)+"x"+str(size.y))
		dialog.hide()
	root.size = Vector2i(1280,720)
	for frame: int in 4: await process_frame


func click(control: Button) -> bool:
	if not check(control != null and control.is_visible_in_tree() and not control.disabled,"visible enabled real area control"): return false
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	var pressed := [false]
	control.pressed.connect(func() -> void: pressed[0] = true,CONNECT_ONE_SHOT)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await process_frame
	return check(pressed[0],"actual mouse event reaches "+control.text)


func screenshot(label: String) -> void:
	if not graphical: return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not check(image != null and not image.is_empty(),"actual graphical framebuffer captured"): return
	var path := output.path_join(label+".png")
	if check(image.save_png(path)==OK,"framebuffer evidence saved"): captures.append(path)


func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if check(file != null,"evidence file opens: "+path):
		file.store_string(JSON.stringify(value,"\t",true))
		file.close()


func tagged_qualification(tag: String, action: Callable) -> void:
	var previous: String = controller.qualification_measurement_tag
	controller.qualification_measurement_tag = tag
	await action.call()
	controller.qualification_measurement_tag = previous


func phase(label: String) -> void:
	print("PERSISTENT_AREAS_TEST_PHASE ",JSON.stringify({"mode":mode,"phase":label,"msec":Time.get_ticks_msec()}))


func exit_fault_checks() -> void:
	phase("failure of real native Save during normal Save & Menu exit")
	if not await until(settled,"ready before normal Save & Menu failure"): return
	var revision := int(controller.manifest.revision)
	var durable_clock: Dictionary = controller.clock.duplicate(true)
	var active_id: String = str(controller.active_area)
	var native_tick := int(worker.paint_state().tick)
	var durable_hash: String = controller.manifest.areas[active_id].physical_hash
	if not check(not controller._io_busy and not controller.busy,
			"native Save & Menu fault starts with idle owner and storage"): return
	controller._store.set_test_fault("before_publish")
	if not check(controller.request_exit("launcher"),"Save & Menu attempts real durable publication"): return
	if not await until(func() -> bool: return not controller.busy,
			"actual Save & Menu publication failure reaches terminal acknowledgement"): return
	if not check(not controller.last_result.get("ok",true) and controller.active_ready
			and not controller._quarantined and current_scene==host
			and controller.active_area==active_id,
			"failed Save & Menu preserves same live native World, stays in editor and refuses exit"): return
	if not check(int(controller.manifest.revision)==revision
			and controller.clock==durable_clock
			and int(worker.paint_state().tick)==native_tick
			and controller.manifest.areas[active_id].physical_hash==durable_hash,
			"failed Save & Menu retains durable generation, live native tick and full clock"): return
	# Actual native read after failed Exit, not a self-reported UI status.
	if not check((await native_materials(Rect2i(0,0,512,512))).has("materials"),
			"same native World remains readable and editable after failed exit"): return
	if not await save_current("healthy real Save after failed normal exit"): return
	check(int(controller.manifest.revision)>revision and controller.active_ready
		and int(worker.paint_state().tick)==native_tick
		and controller.manifest.areas[active_id].physical_hash==durable_hash,
		"successful retry durably acknowledges the original retained native authority")
	# Normal scene-exit is exercised by _finish() after this method returns.


func publication_fault_checks() -> void:
	phase("unpublished checkpoint failure and retry")
	if not await until(settled,"before publication fault cases"): return
	var revision := int(controller.manifest.revision)
	var original_clock: Dictionary = controller.clock.duplicate(true)
	var original_hash: String = controller.manifest.areas[controller.active_area].physical_hash
	# Qualification-only configuration, at a point with no I/O outstanding.
	# This mutates no native World and uses the real file publication path.
	check(not controller._io_busy,"Store fault configured only with no concurrent I/O")
	controller._store.set_test_fault("before_publish")
	if not check(controller.request_save(),"pre-publication failure request admitted"): return
	if not await until(func() -> bool: return not controller.busy,"pre-publication failure returns"): return
	check(not controller.last_result.get("ok",true) and controller.active_ready and not controller._quarantined,
		"definitely unpublished checkpoint failure retains an active, retryable old World")
	check(int(controller.manifest.revision)==revision and controller.clock==original_clock,
		"failed unpublished checkpoint does not advance durable generation or game time")
	if not await save_current("retry after unpublished checkpoint failure"): return
	check(controller.manifest.areas[controller.active_area].physical_hash==original_hash,
		"retry after unpublished failure captures the same paused native state")
	phase("lost acknowledgement after Ahead candidate publication")
	var game_before := int(controller.clock.game_ticks)
	var native_before := int(controller.clock.areas[controller.active_area].native_ticks)
	var injected := [false]
	controller.qualification_boundary_hook = func(boundary: String, _receipt: Dictionary) -> int:
		if boundary == "source_durable" and not injected[0]:
			# Source checkpoint already succeeded. The next publication is the
			# privately advanced same-area candidate, before native adoption.
			check(not controller._io_busy,"candidate lost-ACK fault is serialized after source I/O")
			controller._store.set_test_fault("after_publish")
			injected[0] = true
		return 0
	if not check(controller.request_ahead(12),"Ahead lost-ACK request admitted"): return
	if not await until(func() -> bool: return not controller.busy,"lost publication acknowledgement reaches visible quarantine"): return
	controller.qualification_boundary_hook = Callable()
	var actual := int(controller.operation.completed_ticks)
	check(injected[0] and actual>0,"actual private native progression reached the injected publication boundary")
	check(not controller.active_ready and controller._quarantined and controller._publication_uncertain \
		and controller._force_profile_reopen and host.paused,
		"ambiguous publication keeps the old live World paused and requires profile reopening")
	# COLD donor Ahead prepares an unadopted private candidate; its live source
	# must remain at the old frontier. RAMCACHE resident Ahead advances the
	# existing native owner *before* the failed durable ACK. All genuinely
	# completed ticks MUST remain accounted, even while publication is
	# quarantined and the older durable manifest is independently reconciled.
	if controller._cache_open and controller._cache_configuration.enabled:
		check(int(worker.paint_state().tick)==native_before+actual
			and int(controller.clock.game_ticks)==game_before+actual
			and int(controller.operation.native_ticks_executed)==actual,
			"failed ACK retains exactly once all completed resident native ticks and their game-time debt")
	else:
		check(int(worker.paint_state().tick)==native_before
			and int(controller.clock.game_ticks)==game_before,
			"unadopted private candidate failed ACK leaves the original live World and clock unchanged")
	var published: Dictionary = await controller._io("current_manifest",[])
	if not check(published.has("areas") and int(published.clock.game_ticks)==game_before+actual,
		"lost ACK fixture actually published the advanced checkpoint and matching accounted time"): return
	var published_hash: String = published.areas[controller.active_area].physical_hash
	check(not controller.request_ahead(12),"quarantine refuses new advancement against the older incarnation")
	if not check(controller.request_retry(),"explicit Retry closes and reopens the uncertain profile"): return
	if not await operation_finished("uncertain publication profile reopened and restored"): return
	check(int(controller.clock.game_ticks)==game_before+actual \
		and int(worker.paint_state().tick)==native_before+actual,
		"fresh manifest adoption restores actual completed time exactly once")
	check(controller.manifest.areas[controller.active_area].physical_hash==published_hash,
		"retry restores the actual published native continuation, not the older source or seed")
	check(not controller._publication_uncertain and not controller._force_profile_reopen,
		"successful validated reopening retires the ambiguity")
	samples.append({"kind":"publication_fault_recovery","before_game_tick":game_before,"actual_native_ticks":actual,
		"restored_game_tick":controller.clock.game_ticks,"physical_hash":published_hash})


func _finish() -> void:
	var retained_evidence: Dictionary = controller.evidence() if controller != null else {}
	if controller != null:
		if controller.busy:
			controller.request_cancel()
			await until(func() -> bool: return not controller.busy,"cleanup operation settles",30000)
		if not controller.busy:
			if check(controller.request_exit("launcher"),"durable scene exit admitted"):
				await until(func() -> bool: return current_scene==null or current_scene.scene_file_path=="res://feature_launcher.tscn", "durable scene exit",30000)
	if not output.is_empty():
		write_json(output.path_join("workbench-"+mode+".json"),{"schema":1,"mode":mode,
			"process_id":OS.get_process_id(),"godot":Engine.get_version_info(),"display":DisplayServer.get_name(),
			"graphical":graphical,"assertions":checks,"failures":failures,"captures":captures,"native_samples":samples,
			"evidence":retained_evidence})
	print("PERSISTENT_AREAS_WORKBENCH ",JSON.stringify({"mode":mode,"checks":checks,"failures":failures,
		"graphical":graphical,"pid":OS.get_process_id()}))
	quit(0 if failures.is_empty() else 1)
