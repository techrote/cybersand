extends SceneTree

# Real shared-owner coverage. No extra World or physics tick is used to spawn.
const Runtime = preload("res://scripts/player_playground_runtime.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Course = preload("res://scripts/player_playground_course.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var assertions: int = 0
var failures: int = 0
var runtime: CyberPlayerPlaygroundRuntime


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PLAYGROUND_ACTORS: " + message)


func boundary(arena: CyberPhysicalActorArena) -> Dictionary:
	var water: Dictionary = arena.native_world().water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024))
	return {"world": arena.native_world().get_instance_id(),
		"hash": arena.native_world().get_physical_state_hash(), "cells": arena.native_world().get_cells(),
		"stored_cell_content": water.content_hash,
		"water_quantity": PackedInt64Array([water.water_visible, water.water_overfill, water.water_integer]),
		"tick": arena.session.tick, "world_tick": arena.native_world().get_tick_index(),
		"steps": arena.session.bridge.manual_step_count(),
		"run": arena.session.run_id, "epoch": arena.session.epoch,
		"shapes": arena.session.bridge.hard_surface_shape_count(),
		"sequences": arena.session._sequences.duplicate(), "deadlines": arena.session._deadlines.duplicate(),
		"generations": arena.session._generations.duplicate(), "commands": arena.session._commands.duplicate(true),
		"rids": arena.session.bridge._body_rids.duplicate(),
		"applied": arena.session.bridge._applied_sample_serials.duplicate(),
		"sample": arena.session.bridge._sample_serial,
		"receipt": arena.native_world().get_applied_liquid_construction_receipt().duplicate(true)}


func expect_refusal(arena: CyberPhysicalActorArena, model: StringName, position: Vector2, reason: String) -> void:
	var before: Dictionary = boundary(arena)
	var count: int = arena.session.actor_count()
	var bodies: int = arena.session.bridge.body_count()
	var revision: int = int(arena.roster_snapshot().revision)
	var result: Dictionary = arena.spawn_actor(model, position)
	expect(not result.accepted and not str(result.reason).is_empty(), reason + " has explicit refusal")
	expect(boundary(arena) == before and arena.session.actor_count() == count
		and arena.session.bridge.body_count() == bodies and int(arena.roster_snapshot().revision) == revision,
		reason + " retains exact old authority, body IDs, leases, terrain, cells and clocks")


func all_presets() -> void:
	for index: int in range(Course.PRESETS.size()):
		var id: StringName = Course.PRESETS[index]
		var map_id: StringName = Course.MAP_IDS[index + 1]
		var accepted: bool = runtime.configure(id, map_id, 0, true, &"runner")
		expect(accepted, "shared NPC/prop host configures " + str(id) + ": " + runtime.last_error)
		if not accepted: continue
		var arena: CyberPhysicalActorArena = runtime._arena
		var mechanical: bool = not Course.is_swarm(id)
		var expected_actors: int = 2 if mechanical else 1
		var npc: int = expected_actors - 1
		var roster: Dictionary = arena.roster_snapshot()
		expect(arena.session.actor_count() == expected_actors and roster.props.size() == 3,
			str(id) + " shares the player, initial NPC and three actual props")
		expect(int(roster.construction_receipt.initial_body_count) == arena.session.bridge.body_count(),
			str(id) + " immutable native initial body receipt includes all actor and prop bodies")
		expect(runtime.render_parts().size() == arena.session.bridge.body_count(),
			str(id) + " presents every registered physical body")
		if not mechanical:
			expect(runtime._world == arena.native_world() and runtime.observation().representation == "native-material-field",
				str(id) + " keeps material input identity and aliases exactly one native World")
		var initial_npc: Vector2 = arena.session.observation(npc).position
		var initial_prop: Vector2 = roster.props[0].position
		for frame: int in range(12):
			expect(runtime.submit_action({"move": Vector2.RIGHT, "effort": 0.3}), str(id) + " player input admitted")
			runtime.step()
			expect(not runtime.failed and not arena.native_world().has_failed() and runtime.tick == frame + 1
				and int(arena.native_world().get_tick_index()) == frame + 1
				and arena.session.bridge.manual_step_count() == frame + 1,
				str(id) + " advances all owners through exactly one native and Rapier tick")
		expect(arena.session.observation(npc).position != initial_npc and arena.session.accepted_commands > 0,
			str(id) + " actual demo NPC moves through the normal controller")
		expect(Vector2(arena.roster_snapshot().props[0].position) != initial_prop,
			str(id) + " actual loose prop responds to Rapier gravity")


func append_and_refusal() -> void:
	if not runtime.configure(&"stuntbuggy", &"cannon_run", 0, true, &"runner"):
		expect(false, "append fixture configures: " + runtime.last_error)
		return
	var arena: CyberPhysicalActorArena = runtime._arena
	for _tick: int in range(4):
		runtime.submit_action({"move": Vector2.RIGHT})
		runtime.step()
	# Explicit user edits provide an empty stage and an unrelated retained mark.
	var world: Object = arena.native_world()
	expect(world.diagnostic_fill_rect(Vector2i(320, 80), Vector2i(650, 320), 0), "authored clear spawn stage")
	expect(world.diagnostic_fill_rect(Vector2i(990, 80), Vector2i(2, 2), 2), "unrelated user-painted cells retained")
	arena._sync_terrain()
	var view: Dictionary = runtime.observation()
	var live_command: Dictionary = Session.make_command(view, int(view.last_sequence) + 1, {"move": Vector2.LEFT}, 6)
	var before: Dictionary = boundary(arena)
	var old_actors: int = arena.session.actor_count()
	var old_bodies: int = arena.session.bridge.body_count()
	var result: Dictionary = runtime.spawn_npc(&"skimmer", Vector2(400, 150))
	expect(result.accepted and int(result.actor_id) == old_actors and int(result.first_body_id) == old_bodies + 1,
		"live NPC appended after props uses actual bridge offset")
	var after: Dictionary = boundary(arena)
	# Installing a new native mask intentionally wakes/invalidate activity and
	# pressure caches. Full physical hash may change, but actual cells must not.
	for key: String in ["world", "cells", "stored_cell_content", "water_quantity", "tick", "world_tick", "steps", "run", "epoch", "shapes", "receipt"]:
		expect(after[key] == before[key], "append preserves " + key)
	for key: String in ["sequences", "deadlines", "generations", "commands"]:
		expect(after[key].slice(0, old_actors) == before[key], "append preserves old actor " + key)
	expect(after.rids.slice(0, old_bodies) == before.rids and after.applied.slice(0, old_bodies) == before.applied
		and int(after.sample) == int(before.sample) + 1, "append preserves body IDs and response history while sampling one new complete mask")
	expect(int(arena.session._body_offsets[old_actors]) == old_bodies and world.material_at(990, 80) == 2,
		"NPC source IDs include props and unrelated map edits survive")
	expect(arena.submit(live_command, &"human"), "pre-spawn issued player observation/lease remains valid")
	var copied: Dictionary = arena.roster_snapshot()
	copied.props[0].body_id = -1
	copied.actors[0].model = "changed"
	copied.spawn_receipts.clear()
	expect(arena.roster_snapshot().props[0].body_id > 0 and arena.roster_snapshot().actors[0].model == "stuntbuggy"
		and arena.roster_snapshot().spawn_receipts.size() == 1, "roster readback owns immutable copied values")
	var bridge: CyberRapierPhysicsBridge = arena.session.bridge
	var duplicate: Array[RigidBody2D] = [bridge._bodies[0]]
	before = boundary(arena)
	expect(bridge.append_bodies(duplicate, PackedVector2Array([bridge.body_size(0)])) != OK
		and boundary(arena) == before, "duplicate body RID rejected without changing bridge history")
	var overflow: Array[RigidBody2D] = []
	var overflow_sizes := PackedVector2Array()
	for _index: int in range(Coupling.MAX_BODIES):
		overflow.append(bridge._bodies[0])
		overflow_sizes.append(Vector2.ONE)
	expect(bridge.append_bodies(overflow, overflow_sizes) == ERR_OUT_OF_MEMORY and boundary(arena) == before,
		"aggregate 64-body capacity is an explicit transactional refusal")
	expect_refusal(arena, &"4ly_velocity", Vector2(500, 150), "unsupported flight NPC")
	expect_refusal(arena, &"runner", Vector2(-4, 100), "outside map")
	expect_refusal(arena, &"runner", Vector2(NAN, 100), "nonfinite origin")
	expect_refusal(arena, &"skimmer", Vector2(400, 150), "actual existing body overlap")
	expect(world.diagnostic_fill_rect(Vector2i(600, 100), Vector2i(100, 100), 1), "blocked candidate stage")
	arena._sync_terrain()
	expect_refusal(arena, &"runner", Vector2(650, 150), "occupied native cells")
	for position: Vector2 in [Vector2(500, 150), Vector2(800, 150), Vector2(900, 150), Vector2(400, 280), Vector2(500, 280)]:
		if arena.session.actor_count() == Session.MAX_ACTORS: break
		var admitted: Dictionary = arena.spawn_actor(&"runner", position)
		expect(admitted.accepted, "bounded eight-actor roster grows: " + str(admitted.reason))
	expect(arena.session.actor_count() == Session.MAX_ACTORS, "eight actors share the same native authority")
	expect_refusal(arena, &"runner", Vector2(800, 280), "ninth actor")
	var first_steps: int = bridge.manual_step_count()
	var first_tick: int = int(world.get_tick_index())
	var contacts: int = 0
	for _tick: int in range(96):
		var state: Dictionary = arena.step()
		for offset: int in range(0, arena._coupling_results.size(), Coupling.RESULT_STRIDE):
			contacts += roundi(arena._coupling_results[offset + Coupling.RESULT_CONTACT_COUNT])
		for body: RigidBody2D in arena._props:
			contacts += body.get_contact_count()
		if state.failed: break
	expect(not world.has_failed() and int(world.get_tick_index()) == first_tick + 96
		and bridge.manual_step_count() == first_steps + 96, "full roster and props continue without duplicate ticks")
	expect(contacts > 0, "actual props/actors produce native or Rapier contact feedback")
	expect(world.get_applied_liquid_construction_receipt() == before.receipt,
		"late spawns do not rewrite the original native construction receipt")


func props_only() -> void:
	expect(runtime.configure(&"dryswarm", &"dust_foundry", 0, false), "material player admits explicit props-only actor session")
	if runtime._arena == null: return
	var arena: CyberPhysicalActorArena = runtime._arena
	expect(arena.session.actor_count() == 0 and arena.session.bridge.body_count() == 3,
		"zero actor slots do not require a dummy human or NPC")
	for _tick: int in range(4):
		expect(runtime.submit_action({"move": Vector2.RIGHT}), "props-only swarm command admitted")
		runtime.step()
	expect(not runtime.failed and arena.native_world().get_tick_index() == 4
		and arena.session.tick == 4 and arena.session.bridge.manual_step_count() == 4,
		"props-only session and material controller share exactly four ticks")


func pressure_spawn_quantities() -> void:
	for water_choice: int in [2, 3, 4]:
		var accepted: bool = runtime.configure(&"liquidswarm", &"undertow_lab", water_choice, true, &"runner")
		expect(accepted, "pressure NPC/prop construction " + str(water_choice) + ": " + runtime.last_error)
		if not accepted: continue
		var arena: CyberPhysicalActorArena = runtime._arena
		for _tick: int in range(4): runtime.step()
		var world: Object = arena.native_world()
		expect(not world.has_failed(), "pressure host completes its real prefix")
		world.diagnostic_fill_rect(Vector2i(640, 96), Vector2i(160, 128), 0)
		arena._sync_terrain()
		var before: Dictionary = boundary(arena)
		var result: Dictionary = arena.spawn_actor(&"runner", Vector2(720, 150))
		expect(result.accepted, "pressure dynamic spawn: " + str(result.reason))
		var after: Dictionary = boundary(arena)
		expect(after.water_quantity == before.water_quantity and after.stored_cell_content == before.stored_cell_content
			and after.cells == before.cells and after.receipt == before.receipt and after.tick == before.tick,
			"pressure spawn preserves actual stored cells and visible-plus-overfill Water quantity")
		print("PLAYGROUND_ACTOR_PRESSURE choice=", water_choice, " quantity=", after.water_quantity)


func moving_vacated_footprint() -> void:
	expect(runtime.configure(&"dryswarm", &"dust_foundry", 0, false), "moving-mask props-only fixture configures")
	if runtime._arena == null: return
	var arena: CyberPhysicalActorArena = runtime._arena
	var world: Object = arena.native_world()
	var bridge: CyberRapierPhysicsBridge = arena.session.bridge
	world.diagnostic_fill_rect(Vector2i(640, 96), Vector2i(220, 160), 0)
	arena._sync_terrain()
	bridge.reset_body(0, Vector2(720, 150), 0.0)
	PhysicsServer2D.body_set_state(bridge._body_rids[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(3600, 0))
	bridge.refresh_all_states()
	var pre_step_bodies: PackedFloat32Array = bridge.pack_body_states()
	arena.step()
	expect(bridge.body_transform(0).origin.x > 760.0 and int(world.rigid_body_id_at(720, 150)) == 1
		and int(world.inspect_inertial_cell(Vector2i(720, 150)).material) == 0,
		"real Rapier movement leaves a demonstrably stale native pre-step footprint")
	# Actor origins can lie between limbs. Put the candidate's actual first
	# rectangular part, rather than an assumed origin cell, over the old mask.
	var definition: Dictionary = Arena.Equipment.definition(Arena.Catalog.entry(&"runner"))
	var origin: Vector2 = Vector2(720, 150) - Vector2(definition.parts[0].offset)
	# Public setters deliberately refuse nonempty writes into a body mask. For
	# this separate stored-read control, clear it, seed Sand, then reinstall the
	# actual pre-step packet without overlap resolution or another clock tick.
	world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	world.diagnostic_fill_rect(Vector2i(720, 150), Vector2i(2, 2), 2)
	world.prepare_rigid_body_coupling(pre_step_bodies, false)
	expect(int(world.inspect_inertial_cell(Vector2i(720, 150)).material) == 2
		and int(world.rigid_body_id_at(720, 150)) == 1, "occupied test cell really exists behind the old native mask")
	expect_refusal(arena, &"runner", origin, "stored material behind vacated native mask")
	world.diagnostic_fill_rect(Vector2i(720, 150), Vector2i(2, 2), 0)
	var before: Dictionary = boundary(arena)
	var result: Dictionary = arena.spawn_actor(&"runner", origin)
	expect(result.accepted and result.first_body_id == 4, "NPC can occupy a genuinely vacated actual footprint")
	var after: Dictionary = boundary(arena)
	expect(after.cells == before.cells and after.stored_cell_content == before.stored_cell_content
		and after.water_quantity == before.water_quantity and after.rids.slice(0, 3) == before.rids
		and after.tick == before.tick and after.steps == before.steps and after.receipt == before.receipt,
		"vacated-stage spawn retains old IDs, quantities, map, receipt and clocks")


func run() -> void:
	runtime = Runtime.new()
	root.add_child(runtime)
	all_presets()
	append_and_refusal()
	props_only()
	moving_vacated_footprint()
	pressure_spawn_quantities()
	runtime.close()
	runtime.queue_free()
	await process_frame
	print("PLAYER_PLAYGROUND_ACTORS assertions=", assertions, " failures=", failures)
	quit(1 if failures else 0)
