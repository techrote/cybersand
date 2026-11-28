extends SceneTree
# Independent diagnostic: no Main UX claim. A real failed active native owner
# remains quarantined while healthy inactive B/C are captured and published.
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Store = preload("res://scripts/persistent_area_store.gd")
const Recovery = preload("res://scripts/persistent_area_recovery.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const COMPAT := "independent-recovery-v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var profile := ""
var output := ""
var mode := "seed"
var seed_evidence := ""
var checks := 0
var failures := 0
var observations := {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--recovery-profile="): profile = arg.trim_prefix("--recovery-profile=")
		elif arg.begins_with("--recovery-output="): output = arg.trim_prefix("--recovery-output=")
		elif arg.begins_with("--recovery-mode="): mode = arg.trim_prefix("--recovery-mode=")
		elif arg.begins_with("--recovery-seed="): seed_evidence = arg.trim_prefix("--recovery-seed=")
	if profile.is_empty(): profile=ProjectSettings.globalize_path("user://persistent-recovery-"+Store.new_nonce())
	if output.is_empty(): output=profile+"-evidence.json"
	run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("Independent recovery: "+label)
	return condition

func authoring(fixture: Dictionary, edits: Array = []) -> Dictionary:
	var setup := Setup.fresh(fixture.bridge.default_liquid_policy(),Vector2i(512,512))
	setup.edits = edits.duplicate(true)
	return {"setup":setup,"definition":fixture.checked.definition.duplicate(true),"generated_packet":{},
		"material_baseline":{},"camera":{"origin":Vector2i(0,0),"view_size":Vector2i(256,256),"zoom":1.0,"mode":"overview"}}

func identity(manifest: Dictionary, id: String) -> Dictionary:
	return {"session_id":manifest.session_id,"area_id":id,"incarnation":manifest.areas[id].incarnation,
		"runtime_sha256":"a".repeat(64),"authored_source_sha256":manifest.areas[id].authored_source_sha256}

func publish(store: RefCounted, state: Dictionary, updates: Dictionary, revision: int) -> Dictionary:
	var fence := Store.snapshot_fence(store.current_manifest(),state,updates,Store.new_nonce())
	if not fence.get("ok",false): return fence
	return store.publish_snapshot(state,updates,revision,str(fence.fence.snapshot_id),fence.fence)

func run() -> void:
	if profile.is_empty() or output.is_empty(): check(false,"explicit isolated paths supplied"); finish(); return
	var store := Store.new()
	var opened: Dictionary = store.open_profile(profile,"independent-recovery",COMPAT)
	if not check(opened.get("ok",false),"native OS storage profile opens"): finish(); return
	if mode=="verify":
		verify(store,opened)
		store.close_profile()
		finish()
		return
	if not check(opened.get("fresh",false),"diagnostic starts from fresh profile"): store.close_profile(); finish(); return
	var initial := Fixture.create()
	if not check(not initial.has("error"),"supported initial World constructs"): store.close_profile(); finish(); return
	var capsule: Dictionary = initial.bridge.capture_workbench_continuation(initial.world)
	var updates := {}
	for id: String in Clock.AREA_IDS:
		updates[id] = {"capture":capsule,"authoring":authoring(initial),"incarnation":Store.new_nonce(),"mutation_generation":0}
	var owner := {"operation_id":Store.new_nonce(),"native_tick":0,"physical_hash":capsule.physical_hash}
	var staged: Dictionary = store.prepare_commit({"active_area":"a","clock":Clock.fresh()},updates,0,Store.new_nonce(),owner)
	if not check(staged.get("ok",false),"initial three-area durable checkpoint stages"): store.close_profile(); finish(); return
	var committed: Dictionary = store.commit_prepared(staged.receipt,owner)
	if not check(committed.get("ok",false),"initial manifest acknowledged"): store.close_profile(); finish(); return
	var manifest: Dictionary = committed.manifest
	var durable_a: Dictionary = manifest.areas.a.duplicate(true)
	# Deliberately bounded scheduler capacity injects a real native tick failure.
	# Initial saved A has ordinary capacity and remains independently restorable.
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1)
	var failed := Fixture.create()
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1024)
	if not check(not failed.has("error"),"fault-injection active owner constructs"): store.close_profile(); finish(); return
	failed.world.paint_disc(65,60,0,0)
	var admitted: Dictionary = failed.bridge.resident_admit(failed.world,identity(manifest,"a"))
	if not check(admitted.get("ok",false),"failed-source identity initially admitted"): store.close_profile(); finish(); return
	var clock: Dictionary = manifest.clock.duplicate(true)
	var expected := {"a":{"native_sha256":capsule.sha256,"tick":0,"physical_hash":capsule.physical_hash}}
	var envelopes := {}
	for id: String in ["b","c"]:
		var healthy := Fixture.create()
		if not check(not healthy.has("error"),"healthy inactive "+id+" constructs"): store.close_profile(); finish(); return
		var x := 72 if id=="b" else 80
		healthy.world.paint_disc(65,60,0,0)
		healthy.world.paint_disc(x,60,0,58)
		var ticks := 7 if id=="b" else 3
		for index: int in ticks: check(healthy.world.simulation_tick(),"real "+id+" tick "+str(index))
		clock = Clock.active(clock,id,ticks).clock
		var bound: Dictionary = healthy.bridge.resident_admit(healthy.world,identity(manifest,id))
		if not check(bound.get("ok",false),"healthy "+id+" receives resident identity"): store.close_profile(); finish(); return
		var imported: Dictionary = failed.bridge.resident_import(failed.world,healthy.world,bound.receipt)
		if not check(imported.get("ok",false),"healthy "+id+" unique owner imports inactive"): store.close_profile(); finish(); return
		envelopes[id] = authoring(healthy,[[65,60,0,0],[x,60,0,58]])
	check(not failed.world.simulation_tick() and failed.world.has_failed(),"active A actually fails native capacity and remains quarantined")
	var status: Dictionary = failed.bridge.resident_status(failed.world)
	check(status.active.failed and status.inactive.size()==2,"native status retains failed active and both healthy inactive Worlds")
	var refused: Dictionary = failed.bridge.resident_capture(failed.world,status.active)
	check(not refused.get("ok",false),"failed active cannot counterfeit a current durable capture")
	var recovery_clock: Dictionary = manifest.clock.duplicate(true)
	var recovery_updates := {}
	var source_game_tick: int = int(clock.game_ticks)
	var completed_capture_deltas := 0
	for receipt: Dictionary in status.inactive:
		var id := str(receipt.identity.area_id)
		var captured: Dictionary = failed.bridge.resident_capture(failed.world,receipt)
		if not check(captured.get("ok",false),"healthy inactive capture remains possible under failed active "+id): store.close_profile(); finish(); return
		check(int(captured.capsule.completed_tick)==int(clock.areas[id].native_ticks),"captured native frontier matches independently tracked "+id)
		completed_capture_deltas += int(clock.areas[id].native_ticks)-int(manifest.clock.areas[id].native_ticks)
		recovery_clock.areas[id] = clock.areas[id].duplicate(true)
		recovery_clock.game_ticks = maxi(int(recovery_clock.game_ticks),int(clock.areas[id].accounted_ticks))
		recovery_updates[id] = {"capture":captured.capsule,"authoring":envelopes[id],
			"incarnation":manifest.areas[id].incarnation,"mutation_generation":1}
		expected[id] = {"native_sha256":captured.capsule.sha256,"tick":captured.capsule.completed_tick,"physical_hash":captured.capsule.physical_hash}
	recovery_clock.game_ticks = mini(source_game_tick,int(manifest.clock.game_ticks)+completed_capture_deltas)
	check(Clock.validate(recovery_clock).is_empty(),"recovery clock is canonical and never invents area ticks")
	var overcredited: Dictionary = recovery_clock.duplicate(true)
	overcredited.game_ticks = int(manifest.clock.game_ticks)+completed_capture_deltas+1
	var excessive := publish(store,{"active_area":"a","clock":overcredited},recovery_updates,int(manifest.revision))
	check(not excessive.get("ok",false),"Store refuses recovery global credit beyond all captured native work")
	check(int(recovery_clock.game_ticks)>=int(manifest.clock.game_ticks),"recovery never rewinds acknowledged global time")
	var planned: Dictionary=Recovery.plan(manifest,clock,"a",recovery_updates,Store.new_nonce())
	if not check(planned.get("ok",false),"pure explicit recovery plan admits only healthy inactive captures"): store.close_profile(); finish(); return
	check(planned.state.clock==recovery_clock and planned.updates==recovery_updates,"planner matches independently calculated backed observed frontier")
	check(not planned.summary.ordinary_save_all and not planned.summary.failed_world_reset and not planned.summary.failed_world_discarded,
		"recovery result makes no Save-all or failed-owner reset claim")
	planner_attacks(manifest,clock,recovery_updates)
	var corrupt_updates: Dictionary=recovery_updates.duplicate(true)
	corrupt_updates.b.capture.bytes[0]^=1
	var corrupted_plan: Dictionary=Recovery.plan(manifest,clock,"a",corrupt_updates,Store.new_nonce())
	check(corrupted_plan.get("ok",false),"pure planner leaves full native-byte validation to Store")
	var corrupt_publication: Dictionary=publish(store,corrupted_plan.state,corrupted_plan.updates,int(manifest.revision))
	check(not corrupt_publication.get("ok",false) and store.current_manifest().revision==manifest.revision,"Store rejects corrupt recovery bytes without replacing valid durable authority")
	var result := publish(store,planned.state,planned.updates,int(manifest.revision))
	if not check(result.get("ok",false),"Store accepts monotonic healthy-only recovery publication: "+str(result.get("error",""))): store.close_profile(); finish(); return
	check(result.manifest.areas.a==durable_a,"failed active's last acknowledged checkpoint identity remains unchanged")
	check(failed.world.has_failed() and failed.world.material_at(65,60)==0,"publication does not unbind, reset or overwrite failed active authority")
	var after_status: Dictionary = failed.bridge.resident_status(failed.world)
	check(after_status.active.handle==status.active.handle and after_status.inactive.size()==2,"publication retains all unique native owners")
	var stale := publish(store,{"active_area":"a","clock":recovery_clock},recovery_updates,int(manifest.revision))
	check(not stale.get("ok",false),"old durable revision cannot republish recovery snapshot")
	var reverted: Dictionary = recovery_clock.duplicate(true)
	reverted.areas.b.native_ticks=0
	reverted.areas.b.accounted_ticks=0
	var rollback := publish(store,{"active_area":"a","clock":reverted},{},int(result.manifest.revision))
	check(not rollback.get("ok",false),"completed healthy native frontier cannot be rewound after acknowledgement")
	observations = {"pid":OS.get_process_id(),"source_game_ticks":source_game_tick,"recovered_game_ticks":recovery_clock.game_ticks,
		"explicit_ram_only_global_ticks_discarded":source_game_tick-int(recovery_clock.game_ticks),"global_clock_policy":"maximal-backed-game-time","captured_native_delta_sum":completed_capture_deltas,"overcredit_refusal":excessive.get("error",""),"expected":expected,
		"recovery_summary":planned.summary,"manifest":result.manifest,"manifest_file_sha256":FileAccess.get_sha256(profile.path_join(Store.CURRENT)),"active_failed":failed.world.has_failed(),"active_handle":status.active.handle,
		"active_unsaved_empty_retained":failed.world.material_at(65,60)==0,"stale_refusal":stale.get("error",""),
		"rollback_refusal":rollback.get("error",""),"ordinary_save_all_claimed":false}
	store.close_profile()
	finish()


func planner_attacks(manifest: Dictionary, clock: Dictionary, updates: Dictionary) -> void:
	check(not Recovery.plan(manifest,clock,"unknown",updates,Store.new_nonce()).get("ok",false),"unknown failed area refuses")
	check(not Recovery.plan(manifest,clock,"a",updates,str(manifest.operation_nonce)).get("ok",false),"already committed recovery operation identity refuses")
	check(not Recovery.plan(manifest,clock,"a",{},Store.new_nonce()).get("ok",false),"no healthy captures cannot masquerade as successful rescue")
	var bad: Dictionary=updates.duplicate(true)
	bad.a=bad.b
	check(not Recovery.plan(manifest,clock,"a",bad,Store.new_nonce()).get("ok",false),"failed active update cannot enter recovery publication")
	for field: String in ["authored_source_sha256","physics_profile_sha256","policy_sha256"]:
		bad=updates.duplicate(true)
		bad.b.capture[field]="f".repeat(64)
		check(not Recovery.plan(manifest,clock,"a",bad,Store.new_nonce()).get("ok",false),"wrong healthy source/physics/policy refuses: "+field)
	bad=updates.duplicate(true)
	bad.b.incarnation="f".repeat(32)
	check(not Recovery.plan(manifest,clock,"a",bad,Store.new_nonce()).get("ok",false),"wrong healthy incarnation refuses")
	bad=updates.duplicate(true)
	bad.b.capture.completed_tick+=1
	check(not Recovery.plan(manifest,clock,"a",bad,Store.new_nonce()).get("ok",false),"captured tick different from accounted native frontier refuses")
	var changed_clock: Dictionary=clock.duplicate(true)
	changed_clock.game_ticks=-1
	check(not Recovery.plan(manifest,changed_clock,"a",updates,Store.new_nonce()).get("ok",false),"negative/rewound global time refuses")
	changed_clock=clock.duplicate(true)
	changed_clock.game_ticks=100
	changed_clock.areas.b.origin_game_tick=90
	changed_clock.areas.b.accounted_ticks=97
	check(Clock.validate(changed_clock).is_empty(),"adversarial accounted frontier is structurally valid")
	check(not Recovery.plan(manifest,changed_clock,"a",updates,Store.new_nonce()).get("ok",false),"accounted frontier above backed global cap cannot be manufactured by changing origin")
	bad=updates.duplicate(true)
	var live:=Node.new()
	bad.b.authoring.camera["live_object"]=live
	check(not Recovery.plan(manifest,clock,"a",bad,Store.new_nonce()).get("ok",false),"live host references cannot enter recovery values")
	live.free()
	# Planner-only adversarial clock, not a claim that failed native A executed
	# these extra ticks. It proves omitted RAM-only global time is explicit.
	changed_clock=clock.duplicate(true)
	changed_clock.game_ticks+=90
	changed_clock.areas.a.native_ticks+=90
	changed_clock.areas.a.accounted_ticks+=90
	var projected: Dictionary=Recovery.plan(manifest,changed_clock,"a",updates,Store.new_nonce())
	check(projected.get("ok",false) and int(projected.summary.omitted_ram_game_ticks)==90 \
		and int(projected.state.clock.game_ticks)==10,"unbacked observed global interval is reported rather than silently credited")
	check(projected.state.clock.areas.a==manifest.clock.areas.a,"planner never transfers failed active simulated state into recovery manifest")

func verify(store: RefCounted, opened: Dictionary) -> void:
	if not check(not opened.get("fresh",true),"new process opens acknowledged recovery profile"): return
	var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string(seed_evidence))
	if not check(seed is Dictionary,"retained seed evidence opens"): return
	check(int(seed.observations.pid)!=OS.get_process_id(),"recovery executes in genuinely different process")
	check(FileAccess.get_sha256(profile.path_join(Store.CURRENT))==seed.observations.manifest_file_sha256,"new process reads the byte-identical acknowledged manifest file")
	var restored := {}
	for id: String in Clock.AREA_IDS:
		var loaded: Dictionary = store.read_area(id)
		if not check(loaded.get("ok",false),"complete stored area validates "+id): return
		var world := Fixture.create()
		if not check(not world.has("error"),"fresh native owner constructs for "+id): return
		var token: int = Fixture.prepare(world,Fixture.restore_options(world,loaded.capture,Store.new_nonce()))
		if not check(token>0 and world.bridge.commit_liquid_world(world.world,token),"real native continuation restores "+id): return
		var exact: Dictionary = world.bridge.capture_workbench_continuation(world.world)
		check(exact.bytes==loaded.capture.bytes and exact.sha256==seed.observations.expected[id].native_sha256,
			"entire recovered native state is byte-exact "+id)
		check(int(exact.completed_tick)==int(opened.manifest.clock.areas[id].native_ticks),"restored actual native tick agrees with durable clock "+id)
		if id=="a":
			check(world.world.material_at(65,60)==1,"failed active's unacknowledged Empty edit is honestly absent; last durable A recovered")
		else:
			var x := 72 if id=="b" else 80
			check(world.world.material_at(65,60)==0 and world.world.material_at(x,60)==58,"healthy inactive Empty and unique material marks survived "+id)
			check(loaded.authoring.setup.edits.size()==2,"healthy authoring envelope survives "+id)
		restored[id] = {"native_sha256":exact.sha256,"tick":exact.completed_tick,"physical_hash":exact.physical_hash}
	observations = {"pid":OS.get_process_id(),"seed_pid":seed.observations.pid,"manifest":opened.manifest,"restored":restored}

func finish() -> void:
	var result := {"schema":1,"mode":mode,"checks":checks,"failures":failures,"observations":observations}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(result,"\t")); file.close()
	else: failures+=1
	print("GEN006_NATIVE_FAILED_ACTIVE_RECOVERY ",JSON.stringify({"mode":mode,"checks":checks,"failures":failures,"pid":OS.get_process_id()}))
	quit(0 if failures==0 else 1)
