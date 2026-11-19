extends Node2D

# Finite experimental owner. The same fixture/controller is used by the visible
# evaluator and the source-built regression. It reuses the real authored fleet,
# Rapier manual-step bridge and copied native APIs; no substitute body physics.
const Session = preload("res://scripts/physical_actor_session.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const SCENES: Array[String] = ["dam", "deep_pool", "interference_add", "interference_cancel",
	"basins", "waterfall", "terrain", "body", "needle", "sparse"]
const LABELS: Array[String] = ["Large dam break", "Deep pool / repeated disturbances",
	"Two approaching crests", "Crest meeting trough", "Many small basins", "Waterfall and channel",
	"Water against hard terrain", "Moving Rapier barrel", "Pilot the real Needle", "Sparse sleep and wake"]
const SOLVERS: Array[String] = ["wave_flow_v1", "freemass_v1", "inertial_cellular_v1", "pressure_flow_v1"]
const ROCK: int = 1
const WATER: int = 3
var world: Variant
var actors: CyberPhysicalActorSession
var extent := Vector2i(512, 512)
var scene_id: String = "dam"
var solver: String = "wave_flow_v1"
var error: String = ""
var ticks: int = 0
var initial_quantity: int = 0
var contacts: int = 0
var received_impulses: int = 0
var _epoch: int = 0


func configure(kind: String, law: String, workers: int, substeps: int, side: int = 512) -> bool:
	if kind not in SCENES or law not in SOLVERS or workers < 1 or workers > 32 \
		or substeps < 1 or substeps > 8 or side not in [128, 256, 512, 1024, 2048]:
		error = "Unsupported evaluation configuration"
		return false
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		error = "Source-matched native runtime is unavailable"
		return false
	var candidate: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	if law in ["inertial_cellular_v1", "pressure_flow_v1"]:
		var found: bool = false
		for choice: Dictionary in bridge.liquid_policy_assignment_choices(policy, WATER):
			if choice.accepted and choice.family == law and choice.variant == "reference":
				policy = choice.request
				found = true
				break
		if not found:
			error = "Selected comparison solver is unavailable"
			return false
	var body_scene: bool = kind in ["body", "needle"]
	if not candidate.has_method(&"get_wave_flow_status") or not candidate.diagnostic_reset({
		"workers":workers, "wave_flow":law == "wave_flow_v1", "wave_substeps":substeps,
		"extent":Vector2i(side, side), "liquid_policy":policy, "workbench":body_scene, "telemetry":false}):
		error = str(candidate.get_last_tick_error())
		if error.is_empty(): error = "Wave Flow runtime does not match this evaluator"
		return false
	candidate.set_simulation_window_enabled(false)
	close()
	world = candidate
	extent = Vector2i(side, side)
	scene_id = kind
	solver = law
	ticks = 0
	contacts = 0
	received_impulses = 0
	error = ""
	if not _build_scene(): return false
	if body_scene and not _build_actor(kind == "needle"): return false
	initial_quantity = quantity()
	return true


func _rect(x: int, y: int, width: int, height: int, material: int) -> bool:
	if not world.diagnostic_fill_rect(Vector2i(x, y), Vector2i(width, height), material):
		error = "Fixture rectangle was refused"
		return false
	return true


func _build_scene() -> bool:
	var n: int = extent.x
	var rim: int = maxi(2, n / 128)
	var floor_y: int = n - 12
	if not (_rect(8, 8, rim, n - 16, ROCK) and _rect(n - 8 - rim, 8, rim, n - 16, ROCK)
		and _rect(8, floor_y, n - 16, rim, ROCK)): return false
	var left: int = 8 + rim
	var right: int = n - 8 - rim
	var water_top: int = n / 2
	match scene_id:
		"dam":
			return _rect(left, n / 5, n / 3 - left, floor_y - n / 5, WATER)
		"basins", "sparse":
			var step_size: int = maxi(32, n / 8)
			var separation: int = step_size * 2 if scene_id == "sparse" else step_size + rim * 2
			for y: int in range(step_size, floor_y - step_size, separation):
				for x: int in range(left + step_size / 2, right - step_size, separation):
					if not (_rect(x, y, rim, step_size, ROCK) and _rect(x + step_size, y, rim, step_size, ROCK)
						and _rect(x, y + step_size, step_size + rim, rim, ROCK)
						and _rect(x + rim, y + step_size / 2, step_size - rim, step_size / 2, WATER)): return false
			return true
		"waterfall":
			return _rect(left, n / 5, n / 3, n / 6, WATER) \
				and _rect(left, n / 5 + n / 6, n / 4, rim, ROCK) \
				and _rect(n / 2, n * 2 / 3, n / 3, rim, ROCK) \
				and _rect(left, floor_y - n / 12, right - left, n / 12, WATER)
		"terrain":
			if not _rect(left, n / 4, right - left, floor_y - n / 4, WATER): return false
			for x: int in range(n / 5, right - n / 6, n / 5):
				if not _rect(x, n * 2 / 3, n / 14, floor_y - n * 2 / 3, ROCK): return false
			return true
		_:
			if not _rect(left, water_top, right - left, floor_y - water_top, WATER): return false
			if scene_id in ["interference_add", "interference_cancel"]:
				disturb(-1)
				disturb(1, scene_id == "interference_cancel")
			return true


func _build_actor(needle: bool) -> bool:
	_epoch += 1
	actors = Session.new()
	add_child(actors)
	var definitions: Array = [{"model":"needle" if needle else "reference_barrel", "instance_id":1,
		"position":Vector2(extent.x * 0.5, extent.y * 0.5 - (1 if needle else 4)),
		"canvas_extent":extent, "producer":"human" if needle else "passive",
		"workbench_options":{"response":"LA-SELECTIVE", "budget":20.0,
			"mass_multiplier":1.0, "inertia_multiplier":1.0, "thrust_multiplier":1.0,
			"torque_multiplier":1.0, "boost_multiplier":2.0}}]
	if not actors.configure(definitions, get_world_2d().space, _epoch):
		error = actors.last_error
		return false
	actors.bridge.rebuild_hard_surface_colliders_from_rectangles(world.get_hard_surface_rectangles())
	var body: RigidBody2D = actors.bodies()[0]
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2(5, 10))
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.3)
	actors.bridge.refresh_all_states()
	return true


# Relocate existing whole Water cells. No source/sink is hidden in a splash.
# Reverse swaps a raised patch for a lowered patch to create the trough arm.
func disturb(side: int = -1, reverse: bool = false) -> int:
	if world == null: return 0
	var n: int = extent.x
	var span: int = maxi(4, n / 64)
	var x0: int = n / 3 if side < 0 else n * 2 / 3
	if scene_id in ["sparse", "basins"]:
		var step_size: int = maxi(32, n / 8)
		x0 = 8 + maxi(2, n / 128) * 2 + step_size / 2 + step_size / 3
	var moved: int = 0
	for x: int in range(x0, x0 + span):
		var surface: int = -1
		for y: int in range(10, n - 12):
			if world.material_at(x, y) == WATER:
				surface = y
				break
		if surface < span + 10: continue
		for d: int in range(span):
			var from := Vector2i(x, surface + d)
			var to := Vector2i(x + span * (2 if side < 0 else -2), surface - span + d)
			if to.x <= 10 or to.x >= n - 10: continue
			if reverse:
				to = Vector2i(x + span * 3, surface - 1 - d)
			if world.material_at(to.x, to.y) == 0 and world.diagnostic_relocate_cell(from, to): moved += 1
	return moved


func tick_native() -> bool:
	if world == null or not error.is_empty(): return false
	if actors != null:
		var sample: Dictionary = actors.pack_workbench_sample()
		if sample.is_empty() or not world.prepare_workbench_coupling(sample.states, sample.geometry,
			sample.bodies, sample.session, sample.epoch, true):
			error = "Native body sample was refused"
			return false
	if not world.simulation_tick():
		error = str(world.get_last_tick_error())
		return false
	ticks += 1
	if actors != null:
		var response: Dictionary = world.workbench_coupling_results()
		received_impulses += actors.apply_workbench_results(ticks, response)
		for row: Dictionary in response.get("rows", []): contacts += int(row.get("contacts", 0))
	return true


func tick_physics(action: Dictionary = {}) -> void:
	if actors == null or not error.is_empty(): return
	if scene_id == "needle":
		actors.submit_workbench_action(1, action, {"q":false, "e":false, "s":false, "boost":false}, false)
	actors.advance(actors.bridge.fixed_delta())
	actors.bridge.step()
	actors.complete_step()
	if not actors.last_error.is_empty(): error = actors.last_error


func step(action: Dictionary = {}) -> bool:
	tick_physics(action)
	return tick_native()


func quantity() -> int:
	return 0 if world == null else int(world.get_wave_flow_status().water_quantity)


func status() -> Dictionary:
	if world == null: return {"error":error}
	var result: Dictionary = world.get_wave_flow_status()
	result["error"] = error
	result["solver"] = solver
	result["scene"] = scene_id
	result["quantity_delta"] = quantity() - initial_quantity
	result["contacts"] = contacts
	result["received_responses"] = received_impulses
	return result


func close() -> void:
	if actors != null:
		actors.close()
		actors.free()
		actors = null
	world = null


func _exit_tree() -> void:
	close()
