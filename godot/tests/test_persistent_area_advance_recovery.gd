extends "res://tests/test_persistent_area_ramcache.gd"

const DelayedAdvanceWorker = preload("res://tests/persistent_area_advance_delayed_worker.gd")
var advance_recovery_report := {"cases":[]}


func configure_host() -> void:
	host.simulation_worker = DelayedAdvanceWorker.new(false)


func exercise_write() -> void:
	if not await configure_cache({"enabled":true,"deferred":true,"background":false,"prefetch":false}): return
	for id: String in ["b","c","a"]:
		if not await travel(id): return
	if not check(bench.paint(Vector2i(480,80),Setup.WALL),"recognisable unsaved source edit admitted"): return
	if not await until(func() -> bool:return settled() and not worker.paint_state().get("legacy_busy",false),"source edit acknowledged"): return
	for index: int in 12:
		if int(controller.clock.game_ticks)>=160: break
		if not check(controller.request_ahead(160-int(controller.clock.game_ticks)),"real future ticks create target debt"): return
		if not await operation_finished("source future ticks"): return
	if not check(int(controller.clock.game_ticks)==160,"setup uses exactly160 completed native game ticks"): return
	if not await delayed_case("inactive_debt","b",false,0,true): return
	# This is the same admitted native/Main HOT handoff used by travel. Keeping
	# its existing debt explicit gives a controlled active catch-up fixture
	# without attributing artificial time or changing a production work budget.
	if not await activate_retained_without_catch_up("b"): return
	if not await delayed_case("active_debt","b",true,0,false): return
	if not await prepare_one_tick_debt(): return
	if not await delayed_case("ahead_debt_future","b",true,64,false): return
	await save_expectations()
	if not failures.is_empty(): return
	expected["originating_write_process_id"] = OS.get_process_id()
	write_json(output.path_join("expected-reopen.json"),expected)
	advance_recovery_report["expected_reopen"] = expected.duplicate(true)
	advance_recovery_report["expected_reopen_sha256"] = FileAccess.get_sha256(output.path_join("expected-reopen.json"))
	advance_recovery_report["originating_write_process_id"] = OS.get_process_id()
	advance_recovery_report["session_id"] = controller.manifest.session_id
	advance_recovery_report["completed"] = failures.is_empty()


func activate_retained_without_catch_up(target: String) -> bool:
	var before: Dictionary = controller.clock.duplicate(true)
	controller._begin("qualification_debt_handoff",target)
	var frozen: Dictionary = await controller._freeze_live()
	if not check(frozen.get("ok",false),"controlled handoff freezes actual active owner"): return false
	var remembered: Dictionary = await controller._remember_active()
	if not check(remembered.get("ok",false),"controlled handoff retains source identity"): return false
	var activated: Dictionary = await controller._activate_hot(target)
	if not check(activated.get("ok",false),"controlled handoff receives native and Main acknowledgement"): return false
	await controller._finish("Qualification activates retained native state with explicit remaining debt.")
	return check(controller.active_area==target and controller.clock==before and AreaClock.debt(controller.clock,target)>64,
		"actual active target retains its original accounted frontier and more than two slices of debt")


func prepare_one_tick_debt() -> bool:
	var target := str(controller.active_area)
	var debt := AreaClock.debt(controller.clock,target)
	if not check(debt>1,"Ahead fixture begins with real outstanding debt"): return false
	controller._begin("qualification_exact_debt_prefix",target)
	var frozen: Dictionary = await controller._freeze_live()
	if not check(frozen.get("ok",false),"debt-prefix fixture acquires exclusive native boundary"): return false
	var remembered: Dictionary = await controller._remember_active()
	if not check(remembered.get("ok",false),"debt-prefix fixture binds current receipt"): return false
	var source_clock: Dictionary = controller.clock.duplicate(true)
	var planned: Dictionary = AreaClock.plan(source_clock,target,"catch_up",0,debt-1)
	if not check(planned.get("ok",false),"independent setup admits a bounded debt-only plan"): return false
	var completed := 0
	var slices: Array[Dictionary] = []
	var deadline := Time.get_ticks_msec()+30000
	while completed<int(planned.plan.work_ticks) and Time.get_ticks_msec()<deadline:
		var previous: Dictionary = controller._cache.entry(target).hot
		var result: Dictionary = await controller._worker({"kind":"advance_active","operation_id":controller.operation.operation_id,
			"receipt":previous,"max_ticks":mini(32,int(planned.plan.work_ticks)-completed),"max_us":100000})
		if not check(result.get("ok",false),"setup completes actual bounded native debt work"): return false
		var actual := int(result.result.completed_ticks)
		if not check(actual>0 and int(result.result.current_tick)==int(planned.plan.source_native_tick)+completed+actual,
			"setup native result identifies its exact contiguous completed interval"): return false
		completed += actual
		var accounted: Dictionary = AreaClock.complete(source_clock,planned.plan,completed)
		if not check(accounted.get("ok",false),"setup accounts only its verified cumulative native prefix"): return false
		var refreshed: Dictionary = controller._refresh_resident(target,result.result.receipt)
		if not check(refreshed.get("ok",false),"setup admits the exact advanced native receipt"): return false
		controller.clock = accounted.clock
		controller._resident_clock_dirty = true
		slices.append({"before_receipt":previous,"result":result.result.duplicate(true),"accounted":accounted.duplicate(true)})
	if not check(completed==debt-1 and AreaClock.debt(controller.clock,target)==1 \
		and int(controller.clock.game_ticks)==int(source_clock.game_ticks),
		"real setup leaves exactly one debt tick and advances no global time"): return false
	advance_recovery_report["debt_setup"] = {"base_clock":source_clock,"plan":planned.plan,"slices":slices,
		"completed_ticks":completed,"clock":controller.clock.duplicate(true),"target_area":target}
	await controller._finish("Actual bounded native work leaves one debt tick for the Ahead boundary test.")
	return failures.is_empty()


func delayed_case(kind: String, target: String, is_active: bool, future_ticks: int, release_fault: bool) -> bool:
	phase("late resident advancement "+kind)
	var source := str(controller.active_area)
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before_native: Dictionary = await native_residents()
	var before_cache: Dictionary = controller._cache.entry(target)
	var before_source: Dictionary = controller._cache.entry(source)
	var planned: Dictionary = AreaClock.plan(before_clock,target,"ahead" if future_ticks>0 else "catch_up",future_ticks,controller.MAX_OPERATION_TICKS)
	if not check(planned.get("ok",false) and int(planned.plan.work_ticks)>32,"case requires more than one real bounded native slice"): return false
	var filesystem_before: Dictionary = await controller._io("io_telemetry",[])
	worker.qualification_arm(target,is_active)
	var started := Time.get_ticks_msec()
	var admitted: bool = controller.request_ahead(future_ticks) if future_ticks>0 \
		else (controller.request_catch_up() if is_active else controller.request_travel(target))
	if not check(admitted,"public "+kind+" operation admitted"): return false
	if not await until(func() -> bool:return worker.qualification_slices().size()==2,"two actual positive native slices complete before delayed ACK",10000): return false
	if release_fault:
		controller.request_cancel()
		check(controller.busy and controller.operation.cancel_requested,"cancellation waits for the in-flight native interval")
	if not await until(func() -> bool:return not controller.busy,"unchanged thirty-second owner timeout quarantines interval",45000): return false
	var timeout_elapsed := Time.get_ticks_msec()-started
	var unresolved: Dictionary = controller._unresolved_worker.duplicate(true)
	var slices: Array[Dictionary] = worker.qualification_slices()
	var prefix := int(slices[0].result.completed_ticks)
	var late := int(slices[1].result.completed_ticks)
	var prefix_clock: Dictionary = AreaClock.complete(before_clock,planned.plan,prefix)
	var expected_clock: Dictionary = AreaClock.complete(before_clock,planned.plan,prefix+late)
	if not check(prefix>0 and late>0 and prefix_clock.get("ok",false) and expected_clock.get("ok",false),
		"independent Clock plan resolves the positive acknowledged prefix and real late slice"): return false
	check(timeout_elapsed>=30000,"production owner deadline remains thirty seconds")
	check(not controller.active_ready and controller._quarantined and host.paused,
		"late native acknowledgement leaves active authority paused")
	check(controller.clock==prefix_clock.clock and int(controller._cache.entry(target).completed_tick)==int(prefix_clock.clock.areas[target].native_ticks),
		"already acknowledged prefix is accounted immediately before late completion arrives")
	check(unresolved.get("kind","")==("advance_active" if is_active else "resident_advance") \
		and int(unresolved.get("token",0))==int(slices[1].token),"exact late native request token is retained")
	var pending_at_timeout: Dictionary = controller._resident_advancement.duplicate(true)
	check(pending_at_timeout.get("plan",{})==planned.plan and pending_at_timeout.get("source_clock",{})==before_clock \
		and int(pending_at_timeout.get("accounted_ticks",-1))==prefix,
		"original debt/future plan and complete acknowledged prefix survive timeout")
	check(not controller.request_save() and not controller.request_travel("c") and not controller.request_exit("launcher"),
		"unresolved interval refuses Save, replacement travel and exit")
	if not await until(func() -> bool:return worker.persistent_poll(int(unresolved.token)).get("status","")!="pending",
		"actual delayed native result becomes terminal",10000): return false
	var terminal: Dictionary = worker.persistent_poll(int(unresolved.token))
	if not check(terminal.get("ok",false) and terminal.get("status","")=="complete" \
		and terminal.result==slices[1].result,"late terminal response matches the exact observed native slice"): return false
	var before_retry: Dictionary = controller.status()
	var io_before: Dictionary = controller._io_metrics.duplicate(true)
	var late_native: Dictionary = slices[1].native_status
	var release_timeout := {}
	if release_fault: worker.qualification_delay_release()
	if not check(controller.request_retry(),"Retry admits exact completed resident interval"): return false
	check(not controller.request_retry(),"concurrent repeated Retry is refused")
	if release_fault:
		if not await until(func() -> bool:return not controller.busy,"actual release acknowledgement exceeds its production deadline",45000): return false
		var release_token: Dictionary = controller._unresolved_worker.duplicate(true)
		check(release_token.get("kind","")=="release" and not controller.active_ready \
			and not controller._resident_advancement.is_empty() and controller._resident_advancement.pending.is_empty(),
			"accounted interval guard remains until delayed native owner release acknowledges")
		check(controller.clock==expected_clock.clock,"first Retry accounts the late interval before release timeout")
		release_timeout = {"status":controller.status(),"operation":controller.operation.duplicate(true),"unresolved":release_token}
		if not await until(func() -> bool:return worker.persistent_poll(int(release_token.token)).get("status","")!="pending",
			"actual delayed release becomes terminal",10000): return false
		if not check(controller.request_retry(),"second Retry admits original release acknowledgement"): return false
	if not await operation_finished("late resident interval and owner release recovered"): return false
	var after_native: Dictionary = await native_residents()
	var after_cache: Dictionary = controller._cache.entry(target)
	var after_source: Dictionary = controller._cache.entry(source)
	var target_native := {}
	for receipt: Dictionary in after_native.entries:
		if str(receipt.identity.area_id)==target: target_native = receipt
	check(controller.active_area==source and controller.clock==expected_clock.clock,
		"Retry preserves active identity and credits original debt/future interval exactly once")
	check(int(target_native.get("completed_tick",-1))==int(expected_clock.clock.areas[target].native_ticks) \
		and int(after_cache.completed_tick)==int(target_native.get("completed_tick",-1)) \
		and after_cache.hot==target_native,"clock, cache and actual target native owner agree after Retry")
	check(int(after_cache.hot.handle)==int(before_cache.hot.handle) \
		and int(after_source.hot.handle)==int(before_source.hot.handle),"Retry retains both actual native handles")
	check(int(controller.operation.native_ticks_executed)==prefix+late and int(controller.operation.native_slice_count)==2 \
		and int(controller.operation.completed_ticks)==prefix+late,"operation metrics count each completed slice exactly once")
	if future_ticks>0:
		check(int(planned.plan.source_debt_ticks)==1 and int(expected_clock.game_advanced_ticks)==prefix+late-1 \
			and int(expected_clock.game_advanced_ticks)>0,"Ahead pays the one debt tick then credits only completed future work")
	else:
		check(int(controller.clock.game_ticks)==int(before_clock.game_ticks),"debt-only recovery advances no global game time")
	for key: String in ["native_restorations","source_constructions","captures","private_ticks"]:
		check(int(after_native.counters[key])==int(late_native.counters[key]),"actual native Retry adds zero "+key)
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(io_before[key]),"Retry performs zero repeated "+key)
	var filesystem_after: Dictionary = await controller._io("io_telemetry",[])
	for key: String in ["read_requests","read_system_calls","read_bytes","write_requests","write_system_calls","write_bytes","publication_requests"]:
		check(int(filesystem_after.get(key,-1))==int(filesystem_before.get(key,-2)),"resident recovery performs zero actual profile "+key)
	check(controller._resident_advancement.is_empty() and controller._unresolved_worker.is_empty() \
		and not controller._owner_cleanup_required and not controller._lease_held \
		and int(controller._cache.status().pending_reservations)==0,"all interval, owner and resource guards retire only after ACK")
	check(not controller.request_retry(),"completed interval cannot be consumed again by repeated Retry")
	var after_status: Dictionary = controller.status()
	var completed_operation: Dictionary = controller.operation.duplicate(true)
	var native_identity := await capture_identity(target)
	if native_identity.is_empty(): return false
	check(native_identity==slices[1].native_identity,"Retry preserves complete actual native continuation bytes and physical state")
	advance_recovery_report.cases.append({"kind":kind,"source_area":source,"target_area":target,"base_clock":before_clock,
		"plan":planned.plan,"before_native":before_native,"before_cache":before_cache,"before_source":before_source,
		"acknowledged_prefix_ticks":prefix,"late_ticks":late,"slices":slices,"terminal":terminal,
		"timeout_elapsed_msec":timeout_elapsed,"pending_at_timeout":pending_at_timeout,"before_retry":before_retry,
		"release_timeout":release_timeout,"after_retry":after_status,"expected_completion":expected_clock,
		"after_native":after_native,"after_cache":after_cache,"after_source":after_source,"operation":completed_operation,
		"actual_native_identity":native_identity,"io_before":io_before,"io_after":controller._io_metrics.duplicate(true),
		"filesystem_before":filesystem_before,"filesystem_after":filesystem_after})
	await screenshot("advance-recovered-"+kind)
	return failures.is_empty()


func capture_identity(id: String) -> Dictionary:
	controller._begin("qualification_advance_identity",controller.active_area)
	var frozen: Dictionary = await controller._freeze_live()
	if not check(frozen.get("ok",false),"identity reference acquires native owner"): return {}
	var remembered: Dictionary = await controller._remember_active()
	if not check(remembered.get("ok",false),"identity reference binds actual authoring/native state"): return {}
	var captured: Dictionary = await controller._worker({"kind":"resident_capture","operation_id":controller.operation.operation_id,
		"receipt":controller._cache.entry(id).hot})
	if not check(captured.get("ok",false),"identity reference captures complete native continuation"): return {}
	var capsule: Dictionary = captured.result.capsule
	var result := {"native_sha256":str(capsule.sha256),"physical_hash":str(capsule.physical_hash),
		"completed_tick":int(capsule.completed_tick),"authored_source_sha256":str(capsule.authored_source_sha256)}
	await controller._finish("Complete native identity observed without replay or publication.")
	return result


func exercise_reopen() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected-reopen.json")))
	if not check(parsed is Dictionary and parsed.get("areas",{}).size()==3,"fresh process reads complete three-area recovery oracle"): return
	expected = parsed
	check(str(controller.manifest.session_id)==str(expected.session_id) \
		and AreaClock.canonical(controller.clock)==AreaClock.canonical(expected.clock),"new process restores exact session and accounted game clock")
	check(int(expected.get("originating_write_process_id",0))>0 and int(expected.originating_write_process_id)!=OS.get_process_id(),
		"reopen uses a genuinely new OS process")
	advance_recovery_report["expected_reopen"] = expected.duplicate(true)
	advance_recovery_report["expected_reopen_sha256"] = FileAccess.get_sha256(output.path_join("expected-reopen.json"))
	advance_recovery_report["originating_write_process_id"] = int(expected.originating_write_process_id)
	advance_recovery_report["session_id"] = controller.manifest.session_id
	advance_recovery_report["actual_areas"] = {}
	if not await configure_cache({"enabled":true,"deferred":true,"background":false,"prefetch":false}): return
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		var actual := await capture_identity(id)
		if actual.is_empty(): return
		actual["authoring_sha256"] = str(controller._cache.entry(id).authoring_sha256)
		for field: String in ["native_sha256","physical_hash","completed_tick","authored_source_sha256","authoring_sha256"]:
			check(actual[field]==expected.areas[id][field],"fresh process restores exact "+field+" in "+id)
		advance_recovery_report.actual_areas[id] = actual
	advance_recovery_report["completed"] = failures.is_empty()


func _finish() -> void:
	check(advance_recovery_report.get("completed",false),"late native advancement recovery reaches every required assertion")
	advance_recovery_report.merge({"schema":"gen006-resident-advance-recovery-v1","mode":mode,
		"checks":checks,"failures":failures.duplicate(),"graphical":graphical,"process_id":OS.get_process_id()},true)
	if controller!=null: advance_recovery_report["evidence"] = controller.evidence()
	if not output.is_empty(): write_json(output.path_join("advance-recovery-"+mode+".json"),advance_recovery_report)
	print("GEN006_RAMCACHE_ADVANCE_RECOVERY ",JSON.stringify({"checks":checks,"failures":failures.size(),
		"graphical":graphical,"mode":mode,"pid":OS.get_process_id()}))
	await super._finish()
