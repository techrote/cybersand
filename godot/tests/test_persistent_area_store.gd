extends SceneTree

# Real native capsules + actual desktop filesystem transactions. Three reused
# fixture captures isolate storage semantics; the interactive three distinct
# authored scenes are qualified by the separate Workbench acceptance campaign.
const Store = preload("res://scripts/persistent_area_store.gd")
const Clock = preload("res://scripts/persistent_area_clock.gd")
const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const COMPATIBILITY := "gen006-storage-native-fixture-cyps2-current-512-v1"
var checks := 0
var failures := 0
var profile := ""
var mode := "unit"
var fixture: Dictionary


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--store-profile="): profile = argument.trim_prefix("--store-profile=")
		if argument.begins_with("--store-mode="): mode = argument.trim_prefix("--store-mode=")
	if profile.is_empty(): profile = ProjectSettings.globalize_path("user://gen006-store-tests-" + Store.new_nonce())
	run.call_deferred()


func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("GEN006 store: " + label)
	return condition


func capsule() -> Dictionary:
	var value: Dictionary = fixture.bridge.capture_workbench_continuation(fixture.world)
	check(not value.is_empty(), "native continuation captured: " + str(fixture.bridge.get_last_error()))
	return value


func authoring() -> Dictionary:
	var setup := Setup.fresh(fixture.bridge.default_liquid_policy(), Vector2i(512, 512))
	setup.edits = [[65,60,0,0]] # Explicit Empty survives independently of the original constructor.
	return {"setup":setup, "definition":fixture.checked.definition.duplicate(true), "generated_packet":{}, "material_baseline":{},
		"camera":{"origin":Vector2i(12,24), "view_size":Vector2i(256,256), "zoom":1.5, "mode":"overview"}}


func update(captured: Dictionary, incarnation: String, mutation: int = 0) -> Dictionary:
	return {"capture":captured, "authoring":authoring(), "incarnation":incarnation, "mutation_generation":mutation}


func owner_fence() -> Dictionary:
	return {"operation_id":Store.new_nonce(), "source_area":"a", "world_generation":int(fixture.world.get_liquid_policy_session_generation()),
		"mutation_generation":int(fixture.world.get_revision()), "completed_tick":int(fixture.world.get_tick_index()),
		"physical_hash":str(fixture.world.get_physical_state_hash())}


func initialize_profile(path: String, captured: Dictionary) -> RefCounted:
	var store := Store.new()
	var opened := store.open_profile(path, "qualification", COMPATIBILITY)
	if not check(opened.get("ok", false) and opened.fresh, "isolated fresh profile opens: " + str(opened.get("error", ""))): return store
	var updates := {}
	for id: String in Clock.AREA_IDS: updates[id] = update(captured, Store.new_nonce())
	var clock := Clock.fresh()
	# Initial fixture captures in this test are always native tick zero.
	var fence := owner_fence()
	var prepared := store.prepare_commit({"active_area":"a", "clock":clock}, updates, 0, Store.new_nonce(), fence)
	if not check(prepared.get("ok", false), "three native payloads stage before the manifest: " + str(prepared.get("error", ""))): return store
	var committed := store.commit_prepared(prepared.receipt, fence)
	check(committed.get("ok", false) and committed.manifest.revision == 1, "initial profile manifest publishes atomically: " + str(committed.get("error", "")))
	return store


func advance_native(ticks: int) -> void:
	for index: int in ticks:
		if not check(fixture.world.simulation_tick(), "native fixture tick advances"): return


func save_current(store: RefCounted, mutation: int) -> Dictionary:
	var manifest: Dictionary = store.current_manifest()
	var captured := capsule()
	var next := Clock.active(manifest.clock, "a", int(captured.completed_tick))
	if not check(next.get("ok", false), "observed native ticks account exactly once"): return {}
	var fence := owner_fence()
	var prepared: Dictionary = store.prepare_commit({"active_area":"a", "clock":next.clock},
		{"a":update(captured, manifest.areas.a.incarnation, mutation)}, int(manifest.revision), Store.new_nonce(), fence)
	if not check(prepared.get("ok", false), "evolved native state stages: " + str(prepared.get("error", ""))): return {}
	return {"prepared":prepared, "fence":fence, "capture":captured}


func restored_matches(loaded: Dictionary) -> bool:
	if not check(loaded.get("ok", false), "durable area is available for native restore: " + str(loaded.get("error", ""))): return false
	var options := Fixture.restore_options(fixture, loaded.capture, Store.new_nonce())
	var token := Fixture.prepare(fixture, options)
	if not check(token > 0, "saved native checkpoint passes actual private restoration: " + str(fixture.bridge.get_last_error())): return false
	var readback: Dictionary = fixture.bridge.capture_prepared_workbench_continuation(fixture.world, token)
	var exact: bool = readback.get("sha256", "") == loaded.capture.sha256 and readback.get("physical_hash", "") == loaded.capture.physical_hash \
		and int(readback.get("completed_tick", -1)) == int(loaded.capture.completed_tick)
	check(exact, "restored native bytes, physical state and tick match complete captured authority")
	check(fixture.bridge.commit_liquid_world(fixture.world, token), "private restoration installs through native one-use acknowledgement")
	return exact


func write_raw(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "test-side adversarial file opens"): return
	file.store_buffer(bytes)
	file.close()


func adversarial_containers(store: RefCounted) -> void:
	var good := FileAccess.get_file_as_bytes(profile.path_join(Store.CURRENT))
	for length: int in [0, 8, 51, 52, good.size() - 1]:
		check(not store._decode_manifest(good.slice(0, length), true).ok, "truncated manifest refuses at byte " + str(length))
	var tail := good.duplicate()
	tail.append(0)
	check(not store._decode_manifest(tail, true).ok, "trailing manifest bytes refuse")
	var decoded: Dictionary = Store._unwrap(good, Store.MANIFEST_MAGIC, Store.MAX_MANIFEST_BYTES, 0)
	var original: Dictionary = JSON.parse_string(decoded.metadata.get_string_from_utf8())
	for fault: String in ["version", "area", "session", "tick", "digest", "count"]:
		var mutated: Dictionary = original.duplicate(true)
		match fault:
			"version": mutated.version = 100
			"area": mutated.areas.a.area_id = "b"
			"session": mutated.session_id = "b".repeat(32)
			"tick": mutated.areas.a.completed_tick += 1
			"digest": mutated.areas.a.native_sha256 = "c".repeat(64)
			"count": mutated.areas.erase("c")
		var forged: PackedByteArray = Store._wrap(Store.MANIFEST_MAGIC, JSON.stringify(mutated).to_utf8_buffer())
		check(not store._decode_manifest(forged, true).ok, "checksum-valid wrong " + fault + " refuses")
	var snapshot: Dictionary = store.current_manifest()
	var staged := save_current(store, 2)
	var staged_name: String = "manifest-" + str(staged.prepared.receipt.operation_nonce) + ".tmp"
	var changed := FileAccess.get_file_as_bytes(profile.path_join(staged_name))
	changed[-1] ^= 1
	write_raw(profile.path_join(staged_name), changed)
	check(not store.commit_prepared(staged.prepared.receipt, staged.fence).ok and store.current_manifest() == snapshot,
		"staged manifest corruption cannot cross native publication identity CAS")
	store.abort_prepared(staged.prepared.receipt)
	var live_node := Node.new()
	check(not store.prepare_commit({"active_area":"a", "clock":snapshot.clock}, {}, snapshot.revision, Store.new_nonce(),
		{"unsafe":live_node}).ok, "live host objects cannot enter a storage owner fence")
	live_node.free()


func native_primitives() -> void:
	var raw: Object = ClassDB.instantiate("CyberPersistentAreaStorage")
	check(raw.acquire(profile + "-primitives").ok, "native isolated storage primitive locks")
	var initial := "old complete value".to_utf8_buffer()
	var replacement := "new complete value".to_utf8_buffer()
	check(raw.write_new("target.bin", initial).ok and raw.write_new("target.bin", initial).idempotent,
		"immutable write retry verifies and flushes exact complete bytes")
	check(not raw.write_new("target.bin", replacement).ok and raw.read_file("target.bin", 4096).bytes == initial,
		"immutable write cannot truncate the existing file")
	check(raw.write_new("stage.bin", replacement).ok, "native stage writes complete bytes")
	check(not raw.publish("stage.bin", "target.bin", Store.digest(initial), "0".repeat(64)).ok \
		and raw.read_file("target.bin", 4096).bytes == initial, "wrong staged hash refuses before replacement")
	check(not raw.publish("stage.bin", "target.bin", "0".repeat(64), Store.digest(replacement)).ok,
		"stale target hash refuses compare-and-publish")
	check(raw.publish("stage.bin", "target.bin", Store.digest(initial), Store.digest(replacement)).ok \
		and raw.read_file("target.bin", 4096).bytes == replacement, "atomic publication replaces exactly the admitted target")
	for name: String in ["../escape", "/absolute", "profile.lock", "upperCase", "nul", ".", "con.txt"]:
		check(not raw.write_new(name, initial).ok, "unsafe profile file name refuses: " + name)
	check(raw.write_new("zero.bin", PackedByteArray()).ok and raw.read_file("zero.bin", 0).bytes.is_empty(),
		"zero-byte adversarial file is bounded and hashes without engine errors")
	var capped := false
	for index: int in 65:
		var result: Dictionary = raw.write_new("bounded-" + str(index) + ".bin", PackedByteArray([index]))
		if not result.ok:
			capped = true
			break
	check(capped and raw.list_files().files.size() == 64, "native profile file count is bounded under repeated orphan writes")
	raw.close_profile()


func unit() -> void:
	var original := capsule()
	var store := initialize_profile(profile, original)
	if failures > 0: finish(); return
	var first: Dictionary = store.current_manifest()
	var second := Store.new()
	check(not second.open_profile(profile, "qualification", COMPATIBILITY).get("ok", false), "second profile owner refuses the OS lock")
	second.close_profile()
	var loaded: Dictionary = store.read_area("a")
	check(loaded.ok and loaded.capture.bytes == original.bytes and loaded.capture.extent is Vector2i \
		and loaded.capture.host_settings.region is PackedInt32Array, "complete native capsule and typed execution settings round trip")
	check(loaded.authoring.camera.origin is Vector2i and loaded.authoring.setup.edits == [[65,60,0,0]] \
		and loaded.authoring.definition == fixture.checked.definition, "typed camera, explicit Empty authoring and original geometry identity round trip")
	loaded.capture.bytes[0] ^= 1
	loaded.authoring.setup.edits.clear()
	check(store.read_area("a").capture.bytes == original.bytes and store.read_area("a").authoring.setup.edits.size() == 1,
		"returned payload mutations cannot mutate retained checkpoint state")
	var bad := original.duplicate(true)
	bad.sha256 = "0".repeat(64)
	check(not store.prepare_commit({"active_area":"a", "clock":first.clock}, {"a":update(bad, first.areas.a.incarnation)},
		1, Store.new_nonce(), owner_fence()).ok, "invalid native source digest refuses before any publication")
	var wrong_authoring := update(original, first.areas.a.incarnation)
	wrong_authoring.authoring.definition.rectangles[-1] = 2
	check(not store.prepare_commit({"active_area":"a", "clock":first.clock}, {"a":wrong_authoring},
		1, Store.new_nonce(), owner_fence()).ok, "checksum-valid different original geometry cannot adopt a captured native source")
	var foreign := Fixture.create()
	var foreign_definition: Dictionary = foreign.checked.definition.duplicate(true)
	foreign_definition.rectangles[-1] = 58
	foreign.checked = Contract.validate(foreign_definition)
	foreign.options.definition_hash = foreign.checked.hash
	var foreign_token := Fixture.prepare(foreign, foreign.options)
	check(foreign_token > 0 and foreign.bridge.commit_liquid_world(foreign.world, foreign_token), "independent foreign authored area genuinely constructs")
	var foreign_capsule: Dictionary = foreign.bridge.capture_workbench_continuation(foreign.world)
	var misrouted := update(foreign_capsule, first.areas.a.incarnation, 1)
	misrouted.authoring.definition = foreign.checked.definition
	check(not store.prepare_commit({"active_area":"a", "clock":first.clock}, {"a":misrouted},
		1, Store.new_nonce(), owner_fence()).ok, "a valid foreign area's native capsule cannot replace the existing logical area incarnation")
	var fake_clock: Dictionary = Clock.active(first.clock, "a", 1).clock
	check(not store.prepare_commit({"active_area":"a", "clock":fake_clock}, {}, 1, Store.new_nonce(), owner_fence()).ok,
		"clock advancement without authoritative native capture refuses")
	fixture.world.paint_disc(65,60,0,0)
	fixture.world.paint_disc(72,60,0,58)
	advance_native(12)
	var saved := save_current(store, 1)
	if failures > 0: store.close_profile(); finish(); return
	var stale: Dictionary = saved.fence.duplicate(true)
	stale.mutation_generation += 1
	check(not store.commit_prepared(saved.prepared.receipt, stale).ok and store.current_manifest().revision == 1,
		"stale owner completion cannot discard the old authoritative generation")
	var committed: Dictionary = store.commit_prepared(saved.prepared.receipt, saved.fence)
	check(committed.ok and committed.manifest.clock.game_ticks == 12, "actual completed native work and snapshot publish in one transaction")
	check(store.commit_prepared(saved.prepared.receipt, saved.fence).get("idempotent", false) \
		and store.current_manifest().revision == 2, "same durable acknowledgement replay is idempotent")
	check(restored_matches(store.read_area("a")), "real native readmission from durable state")
	check(fixture.world.material_at(65,60) == 0 and fixture.world.material_at(72,60) == 58,
		"destructive Empty and placed material survive actual native reconstruction")
	check(store.read_area("b").capture.sha256 == original.sha256 and store.read_area("c").capture.sha256 == original.sha256,
		"saving A does not replace the independent inactive B/C payloads")
	var old_receipt: Dictionary = saved.prepared.receipt.duplicate(true)
	var old_fence: Dictionary = saved.fence.duplicate(true)
	# Repeated same-state saves still receive nonreused generation and operation
	# identities. Byte equality never authorizes an old completion (the #514 ABA).
	for index: int in 10:
		var repeated := save_current(store, 1)
		if not check(not repeated.is_empty(), "same-state bounded save prepare"): break
		check(store.commit_prepared(repeated.prepared.receipt, repeated.fence).ok, "same-state bounded save commit")
	check(not store.commit_prepared(old_receipt, old_fence).ok, "old same-byte ACK refuses after a newer residency/transaction")
	var files := DirAccess.get_files_at(profile)
	check(files.size() <= 9, "bounded GC retains only current/previous referenced area generations and the lock")
	adversarial_containers(store)
	var latest: Dictionary = store.current_manifest()
	var pending := save_current(store, 2)
	check(store.abort_prepared(pending.prepared.receipt).ok and store.current_manifest() == latest,
		"cancelling a fully prepared save preserves the previous committed profile")
	for phase: String in ["after_checkpoint", "after_stage", "after_previous", "before_publish"]:
		var before_hash := FileAccess.get_sha256(profile.path_join(Store.CURRENT))
		store.set_test_fault(phase)
		var next: Dictionary = store.current_manifest()
		var fence := owner_fence()
		var prepared: Dictionary = store.prepare_commit({"active_area":"a", "clock":next.clock},
			{"a":update(saved.capture, next.areas.a.incarnation, 2)}, next.revision, Store.new_nonce(), fence)
		if prepared.get("ok", false):
			check(not store.commit_prepared(prepared.receipt, fence).ok, "injected prepublication failure: " + phase)
			store.abort_prepared(prepared.receipt)
		else: check("Injected" in str(prepared.get("error", "")), "injected staging failure: " + phase)
		check(FileAccess.get_sha256(profile.path_join(Store.CURRENT)) == before_hash \
			and fixture.world.material_at(65,60) == 0, "failed save retains old manifest and running native World: " + phase)
	store.close_profile()
	var reopened := Store.new()
	var opened := reopened.open_profile(profile, "qualification", COMPATIBILITY)
	check(opened.ok and opened.manifest.clock.game_ticks == 12, "closed profile reopens all three independently validated native checkpoints: " + str(opened.get("error", "")))
	reopened.close_profile()
	var incompatible := Store.new()
	check(not incompatible.open_profile(profile, "qualification", "different-runtime").ok, "incompatible native/runtime contract refuses without reseeding")
	incompatible.close_profile()
	var current_bytes := FileAccess.get_file_as_bytes(profile.path_join(Store.CURRENT))
	current_bytes[-1] ^= 1
	write_raw(profile.path_join(Store.CURRENT), current_bytes)
	var corrupt := Store.new()
	var refused := corrupt.open_profile(profile, "qualification", COMPATIBILITY)
	check(not refused.ok and refused.get("quarantined", false) and refused.get("recovery_available", false),
		"corrupt current refuses with explicit validated previous recovery available")
	var recovered := corrupt.recover_previous()
	check(recovered.ok and FileAccess.get_file_as_bytes(profile.path_join(Store.QUARANTINE)) == current_bytes,
		"explicit recovery retains corruption evidence and never regenerates the source recipe")
	check(restored_matches(corrupt.read_area("a")), "explicit recovery restores real native authority")
	corrupt.close_profile()
	# A real filesystem obstruction exercises failure independently of hooks.
	var obstruction_path := profile + "-obstruction"
	var obstructed := initialize_profile(obstruction_path, original)
	var obstructed_hash := FileAccess.get_sha256(obstruction_path.path_join(Store.CURRENT))
	DirAccess.make_dir_absolute(obstruction_path.path_join(Store.PREVIOUS))
	var obstructed_state: Dictionary = obstructed.current_manifest()
	var obstruction_result: Dictionary = obstructed.prepare_commit({"active_area":"b", "clock":obstructed_state.clock}, {},
		obstructed_state.revision, Store.new_nonce(), owner_fence())
	check(not obstruction_result.ok and FileAccess.get_sha256(obstruction_path.path_join(Store.CURRENT)) == obstructed_hash,
		"real unavailable publication target refuses without altering current authority")
	obstructed.close_profile()
	native_primitives()
	var moved_path := profile + "-moved-source"
	var movable := initialize_profile(moved_path, original)
	var old_hash := FileAccess.get_sha256(moved_path.path_join(Store.CURRENT))
	var moved := DirAccess.rename_absolute(moved_path, moved_path + "-renamed")
	if moved == OK:
		var state: Dictionary = movable.current_manifest()
		check(not movable.prepare_commit({"active_area":"b", "clock":state.clock}, {}, state.revision, Store.new_nonce(), owner_fence()).ok \
			and FileAccess.get_sha256((moved_path + "-renamed").path_join(Store.CURRENT)) == old_hash,
			"unavailable profile path refuses new publication and preserves the retained directory")
	else:
		check(FileAccess.get_sha256(moved_path.path_join(Store.CURRENT)) == old_hash, "OS directory lock refuses moving the active profile")
	movable.close_profile()
	finish()


func process_mode() -> void:
	var store: RefCounted
	if mode == "seed":
		store = initialize_profile(profile, capsule())
		fixture.world.paint_disc(65,60,0,0)
		fixture.world.paint_disc(72,60,0,58)
		advance_native(10)
		var saved := save_current(store, 1)
		if not saved.is_empty(): check(store.commit_prepared(saved.prepared.receipt, saved.fence).ok, "process seed commits changing native fixture")
	elif mode in ["verify", "crash-staged", "crash-published", "lock-probe"]:
		store = Store.new()
		var opened: Dictionary = store.open_profile(profile, "qualification", COMPATIBILITY)
		if mode == "lock-probe":
			check(not opened.get("ok", false), "independent process refuses existing profile OS lock")
			store.close_profile()
			finish()
			return
		if not check(opened.get("ok", false), "fresh process loads durable manifest: " + str(opened.get("error", ""))): finish(); return
		var loaded: Dictionary = store.read_area("a")
		if not check(loaded.get("ok", false) and restored_matches(loaded), "fresh process reconstructs real native dynamic authority"): finish(); return
		check(fixture.world.material_at(65,60) == 0 and fixture.world.material_at(72,60) == 58, "fresh process retains explicit Empty and placed material")
		if mode.begins_with("crash-"):
			advance_native(3)
			var saved := save_current(store, int(opened.manifest.areas.a.mutation_generation) + 1)
			if saved.is_empty(): finish(); return
			if mode == "crash-published":
				check(store.commit_prepared(saved.prepared.receipt, saved.fence).ok, "crash fixture publishes before acknowledgement is observed")
			print("GEN006_STORE_CRASH_READY ", JSON.stringify({"mode":mode, "revision":store.current_manifest().revision,
				"tick":store.current_manifest().clock.game_ticks, "profile":profile}))
			# The external runner terminates this genuinely separate process.
			# Retain the store/OS lock across event-loop frames until that kill.
			set_meta("crash_store_owner", store)
			return
	else:
		check(false, "unknown process test mode")
		finish()
		return
	var manifest: Dictionary = store.current_manifest()
	print("GEN006_STORE_PROCESS ", JSON.stringify({"mode":mode, "revision":manifest.revision, "game_ticks":manifest.clock.game_ticks,
		"native_tick":fixture.world.get_tick_index(), "physical_hash":fixture.world.get_physical_state_hash(),
		"checkpoint_sha256":manifest.areas.a.native_sha256, "failures":failures}))
	store.close_profile()
	finish()


func finish() -> void:
	print("GEN006_STORE checks=", checks, " failures=", failures, " mode=", mode, " profile=", profile)
	quit(0 if failures == 0 else 1)


func run() -> void:
	if not check(ClassDB.class_exists("CyberPersistentAreaStorage") and ClassDB.class_exists("CyberDemoBridge"), "source-built desktop native runtime is loaded"):
		finish(); return
	fixture = Fixture.create()
	if not check(not fixture.has("error"), "real native fixture starts: " + str(fixture.get("error", ""))): finish(); return
	if mode == "unit": unit()
	else: process_mode()
