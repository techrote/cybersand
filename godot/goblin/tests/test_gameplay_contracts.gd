extends SceneTree

## Deliberately constructed observer inputs. These are harness/oracle contract
## controls, never evidence of in-game coverage or discovered production bugs.
const Assertions = preload("res://goblin/goblin_assertions.gd")
const Expanded = preload("res://goblin/goblin_gameplay_oracles.gd")
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


func run() -> void:
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

	print("GOBLIN_GAMEPLAY_CONTRACT_RESULT ", JSON.stringify({"checks": checks, "failures": failures,
		"evidence_kind": "unit_fixture", "classification": "deliberately constructed oracle controls"}))
	quit(1 if not failures.is_empty() else 0)
