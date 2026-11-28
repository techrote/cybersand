extends SceneTree

# Independent hostile transport values. This test never pretends its fabricated
# native receipts establish actual C++ execution or physics installation.
const Port = preload("res://scripts/object_shard_m4_workbench_port.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
var checks: int = 0
var failures: Array[String] = []
const OWNER: Dictionary = {"native_instance_id":88,"world_generation":7,"session":12,
	"owner_epoch":9,"shard_session":14,"world_incarnation":5,"transport_generation":3}

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func request(terrain: bool = false) -> Dictionary:
	var r: Dictionary = OWNER.duplicate()
	r.merge({"action_id":1,"port_generation":1,"operation":"erase","position":Vector2i(10,10),
		"captured_usec":1,"admitted_usec":2,"probability_ppm":250000,"seed":42,"material_filter":7,
		"observation":{"world_generation":7,"world_revision":90,"render_serial":8,"session":12,
			"owner_epoch":9,"shard_session":14,"world_incarnation":5,"transport_generation":3,"publication_sequence":45}})
	if terrain:
		r["target"] = {}
		r["domain"] = "terrain"
		r["terrain_cells"] = [Vector2i(10,10),Vector2i(11,10)]
	else:
		var a: Dictionary = {"position":Vector2i(10,10),"owner":4,"cell":61,"generation":2,
			"body_generation":2,"geometry_revision":3,"applied_physics_revision":3,"pose_serial":15,
			"material_revision":9,"incarnation":21,"expected":{"material":7,"state_a":2,"state_b":0,"temperature":240}}
		for key: String in ["session","owner_epoch","shard_session","world_incarnation","transport_generation","publication_sequence"]:
			a[key] = r.observation[key]
		var b: Dictionary = a.duplicate(true)
		b.position = Vector2i(11,10)
		b.cell = 62
		r["target"] = a
		r["targets"] = [a,b]
	return r

func receipt(r: Dictionary) -> Dictionary:
	var native: Dictionary = r.duplicate(true)
	native.merge({"accepted":true,"same_world":true,"transaction_id":13,"requested_cells":2,"unique_cells":2,
		"eligible_cells":2,"changed_cells":1,"removed_cells":1,"geometry_rebuilds":1,"native_edit_ns":100,
		"world_revision":91,"source_target":r.target.duplicate(true),"material_revision":10,"geometry_revision":4,
		"applied_physics_revision":3,"pose_serial":15,"body_generation":2,"incarnation":22,"owner":4,"cell":61})
	if r.has("terrain_cells"):
		native.source_terrain_cells = r.terrain_cells.duplicate()
		native.terrain_changed_cells = [r.terrain_cells[0]]
		native.geometry_rebuilds = 0
	else:
		native.source_targets = r.targets.duplicate(true)
	var terminal: Dictionary = OWNER.duplicate()
	terminal.merge({"action_id":1,"port_generation":1,"outcome":"Applied","native_receipt":native})
	return terminal

func consumed(r: Dictionary, terminal: Dictionary) -> Dictionary:
	var port: RefCounted = Port.new(true)
	port._pending[1] = r.duplicate(true)
	var result: Dictionary = port.consume_receipt(terminal)
	return {"result":result,"pending":port.pending_count(),"held":port.held_reason()}

func _run() -> void:
	for terrain: bool in [false,true]:
		var r: Dictionary = request(terrain)
		var original: Dictionary = receipt(r)
		expect(Worker._m4_action_payload_valid(r),"bounded complete batch transport payload accepted / "+str(terrain))
		var valid: Dictionary = consumed(r,original)
		expect(valid.result.outcome=="Applied" and valid.pending==0 and valid.held.is_empty(),"exact batch echo and accounting releases transport / "+str(terrain))
		for key: String in ["requested_cells","unique_cells","eligible_cells","changed_cells","removed_cells","geometry_rebuilds","native_edit_ns"]:
			var bad: Dictionary = original.duplicate(true)
			bad.native_receipt[key] = -1
			var refused: Dictionary = consumed(r,bad)
			expect(refused.pending==1 and refused.held=="UnprovenNativeApplication","negative batch count cannot masquerade as application / "+key+" / "+str(terrain))
		for key: String in ["seed","probability_ppm","material_filter"]:
			var bad: Dictionary = original.duplicate(true)
			bad.native_receipt[key] += 1
			expect(consumed(r,bad).held=="UnprovenNativeApplication","selection echo mismatch holds / "+key+" / "+str(terrain))
		var bad: Dictionary = original.duplicate(true)
		bad.native_receipt.changed_cells = 3
		expect(consumed(r,bad).held=="UnprovenNativeApplication","more changed material than admitted unique cells holds / "+str(terrain))
		bad = original.duplicate(true)
		if terrain: bad.native_receipt.source_terrain_cells[1] = Vector2i(999,999)
		else: bad.native_receipt.source_targets[1].expected.temperature += 1
		expect(consumed(r,bad).held=="UnprovenNativeApplication","second target tamper cannot hide behind first witness / "+str(terrain))
		var oversized: Dictionary = r.duplicate(true)
		var field: String = "terrain_cells" if terrain else "targets"
		for index: int in range(4095): oversized[field].append(r[field][0])
		expect(not Worker._m4_action_payload_valid(oversized),"4097 raw targets refuse before native allocation / "+str(terrain))
		bad = original.duplicate(true)
		bad.native_receipt.removed_cells = 0
		expect(consumed(r,bad).held=="UnprovenNativeApplication","erase requires exact intentionally removed material debit / "+str(terrain))
		bad = original.duplicate(true)
		bad.native_receipt.geometry_rebuilds = 1 if terrain else 0
		expect(consumed(r,bad).held=="UnprovenNativeApplication","domain and actual material change determine geometry rebuild count / "+str(terrain))
		var wrong_position: Dictionary = r.duplicate(true)
		wrong_position.position = Vector2i(15,15)
		expect(not Worker._m4_action_payload_valid(wrong_position),"outer position must equal first explicit target / "+str(terrain))
	var terrain_request: Dictionary = request(true)
	var nested: Dictionary = terrain_request.duplicate(true)
	nested.target = {"unused":[{"unbounded":[{"payload":[1,2,3]}]}]}
	expect(not Worker._m4_action_payload_valid(nested),"terrain may not smuggle unused nested target containers")
	var bad_terrain: Dictionary = receipt(terrain_request)
	bad_terrain.native_receipt.terrain_changed_cells = [Vector2i(90,90)]
	expect(consumed(terrain_request,bad_terrain).held=="UnprovenNativeApplication","unrequested terrain write in receipt holds")
	bad_terrain = receipt(terrain_request)
	bad_terrain.native_receipt.terrain_changed_cells = [Vector2i(10,10),Vector2i(10,10)]
	bad_terrain.native_receipt.changed_cells = 2
	expect(consumed(terrain_request,bad_terrain).held=="UnprovenNativeApplication","duplicated terrain receipt cannot inflate authored material accounting")
	var r: Dictionary = request(false)
	var malformed_clock: Dictionary = receipt(r)
	malformed_clock["transport_timing"] = {"captured_usec":[{"unexpected":"metadata"}],"admitted_usec":2,
		"worker_started_usec":3,"worker_completed_usec":4}
	var observed_clock: Dictionary = consumed(r,malformed_clock)
	expect(observed_clock.result.outcome=="Applied" and observed_clock.result.timing.get("timing_valid",true)==false,
		"malformed observational clock metadata cannot crash or grant material authority")
	var refused_terminal: Dictionary = receipt(r)
	refused_terminal.outcome = "Refused"
	refused_terminal.erase("native_receipt")
	refused_terminal["refusal"] = {"outcome":"DestinationUnavailable","detail":"protected contact "+"x".repeat(300),
		"requested_cells":999999,"unique_cells":2,"eligible_cells":0,"targets":[{"unexpected":[1,2,3]}]}
	var preserved: Dictionary = consumed(r,refused_terminal)
	expect(preserved.result.outcome=="Refused" and preserved.pending==0 and preserved.held.is_empty(),
		"authenticated terminal refusal retires admission without claiming application")
	expect(preserved.result.refusal.native_outcome=="DestinationUnavailable" and preserved.result.refusal.detail.length()==160,
		"specific protected-contact refusal and bounded detail survive transport")
	expect(preserved.result.refusal.requested_cells==2 and preserved.result.refusal.eligible_cells==0 \
		and preserved.result.refusal.domain=="structural" and preserved.result.refusal.operation=="erase",
		"refusal footprint and operation remain bound to admitted request")
	expect(not preserved.result.refusal.has("targets") and preserved.result.native_receipt.is_empty(),
		"descriptive refusal discards nested target payload and never becomes native application authority")
	nested = r.duplicate(true)
	nested["terrain_cells"] = [{"unused":[{"payload":[1,2,3]}]}]
	expect(not Worker._m4_action_payload_valid(nested),"moving batch may not smuggle unused terrain containers")
	nested = r.duplicate(true)
	nested.targets[1].owner += 1
	expect(not Worker._m4_action_payload_valid(nested),"one worker batch cannot mix structural owners")
	nested = r.duplicate(true)
	nested.target = nested.targets[1].duplicate(true)
	expect(not Worker._m4_action_payload_valid(nested),"first full witness must match the separately authenticated primary target")
	for key: String in ["owner","cell","body_generation","pose_serial"]:
		var bad_owner: Dictionary = receipt(r)
		bad_owner.native_receipt[key] += 1
		expect(consumed(r,bad_owner).held=="UnprovenNativeApplication","resulting owner identity is bound to first exact witness / "+key)
	var ignite: Dictionary = r.duplicate(true)
	ignite.operation = "ignite"
	var ignited: Dictionary = receipt(ignite)
	ignited.native_receipt.geometry_rebuilds = 0
	ignited.native_receipt.removed_cells = 0
	expect(consumed(ignite,ignited).result.outcome=="Applied","ignition changes material state without erase debit or geometry rebuild")
	ignited.native_receipt.geometry_rebuilds = 1
	expect(consumed(ignite,ignited).held=="UnprovenNativeApplication","ignition receipt cannot claim an unexpected geometry replacement")
	var noop: Dictionary = receipt(r)
	noop.native_receipt.changed_cells = 0
	noop.native_receipt.removed_cells = 0
	noop.native_receipt.geometry_rebuilds = 0
	expect(consumed(r,noop).result.outcome=="Applied","authenticated no-op batch has no geometry work")
	noop.native_receipt.geometry_rebuilds = 1
	expect(consumed(r,noop).held=="UnprovenNativeApplication","no-op cannot claim a geometry replacement")
	var partial: Dictionary = receipt(r)
	partial.outcome = "Uncertain"
	partial.may_have_executed = true
	partial.native_receipt.partial = true
	partial.native_receipt.outcome = "Quarantined"
	var port: RefCounted = Port.new(true)
	port._pending[1] = r.duplicate(true)
	var uncertain: Dictionary = port.consume_receipt(partial)
	expect(uncertain.outcome=="NativeEditCompletionUncertain" and uncertain.get("may_have_executed",false),"native partial failure reports uncertain completion")
	expect(port.pending_count()==1 and port.results.back().native_receipt.changed_cells==1,"uncertain native changed prefix and pending identity remain available")
	expect(port.consume_receipt(receipt(r)).outcome=="NativeEditCompletionUncertain","later success cannot erase an uncertain native completion")
	port.retire("WorldReplacement")
	expect(port.pending_count()==0 and port.held_reason().is_empty(),"source-owned World replacement retires uncertainty")
	for key: String in ["session","owner_epoch","shard_session","world_incarnation","transport_generation","publication_sequence"]:
		var target: Dictionary = r.targets[1].duplicate(true)
		target[key] += 1
		expect(Port.target_error(target,target.position,r.observation)=="TargetObservationChanged","foreign second-target envelope refuses / "+key)
	print(JSON.stringify({"schema":"objectshard-live-edit-transport-contract-v1","checks":checks,"failures":failures,
		"scope":"value-only hostile receipt, payload and target authentication; native execution and input integration are separate"}))
	quit(0 if failures.is_empty() else 1)
