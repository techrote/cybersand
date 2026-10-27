extends RefCounted

# A borrowed, main-thread-only continuation. Apply keeps the actual actor and
# equipment; this object owns no body, space, joint, session or collider. Closing
# a refused candidate therefore cannot retire the installed owner.
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const Physical = preload("res://scripts/prepared_physical_session.gd")
const PhysicalCatalog = preload("res://scripts/physical_actor_catalog.gd")
const ActorCatalog = preload("res://scripts/actor_rig_catalog.gd")
const MIN_FROZEN_PHYSICS_FRAMES: int = 2
const STATE_VALUE_CAPACITY: int = 65536
var last_error: String = ""
var epoch: int = 0
var base_kind: String = ""
var _bridge: CyberRapierPhysicsBridge
var _bodies: Array[RigidBody2D] = []
var _state_supplier: Callable
var _source_bytes := PackedByteArray()
var _initial_states := PackedFloat32Array()
var _initial_pose := PackedFloat32Array()
var _body_identity: Array = []
var _terrain: Array = []
var _last_frame: int = -1
var _frames: int = 0
var _terrain_verified: bool = false
var _closed: bool = false
var _adopted: bool = false

static func valid_single_configuration(configuration: Dictionary) -> bool:
	if configuration.get("actor_demo_npcs",true): return false
	var producer := StringName(str(configuration.get("actor_producer","")))
	if producer not in CyberActorPrototypeSession.PRODUCERS: return false
	var trial: String = str(configuration.get("physical_trial",""))
	var rig := StringName(str(configuration.get("physical_rig","")))
	var actor := StringName(str(configuration.get("actor_model","")))
	var definitions: Variant = configuration.get("actor_definitions",null)
	if not definitions is Array: return false
	if not trial.is_empty():
		return trial in ["barrel","ripper"] and rig==&"" and actor==&"" and producer==&"human" \
			and definitions.is_empty() and configuration.get("representation","")=="barrel-rapier" \
			and not configuration.get("runtime_recovery_enabled",true)
	if rig!=&"":
		return actor==&"" and PhysicalCatalog.has_rig(rig) and definitions.is_empty() \
			and configuration.get("representation","")=="barrel-rapier" \
			and not configuration.get("runtime_recovery_enabled",true)
	if configuration.get("representation","")!="sampled": return false
	if actor!=&"":
		if not ActorCatalog.has_rig(actor) or definitions.size()!=1 or not definitions[0] is Dictionary: return false
		return definitions[0].size()==3 and str(definitions[0].get("model",""))==str(actor) \
			and str(definitions[0].get("producer",""))==str(producer) \
			and definitions[0].get("position") == Vector2(150,145)
	return producer==&"human" and definitions.is_empty()

func prepare_retained(bridge: CyberRapierPhysicsBridge, values: Array[RigidBody2D],
		kind: String, owner_epoch: int, state_supplier: Callable) -> bool:
	if _bridge != null or bridge == null or not bridge.is_initialized() or values.is_empty() \
		or kind not in ["articulated", "reference_body"] or owner_epoch < 0 \
		or not state_supplier.is_valid() or bridge.pending_hard_surface_chunks() != 0:
		last_error = "Retained default actor requires complete settled owner descriptors"
		return false
	_bridge = bridge; _bodies = values.duplicate(); base_kind = kind; epoch = owner_epoch
	_state_supplier = state_supplier
	_bridge.refresh_all_states()
	_initial_states = _bridge.pack_body_states()
	_initial_pose = Physical._pose_values(_initial_states)
	_body_identity = _current_body_identity()
	if _initial_states.size() != _bodies.size() * Coupling.INPUT_STRIDE:
		last_error = "Retained actor body packet is incomplete"; close(); return false
	for chunk: PackedInt32Array in _bridge._hard_surface_chunk_rectangles:
		_terrain.append(chunk.duplicate())
	var captured: Dictionary = capture_state(_state_supplier.call())
	if not captured.ok:
		last_error = "Retained actor state exceeds copied descriptor capacity"; close(); return false
	_source_bytes = captured.bytes
	_last_frame = Engine.get_physics_frames()
	return true

func owner_kind() -> String:
	return "retained_default_actor"

func physics_bridge() -> CyberRapierPhysicsBridge:
	return _bridge

func bodies() -> Array[RigidBody2D]:
	return _bodies.duplicate()

func initial_body_states() -> PackedFloat32Array:
	return _initial_states.duplicate()

func state_digest() -> String:
	return _source_bytes.hex_encode().sha256_text()

func _current_body_identity() -> Array:
	var result: Array = []
	for body: RigidBody2D in _bodies:
		if not is_instance_valid(body): return []
		result.append([body.get_instance_id(), body.get_rid(),
			PhysicsServer2D.body_get_space(body.get_rid()), body.freeze,
			body.collision_layer, body.collision_mask,
			PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_SLEEPING)])
	return result

func pose_unchanged() -> bool:
	if _closed or _adopted or _bridge == null or not _bridge.is_initialized() \
		or not _state_supplier.is_valid() or _bridge.pending_hard_surface_chunks() != 0 \
		or _current_body_identity() != _body_identity:
		return false
	_bridge.refresh_all_states()
	if Physical._pose_values(_bridge.pack_body_states()) != _initial_pose: return false
	var captured: Dictionary = capture_state(_state_supplier.call())
	return captured.ok and captured.bytes == _source_bytes \
		and _bridge._hard_surface_chunk_rectangles == _terrain

func verify_physics_frame() -> bool:
	if not pose_unchanged():
		last_error = "Retained actor motion, controller, equipment or ownership changed"
		return false
	var frame: int = Engine.get_physics_frames()
	if frame != _last_frame: _frames += 1; _last_frame = frame
	return true

func install_terrain(packed: PackedInt32Array) -> bool:
	if _closed or _bridge==null or not _state_supplier.is_valid():
		last_error="Retained actor borrower is closed";return false
	if not pose_unchanged():
		var actual: Dictionary=capture_state(_state_supplier.call())
		_bridge.refresh_all_states()
		last_error = "Retained actor owner changed before terrain validation (body identities %s, pose %s, copied state %s, terrain %s, pending %d)" % [
			str(_current_body_identity()==_body_identity),str(Physical._pose_values(_bridge.pack_body_states())==_initial_pose),
			str(actual.ok and actual.bytes==_source_bytes),str(_bridge._hard_surface_chunk_rectangles==_terrain),_bridge.pending_hard_surface_chunks()]
		return false
	if _terrain_verified or packed.size() < 3 or packed[0] != _terrain.size() or packed[0] + 2 > packed.size():
		last_error = "Retained actor terrain descriptor count/offset refused (%d versus %d)" % [packed[0] if not packed.is_empty() else -1,_terrain.size()]
		return false
	var cursor: int = packed[0] + 2
	for index: int in range(_terrain.size()):
		var first: int = packed[index + 1]
		var last: int = packed[index + 2]
		if first != cursor or last < first or last > packed.size() \
			or packed.slice(first,last) != _terrain[index]:
			last_error = "Apply cannot retain this actor across changed hard terrain; use authored Restart or F5"
			return false
		cursor = last
	if cursor != packed.size():
		last_error = "Retained actor terrain descriptor has trailing values"; return false
	_terrain_verified = true
	return true

func prepare_terrain_budget(_chunks: int = 8, _microseconds: int = 2000) -> bool:
	# Exact equality was established without changing any installed collider.
	return _terrain_verified and pose_unchanged()

func ready() -> bool:
	return _terrain_verified and _frames >= MIN_FROZEN_PHYSICS_FRAMES and pose_unchanged()

func adopt() -> void:
	# Main keeps the installed wrapper/session. No ownership is transferred to
	# this disposable borrower and no old wrapper is closed on this branch.
	_adopted = true

func close() -> void:
	_closed = true
	_bridge = null; _bodies.clear(); _state_supplier = Callable()
	_terrain.clear(); _source_bytes = PackedByteArray()

static func capture_state(value: Variant) -> Dictionary:
	var budget: Array[int] = [STATE_VALUE_CAPACITY]
	var copied: Dictionary = _copy_state(value,{},budget,0)
	return {"ok":copied.ok,"bytes":var_to_bytes(copied.get("value")) if copied.ok else PackedByteArray()}

static func _copy_state(value: Variant, seen: Dictionary, budget: Array[int], depth: int) -> Dictionary:
	budget[0] -= 1
	if budget[0] < 0 or depth > 32: return {"ok":false}
	if value is Object:
		if not is_instance_valid(value): return {"ok":false}
		var identity: int = value.get_instance_id()
		if seen.has(identity) or value is CyberRapierPhysicsBridge or value.get_script() == null:
			return {"ok":true,"value":["object",identity]}
		seen[identity] = true
		var fields: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
			var child: Dictionary = _copy_state(value.get(property.name),seen,budget,depth+1)
			if not child.ok: return child
			fields[str(property.name)] = child.value
		return {"ok":true,"value":["script_object",identity,fields]}
	if value is Array or value is Dictionary:
		var result: Array = []
		for key: Variant in value.keys() if value is Dictionary else range(value.size()):
			var child: Dictionary = _copy_state(value[key],seen,budget,depth+1)
			if not child.ok: return child
			result.append([key,child.value] if value is Dictionary else child.value)
		return {"ok":true,"value":["dictionary" if value is Dictionary else "array",result]}
	if value is Callable:
		var bound: Dictionary = _copy_state(value.get_bound_arguments(),seen,budget,depth+1)
		if not bound.ok: return bound
		return {"ok":true,"value":["callable",value.get_object_id(),value.get_method(),bound.value]}
	if value is Signal:
		return {"ok":true,"value":["signal",value.get_object_id(),value.get_name()]}
	if value is RID: return {"ok":true,"value":["rid",value.get_id()]}
	return {"ok":true,"value":value}
