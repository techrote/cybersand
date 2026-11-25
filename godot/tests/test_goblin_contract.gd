extends SceneTree

# Artificial unit fixtures ONLY: no native simulation/game defect claims.
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("GOBLIN_CONTRACT: " + message)

func native(revision: int = 5, tick: int = 0) -> Dictionary:
	return {"generation":4,"revision":revision,"tick":tick,"busy":false,"failed":false}

func observation(revision: int = 5, tick: int = 0) -> Dictionary:
	return {"native":native(revision,tick),"paused":true,"material":7,"fixture_id":"construction",
		"scene_identity":"unit-fixture-only","actors":[],"tool":"Brush","selected_actor":0,"pilot_actor":0,"authored_digest":"unit-start"}

func capture(region: Array, values: Array, revision: int = 5) -> Dictionary:
	return {"region":region.duplicate(),"materials":values.duplicate(),"native_receipt":{
		"kind":"capture","status":"completed","backend":"CyberNativeCellWorld","generation":4,
		"observed_generation":4,"revision":revision,"tick":0,"region":region.duplicate()}}

func record(action: Dictionary) -> Dictionary:
	return {"action":action.duplicate(true),"before":observation(),"after":observation(),"admission":{"accepted":true},
		"native_receipt":{},"status":"completed","classification":"game_observation","error":"","duration_usec":10,
		"capture_before":{},"capture_after":{},"interval":{}}

func persistence_capture(observed: Dictionary, protected: bool = false) -> Dictionary:
	var source: Dictionary = observed.native.duplicate(true)
	source.paused = true
	var result := {"region":[0,0,512,512],"admission":{"status":"queued","operation_id":17},
		"source_before":source.duplicate(true),"source_after":source.duplicate(true),"native_receipt":{
		"kind":"capture","status":"refused" if protected else "completed","backend":"CyberNativeCellWorld",
		"operation_id":17,"generation":source.generation,"observed_generation":source.generation,
		"revision":source.revision,"tick":source.tick,"region":[0,0,512,512],"applied":0,"changed":0}}
	if protected:
		result.error = "artificial protected capture fixture"
		result.native_receipt.reason = "Move or remove the body before editing or copying its covered cells."
	else:
		result.material_sha256 = "a".repeat(64)
		result.count = 512 * 512
	return result

func brush() -> Dictionary:
	var row := record({"id":"brush","args":{"x":20,"y":20,"radius":1}})
	row.after.native = native(6)
	row.capture_before = capture([19,19,3,3],[0,0,0,0,0,0,0,0,0])
	row.capture_after = capture([19,19,3,3],[0,7,0,7,7,7,0,7,0],6)
	row.native_receipt = {"status":"completed","kind":"edit","backend":"CyberNativeCellWorld","applied":5,"changed":5,
		"generation":4,"observed_generation":4,"revision":6,"tick":0}
	return row

func failed(rows: Array, id: String = "") -> bool:
	for item: Dictionary in rows:
		if item.status == "fail" and (id.is_empty() or item.id == id): return true
	return false

func metadata() -> Dictionary:
	return {"fixture_id":"construction","policy":"CONTROL","seed":13,"budget":64,
		"initial_scene_identity":"unit-fixture-only","fixture_version":1,"evidence_kind":"unit_fixture",
		"provenance":{"source_commit":"1".repeat(40),"source_tree":"2".repeat(40),"godot_sha256":"3".repeat(64),
		"native_sha256":"4".repeat(64),"rapier_sha256":"5".repeat(64),"godot_version":"unit-fixture",
		"platform":"unit-fixture","source_dirty":false}}

func test_actions() -> void:
	var actions: Array = [{"id":"pause","args":{}},{"id":"play","args":{"ticks":32}},
		{"id":"wait_ticks","args":{"ticks":1}},{"id":"select_material","args":{"material":58}},
		{"id":"brush","args":{"x":8,"y":503,"radius":4}},{"id":"erase","args":{"x":8,"y":503,"radius":0}},
		{"id":"rectangle","args":{"x0":8,"y0":8,"x1":71,"y1":71}},
		{"id":"outline","args":{"x0":71,"y0":71,"x1":8,"y1":8}},
		{"id":"line","args":{"x0":8,"y0":8,"x1":9,"y1":9}},
		{"id":"select_region","args":{"x0":8,"y0":8,"x1":9,"y1":9}},
		{"id":"fill","args":{"x":8,"y":8}},{"id":"paste","args":{"x":8,"y":8}},
		{"id":"copy","args":{}},{"id":"undo","args":{}},{"id":"redo","args":{}},
		{"id":"camera","args":{"x":256,"y":256,"width":480,"height":135}},
		{"id":"actor_select","args":{"actor_id":8}},{"id":"actor_drive","args":{"direction":"right","ticks":16}},
		{"id":"panel","args":{"panel":"details","open":true}},
		{"id":"save_layout","args":{}},{"id":"reopen_layout","args":{}},{"id":"reset_fixture","args":{}},
		{"id":"actor_place","args":{"model":"kestrel","x":32,"y":224}},
		{"id":"actor_pilot","args":{"actor_id":8}},{"id":"actor_reset","args":{}},{"id":"single_step","args":{}}]
	for action: Dictionary in actions:
		check(Transcript.validate_action(action).ok,"finite action " + action.id)
		var restored: Dictionary = JSON.parse_string(JSON.stringify(action))
		check(Transcript.validate_action(restored).ok and Adapter.validate_action(restored).ok,"both readers admit JSON roundtrip " + action.id)
		var extra: Dictionary = action.duplicate(true)
		extra.args.path = "not-a-game-argument"
		check(not Transcript.validate_action(extra).ok,"reject extra argument " + action.id)
	for invalid: Variant in [null,[],"pause",{}, {"id":"arbitrary","args":{}},
		{"id":"brush","args":{"x":true,"y":20,"radius":1}},
		{"id":"brush","args":{"x":7,"y":20,"radius":1}},
		{"id":"brush","args":{"x":8.5,"y":20,"radius":1}},
		{"id":"brush","args":{"x":8,"y":20,"radius":5}},
		{"id":"rectangle","args":{"x0":8,"y0":8,"x1":72,"y1":9}},
		{"id":"play","args":{"ticks":33}},{"id":"wait_ticks","args":{}},
		{"id":"select_material","args":{"material":10}},{"id":"actor_select","args":{"actor_id":0}},
		{"id":"select_material","args":{"material":2.5}},{"id":"select_material","args":{"material":true}},
		{"id":"select_material","args":{"material":"2"}},
		{"id":"camera","args":{"x":0,"y":0,"width":240.5,"height":135}},
		{"id":"camera","args":{"x":0,"y":0,"width":true,"height":135}},
		{"id":"camera","args":{"x":0,"y":0,"width":"240","height":135}},
		{"id":"panel","args":{"panel":"details","open":1}},{"id":"pause","args":{},"goal":"x".repeat(241)}]:
		check(not Transcript.validate_action(invalid).ok and not Adapter.validate_action(invalid).ok,"both readers refuse malformed action")

func test_observers() -> void:
	var oracle := Assertions.new()
	check(not failed(oracle.evaluate(brush())),"five-cell disk expected fixture")
	for mutation: String in ["wrong_material","queued_only","stale_capture","stale_edit","wrong_edit_kind","wrong_count","missing_capture","native_failed"]:
		var bad := brush()
		match mutation:
			"wrong_material": bad.capture_after.materials[4] = 3
			"queued_only": bad.native_receipt.status = "queued"
			"stale_capture": bad.capture_after.native_receipt.generation = 3
			"stale_edit": bad.native_receipt.revision = 5
			"wrong_edit_kind": bad.native_receipt.kind = "capture"
			"wrong_count": bad.native_receipt.applied = 4
			"missing_capture": bad.capture_after = {}
			"native_failed": bad.after.native.failed = true
		oracle.reset()
		check(failed(oracle.evaluate(bad)),"deliberately inconsistent " + mutation + " detected")
	var pause := record({"id":"pause","args":{}})
	pause.interval = {"start_tick":3,"end_tick":3,"observed_frames":3}
	check(not failed(oracle.evaluate(pause)),"settled pause expected fixture")
	pause.interval.end_tick = 4
	check(failed(oracle.evaluate(pause),"paused_native_inactivity"),"artificial paused tick detected")
	pause.interval = {}
	check(failed(oracle.evaluate(pause),"pause_interval_observed"),"missing pause observation fails")
	var play := record({"id":"play","args":{"ticks":4}})
	play.after.paused = false
	play.after.native.tick = 4
	play.interval = {"start_tick":0,"end_tick":4,"observed_frames":3}
	check(not failed(oracle.evaluate(play)),"Play expected observation")
	play.interval.end_tick = 0
	check(failed(oracle.evaluate(play),"native_simulation_progress"),"completed label cannot fabricate native progress")
	var refusal := brush()
	refusal.status = "refused"
	refusal.admission.accepted = false
	refusal.after = refusal.before.duplicate(true)
	check(not failed(oracle.evaluate(refusal)),"unchanged refusal is not a defect")
	refusal.after.native.revision += 1
	check(failed(oracle.evaluate(refusal),"refused_edit_did_not_change_native"),"artificial refused mutation detected")
	refusal.classification = "not_applicable"
	check(not failed(oracle.evaluate(refusal)),"unsupported action is not product failure")
	var camera := record({"id":"camera","args":{"x":128,"y":256,"width":480,"height":270}})
	camera.after.camera = {"origin":[32.0,242.0],"size":[480,270]}
	check(not failed(oracle.evaluate(camera)),"clamped camera float/int equality")
	camera.after.camera.origin[0] = 31.0
	check(failed(oracle.evaluate(camera),"camera_state"),"wrong camera origin detected")
	oracle.reset()
	var edit := brush()
	oracle.evaluate(edit)
	var undo := record({"id":"undo","args":{}})
	undo.before = edit.after.duplicate(true)
	undo.after.native = native(7)
	undo.capture_after = capture([19,19,3,3],edit.capture_before.materials,7)
	check(not failed(oracle.evaluate(undo)),"Undo independently restores prior capture")
	var redo := record({"id":"redo","args":{}})
	redo.before = undo.after.duplicate(true)
	redo.after.native = native(8)
	redo.capture_after = capture([19,19,3,3],edit.capture_after.materials,8)
	check(not failed(oracle.evaluate(redo)),"Redo independently restores edited capture")
	undo.before = redo.after.duplicate(true)
	undo.after.native = native(9)
	undo.capture_after = capture([19,19,3,3],edit.capture_after.materials,9)
	check(failed(oracle.evaluate(undo),"undo_native_materials"),"wrong Undo cannot self-certify")
	var save := record({"id":"save_layout","args":{}})
	save.persistence = {"read_authored_digest":"unit-start"}
	check(not failed(oracle.evaluate(save)),"authored Save expected fixture")
	var reopen := record({"id":"reopen_layout","args":{}})
	reopen.persistence = {"native_material_equality_applicable":true,"saved_material_sha256":"native-start","reopened_material_sha256":"different"}
	check(failed(oracle.evaluate(reopen),"authored_reopen_materials"),"wrong reopened native materials detected")
	reopen.persistence.native_material_equality_applicable = false
	check(failed(oracle.evaluate(reopen),"reopen_material_na_evidence"),"invented material N/A at observed tick zero rejected")
	save.before.native.tick = 1
	save.after.native.tick = 1
	oracle.evaluate(save)
	reopen.persistence.native_material_equality_reason = "evolved_native_tick"
	check(not failed(oracle.evaluate(reopen)),"actual observed evolved Save tick supports authored-only persistence")
	var actor := record({"id":"actor_drive","args":{"direction":"up","ticks":4}})
	actor.interval = {"start_actor_tick":3,"end_actor_tick":8}
	check(failed(oracle.evaluate(actor),"actor_input_admission_observed"),"idle physics advancement cannot establish input delivery")

func test_protected_persistence() -> void:
	var save := record({"id":"save_layout","args":{}})
	save.after.actor_ids = [1]
	save.after.actors = [{"id":1,"observed":true,"model":"reference_barrel","position":[60,60],"linear_velocity":[0,0]}]
	save.before = save.after.duplicate(true)
	save.persistence_capture = persistence_capture(save.after, true)
	save.persistence = {"read_authored_digest":"unit-start","saved_native_tick":0,"material_sha256":"",
		"native_material_equality_applicable":false,"native_material_equality_reason":"native_body_protection"}
	var reopen := record({"id":"reopen_layout","args":{}})
	reopen.before = save.after.duplicate(true)
	reopen.after = save.after.duplicate(true)
	reopen.persistence_capture = persistence_capture(reopen.after, true)
	reopen.persistence = {"saved_native_tick":0,"saved_capture":save.persistence_capture.duplicate(true),
		"saved_material_sha256":"","reopened_material_sha256":"","native_material_equality_applicable":false,
		"native_material_equality_reason":"native_body_protection"}
	var oracle := Assertions.new()
	check(not failed(oracle.evaluate(save)),"exact artificial native body refusal preserves authored Save")
	check(not failed(oracle.evaluate(reopen)),"exact artificial body-protection evidence supports material N/A")
	for mutation: String in ["missing_receipt","other_refusal","missing_actor","stale_source","wrong_operation","changed_cell","invented_reason"]:
		var bad: Dictionary = reopen.duplicate(true)
		match mutation:
			"missing_receipt": bad.persistence_capture.native_receipt = {}
			"other_refusal": bad.persistence_capture.native_receipt.reason = "Unrelated refusal."
			"missing_actor": bad.after.actors = []; bad.after.actor_ids = []
			"stale_source": bad.persistence_capture.source_after.revision = 99
			"wrong_operation": bad.persistence_capture.admission.operation_id = 99
			"changed_cell": bad.persistence_capture.native_receipt.changed = 1
			"invented_reason": bad.persistence.native_material_equality_reason = "anything_else"
		oracle.reset()
		oracle.evaluate(save)
		check(failed(oracle.evaluate(bad)),"artificial persistence inconsistency rejected: " + mutation)
	var complete_save: Dictionary = save.duplicate(true)
	complete_save.persistence_capture = persistence_capture(complete_save.after)
	complete_save.persistence.material_sha256 = "a".repeat(64)
	complete_save.persistence.native_material_equality_applicable = true
	complete_save.persistence.native_material_equality_reason = "available"
	var complete_reopen: Dictionary = reopen.duplicate(true)
	complete_reopen.persistence_capture = persistence_capture(complete_reopen.after)
	complete_reopen.persistence.saved_capture = complete_save.persistence_capture.duplicate(true)
	complete_reopen.persistence.saved_material_sha256 = "a".repeat(64)
	complete_reopen.persistence.reopened_material_sha256 = "a".repeat(64)
	complete_reopen.persistence.native_material_equality_applicable = true
	complete_reopen.persistence.native_material_equality_reason = "available"
	oracle.reset()
	check(not failed(oracle.evaluate(complete_save)) and not failed(oracle.evaluate(complete_reopen)),"complete observed capture digests establish exact material reopen")
	complete_reopen.persistence_capture.material_sha256 = "b".repeat(64)
	check(failed(oracle.evaluate(complete_reopen),"reopen_material_capture_identity"),"equal comparison strings cannot hide a different actual capture digest")
	complete_save.persistence.material_sha256 = "b".repeat(64)
	check(failed(oracle.evaluate(complete_save),"save_material_capture_identity"),"Save comparison digest must match its retained actual capture")

func test_tape() -> void:
	var oracle := Assertions.new()
	var row := brush()
	var tape: Dictionary = Transcript.create(metadata())
	check(Transcript.append(tape,row,oracle.evaluate(row)).ok,"original observation appended")
	Transcript.finish(tape,"completed")
	check(Transcript.validate(tape).ok,"complete unit tape validates")
	var decoded: Variant = JSON.parse_string(JSON.stringify(tape))
	var roundtrip: Dictionary = Transcript.validate(decoded)
	check(roundtrip.ok,"JSON roundtrip fingerprints: " + str(roundtrip.errors))
	check(Transcript.replay_actions(decoded).size() == 1,"bounded action tape decoded")
	check(Transcript.compare(tape,decoded).semantic_match,"JSON readback compares semantically")
	for key: String in ["action","before","after","admission","native_receipt","interval","capture_before","capture_after","assertions"]:
		var malformed: Dictionary = tape.duplicate(true)
		malformed.steps[0][key] = "wrong-type"
		check(not Transcript.validate(malformed).ok,"wrong-type " + key + " rejects safely")
	for key: String in ["source_commit","source_tree","godot_sha256","native_sha256","rapier_sha256"]:
		var malformed: Dictionary = tape.duplicate(true)
		malformed.header.provenance.erase(key)
		check(not Transcript.validate(malformed).ok,"missing " + key + " unqualified")
	var changed: Dictionary = tape.duplicate(true)
	changed.steps[0].capture_after.materials[0] = 58
	check(not Transcript.validate(changed).ok,"mutated readback fingerprint rejects")
	changed = tape.duplicate(true)
	changed.summary.completed_actions += 1
	check(not Transcript.validate(changed).ok,"inflated completion count rejects")
	changed = tape.duplicate(true)
	changed.header.fixture_id = "uncommitted_scene"
	check(not Transcript.validate(changed).ok,"unknown fixture rejects")
	changed = tape.duplicate(true)
	changed.header.seed = -2147483648
	check(Transcript.validate(changed).ok,"signed int32 minimum admitted")
	changed.header.seed = 2147483648
	check(not Transcript.validate(changed).ok,"seed overflow rejects")
	var timed: Dictionary = Transcript.create(metadata())
	row.duration_usec = 99
	Transcript.append(timed,row,oracle.evaluate(row))
	Transcript.finish(timed,"completed")
	var comparison: Dictionary = Transcript.compare(tape,timed)
	check(comparison.semantic_match and not comparison.exact_observation_match,"semantic replay distinct from exact timed observations")
	timed.header.initial_scene_identity = "another-start"
	check(not Transcript.compare(tape,timed).semantic_match,"replay pins initial scene")
	var saved := record({"id":"save_layout","args":{}})
	saved.persistence = {"material_sha256":"a".repeat(64),"native_material_equality_applicable":true}
	var changed_save: Dictionary = saved.duplicate(true)
	changed_save.persistence.material_sha256 = "b".repeat(64)
	check(Transcript.semantic_projection(saved) != Transcript.semantic_projection(changed_save),"semantic replay includes full native persistence digest")
	for malformed_capture: Variant in ["wrong", [], {"native_receipt":"wrong"}, {"admission":[]}, {"source_before":1}, {"source_after":false}]:
		var malformed_row: Dictionary = row.duplicate(true)
		malformed_row.persistence_capture = malformed_capture
		var malformed_tape: Dictionary = Transcript.create(metadata())
		Transcript.append(malformed_tape, malformed_row, oracle.evaluate(row))
		Transcript.finish(malformed_tape, "completed")
		check(not Transcript.validate(malformed_tape).ok,"malformed optional persistence metadata rejected after fingerprinting")
	var tiny := metadata()
	tiny.budget = 1
	var bounded: Dictionary = Transcript.create(tiny)
	check(Transcript.append(bounded,row,[]).ok and not Transcript.append(bounded,row,[]).ok,"explicit budget enforced")

func _initialize() -> void:
	test_actions()
	test_observers()
	test_protected_persistence()
	test_tape()
	test_portable_identity_and_long_tape()
	print("GOBLIN_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence_kind":"unit_fixture",
		"deliberately_inconsistent_data":true,"native_gameplay_executed":false}))
	quit(0 if failures.is_empty() else 1)

func test_portable_identity_and_long_tape() -> void:
	var first: Dictionary = metadata().provenance
	first.platform = "linux"
	first.host = "synthetic-host-one"
	first.replay_identity = {"schema":"cybersand-goblin-replay-identity-v1", "source_commit":first.source_commit,
		"source_tree":first.source_tree, "platform":first.platform, "godot_sha256":first.godot_sha256,
		"native_sha256":first.native_sha256, "rapier_sha256":first.rapier_sha256,
		"game_sources_sha256":"6".repeat(64), "game_source_files":250,
		"import_normalization":"existing-four-rapier-import-descriptors-crlf-to-lf"}
	var second: Dictionary = first.duplicate(true)
	second.host = "synthetic-host-two"
	check(Transcript.same_execution_identity(first, second), "verified portable identity excludes incidental host metadata only")
	for key: String in ["source_commit", "source_tree", "godot_sha256", "native_sha256", "rapier_sha256"]:
		var changed: Dictionary = second.duplicate(true)
		changed[key] = "9".repeat(40 if key in ["source_commit", "source_tree"] else 64)
		check(not Transcript.same_execution_identity(first, changed), "portable identity binds outer provenance " + key)
		changed.replay_identity[key] = changed[key]
		check(not Transcript.same_execution_identity(first, changed), "different admitted portable authority rejects " + key)
	var changed: Dictionary = second.duplicate(true)
	changed.replay_identity.game_sources_sha256 = "9".repeat(64)
	check(not Transcript.same_execution_identity(first, changed), "different canonical game sources reject portable replay")
	changed = second.duplicate(true)
	changed.source_dirty = true
	check(not Transcript.same_execution_identity(first, changed), "dirty source cannot impersonate clean portable identity")
	second.erase("replay_identity")
	check(not Transcript.same_execution_identity(first, second), "portable identity cannot silently fall back to legacy")
	first.erase("replay_identity")
	check(not Transcript.same_execution_identity(first, second), "legacy full provenance remains strict across hosts")
	var header := metadata()
	header.budget = 1024
	header.fixture_version = 2
	header.fixture_sha256 = "7".repeat(64)
	header.pacing_ms = 100
	var long_tape: Dictionary = Transcript.create(header)
	var row := record({"id":"pause", "args":{}})
	row.interval = {"start_tick":0, "end_tick":0, "observed_frames":3}
	# Synthetic observations still need explicit independent assertions.
	var long_assertions: Array = Assertions.new().evaluate(row)
	var all_appended := true
	for index: int in range(1024):
		all_appended = all_appended and Transcript.append(long_tape, row, long_assertions).ok
	check(all_appended and long_tape.steps.size() == 1024, "bounded 1024-action synthetic tape retains every action")
	check(not Transcript.append(long_tape, row, long_assertions).ok, "1025th synthetic record is refused")
	Transcript.finish(long_tape, "budget_complete")
	check(Transcript.validate(long_tape).ok, "long tape independent complete byte bound validates")
	var no_assertions: Dictionary = long_tape.duplicate(true)
	no_assertions.steps[0].assertions = []
	var absent_check: Dictionary = Transcript.validate(no_assertions)
	check(not absent_check.ok and "Step 0 has no independent assertions or explicit applicability result." in absent_check.errors,
		"long synthetic tape cannot omit independent assertions")
	var replay: Dictionary = long_tape.duplicate(true)
	replay.header.fixture_sha256 = "8".repeat(64)
	check(not Transcript.compare(long_tape, replay).semantic_match, "semantic replay binds authored fixture digest")
	replay = long_tape.duplicate(true)
	replay.header.pacing_ms = 0
	check(not Transcript.compare(long_tape, replay).semantic_match, "semantic replay preserves recorded pacing")
