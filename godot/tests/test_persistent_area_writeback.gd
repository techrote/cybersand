extends SceneTree
## Actual Thread + native CYPS + native OS-backed profile publication. The live
## native owner advances after an immutable batch starts; only captured state
## is acknowledged. Separate process/crash orchestration invokes this fixture.

const Writer = preload("res://scripts/persistent_area_writeback.gd")
const Store = preload("res://scripts/persistent_area_store.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const COMPATIBILITY := "ramcache-writeback-cyps2-test-v1"
var checks := 0
var failures := 0
var profile := ""
var mode := "unit"
var evidence := ""
var barrier := ""
var expected_tick := -1
var fixture: Dictionary
var authoring: Dictionary
var events: Array = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--writeback-profile="): profile = argument.trim_prefix("--writeback-profile=")
		if argument.begins_with("--writeback-mode="): mode = argument.trim_prefix("--writeback-mode=")
		if argument.begins_with("--writeback-evidence="): evidence = argument.trim_prefix("--writeback-evidence=")
		if argument.begins_with("--writeback-barrier="): barrier = argument.trim_prefix("--writeback-barrier=")
		if argument.begins_with("--writeback-expected-tick="): expected_tick = argument.trim_prefix("--writeback-expected-tick=").to_int()
	if profile.is_empty(): profile = ProjectSettings.globalize_path("user://ramcache-writeback-"+Store.new_nonce())
	run.call_deferred()


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("RAMCACHE writebehind: "+label)
	return value


func capture() -> Dictionary:
	return fixture.bridge.capture_workbench_continuation(fixture.world)


func update(capsule: Dictionary, incarnation: String, mutation: int) -> Dictionary:
	return {"capture":capsule,"authoring":authoring.duplicate(true),"incarnation":incarnation,"mutation_generation":mutation}


func initialize_profile(store: RefCounted) -> Dictionary:
	var opened: Dictionary = store.open_profile(profile,"writeback-test",COMPATIBILITY)
	if not check(opened.get("ok",false) and opened.get("fresh",false),"fresh isolated native storage owner opens"): return {}
	var initial := capture()
	var updates := {}
	for id: String in Clock.AREA_IDS: updates[id] = update(initial,Store.new_nonce(),0)
	var owner := {"operation_id":Store.new_nonce(),"native_tick":0,"physical_hash":initial.physical_hash}
	var prepared: Dictionary = store.prepare_commit({"active_area":"a","clock":Clock.fresh()},updates,0,Store.new_nonce(),owner)
	if not check(prepared.get("ok",false),"all three native snapshots stage"): return {}
	var committed: Dictionary = store.commit_prepared(prepared.receipt,owner)
	check(committed.get("ok",false),"first manifest publishes")
	return committed.get("manifest",{})


func wait_writer(writer: RefCounted) -> Dictionary:
	var frames := 0
	var deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec() < deadline:
		var polled: Dictionary = writer.poll()
		if polled.status == "complete":
			events.append({"frames_during_publication":frames,"observation":polled.observation,
				"result":polled.result})
			return polled.result
		if polled.status == "idle": return {"ok":false,"error":"Writer lost its in-flight batch"}
		frames += 1
		await process_frame
	check(false,"background I/O finishes within watchdog")
	return {"ok":false,"error":"write-behind watchdog"}


func verify_reopened(store: RefCounted) -> void:
	var opened: Dictionary = store.open_profile(profile,"writeback-test",COMPATIBILITY)
	if not check(opened.get("ok",false) and not opened.get("fresh",true),"new storage owner restores existing manifest"): return
	var loaded: Dictionary = store.read_area("a")
	if not check(loaded.get("ok",false),"reopened complete native capsule validates"): return
	var options := Fixture.restore_options(fixture,loaded.capture,Store.new_nonce())
	var token := Fixture.prepare(fixture,options)
	check(token > 0 and fixture.bridge.commit_liquid_world(fixture.world,token),"reopened checkpoint restores a real native World")
	if expected_tick == 0:
		check(fixture.world.material_at(65,60) == 1 and fixture.world.material_at(72,60) == 0,
			"unpublished RAM-only edits are absent from the prior durable native state")
	else:
		check(fixture.world.material_at(65,60) == 0 and fixture.world.material_at(72,60) == 58,
			"explicit Empty and placed material survive source-independent native restore")
	check(int(fixture.world.get_tick_index()) == int(opened.manifest.clock.areas.a.native_ticks),"recovered actual native tick agrees with durable clock")
	if expected_tick >= 0: check(int(fixture.world.get_tick_index()) == expected_tick,"recovery matches the specific publication boundary's expected tick")
	var restored := capture()
	check(restored.bytes == loaded.capture.bytes,"restored complete supported continuation is byte-exact")
	events.append({"fresh_owner_manifest":opened.manifest,"native_sha256":restored.sha256,
		"native_tick":restored.completed_tick,"physical_hash":restored.physical_hash})


func hold_for_process_death(phase: String, manifest: Dictionary, details: Dictionary = {}) -> void:
	# Test-only explicit OS-death rendezvous. No artificial exception or cleanup
	# substitutes for termination of the actual Godot/native storage process.
	var marker := {"phase":phase,"pid":OS.get_process_id(),
		"session_id":str(manifest.get("session_id","")),"revision":int(manifest.get("revision",-1))}
	marker.merge(details)
	print("GEN006_RAMCACHE_BARRIER ",JSON.stringify(marker))
	var gate := Semaphore.new()
	gate.wait()


func run() -> void:
	fixture = Fixture.create()
	if not check(not fixture.has("error"),"real native fixture constructs"): finish(); return
	var setup := Setup.fresh(fixture.bridge.default_liquid_policy(),Vector2i(512,512))
	setup.edits = [[65,60,0,0],[72,60,0,58]]
	authoring = {"setup":setup,"definition":fixture.checked.definition.duplicate(true),"generated_packet":{},"material_baseline":{},
		"camera":{"origin":Vector2i(12,24),"view_size":Vector2i(256,256),"zoom":1.5,"mode":"overview"}}
	var store := Store.new()
	if mode == "crash" and barrier == "newer_dirty_after_durable":
		# A previous independent process has already durably published tick 4.
		# This process restores that real native World, mutates/advances in RAM,
		# and dies before any new capture or Save can acknowledge the new work.
		var opened := store.open_profile(profile,"writeback-test",COMPATIBILITY)
		if not check(opened.get("ok",false) and not opened.get("fresh",true),"seeded durable native profile opens"): finish(); return
		var loaded := store.read_area("a")
		if not check(loaded.get("ok",false),"seeded native continuation validates"): finish(); return
		var restored_token := Fixture.prepare(fixture,Fixture.restore_options(fixture,loaded.capture,Store.new_nonce()))
		if not check(restored_token > 0 and fixture.bridge.commit_liquid_world(fixture.world,restored_token),
				"seeded durable native World restores"): finish(); return
		check(int(fixture.world.get_tick_index()) == 4,"seeded native game frontier is exact")
		fixture.world.paint_disc(90,60,0,58)
		for index: int in 2: check(fixture.world.simulation_tick(),"newer unsaved native work executes")
		hold_for_process_death(barrier,opened.manifest,{"live_native_tick":int(fixture.world.get_tick_index()),
			"durable_native_tick":int(opened.manifest.clock.areas.a.native_ticks),
			"dirty_material":fixture.world.material_at(90,60)})
		finish()
		return
	if mode == "verify":
		verify_reopened(store)
		store.close_profile()
		finish()
		return
	var manifest := initialize_profile(store)
	if manifest.is_empty(): store.close_profile(); finish(); return
	fixture.world.paint_disc(65,60,0,0)
	fixture.world.paint_disc(72,60,0,58)
	for index: int in 4: check(fixture.world.simulation_tick(),"actual native tick before capture")
	if mode == "crash" and barrier == "before_capture":
		hold_for_process_death(barrier,manifest,{"live_native_tick":int(fixture.world.get_tick_index()),
			"durable_native_tick":int(manifest.clock.areas.a.native_ticks)})
		finish()
		return
	var captured := capture()
	var expected := captured.duplicate(true)
	var state := {"active_area":"a","clock":Clock.active(manifest.clock,"a",int(captured.completed_tick)).clock}
	var updates := {"a":update(captured,manifest.areas.a.incarnation,1)}
	var writer := Writer.new()
	if mode == "crash":
		# This phase deliberately holds the I/O owner *before* publication
		# while Main queues coalesced requests and makes newer native edits.
		store.set_test_barrier("before_snapshot" if barrier == "queued_dirty" else barrier,Semaphore.new())
	check(writer.start(store,state,updates,int(manifest.revision)).ok,"immutable batch starts on a real separate Thread")
	check(not writer.start(store,state,updates,int(manifest.revision)).ok,"second concurrent writer refuses")
	for index: int in 100: writer.request(index%4,"coalesced autosave")
	check(writer.status().pending_requests == 1 and writer.status().metrics.coalesced == 99,
		"rapid saves coalesce to one metadata request with bounded bytes")
	check(writer.take_request().is_empty(),"new capture request cannot acquire store while publication owns it")
	# Caller-owned values and the active native World change after start. These
	# edits must not change the immutable publication or be labelled durable.
	captured.bytes[0] ^= 1
	updates.a.authoring.setup.edits.clear()
	fixture.world.paint_disc(80,60,0,58)
	for index: int in 2: check(fixture.world.simulation_tick(),"active native owner progresses during background publication")
	if mode == "crash" and barrier == "queued_dirty":
		check(writer.status().pending_requests == 1,"queued write-behind save remains pending during process death")
		hold_for_process_death(barrier,manifest,{"live_native_tick":int(fixture.world.get_tick_index()),
			"durable_native_tick":int(manifest.clock.areas.a.native_ticks),
			"queued_requests":int(writer.status().pending_requests)})
		finish()
		return
	var committed := await wait_writer(writer)
	if not check(committed.get("ok",false),"asynchronous publication acknowledges a complete durable manifest: "+str(committed.get("error",""))):
		store.close_profile(); finish(); return
	check(int(committed.manifest.clock.game_ticks) == 4 and int(fixture.world.get_tick_index()) == 6,
		"durable snapshot frontier stays independent of newer live native time")
	check(committed.snapshot_fence.areas.a.native_sha256 == expected.sha256,"ACK binds exact captured native state")
	var loaded: Dictionary = store.read_area("a")
	check(loaded.ok and loaded.capture.bytes == expected.bytes and loaded.authoring.setup.edits.size() == 2,
		"caller mutation cannot alter detached capture or typed authoring")
	check(writer.take_request().priority == 3 and writer.status().pending_requests == 0,"coalesced Save priority persists and drains once")
	check(writer.poll().status == "idle","completed batch retires its thread and store ownership")
	manifest = committed.manifest
	if mode == "seed":
		store.close_profile()
		finish()
		return
	# The stale batch cannot overwrite a later durable generation, even when its
	# captured physical bytes happen to coincide (same-state ABA).
	check(writer.start(store,state,{"a":update(expected,manifest.areas.a.incarnation,1)},1).ok,"stale request can be scheduled as data")
	var stale := await wait_writer(writer)
	check(not stale.get("ok",false) and store.current_manifest().revision == 2,"serialized store rejects stale durable revision")
	for phase: String in ["after_checkpoint","after_stage","after_previous","before_publish"]:
		var before := FileAccess.get_sha256(profile.path_join(Store.CURRENT))
		store.set_test_fault(phase)
		check(writer.start(store,state,{"a":update(expected,manifest.areas.a.incarnation,1)},int(manifest.revision)).ok,
			"background fault batch starts: "+phase)
		var failed := await wait_writer(writer)
		check(not failed.get("ok",false) and "Injected" in str(failed.get("error","")),"publication failure is visible: "+phase)
		check(FileAccess.get_sha256(profile.path_join(Store.CURRENT)) == before and fixture.world.material_at(80,60) == 58,
			"failed publication retains both prior durable and newer resident state: "+phase)
	# A real filesystem obstruction is independent of test hooks.
	store.close_profile()
	store = Store.new()
	check(store.open_profile(profile,"writeback-test",COMPATIBILITY).ok,"owner can reopen after unsuccessful background writes")
	manifest = store.current_manifest()
	var next_capture := capture()
	var next_state := {"active_area":"a","clock":Clock.active(manifest.clock,"a",int(next_capture.completed_tick)).clock}
	var next_updates := {"a":update(next_capture,manifest.areas.a.incarnation,2)}
	var obstructed_fence := Store.snapshot_fence(manifest,next_state,next_updates,Store.new_nonce())
	var obstruction := profile.path_join("manifest-"+str(obstructed_fence.fence.snapshot_id)+".tmp")
	check(DirAccess.make_dir_absolute(obstruction)==OK,"real filesystem obstruction occupies the immutable stage path")
	var prior_sha := FileAccess.get_sha256(profile.path_join(Store.CURRENT))
	check(writer.start(store,next_state,next_updates,int(manifest.revision),obstructed_fence.fence).ok,"obstructed async write starts")
	var obstructed := await wait_writer(writer)
	check(not obstructed.get("ok",false) and not "Injected" in str(obstructed.get("error","")),
		"actual native filesystem refusal is independent of synthetic fault hooks")
	check(FileAccess.get_sha256(profile.path_join(Store.CURRENT))==prior_sha and fixture.world.material_at(80,60)==58,
		"real storage refusal keeps the old durable checkpoint and newer live edit")
	check(DirAccess.remove_absolute(obstruction)==OK,"test obstruction retires without changing valid profile files")
	var malicious := next_updates.duplicate(true)
	var live := Node.new()
	malicious.a.authoring.camera["live_node"] = live
	check(not writer.start(store,next_state,malicious,int(manifest.revision)).ok,"live scene objects cannot enter background batch")
	malicious = next_updates.duplicate(true)
	malicious.a["unused"] = live
	check(not writer.start(store,next_state,malicious,int(manifest.revision)).ok,"unknown update fields cannot smuggle live objects to I/O owner")
	var unsafe_selection := next_state.duplicate(true)
	unsafe_selection.active_area = live
	check(not writer.start(store,unsafe_selection,next_updates,int(manifest.revision)).ok,"selected area cannot smuggle a live object into immutable I/O state")
	live.free()
	var starts_before := int(writer.status().metrics.started)
	var encodes_before := int(writer.status().metrics.metadata_encodes)
	malicious = next_updates.duplicate(true)
	malicious.a.capture.bytes = PackedByteArray()
	check(not writer.start(store,next_state,malicious,int(manifest.revision)).ok,"empty native capsule refuses before I/O Thread creation")
	var oversized := PackedByteArray()
	oversized.resize(Store.MAX_NATIVE_BYTES+1)
	malicious.a.capture.bytes = oversized
	check(not writer.start(store,next_state,malicious,int(manifest.revision)).ok,"native capsule above its individual bound refuses before transfer")
	malicious = next_updates.duplicate(true)
	var metadata: Array = []
	for index: int in 129: metadata.append("x".repeat(65536))
	malicious.a.authoring.camera["oversized_metadata"] = metadata
	check(not writer.start(store,next_state,malicious,int(manifest.revision)).ok,"bounded pure-value items cannot evade combined metadata byte capacity")
	var shared := PackedByteArray()
	shared.resize(5*1024*1024)
	malicious = next_updates.duplicate(true)
	malicious.a.authoring.camera["repeated_packed_bytes"] = [shared,shared]
	check(Store._pure(malicious.a.authoring,[Store.MAX_VALUE_ITEMS]),"repeated packed-byte attack fits the old pure-item contract")
	check(not writer.start(store,next_state,malicious,int(manifest.revision)).ok,
		"aggregate packed payload refuses before allocating its full encoded bytes")
	check(int(writer.status().metrics.metadata_encodes)==encodes_before,
		"oversized native, string and repeated-packed inputs perform no full metadata encoding")
	check(int(writer.status().metrics.started)==starts_before and not writer.busy(),"invalid buffer bounds allocate no publication Thread")
	var fence := Store.snapshot_fence(manifest,next_state,next_updates,Store.new_nonce())
	check(fence.ok,"immutable batch identity can be explicitly checked")
	fence.fence.areas.a.incarnation = "f".repeat(32)
	check(writer.start(store,next_state,next_updates,int(manifest.revision),fence.fence).ok,"tampered fence is passed only as immutable data")
	check(not (await wait_writer(writer)).get("ok",false),"tampered source/incarnation fence refuses before publication")
	store.set_test_fault("after_publish")
	check(writer.start(store,next_state,next_updates,int(manifest.revision)).ok,"lost-ACK publication starts")
	var lost := await wait_writer(writer)
	check(not lost.get("ok",false) and lost.get("published",false) and lost.get("quarantined",false),
		"published but unacknowledged result is explicit uncertain durability")
	store.close_profile()
	var recovered := Store.new()
	verify_reopened(recovered)
	check(int(recovered.current_manifest().clock.game_ticks) == 6,"fresh owner resolves actual atomically published frontier after lost ACK")
	var files := DirAccess.get_files_at(profile)
	check(files.size() <= 9,"failed/coalesced saves retain bounded current/previous profile files")
	recovered.close_profile()
	finish()


func finish() -> void:
	if not evidence.is_empty():
		var output := FileAccess.open(evidence,FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"pid":OS.get_process_id(),
				"mode":mode,"profile":profile,"events":events},"\t"))
			output.close()
		else: check(false,"evidence file opens")
	print("GEN006_RAMCACHE_WRITEBACK checks=",checks," failures=",failures," pid=",OS.get_process_id())
	quit(0 if failures == 0 else 1)
