extends SceneTree

# Independent value-only transport challenge. No native World or Rapier state
# is created or changed; actual delayed-Main motion remains separately tested.
const Port = preload("res://scripts/object_shard_m4_workbench_port.gd")
const IDENTITY: Dictionary = {"native_instance_id":88,"world_generation":7,"session":12,
	"owner_epoch":9,"shard_session":14,"world_incarnation":5,"transport_generation":3}
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _request(port: RefCounted, id: int, operation: String = "erase", identity: Dictionary = IDENTITY) -> Dictionary:
	var value: Dictionary = identity.duplicate(true)
	value.merge({"action_id":id,"port_generation":port.generation,"operation":operation,
		"position":Vector2i(61,42),"target":{"position":Vector2i(61,42),"owner":4,"cell":61,
		"generation":2,"body_generation":2,"geometry_revision":3,"applied_physics_revision":3,
		"pose_serial":15,"material_revision":9,"incarnation":21,
		"expected":{"material":7,"state_a":2,"state_b":0,"temperature":240}}})
	for key: String in ["session","owner_epoch","shard_session","world_incarnation","transport_generation"]:
		value.target[key] = identity[key]
	value.target.publication_sequence = 45
	return value

func _receipt(request: Dictionary, transaction: int) -> Dictionary:
	var native: Dictionary = request.duplicate(true)
	native.merge({"accepted":true,"same_world":true,"source_target":request.target.duplicate(true),
		"transaction_id":transaction,"material_revision":10,"geometry_revision":4,
		"applied_physics_revision":3,"pose_serial":15,"body_generation":2,
		"incarnation":22,"owner":4,"cell":61})
	var terminal: Dictionary = request.duplicate(true)
	terminal.merge({"outcome":"Applied","native_receipt":native})
	return terminal

func _deliver(port: RefCounted, id: int, transaction: int, operation: String = "erase", identity: Dictionary = IDENTITY) -> Dictionary:
	var request: Dictionary = _request(port,id,operation,identity)
	port._pending[id] = request.duplicate(true)
	return port.consume_receipt(_receipt(request,transaction))

func _publication(next_transaction: Variant, identity: Dictionary = IDENTITY) -> Dictionary:
	var value: Dictionary = identity.duplicate(true)
	value.erase("native_instance_id") # This identity belongs to capabilities.
	value.next_transaction = next_transaction
	return value

func _run() -> void:
	var port: RefCounted = Port.new(true)
	_expect(port.latest_edit_presented({},{}),"no prior mutation adds no delivery fence")
	_expect(_deliver(port,1,9).get("outcome")=="Applied","complete value-only erase receipt validates")
	_expect(not port.latest_edit_presented(_publication(9),IDENTITY),"equal transaction still predates the acknowledged edit")
	_expect(port.latest_edit_presented(_publication(10),IDENTITY),"strictly later same-owner publication closes the edit fence")
	_expect(_deliver(port,2,7).get("outcome")=="Applied","older validated receipt can arrive after a newer one")
	_expect(not port.latest_edit_presented(_publication(8),IDENTITY),"out-of-order receipt cannot lower the required transaction")
	_expect(port.latest_edit_presented(_publication(10),IDENTITY),"high-water mark survives out-of-order delivery")
	_expect(_deliver(port,3,12,"ignite").get("outcome")=="Applied","validated ignition advances the same delivery fence")
	_expect(not port.latest_edit_presented(_publication(10),IDENTITY),"earlier erase publication cannot satisfy later ignition")
	_expect(_deliver(port,4,99,"inspect").get("outcome")=="Applied","read-only inspect still validates independently")
	_expect(port.latest_edit_presented(_publication(13),IDENTITY),"inspect does not create a fictitious mutation delivery dependency")
	port.results.clear()
	_expect(not port.latest_edit_presented(_publication(12),IDENTITY),"diagnostic result eviction cannot erase mutation authority")
	_expect(port.latest_edit_presented(_publication(13),IDENTITY),"diagnostic result eviction cannot block an actually later publication")
	for key: String in IDENTITY:
		var foreign: Dictionary = IDENTITY.duplicate(true)
		foreign[key] += 1
		_expect(not port.latest_edit_presented(_publication(13),foreign),"foreign capability identity refuses: "+key)
		if key!="native_instance_id":
			_expect(not port.latest_edit_presented(_publication(13,foreign),IDENTITY),"foreign publication identity refuses: "+key)
	for malformed: Variant in [null,"13",13.0]:
		_expect(not port.latest_edit_presented(_publication(malformed),IDENTITY),"next transaction requires an exact integer: "+str(malformed))
	var conflicting: Dictionary = IDENTITY.duplicate(true)
	conflicting.world_incarnation += 1
	_expect(_deliver(port,5,14,"erase",conflicting).get("outcome")=="ConflictingNativeEditOwner",
		"authenticated receipt cannot replace a different owner inside one port generation")
	_expect(port.pending_count()==1 and port.held_reason()=="ConflictingNativeEditOwner",
		"uncertain conflicting owner remains pending and enters explicit Hold")
	_expect(not port.latest_edit_presented(_publication(100),IDENTITY),"later counters cannot release an owner conflict Hold")
	var previous_generation: int = port.generation
	port.retire("AuthoritativeWorldReplacement")
	_expect(port.generation==previous_generation+1 and port.pending_count()==0 and port.held_reason().is_empty(),
		"real port retirement clears the old generation and pending conflict")
	_expect(port.latest_edit_presented({},{}),"retirement clears the prior delivery identity")
	_expect(_deliver(port,6,1,"erase",conflicting).get("outcome")=="Applied",
		"new port generation accepts its own freshly validated owner")
	_expect(port.latest_edit_presented(_publication(2,conflicting),conflicting),
		"old-owner high-water mark cannot fence a legitimately replaced owner")
	print(JSON.stringify({"schema":"objectshard-m4-edit-delivery-fence-v1",
		"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"checks":checks,"failures":failures,
		"scope":"value-only receipt authentication and delivered-transaction lifetime; no native or physical integration assertion"}))
	quit(0 if failures.is_empty() else 1)
