class_name CyberPhysicalActorArena
extends Node2D

# A distinct synchronous ACT-004 environment. The ordinary desktop worker and
# sampled Thunderbowl v1 retain their own scheduling and observation contracts.
const Session = preload("res://scripts/physical_actor_session.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Effects = preload("res://scripts/physical_actor_effects.gd")
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


func _validated_config(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() > 5:
		return {}
	for key: Variant in value:
		if str(key) not in ["version", "seed", "max_ticks", "actors", "local_patch_radius"]:
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
		var data: Dictionary = Catalog.entry(model)
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
	return {"version": VERSION, "seed": int(value.get("seed", 0)),
		"max_ticks": int(value.get("max_ticks", 600)), "actors": definitions,
		"local_patch_radius": int(value.get("local_patch_radius", 6))}


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
	for rectangle: Dictionary in layout(int(validated.seed)):
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
		"effect_totals": {"requests": _effect_requests_total, "changed_cells": _effect_changes_total, "refused": _effect_refusals_total},
		"cellular_results": _coupling_results.duplicate(),
		"cellular_sample_tick": maxi(-1, int(result.tick) - 1),
		"terrain_revision": _terrain_revision,
		"terrain_shapes": session.bridge.hard_surface_shape_count() if session != null else 0,
		"last_error": last_error, "scope": "evaluator snapshot; no competitive score or learned-policy claim"}, true)
	return result


func render_parts() -> Array:
	return session.render_parts() if session != null else []


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
