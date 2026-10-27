extends RefCounted

# Explicit dry/inert conformance session. One ordinary asynchronous native owner
# and the existing main-thread Rapier bridge; no alternate physics integrator.
const Worker = preload("res://scripts/solid_detachment_worker.gd")
const DOMAIN := Rect2i(32, 16, 64, 64)
const ANCHORS := Rect2i(0, 67, 128, 13)
const CUT := Rect2i(50, 65, 4, 2)
const SEED := Vector2i(51, 34)
const WALL: int = 1
const BRICK: int = 43

var worker: CyberSimulationWorker
var bridge: CyberRapierPhysicsBridge
var viewport: SubViewport
var body: RigidBody2D
var source_payload: PackedInt32Array = PackedInt32Array()
var source_rectangles: PackedInt32Array = PackedInt32Array()
var source_center := Vector2.ZERO
var source_receipt: Dictionary = {}
var commit_receipt: Dictionary = {}
var final_receipt: Dictionary = {}
var status: String = "closed"
var last_error: String = ""
var active: bool = false
var physics_paused: bool = true
var transaction_busy: bool = false
var generation: int = 0
var request_serial: int = 0
var physics_epoch: int = 0
var _tree: SceneTree
var _parent: Node
var _shapes: Array[CollisionShape2D] = []
var _last_request_paused: bool = true

func open(parent: Node, workers: int = 4) -> bool:
	close()
	_parent = parent
	_tree = parent.get_tree()
	generation += 1
	last_error = ""
	worker = Worker.new()
	# Before start_worker(), this thread is the exclusive native owner.
	var native: Object = worker._world
	if not native.has_method(&"solid_detachment_command") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		return _fail("Source-matched native detachment and Rapier runtime required; no fallback")
	if not native.diagnostic_reset({"workers":workers,"telemetry":false}):
		return _fail("Native diagnostic setup refused")
	native.set_simulation_window_enabled(false)
	for item: Array in [[0,72,128,4,WALL], [50,40,4,32,BRICK], [44,27,29,13,BRICK],
		[54,40,11,4,BRICK], [8,45,3,27,BRICK], [60,32,1,1,0]]:
		if not native.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]):
			return _fail("Native fixture authoring refused")
	# Apply initial region request before frozen source observation.
	if not native.simulation_tick():
		return _fail("Initial native inclusion tick failed")
	set_paused(true)
	if worker.start_worker(Vector2(400, 400)) != OK:
		return _fail("Existing asynchronous worker failed to start")
	var configured: Dictionary = await command({"action":"configure","members":1024,"shapes":128})
	if not configured.get("ok",false):
		return _fail("Native feature admission refused: " + str(configured))
	status = "anchored native terrain"
	return true

func set_paused(paused: bool) -> void:
	physics_paused = paused
	if worker != null:
		worker.set_frame_state(0.0,false,paused,Vector2i(64,64),Vector2i.ZERO,Vector2i(160,128),
			0,0,false,true,true)

func command(input: Dictionary) -> Dictionary:
	if worker == null or transaction_busy:
		return {"ok":false,"outcome":"SessionBusyOrClosed"}
	transaction_busy = true
	request_serial += 1
	var id: int = request_serial
	var owner_generation: int = generation
	var request: Dictionary = input.duplicate(true)
	request["request_id"] = id
	worker.queue_lab({"solid_detachment":request})
	var end: int = Time.get_ticks_msec() + 10000
	while generation == owner_generation and worker != null and Time.get_ticks_msec() < end:
		var reply: Dictionary = worker.take_solid_reply(id)
		if not reply.is_empty():
			transaction_busy = false
			return reply
		await _tree.process_frame
		OS.delay_usec(500)
	transaction_busy = false
	return {"ok":false,"outcome":"SessionRetiredOrTimedOut"}

func observe_intact() -> Dictionary:
	return await command({"action":"prepare","domain":DOMAIN,"anchors":ANCHORS,"seed":SEED})

func cut_and_release() -> bool:
	if active or transaction_busy or worker == null:
		return false
	set_paused(true)
	var this_generation: int = generation
	var prepared: Dictionary = await command({"action":"cut_prepare","domain":DOMAIN,"anchors":ANCHORS,
		"seed":SEED,"cut":CUT})
	if generation != this_generation:
		return false
	if not prepared.get("ok",false):
		return _fail("Cut/extraction refused: " + str(prepared.get("outcome")))
	source_receipt = prepared.duplicate(true)
	source_payload = prepared.members.duplicate()
	source_rectangles = prepared.rectangles.duplicate()
	source_center = prepared.center
	# Only copied native values cross this boundary. The source is still native
	# and fenced while the main thread prepares its inactive actual Rapier RIDs.
	if not await _prepare_body(prepared):
		await command({"action":"cancel","token":prepared.token})
		return _fail("Inactive Rapier geometry preparation failed")
	if generation != this_generation:
		return false
	var acknowledged: Dictionary = await command({"action":"acknowledge","token":prepared.token,
		"body_id":1,"body_generation":generation,"shape_count":_shapes.size(),
		"payload_digest":prepared.payload_digest,"shape_digest":prepared.shape_digest})
	if not acknowledged.get("ok",false):
		await command({"action":"cancel","token":prepared.token})
		_destroy_physics()
		return _fail("Native reservation acknowledgement refused")
	commit_receipt = await command({"action":"commit","token":prepared.token})
	if not commit_receipt.get("ok",false):
		await command({"action":"cancel","token":prepared.token})
		_destroy_physics()
		return _fail("Native commit refused")
	if not _install_terrain(commit_receipt):
		return await _rollback_inactive("Post-commit static terrain repair refused")
	# Both clocks remain held. There can be no physics step between retiring the
	# old static shapes and activation/finalization of the new compound body.
	for shape: CollisionShape2D in _shapes:
		shape.disabled = false
	body.collision_layer = 1
	body.collision_mask = 1
	body.freeze = false
	body.sleeping = false
	physics_epoch += 1
	final_receipt = await command({"action":"finalize","token":prepared.token,"body_id":1,
		"body_generation":generation,"terrain_revision":commit_receipt.commit_revision,"physics_epoch":physics_epoch})
	if not final_receipt.get("ok",false):
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		return await _rollback_inactive("Final contact receipt refused")
	bridge.refresh_all_states()
	active = true
	status = "native aggregate — live Rapier motion"
	set_paused(false)
	return true

func _prepare_body(prepared: Dictionary) -> bool:
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(160,128)
	_parent.add_child(viewport)
	body = RigidBody2D.new()
	body.name = "NativeDetachedTree"
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass = float(prepared.mass)
	body.inertia = float(prepared.inertia)
	body.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector2.ZERO
	body.gravity_scale = 0.094
	body.linear_damp = 0.04
	body.angular_damp = 0.04
	body.position = source_center # Initial placement only; never animated.
	var spans: PackedInt32Array = source_rectangles
	_shapes.clear()
	for i: int in range(0,spans.size(),4):
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(spans[i+2],spans[i+3])
		collision.shape = rectangle
		collision.position = Vector2(spans[i],spans[i+1]) + rectangle.size * 0.5 - source_center
		collision.disabled = true
		body.add_child(collision)
		_shapes.append(collision)
	viewport.add_child(body)
	await _tree.process_frame
	if not is_instance_valid(body) or not body.get_rid().is_valid():
		return false
	bridge = CyberRapierPhysicsBridge.new()
	var bodies: Array[RigidBody2D] = [body]
	if bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([Vector2(29,38)])) != OK:
		return false
	if PhysicsServer2D.body_get_shape_count(body.get_rid()) != int(prepared.shape_count):
		return false
	# Install original terrain while dynamic shapes are disabled: useful also
	# for verifying that source retirement really replaces existing colliders.
	return _install_terrain(prepared)

func _install_terrain(receipt: Dictionary) -> bool:
	if bridge == null or not receipt.get("terrain_chunks_valid",false) or \
		str(receipt.get("terrain_snapshot_revision","")) != str(receipt.get("terrain_revision","invalid")):
		return false
	if not bridge.queue_hard_surface_chunk_snapshot(receipt.terrain_chunks):
		return false
	var turns: int = 0
	while bridge.pending_hard_surface_chunks() > 0 and turns < 300:
		bridge.process_hard_surface_collider_budget(16,0)
		turns += 1
	return bridge.pending_hard_surface_chunks() == 0

func _rollback_inactive(reason: String) -> bool:
	var restored: Dictionary = await command({"action":"rollback","token":source_receipt.token})
	if restored.get("ok",false) and _install_terrain(restored):
		physics_epoch += 1
		var finished: Dictionary = await command({"action":"finish_rollback","token":source_receipt.token,
			"body_id":1,"body_generation":generation,"terrain_revision":restored.commit_revision,"physics_epoch":physics_epoch})
		if not finished.get("ok",false):
			reason += "; native rollback completion refused"
	else:
		reason += "; rollback quarantined — reset whole session"
	_destroy_physics()
	return _fail(reason)

func physics_step() -> void:
	if active and not physics_paused and not transaction_busy and bridge != null:
		bridge.step()
	# This dry inert slice deliberately does not misrepresent the compound tree
	# as a filled rectangular native occupancy mask. Dynamic material coupling
	# and aggregate chemistry are NOT admitted by this fixture.

func body_transform() -> Transform2D:
	return bridge.body_transform(0) if bridge != null else Transform2D(0.0,source_center)

func angular_velocity() -> float:
	return float(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)) \
		if is_instance_valid(body) else 0.0

func inspect_active() -> Dictionary:
	var was_paused: bool = physics_paused
	set_paused(true)
	var result: Dictionary = await command({"action":"inspect"})
	set_paused(was_paused)
	return result

func close() -> void:
	generation += 1
	active = false
	physics_paused = true
	if worker != null:
		worker.stop_worker()
	_destroy_physics()
	worker = null
	transaction_busy = false
	status = "closed"

func _destroy_physics() -> void:
	active = false
	if is_instance_valid(body):
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	if bridge != null:
		bridge.shutdown()
		bridge = null
	if is_instance_valid(viewport):
		PhysicsServer2D.space_set_active(viewport.world_2d.space,false)
		viewport.queue_free()
	viewport = null
	body = null
	_shapes.clear()

func _fail(reason: String) -> bool:
	last_error = reason
	status = "REFUSED: " + reason
	physics_paused = true
	return false
