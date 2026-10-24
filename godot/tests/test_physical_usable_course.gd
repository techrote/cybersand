extends SceneTree

const Progress = preload("res://tests/helpers/physical_progress.gd")

# Actual native cells, actual Rapier assemblies and the production issued-view
# action interface. No material, projectile or body implementation is mocked.
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
var arena: CyberPhysicalActorArena
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	if not Progress.begin("test_physical_usable_course"):
		quit(1)
		return
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_USABLE_COURSE: " + message)


func command(extra: Dictionary = {}, movement: Vector2 = Vector2.ZERO) -> Dictionary:
	var view: Dictionary = arena.observation(0)
	var request: Dictionary = {"usable_index": int(view.equipment.usable_index), "aim": Vector2.RIGHT, "power": 0.8}
	request.merge(extra, true)
	return Session.make_command(view, int(view.last_sequence) + 1,
		{"move": movement, "equipment": request}, 18)


func scripted_examples() -> void:
	for model: StringName in [&"digger", &"runner", &"ripper", &"astra", &"tricopter", &"heavylift"]:
		print("REGRESSION_PROGRESS case=test_physical_usable_course phase=script_setup model=", model)
		var config: Dictionary = Arena.usable_course_config(model, 1)
		var ticks: int = 1800 if model == &"heavylift" else 900
		config.max_ticks = ticks
		Progress.mark("configure", str(model))
		expect(arena.configure(config), "course starts " + str(model))
		if arena.session == null:
			continue
		print("REGRESSION_PROGRESS case=test_physical_usable_course phase=world_built model=", model)
		var initial: Dictionary = arena.observation(0)
		var retained: Dictionary = initial.duplicate(true)
		var body: RigidBody2D = arena.session.bodies()[int(initial.equipment.body_id) - 1]
		var body_instance: int = body.get_instance_id()
		var saw_projectile: bool = false
		var saw_release: bool = false
		var saw_pickup: bool = false
		var travel: float = 0.0
		var result: Dictionary = arena.snapshot()
		for tick: int in range(ticks):
			if tick % 150 == 0:
				print("REGRESSION_PROGRESS case=test_physical_usable_course phase=script_step model=", model, " tick=", tick)
			Progress.tick("step")
			result = arena.step()
			var actor: Dictionary = result.actors[0]
			travel = maxf(travel, actor.position.distance_to(initial.position))
			saw_projectile = saw_projectile or not result.physical_usables.projectiles.is_empty()
			saw_pickup = saw_pickup or (saw_release and actor.equipment.state == "held")
			saw_release = saw_release or actor.equipment.state in ["released", "fixed", "deployed"]
		expect(not result.failed and result.tick == ticks and result.world_tick == ticks,
			str(model) + " advances coupled clocks without faults")
		expect(travel > 3.0 and int(result.accepted_commands) >= 150,
			str(model) + " keeps moving through admitted scripted commands")
		expect(int(result.usable_totals.accepted) > 0,
			str(model) + " performs actual native usable work: " + str(result.usable_totals))
		if model in [&"digger", &"runner"]:
			expect(int(result.usable_totals.changed_cells) > 0,
				str(model) + " changes native terrain/material cells")
		elif model == &"heavylift":
			expect(saw_release and body.get_instance_id() == body_instance,
				"heavy delivery releases the original articulated payload body")
			expect(saw_pickup and int(result.actors[0].equipment.equipment_epoch) >= 4,
				"scripted heavy recovery approaches and picks up its original deployed processor")
		else:
			expect(saw_projectile, str(model) + " produces visible committed projectile state")
		expect(initial == retained, str(model) + " retains immutable issued equipment observation")
		print("PHYSICAL_USABLE_COURSE_DEMO model=", model, " travel=", travel,
			" requests=", result.usable_totals, " released=", saw_release, " recovered=", saw_pickup)
		Progress.mark("close")
		arena.close()
		Progress.mark("close_complete")


func mixed_course() -> void:
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=mixed_setup")
	var config: Dictionary = Arena.usable_course_config()
	config.max_ticks = 600
	Progress.mark("configure")
	expect(arena.configure(config), "mixed course starts")
	var expected_parts: int = 0
	for actor: Dictionary in config.actors:
		expected_parts += Equipment.definition(Catalog.entry(StringName(actor.model))).parts.size()
	var initial: Dictionary = arena.snapshot()
	expect(initial.course == "usables-v1" and initial.course_sections.size() == 8,
		"course presents all eight authored practical sections")
	expect(initial.actor_count == 8 and initial.body_count == expected_parts and expected_parts <= 64,
		"eight real equipped assemblies fit the native body roster")
	var result: Dictionary = initial
	for tick: int in range(600):
		if tick % 100 == 0:
			print("REGRESSION_PROGRESS case=test_physical_usable_course phase=mixed_step tick=", tick)
		Progress.tick("step")
		result = arena.step()
	var successful: int = 0
	for actor: Dictionary in result.actors:
		successful += int(int(actor.equipment.accepted_uses) > 0)
		expect(actor.fault == "" and actor.position.is_finite(), "mixed actor remains live " + str(actor.model))
	expect(not result.failed and result.body_count == expected_parts,
		"mixed use/drop/deploy does not clone or discard coupling bodies")
	expect(successful >= 4 and int(result.usable_totals.accepted) > 8,
		"several independent actors perform their equipped work: " + str(result.usable_totals))
	var old_run: String = str(result.run_id)
	expect(arena.reset(), "mixed course resets")
	result = arena.snapshot()
	expect(result.run_id != old_run and result.tick == 0 and result.usable_totals.requests == 0
		and result.physical_usables.projectiles.is_empty() and result.physical_usables.objects.is_empty(),
		"reset retires pending uses and all committed sparse objects")
	var saved_run: String = str(result.run_id)
	config.course = "unknown-course"
	Progress.mark("configure")
	expect(not arena.configure(config) and arena.snapshot().run_id == saved_run,
		"unknown course refusal preserves the live run")
	print("PHYSICAL_USABLE_COURSE_MIXED actors=8 parts=", expected_parts, " successful_actors=", successful)
	Progress.mark("close")
	arena.close()
	Progress.mark("close_complete")


func processor_transaction() -> void:
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=processor_setup")
	var config: Dictionary = Arena.usable_course_config(&"gyrocrate", 1)
	config.max_ticks = 1200
	config.actors[0].producer = "policy"
	config.actors[0].position = Vector2(584, 330)
	Progress.mark("configure")
	expect(arena.configure(config), "native physical processor fixture starts")
	var initial: Dictionary = arena.observation(0).equipment
	var held: RigidBody2D = arena.session.bodies()[int(initial.body_id) - 1]
	var instance: int = held.get_instance_id()
	var count: int = arena.session.bodies().size()
	# Park the carrier above the service pad to isolate the actual free fall,
	# settle/fix gate and native recipe. Only the test fixture parks body motion.
	for body: RigidBody2D in arena.session.bodies():
		if body != held:
			body.freeze = true
	var stale: Dictionary = command({"trigger": true})
	var result: Dictionary = arena.step([stale])
	expect(result.actors[0].equipment.state == "released" and held.get_instance_id() == instance,
		"processor trigger releases the existing body before deployment")
	for tick: int in range(180):
		if tick % 30 == 0:
			print("REGRESSION_PROGRESS case=test_physical_usable_course phase=processor_settle tick=", tick)
		Progress.tick("step")
		result = arena.step([command()])
		if not result.physical_usables.objects.is_empty():
			break
	expect(result.physical_usables.objects.size() == 1 and held.freeze,
		"settled real Rapier body obtains its native processor record")
	if result.physical_usables.objects.size() != 1:
		print("PHYSICAL_USABLE_COURSE_DEPLOY_DIAGNOSTIC ", result.actors[0].equipment)
		Progress.mark("close")
		arena.close()
		Progress.mark("close_complete")
		return
	var object: Dictionary = result.physical_usables.objects[0]
	expect(object.body_id == initial.body_id and object.instance_id == initial.instance_id,
		"native processor names the same physical equipment identity")
	expect(not arena.submit(stale), "pre-drop issued command cannot replay against deployed equipment")
	var feed: Dictionary = arena.course_processor_fixture(0, "feed")
	var jam: Dictionary = arena.course_processor_fixture(0, "jam")
	expect(feed.accepted and jam.accepted, "explicit course controls author real intake and final output jam")
	var stock: int = int(object.stock)
	var cycles: int = int(object.cycles)
	var retained: Dictionary = result.duplicate(true)
	var before_cells: PackedByteArray = arena._world.get_cells()
	Progress.tick("step")
	result = arena.step([command()])
	object = result.physical_usables.objects[0]
	expect(object.status == "blocked-output" and object.stock == stock and object.cycles == cycles,
		"blocked final output refuses the whole recipe without consuming stock")
	var material_inputs: int = 0
	var material_after: int = 0
	var jam_before: int = 0
	var jam_after: int = 0
	var after_cells: PackedByteArray = arena._world.get_cells()
	for y: int in range(320, 352):
		for x: int in range(566, 620):
			material_inputs += int(before_cells[y * 1024 + x] == 13)
			material_after += int(after_cells[y * 1024 + x] == 13)
			jam_before += int(before_cells[y * 1024 + x] == 57)
			jam_after += int(after_cells[y * 1024 + x] == 57)
	# Stone is granular and may fall during the native tick after refusal. Its
	# count stays intact; the explicit brick obstruction stays at the output.
	expect(material_inputs == 1 and material_after == material_inputs and jam_before == 1 and jam_after == jam_before,
		"jam consumes no native intake material and keeps the output obstruction")
	expect(arena.course_processor_fixture(0, "clear").accepted, "course control clears final output")
	expect(arena.course_processor_fixture(0, "feed").accepted, "feed refreshes the intake after ordinary granular motion")
	Progress.tick("step")
	result = arena.step([command()])
	object = result.physical_usables.objects[0]
	expect(object.cycles == cycles + 1 and object.stock == stock - 1,
		"clearing output completes exactly one authored Stone-to-Sand cycle")
	expect(int(result.physical_usables.write_count_last) == 2
		and int(result.physical_usables.sink_slots_last) == 1
		and int(result.physical_usables.source_slots_last) == 1,
		"native processor accounts one consumed and one produced cell slot")
	expect(retained.physical_usables.objects[0].cycles == cycles,
		"later recipe execution leaves retained evaluator snapshot unchanged")
	expect(arena.session.bridge.pending_hard_surface_chunks() == 0,
		"processor hard-material edits reach actual Rapier terrain before stepping")
	for body: RigidBody2D in arena.session.bodies():
		if body != held:
			body.freeze = false
	var picked_up: bool = false
	for tick: int in range(300):
		if tick % 60 == 0:
			print("REGRESSION_PROGRESS case=test_physical_usable_course phase=processor_recover tick=", tick)
		var item: Dictionary = arena.observation(0).equipment
		var approach: float = clampf((Vector2(item.position).x - Vector2(item.grip_position).x) * 0.05, -0.35, 0.35)
		Progress.tick("step")
		result = arena.step([command({"attach": bool(item.reattach_ready)}, Vector2(approach, 0))])
		if result.actors[0].equipment.state == "held":
			picked_up = true
			break
	expect(picked_up and held.get_instance_id() == instance and arena.session.bodies().size() == count,
		"ordinary approach and explicit pickup recover the same processor body")
	Progress.tick("step")
	result = arena.step([command()])
	expect(result.physical_usables.objects.is_empty(), "pickup retires the native deployed incarnation")
	expect(arena.reset() and arena.snapshot().physical_usables.objects.is_empty(),
		"processor run reset discards sparse records and stock history")
	Progress.mark("close")
	arena.close()
	Progress.mark("close_complete")


func run() -> void:
	Progress.mark("run")
	expect(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"RapierPhysicsServer2D"),
		"native and Rapier extensions are required")
	if failures:
		Progress.finish()
		quit(1)
		return
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=setup")
	arena = Arena.new()
	root.add_child(arena)
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=scripted")
	scripted_examples()
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=mixed")
	mixed_course()
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=processor")
	processor_transaction()
	print("REGRESSION_PROGRESS case=test_physical_usable_course phase=teardown")
	arena.free()
	print("PHYSICAL_USABLE_COURSE_RESULT assertions=", assertions, " failures=", failures)
	Progress.mark("quit")
	if not Progress.finish():
		failures += 1
	quit(1 if failures else 0)
