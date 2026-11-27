extends "res://tests/test_persistent_areas_workbench.gd"

# Actual Main, native owner and Workbench qualification. The parent owns
# platform/layout/readback/save-and-new-process scaffolding; this slice records
# cache-path work and native receipts separately from end-to-end elapsed time.
var hot_samples: Array[Dictionary] = []
var warm_samples: Array[Dictionary] = []
var cache_native_before: Dictionary = {}
var cache_native_after: Dictionary = {}
var cache_filesystem_before: Dictionary = {}
var cache_filesystem_after: Dictionary = {}
var hot_sample_count := 30
var warm_sample_count := 30
var stage_one_only := false
var cache_ui_observations: Array[Dictionary] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ramcache-hot-samples="): hot_sample_count = clampi(int(argument.trim_prefix("--ramcache-hot-samples=")),1,300)
		if argument.begins_with("--ramcache-warm-samples="): warm_sample_count = clampi(int(argument.trim_prefix("--ramcache-warm-samples=")),1,100)
		if argument=="--ramcache-stage1-only": stage_one_only = true
	super._initialize()


func configure_cache(changes: Dictionary) -> bool:
	var configuration: Dictionary = controller._cache_configuration.duplicate(true)
	configuration.merge(changes,true)
	if not check(controller.request_cache_configuration(configuration),"cache configuration admitted"): return false
	return await operation_finished("cache policy transaction")


func native_residents() -> Dictionary:
	var id: String = controller.AreaStore.new_nonce()
	var admitted: Dictionary = worker.persistent_request({"kind":"resident_status","operation_id":id})
	if not check(admitted.get("ok",false),"native resident observation admitted"): return {}
	var value: Dictionary = {}
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		value = worker.persistent_poll(int(admitted.token))
		if value.get("status","") in ["complete","failed"]: break
		await process_frame
	if not check(value.get("status","") in ["complete","failed"],"native resident observation completed"): return {}
	if not check(value.get("ok",false),"native resident observation succeeded"): return {}
	return value.result


func travel(id: String) -> bool:
	phase("RAM-cache travel to "+id)
	if not await until(settled,"before cache travel to "+id): return false
	if not check(controller.request_travel(id),"cache travel request to "+id): return false
	if not await operation_finished("cache travel to "+id): return false
	return check(controller.active_area==id and host.world_extent==Vector2i(512,512),
		"selected area identity acknowledged by actual Main: "+id)


func exercise_write() -> void:
	if not check(controller.active_area=="a" and int(controller.clock.game_ticks)==0,
		"fresh cache qualification begins paused in Area A"): return
	if not await configure_cache({"enabled":true,"deferred":true,"background":false,"prefetch":false,
		"budget_bytes":512*1024*1024}): return
	var original_native := {}
	for id: String in Fixtures.IDS: original_native[id] = str(controller.manifest.areas[id].native_sha256)
	# Establish three actual instantiated Worlds, and prove the same handles
	# survive the user's requested A/B/C return sequence.
	for id: String in ["b","c","a","b","a"]:
		if not await travel(id): return
	var resident: Dictionary = await native_residents()
	if resident.is_empty(): return
	check(resident.entries.size()==3 and resident.inactive.size()==2,
		"one active and two inactive genuinely instantiated native Worlds exist")
	var handles := {}
	for receipt: Dictionary in resident.entries:
		handles[str(receipt.identity.area_id)] = int(receipt.handle)
	cache_native_before = resident.counters.duplicate(true)
	cache_filesystem_before = await controller._io("io_telemetry",[])
	if not check(cache_filesystem_before.get("available",false),"actual native storage filesystem telemetry is available"): return
	var before_io: Dictionary = controller._io_metrics.duplicate(true)
	for index: int in hot_sample_count:
		var id: String = Fixtures.IDS[(Fixtures.IDS.find(controller.active_area)+1)%3]
		if not check(AreaClock.debt(controller.clock,id)==0,"hot measurement target has exactly zero debt"): return
		if not await travel(id): return
		var record: Dictionary = controller.metrics.operation_records.back().duplicate(true)
		hot_samples.append(record)
		check(record.residency=="HOT" and int(record.native_ticks_executed)==0,
			"qualified hot sample transfers native ownership without hidden catch-up")
		for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
			check(int(record.io_before[key])==int(record.io_after[key]),"hot sample performs zero "+key)
		check(int(controller._cache.entry(id).hot.handle)==int(handles[id]),
			"hot return reuses the exact retained native handle")
	resident = await native_residents()
	if resident.is_empty(): return
	cache_native_after = resident.counters.duplicate(true)
	cache_filesystem_after = await controller._io("io_telemetry",[])
	for key: String in ["checkpoint_read_requests","checkpoint_read_bytes","read_system_calls","write_system_calls",
		"write_bytes","file_flush_calls","directory_flush_calls","publication_calls"]:
		check(int(cache_filesystem_before[key])==int(cache_filesystem_after[key]),"native filesystem counters prove zero hot-path "+key)
	for key: String in ["native_restorations","source_constructions","captures"]:
		check(int(cache_native_before[key])==int(cache_native_after[key]),"native counters confirm hot sequence performs no "+key)
	check(int(cache_native_after.hot_activations)-int(cache_native_before.hot_activations)==hot_sample_count,
		"every measured hot sample performs one native ownership handoff")
	for key: String in ["profile_read_calls","native_deserializations","source_constructions","synchronous_publications"]:
		check(int(controller._io_metrics[key])==int(before_io[key]),"whole qualified hot sequence has zero "+key)
	if not await save_current("zero-debt hot-state identity checkpoint"): return
	for id: String in Fixtures.IDS:
		check(str(controller.manifest.areas[id].native_sha256)==str(original_native[id]),
			"complete native bytes unchanged by zero-debt hot switches in "+id)
	await screenshot("ramcache-hot-three-worlds")
	if stage_one_only:
		await save_expectations()
		return
	await exercise_warm_benchmark()
	if not failures.is_empty(): return
	await cache_layout_checks("after-travel",true)
	if not failures.is_empty(): return
	await exercise_live_retention()
	if not failures.is_empty(): return
	await exercise_pressure()
	if not failures.is_empty(): return
	await exercise_prefetch()
	if not failures.is_empty(): return
	await exercise_deferred_writeback()
	if not failures.is_empty(): return
	await save_expectations()


func exercise_live_retention() -> void:
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		if id=="a":
			var fixture := Fixtures.description(id)
			if not check(bench.paint(Vector2i(fixture.empty_edit[0],fixture.empty_edit[1]),0),"paused Empty edit admitted before autosave dirtiness observation"): return
			if not await until(func() -> bool:return bool(controller.status().areas.a.dirty),
				"paused edit visibly becomes unsaved without waiting for a native tick"): return
			controller.panel._open_cache()
			check(controller.panel._cache_dialog.visible,"open current RAM cache settings to inspect the paused edit")
			cache_text_checks("paused-empty-edit")
			controller.panel._cache_dialog.hide()
		if not await edit_area(id): return
		if id=="c":
			var native_before := str(controller.manifest.areas.c.native_sha256)
			var source_before := str(controller.manifest.areas.c.authored_source_sha256)
			if not check(bench.request_flatten().get("ok",false),"ordinary Flatten admitted in the persistent gallery"): return
			if not await until(func() -> bool:return not bench.is_flatten_pending(),"actual flattened starting baseline adopted"): return
			if not check(bench.get_flatten_status().get("status","")=="complete" and not bench._material_baseline.is_empty(),
				"Flatten supplies a real authored material baseline"): return
			if not await save_current("flattened authoring with full dynamic continuation saved"): return
			check(str(controller.manifest.areas.c.native_sha256)==native_before \
				and str(controller.manifest.areas.c.authored_source_sha256)==source_before,
				"Flatten does not replace dynamic native state or original construction identity")
		host.camera_origin = Vector2(16+Fixtures.IDS.find(id)*32,24+Fixtures.IDS.find(id)*24)
		host.current_view_size = Vector2i(256,256)
		bench._camera.select(0)
		bench._zoom = 1
		host.update_worker_frame_state()
	if not await travel("a"): return
	check(host.camera_origin==Vector2(16,24) and host.current_view_size==Vector2i(256,256),
		"hot return restores Area A's independent camera envelope")
	var before := await native_materials(Rect2i(0,0,512,512))
	var tick := int(host.latest_snapshot.tick_index)
	if not check(bench.toggle_pause(),"real native gameplay starts in retained Area A"): return
	if not await until(func() -> bool:return int(host.latest_snapshot.tick_index)>=tick+32,"retained active fire completes 32 native ticks"): return
	check(bench.toggle_pause(),"retained native World pauses")
	if not await save_current("active fire state saved"): return
	var after := await native_materials(Rect2i(0,0,512,512))
	check(material_digest(before.materials)!=material_digest(after.materials),"retained fire continues genuine native material reactions")
	for id: String in ["b","c","a"]:
		if not await travel(id): return
		if not await verify_edits(id): return
		if id=="c": check(not bench._material_baseline.is_empty() and bench.applied.edits.is_empty(),
			"hot re-entry preserves the deliberately flattened starting map")
		while AreaClock.debt(controller.clock,id)>0:
			if not check(controller.request_catch_up(),"hot debt retry admitted"): return
			if not await operation_finished("hot debt paid"): return
	check(int(controller.clock.game_ticks)>0,"global time records completed active native ticks")
	var game_before := int(controller.clock.game_ticks)
	if not check(controller.request_ahead(12),"Simulate Ahead works on an active resident World"): return
	if not await operation_finished("resident Simulate Ahead"): return
	check(int(controller.clock.game_ticks)-game_before==int(controller.operation.completed_ticks),
		"active resident Ahead credits exactly completed future ticks")
	await screenshot("ramcache-native-dynamic-state")


func exercise_warm_benchmark() -> void:
	# Match the HOT and donor COLD workloads exactly: the original native
	# capsules at G=0, with no edits, fire progression or Ahead between samples.
	if not check(host.paused and int(controller.clock.game_ticks)==0,
		"WARM benchmark uses the same paused initial native states as HOT and COLD"): return
	var native_identity := {}
	for id: String in Fixtures.IDS: native_identity[id] = str(controller.manifest.areas[id].native_sha256)
	if not check(controller.request_eviction(),"safe inactive eviction admitted"): return
	if not await operation_finished("hot-to-warm demotion"): return
	check(int(controller._cache.status().hot_count)==1 and int(controller._cache.status().warm_count)>=1,
		"inactive native allocations release while validated RAM checkpoints remain warm")
	var target_counts := {"a":0,"b":0,"c":0}
	for index: int in warm_sample_count:
		# Use the same cyclic area mix as HOT/COLD. Safe eviction can discard an
		# older WARM entry, so stage that exact validated target outside timing
		# instead of selecting whichever smaller fixture happens to remain warm.
		var target: String = Fixtures.IDS[(Fixtures.IDS.find(controller.active_area)+1)%3]
		var staging: Dictionary = await stage_warm_benchmark_target(target)
		if not staging.get("ok",false): return
		if not check(str(controller._cache.entry(target).warm.sha256)==str(native_identity[target]),
			"staged WARM target retains its full original native capsule identity"): return
		var filesystem_before: Dictionary = await controller._io("io_telemetry",[])
		var native_before: Dictionary = await native_residents()
		if not await travel(target): return
		var record: Dictionary = controller.metrics.operation_records.back().duplicate(true)
		var filesystem_after: Dictionary = await controller._io("io_telemetry",[])
		var native_after: Dictionary = await native_residents()
		record["filesystem_before"] = filesystem_before
		record["filesystem_after"] = filesystem_after
		record["native_before"] = native_before.get("counters",{})
		record["native_after"] = native_after.get("counters",{})
		record["benchmark_staging"] = staging
		warm_samples.append(record)
		target_counts[target] += 1
		check(int(record.debt_before_ticks)==0 and int(record.native_ticks_executed)==0,
			"warm benchmark sample has zero debt and zero catch-up ticks")
		check(record.residency=="WARM","warm transition classification is distinct from hot native residency")
		check(int(record.io_after.profile_read_calls)==int(record.io_before.profile_read_calls),"warm transition performs no target checkpoint filesystem read")
		check(int(record.io_after.native_deserializations)==int(record.io_before.native_deserializations)+1,
			"warm transition reports its real native deserialization")
		for key: String in ["checkpoint_read_requests","checkpoint_read_bytes","read_system_calls","write_system_calls","publication_calls"]:
			check(int(filesystem_before.get(key,-1))==int(filesystem_after.get(key,-2)),"actual native telemetry proves zero WARM-path "+key)
		check(int(native_after.get("counters",{}).get("native_restorations",-1)) \
			==int(native_before.get("counters",{}).get("native_restorations",-2))+1,
			"actual native counter proves one restoration per WARM sample")
		if not await save_current("warm sample durable before next demotion"): return
		if not check(controller.request_eviction(),"repeatable warm eviction admitted"): return
		if not await operation_finished("warm sample demotion"): return
	check(int(controller.clock.game_ticks)==0,"all WARM timing samples retain the same initial global frontier")
	for id: String in Fixtures.IDS:
		if warm_sample_count>=3:
			check(int(target_counts[id])>0,"WARM benchmark exercises area "+id)
		if warm_sample_count%3==0:
			check(int(target_counts[id])==warm_sample_count/3,"WARM benchmark has a balanced cyclic target count in "+id)
		check(str(controller.manifest.areas[id].native_sha256)==str(native_identity[id]),
			"full native initial capsule remains unchanged throughout WARM timing in "+id)
	samples.append({"kind":"warm_benchmark_area_mix","target_counts":target_counts,"samples":warm_sample_count})


func stage_warm_benchmark_target(target: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	var entry: Dictionary = controller._cache.entry(target)
	if not check(entry.hot.is_empty(),"WARM measurement target has no instantiated native owner"): return {}
	if not entry.warm.is_empty():
		return {"ok":true,"area_id":target,"outside_measured_interval":true,"read_from_disk":false,
			"elapsed_us":Time.get_ticks_usec()-started}
	# Reserve before loading/copying the immutable checkpoint. This temporary
	# setup work is recorded separately and never included in a WARM sample.
	var reservation: String = controller.AreaStore.new_nonce()
	var maximum_bytes: int = 3*(controller.AreaStore.MAX_NATIVE_BYTES+controller.AreaStore.MAX_METADATA_BYTES)
	var reserved: Dictionary = controller._cache.reserve(reservation,target,maximum_bytes)
	if not check(reserved.get("ok",false),"WARM fixture staging has an admitted resource reservation"): return {}
	var before: Dictionary = await controller._io("io_telemetry",[])
	var loaded: Dictionary = await controller._io("read_area",[target])
	controller._io_metrics.profile_read_calls += 1
	if loaded.get("ok",false): controller._io_metrics.profile_read_bytes += loaded.capture.bytes.size()
	if not check(loaded.get("ok",false),"WARM fixture staging reads a complete validated durable checkpoint"):
		controller._cache.release_reservation(reservation)
		return {}
	var retained: Dictionary = controller._cache.retain_warm(target,loaded.capture,loaded.authoring,
		int(loaded.record.mutation_generation),str(loaded.record.incarnation),reservation)
	if not check(retained.get("ok",false),"WARM fixture staging admits the exact checkpoint under its budget"):
		controller._cache.release_reservation(reservation)
		return {}
	return {"ok":true,"area_id":target,"outside_measured_interval":true,"read_from_disk":true,
		"elapsed_us":Time.get_ticks_usec()-started,"reserved_bytes":maximum_bytes,
		"native_sha256":str(loaded.capture.sha256),"filesystem_before":before,
		"filesystem_after":await controller._io("io_telemetry",[])}


func exercise_pressure() -> void:
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		while AreaClock.debt(controller.clock,id)>0:
			if not check(controller.request_catch_up(),"edited pressure-fixture debt payment admitted"): return
			if not await operation_finished("edited pressure-fixture debt payment"): return
	if not await save_current("edited resident authorities durable before cache pressure"): return
	if not check(controller.request_eviction(),"edited-state safe eviction admitted"): return
	if not await operation_finished("edited-state demotion before budget pressure"): return
	var bound := int(controller._cache.entry(controller.active_area).hot.native_reservation_bytes)
	for budget: int in [2*bound+12*1024*1024,bound+6*1024*1024]:
		if not await configure_cache({"budget_bytes":budget}): return
		check(int(controller._cache.status().used_bytes)<=budget,"retained cache respects a reduced one/two-World admission budget")
	if not await configure_cache({"budget_bytes":1024*1024}): return
	check(controller._cache.status().over_budget and int(controller._cache.status().hot_count)==1,
		"too-small budget visibly pins only the mandatory active World")
	var pressured_target: String = Fixtures.IDS[(Fixtures.IDS.find(controller.active_area)+1)%3]
	if not await travel(pressured_target): return
	check(controller.operation.get("cache_budget_fallback",false),"exhausted cache uses explicit durable cold fallback")
	if not await verify_edits(pressured_target): return
	if not await configure_cache({"budget_bytes":512*1024*1024}): return
	if not await configure_cache({"enabled":false}): return
	var target: String = Fixtures.IDS[(Fixtures.IDS.find(controller.active_area)+1)%3]
	if not await travel(target): return
	check(not controller._cache_configuration.enabled,"cache-disabled original cold path remains operational")
	if not await verify_edits(target): return
	if not await configure_cache({"enabled":true,"budget_bytes":512*1024*1024}): return


func exercise_prefetch() -> void:
	var tick := int(host.latest_snapshot.tick_index)
	if not check(bench.toggle_pause(),"active native gameplay runs during destination preparation"): return
	if not await until(func() -> bool:return int(host.latest_snapshot.tick_index)>=tick+8,"prefetch begins with legitimate inactive debt"): return
	if not await configure_cache({"prefetch":true,"background":false}): return
	var game_before := int(controller.clock.game_ticks)
	var target: String = Fixtures.IDS[(Fixtures.IDS.find(controller.active_area)+1)%3]
	if not check(controller.request_prefetch(target),"explicit destination intent starts preparation before travel"): return
	if not await until(func() -> bool:
		return not controller._prefetch_busy and not controller._cache.entry(target).hot.is_empty(),
		"destination becomes a genuine inactive hot World before activation",90000): return
	check(int(controller.clock.game_ticks)>game_before,"active native gameplay advances global time while another World prepares")
	check(int(controller._io_metrics.prefetch_native_ticks)>0,"private preparation executes legitimate native catch-up before arrival")
	if not host.paused: check(bench.toggle_pause(),"active gameplay pauses after successful background preparation")
	var receipt: Dictionary = controller._cache.entry(target).hot.duplicate(true)
	var before := int(controller._io_metrics.native_deserializations)
	if not await travel(target): return
	check(int(controller._cache.entry(target).hot.handle)==int(receipt.handle),"arrival reuses the exact prefetched native World")
	check(int(controller._io_metrics.native_deserializations)==before,"prefetched arrival does not deserialize again")
	check(controller.operation.get("prefetch_hit",false),"arrival records a real preparation-before-activation hit")
	var preparation_id := str(controller.operation.get("prefetch_operation_id",""))
	var observed_preparation := false
	for record: Dictionary in controller.metrics.prefetch_records:
		if str(record.operation_id)==preparation_id:
			observed_preparation = record.status=="completed" and record.area_id==target \
				and int(record.native_work.get("receipt",{}).get("handle",-1))==int(receipt.handle) \
				and int(record.frame_observations)>0 and float(record.max_main_frame_ms)>0.0
			var phases: Dictionary = record.phase_timestamps
			check(int(phases.worker_admission_started_usec)<=int(phases.worker_admission_finished_usec) \
				and int(phases.worker_admission_finished_usec)<=int(phases.native_result_observed_usec) \
				and int(phases.native_result_observed_usec)<=int(phases.cache_admission_started_usec) \
				and int(phases.cache_admission_started_usec)<=int(phases.cache_admission_finished_usec),
				"prefetch phase timestamps bound admission, private work observation and cache adoption")
			check(int(record.worst_frame_start_usec)<int(record.worst_frame_end_usec) \
				and int(record.worst_frame_end_usec)>=int(record.start_usec),
				"prefetch frame-gap evidence identifies its actual monotonic interval")
	check(observed_preparation,"prefetched arrival is correlated with the exact prepared handle and measured frame interval")
	var alternatives: Array = controller.Connectivity.adjacent(target)
	controller.request_prefetch(str(alternatives[0]))
	controller.request_prefetch(str(alternatives[1]))
	if not await travel(str(alternatives[1])): return
	check(controller.active_area==str(alternatives[1]),"rapid reversed destination intent yields to the explicit transition")
	if not await configure_cache({"prefetch":false}): return


func layout_checks() -> void:
	await super.layout_checks()
	await cache_layout_checks("startup")


func cache_text_checks(label: String) -> void:
	var state: Dictionary = controller.status()
	controller.panel.update_state(state)
	var cache: Dictionary = state.cache
	var counters: Dictionary = cache.counters
	var configuration: Dictionary = state.cache_configuration
	var summary: String = controller.panel._cache_summary.text
	for expected_text: String in [
		"HOT %d · WARM %d · COLD %d" % [cache.hot_count,cache.warm_count,cache.cold_count],
		"%d HOT hits · %d WARM hits · %d COLD misses" % [counters.hot_hits,counters.warm_hits,counters.cold_misses],
		"Native capacity estimate %.2f MiB (last observed)" % (float(cache.native_bytes)/1048576.0),
		"growth reserve %.2f MiB" % (float(cache.native_headroom_bytes)/1048576.0),
		"WARM %.2f MiB; authoring %.2f MiB" % [float(cache.warm_bytes)/1048576.0,float(cache.authoring_bytes)/1048576.0],
		"preparation reserved %.2f MiB" % (float(cache.reserved_bytes)/1048576.0),
		"publication %.2f / %.0f MiB" % [float(cache.essential_publication_reserved_bytes)/1048576.0,float(cache.essential_publication_cap_bytes)/1048576.0],
		"not process RSS",
	]:
		check(summary.contains(expected_text),"actual cache UI observes "+expected_text)
	var area_text: String = controller.panel._cache_areas.text
	for area: Dictionary in Fixtures.AREAS:
		var record: Dictionary = state.areas[area.id]
		check(area_text.contains("%s · %s: %s\n  Behind game time %.2f s; %s" % [area.letter,area.label,
			record.residency,float(record.debt_ticks)/60.0,record.durability]),
			"actual area identity/tier/debt/unsaved state remains visible: "+str(area.id))
	check(area_text.contains("Background publication: "+str(state.writeback.get("status","idle"))) \
		and area_text.contains("Destination preparation: "+str(state.prefetch.get("message","idle"))),
		"actual saving and destination readiness status remain visible")
	check(controller.panel._cache_enabled.button_pressed==bool(configuration.enabled) \
		and controller.panel._deferred.button_pressed==bool(configuration.deferred) \
		and controller.panel._background.button_pressed==bool(configuration.background) \
		and controller.panel._prefetch.button_pressed==bool(configuration.prefetch),
		"cache and persistence controls reflect the actual configuration")
	check(controller.panel._cache_save.disabled==(bool(state.busy) or not bool(state.ready)),
		"Save availability reflects actual owner readiness")
	cache_ui_observations.append({"label":label,"viewport":root.size,"summary":summary,"areas":area_text,
		"cache":cache.duplicate(true),"configuration":configuration.duplicate(true),"ready":bool(state.ready)})


func cache_layout_checks(label: String, verify_export: bool = false) -> void:
	if not graphical: return
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		await process_frame
		controller.panel._open_cache()
		for frame: int in 2: await process_frame
		var dialog: AcceptDialog = controller.panel._cache_dialog
		cache_text_checks(label+"-"+str(dimensions.y))
		check(dialog.visible,"RAM cache settings window is displayed at "+str(dimensions))
		check(dialog.size.y<=dimensions.y-48 and dialog.size.x<=dimensions.x-32,
			"cache modal stays within the usable viewport")
		check(Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(dialog.get_ok_button().get_global_rect()),
			"cache modal Close remains reachable in its fixed footer")
		var scroll: ScrollContainer = dialog.find_children("*","ScrollContainer",true,false)[0]
		check(scroll.get_global_rect().encloses(controller.panel._cache_save.get_global_rect()),
			"Save all remains visible without scrolling at "+str(dimensions))
		var export_button: Button
		for button: Button in dialog.find_children("*","Button",true,false):
			if button.text=="Export diagnostics": export_button = button
		check(export_button!=null and scroll.get_global_rect().encloses(export_button.get_global_rect()),
			"diagnostics export remains visible without scrolling")
		if verify_export and dimensions.y==720:
			var observed: Dictionary = controller.status().cache
			check(int(observed.counters.hot_hits)>0 and int(observed.counters.warm_hits)>0 \
				and int(observed.counters.cold_misses)>0,"visible counters include actual HOT/WARM/COLD lookups")
			export_button.pressed.emit()
			check(controller.message.begins_with("Diagnostics exported to "),"real diagnostics button exports the observed state")
			var exported: Variant = JSON.parse_string(FileAccess.get_file_as_string(controller.message.trim_prefix("Diagnostics exported to ")))
			check(exported is Dictionary,"exported cache diagnostics decode as a dictionary")
			if exported is Dictionary:
				for key: String in observed.counters:
					check(int(exported.status.cache.counters.get(key,-1))==int(observed.counters[key]),
						"exported "+key+" counter matches the actual UI owner")
				for key: String in ["native_bytes","native_headroom_bytes","warm_bytes","authoring_bytes","reserved_bytes","essential_publication_reserved_bytes"]:
					check(int(exported.status.cache[key])==int(observed[key]),"exported "+key+" matches actual accounting")
				check(str(exported.memory_scope).contains("not process RSS"),"export distinguishes measured Godot bytes from process RSS")
		await screenshot("ramcache-controls-"+str(dimensions.y)+( "" if label=="startup" else "-"+label))
		dialog.hide()
	root.size = Vector2i(1280,720)
	await process_frame


func exercise_deferred_writeback() -> void:
	if not await configure_cache({"background":true,"deferred":true}): return
	# Native gameplay continues after the short snapshot boundary, while the
	# same real I/O Thread serializes and publishes the immutable older state.
	var tick := int(host.latest_snapshot.tick_index)
	if not check(bench.toggle_pause(),"native play starts for write-behind overlap"): return
	if not await until(func() -> bool:return int(host.latest_snapshot.tick_index)>=tick+8,"native work before background saving"): return
	controller._last_background_msec = 0
	if not await until(func() -> bool:return controller._writeback.busy(),"real asynchronous publication starts",30000): return
	var queued_tick := int(host.latest_snapshot.tick_index)
	var target: String = Fixtures.IDS[(Fixtures.IDS.find(controller.active_area)+1)%3]
	if not controller._cache.entry(target).hot.is_empty():
		if not await travel(target): return
		check(int(controller.operation.io_before.synchronous_publications)==int(controller._io_metrics.synchronous_publications),
			"deferred hot travel does not synchronously flush an in-flight background save")
	if not host.paused: check(bench.toggle_pause(),"native play pauses after write-behind overlap")
	if not await until(func() -> bool:return not controller._writeback.busy(),"background publication acknowledges",90000): return
	check(int(controller._writeback.status().metrics.completed)>0,"background checkpoint completed on its actual I/O thread")
	samples.append({"kind":"writeback_overlap","queued_active_tick":queued_tick,
		"global_game_tick":int(controller.clock.game_ticks),"writer":controller._writeback.status()})
	if not await save_current("manual Save all waits for newest resident authority"): return
	check(int(controller._cache.status().dirty_count)==0 and not controller._resident_clock_dirty,
		"manual Save all acknowledges every dirty area and global clock")
	if not await configure_cache({"background":false}): return


func save_expectations() -> void:
	for id: String in Fixtures.IDS:
		if controller.active_area!=id and not await travel(id): return
		while AreaClock.debt(controller.clock,id)>0:
			if not check(controller.request_catch_up(),"final bounded debt payment admitted"): return
			if not await operation_finished("final debt payment"): return
	if not await save_current("all cache state durable for genuinely new-process reopening"): return
	expected = {"version":1,"session_id":controller.manifest.session_id,"clock":controller.clock.duplicate(true),"areas":{}}
	for id: String in Fixtures.IDS:
		var record: Dictionary = controller.manifest.areas[id]
		expected.areas[id] = {"physical_hash":record.physical_hash,"native_sha256":record.native_sha256,
			"completed_tick":record.completed_tick,"authored_source_sha256":record.authored_source_sha256,
			"authoring_sha256":record.authoring_sha256,
			"flatten_sha256":str(controller._cache.entry(id).authoring.get("material_baseline",{}).get("sha256",""))}
	write_json(output.path_join("expected-reopen.json"),expected)


func exercise_reopen() -> void:
	await super.exercise_reopen()
	if not failures.is_empty(): return
	if not await travel("c"): return
	check(str(bench._material_baseline.get("sha256",""))==str(expected.areas.c.get("flatten_sha256","")),
		"fresh process restores the exact flattened starting baseline alongside dynamic continuation")


func _finish() -> void:
	if controller!=null and not output.is_empty():
		write_json(output.path_join("ramcache-"+mode+".json"),{"schema":"gen006-ramcache-workbench-v1",
			"mode":mode,"process_id":OS.get_process_id(),"graphical":graphical,"checks":checks,"failures":failures,
			"hot_samples":hot_samples,"warm_samples":warm_samples,"native_before":cache_native_before,
			"cache_ui_observations":cache_ui_observations,
			"native_after":cache_native_after,"filesystem_before":cache_filesystem_before,
			"filesystem_after":cache_filesystem_after,"evidence":controller.evidence()})
	print("GEN006_RAMCACHE ",JSON.stringify({"checks":checks,"failures":failures,"mode":mode,
		"hot_samples":hot_samples.size(),"warm_samples":warm_samples.size(),"graphical":graphical,"pid":OS.get_process_id()}))
	await super._finish()
