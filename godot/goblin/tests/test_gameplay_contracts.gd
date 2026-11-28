extends SceneTree

## Deliberately constructed observer inputs. These are harness/oracle contract
## controls, never evidence of in-game coverage or discovered production bugs.
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Expanded = preload("res://goblin/goblin_gameplay_oracles.gd")
const Lineage = preload("res://goblin/goblin_material_lineage.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("GOBLIN_GAMEPLAY_CONTRACT " + label)


func native(generation: int = 1) -> Dictionary:
	return {"generation": generation, "revision": 30, "tick": 0, "failed": false, "paused": true, "busy": false}


func actor() -> Dictionary:
	return {"id": 1, "model": "runner", "position": [120.0, 96.0], "rotation": 0.0,
		"linear_velocity": [0.0, 0.0], "observed": true, "authored_spawn": [120.0, 96.0],
		"options": {"budget": 20.0, "mass_multiplier": 1.0}, "capabilities": {"proxy_count": 6},
		"control_observation": {"producer": "human", "epoch": 5, "control_generation": 3,
			"actor_id": 0, "run_id": "unit-control", "equipment": {}},
		"authored_control": {"source": "human", "enabled": true, "usable_index": 3}}


func record(id: String, args: Dictionary = {}) -> Dictionary:
	var before := {"native": native(), "paused": true, "actors": [actor()], "actor_ids": [1],
		"selected_actor": 1, "pilot_actor": 1, "next_actor_id": 2, "physical_epoch": 5,
		"physical_session_active": true, "physical_body_count": 6, "physical_proxy_count": 6, "physical_ready": true}
	return {"action": {"id": id, "args": args}, "status": "completed", "classification": "game_observation",
		"before": before, "after": before.duplicate(true), "admission": {"accepted": true},
		"native_receipt": {}, "capture_before": {}, "capture_after": {}, "interval": {}}


func outcome(rows: Array[Dictionary], id: String, expected: String, label: String) -> void:
	var found := false
	for row: Dictionary in rows:
		if row.id == id:
			found = true
			check(row.status == expected, label + " / " + str(row.status))
	check(found, label + " / assertion present")


func input_record() -> Dictionary:
	var row := record("actor_trigger", {"button": "trigger", "ticks": 4})
	row.before.paused = false
	row.after.paused = false
	row.before.native.paused = false
	row.after.native.paused = false
	row.after.native.tick = 5
	row.interval = {"start_tick": 0, "end_tick": 4, "start_actor_tick": 0, "end_actor_tick": 4}
	row["actor_delivery"] = {"instance_id": 1,
		"before": {"instance_id": 1, "epoch": 5, "generation": 3, "producer": "human", "accepted": 10, "last_sequence": 9},
		"during": {"instance_id": 1, "epoch": 5, "generation": 3, "producer": "human", "accepted": 14, "last_sequence": 13, "lease_remaining": 5},
		"sampled_command": {"equipment": {"trigger": true}}, "released_command": {"equipment": {"trigger": false}}}
	var equipment := {"instance_id": "unit-equipment", "equipment_epoch": 1, "usable_index": 3,
		"last_receipt": {"request_id": "unit-request", "instance_id": "unit-equipment", "equipment_epoch": 1,
			"usable_index": 3, "generation": 3, "epoch": 5, "run_id": "unit-control", "actor_id": 0,
			"accepted": true, "consumed": true, "charge": 97.8, "cooldown": 0.2}}
	row.after.actors[0].control_observation.equipment = equipment
	return row


func origin_record(id: String, model: String = "monowheel") -> Dictionary:
	# Artificial observations of the published model contract, not game coverage.
	var root_position := [120.0, 97.5] if model == "monowheel" else [120.0, 96.0]
	var body := {"position": root_position.duplicate(), "retained_parts": [{"position": root_position.duplicate()}]}
	if model == "monowheel": body.retained_parts.append({"position": [120.0, 96.0]})
	var value := actor()
	value.model = model
	value.position = root_position.duplicate()
	value["state"] = body.duplicate(true)
	var args: Dictionary = {"model": model, "x": 120, "y": 96} if id == "actor_place" else ({"x": 120, "y": 96} if id == "actor_move" else {})
	var row := record(id, args)
	row.before["adapter_version"] = 2
	row.after["adapter_version"] = 2
	row.before.actors = [value.duplicate(true)]
	row.after.actors = [value.duplicate(true)]
	row.after.native = native(2)
	row.after.physical_epoch = 6
	row["actor_authoring"] = {"spawn": [120.0, 96.0], "authored_after": {"spawn": [120.0, 96.0]},
		"body": body.duplicate(true), "physical_epoch_before": 5, "physical_epoch_after": 6}
	if id == "actor_place":
		row.before.actors = []
		row.before.actor_ids = []
		row.before.next_actor_id = 1
	if id == "actor_replace":
		row.action.args = {"model": model}
		row.before.actors[0].model = "runner"
		row.after.actors[0].id = 2
		row.after.actor_ids = [2]
	return row


func origin_controls() -> void:
	for model: String in ["kestrel", "reference_barrel", "runner", "crawler", "monowheel", "stuntbuggy"]:
		var row := origin_record("actor_place", model)
		var oracle := Assertions.new()
		for id: String in ["actor_place_position", "actor_place_authored_spawn", "actor_place_part_origins"]:
			outcome(oracle.evaluate(row), id, "pass", "exact authored and physical origin / " + model + " / " + id)
		var changed := row.duplicate(true)
		changed.after.actors[0].position[1] += 0.25
		outcome(Assertions.new().evaluate(changed), "actor_place_position", "fail", "shifted actual root rejected / " + model)
		changed = row.duplicate(true)
		changed.after.actors[0].authored_spawn[1] += 0.25
		outcome(Assertions.new().evaluate(changed), "actor_place_authored_spawn", "fail", "shifted authored origin rejected / " + model)
		changed = row.duplicate(true)
		changed.after.actors[0].state.retained_parts[0].position[1] += 0.25
		outcome(Assertions.new().evaluate(changed), "actor_place_part_origins", "fail", "shifted retained root rejected / " + model)
	var row := origin_record("actor_place")
	row.after.actors[0].state.retained_parts[1].position[1] += 0.25
	outcome(Assertions.new().evaluate(row), "actor_place_part_origins", "fail", "shifted monowheel rim rejected")
	row = origin_record("actor_place")
	row.after.actors[0].state.erase("retained_parts")
	outcome(Assertions.new().evaluate(row), "actor_place_part_origins", "fail", "missing current part proof rejected")
	check(Expanded.actor_origin_root("invented_model", [120, 96]).is_empty(), "unknown model has no invented root contract")
	for point: Variant in [[true, 96], [120, NAN], [120, INF], [120], "120,96"]:
		check(Expanded.actor_origin_root("monowheel", point).is_empty(), "malformed authored point rejected " + str(point))
	for id: String in ["actor_reset", "actor_move", "actor_replace"]:
		row = origin_record(id)
		var root_id: String = {"actor_reset": "actor_reset_authored_position", "actor_move": "actor_move_actual_position",
			"actor_replace": "actor_replacement_position"}[id]
		var part_id: String = {"actor_reset": "actor_reset_part_origins", "actor_move": "actor_move_part_origins",
			"actor_replace": "actor_replacement_part_origins"}[id]
		outcome(Assertions.new().evaluate(row), root_id, "pass", id + " reconstructs root from assembly origin")
		outcome(Assertions.new().evaluate(row), part_id, "pass", id + " publishes actual expected part origins")
		row.after.actors[0].position[1] = 96.0
		outcome(Assertions.new().evaluate(row), root_id, "fail", id + " rejects wrongly unshifted physical root")
	row = origin_record("actor_place", "runner")
	row.before.adapter_version = 1
	row.after.adapter_version = 1
	row.after.actors[0].erase("state")
	row.after.actors[0].erase("authored_spawn")
	row.erase("actor_authoring")
	outcome(Assertions.new().evaluate(row), "actor_place_position", "pass", "legacy zero-offset root remains checked")
	outcome(Assertions.new().evaluate(row), "actor_place_part_origins", "not_applicable", "legacy absent part proof is explicit N/A")
	row = origin_record("actor_capture_spawn")
	row.after.actors[0].authored_spawn = [120.0, 97.5]
	outcome(Expanded.evaluate(row), "authored_reset_spawn_readback", "pass", "Capture keeps its existing physical-root coordinate semantics")
	outcome(Expanded.evaluate(row), "spawn_edit_keeps_live_poses", "pass", "Capture does not move an eccentric assembly")


func lineage_receipt(generation: int) -> Dictionary:
	# Artificial canonical-header control. This is never a native receipt claim.
	var bytes := PackedByteArray()
	bytes.resize(52)
	for index: int in range(52): bytes[index] = 0
	var domain := "cybersand-run-receipt-v1".to_utf8_buffer()
	bytes[0] = 24
	for index: int in range(24): bytes[index + 4] = domain[index]
	bytes[28] = 1
	bytes[30] = 2
	bytes[31] = 1
	bytes[32] = 15
	for index: int in range(8): bytes[36 + index] = (generation >> (8 * index)) & 255
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(bytes)
	return {"kind": "applied_run", "schema_version": 1, "session_generation": generation, "completed_tick": 0,
		"canonical_bytes": Array(bytes), "receipt_hash": hasher.finish().hex_encode()}


func lineage_controls() -> void:
	var first := native()
	var receipt := lineage_receipt(1)
	check(Lineage.construction_receipt(receipt, first), "lineage tracker binds the canonical generation header")
	check(Assertions._lineage_receipt(receipt, first), "independent oracle binds the canonical generation header")
	var relabelled := receipt.duplicate(true)
	relabelled.session_generation = 2
	check(not Lineage.construction_receipt(relabelled, native(2)), "tracker rejects old hash with relabelled outer generation")
	check(not Assertions._lineage_receipt(relabelled, native(2)), "oracle rejects old hash with relabelled outer generation")
	for key: String in ["completed_tick", "session_generation", "schema_version"]:
		var malformed := receipt.duplicate(true)
		malformed[key] = false
		check(not Lineage.construction_receipt(malformed, first) and not Assertions._lineage_receipt(malformed, first),
			"lineage construction rejects Boolean " + key)
	var tracker := Lineage.new()
	check(tracker.authored(first, receipt, "fixture_install", true), "actual-style authored acknowledgement seeds tracker")
	var installed_observation := {"native": first.duplicate(), "paused": true, "actor_ids": [], "actors": [],
		"adapter_version": 3, "scene_identity": "artificial-lineage", "authored_digest": "artificial-lineage",
		"material_lineage": tracker.observe(first, true)}
	var oracle := Assertions.new()
	oracle.reset({"ok": true, "observation": installed_observation, "native_receipt": receipt})
	var selected := {"action": {"id": "select_material", "args": {"material": 7}}, "status": "completed",
		"classification": "game_observation", "admission": {"accepted": true}, "native_receipt": {}, "interval": {},
		"before": installed_observation.duplicate(true), "after": installed_observation.duplicate(true)}
	selected.after.material = 7
	outcome(oracle.evaluate(selected), "material_lineage_after", "pass", "oracle independently seeds an authored observation")
	var unseeded := Assertions.new()
	outcome(unseeded.evaluate(selected), "material_lineage_before", "fail", "producer fresh claim cannot replace initialization proof")
	var progressed := first.duplicate()
	progressed.tick = 4
	progressed.revision = 34
	progressed.paused = false
	var exposed: Dictionary = tracker.observe(progressed, false)
	check(exposed.state == "simulation_exposed", "positive native progression records exposure, not a movement claim")
	progressed.paused = true
	var before := {"native": progressed, "paused": true, "material_lineage": tracker.observe(progressed, true)}
	var retained := native(2)
	retained.revision = 35
	var transition := {"action": {"id": "actor_reset", "args": {}}, "before": before,
		"status": "completed", "admission": {"accepted": true}, "native_receipt": lineage_receipt(2)}
	tracker.finish(transition, retained, true)
	check(tracker.observe(retained, true).state == "simulation_exposed", "Reset selected retains exposure across a local clock reset")
	transition.before = {"native": retained, "paused": true, "material_lineage": tracker.observe(retained, true)}
	transition.action.id = "restore_start"
	transition.native_receipt = lineage_receipt(3)
	var restored := native(3)
	tracker.finish(transition, restored, true)
	check(tracker.observe(restored, true).state == "authored_compatible", "Restore start re-establishes authored compatibility")
	# Simulate installation being seen before the enclosing row's missing
	# acknowledgement: the final row must still fail closed.
	tracker.authored(native(4), lineage_receipt(4), "fixture_install", true)
	transition.before = {"native": restored, "paused": true, "material_lineage": {}}
	transition.native_receipt = {}
	tracker.finish(transition, native(4), true)
	check(tracker.observe(native(4), true).state == "unknown", "missing final fresh receipt cannot retain an early compatibility claim")
	tracker.authored(first, receipt, "fixture_install", true)
	var running := first.duplicate()
	running.paused = false
	check(tracker.observe(running, false).state == "unknown", "unobserved running interval is not an authored proof")
	check(tracker.observe(native(2), true).state == "unknown", "unacknowledged generation reset remains unknown")


func run() -> void:
	lineage_controls()
	origin_controls()
	var row := record("actor_remove")
	row.after.native = native(2)
	row.after.actors = []
	row.after.actor_ids = []
	row.after.selected_actor = 0
	row.after.pilot_actor = 0
	row.after.physical_session_active = false
	row.after.physical_ready = false
	row.after.physical_body_count = 0
	row.after.physical_proxy_count = 0
	outcome(Expanded.evaluate(row), "empty_replacement_retires_physical_owner", "pass", "empty World may retain epoch counter")
	row.after.physical_session_active = true
	outcome(Expanded.evaluate(row), "empty_replacement_retires_physical_owner", "fail", "stale actor session is detected")

	row = record("actor_settings", {"field": "mass_multiplier", "value": 1.234})
	row.after.native = native(2)
	row.after.physical_epoch = 6
	row.after.actors[0].options.mass_multiplier = 1.23
	outcome(Expanded.evaluate(row), "actor_tuning_readback", "pass", "ordinary multiplier quantizes to hundredths")
	row.after.actors[0].options.mass_multiplier = 1.24
	outcome(Expanded.evaluate(row), "actor_tuning_readback", "fail", "wrong quantized multiplier is detected")
	row.action.args = {"field": "budget", "value": 15.4}
	row.after.actors[0].options.budget = 15.0
	outcome(Expanded.evaluate(row), "actor_tuning_readback", "pass", "ordinary budget quantizes to integer")

	row = record("actor_capture_spawn")
	row.before.actors[0].position = [95.8294143676758, 209.344680786133]
	row.after.actors[0].position = row.before.actors[0].position.duplicate()
	var ui_value := Vector2(95.83, 209.34)
	row.after.actors[0].authored_spawn = [ui_value.x, ui_value.y]
	outcome(Expanded.evaluate(row), "authored_reset_spawn_readback", "pass", "captured body pose follows actual coordinate control precision")
	outcome(Expanded.evaluate(row), "spawn_edit_keeps_live_poses", "pass", "capturing spawn retains exact live pose")
	row.after.actors[0].authored_spawn[1] += 0.01
	outcome(Expanded.evaluate(row), "authored_reset_spawn_readback", "fail", "wrong captured reset coordinate is detected")

	row = input_record()
	for assertion: Dictionary in Expanded.evaluate(row):
		check(assertion.status == "pass", "complete current input control passes / " + str(assertion.id))
	outcome(Expanded.evaluate(row), "actuator_live_input_admission", "pass", "current human actuator input admitted")
	outcome(Expanded.evaluate(row), "equipment_receipt_current_owner", "pass", "current equipment receipt source admitted")
	outcome(Expanded.evaluate(row), "equipment_receipt_resource_bounds", "pass", "bounded equipment resource receipt admitted")
	for field: String in ["instance_id", "epoch", "generation"]:
		var tampered := row.duplicate(true)
		tampered.actor_delivery.during[field] = -1
		outcome(Expanded.evaluate(tampered), "actuator_live_input_admission", "fail", "stale input " + field + " rejected")
	for field: String in ["equipment_epoch", "generation", "epoch", "actor_id", "usable_index"]:
		var tampered := row.duplicate(true)
		tampered.after.actors[0].control_observation.equipment.last_receipt[field] = -1
		outcome(Expanded.evaluate(tampered), "equipment_receipt_current_owner", "fail", "stale equipment " + field + " rejected")
	row.after.actors[0].control_observation.equipment.last_receipt.charge = 100.1
	outcome(Expanded.evaluate(row), "equipment_receipt_resource_bounds", "fail", "out-of-contract charge rejected")

	row = record("source_place", {"x": 220, "y": 48})
	row.before.material = 2
	row.before.snapshot_serial = 10
	row.after.source = {"pending_commands": 0, "snapshot_serial": 11,
		"receipt": {"origin": [220, 48], "material": 2, "stream_enabled": false, "burst_queued": false, "stream_ticks": 0}}
	outcome(Expanded.evaluate(row), "source_command_consumed_and_published", "pass", "fresh consumed configure receipt passes")
	outcome(Expanded.evaluate(row), "source_configuration_native_ack", "pass", "configured source resets burst and stream")
	row.after.source.snapshot_serial = 10
	outcome(Expanded.evaluate(row), "source_command_consumed_and_published", "fail", "identical old source publication cannot acknowledge new configure")
	row.after.source.snapshot_serial = 11
	row.after.source.pending_commands = 1
	outcome(Expanded.evaluate(row), "source_command_consumed_and_published", "fail", "unconsumed configure cannot complete")

	row = record("actor_place", {"model": "runner", "x": 120, "y": 96})
	row.before.actors = []
	row.before.actor_ids = []
	row.before.next_actor_id = 1
	row.after.native = native(2)
	var bytes := PackedByteArray([1, 2, 3])
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(bytes)
	row.native_receipt = {"canonical_bytes": Array(bytes), "receipt_hash": hasher.finish().hex_encode(),
		"session_generation": 2, "initial_body_count": 6}
	var oracle := Assertions.new()
	outcome(oracle.evaluate(row), "actor_native_construction_receipt", "pass", "six runner collision proxies belong to one logical actor")
	row.native_receipt.initial_body_count = 1
	oracle.reset()
	outcome(oracle.evaluate(row), "actor_native_construction_receipt", "fail", "logical count cannot replace collision proxy count")

	var edge_native := native()
	edge_native.tick = 12
	var publication := {"reason": Expanded.FINITE_CANVAS_REFUSAL, "generation": 1,
		"tick": 12, "serial": 40, "paused": true, "failed": false}
	var proof := Expanded.finite_canvas_refusal(edge_native, publication)
	check(not proof.is_empty(), "actual finite edge contract admits a source-matched legal refusal")
	for change: Dictionary in [{"reason": "The workbench body sample was refused. Rebuild or reset the selected setup."},
		{"reason": "invented refusal"}, {"generation": 2}, {"tick": 11}, {"serial": 0},
		{"serial": true}, {"paused": false}, {"failed": true}]:
		var altered := publication.duplicate(true)
		altered.merge(change, true)
		check(Expanded.finite_canvas_refusal(edge_native, altered).is_empty(), "unqualified edge publication rejected " + str(change))
	for change: Dictionary in [{"failed": true}, {"paused": false}, {"generation": 2}, {"tick": 13}]:
		var altered := edge_native.duplicate(true)
		altered.merge(change, true)
		check(Expanded.finite_canvas_refusal(altered, publication).is_empty(), "wrong current owner cannot acknowledge edge refusal " + str(change))
	row = record("play", {"ticks": 4})
	row.status = "partial"
	row.before.native.tick = 10
	row.after.native = edge_native
	row.after.progress_refusal = proof.duplicate(true)
	row.interval = {"ok": false, "start_tick": 10, "end_tick": 12, "progress_refusal": proof.duplicate(true)}
	row.expected_refusal = proof.duplicate(true)
	check(Expanded.expected_boundary_refusal(row), "bounded partial progress retains expected refusal proof")
	outcome(Expanded.evaluate(row), "finite_canvas_refusal_current_source", "pass", "edge refusal oracle independently checks retained proof")
	var bad_edge := row.duplicate(true)
	bad_edge.after.native.generation = 2
	check(not Expanded.expected_boundary_refusal(bad_edge), "later owner cannot borrow prior boundary refusal")
	outcome(Expanded.evaluate(bad_edge), "finite_canvas_refusal_current_source", "fail", "stale boundary proof is an evidence failure")
	bad_edge = row.duplicate(true)
	bad_edge.admission.accepted = false
	check(not Expanded.expected_boundary_refusal(bad_edge), "unadmitted operation cannot claim partial boundary progress")
	bad_edge = row.duplicate(true)
	bad_edge.interval.end_tick = 11
	check(not Expanded.expected_boundary_refusal(bad_edge), "partial interval must reach the published refusal tick")
	bad_edge = row.duplicate(true)
	bad_edge.classification = "native_failure"
	check(not Expanded.expected_boundary_refusal(bad_edge), "native failure cannot be downgraded to expected edge refusal")
	bad_edge = row.duplicate(true)
	bad_edge.interval.progress_refusal = {}
	check(not Expanded.expected_boundary_refusal(bad_edge), "missing interval refusal cannot prove an interrupted request")
	bad_edge.actor_delivery = {"release_interval": row.interval.duplicate(true)}
	check(Expanded.expected_boundary_refusal(bad_edge), "release interval can independently reach the finite edge")

	var blocked_capture := {"region": [48, 48, 1, 1], "error": Expanded.FINITE_CANVAS_REFUSAL,
		"admission": {"status": "refused", "reason": Expanded.FINITE_CANVAS_REFUSAL}, "native_receipt": {},
		"source_before": edge_native.duplicate(true), "source_after": edge_native.duplicate(true),
		"progress_refusal": proof.duplicate(true)}
	check(Expanded.expected_boundary_capture_refusal(blocked_capture), "published finite-edge stop justifies prequeue capture refusal")
	for change: Dictionary in [{"status": "queued"}, {"accepted": true},
		{"reason": "The workbench body sample was refused. Rebuild or reset the selected setup."},
		{"reason": "Wait for the current paint acknowledgement."}]:
		var altered := blocked_capture.duplicate(true)
		altered.admission.merge(change, true)
		check(not Expanded.expected_boundary_capture_refusal(altered), "unrelated capture admission remains unresolved " + str(change))
	for change: Dictionary in [{"generation": 2}, {"revision": 31}, {"tick": 13}, {"paused": false}, {"failed": true}]:
		var altered := blocked_capture.duplicate(true)
		altered.source_after.merge(change, true)
		check(not Expanded.expected_boundary_capture_refusal(altered), "capture source transition cannot borrow boundary refusal " + str(change))
	for change: Dictionary in [{"generation": 2}, {"tick": 11}, {"serial": 0}, {"reason": "invented"}, {"failed": true}]:
		var altered := blocked_capture.duplicate(true)
		altered.progress_refusal.publication.merge(change, true)
		check(not Expanded.expected_boundary_capture_refusal(altered), "stale or invalid capture publication rejected " + str(change))
	for change: Dictionary in [{"wait_failure_classification": "timeout"}, {"wait_failure_classification": "native_failure"},
		{"native_receipt": {"status": "completed"}}, {"source_matches": true}, {"materials": [0]},
		{"progress_refusal": {}}, {"source_before": null}, {"admission": []}, {"error": ""}]:
		var altered := blocked_capture.duplicate(true)
		altered.merge(change, true)
		check(not Expanded.expected_boundary_capture_refusal(altered), "capture classification requires complete exact refusal evidence " + str(change))
	row = record("brush", {"x": 48, "y": 48, "radius": 0})
	row.status = "refused"
	row.classification = "not_applicable"
	row.admission = {}
	row.before.native = edge_native.duplicate(true)
	row.after.native = edge_native.duplicate(true)
	row.after.progress_refusal = proof.duplicate(true)
	row.capture_before = blocked_capture.duplicate(true)
	outcome(Expanded.evaluate(row), "finite_edge_capture_source_capture_before", "pass", "unadmitted brush keeps exact paused edge proof")
	row.after.native.generation = 2
	outcome(Expanded.evaluate(row), "finite_edge_capture_source_capture_before", "fail", "later World cannot inherit a prior capture refusal proof")

	print("GOBLIN_GAMEPLAY_CONTRACT_RESULT ", JSON.stringify({"checks": checks, "failures": failures,
		"evidence_kind": "unit_fixture", "classification": "deliberately constructed oracle controls"}))
	quit(1 if not failures.is_empty() else 0)
