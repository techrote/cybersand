extends SceneTree

# Provisional physical-space proof only. Full native/body transaction integration
# is a separate #202 phase; these tests never claim a prepared World was installed.
const Candidate = preload("res://scripts/prepared_physical_session.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Registry = preload("res://scripts/workbench_actor_catalog.gd")
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
	await retained_articulated_pose(host)
	host.queue_free();await process_frame
	finish()

func retained_articulated_pose(host: Node2D) -> void:
	# Ordinary Workbench replacement must retain arbitrary rotated parts. These
	# angles include the one-ULP failure observed after the mixed workshop ran.
	var definitions: Array = []
	var models: Array[String] = ["runner", "crawler", "skimmer"]
	var angles: Array[float] = [-0.185859769583, 1.234567, -1.7320508, 0.33333333]
	for slot: int in models.size():
		var model: String = models[slot]
		var origin := Vector2(100 + slot * 100, 90)
		var control: Dictionary = Registry.default_control(model)
		var retained: Array = []
		var data: Dictionary = Registry.definition(model)
		for index: int in data.parts.size():
			retained.append({"position":origin + data.parts[index].offset,
				"rotation":angles[(slot + index) % angles.size()],
				"linear_velocity":Vector2(2 + index, -3), "angular_velocity":0.1 * index})
		definitions.append({"model":model,"instance_id":slot + 1,"position":origin,
			"producer":Registry.producer_for(str(control.source)),"workbench_control":control,
			"usable_index":control.usable_index,"canvas_extent":Vector2i(512,384),
			"retained_parts":retained,"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,
				"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,
				"torque_multiplier":1.0,"boost_multiplier":2.0}})
	var candidate = Candidate.new()
	expect(candidate.prepare(host,definitions,21),"rotated retained articulated parts prepare in a frozen Workbench owner")
	if candidate.session == null: return
	var initial: PackedFloat32Array = candidate.initial_body_states()
	for frame: int in range(8):
		await physics_frame
		expect(candidate.verify_physics_frame(),"retained articulated exact pose survives deferred scene synchronization: " + candidate.last_error)
		expect(candidate.initial_body_states() == initial,"published initial identity remains immutable")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var builder: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(builder.build_world(world,PackedInt32Array([0,0,512,384,0,0,128,512,8,1])),"retained articulated terrain fixture builds")
	expect(candidate.install_terrain(world.get_hard_surface_chunk_rectangles()),"rotated frozen composition accepts native terrain after real frames")
	for index: int in range(32):
		expect(candidate.prepare_terrain_budget(8,0),"rotated composition terrain preparation preserves exact pose")
		if candidate.ready(): break
	expect(candidate.ready(),"rotated multipart candidate is eligible for atomic adoption")
	# A single representable position step after capture must still fail. This
	# guards against solving deferred notifications by weakening the exact fence.
	var body: RigidBody2D = candidate.bodies()[0]
	var pose: Transform2D = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
	var bits := PackedByteArray()
	bits.resize(4)
	bits.encode_float(0,pose.origin.x)
	bits.encode_u32(0,bits.decode_u32(0) + 1)
	pose.origin.x = bits.decode_float(0)
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,pose)
	expect(not candidate.pose_unchanged() and candidate.last_error.contains("body 1 component 1"),
		"one float32 ULP of post-capture motion still refuses adoption with a body/component diagnostic")
	expect(not candidate.ready(),"changed provisional geometry cannot become ready")
	candidate.close()

func finish() -> void:
	print("PREPARED_PHYSICAL_OWNER: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
