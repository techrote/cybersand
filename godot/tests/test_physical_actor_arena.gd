extends SceneTree

const Progress = preload("res://tests/helpers/physical_progress.gd")

# Real synchronous native/Rapier coverage. No material or physics mock stands
# in for a roster run, a cell effect or the terrain collider update below.
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const ROSTER_TICKS: int = 240
var _assertions: int = 0
var _failures: int = 0
var _arena: CyberPhysicalActorArena


func _init() -> void:
	if not Progress.begin("test_physical_actor_arena"):
		quit(1)
		return
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures += 1
		push_error("PHYSICAL_ARENA: " + message)


func _config(model: StringName, producer: String = "policy", ticks: int = 100,
		position: Vector2 = Vector2(310, 190)) -> Dictionary:
	return {"version": 2, "seed": 3, "max_ticks": ticks, "local_patch_radius": 8,
		"actors": [{"model": str(model), "producer": producer, "position": position}]}


func _command(action: Dictionary, lease: int = 12) -> Dictionary:
	var view: Dictionary = _arena.observation(0)
	return Session.make_command(view, int(view.last_sequence) + 1, action, lease)


func _roster() -> void:
	var largest: StringName = &"runner"
	var largest_count: int = 0
	for id: StringName in Catalog.RIG_IDS:
		print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=roster_setup rig=", id)
		var config: Dictionary = Arena.default_config(id, 1)
		config.seed = 17
		config.max_ticks = ROSTER_TICKS
		Progress.mark("configure", str(id))
		_check(_arena.configure(config), "configure native roster " + str(id) + ": " + _arena.last_error)
		if _arena.session == null:
			continue
		print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=world_built rig=", id)
		var data: Dictionary = Equipment.definition(Catalog.entry(id))
		if int(data.part_count) > largest_count:
			largest_count = int(data.part_count)
			largest = id
		var initial: Dictionary = _arena.observation(0)
		_check(int(_arena.snapshot().terrain_shapes) > 0, str(id) + " has real native terrain shapes")
		var state: Dictionary = _arena.snapshot()
		var travel: float = 0.0
		for _tick: int in range(ROSTER_TICKS):
			if _tick % 60 == 0:
				print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=roster_step rig=", id, " tick=", _tick)
			Progress.tick("step")
			state = _arena.step()
			travel = maxf(travel, state.actors[0].position.distance_to(initial.position))
		_check(not bool(state.failed) and int(state.tick) == ROSTER_TICKS and int(state.world_tick) == ROSTER_TICKS,
			str(id) + " completes native and Rapier ticks together: " + str(state.reason))
		_check(int(state.accepted_commands) >= ROSTER_TICKS / Session.DECISION_TICKS
			and travel > 3.0, str(id) + " sustains its demo in the coupled native world")
		_check(bool(state.truncated) and not bool(state.terminated), str(id) + " explicit tick-budget truncation")
		_check(int(state.body_count) == int(data.part_count) and _arena.render_parts().size() == int(data.part_count),
			str(id) + " keeps every articulated collider and drawing part")
		var results: PackedFloat32Array = state.cellular_results
		_check(results.size() == int(data.part_count) * Coupling.RESULT_STRIDE,
			str(id) + " retains native feedback for every part")
		for index: int in range(int(data.part_count)):
			var part: Dictionary = state.actors[0].parts[index]
			_check(part.position.is_finite() and part.velocity.is_finite()
				and is_finite(float(part.rotation)) and is_finite(float(part.angular_velocity)),
				str(id) + " finite actual part " + str(index))
			_check(int(results[index * Coupling.RESULT_STRIDE]) == index + 1,
				str(id) + " native part identity " + str(index))
		_check(initial.tick == 0 and initial.cell_patch.materials.size() == 169,
			str(id) + " retained bounded observation is immutable")
		var weak_world: WeakRef = weakref(_arena._world)
		print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=roster_teardown rig=", id)
		Progress.mark("close")
		_arena.close()
		Progress.mark("close_complete")
		_check(_arena.get_child_count() == 0 and _arena.render_parts().is_empty() and weak_world.get_ref() == null,
			str(id) + " closes actual world, space, bodies and joints")
	print("PHYSICAL_ARENA_ROSTER models=", Catalog.RIG_IDS.size(), " ticks_each=", ROSTER_TICKS, " real_native=true")
	# Exercise eight independent actors using the largest real authored assembly.
	var batch: Dictionary = Arena.default_config(largest, 8)
	batch.max_ticks = 8
	for actor: Dictionary in batch.actors:
		actor.model = str(largest)
	Progress.mark("configure")
	_check(_arena.configure(batch), "eight largest assemblies admitted")
	var result: Dictionary = _arena.snapshot()
	for _tick: int in range(8):
		result = _arena.step()
	_check(not bool(result.failed) and int(result.actor_count) == 8 and int(result.body_count) == largest_count * 8,
		"eight actors preserve all independent articulated parts")
	_check(result.cellular_results.size() == largest_count * 8 * Coupling.RESULT_STRIDE,
		"eight-actor native feedback is complete")
	print("PHYSICAL_ARENA_CAPACITY actors=8 parts=", result.body_count, " largest_rig=", largest)
	Progress.mark("close")
	_arena.close()
	Progress.mark("close_complete")


func _protocol() -> void:
	Progress.mark("configure")
	_check(_arena.configure(_config(&"pouncer", "policy", 100, Vector2(380, 340))), "policy arena starts")
	var first: Dictionary = _arena.observation(0)
	_check(first.cell_patch.materials.size() == 289 and first.cell_patch.body_ids.size() == 289,
		"local patch is at most 17 by 17 and includes transient identity")
	_check(not first.has("actors") and not first.has("terrain_shapes"), "policy view omits full evaluator roster")
	var old_command: Dictionary = Session.make_command(first, 0, {"primary": true}, 1)
	_check(not _arena.submit(old_command, &"human"), "arena preserves exclusive policy ownership")
	var state: Dictionary = _arena.step([old_command])
	_check(state.command_results.size() == 1 and bool(state.command_results[0].accepted), "wire command admitted at the integration boundary")
	_check(int(state.tick) == 1 and int(state.world_tick) == 1, "one admitted batch advances each clock once")
	_check(not _arena.submit(old_command), "duplicate sequence is rejected")
	Progress.tick("step")
	state = _arena.step()
	_check(state.actors[0].action.is_empty() and float(state.actors[0].charge) == 0.0,
		"expired charged input cancels without a release impulse")
	_check(not _arena.submit(Session.make_command(first, 1, {"primary": true}, 1)), "source-anchored lease cannot refresh stale input")
	var tick: int = int(state.tick)
	_arena.step({"action": "not an array"})
	_check(int(_arena.snapshot().tick) == tick, "malformed batch does not advance the environment")
	_arena.step([_command({"move": [1, 0]}), _command({"move": [-1, 0]})])
	_check(int(_arena.snapshot().tick) == tick, "duplicate actor batch is rejected before admission")
	var cancelled: Dictionary = _command({"tool": true})
	_check(_arena.cancel(0, &"policy"), "owner cancellation succeeds")
	_check(not _arena.submit(cancelled), "same-tick cancellation revokes issued observation")
	var paused_command: Dictionary = _command({"primary": true})
	_arena.set_paused(true)
	_arena.step()
	_check(int(_arena.snapshot().tick) == tick and int(_arena.snapshot().world_tick) == tick, "pause holds both clocks")
	_check(not _arena.submit(paused_command), "pause refuses new actuation")
	_arena.set_paused(false)
	_check(not _arena.submit(paused_command), "resume cannot replay a pre-pause capability")
	_check(_arena.submit(_command({"move": [1, 0]})), "fresh resumed observation can control")
	var live_id: String = str(_arena.snapshot().run_id)
	for invalid: Variant in [null, [], {}, {"version": 1, "actors": [{"model": "runner"}]},
		{"actors": [{"model": "runner", "position": [NAN, 10]}]},
		{"actors": [{"model": "runner", "position": [true, 200]}]},
		{"actors": [{"model": "runner", "position": [1.0e20, 300]}]},
		{"actors": [{"model": "runner", "producer": "remote"}]},
		{"seed": 1.5, "actors": [{"model": "runner"}]},
		{"max_ticks": 36001, "actors": [{"model": "runner"}]},
		{"local_patch_radius": 9, "actors": [{"model": "runner"}]},
		{"unknown": true, "actors": [{"model": "runner"}]}]:
		Progress.mark("configure")
		_check(not _arena.configure(invalid), "invalid arena configuration refused")
		_check(str(_arena.snapshot().run_id) == live_id and int(_arena.snapshot().tick) == tick,
			"rejected reset preserves the running owner")
	var before_reset: Dictionary = _command({"primary": true})
	var old_epoch: int = int(_arena.snapshot().epoch)
	_check(_arena.reset(), "validated config resets in place")
	_check(int(_arena.snapshot().tick) == 0 and int(_arena.snapshot().world_tick) == 0
		and int(_arena.snapshot().epoch) > old_epoch and str(_arena.snapshot().run_id) != live_id,
		"reset creates fresh epoch, capabilities, physics space and native world")
	_check(not _arena.submit(before_reset), "reset fences old run command")
	_check(_arena.snapshot().effects.is_empty() and int(_arena.snapshot().effect_totals.requests) == 0,
		"reset retains no deferred usable work")
	var encoded: Variant = Arena.json_value(_arena.observation(0))
	var round_trip: Variant = JSON.parse_string(JSON.stringify(encoded))
	_check(round_trip is Dictionary and round_trip.position is Array and round_trip.position.size() == 2,
		"wire observation JSON uses numeric vector arrays")
	_check(round_trip.cell_patch.materials is Array and round_trip.cell_patch.materials.size() == 289,
		"bounded native cell patch survives JSON serialization")
	Progress.mark("close")
	_arena.close()
	Progress.mark("close_complete")
	Progress.mark("close")
	_arena.close()
	Progress.mark("close_complete")
	_check(_arena.session == null and _arena.get_child_count() == 0 and _arena.observation(0).is_empty(),
		"teardown is idempotent and issues no new views")


func _native_effects_and_terrain() -> void:
	Progress.mark("configure")
	_check(_arena.configure(_config(&"runner")), "physical stamper arena starts")
	var command: Dictionary = _command({"equipment": {"aim": [1, 0], "trigger": true, "power": 1.0}}, 1)
	var state: Dictionary = _arena.step([command])
	var receipts: Array = state.physical_usables.receipts
	_check(receipts.size() == 1 and receipts[0].accepted and int(receipts[0].changed_cells) > 0,
		"mounted catalogue tool produces a real native deposit")
	var stored: PackedByteArray = _arena._world.get_cells()
	var deposited: int = 0
	for y: int in range(175, 205):
		for x: int in range(300, 380):
			deposited += int(stored[y * 1024 + x] == 57)
	_check(deposited > 0 and deposited == int(state.usable_totals.changed_cells)
		and state.actors[0].equipment.last_recoil.x < 0.0,
		"native receipt agrees with stored Industrial Brick and real part recoil")
	_check(not _arena.submit(command), "material effect cannot replay the input sequence")
	_arena.step()
	_check(int(_arena.snapshot().usable_totals.requests) == 1, "expired equipment lease queues no later material edits")
	_check(_arena.reset(), "stamper reset succeeds")
	_check(_arena.snapshot().usable_totals.requests == 0, "reset replaces edited world and pending equipment work")
	Progress.mark("close")
	_arena.close()
	Progress.mark("close_complete")

	Progress.mark("configure")
	_check(_arena.configure(_config(&"lineshank", "policy", 10, Vector2(328, 270))), "physical cutter arena starts")
	var previous_revision: int = int(_arena.snapshot().terrain_revision)
	_check(int(_arena._world.material_at(328, 240)) == 56, "authored packed-earth target exists natively")
	Progress.tick("step")
	state = _arena.step([_command({"equipment": {"aim": [0, -1], "trigger": true, "power": 1.0}}, 1)])
	_check(int(state.usable_totals.changed_cells) > 0,
		"catalogue cutter changes native hard terrain through the physical equipment path")
	_check(int(state.terrain_revision) > previous_revision
		and int(state.terrain_revision) == int(_arena._world.get_hard_surface_revision())
		and _arena.session.bridge.pending_hard_surface_chunks() == 0,
		"every changed native hard-terrain chunk reaches Rapier before its next step")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(328.5, 240.5)
	query.collision_mask = 1
	_check(int(_arena._world.material_at(328, 240)) == 0
		and _arena.session.get_world_2d().direct_space_state.intersect_point(query, 8).is_empty(),
		"excavated native cell has no stale Rapier terrain collider")
	query.position = Vector2(330.5, 245.5)
	_check(not _arena.session.get_world_2d().direct_space_state.intersect_point(query, 8).is_empty(),
		"uncut neighboring target retains its real terrain collider")
	Progress.mark("close")
	_arena.close()
	Progress.mark("close_complete")


func _run() -> void:
	Progress.mark("run")
	var start_usec: int = Time.get_ticks_usec()
	_check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"RapierPhysicsServer2D"),
		"pinned native and Rapier extensions are required")
	if _failures > 0:
		Progress.finish()
		quit(1)
		return
	print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=setup")
	_arena = Arena.new()
	root.add_child(_arena)
	print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=roster")
	_roster()
	print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=protocol")
	_protocol()
	print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=effects")
	_native_effects_and_terrain()
	print("REGRESSION_PROGRESS case=test_physical_actor_arena phase=teardown")
	_arena.free()
	print("PHYSICAL_ARENA_RESULT assertions=", _assertions, " failures=", _failures,
		" elapsed_ms=", float(Time.get_ticks_usec() - start_usec) / 1000.0)
	Progress.mark("quit")
	if not Progress.finish():
		_failures += 1
	quit(1 if _failures > 0 else 0)
