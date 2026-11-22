extends "res://tests/test_persistent_area_ramcache.gd"

# Real Main/native regression for synchronous retained-state publication.
# A lost disk acknowledgement never makes an older checkpoint authoritative
# over the already advanced HOT owner. Reopen runs in a distinct OS process.
var storage_recovery_report := {"cases":[]}


func exercise_write() -> void:
	if not await configure_cache({"enabled":true,"deferred":false,"background":false,"prefetch":false}): return
	if not await lost_ack_case("ahead"): return
	if not await unpublished_dirty_save(): return
	if not await lost_ack_case("save"): return
	if not await destination_fault("b","COLD","before_publish"): return
	if not await destination_fault("c","COLD","after_publish"): return
	if not check(controller.request_eviction(),"safe demotion admitted before WARM publication attack"): return
	if not await operation_finished("inactive native owners demoted to validated WARM capsules"): return
	if not check(controller._cache.entry("a").residency=="WARM","later target is a real captured WARM checkpoint"): return
	if not check(controller.request_ahead(12),"actual active native work creates legitimate WARM-target debt"): return
	if not await operation_finished("finite native progression before WARM target fault"): return
	if not await destination_fault("a","WARM","after_publish"): return
	await save_expectations()
	expected["originating_write_process_id"] = OS.get_process_id()
	write_json(output.path_join("expected-reopen.json"),expected)
	storage_recovery_report["expected_reopen"] = expected.duplicate(true)
	storage_recovery_report["expected_reopen_sha256"] = FileAccess.get_sha256(output.path_join("expected-reopen.json"))
	storage_recovery_report["session_id"] = controller.manifest.session_id
	storage_recovery_report["originating_write_process_id"] = OS.get_process_id()
	storage_recovery_report["completed"] = failures.is_empty()


func paint_unsaved(position: Vector2i) -> bool:
	if not check(bench.paint(position,Setup.WALL),"paused material edit admitted before retained publication"): return false
	return await until(func() -> bool:return settled() and bool(controller._cache.entry(controller.active_area).dirty) \
		and not worker.paint_state().get("legacy_busy",false),"paused material edit reaches the resident mutation fence")


func lost_ack_case(kind: String) -> bool:
	phase("cached synchronous "+kind+" loses publication ACK")
	if kind=="save" and not await paint_unsaved(Vector2i(480,80)): return false
	var before_manifest: Dictionary = controller.manifest.duplicate(true)
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before_native: Dictionary = await native_residents()
	if before_native.is_empty(): return false
	var injected := [false]
	if kind=="ahead":
		controller.qualification_boundary_hook = func(boundary: String, _receipt: Dictionary) -> int:
			if boundary=="source_durable" and not injected[0]:
				controller._store.set_test_fault("after_publish")
				injected[0] = true
			return 0
	else:
		check(not controller._io_busy and not controller._writeback.busy(),"synchronous Save fault is installed outside I/O")
		controller._store.set_test_fault("after_publish")
		injected[0] = true
	if not check(controller.request_ahead(12) if kind=="ahead" else controller.request_save(),"cached "+kind+" admitted"): return false
	if not await until(func() -> bool:return not controller.busy,"actual retained publication reaches lost-ACK quarantine"): return false
	controller.qualification_boundary_hook = Callable()
	var completed := int(controller.operation.completed_ticks)
	check(injected[0] and (completed>0 if kind=="ahead" else completed==0),"fault follows the expected actual native work")
	check(not controller.active_ready and controller._quarantined and controller._publication_uncertain \
		and controller._force_profile_reopen and host.paused,"uncertain resident publication pauses further gameplay")
	check(controller.manifest==before_manifest,"missing ACK does not falsely advance the acknowledged manifest")
	check(int(controller.clock.game_ticks)==int(before_clock.game_ticks)+completed \
		and int(controller.clock.areas.a.native_ticks)==int(before_clock.areas.a.native_ticks)+completed \
		and int(worker.paint_state().tick)==int(controller.clock.areas.a.native_ticks),
		"completed retained native work is already accounted exactly once despite missing durability ACK")
	var resident_clock: Dictionary = controller.clock.duplicate(true)
	var published: Dictionary = await controller._io("current_manifest",[])
	if not check(published.get("clock",{})==resident_clock and int(published.get("revision",-1))==int(before_manifest.revision)+1,
		"actual filesystem publication contains the exact current resident clock and next revision"): return false
	var retained: Dictionary = await native_residents()
	if retained.is_empty(): return false
	check(int(retained.active.handle)==int(before_native.active.handle),"failed publication retains the same instantiated native owner")
	check(not controller.request_ahead(1) and not controller.request_travel("b") and not controller.request_save(),
		"quarantine rejects further progression, replacement and duplicate Save")
	var io_before: Dictionary = controller._io_metrics.duplicate(true)
	if not check(controller.request_retry(),"Retry admits storage-only reconciliation of retained synchronous state"): return false
	check(not controller.request_retry(),"a second outstanding Retry is refused")
	if not await operation_finished("retained synchronous "+kind+" publication acknowledgement reconciled"): return false
	var after: Dictionary = await native_residents()
	if after.is_empty(): return false
	check(controller.clock==resident_clock and int(worker.paint_state().tick)==int(resident_clock.areas.a.native_ticks),
		"Retry preserves exact resident game time without replaying native work")
	check(controller.manifest==published,"Retry acknowledges the already published snapshot without publishing a replacement")
	check(int(after.active.handle)==int(retained.active.handle) \
		and int(after.active.completed_tick)==int(retained.active.completed_tick),"Retry preserves the active native handle and completed tick")
	for key: String in ["native_restorations","source_constructions"]:
		check(int(after.counters[key])==int(retained.counters[key]),"actual native Retry performs zero "+key)
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(io_before[key]),"resident Retry performs zero repeated "+key)
	check(not controller._publication_uncertain and not controller._force_profile_reopen \
		and int(controller._cache.status().dirty_count)==0,"exact durable ACK retires ambiguity and clears only the captured dirty state")
	check(not controller.request_retry(),"Retry after successful acknowledgement is a no-op refusal")
	var captured := await capture_active_reference()
	if captured.is_empty(): return false
	check(captured.sha256==published.areas.a.native_sha256 and captured.physical_hash==published.areas.a.physical_hash,
		"complete native continuation after Retry equals the actual published bytes")
	storage_recovery_report.cases.append({"kind":kind,"completed_ticks":completed,"clock":resident_clock,
		"published_revision":published.revision,"published_native_sha256":published.areas.a.native_sha256,
		"previous_native_sha256":before_manifest.areas.a.native_sha256,"source_area":"a",
		"before_native":retained,"after_native":after,"io_before":io_before,"io_after":controller._io_metrics.duplicate(true)})
	return failures.is_empty()


func unpublished_dirty_save() -> bool:
	phase("cached dirty Save fails before publication")
	if not await paint_unsaved(Vector2i(472,72)): return false
	var before_manifest: Dictionary = controller.manifest.duplicate(true)
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before: Dictionary = await native_residents()
	controller._store.set_test_fault("before_publish")
	if not check(controller.request_save(),"dirty pre-publication Save admitted"): return false
	if not await until(func() -> bool:return not controller.busy,"definitely unpublished resident save returns"): return false
	check(not controller.last_result.get("ok",true) and controller.active_ready and not controller._quarantined,
		"definitely unpublished dirty Save preserves a usable current World")
	check(controller.manifest==before_manifest and controller.clock==before_clock and controller._cache.entry("a").dirty,
		"unpublished Save retains newer resident edits without changing acknowledged storage or game time")
	if not await save_current("retry of definitely unpublished retained Save"): return false
	var after: Dictionary = await native_residents()
	check(controller.clock==before_clock and int(after.active.handle)==int(before.active.handle) \
		and int(after.active.completed_tick)==int(before.active.completed_tick),"Save retry neither replaces nor advances the retained owner")
	check(int(controller.manifest.revision)==int(before_manifest.revision)+1 \
		and int(controller._cache.status().dirty_count)==0,"one later successful publication acknowledges the existing resident edit")
	storage_recovery_report.cases.append({"kind":"unpublished_save","clock":before_clock,
		"acknowledged_revision":controller.manifest.revision,"before_native":before,"after_native":after,
		"previous_native_sha256":before_manifest.areas.a.native_sha256,
		"published_native_sha256":controller.manifest.areas.a.native_sha256})
	return failures.is_empty()


func destination_fault(target: String, residency: String, fault: String) -> bool:
	phase("strict "+residency+" destination fails at "+fault)
	if not check(controller._cache.entry(target).residency==residency and AreaClock.debt(controller.clock,target)>0,
		"destination has the actual requested tier and legitimate completed-game-time debt"): return false
	var source := str(controller.active_area)
	var source_capture := await capture_active_reference()
	if source_capture.is_empty(): return false
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before_manifest: Dictionary = controller.manifest.duplicate(true)
	var before_native: Dictionary = await native_residents()
	var injected := [false]
	controller.qualification_boundary_hook = func(boundary: String, _receipt: Dictionary) -> int:
		if boundary=="source_durable" and not injected[0]:
			controller._store.set_test_fault(fault)
			injected[0] = true
		return 0
	if not check(controller.request_travel(target),"strict destination preparation admitted"): return false
	if not await until(func() -> bool:return not controller.busy,"prepared destination reaches the actual storage failure"): return false
	controller.qualification_boundary_hook = Callable()
	var completed := int(controller.operation.completed_ticks)
	var warm: Dictionary = controller._cache.entry(target)
	var retained: Dictionary = await native_residents()
	if not check(injected[0] and completed>0 and warm.hot.is_empty() and not warm.warm.is_empty(),
		"actual private native ticks survive as a complete validated WARM authority"): return false
	check(controller.active_area==source and int(retained.active.handle)==int(before_native.active.handle) \
		and int(retained.active.completed_tick)==int(before_native.active.completed_tick),
		"failed target publication leaves the exact source HOT owner active and unchanged")
	check(int(controller.clock.game_ticks)==int(before_clock.game_ticks) \
		and int(controller.clock.areas[target].native_ticks)==int(before_clock.areas[target].native_ticks)+completed \
		and int(warm.warm.completed_tick)==int(controller.clock.areas[target].native_ticks),
		"WARM admission retains only its verified native interval with matching accounted RAM time")
	check(int(controller._cache.status().pending_reservations)==0 and not controller._lease_held \
		and controller._unresolved_worker.is_empty(),"discard and native release acknowledge before preparation reservation retires")
	var resident_clock: Dictionary = controller.clock.duplicate(true)
	var io_before: Dictionary = controller._io_metrics.duplicate(true)
	if fault=="after_publish":
		check(not controller.active_ready and controller._quarantined and controller._publication_uncertain,
			"uncertain destination publication visibly quarantines retained source and WARM target")
		var published: Dictionary = await controller._io("current_manifest",[])
		check(published.clock==resident_clock and str(published.areas[target].native_sha256)==str(warm.warm.sha256),
			"actual published destination and game-time identities equal retained WARM authority")
		if not check(controller.request_retry(),"Retry reconciles WARM destination publication without replacing source"): return false
		check(not controller.request_retry(),"duplicate destination Retry is refused while pending")
		if not await operation_finished("exact retained destination publication acknowledged"): return false
		check(controller.manifest==published,"destination Retry acknowledges the original publication only")
	else:
		check(controller.active_ready and not controller._quarantined and not controller._publication_uncertain \
			and controller.manifest==before_manifest and warm.dirty,
			"definitely unpublished destination keeps a usable source and dirty WARM authority")
	var after: Dictionary = await native_residents()
	check(controller.clock==resident_clock and controller.active_area==source \
		and int(after.active.handle)==int(retained.active.handle),"storage reconciliation preserves source authority and accounted work")
	for key: String in ["native_restorations","source_constructions"]:
		check(int(after.counters[key])==int(retained.counters[key]),"destination storage Retry performs zero "+key)
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(io_before[key]),"destination storage Retry performs zero repeated "+key)
	var source_after := await capture_active_reference()
	if source_after.is_empty(): return false
	check(source_after.sha256==source_capture.sha256 and source_after.physical_hash==source_capture.physical_hash,
		"source retains its complete native continuation across the failed destination transaction")
	var warm_tick := int(warm.warm.completed_tick)
	var warm_hash := str(warm.warm.sha256)
	var retry_io_after: Dictionary = controller._io_metrics.duplicate(true)
	if not await travel(target): return false
	var activation: Dictionary = controller.operation.duplicate(true)
	check(str(activation.residency)=="WARM" and int(activation.plan_source_native_tick)==warm_tick \
		and int(controller.clock.areas[target].native_ticks)==warm_tick+int(activation.completed_ticks),
		"subsequent activation resumes after the retained interval and never repeats its completed ticks")
	var activated := await capture_active_reference()
	if activated.is_empty(): return false
	if int(activation.completed_ticks)==0:
		check(str(activated.sha256)==warm_hash,"zero-debt WARM activation reconstructs exactly the retained native bytes")
	check(int(controller._cache.status().pending_reservations)==0,"successful WARM activation leaves no preparation reservation")
	storage_recovery_report.cases.append({"kind":"destination","residency":residency,"fault":fault,
		"source_area":source,"target_area":target,"completed_ticks":completed,"clock_before":before_clock,
		"retained_clock":resident_clock,"retained_native_sha256":warm_hash,"retained_native_tick":warm_tick,
		"source_native_sha256":source_capture.sha256,"source_native_sha256_after":source_after.sha256,
		"before_native":retained,"after_native":after,"io_before":io_before,"io_after":retry_io_after,
		"activation":activation,"activated_native_sha256":activated.sha256,
		"activated_native_tick":activated.completed_tick,"pending_reservations":controller._cache.status().pending_reservations})
	return failures.is_empty()


func capture_active_reference() -> Dictionary:
	controller._begin("storage_recovery_reference",controller.active_area)
	var frozen: Dictionary = await controller._freeze_live()
	if not check(frozen.get("ok",false),"reference acquires actual native ownership"): return {}
	var remembered: Dictionary = await controller._remember_active()
	if not check(remembered.get("ok",false),"reference binds the actual resident identity"): return {}
	var captured: Dictionary = await controller._worker({"kind":"resident_capture",
		"operation_id":controller.operation.operation_id,"receipt":controller._cache.entry(controller.active_area).hot})
	if not check(captured.get("ok",false),"reference captures complete supported native continuation"): return {}
	await controller._finish("Reference observed without replay or publication.")
	return captured.result.capsule


func exercise_reopen() -> void:
	var text := FileAccess.get_file_as_string(output.path_join("expected-reopen.json"))
	var parsed: Variant = JSON.parse_string(text)
	if not check(parsed is Dictionary and parsed.get("areas",{}).size()==3,"fresh process reads the completed recovery oracle"): return
	expected = parsed
	check(str(controller.manifest.session_id)==str(expected.session_id) \
		and AreaClock.canonical(controller.clock)==AreaClock.canonical(expected.clock),
		"genuinely new process restores the acknowledged session and exact game-time frontier")
	check(int(expected.get("originating_write_process_id",0))>0 and int(expected.originating_write_process_id)!=OS.get_process_id(),
		"reopen uses a genuinely different OS process from the acknowledged writer")
	storage_recovery_report["expected_reopen"] = expected.duplicate(true)
	storage_recovery_report["expected_reopen_sha256"] = FileAccess.get_sha256(output.path_join("expected-reopen.json"))
	storage_recovery_report["originating_write_process_id"] = int(expected.originating_write_process_id)
	storage_recovery_report["session_id"] = controller.manifest.session_id
	storage_recovery_report["actual_areas"] = {}
	if not await configure_cache({"enabled":true,"deferred":true,"background":false,"prefetch":false}): return
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		var captured := await capture_active_reference()
		if captured.is_empty(): return
		check(str(captured.sha256)==str(expected.areas[id].native_sha256) \
			and str(captured.physical_hash)==str(expected.areas[id].physical_hash) \
			and int(captured.completed_tick)==int(expected.areas[id].completed_tick),
			"fresh process reconstructs exact saved native state for area "+id)
		check(str(controller._cache.entry(id).authoring_sha256)==str(expected.areas[id].authoring_sha256),
			"fresh process retains the matching authored envelope for "+id)
		storage_recovery_report.actual_areas[id] = {"native_sha256":captured.sha256,"physical_hash":captured.physical_hash,
			"completed_tick":captured.completed_tick,"authoring_sha256":controller._cache.entry(id).authoring_sha256,
			"authored_source_sha256":captured.authored_source_sha256}
	storage_recovery_report["completed"] = failures.is_empty()


func _finish() -> void:
	check(storage_recovery_report.get("completed",false),"resident-storage recovery reaches every required assertion")
	storage_recovery_report.merge({"schema":"gen006-resident-storage-recovery-v1","mode":mode,
		"checks":checks,"failures":failures.duplicate(),"graphical":graphical,"process_id":OS.get_process_id()},true)
	if controller!=null: storage_recovery_report["evidence"] = controller.evidence()
	if not output.is_empty(): write_json(output.path_join("resident-storage-recovery-"+mode+".json"),storage_recovery_report)
	print("GEN006_RAMCACHE_RESIDENT_STORAGE_RECOVERY ",JSON.stringify({"checks":checks,"failures":failures.size(),
		"graphical":graphical,"mode":mode,"pid":OS.get_process_id()}))
	await super._finish()
