extends SceneTree

const Prepared = preload("res://scripts/prepared_reference_body_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var assertions: int = 0
var failures: int = 0
var graph: Node
var templates: Array[RigidBody2D] = []
var candidates: Array[RefCounted] = []

func _initialize() -> void: run.call_deferred()

func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value: failures += 1;push_error("LIQUID_REFERENCE_BODY_POSES: "+message)
	return value

func poses_match(states: PackedFloat32Array, positions: PackedVector2Array, rotations: PackedFloat32Array) -> bool:
	if states.size()!=3*Coupling.INPUT_STRIDE: return false
	for index: int in range(3):
		var offset: int = index*Coupling.INPUT_STRIDE
		if states[offset]!=index+1 or states[offset+1]!=positions[index].x or states[offset+2]!=positions[index].y \
			or not is_equal_approx(states[offset+3],rotations[index]) or states[offset+4]!=8 or states[offset+5]!=14 \
			or states[offset+6]!=0 or states[offset+7]!=0 or states[offset+8]!=0 or states[offset+9]!=templates[index].mass:
			return false
	return true

func mask(states: PackedFloat32Array) -> PackedByteArray:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.build_world(world,PackedInt32Array([0,0,1,1,1])): return PackedByteArray()
	world.prepare_rigid_body_coupling(states,false)
	var values := PackedByteArray()
	for y: int in range(160,192):
		for x: int in range(144,280): values.append(world.rigid_body_id_at(x,y))
	return values

func run() -> void:
	# Use exact scene template properties without starting either normal owner.
	graph = load("res://main.tscn").instantiate()
	for name: String in ["TestBody1","TestBody2","TestBody3"]:
		templates.append(graph.get_node("RigidBodies/"+name))
	var original: Array[Dictionary] = []
	for body: RigidBody2D in templates:
		original.append({"transform":body.transform,"velocity":body.linear_velocity,"angular":body.angular_velocity,
			"freeze":body.freeze,"layer":body.collision_layer,"mask":body.collision_mask})
	var water_positions := PackedVector2Array([Vector2(160,176),Vector2(212,176),Vector2(264,176)])
	var zero := PackedFloat32Array([0,0,0])
	var old := Prepared.new();candidates.append(old)
	if not expect(old.prepare_reference(root,templates,Vector2(8,14)),"omitted poses construct existing Water Feel defaults"):
		finish();return
	var explicit := Prepared.new();candidates.append(explicit)
	if not expect(explicit.prepare_reference(root,templates,Vector2(8,14),water_positions,zero),"explicit old defaults construct"):
		finish();return
	expect(poses_match(old.initial_body_states(),water_positions,zero)
		and Prepared._pose_values(old.initial_body_states())==Prepared._pose_values(explicit.initial_body_states()),
		"omitted and explicit defaults preserve all actual pose/size/velocity/mass fields exactly")
	var old_mask: PackedByteArray = mask(old.initial_body_states())
	expect(old_mask==mask(explicit.initial_body_states()) and old_mask.count(1)>0 and old_mask.count(2)>0 and old_mask.count(3)>0,
		"omitted default native mask raster equals explicit defaults and contains all three bodies")
	var positions := PackedVector2Array([Vector2(124,92),Vector2(140,72),Vector2(176,52)])
	var rotations := PackedFloat32Array([0,0.12,-0.1])
	var selected := Prepared.new();candidates.append(selected)
	if not expect(selected.prepare_reference(root,templates,Vector2(8,14),positions,rotations),"explicit desktop constructor poses and rotations construct"):
		finish();return
	expect(poses_match(selected.initial_body_states(),positions,rotations),"actual frozen readback uses all supplied poses with zero initial velocity")
	var captured: PackedFloat32Array = selected.initial_body_states()
	positions[0] = Vector2(900,900);rotations[1] = 1.5
	expect(selected.initial_body_states()==captured and selected.pose_unchanged(),"caller mutation cannot alter copied initial poses or retained graph")
	var position_only := Prepared.new();candidates.append(position_only)
	expect(position_only.prepare_reference(root,templates,Vector2(8,14),water_positions)
		and poses_match(position_only.initial_body_states(),water_positions,zero),"omitted rotation array retains exact zero rotation independently")
	var rotation_only := Prepared.new();candidates.append(rotation_only)
	expect(rotation_only.prepare_reference(root,templates,Vector2(8,14),PackedVector2Array(),PackedFloat32Array([0,0.2,-0.2]))
		and poses_match(rotation_only.initial_body_states(),water_positions,PackedFloat32Array([0,0.2,-0.2])),
		"omitted positions retain exact Water coordinates independently")
	var invalid: Array[Dictionary] = [
		{"positions":PackedVector2Array([Vector2.ZERO,Vector2.ONE]),"rotations":zero},
		{"positions":water_positions,"rotations":PackedFloat32Array([0,0])},
		{"positions":PackedVector2Array([Vector2(INF,0),Vector2.ONE,Vector2.ZERO]),"rotations":zero},
		{"positions":water_positions,"rotations":PackedFloat32Array([0,NAN,0])}]
	for request: Dictionary in invalid:
		var refused := Prepared.new()
		var children: int = root.get_child_count()
		expect(not refused.prepare_reference(root,templates,Vector2(8,14),request.positions,request.rotations)
			and refused.viewport==null and root.get_child_count()==children and not refused.last_error.is_empty()
			and selected.pose_unchanged(),"invalid length/nonfinite request refuses before allocation and retains existing owner")
	for frame: int in range(32):
		await physics_frame
		expect(old.verify_physics_frame() and selected.verify_physics_frame()
			and Prepared._pose_values(selected.initial_body_states())==Prepared._pose_values(captured),
			"real frozen physics frame %d preserves supplied poses and original defaults" % frame)
	expect(selected.install_terrain(PackedInt32Array([1,3,3])) and selected.prepare_terrain_budget() and selected.ready(),
		"supplied-pose owner follows unchanged frozen-frame/terrain readiness contract")
	var retained_viewport: SubViewport = selected.viewport
	var retained_space: RID = selected.viewport.world_2d.space
	var retained_bodies: Array[RigidBody2D] = selected.bodies()
	selected.adopt()
	expect(selected.viewport==retained_viewport and selected.viewport.world_2d.space==retained_space
		and selected.bodies()==retained_bodies and not retained_bodies[0].freeze and not retained_bodies[1].freeze
		and not retained_bodies[2].freeze,"adoption retains exact permanent graph/space and only releases frozen bodies")
	for index: int in range(3):
		var body: RigidBody2D = templates[index]
		expect(original[index]=={"transform":body.transform,"velocity":body.linear_velocity,"angular":body.angular_velocity,
			"freeze":body.freeze,"layer":body.collision_layer,"mask":body.collision_mask},"scene template %d remains untouched" % index)
	var digest := HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(old_mask)
	print("LIQUID_REFERENCE_BODY_POSES_RESULT ",JSON.stringify({"ok":failures==0,"frozen_frames":32,
		"default_mask_sha256":digest.finish().hex_encode(),"explicit_positions":[[124,92],[140,72],[176,52]],
		"scope":"shared prepared three-body pose API; not a new constructor or final runtime qualification"}))
	finish()

func finish() -> void:
	for candidate: RefCounted in candidates: candidate.close()
	if graph!=null: graph.free()
	print("LIQUID_REFERENCE_BODY_POSES: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
