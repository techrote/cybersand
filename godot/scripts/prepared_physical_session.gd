extends RefCounted

# Main-thread-only provisional owner. It keeps its own permanent physics space;
# no scene node, RID or PhysicsServer object crosses the cellular worker boundary.
const Session = preload("res://scripts/physical_actor_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const MIN_FROZEN_PHYSICS_FRAMES: int = 2
var viewport: SubViewport
var session: CyberPhysicalActorSession
var last_error: String = ""
var _initial_states := PackedFloat32Array()
var _initial_pose := PackedFloat32Array()
var _last_physics_frame: int = -1
var _verified_physics_frames: int = 0
var _terrain_installed: bool = false
var _terrain_ready: bool = false
var _adopted: bool = false

func prepare(parent: Node, definitions: Array, epoch: int) -> bool:
	if viewport != null or not Session.valid_definitions(definitions) or epoch < 1:
		last_error = "Invalid provisional physical owner configuration"
		return false
	viewport = SubViewport.new()
	viewport.name = "PreparedPhysicalSpace"
	viewport.size = Vector2i(2,2)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.world_2d = World2D.new()
	parent.add_child(viewport)
	session = Session.new()
	session.name = "PreparedPhysicalActors"
	session.visible = false
	viewport.add_child(session)
	if not session.configure(definitions,viewport.world_2d.space,epoch):
		last_error = session.last_error
		close()
		return false
	# Bridge initialization disables automatic integration for this exact space.
	# Frozen dynamic bodies add a second explicit hold across asynchronous frames.
	session.set_suspended(true)
	return _capture_frozen_pose()

func physics_bridge() -> CyberRapierPhysicsBridge:
	return session.bridge if session != null else null

func bodies() -> Array[RigidBody2D]:
	return session.bodies() if session != null else []

func owner_kind() -> String:
	return "articulated"

func _capture_frozen_pose() -> bool:
	PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
	for body: RigidBody2D in bodies(): body.freeze = true
	physics_bridge().refresh_all_states()
	_initial_states = physics_bridge().pack_body_states()
	_initial_pose = _pose_values(_initial_states)
	_last_physics_frame = Engine.get_physics_frames()
	if _initial_states.is_empty():
		last_error = "Provisional physical owner supplied no actual body states"
		close()
		return false
	return true

static func _pose_values(states: PackedFloat32Array) -> PackedFloat32Array:
	var value: PackedFloat32Array = states.duplicate()
	# Publication serial changes when read; geometry, mass and actual velocities
	# must remain exact. Keep the original serial in the worker-bound mask input.
	for offset: int in range(0,value.size(),Coupling.INPUT_STRIDE):
		value[offset+Coupling.INPUT_SAMPLE_SERIAL] = 0
	return value

func initial_body_states() -> PackedFloat32Array:
	return _initial_states.duplicate()

func pose_unchanged() -> bool:
	var bridge: CyberRapierPhysicsBridge = physics_bridge()
	if viewport == null or bridge == null or _adopted or not bridge.is_initialized(): return false
	for body: RigidBody2D in bodies():
		if not body.freeze: return false
	bridge.refresh_all_states()
	return _pose_values(bridge.pack_body_states()) == _initial_pose

func verify_physics_frame() -> bool:
	if not pose_unchanged():
		last_error = "Provisional physical pose changed before commit"
		return false
	var frame: int = Engine.get_physics_frames()
	if frame != _last_physics_frame:
		_verified_physics_frames += 1
		_last_physics_frame = frame
	return true

func install_terrain(chunks: PackedInt32Array) -> bool:
	if _terrain_installed or not pose_unchanged() or not physics_bridge().queue_hard_surface_chunk_snapshot(chunks):
		last_error = "Provisional terrain snapshot refused"
		return false
	_terrain_installed = true
	return true

func prepare_terrain_budget(chunks: int = 8, microseconds: int = 2000) -> bool:
	if not _terrain_installed or not pose_unchanged():
		last_error = "Provisional physical pose or terrain preparation is unavailable"
		return false
	physics_bridge().process_hard_surface_collider_budget(chunks,microseconds)
	_terrain_ready = physics_bridge().pending_hard_surface_chunks() == 0
	return true

func ready() -> bool:
	return _terrain_installed and _terrain_ready and _verified_physics_frames >= MIN_FROZEN_PHYSICS_FRAMES and pose_unchanged()

func adopt() -> void:
	# The caller has already verified readiness and committed the matching native
	# candidate. This path performs no construction, validation or physics rebind.
	if _adopted: return
	_adopted = true
	for body: RigidBody2D in bodies(): body.freeze = false

func close() -> void:
	_close_prepared_owner()
	if viewport != null:
		viewport.free()
		viewport = null
	_terrain_installed = false
	_terrain_ready = false

func _close_prepared_owner() -> void:
	if session != null:
		session.close()
		session = null
