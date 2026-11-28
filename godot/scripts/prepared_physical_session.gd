extends RefCounted

# Main-thread-only provisional owner. It keeps its own permanent physics space;
# no scene node, RID or PhysicsServer object crosses the cellular worker boundary.
const Session = preload("res://scripts/physical_actor_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const MIN_FROZEN_PHYSICS_FRAMES: int = 2
var viewport: SubViewport
var session: CyberPhysicalActorSession
var last_error: String = ""
var _initial_workbench: Dictionary = {}
var _initial_states := PackedFloat32Array()
var _initial_pose := PackedFloat32Array()
var _last_physics_frame: int = -1
var _verified_physics_frames: int = 0
var _terrain_installed: bool = false
var _terrain_ready: bool = false
var _adopted: bool = false
# Optional Main-thread scalar observer. It is not an ownership/ready signal.
var diagnostic_observer: Callable
var _diagnostic_started_usec := 0

func _diagnostic(phase: String, started_usec: int, details: Dictionary = {}) -> void:
	if diagnostic_observer.is_valid(): diagnostic_observer.call(phase,started_usec,details)


func prepare(parent: Node, definitions: Array, epoch: int) -> bool:
	_diagnostic_started_usec = Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
	if viewport != null or not Session.valid_definitions(definitions) or epoch < 1:
		last_error = "Invalid provisional physical owner configuration"
		return false
	_diagnostic("definition_validation",_diagnostic_started_usec,{"expected_epoch":epoch,"actors":definitions.size()})
	var space_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
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
	_diagnostic("physical_space",space_started,{"expected_epoch":epoch})
	if not session.configure(definitions,viewport.world_2d.space,epoch,diagnostic_observer):
		last_error = session.last_error
		close()
		return false
	# Bridge initialization disables automatic integration for this exact space.
	# Frozen dynamic bodies add a second explicit hold across asynchronous frames.
	var frozen_started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
	session.set_suspended(true)
	var captured := _capture_frozen_pose()
	_diagnostic("frozen_pose",frozen_started,{"captured":captured})
	_diagnostic("physical_preparation",_diagnostic_started_usec,{"accepted":captured,"expected_epoch":epoch})
	return captured

func physics_bridge() -> CyberRapierPhysicsBridge:
	return session.bridge if session != null else null

func bodies() -> Array[RigidBody2D]:
	return session.bodies() if session != null else []

func owner_kind() -> String:
	return "articulated"

func _capture_frozen_pose() -> bool:
	PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
	for body: RigidBody2D in bodies():
		# Restored articulated transforms still have pending Node2D notifications.
		# Resolve those notifications before the immutable server-state capture;
		# otherwise the next frame may round an angle by one float32 ULP while
		# this space remains frozen. Exact post-capture pose checks stay required.
		body.force_update_transform()
		body.freeze = true
	physics_bridge().refresh_all_states()
	_initial_states = physics_bridge().pack_body_states()
	_initial_pose = _pose_values(_initial_states)
	if physics_bridge() is Session.WorkbenchBridge:
		_initial_workbench = session.pack_workbench_sample()
		if _initial_workbench.is_empty():
			last_error = "Invalid provisional workbench hull samples"
			close()
			return false
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

func initial_workbench_sample() -> Dictionary:
	return _initial_workbench.duplicate(true)

func pose_unchanged() -> bool:
	var bridge: CyberRapierPhysicsBridge = physics_bridge()
	if viewport == null or bridge == null or _adopted or not bridge.is_initialized():
		last_error = "Provisional physical owner is unavailable or already adopted"
		return false
	for body: RigidBody2D in bodies():
		if not body.freeze:
			last_error = "Provisional physical body %s is not frozen" % body.name
			return false
	bridge.refresh_all_states()
	var current: PackedFloat32Array = _pose_values(bridge.pack_body_states())
	if current.size() != _initial_pose.size():
		last_error = "Provisional physical body-state size changed (%d -> %d)" % [_initial_pose.size(), current.size()]
		return false
	for offset: int in range(current.size()):
		if current[offset] != _initial_pose[offset]:
			last_error = "Provisional physical body %d component %d changed before commit (%.12f -> %.12f)" % [
				1 + offset / Coupling.INPUT_STRIDE, offset % Coupling.INPUT_STRIDE, _initial_pose[offset], current[offset]]
			return false
	return true

func verify_physics_frame() -> bool:
	if not pose_unchanged():
		return false
	var frame: int = Engine.get_physics_frames()
	if frame != _last_physics_frame:
		_verified_physics_frames += 1
		_last_physics_frame = frame
	return true

func install_terrain(chunks: PackedInt32Array) -> bool:
	var started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
	if _terrain_installed:
		last_error = "Provisional terrain was already installed"
		return false
	if not pose_unchanged(): return false
	if not physics_bridge().queue_hard_surface_chunk_snapshot(chunks):
		last_error = "Provisional terrain snapshot refused"
		return false
	_terrain_installed = true
	_diagnostic("terrain_packet",started,{"chunk_values":chunks.size(),
		"since_preparation_usec":Time.get_ticks_usec()-_diagnostic_started_usec if _diagnostic_started_usec > 0 else 0})
	return true

func prepare_terrain_budget(chunks: int = 8, microseconds: int = 2000) -> bool:
	if not _terrain_installed:
		last_error = "Provisional terrain preparation is unavailable"
		return false
	if not pose_unchanged(): return false
	var started := Time.get_ticks_usec() if diagnostic_observer.is_valid() else 0
	physics_bridge().process_hard_surface_collider_budget(chunks,microseconds)
	_terrain_ready = physics_bridge().pending_hard_surface_chunks() == 0
	_diagnostic("terrain_budget",started,{"pending_chunks":physics_bridge().pending_hard_surface_chunks(),
		"ready":_terrain_ready,"frozen_physics_frames":_verified_physics_frames})
	return true

func ready() -> bool:
	return _terrain_installed and _terrain_ready and _verified_physics_frames >= MIN_FROZEN_PHYSICS_FRAMES and pose_unchanged()

func adopt() -> void:
	# The caller has already verified readiness and committed the matching native
	# candidate. This path performs no construction, validation or physics rebind.
	if _adopted: return
	_adopted = true
	for body: RigidBody2D in bodies(): body.freeze = false
	if session != null: session.adopt_retained_motion()
	_diagnostic("physical_adopted",_diagnostic_started_usec,{"frozen_physics_frames":_verified_physics_frames})

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
