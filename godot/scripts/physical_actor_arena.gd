class_name CyberPhysicalActorArena
extends Node2D

# A distinct synchronous ACT-004 environment. The ordinary desktop worker and
# sampled Thunderbowl v1 retain their own scheduling and observation contracts.
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Effects = preload("res://scripts/physical_actor_effects.gd")
const UsableRuntime = preload("res://scripts/physical_usable_runtime.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")
const UsableCourse = preload("res://scripts/physical_usable_course.gd")
const PlayerCourse = preload("res://scripts/player_playground_course.gd")
const FlightCourse = preload("res://scripts/physical_flight_course.gd")
const FlightProfile = preload("res://scripts/physical_flight_profile.gd")
const VERSION: int = 2
const PHYSICS_HZ: int = 60
const MAX_TICKS: int = 36000
const ARENA_RECT := Rect2i(128, 128, 512, 256)
const FLOOR_Y: int = 352
const SCHEDULE: String = "synchronous-mask-actuation-effects-material-feedback-terrain-rapier/v1"

var last_error: String = ""
var session: CyberPhysicalActorSession
var config: Dictionary = {}
var _world: Object
var _viewport: SubViewport
var _effects := Effects.new()
var _usables := UsableRuntime.new()
var _usable_requests_total: int = 0
var _usable_accepted_total: int = 0
var _usable_refused_total: int = 0
var _usable_changes_total: int = 0
var _course_fixture_result: Dictionary = {}
var _epoch_counter: int = 0
var _terrain_revision: int = -1
var _finished: bool = true
var _failed: bool = false
var _reason: String = "not_configured"
var _paused: bool = false
var _coupling_results := PackedFloat32Array()
var _effect_receipts: Array = []
var _command_receipts: Array = []
var _effect_requests_total: int = 0
var _effect_changes_total: int = 0
var _effect_refusals_total: int = 0
var _presentation_tick: int = -6
var _presentation_revision: int = -1
var _presentation_rect := Rect2i()
var _presentation_cache := PackedByteArray()


static func default_config(model: StringName = &"ripper", count: int = 4) -> Dictionary:
	var actors: Array = []
	var first: int = Catalog.RIG_IDS.find(model)
	if first < 0:
		first = 0
	for index: int in range(clampi(count, 1, Session.MAX_ACTORS)):
		actors.append({"model": str(Catalog.RIG_IDS[(first + index) % Catalog.RIG_IDS.size()]), "producer": "demo"})
	return {"version": VERSION, "seed": 0, "max_ticks": 36000, "actors": actors, "local_patch_radius": 6}


static func usable_course_config(model: StringName = &"digger", count: int = 8) -> Dictionary:
	return UsableCourse.config(model, count)


func _validated_config(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() > 8:
		return {}
	for key: Variant in value:
		if str(key) not in ["version", "seed", "max_ticks", "actors", "local_patch_radius", "course", "flight_scenario", "flight_split"]:
			return {}
	if not value.get("course", "manoeuvre") is String or str(value.get("course", "manoeuvre")) not in ["manoeuvre", UsableCourse.ID, PlayerCourse.ID, FlightCourse.ID]:
		return {}
	if str(value.get("course", "")) == FlightCourse.ID:
		if FlightCourse.scenario(str(value.get("flight_scenario", "")), int(value.get("seed", 0)), str(value.get("flight_split", "development"))).is_empty():
			return {}
	if not Session._integer(value.get("version", VERSION), VERSION, VERSION) \
		or not Session._integer(value.get("seed", 0), 0, 2147483647) \
		or not Session._integer(value.get("max_ticks", 600), 1, MAX_TICKS) \
		or not Session._integer(value.get("local_patch_radius", 6), 0, 8):
		return {}
	var actors: Variant = value.get("actors")
	if not actors is Array or actors.is_empty() or actors.size() > Session.MAX_ACTORS:
		return {}
	var definitions: Array = []
	for index: int in range(actors.size()):
		var actor: Variant = actors[index]
		if not actor is Dictionary or actor.size() > 3:
			return {}
		for key: Variant in actor:
			if str(key) not in ["model", "producer", "position"]:
				return {}
		if not actor.get("model") is String and not actor.get("model") is StringName:
			return {}
		var model := StringName(str(actor.model))
		var producer := StringName(str(actor.get("producer", "demo")))
		if not Catalog.has_rig(model) or producer not in Session.PRODUCERS:
			return {}
		var data: Dictionary = Equipment.definition(Catalog.entry(model))
		var position: Variant = actor.get("position", Vector2(
			176.0 + float(index) * 56.0, FLOOR_Y - float(data.spawn_floor_clearance)))
		if position is Array and position.size() == 2 \
			and (position[0] is int or position[0] is float) and (position[1] is int or position[1] is float):
			position = Vector2(float(position[0]), float(position[1]))
		if not position is Vector2 or not position.is_finite() or not Rect2(ARENA_RECT).has_point(position):
			return {}
		definitions.append({"model": model, "producer": producer, "position": position})
	if not Session.valid_definitions(definitions):
		return {}
	if str(value.get("course", "")) == FlightCourse.ID:
		var flight_scenario: Dictionary = FlightCourse.scenario(str(value.get("flight_scenario", "")),
			int(value.get("seed", 0)), str(value.get("flight_split", "development")))
		if definitions.size() != 1 or not FlightProfile.has_rig(definitions[0].model) \
			or Vector2(definitions[0].position).distance_to(Vector2(flight_scenario.start)) > 0.0001:
			return {}
	return {"version": VERSION, "seed": int(value.get("seed", 0)),
		"max_ticks": int(value.get("max_ticks", 600)), "actors": definitions,
		"local_patch_radius": int(value.get("local_patch_radius", 6)), "course": str(value.get("course", "manoeuvre")),
		"flight_scenario": str(value.get("flight_scenario", "")), "flight_split": str(value.get("flight_split", "development"))}


func configure(value: Variant) -> bool:
	var validated: Dictionary = _validated_config(value)
	if validated.is_empty() or not is_inside_tree():
		last_error = "invalid_config_or_owner"
		return false
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		last_error = "native_or_rapier_unavailable"
		return false
	if not is_equal_approx(float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)), 60.0):
		last_error = "physical_arena_requires_60_hz"
		return false
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not world.diagnostic_reset({"workers": 1, "telemetry": false}):
		last_error = "native_reset"
		return false
	world.set_simulation_window_enabled(false)
	world.set_cadence_lod_enabled(false)
	var rectangles: Array = layout(int(validated.seed))
	if validated.course == UsableCourse.ID:
		rectangles = UsableCourse.layout()
	elif validated.course == PlayerCourse.ID:
		rectangles = PlayerCourse.layout()
	elif validated.course == FlightCourse.ID:
		rectangles = FlightCourse.layout(validated.flight_scenario, validated.seed, validated.flight_split)
	for rectangle: Dictionary in rectangles:
		if not world.diagnostic_fill_rect(rectangle.origin, rectangle.size, rectangle.material):
			last_error = "native_layout"
			return false
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(512, 256)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var candidate := Session.new()
	viewport.add_child(candidate)
	if not candidate.configure(validated.actors, viewport.world_2d.space, _epoch_counter + 1):
		last_error = candidate.last_error
		candidate.close()
		viewport.free()
		return false
	# Commit only after validation, native layout and the complete articulated
	# assembly succeed. A malformed reset cannot destroy a running environment.
	close()
	_world = world
	_viewport = viewport
	session = candidate
	config = validated.duplicate(true)
	_epoch_counter += 1
	_effects.reset(_epoch_counter)
	_usables.reset(_epoch_counter)
	_usable_requests_total = 0
	_usable_accepted_total = 0
	_usable_refused_total = 0
	_usable_changes_total = 0
	_course_fixture_result.clear()
	_finished = false
	_failed = false
	_paused = false
	_reason = "running"
	last_error = ""
	_terrain_revision = -1
	_effect_requests_total = 0
	_effect_changes_total = 0
	_effect_refusals_total = 0
	_presentation_tick = -6
	_presentation_revision = -1
	_sync_terrain()
	if _failed:
		return false
	_world.prepare_rigid_body_coupling(session.bridge.pack_body_states(), false)
	return true


static func layout(seed: int) -> Array:
	var result: Array = [
		{"origin": Vector2i(128, FLOOR_Y), "size": Vector2i(512, 8), "material": 1},
		{"origin": Vector2i(128, 140), "size": Vector2i(4, 220), "material": 1},
		{"origin": Vector2i(636, 140), "size": Vector2i(4, 220), "material": 1},
		{"origin": Vector2i(128, 136), "size": Vector2i(512, 4), "material": 1},
		{"origin": Vector2i(242, 294), "size": Vector2i(56, 4), "material": 1},
		{"origin": Vector2i(436, 265), "size": Vector2i(64, 4), "material": 1},
		{"origin": Vector2i(350, 212), "size": Vector2i(60, 4), "material": 1},
		# A small authored excavation target exercises native hard-terrain edits.
		{"origin": Vector2i(324, 232), "size": Vector2i(8, 16), "material": 56},
		{"origin": Vector2i(318, 336), "size": Vector2i(9, 16), "material": 56},
		{"origin": Vector2i(152, 348), "size": Vector2i(52, 4), "material": 2},
		{"origin": Vector2i(536, 346), "size": Vector2i(68, 6), "material": 2},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index: int in range(5):
		var height: int = rng.randi_range(3, 9)
		result.append({"origin": Vector2i(205 + index * 84, FLOOR_Y - height),
			"size": Vector2i(7, height), "material": 2})
	return result


func reset() -> bool:
	return configure(config)


func observation(actor_id: int) -> Dictionary:
	if session == null or _world == null or _failed:
		return {}
	var view: Dictionary = session.observation(actor_id)
	if view.is_empty():
		return view
	view["environment_version"] = VERSION
	view["schedule"] = SCHEDULE
	view["observation_scope"] = "self, rig rays and bounded composed native cells"
	var radius: int = int(config.local_patch_radius)
	var centre: Vector2 = view.position
	# Escaped bodies still get a bounded outside-world patch; finite but enormous
	# transforms must never be narrowed directly into integer cell coordinates.
	var patch_origin := Vector2i(floori(clampf(centre.x, -1024.0, 2048.0)),
		floori(clampf(centre.y, -1024.0, 2048.0))) - Vector2i(radius, radius)
	var width: int = radius * 2 + 1
	var materials := PackedByteArray()
	var body_ids := PackedByteArray()
	materials.resize(width * width)
	body_ids.resize(width * width)
	for y: int in range(width):
		for x: int in range(width):
			materials[y * width + x] = int(_world.material_at(patch_origin.x + x, patch_origin.y + y))
			body_ids[y * width + x] = int(_world.rigid_body_id_at(patch_origin.x + x, patch_origin.y + y))
	view["cell_patch"] = {"origin": patch_origin, "size": Vector2i(width, width),
		"materials": materials, "body_ids": body_ids, "sample_tick": session.tick,
		"body_mask_pose_tick": maxi(0, session.tick - 1)}
	var own_effects: Array = []
	for receipt: Dictionary in _effect_receipts:
		if int(receipt.actor_slot) == actor_id:
			own_effects.append(receipt.duplicate(true))
	view["last_effects"] = own_effects
	return view


func local_flight_rays(actor_id: int, maximum_distance: float = 80.0) -> Dictionary:
	# Narrow main-thread OWNER sensing over the same installed native terrain
	# collision as the real body. Only bounded range fractions and masks leave.
	if session == null or _viewport == null or _finished or _failed or actor_id != 0 \
		or not session.is_flight_actor(actor_id) or maximum_distance < 8.0 or maximum_distance > 96.0:
		return {"available": false, "distances": [], "hits": [], "valid": []}
	var view: Dictionary = session.observation(actor_id)
	var position: Vector2 = view.get("centre", Vector2.INF)
	if not position.is_finite():
		return {"available": false, "distances": [], "hits": [], "valid": []}
	var body: RigidBody2D = session.bodies()[0]
	var exclusions: Array[RID] = [body.get_rid()]
	var vectors: Array[Vector2] = [Vector2.RIGHT, Vector2(1, -1).normalized(),
		Vector2.UP, Vector2(-1, -1).normalized(), Vector2.LEFT,
		Vector2(-1, 1).normalized(), Vector2.DOWN, Vector2(1, 1).normalized()]
	var distances: Array[float] = []
	var hits: Array[bool] = []
	var valid: Array[bool] = []
	for direction: Vector2 in vectors:
		var query := PhysicsRayQueryParameters2D.create(position,
			position + direction * maximum_distance, 1, exclusions)
		query.hit_from_inside = false
		var result: Dictionary = _viewport.world_2d.direct_space_state.intersect_ray(query)
		var hit: bool = not result.is_empty()
		distances.append(clampf(position.distance_to(Vector2(result.position)) / maximum_distance, 0.0, 1.0) if hit else 1.0)
		hits.append(hit)
		valid.append(true)
	return {"available": true, "maximum_distance_cells": maximum_distance,
		"distances": distances, "hits": hits, "valid": valid}


func flight_contact_count(actor_id: int) -> int:
	# Evaluator-only authoritative Rapier contact count. Not part of the
	# policy-visible observation or low-level stabilizer input.
	if session == null or not session.is_flight_actor(actor_id) or actor_id != 0:
		return -1
	var body: RigidBody2D = session.bodies()[0]
	var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.get_rid())
	return state.get_contact_count() if state != null else -1


func apply_flight_disturbance(actor_id: int, expected_epoch: int,
		expected_tick: int, velocity_jump: Vector2, angular_jump: float) -> Dictionary:
	# Bounded evaluator/host facility only, NOT an admitted policy action.
	# All disturbance motion occurs as a Rapier impulse during next step.
	if session == null or _finished or _paused or actor_id != 0 \
		or not session.is_flight_actor(actor_id) or session.epoch != expected_epoch \
		or session.tick != expected_tick or not velocity_jump.is_finite() \
		or not is_finite(angular_jump) or velocity_jump.length() > 24.0 \
		or absf(angular_jump) > 1.0:
		return {"accepted": false, "reason": "disturbance_admission"}
	var body: RigidBody2D = session.bodies()[0]
	var linear_impulse: Vector2 = velocity_jump * body.mass
	var angular_impulse: float = angular_jump * body.inertia
	PhysicsServer2D.body_apply_central_impulse(body.get_rid(), linear_impulse)
	PhysicsServer2D.body_apply_torque_impulse(body.get_rid(), angular_impulse)
	return {"accepted": true, "epoch": expected_epoch, "tick": expected_tick,
		"delta_velocity_cells_per_second": velocity_jump,
		"delta_angular_velocity_rad_per_second": angular_jump,
		"linear_impulse": linear_impulse, "angular_impulse": angular_impulse}


func submit(command: Variant, producer: StringName = &"policy") -> bool:
	if session == null or _finished or _paused:
		last_error = "inactive_or_paused"
		return false
	var accepted: bool = session.submit(command, producer)
	if not accepted:
		last_error = session.last_error
	return accepted


func cancel(actor_id: int, producer: StringName) -> bool:
	return session != null and session.cancel_input(actor_id, session.epoch, producer)


func set_paused(paused: bool) -> void:
	_paused = paused
	if session != null:
		session.set_suspended(paused)


func step(commands: Variant = []) -> Dictionary:
	if session == null or _finished or _paused:
		return snapshot()
	if not commands is Array or commands.size() > Session.MAX_ACTORS:
		last_error = "command_batch"
		return snapshot()
	_command_receipts.clear()
	var seen: Dictionary = {}
	for command: Variant in commands:
		if command is Dictionary and Session._integer(command.get("actor_id"), 0, 7):
			var actor: int = int(command.actor_id)
			if seen.has(actor):
				last_error = "duplicate_actor_in_batch"
				return snapshot()
			seen[actor] = true
	# A mask is copied from the current actual pose. Actuation adds forces but
	# does not integrate: usable source positions match this mask exactly.
	_world.prepare_rigid_body_coupling(session.bridge.pack_body_states(), true)
	for command: Variant in commands:
		var accepted: bool = submit(command, &"policy")
		_command_receipts.append({"accepted": accepted,
			"reason": "" if accepted else last_error})
	session.advance(1.0 / PHYSICS_HZ)
	var requests: Array = session.drain_effects()
	_effect_receipts = _effects.apply(_world, requests, session.epoch)
	_effect_requests_total += requests.size()
	for receipt: Dictionary in _effect_receipts:
		_effect_changes_total += int(receipt.changed_cells)
		_effect_refusals_total += int(receipt.status == "refused")
	var usable_requests: Array = session.drain_equipment_requests()
	var equipment_state: Dictionary = _usables.step(1.0 / PHYSICS_HZ, _world,
		session.equipment_frame(), usable_requests)
	_usable_requests_total += usable_requests.size()
	# Autonomous impacts, fuses and processor cycles can write on ticks with no
	# new request. Count the exclusive owner's complete per-tick edit total.
	_usable_changes_total += int(equipment_state.get("write_count_last", 0))
	for request: Dictionary in usable_requests:
		for receipt: Dictionary in equipment_state.get("receipts", []):
			if str(receipt.get("request_id", "")) != str(request.get("request_id", "")):
				continue
			_usable_accepted_total += int(bool(receipt.get("accepted", false)))
			_usable_refused_total += int(not bool(receipt.get("accepted", false)))
	session.accept_equipment_feedback(equipment_state)
	if not bool(_world.simulation_tick()):
		_fail("native_tick")
		return snapshot()
	_coupling_results = _world.rigid_body_results()
	session.bridge.apply_cellular_results(session.tick + 1, _coupling_results)
	_sync_terrain()
	if _failed:
		return snapshot()
	session.bridge.step()
	session.complete_step()
	for actor: Dictionary in session.snapshot().actors:
		if not str(actor.get("fault", "")).is_empty():
			_fail("actor_fault: " + str(actor.fault))
			break
	if not _failed and session.tick >= int(config.max_ticks):
		_finished = true
		_reason = "tick_limit"
		session.set_suspended(true)
	return snapshot()


func _sync_terrain() -> void:
	var revision: int = int(_world.get_hard_surface_revision())
	if revision == _terrain_revision:
		return
	var chunks: PackedInt32Array = _world.get_hard_surface_chunk_rectangles()
	if not session.bridge.queue_hard_surface_chunk_snapshot(chunks):
		_fail("terrain_snapshot")
		return
	# This small synchronous lab finishes all 256 bounded world chunks before
	# the next Rapier step. It makes no desktop frame-time budget claim.
	session.bridge.process_hard_surface_collider_budget(256, 0)
	if session.bridge.pending_hard_surface_chunks() != 0:
		_fail("terrain_capacity")
	_terrain_revision = revision


func _fail(reason: String) -> void:
	_failed = true
	_finished = true
	_reason = reason
	last_error = reason
	if session != null:
		session.set_suspended(true)


func snapshot() -> Dictionary:
	var result: Dictionary = session.snapshot() if session != null else {"tick": 0, "actors": [], "actor_count": 0, "body_count": 0}
	result.merge({"version": VERSION, "environment": "physical-manoeuvre-and-usable-lab",
		"representation": "articulated-rapier", "schedule": SCHEDULE,
		"seed": int(config.get("seed", 0)), "seed_scope": "authored material fixture layout",
		"max_ticks": int(config.get("max_ticks", 0)), "physics_hz": PHYSICS_HZ,
		"decision_ticks": Session.DECISION_TICKS, "native_workers": 1,
		"finished": _finished, "failed": _failed, "terminated": _failed,
		"truncated": _reason == "tick_limit", "reason": _reason, "paused": _paused,
		"world_tick": int(_world.get_tick_index()) if _world != null else 0,
		"command_results": _command_receipts.duplicate(true),
		"effects": _effect_receipts.duplicate(true),
		"physical_usables": _usables.snapshot(),
		"usable_totals": {"requests": _usable_requests_total, "accepted": _usable_accepted_total,
			"refused": _usable_refused_total, "changed_cells": _usable_changes_total},
		"course": str(config.get("course", "manoeuvre")),
		"flight_scenario": str(config.get("flight_scenario", "")),
		"flight_split": str(config.get("flight_split", "")),
		"course_sections": UsableCourse.sections() if config.get("course") == UsableCourse.ID else [],
		"course_fixture_result": _course_fixture_result.duplicate(true),
		"effect_totals": {"requests": _effect_requests_total, "changed_cells": _effect_changes_total, "refused": _effect_refusals_total},
		"cellular_results": _coupling_results.duplicate(),
		"cellular_sample_tick": maxi(-1, int(result.tick) - 1),
		"terrain_revision": _terrain_revision,
		"terrain_shapes": session.bridge.hard_surface_shape_count() if session != null else 0,
		"last_error": last_error, "scope": "evaluator snapshot; no competitive score or learned-policy claim"}, true)
	return result


func render_parts() -> Array:
	return session.render_parts() if session != null else []


func course_processor_fixture(actor_id: int, operation: String = "feed") -> Dictionary:
	# Explicit lab authoring, never included in a policy observation/action.
	# Ports come from the same physical body and geometry used by the worker.
	var result: Dictionary = {"accepted": false, "operation": operation, "actor_id": actor_id, "reason": "course_only"}
	if _world == null or session == null or _failed or config.get("course") != UsableCourse.ID:
		return result
	if operation not in ["feed", "jam", "clear"] or actor_id < 0 or actor_id >= session.snapshot().actor_count:
		result.reason = "invalid_fixture_request"
		return result
	var object: Dictionary = {}
	for candidate: Dictionary in _usables.snapshot().get("objects", []):
		if int(candidate.get("owner", -1)) == actor_id:
			object = candidate
			break
	if object.is_empty():
		result.reason = "deploy_and_settle_processor_first"
		_course_fixture_result = result
		return result.duplicate(true)
	var definition: Dictionary = UsableCatalog.entry(int(object.usable_index))
	var centre: Vector2 = object.position
	var reach: float = ceilf(Vector2(object.half_extents).x + 2.0)
	var angle: float = float(object.rotation)
	var input_ports: Array[Vector2i] = [Vector2i((centre + Vector2(-reach, -1).rotated(angle)).round()),
		Vector2i((centre + Vector2(-reach, 1).rotated(angle)).round())]
	var output_ports: Array[Vector2i] = [Vector2i((centre + Vector2(reach, -1).rotated(angle)).round()),
		Vector2i((centre + Vector2(reach, 1).rotated(angle)).round())]
	var writes: Array = []
	if operation == "feed":
		var materials: Array[int] = []
		for pair: Array in definition.get("inputs", []):
			for _index: int in range(int(pair[1])):
				materials.append(int(pair[0]))
		if materials.size() > input_ports.size():
			result.reason = "recipe_capacity"
			return result
		for index: int in range(materials.size()):
			writes.append({"point": input_ports[index], "material": materials[index]})
		if definition.has("catalyst_any") or str(definition.operation) == "firewarden":
			var catalyst: int = int(definition.catalyst_any[0]) if definition.has("catalyst_any") else 6
			writes.append({"point": Vector2i((centre + Vector2(0, -ceilf(Vector2(object.half_extents).y + 1.0)).rotated(angle)).round()), "material": catalyst})
	else:
		var output_count: int = 0
		for pair: Array in definition.get("outputs", []):
			output_count += int(pair[1])
		# Blocking the final required slot catches partial recipe consumption.
		var port: Vector2i = output_ports[clampi(output_count - 1, 0, output_ports.size() - 1)]
		# Industrial Brick holds the port closed until explicitly cleared. Loose
		# Stone would fall away during the same native tick as the refusal.
		writes.append({"point": port, "material": 57 if operation == "jam" else 0})
	for write: Dictionary in writes:
		var point: Vector2i = write.point
		if point.x < 0 or point.y < 0 or point.x >= 1024 or point.y >= 1024 \
			or int(_world.rigid_body_id_at(point.x, point.y)) != 0 \
			or int(_world.material_at(point.x, point.y)) == 1:
			result.reason = "fixture_port_protected"
			_course_fixture_result = result
			return result.duplicate(true)
	for write: Dictionary in writes:
		_world.emit_disc(write.point.x, write.point.y, 0, int(write.material))
	result.accepted = true
	result.reason = "fixture_applied"
	result["ports"] = writes.duplicate(true)
	result["instance_id"] = str(object.instance_id)
	_course_fixture_result = result
	return result.duplicate(true)


func presentation_snapshot(force: bool = false) -> Dictionary:
	# The playground reuses native immutable RG8 publication, avoiding a scripted
	# per-cell palette loop while its actors and materials are moving.
	return _world.take_render_snapshot(force) if _world != null else {}


func presentation_cells(view: Rect2i = ARENA_RECT) -> PackedByteArray:
	var bounded: Rect2i = view.intersection(Rect2i(0, 0, 1024, 1024))
	if _world == null or bounded.size.x < 1 or bounded.size.y < 1 or bounded.size.x > 512 or bounded.size.y > 384:
		return PackedByteArray()
	var revision: int = int(_world.get_revision())
	if bounded == _presentation_rect and (_presentation_revision == revision or session.tick - _presentation_tick < 6):
		return _presentation_cache.duplicate()
	var source: PackedByteArray = _world.get_cells()
	_presentation_cache.clear()
	_presentation_cache.resize(bounded.size.x * bounded.size.y)
	for y: int in range(bounded.size.y):
		for x: int in range(bounded.size.x):
			_presentation_cache[y * bounded.size.x + x] = source[(bounded.position.y + y) * 1024 + bounded.position.x + x]
	_presentation_tick = session.tick
	_presentation_revision = revision
	_presentation_rect = bounded
	return _presentation_cache.duplicate()


func close() -> void:
	if _world != null and not bool(_world.has_failed()):
		_world.prepare_rigid_body_coupling(PackedFloat32Array(), false)
	if session != null:
		session.close()
		session = null
	if is_instance_valid(_viewport):
		_viewport.free()
	_viewport = null
	_world = null
	_effects.reset()
	_usables.reset()
	_coupling_results.clear()
	_effect_receipts.clear()
	_command_receipts.clear()
	_presentation_cache.clear()
	_finished = true
	_reason = "closed"
	_paused = false


func _exit_tree() -> void:
	close()


static func json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_TRANSFORM2D:
			return [json_value(value.x), json_value(value.y), json_value(value.origin)]
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value:
				result[str(key)] = json_value(value[key])
			return result
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var result: Array = []
			for item: Variant in value:
				result.append(json_value(item))
			return result
		TYPE_STRING_NAME:
			return str(value)
	return value
