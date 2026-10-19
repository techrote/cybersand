extends SceneTree

const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Worker = preload("res://scripts/simulation_worker.gd")
var assertions: int = 0
var failures: int = 0
var desktop: Control


class KeyboardHarness:
	extends "res://scripts/main.gd"
	var allowed: bool = true
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_key_input(false)
	func actor_keyboard_allowed() -> bool:
		return allowed
	func actor_pointer_aim() -> Vector2:
		return Vector2.RIGHT


class TerrainPublicationWorker:
	extends "res://scripts/simulation_worker.gd"
	# Exercise the production owner loop for exactly one publication. Keeping
	# the terrain cache young makes reset/epoch races deterministic; tests read
	# native state only after this exclusive iteration or stop_worker() returns.
	func publish_once() -> CyberSimulationSnapshot:
		_running = true
		_worker_loop()
		return take_latest_snapshot(0)
	func _publish_snapshot(step_ms: float, is_paused: bool, interval: int,
			force_full: bool = false,
			states: PackedFloat32Array = PackedFloat32Array(), body_epoch: int = 0) -> void:
		_last_hard_surface_snapshot_usec = Time.get_ticks_usec()
		super._publish_snapshot(step_ms, is_paused, interval, force_full, states, body_epoch)
		_mutex.lock()
		_running = false
		_mutex.unlock()


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_INTEGRATION: " + message)


func wait_for(predicate: Callable, timeout: int = 20000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false


func installed() -> void:
	expect(await wait_for(func() -> bool:
		return desktop._actor_reset_receipt == 0 and desktop.pending_microscenario_apply.is_empty()),
		"native owner acknowledges actor replacement")
	await process_frame


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func keyboard_contract() -> void:
	var harness = KeyboardHarness.new()
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	harness.add_child(layout)
	var view := TextureRect.new()
	view.name = "World"
	view.material = ShaderMaterial.new()
	layout.add_child(view)
	var label := Label.new()
	label.name = "Status"
	layout.add_child(label)
	var bodies := Node2D.new()
	bodies.name = "RigidBodies"
	harness.add_child(bodies)
	for index: int in range(1, 4):
		var body := RigidBody2D.new()
		body.name = "TestBody%d" % index
		body.freeze = true
		bodies.add_child(body)
	root.add_child(harness)
	harness.physical_rig_id = &"pouncer"
	harness.actor_producer_selection = &"human"
	harness._physical_epoch = 1
	harness.physical_actor_session = Session.new()
	harness.add_child(harness.physical_actor_session)
	expect(harness.physical_actor_session.configure([
		{"model": &"pouncer", "producer": &"human", "position": Vector2(90, 90)}],
		harness.get_world_2d().space, 1), "keyboard fixture uses actual articulated rig")
	harness.physical_actor_session.input_cancelled.connect(harness._on_physical_actor_input_cancelled)
	harness.simulation_worker.set_physical_actor_epoch(1)
	harness.simulation_worker.set_frame_state(0, false, false, Vector2i(90, 90), Vector2i.ZERO,
		Vector2i(100, 100), 0, 0, true, true, true)
	harness.rapier_bridge = harness.physical_actor_session.bridge
	harness._publish_physical_keyboard_input()
	key(KEY_SPACE, true)
	harness._publish_physical_keyboard_input()
	expect(harness.physical_actor_session._commands[0].primary, "Space enters charge channel")
	# Simulate the worker having copied both actors' packets before focus is
	# lost. Admission must revoke only the cancelled actor even after that copy.
	harness.simulation_worker.set_rigid_body_states(PackedFloat32Array(), 1,
		[{"actor_slot": 0}, {"actor_slot": 1}])
	var copied_packets: Array = harness.simulation_worker._pending_physical_effects.duplicate(true)
	expect(harness.simulation_worker._admit_physical_effects(copied_packets, 1).size() == 2,
		"both packets have live owner generations before focus loss")
	harness.allowed = false
	harness._publish_physical_keyboard_input()
	expect(harness.physical_actor_session._commands[0].is_empty(), "focus/UI block cancels held charge")
	var admitted: Array = harness.simulation_worker._admit_physical_effects(copied_packets, 1)
	expect(admitted.size() == 1 and int(admitted[0].actor_slot) == 1,
		"focus loss revokes copied tool work without cancelling another actor")
	expect(harness.simulation_worker._pending_physical_effects.size() == 1,
		"focus loss also removes the actor's queued tool work")
	harness.allowed = true
	harness._publish_physical_keyboard_input()
	expect(harness.physical_actor_session._commands[0].is_empty(), "held key cannot rearm after focus return")
	key(KEY_SPACE, false)
	harness._publish_physical_keyboard_input()
	expect(not harness.physical_actor_session._commands[0].primary, "all-released boundary rearms neutrally")
	key(KEY_M, true)
	key(KEY_E, true)
	harness._publish_physical_keyboard_input()
	expect(harness.physical_actor_session._commands[0].equipment.trigger and harness.physical_actor_session._commands[0].trim == 1.0,
		"tool and trim are independent physical channels")
	key(KEY_M, false)
	key(KEY_E, false)
	harness._publish_physical_keyboard_input()
	# A fresh native epoch and a fully installed collider packet are both
	# required before the desktop may advance its new Rapier assembly.
	harness.latest_snapshot = CyberSimulationSnapshot.new()
	harness.latest_snapshot.hard_surface_revision = 7
	harness.last_hard_surface_revision = 7
	harness.latest_snapshot.rigid_body_epoch = 0
	harness._update_physical_terrain_ready()
	expect(not harness._physical_terrain_ready, "a previous owner's snapshot cannot release the terrain fence")
	harness.latest_snapshot.rigid_body_epoch = 1
	expect(harness.rapier_bridge.queue_hard_surface_chunk_snapshot(
		PackedInt32Array([1, 3, 7, 70, 110, 40, 4])), "initial terrain packet is accepted")
	harness._update_physical_terrain_ready()
	expect(not harness._physical_terrain_ready, "queued but uninstalled terrain cannot release the fence")
	harness.worker_start_error = OK
	harness.paused = false
	var waiting_pose: Transform2D = harness.rapier_bridge.body_transform(0)
	harness._physics_process(1.0 / 60.0)
	expect(harness.physical_actor_session.tick == 0 and harness.rapier_bridge.body_transform(0) == waiting_pose,
		"early unpause holds the actor while initial colliders are missing")
	harness.rapier_bridge.process_hard_surface_collider_budget(1, 0)
	harness._update_physical_terrain_ready()
	expect(harness._physical_terrain_ready and harness.rapier_bridge.hard_surface_shape_count() == 1,
		"complete current terrain automatically releases the fence")
	harness._physics_process(1.0 / 60.0)
	expect(harness.physical_actor_session.tick == 1, "ready actor can advance through normal desktop control")
	harness.free()
	await process_frame


func terrain_publication_contract() -> void:
	var worker := TerrainPublicationWorker.new()
	expect(worker._world.diagnostic_reset({"workers": 1}), "terrain fixture owns a fresh native World")
	expect(worker._world.diagnostic_fill_rect(Vector2i(64, 110), Vector2i(64, 4), 1),
		"terrain fixture installs an initial floor")
	worker.set_frame_state(0, false, true, Vector2i(90, 90), Vector2i(50, 50),
		Vector2i(150, 150), 0, 0, true, true, true)
	worker.set_rigid_body_states(PackedFloat32Array(), 31)
	var initial: CyberSimulationSnapshot = worker.publish_once()
	var old_geometry: PackedInt32Array = initial.hard_surface_chunk_rectangles.duplicate()
	expect(worker._world.diagnostic_fill_rect(Vector2i(64, 110), Vector2i(64, 4), 0)
		and worker._world.diagnostic_fill_rect(Vector2i(64, 150), Vector2i(64, 4), 1),
		"fixture moves the floor inside the terrain publication interval")
	var retained: CyberSimulationSnapshot = worker.publish_once()
	expect(retained.hard_surface_chunk_rectangles == old_geometry,
		"ordinary same-owner edits retain the budgeted terrain cadence")
	worker.set_rigid_body_states(PackedFloat32Array(), 32)
	var replacement: CyberSimulationSnapshot = worker.publish_once()
	expect(replacement.rigid_body_epoch == 32
		and replacement.hard_surface_revision == int(worker._world.hard_surface_revision)
		and replacement.hard_surface_chunk_rectangles == worker._world.get_hard_surface_chunk_rectangles()
		and replacement.hard_surface_chunk_rectangles != old_geometry,
		"new physical epoch publishes current terrain even while the old packet is throttled")
	expect(initial.hard_surface_chunk_rectangles == old_geometry,
		"refresh preserves the previous immutable terrain publication")
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var session := Session.new()
	viewport.add_child(session)
	expect(session.configure([{"model": &"runner", "producer": &"demo", "position": Vector2(90, 90)}],
		viewport.world_2d.space, 32), "replacement terrain is tested with a real Rapier assembly")
	var fence := KeyboardHarness.new()
	fence.physical_actor_session = session
	fence._physical_epoch = 32
	fence.rapier_bridge = session.bridge
	fence.latest_snapshot = replacement
	fence.sync_hard_surface_colliders()
	fence._update_physical_terrain_ready()
	expect(not fence._physical_terrain_ready, "fresh owner terrain remains fenced until actual collider installation")
	fence.rapier_bridge.process_hard_surface_collider_budget(256, 0)
	fence._update_physical_terrain_ready()
	expect(fence._physical_terrain_ready and fence.rapier_bridge.hard_surface_shape_count() > 0,
		"the desktop admits the freshly published floor after its collider budget completes")
	session.close()
	fence.physical_actor_session = null
	fence.free()
	viewport.free()
	worker.queue_reset(Vector2(90, 90), false, false)
	var reset: CyberSimulationSnapshot = worker.publish_once()
	expect(reset.rigid_body_epoch == 32
		and reset.hard_surface_revision == int(worker._world.hard_surface_revision)
		and reset.hard_surface_chunk_rectangles == worker._world.get_hard_surface_chunk_rectangles()
		and reset.hard_surface_chunk_rectangles != replacement.hard_surface_chunk_rectangles,
		"ordinary World reset refreshes terrain immediately even without an epoch change")
	var first_map: CyberSimulationSnapshot
	for floor_y: int in [110, 150]:
		var definition: Dictionary = CyberMicroScenarioContract.base("terrain-cache-%d" % floor_y)
		definition.rectangles = [64, floor_y, 64, 4, 1]
		definition.body_enabled = true
		worker.queue_lab({"scenario_reset": definition, "scenario_request_serial": floor_y,
			"scenario_mode": "Inspect", "sampled_character_enabled": false})
		var loaded: CyberSimulationSnapshot = worker.publish_once()
		expect(loaded.lab_context.get("scenario_request_applied", false)
			and loaded.rigid_body_epoch == 32
			and loaded.hard_surface_revision == int(worker._world.hard_surface_revision)
			and loaded.hard_surface_chunk_rectangles == worker._world.get_hard_surface_chunk_rectangles(),
			"same-epoch map load publishes its own native floor at y=%d" % floor_y)
		if first_map == null:
			first_map = loaded
		else:
			expect(loaded.hard_surface_revision == first_map.hard_surface_revision
				and loaded.hard_surface_chunk_rectangles != first_map.hard_surface_chunk_rectangles,
				"equal revision numbers across candidate Worlds do not preserve obsolete geometry")
	# Restarting a stopped owner is another initial publication, including the
	# reference epoch zero. Equal revision numbers must not hide a new World.
	var reused := TerrainPublicationWorker.new()
	reused.set_frame_state(0, false, true, Vector2i(90, 90), Vector2i(50, 50),
		Vector2i(150, 150), 0, 0, true, true, true)
	expect(reused._world.diagnostic_reset({"workers": 1})
		and reused._world.diagnostic_fill_rect(Vector2i(64, 110), Vector2i(64, 4), 1),
		"reuse fixture starts with a native floor")
	var prior: CyberSimulationSnapshot = reused.publish_once()
	expect(reused._world.diagnostic_reset({"workers": 1})
		and reused._world.diagnostic_fill_rect(Vector2i(64, 150), Vector2i(64, 4), 1),
		"stopped owner replaces terrain without changing its body epoch")
	expect(reused.start_worker(Vector2(90, 90)) == OK, "stopped owner starts again")
	reused.stop_worker()
	var restarted: CyberSimulationSnapshot = reused.take_latest_snapshot(prior.serial)
	expect(restarted != null and restarted.rigid_body_epoch == 0
		and restarted.hard_surface_revision == prior.hard_surface_revision
		and restarted.hard_surface_chunk_rectangles != prior.hard_surface_chunk_rectangles
		and restarted.hard_surface_chunk_rectangles == reused._world.get_hard_surface_chunk_rectangles(),
		"worker startup refreshes equal-revision terrain under the unchanged reference epoch")
	print("Physical terrain publication: epoch replacement, reset, equal-revision map load and worker reuse exercised")


func native_effect_boundary() -> void:
	var worker := Worker.new()
	worker.set_frame_state(0, false, true, Vector2i(800, 20), Vector2i(750, 0),
		Vector2i(100, 100), 0, 0, true, true, true)
	expect(worker.start_worker(Vector2(800, 20)) == OK, "native effect owner starts")
	var receipt: int = worker.queue_actor_prototype_reset([], Vector2(800, 20), false)
	expect(receipt > 0 and await wait_for(func() -> bool:
		var snapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_prototype_reset_serial == receipt),
		"physical-only native reset acknowledged")
	var states := PackedFloat32Array()
	CyberRigidBodyCoupling.append_input(states, 1, Vector2(800, 20), 0.0, Vector2(8, 6),
		Vector2.ZERO, 0.0, 1.0, 1)
	worker.set_physical_actor_epoch(17)
	worker.set_frame_state(0, false, false, Vector2i(800, 20), Vector2i(750, 0),
		Vector2i(100, 100), 0, 0, true, true, true)
	var effect: Dictionary = {"actor_slot": 0, "epoch": 17, "sequence": 1,
		"kind": "deposit", "source": Vector2(800, 20), "origin": Vector2(809, 20),
		"source_body_id": 1, "source_part": 0, "radius": 1, "strength": 1.0, "material": 2}
	worker.set_rigid_body_states(states, 17, [effect])
	effect.origin = Vector2(10, 10) # Mutating producer storage cannot move admitted effect.
	expect(await wait_for(func() -> bool:
		var snapshot = worker.take_latest_snapshot(0)
		return snapshot != null and not snapshot.physical_actor_effects.is_empty()),
		"exclusive native owner consumes copied effect")
	var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	expect(snapshot.rigid_body_epoch == 17 and snapshot.actor_prototypes.is_empty(),
		"body publication carries physical generation without a sampled actor owner")
	if not snapshot.physical_actor_effects.is_empty():
		expect(snapshot.physical_actor_effects[0].changed_cells > 0,
			"real source-mask clearance allows Sand emission outside the held collider")
	worker.set_physical_actor_epoch(18)
	worker.set_rigid_body_states(states, 17, [effect])
	expect(worker._pending_physical_effects.is_empty(), "old-generation effects cannot enter replacement owner queue")
	worker.set_physical_actor_epoch(0)
	expect(worker._pending_physical_effects.is_empty(), "closing physical owner retires queued effects")
	worker.stop_worker()


func run() -> void:
	await keyboard_contract()
	terrain_publication_contract()
	await native_effect_boundary()
	desktop = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	var last_epoch: int = 0
	for rig_id: StringName in Catalog.RIG_IDS:
		expect(desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(rig_id)), &"demo", false),
			"F5 admits articulated " + str(rig_id))
		await installed()
		if desktop.physical_actor_session == null:
			expect(false, "physical rig installation failed")
			break
		var state: Dictionary = desktop.physical_actor_session.snapshot()
		expect(state.actor_count == 1 and state.body_count == Equipment.definition(Catalog.entry(rig_id)).parts.size(),
			"F5 installs every part for " + str(rig_id))
		expect(state.epoch > last_epoch and desktop.physical_rig_id == rig_id, "reset replaces incarnation and identity")
		last_epoch = state.epoch
		expect(desktop.latest_snapshot.actor_prototypes.is_empty() and desktop.player_uses_barrel(),
			"Rapier and sampled actor owners are exclusive")
		var panel = desktop.actor_prototype_panel
		panel.configure_selection(StringName("rapier/" + str(rig_id)), &"demo", true)
		expect(panel.model_choice.get_item_text(panel.model_choice.selected).begins_with("Articulated Rapier"),
			"picker maps the complete physical roster")
		expect(not panel.producer_choice.disabled and not panel.npc_choice.disabled,
			"every articulated entry exposes scripted and policy pilots")
	for model: StringName in [&"astra", &"jev", &"ripper"]:
		expect(desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(model)), &"demo", false),
			"live desktop demo starts " + str(model))
		# Deliberately request play before acknowledgement/collider completion.
		desktop.paused = false
		await installed()
		desktop.paused = false
		var start_position: Vector2 = desktop.physical_actor_session.observation(0).position
		expect(await wait_for(func() -> bool: return desktop.physical_actor_session.tick >= 120),
			"desktop demo advances 120 physical ticks after terrain admission: " + str(model))
		var live: Dictionary = desktop.physical_actor_session.snapshot()
		expect(desktop._physical_terrain_ready and live.actors[0].fault == ""
			and live.actors[0].position.distance_to(start_position) > 1.0,
			"live native-worker demo retains finite vigorous motion: " + str(model))
		desktop.paused = true
	expect(desktop.apply_actor_prototype_configuration(&"rapier/heavylift", &"demo", true), "new Set X companions admitted")
	await installed()
	expect(desktop.physical_actor_session.snapshot().actor_count == 8, "Set X visibly caps the shared owner at eight actors")
	expect(desktop.rigid_bodies.size() <= 64 and not desktop.rigid_bodies.has(desktop.test_rigid_body_1),
		"physical actor parts replace the three reference barrels")
	var epoch: int = desktop._physical_epoch
	desktop.reset_world()
	await installed()
	expect(desktop.physical_rig_id == &"heavylift" and desktop._physical_epoch > epoch, "R retains model and replaces assembly")
	expect(desktop.microscenario_launch(CyberShowcaseTiles.scenario_ids()[0], "Play"), "exploratory map opens")
	await installed()
	expect(desktop.apply_actor_prototype_configuration(&"rapier/lineshank", &"policy", false), "physical actor admitted in authored map")
	await installed()
	epoch = desktop._physical_epoch
	desktop.microscenario_reset()
	await installed()
	expect(desktop.physical_rig_id == &"lineshank" and desktop._physical_epoch > epoch, "map R retains articulated actor and fences old epoch")
	expect(desktop.microscenario_launch("fixtures/sand-release", "Inspect"), "registered fixture opens")
	await installed()
	expect(desktop.physical_actor_session == null and desktop.physical_rig_id == &"", "protected fixture retires physical session")
	expect(not desktop.apply_actor_prototype_configuration(&"rapier/runner", &"demo", false),
		"physical selection cannot rewrite a protected fixture")
	desktop.free()
	await process_frame
	print("Physical actor integration: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
