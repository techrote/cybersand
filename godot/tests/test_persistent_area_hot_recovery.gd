extends "res://tests/test_persistent_area_ramcache.gd"

const DelayedHotWorker = preload("res://tests/persistent_area_hot_delayed_worker.gd")
var recovery_report := {}


func configure_host() -> void:
	host.simulation_worker = DelayedHotWorker.new(false)


func resident_reference() -> Dictionary:
	controller._begin("qualification_resident_reference",controller.active_area)
	var frozen: Dictionary = await controller._freeze_live()
	if not check(frozen.get("ok",false),"reference freezes the actual native owner"): return {}
	var remembered: Dictionary = await controller._remember_active()
	if not check(remembered.get("ok",false),"reference binds current authoring and mutation identity"): return {}
	var entry: Dictionary = controller._cache.entry(controller.active_area)
	var captured: Dictionary = await controller._worker({"kind":"resident_capture",
		"operation_id":controller.operation.operation_id,"receipt":entry.hot})
	if not check(captured.get("ok",false),"reference captures actual complete resident native bytes"): return {}
	var result := {"capture":captured.result.capsule,"authoring":entry.authoring.duplicate(true),
		"handle":int(entry.hot.handle),"mutation_generation":int(entry.mutation_generation)}
	await controller._finish("Qualification reference retained without saving.")
	return result


func dirty_marker(id: String) -> bool:
	var fixture := Fixtures.description(id)
	if not check(bench.paint(Vector2i(fixture.empty_edit[0],fixture.empty_edit[1]),0),"unsaved Empty edit admitted in "+id): return false
	if not await until(func() -> bool:return settled() and not worker.paint_state().get("legacy_busy",false),"Empty edit acknowledged in "+id): return false
	if not check(bench.paint(Vector2i(fixture.paint_edit[0],fixture.paint_edit[1]),Setup.WALL),"unsaved Wall edit admitted in "+id): return false
	return await until(func() -> bool:return settled() and not worker.paint_state().get("legacy_busy",false),"Wall edit acknowledged in "+id)


func exercise_write() -> void:
	controller.qualification_measurement_tag = "late_resident_and_main_ack"
	if not await configure_cache({"enabled":true,"deferred":true,"background":false,"prefetch":false}): return
	var durable_before: Dictionary = controller.manifest.duplicate(true)
	if not await dirty_marker("a"): return
	var a := await resident_reference()
	if a.is_empty(): return
	if not await travel("b"): return
	if not await dirty_marker("b"): return
	var b := await resident_reference()
	if b.is_empty(): return
	if not await travel("a"): return
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before_native: Dictionary = await native_residents()
	var before_io: Dictionary = controller._io_metrics.duplicate(true)
	check(controller.manifest==durable_before,"both dirty resident areas deliberately predate their durable checkpoints")
	check(a.capture.sha256!=durable_before.areas.a.native_sha256 and b.capture.sha256!=durable_before.areas.b.native_sha256,
		"both unsaved edits change complete native identity")
	worker.qualification_delay_hot_completion()
	# Main's real acknowledgement is withheld separately from the native
	# completion. Child controller and worker keep running; no result is mocked.
	host.set_process(false)
	var started := Time.get_ticks_msec()
	if not check(controller.request_travel("b"),"hot transfer admitted before delayed native completion"): return
	if not await until(func() -> bool:return not controller.busy,"production owner deadline quarantines the delayed handoff",45000): return
	check(Time.get_ticks_msec()-started>=30000,"actual production thirty-second owner deadline exercised")
	check(not controller.active_ready and controller._quarantined and host.paused,
		"late handoff leaves gameplay paused and authority visibly quarantined")
	var retained: Dictionary = controller._unresolved_worker.duplicate(true)
	var handoff: Dictionary = controller._resident_handoff.duplicate(true)
	if not check(retained.get("kind","")=="activate_resident" and int(retained.get("token",0))>0,
		"exact native activation token is retained"): return
	check(handoff.get("operation_id","")==retained.operation_id and handoff.source_area=="a" and handoff.target_area=="b",
		"source, target and original operation survive the timeout")
	check(int(host.pending_microscenario_apply.get("serial",-1))==int(handoff.serial),
		"exact Main pending installation serial remains outstanding")
	check(not controller.request_save() and not controller.request_travel("c") and not controller.request_exit("launcher"),
		"new mutations, travel and exit refuse while handoff authority is unresolved")
	if not check(controller.request_retry(),"early Retry checks the same pending native completion"): return
	if not await until(func() -> bool:return not controller.busy,"early Retry remains bounded",1500): return
	check(controller._unresolved_worker==retained and controller._resident_handoff==handoff,
		"early Retry retains both identities without inventing cancellation")
	if not await until(func() -> bool:return worker.persistent_poll(int(retained.token)).get("status","")!="pending",
		"real late native handoff finishes",10000): return
	var completed: Dictionary = worker.persistent_poll(int(retained.token))
	check(completed.get("ok",false) and completed.result.get("committed",false),"late native completion proves an actual resident commit")
	recovery_report["before_recovery"] = controller.status()
	if not check(controller.request_retry(),"Retry consumes the original completed resident handoff"): return
	for index: int in 5: await process_frame
	check(controller.busy and not controller.active_ready and not host.pending_microscenario_apply.is_empty(),
		"recovery waits for real Main acknowledgement before gameplay resumes")
	host.set_process(true)
	if not await until(settled,"exact native/Main acknowledgement restores the retained target",15000): return
	check(controller.active_area=="b" and controller.last_result.get("ok",false),"the committed target becomes active after acknowledgement")
	check(controller._resident_handoff.is_empty() and controller._unresolved_worker.is_empty() \
		and not controller._lease_held and not controller._owner_cleanup_required,
		"handoff and lease retire only after the two acknowledgements")
	check(controller.clock==before_clock,"recovery neither resets nor double-credits game time")
	check(controller.manifest==durable_before,"recovery does not replace dirty RAM with older durable state")
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(before_io[key]),"late handoff recovery performs zero "+key)
	var after_native: Dictionary = await native_residents()
	check(after_native.counters.native_restorations==before_native.counters.native_restorations \
		and after_native.counters.source_constructions==before_native.counters.source_constructions,
		"actual native counters prove no hidden reconstruction during Retry")
	var after_b := await resident_reference()
	check(not after_b.is_empty() and after_b.capture.sha256==b.capture.sha256 and after_b.authoring==b.authoring \
		and int(after_b.handle)==int(b.handle),"target retains complete unsaved native bytes, authoring and original handle")
	if not await verify_edits("b"): return
	if not await travel("a"): return
	var after_a := await resident_reference()
	check(not after_a.is_empty() and after_a.capture.sha256==a.capture.sha256 and after_a.authoring==a.authoring \
		and int(after_a.handle)==int(a.handle),"source also retains complete unsaved native bytes, authoring and original handle")
	if not await verify_edits("a"): return
	if not await delayed_release(a,b,durable_before,before_clock): return
	if not await save_current("recovered dirty resident authorities reach durable Save all"): return
	check(controller.manifest.areas.a.native_sha256==a.capture.sha256 and controller.manifest.areas.b.native_sha256==b.capture.sha256,
		"explicit Save publishes both originally unsaved authorities after successful recovery")
	if not await delayed_cold_commit(): return
	recovery_report["after_recovery"] = controller.status()
	recovery_report["source_native_sha256"] = a.capture.sha256
	recovery_report["target_native_sha256"] = b.capture.sha256
	recovery_report["timeout_msec"] = Time.get_ticks_msec()-started
	controller.qualification_measurement_tag = ""


func delayed_release(a: Dictionary, b: Dictionary, durable_before: Dictionary, before_clock: Dictionary) -> bool:
	phase("late owner release after matching native and Main handoff")
	var before_io: Dictionary = controller._io_metrics.duplicate(true)
	worker.qualification_delay_owner_release()
	var started := Time.get_ticks_msec()
	if not check(controller.request_travel("b"),"hot travel admitted before release completion delay"): return false
	if not await until(func() -> bool:return not controller.busy,"actual release completion exceeds owner deadline",45000): return false
	check(Time.get_ticks_msec()-started>=30000,"release fault uses the production thirty-second deadline")
	var retained: Dictionary = controller._unresolved_worker.duplicate(true)
	if not check(retained.get("kind","")=="release" and not controller.active_ready,
		"release timeout retains its exact completion token and pauses gameplay"): return false
	check(controller._resident_handoff.get("main_acknowledged",false) and controller.active_area=="b",
		"accepted resident identity remains guarded until owner release acknowledges")
	check(host.pending_microscenario_apply.is_empty(),"this release fault occurs after real Main acknowledgement")
	if not await until(func() -> bool:return worker.persistent_poll(int(retained.token)).get("status","")!="pending",
		"actual delayed owner release becomes terminal",10000): return false
	if not check(controller.request_retry(),"Retry acknowledges the original delayed release"): return false
	if not await until(settled,"release recovery resumes the retained target without disk restore",15000): return false
	check(controller.active_area=="b" and controller._resident_handoff.is_empty(),"release acknowledgement retires the resident recovery guard")
	check(int(controller._cache.status().pending_reservations)==0,"release recovery retires every resource reservation")
	check(controller.clock==before_clock and controller.manifest==durable_before,
		"release Retry preserves both resident clock and older durable ledger independently")
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(before_io[key]),"late release recovery performs zero "+key)
	check(int(controller._io_metrics.hot_handoffs)==int(before_io.hot_handoffs)+1,
		"repeated native/Main reconciliation records the actual handoff only once")
	var after_b := await resident_reference()
	check(not after_b.is_empty() and after_b.capture.sha256==b.capture.sha256 and after_b.authoring==b.authoring,
		"release Retry retains target unsaved native and authoring state")
	if not await travel("a"): return false
	var after_a := await resident_reference()
	check(not after_a.is_empty() and after_a.capture.sha256==a.capture.sha256 and after_a.authoring==a.authoring,
		"release Retry retains source unsaved native and authoring state")
	recovery_report["release_recovery"] = controller.status()
	return failures.is_empty()


func delayed_cold_commit() -> bool:
	phase("deferred cold commit with unsaved catch-up and late Main acknowledgement")
	if not check(controller._cache.entry("c").hot.is_empty(),"cold fault target has no resident World yet"): return false
	if not check(controller.request_ahead(12),"native future ticks create legitimate cold-area debt"): return false
	if not await operation_finished("future ticks before cold fault"): return false
	var source := await resident_reference()
	if source.is_empty(): return false
	var before_clock: Dictionary = controller.clock.duplicate(true)
	var before_durable: Dictionary = controller.manifest.duplicate(true)
	worker.qualification_delay_cold_completion()
	host.set_process(false)
	if not check(controller.request_travel("c"),"deferred cold travel admitted before commit delay"): return false
	if not await until(func() -> bool:return not controller.busy,"cold native commit reaches production deadline",50000): return false
	var retained: Dictionary = controller._unresolved_worker.duplicate(true)
	if not check(retained.get("kind","")=="commit" and not controller.active_ready,
		"unbound committed cold target retains its original completion token"): return false
	check(controller._resident_handoff.get("route","")=="COLD" and controller._resident_handoff.target_receipt.is_empty(),
		"cold target identity, envelope, reservation and accounted interval survive the late completion")
	if not await until(func() -> bool:return worker.persistent_poll(int(retained.token)).get("status","")!="pending",
		"actual cold commit completes after the host deadline",10000): return false
	var reference: Dictionary = worker.qualification_cold_reference()
	if not check(str(reference.get("sha256","")).length()==64 and int(reference.completed_tick)>0,
		"real committed cold target has a complete native hash after actual catch-up"): return false
	var retry_io: Dictionary = controller._io_metrics.duplicate(true)
	if not check(controller.request_retry(),"Retry binds the exact committed cold target"): return false
	for index: int in 5: await process_frame
	check(controller.busy and not controller.active_ready,"cold recovery waits for original Main acknowledgement")
	host.set_process(true)
	if not await until(settled,"cold target resumes without regeneration or repeated catch-up",15000): return false
	check(controller.active_area=="c" and controller._resident_handoff.is_empty(),"late cold target becomes the one acknowledged resident authority")
	check(int(controller._cache.status().pending_reservations)==0,"cold recovery consumes and retires its original preparation reservation")
	check(int(controller.clock.game_ticks)==int(before_clock.game_ticks) \
		and int(controller.clock.areas.c.native_ticks)==int(reference.completed_tick) \
		and int(controller.clock.areas.c.accounted_ticks)==int(before_clock.game_ticks),
		"cold recovery admits the completed catch-up interval exactly once")
	check(controller.manifest==before_durable,"cold recovery keeps durable and newer RAM states independent")
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(retry_io[key]),"cold Retry performs zero repeated "+key)
	var actual := await resident_reference()
	check(not actual.is_empty() and actual.capture.sha256==reference.sha256 \
		and actual.capture.physical_hash==reference.physical_hash,
		"cold Retry retains complete committed native bytes and delayed reaction state")
	if not await travel("a"): return false
	var retained_source := await resident_reference()
	check(not retained_source.is_empty() and retained_source.capture.sha256==source.capture.sha256 \
		and retained_source.authoring==source.authoring,
		"cold Retry also preserves the source's unsaved native progression and authoring")
	if not await save_current("cold recovery reaches explicit durable Save all"): return false
	check(controller.manifest.areas.c.native_sha256==reference.sha256,
		"Save acknowledges the exact recovered cold target rather than its older checkpoint")
	recovery_report["cold_recovery"] = controller.status()
	return failures.is_empty()


func _finish() -> void:
	if host!=null: host.set_process(true)
	check(recovery_report.has("before_recovery") and recovery_report.has("after_recovery") \
		and recovery_report.has("release_recovery") and recovery_report.has("cold_recovery"),
		"late native and Main acknowledgement campaign reached its complete recovery assertions")
	recovery_report.merge({"checks":checks,"failures":failures.duplicate(),"graphical":graphical,"process_id":OS.get_process_id()},true)
	if not output.is_empty(): write_json(output.path_join("hot-recovery.json"),recovery_report)
	print("GEN006_RAMCACHE_HOT_RECOVERY ",JSON.stringify({"checks":checks,"failures":failures.size(),"graphical":graphical}))
	await super._finish()
