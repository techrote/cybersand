extends SceneTree

const Continuation = preload("res://scripts/workbench_same_frame_continuation.gd")
var checks: int = 0
var failures: Array[String] = []
var polls: int = 0
var mailbox: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("SAME_FRAME: " + label)

func identity() -> Dictionary:
	return {"owner":"1","bridge":"-9223372009138813471","worker":"-9223372009138813472","epoch":7,"session":11,"tick":12,
		"manual_steps":12,"sample":13,"bridge_sample":13,"installed_revision":99,
		"accepted_commands":20,"sequences":PackedInt64Array([20,-1]),
		"generations":PackedInt64Array([2,0]),"deadlines":PackedInt64Array([18,-1])}

func packet() -> CyberSimulationSnapshot:
	var value := CyberSimulationSnapshot.new()
	value.rigid_body_epoch = 7
	value.physics_world_generation = 4
	value.hard_surface_chunk_rectangles_valid = true
	value.hard_surface_revision = 99
	value.lab_context = {"workbench_completed_sample":13,"workbench_hard_surface_revision":99,
		"workbench_gcr":{"valid":true,"epoch":7,"session":11,"rows":[{"sample":13},{"sample":13}]}}
	return value

func active(value: CyberSimulationSnapshot) -> Dictionary:
	return {"status":"active","epoch":7,"session":11,"snapshot":value}

func read_mailbox() -> Dictionary:
	polls += 1
	return mailbox

func armed() -> RefCounted:
	var value := Continuation.new()
	value.begin_callback(10,600,100)
	check(value.arm(identity(),4,99,1.0/60.0,110),"a real held callback can arm once")
	return value

func _run() -> void:
	var value := Continuation.new()
	check(not value.arm(identity(),4,99,1.0/60.0,110),"no permit before a real callback")
	check(value.take_ready(10,identity(),read_mailbox).status == "empty" and polls == 0,"empty permit never reads")
	value = armed()
	mailbox = active(packet())
	var result: Dictionary = value.take_ready(10,identity(),read_mailbox)
	check(result.status == "ready" and result.polls == 1 and polls == 1,"ready handoff performs exactly one nonblocking read")
	check(result.callback_serial == 1 and result.process_frame == 10 and result.physics_frame == 600
		and result.callback_started_usec == 100 and result.held_usec == 110,"permit retains original real callback identity")
	check(result.snapshot == mailbox.snapshot,"immutable actual snapshot is retained without fabrication")
	check(value.take_ready(10,identity(),read_mailbox).status == "empty" and polls == 1,"spent permit cannot step or poll twice")
	value.begin_callback(10,601,120)
	check(not value.arm(identity(),4,99,1.0/60.0,130),"a frame with a spent attempt cannot rearm")
	value.begin_callback(11,602,140)
	check(value.arm(identity(),4,99,1.0/60.0,150),"next frame requires its own real callback")
	check(value.take_ready(12,identity(),read_mailbox).status == "frame_expired" and polls == 1,"permit never carries time into a later frame")
	value = armed()
	value.begin_callback(10,601,120)
	check(value.take_ready(10,identity(),read_mailbox).status == "empty","a newer callback discards its predecessor's unspent permit")
	value = armed()
	value.discard()
	check(value.take_ready(10,identity(),read_mailbox).status == "empty","explicit lifecycle discard grants no authority")
	for key: String in Continuation.OWNERS:
		value = armed()
		var changed: Dictionary = identity()
		changed[key] = str(int(changed[key])+1)
		var before: int = polls
		result = value.take_ready(10,changed,read_mailbox)
		check(result.status == "owner_or_input_changed" and polls == before,"changed exact owner " + key + " refuses before polling")
	for key: String in Continuation.SCALARS:
		value = armed()
		var changed: Dictionary = identity()
		changed[key] += 1
		var before: int = polls
		result = value.take_ready(10,changed,read_mailbox)
		check(result.status == "owner_or_input_changed" and polls == before,"changed " + key + " refuses before polling")
	for key: String in Continuation.ARRAYS:
		value = armed()
		var changed: Dictionary = identity()
		changed[key][0] += 1
		var before: int = polls
		result = value.take_ready(10,changed,read_mailbox)
		check(result.status == "owner_or_input_changed" and polls == before,"changed actor " + key + " refuses before polling")
	for state: String in ["contended","transition","retired","failed","invalid"]:
		value = armed()
		mailbox = {"status":state}
		result = value.take_ready(10,identity(),read_mailbox)
		check(result.status == state and result.polls == 1,"mailbox " + state + " fails once without retry")
		check(value.take_ready(10,identity(),read_mailbox).status == "empty","failed read spends its permit")
	for kind: String in ["mailbox_epoch","mailbox_session","packet_epoch","world","failed","refusal",
		"sample","terrain","required_terrain","missing_terrain","gcr_epoch","gcr_session","invalid_gcr","row_sample","empty_rows","large_rows"]:
		value = armed()
		var snap: CyberSimulationSnapshot = packet()
		mailbox = active(snap)
		match kind:
			"mailbox_epoch": mailbox.epoch += 1
			"mailbox_session": mailbox.session += 1
			"packet_epoch": snap.rigid_body_epoch += 1
			"world": snap.physics_world_generation += 1
			"failed": snap.simulation_failed = true
			"refusal": snap.lab_context["workbench_refusal"] = "refused"
			"sample": snap.lab_context.workbench_completed_sample += 1
			"terrain": snap.hard_surface_revision += 1
			"required_terrain": snap.lab_context.workbench_hard_surface_revision += 1
			"missing_terrain": snap.hard_surface_chunk_rectangles_valid = false
			"gcr_epoch": snap.lab_context.workbench_gcr.epoch += 1
			"gcr_session": snap.lab_context.workbench_gcr.session += 1
			"invalid_gcr": snap.lab_context.workbench_gcr.valid = false
			"row_sample": snap.lab_context.workbench_gcr.rows[1].sample += 1
			"empty_rows": snap.lab_context.workbench_gcr.rows = []
			"large_rows": snap.lab_context.workbench_gcr.rows.resize(65)
		result = value.take_ready(10,identity(),read_mailbox)
		check(result.status != "ready" and not result.has("snapshot") and result.polls == 1,"forged or changed " + kind + " fails closed")
	var large: Dictionary = identity()
	large.sequences.resize(9)
	check(not Continuation.valid_identity(large),"actor identity copies are bounded to eight")
	var report := {"schema":"workbench-same-frame-unit-v1","checks":checks,"failures":failures,
		"polls":polls,"godot":Engine.get_version_info().string,"scope":"one-shot admission state, no performance or graphical claim"}
	print("SAME_FRAME_UNIT_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
