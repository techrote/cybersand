class_name CyberThunderbowlArena
extends RefCounted

# ACT-003: a single owner advances real native cells and current actor motors.
# Policies receive owned values through observation(); snapshot() is a separate
# evaluator interface. These trusted GDScript examples are not a code sandbox.
const Contract = preload("res://scripts/thunderbowl_contract.gd")
const Session = preload("res://scripts/actor_prototype_session.gd")
const Catalog = preload("res://scripts/actor_rig_catalog.gd")
const DT: float = 1.0 / 60.0
const MAX_ACTORS: int = 8
const ARENA_ORIGIN: Vector2i = Vector2i(96, 96)
const ARENA_SIZE: Vector2i = Vector2i(256, 144)
const FLOOR_Y: int = 228
const SENSOR_RADIUS: float = 64.0
const STENCIL_SIZE: int = 9
const STENCIL_CELL_STEP: int = 4
const ORACLE_SIZE: Vector2i = Vector2i(32, 18)
const MAX_SENSOR_READS: int = 8192
const MAX_TAG_READS: int = 10752
const MAX_LINE_READS: int = 192
const MAX_EVENTS: int = 128
const MAX_COMMANDS: int = 8
const MAX_MESSAGES: int = 56
const OBSERVATION_HISTORY: int = 19
const TAG_RANGE: float = 56.0
const TAG_CONE_DOT: float = 0.94
const TAG_COOLDOWN_TICKS: int = 30
const VIRTUAL_HP: int = 3
const COMMUNICATORS: Array[String] = ["local_swarm", "nca"]

var last_error: String = ""
var _world: Variant
var _session: CyberActorPrototypeSession
var _config: Dictionary = {}
var _context: Dictionary = {}
var _run_id: String = ""
var _tick: int = 0
var _finished: bool = true
var _reason: String = "not_configured"
var _failed: bool = false
var _attempted_tick: int = 0
var _layout: Array = []
var _layout_digest: String = ""
var _initial_hash: String = ""
var _final_hash: String = ""
var _initial_team_count: int = 0
var _hp: PackedInt32Array = PackedInt32Array()
var _alive: PackedByteArray = PackedByteArray()
var _rewards: PackedFloat64Array = PackedFloat64Array()
var _tags_dealt: PackedInt32Array = PackedInt32Array()
var _tags_taken: PackedInt32Array = PackedInt32Array()
var _tag_deadline: PackedInt64Array = PackedInt64Array()
var _tag_held: PackedByteArray = PackedByteArray()
var _tag_aim: PackedVector2Array = PackedVector2Array()
var _tag_pressed: PackedByteArray = PackedByteArray()
var _command_deadline: PackedInt64Array = PackedInt64Array()
var _last_sequences: PackedInt64Array = PackedInt64Array()
var _issued: Array[PackedInt64Array] = []
var _views: Array[Dictionary] = []
var _visibility: PackedInt32Array = PackedInt32Array()
var _inboxes: Array[Array] = []
var _pending: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _event_count: int = 0
var _event_head: int = 0
var _message_drops: int = 0
var _admission: Dictionary = {"accepted": 0, "rejected": 0, "reasons": []}
var _sensor_reads: int = 0
var _tag_reads: int = 0
var _sensor_reads_total: int = 0
var _sensor_total_at_step: int = 0
var _sensor_reads_last_step: int = 0
var _tag_reads_total: int = 0
var _presentation_reads_total: int = 0
var _accepted_commands: int = 0
var _rejected_commands: int = 0
var _sensor_limited: bool = false
var _tag_limited: bool = false
var _oracle_terrain: Dictionary = {}
var _render_cache: PackedByteArray = PackedByteArray()
var _render_tick: int = -1


func configure(config: Dictionary) -> bool:
	if not Contract.valid_config(config):
		last_error = "Thunderbowl config rejected by the versioned contract"
		return false
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		last_error = "Thunderbowl requires the current native extension"
		return false
	var candidate: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not candidate.diagnostic_reset({"workers": 1}):
		last_error = "Native arena setup failed"
		return false
	candidate.set_simulation_window_enabled(false)
	candidate.set_cadence_lod_enabled(false)
	var layout: Array = _make_layout(int(config.seed))
	for rectangle: Dictionary in layout:
		if not candidate.diagnostic_fill_rect(Vector2i(rectangle.x, rectangle.y),
			Vector2i(rectangle.width, rectangle.height), int(rectangle.material)):
			last_error = "Native arena geometry was refused"
			return false
	var definitions: Array = []
	var teams: Dictionary = {}
	for index: int in range(config.actors.size()):
		var definition: Dictionary = config.actors[index]
		var dimensions: Vector2 = Catalog.entry(StringName(definition.model)).body_size
		var position := Vector2(float(ARENA_ORIGIN.x + 18 + index * 31) - dimensions.x * 0.5,
			float(FLOOR_Y) - dimensions.y)
		definitions.append({"model": definition.model, "position": position,
			"producer": _producer(definition), "control_mode": definition.control_mode})
		teams[int(definition.team)] = true
	var session := Session.new()
	if not session.configure(definitions, candidate):
		last_error = "Current actor session refused arena actors"
		return false
	# Configuration is transactional: no previous owner or score changes above.
	if _session != null:
		_session.clear()
	_world = candidate
	_session = session
	_config = config.duplicate(true)
	_context = _session.snapshot()
	_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_tick = 0
	_attempted_tick = 0
	_finished = false
	_failed = false
	_reason = "running"
	last_error = ""
	_layout = layout
	_layout_digest = JSON.stringify(layout).sha256_text()
	_initial_hash = str(_world.diagnostic_snapshot(ARENA_ORIGIN, ARENA_SIZE, false).get("hash", ""))
	_final_hash = ""
	_initial_team_count = teams.size()
	var count: int = definitions.size()
	_hp.resize(count)
	_hp.fill(VIRTUAL_HP)
	_alive.resize(count)
	_alive.fill(1)
	_rewards.resize(count)
	_rewards.fill(0.0)
	_tags_dealt.resize(count)
	_tags_dealt.fill(0)
	_tags_taken.resize(count)
	_tags_taken.fill(0)
	_tag_deadline.resize(count)
	_tag_deadline.fill(0)
	_tag_held.resize(count)
	_tag_held.fill(0)
	_tag_pressed.resize(count)
	_tag_pressed.fill(0)
	_tag_aim.resize(count)
	_tag_aim.fill(Vector2.ZERO)
	_command_deadline.resize(count)
	_command_deadline.fill(-1)
	_last_sequences.resize(count)
	_last_sequences.fill(-1)
	_issued.clear()
	_inboxes.clear()
	for _index: int in range(count):
		var history := PackedInt64Array()
		history.resize(OBSERVATION_HISTORY)
		history.fill(-1)
		_issued.append(history)
		_inboxes.append([])
	_pending.clear()
	_events.clear()
	_event_count = 0
	_event_head = 0
	_message_drops = 0
	_sensor_reads_total = 0
	_sensor_total_at_step = 0
	_sensor_reads_last_step = 0
	_tag_reads_total = 0
	_presentation_reads_total = 0
	_accepted_commands = 0
	_rejected_commands = 0
	_admission = {"accepted": 0, "rejected": 0, "reasons": []}
	_render_cache.clear()
	_render_tick = -1
	_invalidate_views()
	return true


func observation(actor_id: int) -> Dictionary:
	if _session == null or _failed or actor_id < 0 or actor_id >= _hp.size():
		return {}
	_ensure_views()
	var history: PackedInt64Array = _issued[actor_id]
	history[_tick % OBSERVATION_HISTORY] = _tick
	_issued[actor_id] = history
	return _views[actor_id].duplicate(true)


func step(commands: Array) -> Dictionary:
	if _finished or _session == null:
		return snapshot()
	_admission = {"accepted": 0, "rejected": 0, "reasons": []}
	_tag_pressed.fill(0)
	_tag_reads = 0
	_tag_limited = false
	for index: int in range(_hp.size()):
		if _command_deadline[index] < _tick + 1:
			_tag_held[index] = 0
			_tag_aim[index] = Vector2.ZERO
	var seen: Dictionary = {}
	if commands.size() > MAX_COMMANDS:
		_admission.rejected = commands.size()
		_rejected_commands += commands.size()
		_admission.reasons.append("command_capacity")
	else:
		for command: Variant in commands:
			_admit(command, seen)
	# All admitted policies refer to the same completed state. There are no
	# policy callbacks while either motor or native authority is being advanced.
	_session.step(DT, _world)
	_attempted_tick = _tick + 1
	if not _advance_materials():
		_failed = true
		_finished = true
		_reason = "native_failure"
		last_error = str(_world.get_last_tick_error())
		if last_error.is_empty():
			last_error = "Native arena step failed"
		_session.set_suspended(true)
		_pending.clear()
		_tag_held.fill(0)
		# Keep the last completed actor/context and reward generation, matching
		# the desktop failed-world quarantine rather than publishing half a tick.
		return snapshot()
	_tick += 1
	_context = _session.snapshot()
	_invalidate_views()
	_resolve_ring_outs()
	_resolve_tags()
	_deliver_messages()
	_sensor_reads_last_step = _sensor_reads_total - _sensor_total_at_step
	_sensor_total_at_step = _sensor_reads_total
	var teams: Dictionary = {}
	for index: int in range(_hp.size()):
		if _alive[index] != 0:
			teams[int(_config.actors[index].team)] = true
	if teams.is_empty():
		_finish("all_eliminated")
	elif _initial_team_count > 1 and teams.size() == 1:
		_finish("last_team_standing")
	elif _tick >= int(_config.max_ticks):
		_finish("tick_limit")
	return snapshot()


func snapshot() -> Dictionary:
	# Explicit evaluator privilege. Never hand this dictionary to a local policy.
	return {
		"version": 1, "scope": "native rigs with arena-only virtual tag combat",
		"run_id": _run_id, "tick": _tick, "attempted_tick": _attempted_tick,
		"finished": _finished, "reason": _reason, "failed": _failed, "error": last_error,
		"seed": int(_config.get("seed", 0)), "evaluation": str(_config.get("evaluation", "mechanics")),
		"layout": str(_config.get("layout", "")), "layout_digest": _layout_digest,
		"initial_material_hash": _initial_hash, "final_material_hash": _final_hash,
		"arena": {"origin": [ARENA_ORIGIN.x, ARENA_ORIGIN.y], "size": [ARENA_SIZE.x, ARENA_SIZE.y]},
		"actors": _config.get("actors", []).duplicate(true), "actor_prototypes": _context.duplicate(true),
		"hp": _hp.duplicate(), "alive": _alive.duplicate(), "rewards": _rewards.duplicate(),
		"tags_dealt": _tags_dealt.duplicate(), "tags_taken": _tags_taken.duplicate(),
		"events": _ordered_events(), "event_count": _event_count,
		"dropped_events": maxi(0, _event_count - MAX_EVENTS), "dropped_messages": _message_drops,
		"admission": _admission.duplicate(true),
		"admission_totals": {"accepted": _accepted_commands, "rejected": _rejected_commands},
		"work": {"sensor_reads": _sensor_reads, "sensor_limit": MAX_SENSOR_READS,
			"sensor_reads_last_step": _sensor_reads_last_step, "sensor_reads_total": _sensor_reads_total,
			"tag_reads_total": _tag_reads_total, "presentation_reads_total": _presentation_reads_total,
			"sensor_limited": _sensor_limited, "tag_reads": _tag_reads, "tag_limit": MAX_TAG_READS,
			"tag_limited": _tag_limited, "motor_collision_queries": int(_context.get("query_count_last", 0)),
			"motor_ray_queries": int(_context.get("ray_query_count_last", 0)),
			"motor_effect_reads": int(_context.get("effect_read_count_last", 0)),
			"motor_edited_cells": int(_context.get("edited_cell_count_last", 0))},
		"rules": {"virtual_hp": VIRTUAL_HP, "tag_range": TAG_RANGE, "tag_cone_dot": TAG_CONE_DOT,
			"tag_cooldown_ticks": TAG_COOLDOWN_TICKS, "tag_requires_rising_edge": true,
			"damage_reward": 1.0, "elimination_reward_shared": 2.0,
			"no_physical_actor_damage_or_removal": true, "workers": 1, "hz": 60},
	}


func close() -> void:
	if _session != null:
		_session.clear()
	_session = null
	_world = null
	_finished = true
	_reason = "closed"
	_pending.clear()
	_views.clear()
	_inboxes.clear()
	_render_cache.clear()


func presentation_cells() -> PackedByteArray:
	# Optional presentation-only, owned 256x144 material image. It is sampled at
	# most once per six completed ticks and is never included in policy views.
	# The fixed 36,864 reads are explicit and absent from headless decision work.
	if _world == null or _failed:
		return _render_cache.duplicate()
	if _render_tick >= 0 and _tick - _render_tick < 6:
		return _render_cache.duplicate()
	_render_cache.resize(ARENA_SIZE.x * ARENA_SIZE.y)
	for y: int in range(ARENA_SIZE.y):
		for x: int in range(ARENA_SIZE.x):
			_render_cache[y * ARENA_SIZE.x + x] = int(_world.material_at(ARENA_ORIGIN.x + x, ARENA_ORIGIN.y + y))
	_render_tick = _tick
	_presentation_reads_total += ARENA_SIZE.x * ARENA_SIZE.y
	return _render_cache.duplicate()


func _advance_materials() -> bool:
	return bool(_world.simulation_tick())


static func _producer(definition: Dictionary) -> StringName:
	return &"human" if str(definition.controller).begins_with("human_") else &"policy"


static func _make_layout(seed: int) -> Array:
	var result: Array = [
		{"x": 96, "y": 96, "width": 4, "height": 144, "material": 1},
		{"x": 348, "y": 96, "width": 4, "height": 144, "material": 1},
		{"x": 96, "y": FLOOR_Y + 8, "width": 256, "height": 4, "material": 1},
		{"x": 100, "y": FLOOR_Y, "width": 248, "height": 8, "material": 56},
		{"x": 108, "y": 104, "width": 62, "height": 4, "material": 1},
		{"x": 278, "y": 104, "width": 62, "height": 4, "material": 1},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index: int in range(7):
		var height: int = rng.randi_range(3, 8)
		result.append({"x": 127 + index * 31, "y": FLOOR_Y - height,
			"width": 5, "height": height, "material": 56})
	for index: int in range(3):
		result.append({"x": 132 + index * 66 + rng.randi_range(-5, 5),
			"y": 170 + rng.randi_range(-12, 8), "width": 24, "height": 4, "material": 1})
	return result


func _admit(value: Variant, seen: Dictionary) -> void:
	if not value is Dictionary or not Contract.valid_command(value):
		_reject("command_schema")
		return
	var command: Dictionary = value
	var actor_id: int = int(command.actor_id)
	if actor_id < 0 or actor_id >= _hp.size() or _alive[actor_id] == 0:
		_reject("actor_unavailable")
		return
	if seen.has(actor_id):
		_reject("duplicate_actor")
		return
	var definition: Dictionary = _config.actors[actor_id]
	var observed: int = int(command.observed_tick)
	if command.run_id != _run_id or int(command.epoch) != int(_context.epoch):
		_reject("run_or_epoch")
		return
	if observed < 0 or observed > _tick or observed < _tick - 18 \
		or observed + int(command.lease_ticks) <= _tick:
		_reject("observation_expired")
		return
	if _issued[actor_id][observed % OBSERVATION_HISTORY] != observed \
		or str(command.observation_id) != _observation_id(actor_id, observed):
		_reject("observation_not_issued")
		return
	if int(command.sequence) <= _last_sequences[actor_id]:
		_reject("sequence")
		return
	var metal: bool = definition.control_mode == "metal"
	if (command.kind == "actuator_action") != metal:
		_reject("control_mode")
		return
	if not command.message.is_empty() and (str(definition.controller) not in COMMUNICATORS \
		or definition.observation_mode == "self"):
		_reject("message_privilege")
		return
	if (command.message_type == "goal_hint" and definition.controller != "local_swarm") \
		or (command.message_type == "latent_state" and definition.controller != "nca"):
		_reject("message_type_privilege")
		return
	var producer: StringName = _producer(definition)
	if bool(command.cancel):
		_session.cancel_input(actor_id, int(command.epoch), producer)
	var action: Dictionary = command.action
	var admitted: bool
	if metal:
		var values: Array = action.actuators
		admitted = _session.submit_actuator_action(actor_id, int(command.epoch), int(command.sequence),
			observed, Vector4(values[0], values[1], values[2], values[3]), int(command.lease_ticks), producer)
	else:
		admitted = _session.submit_rig_action(actor_id, int(command.epoch), int(command.sequence), observed,
			Vector2(action.movement[0], action.movement[1]), Vector2(action.aim[0], action.aim[1]),
			float(action.effort), float(action.trim), float(action.reel), bool(action.primary),
			bool(action.secondary), bool(action.auxiliary), int(command.lease_ticks), producer)
	if not admitted:
		_reject("session_refused")
		return
	seen[actor_id] = true
	_last_sequences[actor_id] = int(command.sequence)
	_command_deadline[actor_id] = observed + int(command.lease_ticks)
	if bool(command.cancel):
		_tag_held[actor_id] = 0
		_tag_pressed[actor_id] = 0
		_tag_aim[actor_id] = Vector2.ZERO
	else:
		_tag_pressed[actor_id] = int(bool(command.tag) and _tag_held[actor_id] == 0)
		_tag_held[actor_id] = int(bool(command.tag))
		var aim: Array = action.tag_aim if metal else action.aim
		_tag_aim[actor_id] = _unit(Vector2(aim[0], aim[1]))
	if not command.message.is_empty():
		_pending.append({"sender": actor_id, "kind": command.message_type, "payload": command.message.duplicate(),
			"sent_tick": _tick, "expires_tick": _command_deadline[actor_id]})
	_admission.accepted += 1
	_accepted_commands += 1


func _reject(reason: String) -> void:
	_admission.rejected += 1
	_rejected_commands += 1
	if _admission.reasons.size() < MAX_COMMANDS:
		_admission.reasons.append(reason)


func _observation_id(actor_id: int, observed: int) -> String:
	return "%s:%d:%d:%d" % [_run_id, int(_context.epoch), observed, actor_id]


func _invalidate_views() -> void:
	_views.clear()
	_visibility.resize(_hp.size() * _hp.size())
	_visibility.fill(-1)
	_sensor_reads = 0
	_sensor_limited = false
	_oracle_terrain.clear()


func _state(actor_id: int) -> PackedFloat32Array:
	return _context.get("rig_states", PackedFloat32Array()).slice(actor_id * 40, (actor_id + 1) * 40)


func _centre(actor_id: int) -> Vector2:
	var offset: int = actor_id * 40
	var states: PackedFloat32Array = _context.rig_states
	return Vector2(states[offset] + states[offset + 35] * 0.5, states[offset + 1] + states[offset + 36] * 0.5)


func _ensure_views() -> void:
	if not _views.is_empty():
		return
	for actor_id: int in range(_hp.size()):
		var definition: Dictionary = _config.actors[actor_id]
		var centre: Vector2 = _centre(actor_id)
		var origin: Vector2i = Vector2i(centre.floor()) - Vector2i(16, 16)
		var stencil: Array[int] = []
		stencil.resize(STENCIL_SIZE * STENCIL_SIZE)
		for y: int in range(STENCIL_SIZE):
			for x: int in range(STENCIL_SIZE):
				stencil[y * STENCIL_SIZE + x] = _cell(origin + Vector2i(x, y) * STENCIL_CELL_STEP, false)
		var neighbors: Array = []
		if definition.observation_mode != "self" and _alive[actor_id] != 0:
			for other: int in range(_hp.size()):
				if other == actor_id or _alive[other] == 0 or not _pair_visible(actor_id, other):
					continue
				var other_state: PackedFloat32Array = _state(other)
				var relative: Vector2 = _centre(other) - centre
				neighbors.append({"actor_id": other, "team": int(_config.actors[other].team),
					"relative_position": [relative.x, relative.y], "velocity": [other_state[2], other_state[3]],
					"body_size": [other_state[35], other_state[36]], "rotation": other_state[16]})
		var actuation: Array = []
		actuation.resize(32)
		actuation.fill(0.0)
		var actuation_states: PackedFloat32Array = _context.get("actuation_states", PackedFloat32Array())
		if actuation_states.size() >= (actor_id + 1) * 32:
			actuation = Array(actuation_states.slice(actor_id * 32, (actor_id + 1) * 32))
		var profiles: Array = _context.get("actuation_profiles", [])
		var view: Dictionary = {
			"version": 1, "run_id": _run_id, "actor_id": actor_id, "epoch": int(_context.epoch),
			"tick": _tick, "observation_id": _observation_id(actor_id, _tick),
			"observation_mode": definition.observation_mode, "control_mode": definition.control_mode,
			"model": definition.model, "team": int(definition.team), "alive": _alive[actor_id] != 0,
			"self_state": Array(_state(actor_id)), "self_hp": _hp[actor_id],
			"tag_ready": _alive[actor_id] != 0 and _tick + 1 >= _tag_deadline[actor_id],
			"actuation_state": actuation, "actuation_profile": str(profiles[actor_id]) if profiles.size() > actor_id else "",
			"terrain": {"origin": [origin.x, origin.y], "size": [STENCIL_SIZE, STENCIL_SIZE],
				"cell_step": STENCIL_CELL_STEP, "cells": stencil},
			"neighbors": neighbors, "messages": _visible_messages(actor_id),
		}
		if definition.observation_mode == "oracle":
			view["oracle"] = {"actors": _oracle_actors(), "terrain": _global_terrain().duplicate(true)}
		_views.append(view)


func _oracle_actors() -> Array:
	var result: Array = []
	for index: int in range(_hp.size()):
		result.append({"actor_id": index, "model": _config.actors[index].model,
			"team": int(_config.actors[index].team), "alive": _alive[index] != 0,
			"hp": _hp[index], "state": Array(_state(index))})
	return result


func _global_terrain() -> Dictionary:
	if not _oracle_terrain.is_empty():
		return _oracle_terrain
	var cells: Array[int] = []
	cells.resize(ORACLE_SIZE.x * ORACLE_SIZE.y)
	for y: int in range(ORACLE_SIZE.y):
		for x: int in range(ORACLE_SIZE.x):
			cells[y * ORACLE_SIZE.x + x] = _cell(ARENA_ORIGIN + Vector2i(x * 8 + 4, y * 8 + 4), false)
	_oracle_terrain = {"origin": [ARENA_ORIGIN.x, ARENA_ORIGIN.y],
		"size": [ORACLE_SIZE.x, ORACLE_SIZE.y], "cell_spacing": 8, "sample_offset": [4, 4], "cells": cells}
	return _oracle_terrain


func _pair_visible(first: int, second: int) -> bool:
	var offset: int = first * _hp.size() + second
	if _visibility[offset] >= 0:
		return _visibility[offset] != 0
	var a: Vector2 = _centre(first)
	var b: Vector2 = _centre(second)
	var visible: bool = a.distance_squared_to(b) <= SENSOR_RADIUS * SENSOR_RADIUS \
		and _line_clear(a, b, false)
	_visibility[offset] = int(visible)
	_visibility[second * _hp.size() + first] = int(visible)
	return visible


func _cell(point: Vector2i, tag_lane: bool) -> int:
	if tag_lane:
		if _tag_reads >= MAX_TAG_READS:
			_tag_limited = true
			return 1
		_tag_reads += 1
		_tag_reads_total += 1
	else:
		if _sensor_reads >= MAX_SENSOR_READS:
			_sensor_limited = true
			return 1
		_sensor_reads += 1
		_sensor_reads_total += 1
	if point.x < 0 or point.y < 0 or point.x >= 1024 or point.y >= 1024:
		return 1
	return int(_world.material_at(point.x, point.y))


func _line_clear(start: Vector2, finish: Vector2, tag_lane: bool) -> bool:
	# Bounded supercover; a diagonal may not see/tag through a one-cell corner.
	if not start.is_finite() or not finish.is_finite():
		return false
	var delta: Vector2 = finish - start
	var steps: int = maxi(1, ceili(maxf(absf(delta.x), absf(delta.y))))
	if steps > 64:
		return false
	var previous: Vector2i = Vector2i(start.floor())
	var reads: int = 1
	if _cell(previous, tag_lane) != 0:
		return false
	for index: int in range(1, steps + 1):
		var current: Vector2i = Vector2i((start + delta * (float(index) / float(steps))).floor())
		if current == previous:
			continue
		if current.x != previous.x and current.y != previous.y:
			reads += 2
			if reads >= MAX_LINE_READS or _cell(Vector2i(current.x, previous.y), tag_lane) != 0 \
				or _cell(Vector2i(previous.x, current.y), tag_lane) != 0:
				return false
		reads += 1
		if reads > MAX_LINE_READS or _cell(current, tag_lane) != 0:
			return false
		previous = current
	return true


static func _unit(value: Vector2) -> Vector2:
	if value == Vector2.ZERO or not value.is_finite():
		return Vector2.ZERO
	return (value / maxf(absf(value.x), absf(value.y))).normalized()


func _resolve_ring_outs() -> void:
	var bounds := Rect2(Vector2(ARENA_ORIGIN), Vector2(ARENA_SIZE))
	for index: int in range(_hp.size()):
		if _alive[index] != 0 and not bounds.has_point(_centre(index)):
			_hp[index] = 0
			_rewards[index] -= 2.0
			_eliminate(index)
			_event({"type": "ring_out", "actor_id": index})


func _resolve_tags() -> void:
	var hits: Array[Dictionary] = []
	var attackers: Array[Array] = []
	for _index: int in range(_hp.size()):
		attackers.append([])
	for shooter: int in range(_hp.size()):
		if _alive[shooter] == 0 or _tag_pressed[shooter] == 0 \
			or _tick < _tag_deadline[shooter] or _tag_aim[shooter] == Vector2.ZERO:
			continue
		_tag_deadline[shooter] = _tick + TAG_COOLDOWN_TICKS
		var target: int = -1
		var nearest: float = TAG_RANGE + 1.0
		for other: int in range(_hp.size()):
			if other == shooter or _alive[other] == 0 \
				or int(_config.actors[other].team) == int(_config.actors[shooter].team):
				continue
			var relative: Vector2 = _centre(other) - _centre(shooter)
			var distance: float = relative.length()
			if distance <= 0.001 or distance > TAG_RANGE or distance >= nearest \
				or _tag_aim[shooter].dot(relative / distance) < TAG_CONE_DOT:
				continue
			if _line_clear(_centre(shooter), _centre(other), true):
				nearest = distance
				target = other
		if target < 0:
			_event({"type": "tag_miss", "actor_id": shooter})
		else:
			hits.append({"shooter": shooter, "target": target})
			attackers[target].append(shooter)
	# Resolve simultaneous valid shots before eliminating anyone. Overkill is
	# counted as tag hits; HP is clamped, and a single kill bonus is shared.
	for hit: Dictionary in hits:
		var shooter: int = hit.shooter
		var target: int = hit.target
		_tags_dealt[shooter] += 1
		_tags_taken[target] += 1
		_rewards[shooter] += 1.0
		_rewards[target] -= 1.0
		_event({"type": "tag", "actor_id": shooter, "target_id": target})
	for target: int in range(_hp.size()):
		if attackers[target].is_empty():
			continue
		_hp[target] = maxi(0, _hp[target] - attackers[target].size())
		if _hp[target] > 0:
			continue
		_rewards[target] -= 2.0
		for shooter: int in attackers[target]:
			_rewards[shooter] += 2.0 / float(attackers[target].size())
		_eliminate(target)
		_event({"type": "eliminated", "actor_id": target, "contributors": attackers[target].duplicate()})


func _eliminate(actor_id: int) -> void:
	_alive[actor_id] = 0
	_tag_held[actor_id] = 0
	_tag_pressed[actor_id] = 0
	_tag_aim[actor_id] = Vector2.ZERO
	_session.cancel_input(actor_id, int(_context.epoch), _producer(_config.actors[actor_id]))
	_inboxes[actor_id].clear()


func _deliver_messages() -> void:
	for receiver: int in range(_hp.size()):
		var retained: Array = []
		for message: Dictionary in _inboxes[receiver]:
			if int(message.expires_tick) >= _tick and _can_message(int(message.sender), receiver):
				retained.append(message)
		for message: Dictionary in _pending:
			if int(message.expires_tick) < _tick or not _can_message(int(message.sender), receiver):
				continue
			for index: int in range(retained.size() - 1, -1, -1):
				if retained[index].sender == message.sender:
					retained.remove_at(index)
			if retained.size() < MAX_ACTORS - 1:
				retained.append(message.duplicate(true))
			else:
				_message_drops += 1
		retained.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.sender) < int(b.sender))
		_inboxes[receiver] = retained
	_pending.clear()


func _can_message(sender: int, receiver: int) -> bool:
	if sender == receiver or _alive[sender] == 0 or _alive[receiver] == 0:
		return false
	var from: Dictionary = _config.actors[sender]
	var to: Dictionary = _config.actors[receiver]
	return str(to.controller) in COMMUNICATORS and to.observation_mode != "self" \
		and int(from.team) == int(to.team) and _pair_visible(sender, receiver)


func _visible_messages(actor_id: int) -> Array:
	if _config.actors[actor_id].observation_mode == "self" \
		or str(_config.actors[actor_id].controller) not in COMMUNICATORS:
		return []
	return _inboxes[actor_id].duplicate(true)


func _event(event: Dictionary) -> void:
	event["tick"] = _tick
	event["id"] = _event_count
	_event_count += 1
	if _events.size() < MAX_EVENTS:
		_events.append(event)
	else:
		_events[_event_head] = event
		_event_head = (_event_head + 1) % MAX_EVENTS


func _ordered_events() -> Array:
	var result: Array = []
	for index: int in range(_events.size()):
		result.append(_events[(_event_head + index) % _events.size()].duplicate(true))
	return result


func _finish(reason: String) -> void:
	_finished = true
	_reason = reason
	_session.set_suspended(true)
	_context = _session.snapshot()
	_pending.clear()
	_tag_held.fill(0)
	_views.clear()
	_final_hash = str(_world.diagnostic_snapshot(ARENA_ORIGIN, ARENA_SIZE, false).get("hash", ""))
