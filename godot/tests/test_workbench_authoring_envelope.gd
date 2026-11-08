extends SceneTree

# WB-AGENT-001 (#526) admission only. No native World or worker is mutated.
# An accepted bounded envelope is not a verified authoring receipt.
const Envelope = preload("res://scripts/workbench_authoring_envelope.gd")

var assertions: int = 0
var failures: int = 0


func _expect(ok: bool, message: String) -> void:
	assertions += 1
	if ok:
		return
	failures += 1
	push_error("WB_AGENT_ENVELOPE: " + message)


func _command(action: String, arguments: Dictionary = {}) -> Dictionary:
	var value: Dictionary = arguments.duplicate(true)
	value["action"] = action
	value["schema_version"] = 1
	return value


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var authorize: Dictionary = _command("authorize_task",{
		"task_id":"strict-envelope",
		"scope":Rect2i(Vector2i(1120,100),Vector2i(200,120)),
		"protected":[Rect2i(Vector2i(1150,100),Vector2i(4,4))],
		"allowed_materials":[0,58]
	})
	_expect(Envelope.valid(authorize),"bounded host authorization rejected")
	_expect(Envelope.valid(_command("observe",{
		"region":Rect2i(Vector2i(1200,100),Vector2i(10,10)),
		"detail":"counts"
	})),"distant valid observation envelope rejected")
	_expect(Envelope.valid(_command("observe")),"default-region observe rejected")
	_expect(Envelope.valid(_command("prepare_edit",{
		"observation_id":"observation:7:1",
		"operations":[{"shape":"line","x0":1100,"y0":300,
			"x1":1110,"y1":300,"material":58,"replace_only_material":0}]
	})),"normal filtered line operation rejected")
	_expect(Envelope.valid(_command("confirm_observation_frame",{
		"observation_id":"observation:7:1",
		"render_identity":{
			"render_snapshot_serial":10,"world_generation":7,
			"world_revision":24,"tick":8,
			"viewport_width":1280,"viewport_height":720
		}
	})),"trusted post-draw identity envelope rejected")
	_expect(Envelope.valid(_command("apply_edit",{
		"proposal_id":"proposal:7:2"
	})),"normal apply request envelope rejected")
	_expect(Envelope.valid(_command("retire_task")),"host retirement envelope rejected")

	var too_many: Array = []
	for i: int in range(9):
		too_many.append({"shape":"disc","x":1200+i,"y":100,
			"radius":0,"material":58})
	_expect(not Envelope.valid(_command("prepare_edit",{
		"observation_id":"observation:7:1","operations":too_many
	})),"ninth primitive admitted to worker copy queue")

	var oversized_protected: Array = []
	for i: int in range(33):
		oversized_protected.append(Rect2i(Vector2i(i,0),Vector2i.ONE))
	var big_authorize: Dictionary = authorize.duplicate(true)
	big_authorize.protected = oversized_protected
	_expect(not Envelope.valid(big_authorize),
		"excess protected-region data admitted to worker deepcopy")

	var junk: Dictionary = _command("apply_edit",{
		"proposal_id":"proposal:7:2",
		"unbounded_payload":PackedByteArray()
	})
	_expect(not Envelope.valid(junk),"unrecognized main-to-owner metadata admitted")

	var extra_operation: Dictionary = _command("prepare_edit",{
		"observation_id":"observation:7:1",
		"operations":[{"shape":"disc","x":1200,"y":100,
			"radius":0,"material":58,"unbounded_payload":[]}]
	})
	_expect(not Envelope.valid(extra_operation),
		"nested unrecognized operation payload admitted")

	var bad_shape: Dictionary = _command("prepare_edit",{
		"observation_id":"observation:7:1",
		"operations":[{"shape":"polygon","vertices":[Vector2i(1,1)],
			"material":58}]
	})
	_expect(not Envelope.valid(bad_shape),"unapproved polygon command admitted")

	var float_coordinate: Dictionary = _command("prepare_edit",{
		"observation_id":"observation:7:1",
		"operations":[{"shape":"disc","x":1200.0,"y":100,
			"radius":0,"material":58}]
	})
	_expect(not Envelope.valid(float_coordinate),
		"non-integer model coordinate silently narrowed")

	var bool_filter: Dictionary = _command("prepare_edit",{
		"observation_id":"observation:7:1",
		"operations":[{"shape":"disc","x":1200,"y":100,
			"radius":0,"material":58,"replace_only_material":true}]
	})
	_expect(not Envelope.valid(bool_filter),
		"boolean native material filter silently converted to integer")

	var missing: Dictionary = _command("confirm_observation_frame",{
		"observation_id":"observation:7:1",
		"render_identity":{"render_snapshot_serial":1,"world_generation":7}
	})
	_expect(not Envelope.valid(missing),"incomplete framebuffer ACK envelope admitted")

	var long_id: Dictionary = _command("apply_edit",{
		"proposal_id":"x".repeat(129)
	})
	_expect(not Envelope.valid(long_id),"unbounded proposal identifier admitted")
	_expect(not Envelope.valid(_command("apply_edit",{
		"proposal_id":""
	})),"empty proposal identifier admitted")

	var incorrect_schema: Dictionary = _command("observe")
	incorrect_schema.schema_version = 999
	_expect(not Envelope.valid(incorrect_schema),"unknown tool schema version admitted")
	incorrect_schema.schema_version = true
	_expect(not Envelope.valid(incorrect_schema),"boolean schema version admitted")
	_expect(not Envelope.valid(_command("execute_arbitrary_code",{
		"command":"rm -rf /"
	})),"unknown host-native action admitted")

	print("WB_AGENT_ENVELOPE: %d assertions, %d failures (admission-only)" % [
		assertions, failures
	])
	quit(1 if failures else 0)
