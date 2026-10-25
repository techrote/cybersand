extends SceneTree

# Provisional physical-space proof only. Full native/body transaction integration
# is a separate #202 phase; these tests never claim a prepared World was installed.
const Candidate = preload("res://scripts/prepared_physical_session.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
var failures: int = 0
var assertions: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PREPARED_PHYSICAL_OWNER: " + message)

func run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	await process_frame
	var unrelated := RigidBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,14);shape.shape = rectangle
	unrelated.add_child(shape)
	unrelated.position = Vector2(400,50)
	unrelated.linear_velocity = Vector2(3,4)
	host.add_child(unrelated)
	var candidate = Candidate.new()
	expect(candidate.prepare(host,[{"model":&"runner","producer":&"human","position":Vector2(64,64)}],7),
		"actual provisional rig, equipment and Rapier bridge configure")
	if candidate.session == null:
		finish();return
	var original_space: RID = candidate.viewport.world_2d.space
	expect(original_space != host.get_viewport().world_2d.space,"provisional graph owns a distinct permanent World2D")
	var initial: PackedFloat32Array = candidate.initial_body_states()
	var untouched: PackedFloat32Array = initial.duplicate()
	initial[1] += 999
	expect(candidate.initial_body_states() == untouched,"worker-bound actual body states are copied values")
	expect(not candidate.ready() and not candidate.prepare_terrain_budget(),"missing initial terrain cannot become ready")
	expect(not candidate.install_terrain(PackedInt32Array([0,1,2])) and candidate.pose_unchanged(),
		"declared terrain refusal leaves the frozen actual body state unchanged")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(bridge.build_world(world,PackedInt32Array([0,0,256,256,0,0,128,256,8,1])),"native terrain control builds")
	var cells_hash: String = world.get_physical_state_hash()
	expect(candidate.install_terrain(world.get_hard_surface_chunk_rectangles()),"copied native terrain chunks admit before adoption")
	var external_start: Transform2D = PhysicsServer2D.body_get_state(unrelated.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	var frame_start: int = Engine.get_physics_frames()
	for _frame: int in range(40):
		await physics_frame
		expect(candidate.verify_physics_frame(),"actual physics-frame pose/velocity stays exact while candidate waits")
		expect(candidate.prepare_terrain_budget(8,0),"bounded initial terrain installs in the frozen permanent space")
		if candidate.ready(): break
	expect(candidate.ready() and Engine.get_physics_frames()-frame_start >= 2,
		"readiness requires complete terrain and multiple verified real physics frames")
	var external_now: Transform2D = PhysicsServer2D.body_get_state(unrelated.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	expect(external_now.origin != external_start.origin,"unrelated active World2D actually integrates across those frames")
	expect(candidate.initial_body_states() == untouched and world.get_physical_state_hash() == cells_hash,
		"frozen actual body input and independent native terrain remain unchanged")
	var retained_session: CyberPhysicalActorSession = candidate.session
	candidate.adopt()
	expect(candidate.session == retained_session and candidate.viewport.world_2d.space == original_space,
		"adoption retains the exact configured graph and physics space without rebind")
	for body: RigidBody2D in candidate.session.bodies(): expect(not body.freeze,"dynamic body thaw occurs only after adoption")
	candidate.session.set_suspended(false)
	for _step: int in range(8):
		candidate.session.advance(candidate.session.bridge.fixed_delta())
		candidate.session.bridge.step()
		candidate.session.complete_step()
	candidate.session.bridge.refresh_all_states()
	expect(candidate.session.bridge.manual_step_count() == 8 and Candidate._pose_values(candidate.session.bridge.pack_body_states())
		!= Candidate._pose_values(untouched),"accepted permanent space resumes real manually stepped physical motion")
	candidate.session.set_suspended(true)
	var retained_pose: PackedFloat32Array = Candidate._pose_values(candidate.session.bridge.pack_body_states())
	var refused = Candidate.new()
	expect(refused.prepare(host,[{"model":&"runner","producer":&"human","position":Vector2(180,64)}],8),"a separate replacement graph stages")
	expect(not refused.install_terrain(PackedInt32Array([2,0,0])),"malformed replacement terrain refuses")
	refused.close()
	for _frame: int in range(3): await physics_frame
	candidate.session.bridge.refresh_all_states()
	expect(candidate.session == retained_session and candidate.viewport.world_2d.space == original_space
		and Candidate._pose_values(candidate.session.bridge.pack_body_states()) == retained_pose,
		"refusal and candidate cleanup retain the prior accepted physical graph and complete paused pose")
	candidate.close()
	host.queue_free();await process_frame
	finish()

func finish() -> void:
	print("PREPARED_PHYSICAL_OWNER: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
