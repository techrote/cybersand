extends "res://tests/test_persistent_area_ramcache.gd"

const CAPACITY_SETTING := "cybersand/native_active_core_capacity"
var previous_capacity: Variant
var rescue_report := {}
var strict_exit_case := false
var first_area_case := false
var during_ahead_case := false


func _initialize() -> void:
	previous_capacity = ProjectSettings.get_setting(CAPACITY_SETTING,null)
	# A real bounded native scheduling failure, confined to this fresh fault
	# profile. No ordinary application or simulation capacity is changed.
	# Reopen must retain this fault profile's exact admitted execution setting.
	# Changing capacity across restart is correctly rejected by CYPS admission.
	ProjectSettings.set_setting(CAPACITY_SETTING,1)
	strict_exit_case = "--recoverable-strict-exit" in OS.get_cmdline_user_args()
	first_area_case = "--recoverable-first-area" in OS.get_cmdline_user_args()
	during_ahead_case = "--recoverable-during-ahead" in OS.get_cmdline_user_args()
	super._initialize()


func capture_reference() -> Dictionary:
	controller._begin("healthy_recovery_reference",controller.active_area)
	var frozen: Dictionary = await controller._freeze_live()
	if not check(frozen.get("ok",false),"reference freezes the actual supported owner"): return {}
	var remembered: Dictionary = await controller._remember_active()
	if not check(remembered.get("ok",false),"reference binds current authoring"): return {}
	var receipt: Dictionary = controller._cache.entry(controller.active_area).hot
	var captured: Dictionary = await controller._worker({"kind":"resident_capture",
		"operation_id":controller.operation.operation_id,"receipt":receipt})
	if not check(captured.get("ok",false),"healthy native reference captured"): return {}
	await controller._finish("Reference retained without durable publication.")
	return captured.result.capsule


func mark_unsaved(id: String) -> bool:
	var fixture := Fixtures.description(id)
	if not check(bench.paint(Vector2i(fixture.empty_edit[0],fixture.empty_edit[1]),0),"unsaved Empty admitted in "+id): return false
	if not await until(func() -> bool:return not worker.paint_state().get("legacy_busy",false),"Empty drains in "+id): return false
	if not check(bench.paint(Vector2i(fixture.paint_edit[0],fixture.paint_edit[1]),Setup.WALL),"unsaved Wall admitted in "+id): return false
	return await until(func() -> bool:return not worker.paint_state().get("legacy_busy",false),"Wall drains in "+id)


func exercise_write() -> void:
	ProjectSettings.set_setting(CAPACITY_SETTING,previous_capacity)
	if not await configure_cache({"enabled":true,"deferred":not strict_exit_case,"background":false,"prefetch":false}): return
	if first_area_case:
		await first_area_failure()
		return
	var durable_a: Dictionary = controller.manifest.areas.a.duplicate(true)
	var healthy := {}
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		if not await mark_unsaved(id): return
		var capsule := await capture_reference()
		if capsule.is_empty(): return
		if id!="a": healthy[id] = capsule
	if not await travel("a"): return
	durable_a = controller.manifest.areas.a.duplicate(true)
	if strict_exit_case:
		check(controller._candidate_durable,"strict completed travel retains the historical candidate-durable flag")
		if not check(bench.paint(Vector2i(480,72),Setup.WALL),"new unsaved active edit follows strict durable travel"): return
		if not await until(func() -> bool:return controller.status().areas.a.dirty and not worker.paint_state().get("legacy_busy",false),
			"strict active edit is visibly unsaved without resetting candidate durability"): return
	var before: Dictionary = await native_residents()
	var failed_advancement := {}
	if during_ahead_case:
		var before_clock: Dictionary = controller.clock.duplicate(true)
		if not check(controller.request_ahead(1),"actual capacity-limited native Simulate Ahead admitted"): return
		if not await until(func() -> bool:return worker.has_failed() and not controller.busy \
			and not controller.active_ready,"actual native failure during an admitted Ahead slice",15000): return
		var pending: Dictionary = controller._resident_advancement.duplicate(true)
		if not check(not pending.get("pending",{}).is_empty(),"failed native slice retains its exact request and game-time plan"): return
		var terminal: Dictionary = worker.persistent_poll(int(pending.pending.token))
		check(terminal.get("status","")=="failed" and terminal.result.get("receipt",{}).get("failed",false),
			"real terminal native failure carries the failed owner receipt")
		check(not controller.request_save_recoverable() and not controller.request_exit("launcher"),
			"unacknowledged failed slice cannot bypass its owner cleanup")
		if not check(controller.request_retry(),"Retry admits known failed interval and owner release acknowledgement"): return
		if not await until(func() -> bool:return not controller.busy,"failed interval owner cleanup acknowledges",15000): return
		var completed: Dictionary = AreaClock.complete(before_clock,pending.plan,int(terminal.result.completed_ticks))
		check(completed.get("ok",false) and controller.clock==completed.clock,
			"only proven completed ticks before failure are credited; failing tick is never simulated time")
		check(controller._resident_advancement.is_empty() and controller._unresolved_worker.is_empty() \
			and not controller._owner_cleanup_required and not controller._lease_held,
			"known failed request guard retires only after actual owner release ACK")
		check(not controller.active_ready and controller._quarantined and host.paused and worker.has_failed(),
			"acknowledging native failure never resumes, resets or captures the failed World")
		failed_advancement = {"before_clock":before_clock,"pending":pending,"terminal":terminal,
			"completed":completed,"after_cleanup":controller.status()}
	else:
		if not check(bench.toggle_pause(),"actual capacity-limited native area enters play"): return
		if not await until(func() -> bool:return worker.has_failed() and not controller.active_ready,
			"actual native failure produces the visible persistent quarantine",15000): return
	check(host.latest_snapshot.last_tick_error.contains("active scheduling-core capacity exhausted"),
		"failure is the intended real native capacity fault")
	check(not controller.request_save() and not controller.request_exit("launcher"),
		"ordinary Save all and implicit exit refuse the failed unsaved owner")
	check(is_instance_valid(host) and current_scene==host,"failed ordinary exit retains the actual scene and dirty native owner")
	check(controller.panel._recoverable_save.visible,"healthy-area recovery control remains accessible")
	await screenshot("failed-area-recovery-action")
	check(not controller._io_busy and not controller._writeback.busy(),"lost-ACK injection is serialized before publication")
	controller._store.set_test_fault("after_publish")
	var clock_before_recovery: Dictionary = controller.clock.duplicate(true)
	controller.panel._recoverable_save.pressed.emit()
	if not await until(func() -> bool:return not controller.busy,"actual healthy-area publication loses its acknowledgement"): return
	check(not controller.last_result.get("ok",true) and controller._publication_uncertain \
		and not controller._recovery_save_pending.is_empty(),"lost ACK retains the exact pending healthy recovery plan")
	check(not controller.request_save_recoverable() and not controller.request_recovery_exit("launcher"),
		"neither another capture nor explicit close can counterfeit the missing durable ACK")
	if not check(controller.request_retry(),"failed-owner Retry reopens storage without freezing or restoring the failed World"): return
	if not await until(func() -> bool:return not controller.busy,"storage-only retry acknowledges the exact published healthy snapshot"): return
	if not check(controller.last_result.get("ok",false) and not controller.last_result.get("ordinary_save_all",true),
		"partial recovery receives explicit durable acknowledgement without a Save-all claim"): return
	check(controller.clock==clock_before_recovery and controller._recovery_save_pending.is_empty() and not controller._publication_uncertain,
		"storage-only ACK recovery preserves RAM game time and retires the original publication ambiguity")
	var after: Dictionary = await native_residents()
	check(after.active.failed and int(after.active.handle)==int(before.active.handle) and after.inactive.size()==2,
		"failed active and both healthy native owners remain instantiated and unchanged")
	check(controller.manifest.areas.a==durable_a,"recovery preserves the failed area's last durable record")
	check(int(after.counters.native_restorations)==int(before.counters.native_restorations),
		"lost-ACK recovery performs no native reconstruction")
	for id: String in ["b","c"]:
		check(controller.manifest.areas[id].native_sha256==healthy[id].sha256 \
			and controller.manifest.areas[id].physical_hash==healthy[id].physical_hash,
			"recovery durably preserves complete unsaved healthy native state in "+id)
	check(not controller.active_ready and controller._quarantined and host.paused,
		"successful healthy publication never resumes or resets the failed World")
	check(int(controller._cache.status().essential_publication_reserved_bytes)==0,
		"recovery publication releases its bounded immutable working headroom")
	rescue_report = {"state":controller.status(),"evidence":controller.evidence(),"native_before":before,"native_after":after,
		"strict_exit_case":strict_exit_case,"during_ahead_case":during_ahead_case,
		"failed_advancement":failed_advancement,"lost_ack_recovered":true}
	var expected := {"session_id":controller.manifest.session_id,"clock":controller.manifest.clock.duplicate(true),"areas":{}}
	for id: String in Fixtures.IDS: expected.areas[id] = controller.manifest.areas[id].duplicate(true)
	if during_ahead_case: expected["originating_write_process_id"] = OS.get_process_id()
	write_json(output.path_join("recovery-expected.json"),expected)
	if during_ahead_case:
		rescue_report["expected_reopen"] = expected.duplicate(true)
		rescue_report["expected_reopen_sha256"] = FileAccess.get_sha256(output.path_join("recovery-expected.json"))
	await confirm_recovery_close()


func confirm_recovery_close() -> void:
	controller.panel._open_recovery_exit()
	await process_frame
	check(controller.panel._recovery_exit_dialog.visible \
		and controller.panel._recovery_exit_dialog.dialog_text.contains("unsaved RAM state"),
		"explicit recovery close discloses the failed area's unsaved-state loss")
	await screenshot("failed-area-recovery-close-confirmation")
	controller.panel._recovery_exit_dialog.confirmed.emit()
	if not await until(func() -> bool:return current_scene!=null and current_scene.scene_file_path=="res://feature_launcher.tscn",
		"explicitly confirmed recovery close returns to the ordinary launcher",30000): return
	controller = null
	host = null
	bench = null
	rescue_report["explicit_close_acknowledged"] = true


func first_area_failure() -> void:
	check(int(controller._cache.status().hot_count)==1 and int(controller._cache.status().cold_count)==2,
		"first-area failure begins with one HOT and two untouched COLD entries")
	if not await mark_unsaved("a"): return
	if (await capture_reference()).is_empty(): return
	var original_manifest: Dictionary = controller.manifest.duplicate(true)
	var before: Dictionary = await native_residents()
	if not check(bench.toggle_pause(),"first area enters actual failing native simulation"): return
	if not await until(func() -> bool:return worker.has_failed() and not controller.active_ready,
		"first native failure is quarantined",15000): return
	check(not controller.request_exit("launcher"),"ordinary first-area exit refuses unsaved failed state")
	check(not controller.panel._recoverable_save.visible and controller.panel._recovery_close.visible,
		"no unavailable healthy-save action is required; explicit failed-profile close remains accessible")
	check(not controller.status().recovery_close.get("ordinary_save_all",true) \
		and not controller.status().recovery_close.get("has_healthy_recovery",true),
		"last-durable-profile close does not invent a new recovery save or Save-all claim")
	var after: Dictionary = await native_residents()
	check(after.active.failed and int(after.active.handle)==int(before.active.handle) and after.inactive.is_empty(),
		"failed first native owner remains instantiated until explicit loss confirmation")
	check(controller.manifest==original_manifest,"offering explicit first-area close does not publish or mutate the last durable profile")
	var expected := {"session_id":controller.manifest.session_id,"clock":controller.manifest.clock.duplicate(true),"areas":{}}
	for id: String in Fixtures.IDS: expected.areas[id] = controller.manifest.areas[id].duplicate(true)
	write_json(output.path_join("recovery-expected.json"),expected)
	rescue_report = {"first_area_case":true,"state":controller.status(),"evidence":controller.evidence(),"native_before":before,"native_after":after}
	await confirm_recovery_close()


func exercise_reopen() -> void:
	ProjectSettings.set_setting(CAPACITY_SETTING,previous_capacity)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("recovery-expected.json")))
	if not check(saved is Dictionary and saved.session_id==controller.manifest.session_id,"new process opens the exact recovery session"): return
	var actual_areas := {}
	if during_ahead_case:
		check(int(saved.get("originating_write_process_id",0))>0 and int(saved.originating_write_process_id)!=OS.get_process_id(),
			"failed-Ahead recovery reopens in a genuinely different process")
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		var capsule := await capture_reference()
		if not check(not capsule.is_empty() and capsule.sha256==saved.areas[id].native_sha256 \
			and capsule.physical_hash==saved.areas[id].physical_hash and int(capsule.completed_tick)==int(saved.areas[id].completed_tick),
			"fresh process reconstructs exact recovery continuation in "+id): return
		actual_areas[id] = {"native_sha256":capsule.sha256,"physical_hash":capsule.physical_hash,
			"completed_tick":capsule.completed_tick,"authored_source_sha256":capsule.authored_source_sha256,
			"authoring_sha256":controller._cache.entry(id).authoring_sha256}
		if during_ahead_case:
			check(str(actual_areas[id].authoring_sha256)==str(saved.areas[id].authoring_sha256) \
				and str(actual_areas[id].authored_source_sha256)==str(saved.areas[id].authored_source_sha256),
				"failed-Ahead recovery restores the matching authored envelope and source in "+id)
		if id!="a" and not first_area_case and not await verify_edits(id): return
	if not await travel("a"): return
	var point: Array = Fixtures.description("a").empty_edit
	check(await native_cell(Vector2i(point[0],point[1]))==(0 if strict_exit_case else Setup.WOOD),
		"failed A explicitly reopens its prior durable authored material, as disclosed before close")
	if strict_exit_case:
		check(await native_cell(Vector2i(480,72))==0,"strict-mode failure's final unsaved edit is omitted only after explicit close confirmation")
	rescue_report = {"fresh_process":true,"state":controller.status(),"evidence":controller.evidence(),
		"during_ahead_case":during_ahead_case,"actual_areas":actual_areas}
	if during_ahead_case:
		rescue_report["expected_reopen"] = saved.duplicate(true)
		rescue_report["expected_reopen_sha256"] = FileAccess.get_sha256(output.path_join("recovery-expected.json"))
		rescue_report["originating_write_process_id"] = int(saved.originating_write_process_id)


func _finish() -> void:
	ProjectSettings.set_setting(CAPACITY_SETTING,previous_capacity)
	check(not rescue_report.is_empty() and (rescue_report.get("explicit_close_acknowledged",false) \
		or rescue_report.get("fresh_process",false)),"recovery Workbench campaign reached complete assertions")
	if controller!=null and is_instance_valid(controller):
		if controller.active_ready and not controller.busy:
			if check(controller.request_exit("launcher"),"healthy reopened profile exits durably"):
				await until(func() -> bool:return current_scene!=null and current_scene.scene_file_path=="res://feature_launcher.tscn","reopened profile exit",30000)
		else:
			worker.stop_worker()
			await controller._io("close_profile",[])
	rescue_report.merge({"checks":checks,"failures":failures.duplicate(),"graphical":graphical,"process_id":OS.get_process_id(),"mode":mode},true)
	if not output.is_empty(): write_json(output.path_join("recoverable-workbench-"+mode+".json"),rescue_report)
	print("GEN006_RAMCACHE_RECOVERABLE_WORKBENCH ",JSON.stringify({"checks":checks,"failures":failures.size(),"graphical":graphical,"mode":mode}))
	quit(0 if failures.is_empty() else 1)
