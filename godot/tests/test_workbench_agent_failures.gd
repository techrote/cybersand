extends SceneTree

## WB-AGENT-001 failure injection ONLY. This is not native/Godot acceptance:
## test_workbench_agent_owner.gd separately exercises real native World.
const Session = preload("res://scripts/workbench_authoring_session.gd")

class FaultWorld extends RefCounted:
	var revision: int = 1
	var tick_index: int = 0
	var changes: Dictionary = {}
	var emit_calls: int = 0
	var fail_on_call: int = 2

	func has_failed() -> bool:
		return false

	func material_at(x: int, y: int) -> int:
		return int(changes.get(Vector2i(x,y),0))

	func emit_disc(x: int, y: int, radius: int, material: int) -> void:
		assert(radius == 0)
		emit_calls += 1
		if emit_calls == fail_on_call:
			return # Explicitly simulate a native placement refusal.
		changes[Vector2i(x,y)] = material
		revision += 1


var failures: int = 0
var checks: int = 0


func _expect(ok: bool, claim: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error("WB_AGENT_FAILURE: "+claim)


func call_session(session: RefCounted, world: RefCounted,
		action: String, arguments: Dictionary = {}) -> Dictionary:
	var command: Dictionary = arguments.duplicate(true)
	command["action"] = action
	command["schema_version"] = 1
	return session.execute(command,world,1,Vector2i(512,512),true,0,1)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := FaultWorld.new()
	var session = Session.new()
	var a: Dictionary = call_session(session,world,"authorize_task",{
		"task_id":"fault-01",
		"scope":Rect2i(Vector2i(100,100),Vector2i(32,32)),
		"protected":[],
		"allowed_materials":[0,58]
	})
	_expect(a.get("status")=="authorized","authorize synthetic fault fixture")
	var takeover: Dictionary = call_session(session,world,"authorize_task",{
		"task_id":"other-host",
		"scope":Rect2i(Vector2i(0,0),Vector2i(2,2)),
		"protected":[],
		"allowed_materials":[0]
	})
	_expect(takeover.get("status")=="refused"
		and takeover.get("reason")=="task_already_authorized",
		"second host replaced live task on the same World")
	var obs: Dictionary = call_session(session,world,"observe",{
		"region":Rect2i(Vector2i(100,100),Vector2i(3,3))
	})
	_expect(obs.get("status")=="native_observed","observe synthetic fixture")
	var unconfirmed_image: Dictionary = call_session(session,world,"prepare_edit",{
		"observation_id":obs.observation_id,
		"operations":[{"shape":"disc","x":100,"y":100,"radius":0,"material":58}]
	})
	_expect(unconfirmed_image.get("reason")=="observation_not_matched_to_frame",
		"native-only observation was incorrectly sufficient to prepare an edit")
	# This synthetic ACK is confined to the error-injection test. The real
	# owner integration test uses actual post-draw screenshot and upload ACK.
	var confirmed: Dictionary = call_session(session,world,"confirm_observation_frame",{
		"observation_id":obs.observation_id,
		"render_identity":{
			"render_snapshot_serial":1, "world_generation":1,
			"world_revision":world.revision, "tick":world.tick_index
		}
	})
	_expect(confirmed.get("status")=="observation_confirmed",
		"synthetic frame ACK did not establish the fixture premise")
	var proposal: Dictionary = call_session(session,world,"prepare_edit",{
		"observation_id":obs.observation_id,
		"operations":[{"shape":"line","x0":100,"y0":100,
			"x1":102,"y1":100,"material":58}]
	})
	_expect(proposal.get("status")=="proposed" and proposal.get("changed_cells")==3,
		"prepare three source-exact synthetic cells")
	_expect(world.emit_calls==0,"prepare emitted native changes")
	var applied: Dictionary = call_session(session,world,"apply_edit",{
		"proposal_id":proposal.proposal_id
	})
	_expect(applied.get("status")=="unconfirmed"
		and applied.get("reason")=="native_write_readback_mismatch",
		"partial simulated native error falsely reported as applied")
	_expect(int(applied.get("confirmed_writes",-1))==1
		and int(applied.get("issued_writes",-1))==2,
		"partial write counts were not reported precisely")
	_expect(world.material_at(100,100)==58 and world.material_at(101,100)==0,
		"fault fixture didn't actually exercise partial placement")
	var before_duplicate: int = world.emit_calls
	var duplicate: Dictionary = call_session(session,world,"apply_edit",{
		"proposal_id":proposal.proposal_id
	})
	_expect(duplicate==applied and world.emit_calls==before_duplicate,
		"uncertain duplicate outcome re-emitted native mutations")
	var blocked: Dictionary = call_session(session,world,"observe",{
		"region":Rect2i(Vector2i(100,100),Vector2i(3,3))
	})
	_expect(blocked.get("reason")=="authoring_quarantined_after_uncertain_native_outcome",
		"unconfirmed native result did not quarantine the agent")
	var new_task: Dictionary = call_session(session,world,"authorize_task",{
		"task_id":"retry",
		"scope":Rect2i(Vector2i(100,100),Vector2i(32,32)),
		"protected":[],
		"allowed_materials":[0,58]
	})
	_expect(new_task.get("status")=="refused",
		"new task bypassed uncertain-result quarantine")

	print("WB_AGENT_FAILURE: %d assertions, %d failures (synthetic fault injection only)" % [
		checks,failures])
	quit(1 if failures else 0)
