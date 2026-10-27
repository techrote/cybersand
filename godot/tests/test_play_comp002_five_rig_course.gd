extends SceneTree

# PLAY-COMP-002 / #267: five real SetP rigs in the single existing asynchronous
# desktop host, on the original course geometry and source-matched rig origins.
# A test-only focus seam preserves real physics, controller and native ownership.
const Course = preload("res://scripts/player_playground_course.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")

var desktop: Control
var assertions: int = 0
var failures: int = 0
var expected_model: StringName = &""
var start_physics_tick: int = 0


class DesktopHarness:
	extends "res://scripts/main.gd"
	# Same headless-only focus seam as PLAY-COMP-001; no synthetic actor.
	func actor_keyboard_allowed() -> bool:
		return (not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, reason: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PLAY_COMP002: " + reason)


func wait_for(predicate: Callable, timeout_ms: int = 30000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false


func course_installed() -> bool:
	return (desktop.pending_microscenario_apply.is_empty()
		and desktop.tower_context.get("micro_active", false)
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID)


func actor_installed() -> bool:
	return (course_installed() and desktop._actor_reset_receipt == 0
		and desktop.physical_actor_session != null
		and desktop.physical_rig_id == expected_model
		and desktop._physical_terrain_ready)


func input_rearmed() -> bool:
	return (desktop.physical_actor_session != null
		and desktop.physical_actor_session.tick > start_physics_tick
		and not desktop._actor_input_rearm)


func physics_advanced() -> bool:
	return (desktop.physical_actor_session != null
		and desktop.physical_actor_session.tick >= start_physics_tick + 30)


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func finish() -> void:
	key(KEY_D, false)
	key(KEY_W, false)
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	print("PLAY_COMP002_RESULT ", JSON.stringify({
		"assertions":assertions, "failures":failures,
		"mechanical_presets":Course.MECHANICAL_PRESETS.size(),
		"route":"existing-CyberSimulationWorker+main-Rapier",
		"swarm_qualified":false, "gamepad_qualified":false,
		"frame_pacing_measured":false, "parallel_speedup_proven":false
	}))
	quit(0 if failures == 0 else 1)


func run() -> void:
	var definition: Dictionary = Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0)
	var checked: Dictionary = Contract.validate(definition)
	expect(bool(checked.get("ok", false)), "authored course validates")
	expect(Catalogue.PLAYER_COURSE_ID in Catalogue.ids(),
		"existing MicroScenario picker exposes the authored player course")
	expect(Course.MECHANICAL_PRESETS.size() == 5,
		"exactly five SetP mechanical presets, not either material swarm")
	expect(Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 1).is_empty(),
		"unspecified procedural seed is refused without replacing the authored course")
	if not checked.get("ok", false):
		await finish()
		return

	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	expect(desktop.worker_start_error == OK
		and desktop.simulation_worker._thread.is_started(),
		"original asynchronous worker thread was started")

	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"real existing desktop admits original course")
	if not await wait_for(Callable(self, "course_installed")):
		expect(false, "course installation was not acknowledged")
		await finish()
		return
	expect(desktop.microscenario_definition.rectangles == checked.definition.rectangles,
		"exact authored course geometry is retained by the existing owner")

	for model_id: StringName in Course.MECHANICAL_PRESETS:
		expected_model = model_id
		var prepared: Dictionary = Equipment.definition(Catalog.entry(model_id))
		expect(not prepared.is_empty(), "actual SetP equipment/rig definition exists: " + str(model_id))
		if prepared.is_empty():
			continue
		var intended: Vector2 = Course.mechanical_origin(model_id,
			float(prepared.spawn_floor_clearance))
		expect(intended.is_finite(), "original authoring has a bounded mechanical spawn: " + str(model_id))
		var generated: Array = desktop.physical_actor_definitions(model_id, &"human", false,
			Vector2(178, 304), Catalogue.PLAYER_COURSE_ID)
		expect(generated.size() == 1 and generated[0].position.distance_to(intended) < 0.01,
			"normal actor-session constructor preserves original course spawn: " + str(model_id))

		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(model_id)), &"human", false),
			"existing F5 path admits physical course preset: " + str(model_id))
		var accepted: bool = await wait_for(Callable(self, "actor_installed"))
		expect(accepted, "actor/terrain receipt acknowledged by existing worker: " + str(model_id))
		if not accepted:
			await finish()
			return
		var session = desktop.physical_actor_session
		var first: Dictionary = session.observation(0)
		expect(str(first.get("model", "")) == str(model_id)
			and str(first.get("producer", "")) == "human"
			and session.bodies().size() > 0,
			"actual Rapier SetP session owns selected human actor: " + str(model_id))
		expect(desktop.microscenario_definition.rectangles == checked.definition.rectangles,
			"changing player has not replaced/edited the authored map: " + str(model_id))
		var body = session.bodies()[0]
		var body_expected: Vector2 = intended + Vector2(prepared.parts[0].offset)
		expect(body.global_position.distance_to(body_expected) < 2.0,
			"real first Rapier body starts at authored clearance: " + str(model_id))

		start_physics_tick = session.tick
		desktop.paused = false
		var rearmed: bool = await wait_for(Callable(self, "input_rearmed"))
		expect(rearmed, "neutral frame clears production reset/rearm fence: " + str(model_id))
		if not rearmed:
			await finish()
			return
		var initial: Vector2 = session.observation(0).get("position", Vector2.INF)
		start_physics_tick = session.tick
		var input_key: Key = KEY_D if model_id == &"acrobat" else KEY_W
		key(input_key, true)
		var advanced: bool = await wait_for(Callable(self, "physics_advanced"))
		var after: Dictionary = session.observation(0)
		key(input_key, false)
		expect(advanced, "real Rapier physics advances with native World live: " + str(model_id))
		if advanced:
			var action: Dictionary = after.get("action", {})
			var move: Vector2 = action.get("move", Vector2.ZERO)
			expect((move.x > 0.5 if input_key == KEY_D else move.y < -0.5),
				"key command reaches actual SetP movement controller: " + str(model_id))
			var final_position: Vector2 = after.get("position", Vector2.INF)
			expect(final_position.is_finite() and initial.distance_to(final_position) > 0.25,
				"physical actor changes pose while commanded: " + str(model_id))
			print("PLAY_COMP002_RIG ", JSON.stringify({
				"rig":str(model_id), "initial_position":initial,
				"final_position":final_position, "authored_spawn":intended,
				"physics_tick":session.tick,
				"native_tick":desktop.latest_snapshot.tick_index if desktop.latest_snapshot != null else -1,
				"resolved_native_workers":desktop.latest_snapshot.scheduler_thread_capacity_hint if desktop.latest_snapshot != null else -1,
				"terrain_ready":desktop._physical_terrain_ready
			}))
		expect(desktop.latest_snapshot != null and desktop.latest_snapshot.tick_index > 0,
			"native cellular World publishes independently of main-thread Rapier: " + str(model_id))
		desktop.paused = true
		await process_frame

	# Reset must preserve the most recently selected rig and map identity.
	desktop.microscenario_reset()
	var reset_ok: bool = await wait_for(Callable(self, "actor_installed"))
	expect(reset_ok and desktop.microscenario_definition.rectangles == checked.definition.rectangles,
		"existing owner resets while retaining course and selected rig")
	await finish()
