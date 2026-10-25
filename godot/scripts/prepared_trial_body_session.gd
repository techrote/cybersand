extends "res://scripts/prepared_physical_session.gd"

# One actual reference-trial rectangle in its permanent private Rapier space.
# Apply supplies a copied live packet; fresh Restart/F5 supplies authored pose
# and zero motion. Neither path rebinds or resets the body after native commit.
const Trial = preload("res://scripts/physical_actor_trial.gd")
var bridge: CyberRapierPhysicsBridge = CyberRapierPhysicsBridge.new()
var _bodies: Array[RigidBody2D] = []
var arm: String = ""
var epoch: int = 0

func owner_kind() -> String: return "trial_body"
func physics_bridge() -> CyberRapierPhysicsBridge: return bridge
func bodies() -> Array[RigidBody2D]: return _bodies

static func valid_input(value: PackedFloat32Array, trial: String) -> bool:
	if trial not in ["barrel","ripper"] or value.size()!=Coupling.INPUT_STRIDE \
		or not Coupling.input_record_valid(value,0): return false
	var size: Vector2 = Trial.body_size(trial)
	return value[Coupling.INPUT_BODY_ID]==1 and value[Coupling.INPUT_SIZE_X]==size.x \
		and value[Coupling.INPUT_SIZE_Y]==size.y

func prepare_trial(parent: Node, template: RigidBody2D, trial: String,
		identity_epoch: int, state: PackedFloat32Array) -> bool:
	if viewport!=null or not is_instance_valid(template) or identity_epoch<1 or not valid_input(state,trial) \
		or not is_finite(template.mass) or template.mass<=0 \
		or not is_equal_approx(template.mass,state[Coupling.INPUT_MASS]):
		last_error="Prepared trial requires one valid actual rectangle and mass";return false
	arm=trial;epoch=identity_epoch
	viewport=SubViewport.new();viewport.name="PreparedTrialBodySpace"
	viewport.size=Vector2i(2,2);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.world_2d=World2D.new();parent.add_child(viewport)
	PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
	var body: RigidBody2D = template.duplicate()
	body.name="PreparedTrialBody";body.freeze=false
	body.collision_layer=1;body.collision_mask=1
	var collision: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
	if collision==null:
		body.free();last_error="Prepared trial template has no rectangle holder";close();return false
	var shape:=RectangleShape2D.new();shape.size=Trial.body_size(trial);collision.shape=shape
	body.position=Vector2(state[Coupling.INPUT_CENTER_X],state[Coupling.INPUT_CENTER_Y])
	body.rotation=state[Coupling.INPUT_ROTATION]
	body.linear_velocity=Vector2(state[Coupling.INPUT_VELOCITY_X],state[Coupling.INPUT_VELOCITY_Y])
	body.angular_velocity=state[Coupling.INPUT_ANGULAR_VELOCITY]
	viewport.add_child(body);_bodies.append(body)
	if bridge.initialize(viewport.world_2d.space,_bodies,PackedVector2Array([shape.size]))!=OK:
		last_error="Prepared trial Rapier bridge refused";close();return false
	# Use the authoritative server values from the live packet, never scene-node
	# transform caches. reset_body deliberately clears velocity and is unsuitable.
	var rid: RID=body.get_rid()
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(state[Coupling.INPUT_ROTATION],Vector2(state[Coupling.INPUT_CENTER_X],state[Coupling.INPUT_CENTER_Y])))
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		Vector2(state[Coupling.INPUT_VELOCITY_X],state[Coupling.INPUT_VELOCITY_Y]))
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,state[Coupling.INPUT_ANGULAR_VELOCITY])
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING,false)
	if not _capture_frozen_pose(): return false
	var actual: PackedFloat32Array=initial_body_states()
	for field: int in range(Coupling.INPUT_STRIDE-1):
		if actual[field]!=state[field]:
			last_error="Prepared trial field %d differs: actual %s / captured %s"%[field,str(actual[field]),str(state[field])];close();return false
	return true

func _capture_frozen_pose() -> bool:
	# Rapier static/frozen mode discards velocity. The private space is instead
	# inactive for automatic physics and remains exclusively manually stepped.
	PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
	bridge.refresh_all_states();_initial_states=bridge.pack_body_states()
	_initial_pose=_pose_values(_initial_states);_last_physics_frame=Engine.get_physics_frames()
	if _initial_states.is_empty(): last_error="Prepared trial actual state is empty";close();return false
	return true

func pose_unchanged() -> bool:
	if viewport==null or not bridge.is_initialized() or _adopted \
		or PhysicsServer2D.space_is_active(viewport.world_2d.space): return false
	for body: RigidBody2D in _bodies:
		if body.freeze: return false
	bridge.refresh_all_states()
	var actual: PackedFloat32Array=_pose_values(bridge.pack_body_states())
	if actual!=_initial_pose:
		last_error="Prepared trial changed actual state: %s / captured %s"%[str(actual),str(_initial_pose)];return false
	return true

func _close_prepared_owner() -> void:
	bridge.shutdown();_bodies.clear()
