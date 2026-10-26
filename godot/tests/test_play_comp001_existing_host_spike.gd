extends SceneTree

# PLAY-COMP-001 / #273: real native/Rapier proof of the existing asynchronous
# desktop host. No dedicated player World owner or synthetic physics shim.
const Course = preload("res://scripts/player_playground_course.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")

var desktop: Control
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, reason: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PLAY_COMP001: " + reason)


func wait_for(predicate: Callable, timeout_ms: int = 30000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false


# Explicit predicates avoid ambiguous multiline lambda call parsing.
func course_installed() -> bool:
	return (desktop.pending_microscenario_apply.is_empty()
		and bool(desktop.tower_context.get("micro_active", false)))


func actor_installed() -> bool:
	return (desktop.pending_microscenario_apply.is_empty()
		and desktop._actor_reset_receipt == 0
		and desktop.physical_actor_session != null)


func terrain_installed() -> bool:
	return desktop._physical_terrain_ready


var _initial_physics_tick: int = 0


func player_stepped() -> bool:
	return (desktop.physical_actor_session != null
		and desktop.physical_actor_session.tick >= _initial_physics_tick + 35)


func reset_acknowledged() -> bool:
	return (desktop.pending_microscenario_apply.is_empty()
		and desktop._actor_reset_receipt == 0
		and desktop.physical_rig_id == &"acrobat")


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func finish() -> void:
	key(KEY_D, false)
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	print("PLAY_COMP001_RESULT ", JSON.stringify({
		"assertions":assertions, "failures":failures,
		"route":"existing-CyberSimulationWorker+main-Rapier",
		"measured_frame_pacing":false, "full_controls_qualified":false
	}))
	quit(0 if failures == 0 else 1)


func run() -> void:
	var definition: Dictionary = Catalogue.player_playground_definition()
	var authored: Array = Course.layout()
	expect(not authored.is_empty(), "original playground course is available")
	expect(definition.get("id", "") == Catalogue.PLAYER_COURSE_ID,
		"registered playground route has its own identity")
	expect(Array(definition.get("rectangles", [])).size() == authored.size() * 5,
		"all original course rectangles converted without omission")
	if authored.size() * 5 == Array(definition.get("rectangles", [])).size():
		for index: int in range(authored.size()):
			var record: Dictionary = authored[index]
			var expected: Array = [record.origin.x, record.origin.y,
				record.size.x, record.size.y, record.material]
			expect(Array(definition.rectangles).slice(index * 5, index * 5 + 5) == expected,
				"exact course geometry/material at record %d" % index)
	var checked: Dictionary = Contract.validate(definition)
	expect(bool(checked.get("ok", false)),
		"original layout admitted by existing MicroScenario validator: " + str(checked.get("error", "")))
	expect(Catalogue.exploratory_actor_map(definition),
		"dedicated course admitted as an exploratory gameplay map")
	expect(Catalogue.definition(Catalogue.PLAYER_COURSE_ID) == definition,
		"course definition resolved through existing catalogue")
	if not checked.get("ok", false):
		await finish()
		return

	desktop = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	expect(desktop.worker_start_error == OK
		and desktop.simulation_worker._thread.is_started(),
		"ordinary desktop simulation thread is running")

	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"actual course accepted by ordinary desktop scene")
	var installed: bool = await wait_for(Callable(self, "course_installed"))
	expect(installed, "existing worker acknowledged native course installation")
	if not installed:
		await finish()
		return

	expect(str(desktop.microscenario_definition.id) == Catalogue.PLAYER_COURSE_ID,
		"installed session retains actual course identity")
	expect(desktop.microscenario_definition.rectangles == checked.definition.rectangles,
		"worker-accepted course is not replaced by a demo fallback")
	expect(desktop.actor_prototypes_allowed(), "normal F5 mechanical actor selector remains available")
	expect(desktop.apply_actor_prototype_configuration(&"rapier/acrobat", &"human", false),
		"SetP acrobat selected through existing F5 physical actor path")
	var actor_ready: bool = await wait_for(Callable(self, "actor_installed"))
	expect(actor_ready, "physical actor replacement acknowledged by existing native owner")
	if not actor_ready:
		await finish()
		return

	expect(desktop.physical_rig_id == &"acrobat", "actual SetP model retained")
	var session = desktop.physical_actor_session
	var actor: Dictionary = session.observation(0)
	expect(str(actor.get("model", "")) == "acrobat"
		and str(actor.get("producer", "")) == "human",
		"live real Rapier session owns the correct human preset")
	expect(session.bodies().size() > 0, "Rapier geometry exists, not a sampled mock")

	var terrain_ready: bool = await wait_for(Callable(self, "terrain_installed"), 30000)
	expect(terrain_ready, "actual hard-terrain collider installation gate released")
	if not terrain_ready:
		await finish()
		return

	var initial_position: Vector2 = actor.get("position", Vector2.ZERO)
	_initial_physics_tick = session.tick
	desktop.paused = false
	await process_frame
	key(KEY_D, true)
	var stepped: bool = await wait_for(Callable(self, "player_stepped"), 30000)
	key(KEY_D, false)
	expect(stepped, "main-thread Rapier advances while separate native worker is live")
	if stepped:
		var later: Dictionary = desktop.physical_actor_session.observation(0)
		expect(Vector2(later.get("position", Vector2.ZERO)).x > initial_position.x + 0.25,
			"real keyboard input moves SetP acrobat through actual native course")
	expect(desktop.latest_snapshot != null and desktop.latest_snapshot.tick_index > 0,
		"asynchronous native World completed ordinary material ticks")
	if desktop.latest_snapshot != null:
		print("PLAY_COMP001_EVIDENCE ", JSON.stringify({
			"native_tick":desktop.latest_snapshot.tick_index,
			"physics_tick":session.tick,
			"resolved_native_workers":desktop.latest_snapshot.scheduler_thread_capacity_hint,
			"parallel_phases_last_tick":desktop.latest_snapshot.scheduler_parallel_phases_last_tick,
			"rig":"acrobat", "course":Catalogue.PLAYER_COURSE_ID,
			"terrain_ready":desktop._physical_terrain_ready
		}))
	desktop.paused = true
	desktop.microscenario_reset()
	var reset_ok: bool = await wait_for(Callable(self, "reset_acknowledged"), 30000)
	expect(reset_ok, "reset preserves course + selected mechanical actor through existing owner")
	await finish()
