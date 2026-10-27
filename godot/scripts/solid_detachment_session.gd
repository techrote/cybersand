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
var _opening: bool = false
var _release_in_progress: bool = false

func open(parent: Node, workers: int = 4) -> bool:
	close()
	_parent = parent
	_tree = parent.get_tree()
	generation += 1
	_opening = true
	last_error = ""
	worker = Worker.new()
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
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
	if not _owns(owner_generation, owner_worker):
		return false
	_opening = false
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
	var owner_worker: CyberSimulationWorker = worker
	var owner_tree: SceneTree = _tree
	var request: Dictionary = input.duplicate(true)
	request["request_id"] = id
	owner_worker.queue_lab({"solid_detachment":request})
	var end: int = Time.get_ticks_msec() + 10000
	while _owns(owner_generation, owner_worker) and Time.get_ticks_msec() < end:
		var reply: Dictionary = owner_worker.take_solid_reply(id)
		if not reply.is_empty():
			if request_serial == id:
				transaction_busy = false
			return reply
		await owner_tree.process_frame
		OS.delay_usec(500)
	# A retired coroutine must not release a replacement owner's command lock.
	if not _owns(owner_generation, owner_worker):
		return {"ok":false,"outcome":"SessionRetired"}
	if request_serial == id:
		transaction_busy = false
	_fail("Native command timed out; reset the session before retrying")
	return {"ok":false,"outcome":"SessionTimedOut"}

func _owns(owner_generation: int, owner_worker: CyberSimulationWorker) -> bool:
	return generation == owner_generation and worker != null and worker == owner_worker

func observe_intact() -> Dictionary:
	return await command({"action":"prepare","domain":DOMAIN,"anchors":ANCHORS,"seed":SEED})

func cut_and_release() -> bool:
	if active or transaction_busy or worker == null or _opening or _release_in_progress:
		return false
	_release_in_progress = true
	set_paused(true)
	var this_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var prepared: Dictionary = await command({"action":"cut_prepare","domain":DOMAIN,"anchors":ANCHORS,
		"seed":SEED,"cut":CUT})
	if not _owns(this_generation, owner_worker):
		return false
	if not prepared.get("ok",false):
		return _fail("Cut/extraction refused: " + str(prepared.get("outcome")))
	source_receipt = prepared.duplicate(true)
	source_payload = prepared.members.duplicate()
	source_rectangles = prepared.rectangles.duplicate()
	source_center = prepared.center
	# Only copied native values cross this boundary. The source is still native
	# and fenced while the main thread prepares its inactive actual Rapier RIDs.
	var body_ready: bool = await _prepare_body(prepared)
	if not _owns(this_generation, owner_worker):
		return false
	if not body_ready:
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		_destroy_physics()
		return _fail("Inactive Rapier geometry preparation failed")
	var acknowledged: Dictionary = await command({"action":"acknowledge","token":prepared.token,
		"body_id":1,"body_generation":this_generation,"shape_count":_shapes.size(),
		"payload_digest":prepared.payload_digest,"shape_digest":prepared.shape_digest})
	if not _owns(this_generation, owner_worker):
		return false
	if not acknowledged.get("ok",false):
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		_destroy_physics()
		return _fail("Native reservation acknowledgement refused")
	# Store a reply only after proving the receiving session still owns it.
	var committed: Dictionary = await command({"action":"commit","token":prepared.token})
	if not _owns(this_generation, owner_worker):
		return false
	commit_receipt = committed
	if not committed.get("ok",false):
		await command({"action":"cancel","token":prepared.token})
		if not _owns(this_generation, owner_worker):
			return false
		_destroy_physics()
		return _fail("Native commit refused")
	if not _install_terrain(committed):
		return await _rollback_inactive("Post-commit static terrain repair refused")
	# Both clocks remain held. No physics step is permitted between retiring the
	# old static shapes and activation/finalization of the new compound body.
	for shape: CollisionShape2D in _shapes:
		shape.disabled = false
	body.collision_layer = 1
	body.collision_mask = 1
	body.freeze = false
	body.sleeping = false
	physics_epoch += 1
	var finalized: Dictionary = await command({"action":"finalize","token":prepared.token,"body_id":1,
		"body_generation":this_generation,"terrain_revision":committed.commit_revision,"physics_epoch":physics_epoch})
	if not _owns(this_generation, owner_worker):
		return false
	final_receipt = finalized
	if not finalized.get("ok",false):
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		return await _rollback_inactive("Final contact receipt refused")
	bridge.refresh_all_states()
	active = true
	_release_in_progress = false
	status = "native aggregate — live Rapier motion"
	set_paused(false)
	return true

func _prepare_body(prepared: Dictionary) -> bool:
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var owner_tree: SceneTree = _tree
	if owner_worker == null or not is_instance_valid(_parent):
		return false
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
	var prepared_body: RigidBody2D = body
	var prepared_viewport: SubViewport = viewport
	await owner_tree.process_frame
	if not _owns(owner_generation, owner_worker):
		return false
	if body != prepared_body or viewport != prepared_viewport:
		return false
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
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	if owner_worker == null or not source_receipt.has("token"):
		return false
	var token: String = str(source_receipt.token)
	var restored: Dictionary = await command({"action":"rollback","token":token})
	if not _owns(owner_generation, owner_worker):
		return false
	if restored.get("ok",false) and _install_terrain(restored):
		physics_epoch += 1
		var finished: Dictionary = await command({"action":"finish_rollback","token":token,
			"body_id":1,"body_generation":owner_generation,"terrain_revision":restored.commit_revision,"physics_epoch":physics_epoch})
		if not _owns(owner_generation, owner_worker):
			return false
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
	if worker == null or _opening or _release_in_progress or transaction_busy:
		return {"ok":false,"outcome":"SessionBusyOrClosed"}
	var owner_generation: int = generation
	var owner_worker: CyberSimulationWorker = worker
	var was_paused: bool = physics_paused
	set_paused(true)
	var result: Dictionary = await command({"action":"inspect"})
	if not _owns(owner_generation, owner_worker):
		return {"ok":false,"outcome":"SessionRetired"}
	if result.get("ok", false):
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
	_opening = false
	_release_in_progress = false
	source_payload = PackedInt32Array()
	source_rectangles = PackedInt32Array()
	source_center = Vector2.ZERO
	source_receipt = {}
	commit_receipt = {}
	final_receipt = {}
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
	_opening = false
	_release_in_progress = false
	set_paused(true)
	return false
