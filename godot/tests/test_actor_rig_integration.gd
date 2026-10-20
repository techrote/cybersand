extends SceneTree

const Worker = preload("res://scripts/simulation_worker.gd")
const Recorder = preload("res://scripts/gameplay_recorder.gd")
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const PhysicalCatalog = preload("res://scripts/physical_actor_catalog.gd")
const MicroCatalog = preload("res://scripts/microscenario_catalogue.gd")
const WaterProfiles = preload("res://scripts/water_experiment_profiles.gd")
const SPAWN := Vector2(800.0, 20.0)
const INPUT_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT,
	KEY_Q, KEY_E, KEY_Z, KEY_X, KEY_C, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]


class InputSink:
	extends CyberSimulationWorker
	var packets: Array[Dictionary] = []
	var legacy_packets: int = 0
	var cancellations: int = 0

	func submit_actor_action(_actor_id: int, _epoch: int, _sequence: int, _observed_tick: int,
		_movement: Vector2, _primary: bool, _secondary: bool, _lease_ticks: int = 12,
		_producer: StringName = &"policy") -> bool:
		legacy_packets += 1
		return true

	func submit_actor_rig_action(actor_id: int, epoch: int, sequence: int, observed_tick: int,
		movement: Vector2, aim: Vector2, effort: float, trim: float, reel: float,
		primary: bool, secondary: bool, auxiliary: bool, lease_ticks: int = 12,
		producer: StringName = &"policy") -> bool:
		packets.append({"id": actor_id, "epoch": epoch, "sequence": sequence,
			"tick": observed_tick, "move": movement, "aim": aim, "effort": effort,
			"trim": trim, "reel": reel, "primary": primary, "secondary": secondary,
			"auxiliary": auxiliary, "lease": lease_ticks, "producer": producer})
		return true

	func cancel_actor_input(_actor_id: int, _epoch: int, _producer: StringName) -> bool:
		cancellations += 1
		return true

	func has_failed() -> bool:
		return false


class KeyboardHarness:
	extends "res://scripts/main.gd"
	var input_allowed: bool = true

	func _ready() -> void:
		# Keep a real Viewport for event consumption without starting another
		# simulation owner or pretending headless OS focus is interactive evidence.
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_key_input(false)

	func actor_keyboard_allowed() -> bool:
		return input_allowed

	func actor_pointer_aim() -> Vector2:
		return Vector2(-0.6, 0.8)


var assertions: int = 0
var failures: int = 0
var native_samples: Array[CyberSimulationSnapshot] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error("ACTOR_RIG_INTEGRATION: " + message)


func _wait_for(predicate: Callable, timeout_ms: int = 15000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call():
			return true
	return false


func _frame(worker: CyberSimulationWorker, paused: bool, legacy_input: float = 0.0,
	legacy_jetpack: bool = false) -> void:
	worker.set_frame_state(legacy_input, legacy_jetpack, paused, Vector2i(800, 40),
		Vector2i(720, 0), Vector2i(160, 100), 0, 0, true, true, true)


func _definition(model: StringName, producer: StringName = &"policy") -> Array:
	return [{"model": model, "producer": producer, "position": SPAWN}]


func _wait_receipt(worker: CyberSimulationWorker, receipt: int) -> bool:
	return await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.actor_prototype_reset_serial >= receipt
	)


func _native_worker_actions_and_effects() -> void:
	var worker := Worker.new()
	_frame(worker, true)
	_expect(worker.start_worker(SPAWN) == OK, "native owner thread did not start")
	var definitions: Array = _definition(&"gemini")
	definitions.append({"model": &"clamberer", "producer": &"policy", "position": SPAWN + Vector2(30.0, 0.0)})
	var receipt: int = worker.queue_actor_prototype_reset(definitions, SPAWN)
	_expect(receipt > 0 and await _wait_receipt(worker, receipt), "worker did not acknowledge extended rig reset")
	var initial: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	if initial == null or initial.actor_prototypes.is_empty():
		_expect(false, "native rig reset left no extended publication")
		worker.stop_worker()
		return
	var retained: Dictionary = initial.actor_prototypes.duplicate(true)
	native_samples.append(initial)
	_expect(initial.actor_prototype_reset_applied and int(retained.count) == 2 \
		and retained.rig_states.size() == 80 and retained.applied_actions.size() == 20,
		"native reset receipt/schema does not describe both installed rigs")
	_expect(initial.player_representation == "actor-prototype/gemini", "native worker published the wrong player rig identity")
	_frame(worker, false, 1.0, true)
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and int(snapshot.actor_prototypes.get("tick", 0)) >= 5
	), "native rigs did not advance through fixed owner ticks")
	var neutral: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	_expect(is_equal_approx(neutral.character_position.x, SPAWN.x) and neutral.character_position.y > SPAWN.y,
		"legacy sampled input also drove or lifted the installed Gemini rig")
	var context: Dictionary = neutral.actor_prototypes
	_expect(not worker.submit_actor_rig_action(0, int(context.epoch), 1, int(context.tick),
		Vector2.RIGHT, Vector2.LEFT, 0.9, 0.35, -0.4, true, true, true, 18, &"human"),
		"live owner accepted the wrong extended producer")
	_expect(worker.submit_actor_rig_action(0, int(context.epoch), 1, int(context.tick),
		Vector2.RIGHT, Vector2.LEFT, 0.9, 0.35, -0.4, true, true, true, 18, &"policy"),
		"live owner refused a valid extended policy action")
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and int(snapshot.actor_prototypes.applied_sequences[0]) == 1 \
			and snapshot.character_position.x < SPAWN.x - 1.0
	), "independent aimed policy burst did not reach the native rig owner")
	var moved: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
	native_samples.append(moved)
	_expect(moved.actor_prototypes == moved.lab_context.actor_prototypes,
		"worker current context and actor publication disagree")
	_expect(moved.tick_index == int(moved.actor_prototypes.tick), "native World and rig session ticks diverged")
	_expect(absf(float(moved.actor_prototypes.rig_states[16])) > 0.0001,
		"native extended trim and paired thrusters never rotated the actual hull")
	_expect(float(moved.actor_prototypes.applied_actions[0]) == 1.0 \
		and float(moved.actor_prototypes.applied_actions[2]) == -1.0 \
		and is_equal_approx(float(moved.actor_prototypes.applied_actions[5]), 0.35),
		"worker conflated move/aim/trim in consumed action readback")
	_expect(initial.actor_prototypes == retained, "later native owner ticks mutated an earlier rig publication")
	_expect(int(moved.actor_prototypes.query_count_last) <= 2 * 96,
		"native two-rig owner exceeded aggregate occupancy budget")
	_frame(worker, true)
	_expect(await _wait_for(func() -> bool:
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		return snapshot != null and snapshot.paused and snapshot.actor_prototypes.suspended
	), "native pause did not suspend extended action ownership")
	_expect(not worker.submit_actor_rig_action(0, int(context.epoch), 2, int(context.tick),
		Vector2.RIGHT, Vector2.UP, 1.0, 1.0, 1.0, true, true, true, 18, &"policy"),
		"late pre-pause v2 inference reached a suspended owner")

	# Fixture authoring goes through the existing owner brush queue. The policy
	# still receives only movement/aim/effort: no radius/material/World handles.
	for model: StringName in [&"rocketjumper", &"digger"]:
		receipt = worker.queue_actor_prototype_reset(_definition(model), SPAWN)
		_expect(receipt > 0 and await _wait_receipt(worker, receipt), "native effect rig reset did not acknowledge")
		var before_fixture: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		var fixture_revision: int = before_fixture.world_revision
		if model == &"rocketjumper":
			_expect(worker.queue_emit_disc(814, 26, 1, CyberCellWorld.WALL), "native rocket surface fixture was refused")
		else:
			_expect(worker.queue_emit_disc(803, 31, 4, CyberCellWorld.SAND), "native drill material fixture was refused")
		_expect(await _wait_for(func() -> bool:
			var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			return snapshot != null and snapshot.world_revision > fixture_revision
		), "paused owner did not install the bounded effect fixture")
		_frame(worker, false)
		_expect(await _wait_for(func() -> bool:
			var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			return snapshot != null and not snapshot.paused and int(snapshot.actor_prototypes.tick) >= 1
		), "effect fixture did not resume with a fresh epoch")
		var ready: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		context = ready.actor_prototypes
		var aim: Vector2 = Vector2.RIGHT if model == &"rocketjumper" else Vector2.DOWN
		_expect(worker.submit_actor_rig_action(0, int(context.epoch), 1, int(context.tick),
			Vector2.ZERO, aim, 1.0, 0.0, 0.0, true, false, false, 18, &"policy"),
			"native tool action was refused")
		var effect_seen: bool = await _wait_for(func() -> bool:
			var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			if snapshot == null or snapshot.actor_prototypes.is_empty():
				return false
			var state: PackedFloat32Array = snapshot.actor_prototypes.rig_states
			return int(snapshot.actor_prototypes.applied_sequences[0]) == 1 \
				and int(state[31]) == (2 if model == &"rocketjumper" else 1) \
				and (model == &"rocketjumper" or int(state[30]) > 0)
		)
		_expect(effect_seen, "native owner never published its actual " + str(model) + " effect")
		if effect_seen:
			var effect_snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			var state: PackedFloat32Array = effect_snapshot.actor_prototypes.rig_states
			_expect(int(state[29]) <= 64 and int(state[38]) <= 64 and int(state[30]) <= 64,
				"native owner effect exceeded ray/read/write bounds")
			if model == &"rocketjumper":
				_expect(effect_snapshot.character_velocity.x < 0.0 and int(state[30]) == 0,
					"protected rocket contact failed recoil or excavated Wall")
		_frame(worker, true)
		_expect(await _wait_for(func() -> bool:
			var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
			return snapshot != null and snapshot.paused and snapshot.actor_prototypes.suspended
		), "owner effect fixture did not suspend")
	worker.stop_worker()
	# Mutable owner inspection is confined to the period after its Thread joins.
	_expect(worker._character is CyberActorRigMotor and worker._character == worker._actor_session.player(),
		"extended rig left a duplicate or legacy sampled player owner")


func _controlled_owner_exclusions() -> void:
	var water: Dictionary = WaterProfiles.resolve({}, {}, {"scenario_id": "shallow-pool",
		"mass_bits": 5, "coherence_ticks": 7, "interface_mode": "oriented", "seed": 441})
	var commands: Array[Dictionary] = [{"reset": true}, {"water_reset": true, "water_policy": water.policy},
		{"scenario_reset": MicroCatalog.sand_release(), "scenario_mode": "Inspect"}]
	for command: Dictionary in commands:
		var worker := Worker.new()
		_frame(worker, true)
		var receipt: int = worker.queue_actor_prototype_reset(_definition(&"digger"), SPAWN)
		_expect(receipt > 0, "stale rig admission fixture could not queue its reset")
		_expect(worker._apply_lab(command), "controlled apparatus fixture failed before owner startup")
		_expect(worker.start_worker(SPAWN) == OK, "controlled owner thread did not start")
		_expect(await _wait_receipt(worker, receipt), "controlled owner did not dispose of stale rig reset receipt")
		var snapshot: CyberSimulationSnapshot = worker.take_latest_snapshot(0)
		_expect(snapshot != null and not snapshot.actor_prototype_reset_applied \
			and snapshot.actor_prototypes.is_empty() and snapshot.lab_context.get("active", false),
			"stale rig reset replaced Tower/Water/MicroScenario ownership")
		_expect(worker.queue_actor_prototype_reset(_definition(&"rocketjumper"), SPAWN) == 0,
			"direct new-rig reset bypassed controlled apparatus exclusion")
		_expect(not worker.submit_actor_rig_action(0, 1, 99, 0, Vector2.RIGHT, Vector2.DOWN,
			1.0, 1.0, 1.0, true, true, true), "controlled apparatus admitted an orphan extended effect action")
		worker.stop_worker()
		_expect(not worker._actor_session.active() and not worker._character is CyberActorRigMotor,
			"controlled reset retained a hidden rig owner")


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return event


func _keyboard_controls_and_rearm() -> void:
	for keycode: Key in INPUT_KEYS:
		_key(keycode, false)
	var desktop := KeyboardHarness.new()
	var sink := InputSink.new()
	desktop.simulation_worker = sink
	desktop.latest_snapshot = CyberSimulationSnapshot.new()
	desktop.latest_snapshot.actor_prototypes = {"epoch": 1, "tick": 0, "rig_version": 2,
		"models": [&"gemini"], "producers": [&"human"], "suspended": false}
	# Base-script @onready fields still initialize even when this harness
	# overrides _ready. Supply their real node types before entering the tree.
	var layout := Control.new()
	layout.name = "Layout"
	desktop.add_child(layout)
	var view := TextureRect.new()
	view.name = "World"
	view.material = ShaderMaterial.new()
	layout.add_child(view)
	var label := Label.new()
	label.name = "Status"
	layout.add_child(label)
	var bodies := Node2D.new()
	bodies.name = "RigidBodies"
	desktop.add_child(bodies)
	for index: int in range(1, 4):
		var body := RigidBody2D.new()
		body.name = "TestBody%d" % index
		body.freeze = true
		bodies.add_child(body)
	root.add_child(desktop)
	desktop.publish_actor_keyboard_input()
	_expect(not desktop._actor_input_rearm and sink.packets.size() == 1 and sink.legacy_packets == 0,
		"released extended controls did not arm only the v2 path")
	var paint_before: int = desktop.selected_material_id
	var coherence_before: bool = desktop.coherent_liquid_emission
	desktop._unhandled_key_input(_key(KEY_D, true))
	desktop._unhandled_key_input(_key(KEY_E, true))
	desktop._unhandled_key_input(_key(KEY_X, true))
	desktop._unhandled_key_input(_key(KEY_C, true))
	desktop._unhandled_key_input(_key(KEY_C, false))
	_expect(sink.packets.size() == 6 and sink.packets[4].auxiliary and not sink.packets[5].auxiliary,
		"desktop C press-release was lost between physics samples")
	var packet: Dictionary = sink.packets.back()
	_expect(packet.move == Vector2.RIGHT and packet.aim == Vector2(-0.6, 0.8) \
		and packet.trim == 1.0 and packet.reel == 1.0,
		"keyboard movement, pointer aim, trim and reel were conflated")
	_expect(packet.producer == &"human" and int(packet.lease) == 6,
		"extended keyboard adapter changed producer identity or lease")
	_expect(desktop.selected_material_id == paint_before and desktop.coherent_liquid_emission == coherence_before,
		"active rig Q/E/C leaked into global material/coherence shortcuts")
	for keycode: Key in [KEY_D, KEY_E, KEY_X]:
		desktop._unhandled_key_input(_key(keycode, false))
	for keycode: Key in [KEY_BRACKETRIGHT, KEY_BRACKETLEFT]:
		for press: int in range(30):
			desktop._unhandled_key_input(_key(keycode, true))
			desktop._unhandled_key_input(_key(keycode, false))
		_expect(desktop._actor_effort == (1.0 if keycode == KEY_BRACKETRIGHT else 0.0),
			"keyboard effort adjustment escaped its bounds or failed to reach an endpoint")
	for pair: Array in [[KEY_Q, KEY_E], [KEY_Z, KEY_X], [KEY_A, KEY_D]]:
		desktop.input_allowed = false
		desktop.publish_actor_keyboard_input()
		var count: int = sink.packets.size()
		desktop.input_allowed = true
		_key(pair[0], true)
		_key(pair[1], true)
		desktop.publish_actor_keyboard_input()
		_expect(desktop._actor_input_rearm and sink.packets.size() == count,
			"opposing held parametric keys bypassed release-to-rearm")
		_key(pair[0], false)
		desktop.publish_actor_keyboard_input()
		_expect(desktop._actor_input_rearm and sink.packets.size() == count,
			"one remaining parametric key bypassed rearm")
		_key(pair[1], false)
		desktop.publish_actor_keyboard_input()
		_expect(not desktop._actor_input_rearm and sink.packets.size() == count + 1,
			"fully released extended controls failed to rearm")
	var count: int = sink.packets.size()
	_key(KEY_C, true)
	desktop.latest_snapshot.actor_prototypes.epoch = 2
	desktop.publish_actor_keyboard_input()
	_expect(desktop._actor_input_rearm and sink.packets.size() == count,
		"new epoch replayed a held auxiliary action")
	_key(KEY_C, false)
	desktop.publish_actor_keyboard_input()
	_expect(sink.packets.back().sequence == 1 and sink.packets.back().epoch == 2,
		"new extended keyboard lifetime did not restart its sequence")
	desktop.latest_snapshot.actor_prototypes.producers = [&"policy"]
	count = sink.packets.size()
	desktop._unhandled_key_input(_key(KEY_SPACE, true))
	_expect(sink.packets.size() == count, "keyboard also actuated an external-policy rig")
	for keycode: Key in INPUT_KEYS:
		_key(keycode, false)
	desktop.free()


func _wait_model(desktop: Control, model: StringName, count: int) -> bool:
	return await _wait_for(func() -> bool:
		if desktop.latest_snapshot == null or desktop._actor_reset_receipt != 0:
			return false
		var context: Dictionary = desktop.latest_snapshot.actor_prototypes
		return context.is_empty() if count == 0 else int(context.get("count", 0)) == count and context.models[0] == model
	)


func _selector_and_geometry() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var desktop: Control = scene.instantiate()
	root.add_child(desktop)
	await process_frame
	desktop.paused = true
	var panel: CyberActorPrototypePanel = desktop.actor_prototype_panel
	_expect(panel.set_choice.item_count == PhysicalCatalog.SET_IDS.size() and panel.model_choice.item_count == 9
		and panel._visible_models.slice(0, 4) == [&"", &"runner", &"skimmer", &"crawler"],
		"rig selector lost catalogue sets, original Set A indices, reference trials or articulated choices")
	for model: StringName in PhysicalCatalog.rigs_in_set(&"setP"):
		var choice := StringName("rapier/" + str(model))
		panel.configure_selection(choice, &"human", false)
		_expect(panel.selected_set_id() == &"setP" and panel._visible_models[panel.model_choice.selected] == choice,
			"selector cannot address player preset " + str(model))
		_expect(panel.description.text.contains(PhysicalCatalog.name_for(model).to_upper()) and panel.effort_slider.editable,
			"player preset lost its description or human effort control")
	for set_id: StringName in Catalog.SET_IDS:
		var group: Array[StringName] = Catalog.rigs_in_set(set_id)
		for model: StringName in group:
			panel.configure_selection(model, &"policy", true)
			_expect(panel.selected_set_id() == set_id \
				and panel._visible_models[panel.model_choice.selected] == model,
				"selector cannot address registered rig " + str(model))
			_expect(panel.description.text.contains(Catalog.name_for(model).to_upper()),
				"selector retained a different rig's description")
			_expect(not panel.effort_slider.editable, "policy selection exposed an unapplied keyboard-only power control")
		panel._apply()
		_expect(await _wait_model(desktop, group.back(), group.size()), "set comparison did not install every other selected-set rig")
		var context: Dictionary = desktop.latest_snapshot.actor_prototypes
		if context.is_empty():
			continue
		_expect(context.models.size() <= 8 and context.models[0] == group.back() \
			and context.producers[0] == &"policy", "set comparison changed player identity or exceeded actor capacity")
		for model: StringName in group:
			_expect(context.models.has(model), "set comparison omitted a registered peer")
		for index: int in range(group.size()):
			_expect(context.rig_sets[index] == set_id \
				and (index == 0 or context.producers[index] == &"demo"),
				"comparison mixed sets or assigned an NPC the player's producer")
		_expect(not desktop.toggle_sampled_runtime_recovery(), "rig selection enabled legacy runtime relocation")
	panel.configure_selection(&"gemini", &"human", false)
	panel.effort_slider.value = 0.85
	panel._apply()
	_expect(await _wait_model(desktop, &"gemini", 1), "human rig selection did not acknowledge")
	_expect(is_equal_approx(desktop._actor_effort, 0.85), "human rig apply lost its selected parametric effort")

	# Exact presentation geometry is checked without asserting visual appeal or
	# OS focus. These copies are test-owned, never mutations of live snapshots.
	var visual_context: Dictionary = desktop.latest_snapshot.actor_prototypes.duplicate(true)
	visual_context.rig_states[0] = 40.0
	visual_context.rig_states[1] = 30.0
	visual_context.rig_states[16] = 0.4
	visual_context.rig_states[20] = 3.0
	visual_context.rig_states[21] = 100.5
	visual_context.rig_states[22] = 20.5
	visual_context.rig_states[35] = 12.0
	visual_context.rig_states[36] = 8.0
	visual_context.states = visual_context.rig_states.slice(0, 16)
	desktop.world_view.size = Vector2(800, 800)
	desktop.current_view_size = Vector2i(320, 180)
	var content: Rect2 = desktop.view_content_rect()
	var origin := Vector2(12.75, 7.25)
	var overlay: CyberActorPrototypeOverlay = desktop.actor_prototype_overlay
	overlay.present(visual_context, origin, desktop.current_view_size, content)
	_expect(content == Rect2(0, 175, 800, 450) and overlay.position == content.position \
		and overlay.size == content.size and overlay._origin == origin.floor(),
		"extended overlay diverges from the terrain's integer aspect-fit transform")
	var polygon: PackedVector2Array = overlay.body_polygon(0)
	var center := Vector2(46.0, 34.0)
	var half := Vector2(6.0, 4.0)
	var corners: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		half, Vector2(-half.x, half.y)]
	_expect(polygon.size() == 4, "rotated overlay hull is not a four-corner rectangle")
	for index: int in range(4):
		var expected: Vector2 = (center + corners[index].rotated(0.4) - origin.floor()) \
			* content.size / Vector2(320, 180)
		_expect(polygon[index].distance_to(expected) < 0.0001, "overlay drew legacy dimensions or an unrotated rig hull")
	var line: PackedVector2Array = overlay.anchor_line(0)
	_expect(line.size() == 2 and line[0].is_equal_approx(overlay.world_to_overlay(center)) \
		and line[1].is_equal_approx(overlay.world_to_overlay(Vector2(100.5, 20.5))),
		"rope/anchor overlay used a different projection or stale attachment")
	var saved_snapshot: CyberSimulationSnapshot = desktop.latest_snapshot
	var saved_position: Vector2 = desktop.character_position
	var saved_origin: Vector2 = desktop.camera_origin
	desktop.latest_snapshot = CyberSimulationSnapshot.new()
	desktop.latest_snapshot.actor_prototypes = visual_context.duplicate(true)
	desktop.character_position = Vector2(40.0, 30.0)
	desktop.camera_origin = origin
	var local_pointer: Vector2 = content.position + Vector2(600.0, 200.0)
	var world_pointer: Vector2 = origin.floor() + Vector2(600.0, 200.0) / content.size * Vector2(320, 180)
	# The real projection accepts explicit local coordinates so headless Window
	# stretch/OS pointer state is not mistaken for interactive acceptance.
	_expect(desktop.actor_pointer_aim_at(local_pointer).distance_to((world_pointer - center).normalized()) < 0.0001,
		"actual pointer projection disagrees with floored terrain camera, letterbox or rig centre")
	_expect(desktop.actor_pointer_aim_at(Vector2(200.0, 80.0)) == Vector2.ZERO,
		"pointer in the letterbox invented a world aim target")
	desktop.latest_snapshot = saved_snapshot
	desktop.character_position = saved_position
	desktop.camera_origin = saved_origin
	var visual_before: Dictionary = visual_context.duplicate(true)
	var retained_polygon: PackedVector2Array = polygon.duplicate()
	overlay.present(desktop.latest_snapshot.actor_prototypes, Vector2.ZERO, Vector2i(320, 180), content)
	_expect(visual_context == visual_before and polygon == retained_polygon,
		"overlay mutation reached source context or a retained geometry result")

	panel.configure_selection(&"", &"human", false)
	panel._apply()
	_expect(await _wait_model(desktop, &"", 0), "baseline selection did not clear extended session")
	_expect(desktop.apply_actor_prototype_configuration(&"digger", &"policy", false), "rig reinstall before MicroScenario was refused")
	_expect(await _wait_model(desktop, &"digger", 1), "rig reinstall before MicroScenario did not acknowledge")
	_expect(desktop.microscenario_launch("fixtures/sand-release"), "controlled MicroScenario transition was refused")
	_expect(await _wait_for(func() -> bool:
		return desktop.pending_microscenario_apply.is_empty() and desktop.tower_context.get("micro_active", false)
	), "MicroScenario transition did not acknowledge")
	_expect(desktop.latest_snapshot.actor_prototypes.is_empty() and desktop.actor_model_selection == &"" \
		and not desktop.actor_prototypes_allowed() and desktop._actor_input_rearm,
		"MicroScenario transition retained rig ownership, selection or armed controls")
	desktop.queue_free()
	await process_frame


func _recorded_snapshot(actor: CyberSimulationSnapshot, material_actor: CyberSimulationSnapshot,
	serial: int, published_usec: int) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.serial = serial
	snapshot.published_usec = published_usec
	snapshot.tick_index = actor.tick_index
	snapshot.character_position = actor.character_position
	snapshot.character_velocity = actor.character_velocity
	snapshot.character_grounded = actor.character_grounded
	snapshot.character_runtime_recovery_enabled = false
	snapshot.player_representation = actor.player_representation
	snapshot.actor_prototypes = actor.actor_prototypes.duplicate(true)
	snapshot.lab_context = actor.lab_context.duplicate(true)
	snapshot.render_context = material_actor.lab_context.duplicate(true)
	snapshot.render_snapshot_serial = 1
	snapshot.render_tick_index = material_actor.tick_index
	snapshot.render_generated_usec = published_usec - serial * 20000
	snapshot.render_channels = 2
	snapshot.render_full_refresh = true
	snapshot.render_patch_rectangles = PackedInt32Array([10, 20, 2, 2, 0, 4])
	snapshot.render_patch_cells = PackedByteArray([1, 0, 2, 0, 3, 0, 4, 0])
	return snapshot


func _recording_extended_context() -> void:
	_expect(native_samples.size() == 2, "native extended samples unavailable for recording")
	if native_samples.size() != 2:
		return
	var recorder := Recorder.new()
	_expect(recorder.start_recording({"roi": Rect2i(10, 20, 2, 2), "capture_hz": 60,
		"queue_capacity": 4}, {"source": "actor-rig-integration"}, false) == OK,
		"extended actor recorder failed to start")
	var base_usec: int = Time.get_ticks_usec() + 100
	var first := _recorded_snapshot(native_samples[0], native_samples[0], 1, base_usec)
	var second := _recorded_snapshot(native_samples[1], native_samples[0], 2, base_usec + 20000)
	recorder.ingest_snapshot(first)
	recorder.ingest_snapshot(second)
	_expect(recorder._queue.size() == 2, "rig-only publication with retained material did not record")
	if recorder._queue.size() == 2:
		var metadata: Dictionary = recorder._queue[1].metadata
		_expect(metadata.actor_sample.actor_prototypes == second.actor_prototypes \
			and metadata.material_generation.actor_prototypes == first.actor_prototypes,
			"recorder conflated current rig/action state with retained material-generation context")
		_expect(int(metadata.actor_sample.completed_simulation_tick) == second.tick_index \
			and int(metadata.material_generation.completed_simulation_tick) == first.tick_index,
			"extended metadata lost the two distinct owner times")
		_expect(float(metadata.player.extent[0]) == float(second.actor_prototypes.rig_states[35]) \
			and float(metadata.player.extent[1]) == float(second.actor_prototypes.rig_states[36]) \
			and float(metadata.player.rotation_radians) == float(second.actor_prototypes.rig_states[16]),
			"recorder retained legacy body dimensions or lost exact rig angle")
		_expect(metadata.player.rig_id == "gemini" and metadata.player.rig_set == "setV" \
			and not metadata.player.environment_profile_applied, "recorded player capability identity is wrong")
		var decoded: Variant = JSON.parse_string(JSON.stringify(metadata))
		_expect(decoded is Dictionary, "extended recorder metadata did not round-trip through JSON")
		if decoded is Dictionary:
			for context: Dictionary in [decoded.player.actor_prototype, decoded.actor_sample.actor_prototypes,
				decoded.material_generation.actor_prototypes]:
				_expect(context.states is Array and context.states.size() == 32 \
					and context.rig_states is Array and context.rig_states.size() == 80 \
					and context.applied_actions is Array and context.applied_actions.size() == 20,
					"recorded v1/v2/action packed fields are not usable fixed-stride JSON arrays")
				for field: String in ["states", "rig_states", "applied_actions", "applied_sequences", "applied_flags"]:
					for value: Variant in context[field]:
						_expect((value is int or value is float) and is_finite(float(value)),
							"recorded extended state contains a nonnumeric/nonfinite feature")
				_expect(context.rig_capabilities[0].body_size is Array \
					and context.rig_capabilities[0].color is Array \
					and context.rig_capabilities[0].motor.body_size is Array,
					"recorded capability descriptors leaked engine-only vector/color strings")
		second.actor_prototypes.rig_states[16] = -999.0
		second.actor_prototypes.applied_actions[4] = -999.0
		_expect(float(metadata.actor_sample.actor_prototypes.rig_states[16]) != -999.0 \
			and float(metadata.actor_sample.actor_prototypes.applied_actions[4]) != -999.0,
			"recorder metadata retained mutable rig/action source storage")
	recorder.stop_recording()


func _run() -> void:
	_keyboard_controls_and_rearm()
	await _native_worker_actions_and_effects()
	await _controlled_owner_exclusions()
	_recording_extended_context()
	await _selector_and_geometry()
	print("ACTOR_RIG_INTEGRATION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
