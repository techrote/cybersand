class_name CyberActorPrototypeSession
extends RefCounted

# ACT-001/002: only the simulation owner may configure, advance or observe motors.
# Producers may submit/cancel copied scalar actions through the bounded mailbox.
# No producer is allowed to retain the World or an actor reference.
const Prototype = preload("res://scripts/actor_prototype.gd")
const RigMotor = preload("res://scripts/actor_rig_motor.gd")
const RigCatalog = preload("res://scripts/actor_rig_catalog.gd")
const Actuation = preload("res://scripts/actor_rig_actuation.gd")
const MAX_ACTORS: int = 8
const MAX_LEASE_TICKS: int = 18
const DEFAULT_LEASE_TICKS: int = 12
const OBSERVATION_STRIDE: int = 16
const RIG_OBSERVATION_STRIDE: int = 40
const ACTION_STRIDE: int = 10
const ACTUATION_STRIDE: int = 32
const DEMO_INTERVAL_TICKS: int = 6
const MODEL_IDS: Array[StringName] = [&"runner", &"skimmer", &"crawler"]
const RIG_IDS: Array[StringName] = RigCatalog.RIG_IDS
const PRODUCERS: Array[StringName] = [&"human", &"policy", &"demo"]
const PRIMARY_HELD: int = 1
const SECONDARY_HELD: int = 2
const PRIMARY_PRESSED: int = 4
const SECONDARY_PRESSED: int = 8
const CANCEL: int = 16
const AUXILIARY_HELD: int = 32
const AUXILIARY_PRESSED: int = 64

class ActionSlot:
	extends RefCounted
	var movement: Vector2 = Vector2.ZERO
	var aim: Vector2 = Vector2.ZERO
	var effort: float = 0.7
	var trim: float = 0.0
	var reel: float = 0.0
	var primary: bool = false
	var secondary: bool = false
	var auxiliary: bool = false
	var primary_pressed: bool = false
	var secondary_pressed: bool = false
	var auxiliary_pressed: bool = false
	var cancel_pending: bool = false
	var sequence: int = -1
	var deadline: int = -1
	var producer: StringName = &"policy"
	var control_mode: StringName = &"wire"
	var model: StringName = &"runner"
	var actuators: Vector4 = Vector4.ZERO
	var was_live: bool = false

	func neutralize() -> void:
		actuators = Vector4.ZERO
		movement = Vector2.ZERO
		aim = Vector2.ZERO
		effort = 0.0
		trim = 0.0
		reel = 0.0
		primary = false
		secondary = false
		auxiliary = false
		primary_pressed = false
		secondary_pressed = false
		auxiliary_pressed = false
		deadline = -1
		was_live = false
		cancel_pending = true

var _mutex: Mutex = Mutex.new()
var _slots: Array[ActionSlot] = []
var _actors: Array[CyberActorPrototype] = []
var _moves: PackedVector2Array = PackedVector2Array()
var _aims: PackedVector2Array = PackedVector2Array()
var _efforts: PackedFloat32Array = PackedFloat32Array()
var _trims: PackedFloat32Array = PackedFloat32Array()
var _reels: PackedFloat32Array = PackedFloat32Array()
var _flags: PackedInt32Array = PackedInt32Array()
var _applied_actions: PackedFloat32Array = PackedFloat32Array()
var _applied_sequences: PackedInt64Array = PackedInt64Array()
var _homes: PackedVector2Array = PackedVector2Array()
var _directions: PackedFloat32Array = PackedFloat32Array()
var _demo_sequences: PackedInt64Array = PackedInt64Array()
var _models: Array[StringName] = []
var _producers: Array[StringName] = []
var _capabilities: Array[Dictionary] = []
var _rig_capabilities: Array[Dictionary] = []
var _rig_sets: Array[StringName] = []
var _control_modes: Array[StringName] = []
var _actuation_profiles: Array[String] = []
var _actuation_capabilities: Array[Dictionary] = []
var _actuators: Array[Vector4] = []
var _epoch: int = 0
var _tick: int = 0
var _count: int = 0 # Mailbox count; guarded together with epoch/tick/suspension.
var _suspended: bool = false
var query_count_last: int = 0
var ray_query_count_last: int = 0
var effect_read_count_last: int = 0
var edited_cell_count_last: int = 0


func _init() -> void:
	_moves.resize(MAX_ACTORS)
	_aims.resize(MAX_ACTORS)
	_efforts.resize(MAX_ACTORS)
	_trims.resize(MAX_ACTORS)
	_reels.resize(MAX_ACTORS)
	_flags.resize(MAX_ACTORS)
	_applied_actions.resize(MAX_ACTORS * ACTION_STRIDE)
	_applied_sequences.resize(MAX_ACTORS)
	_applied_sequences.fill(-1)
	_homes.resize(MAX_ACTORS)
	_directions.resize(MAX_ACTORS)
	_demo_sequences.resize(MAX_ACTORS)
	for _index: int in range(MAX_ACTORS):
		_slots.append(ActionSlot.new())
		_actuators.append(Vector4.ZERO)


static func valid_definitions(definitions: Array) -> bool:
	if definitions.size() > MAX_ACTORS:
		return false
	for definition in definitions:
		if not definition is Dictionary:
			return false
		var model_value = definition.get("model", "")
		var producer_value = definition.get("producer", "policy")
		if not (model_value is String or model_value is StringName):
			return false
		if not (producer_value is String or producer_value is StringName):
			return false
		var model_id: StringName = StringName(model_value)
		if not RigCatalog.has_rig(model_id):
			return false
		if not PRODUCERS.has(StringName(producer_value)):
			return false
		var mode_value = definition.get("control_mode", "wire")
		if not (mode_value is String or mode_value is StringName):
			return false
		if not ["wire", "metal"].has(String(mode_value)):
			return false
		if String(mode_value) == "metal" and (
			not Actuation.supports_model(model_id) or String(producer_value) == "demo"
		):
			return false
		var spawn = definition.get("position", null)
		if not spawn is Vector2 or not spawn.is_finite():
			return false
		# Prototype spawns belong to the existing finite demo world.
		if spawn.x < 0.0 or spawn.y < 0.0:
			return false
		var body: Vector2 = RigCatalog.entry(model_id).get("body_size", CyberSampledCharacter.BODY_SIZE)
		if spawn.x > CyberCellWorld.WORLD_WIDTH - body.x:
			return false
		if spawn.y > CyberCellWorld.WORLD_HEIGHT - body.y:
			return false
	return true


func identity_epoch() -> int:
	_mutex.lock()
	var value: int = _epoch
	_mutex.unlock()
	return value

func configure(definitions: Array, world, epoch_floor: int = -1) -> bool:
	# A privately staged replacement must retire the previous session identity,
	# even when this fresh object has never configured actors before.
	if epoch_floor == 9223372036854775807 or not valid_definitions(definitions):
		return false
	var candidates: Array[CyberActorPrototype] = []
	var capabilities: Array[Dictionary] = []
	var rig_capabilities: Array[Dictionary] = []
	var rig_sets: Array[StringName] = []
	var models: Array[StringName] = []
	var producers: Array[StringName] = []
	var control_modes: Array[StringName] = []
	var actuation_profiles: Array[String] = []
	var actuation_capabilities: Array[Dictionary] = []
	for definition: Dictionary in definitions:
		var model_id: StringName = StringName(definition.model)
		var actor: CyberActorPrototype = Prototype.new() if MODEL_IDS.has(model_id) else RigMotor.new()
		if not actor.configure_model(model_id):
			return false
		actor.reset(definition.position)
		# The only automatic repair is this explicit, bounded spawn operation.
		actor.recover_invalid_spawn(world)
		candidates.append(actor)
		capabilities.append(actor.capabilities())
		var rig_info: Dictionary = RigCatalog.entry(model_id)
		var rig_body: Vector2 = rig_info.get("body_size", CyberSampledCharacter.BODY_SIZE)
		var rig_color: Color = rig_info.get("color", Color.WHITE)
		rig_info["body_size"] = [rig_body.x, rig_body.y]
		rig_info["color"] = [rig_color.r, rig_color.g, rig_color.b, rig_color.a]
		rig_info["motor"] = actor.capabilities()
		rig_capabilities.append(rig_info)
		rig_sets.append(RigCatalog.set_for(model_id))
		models.append(model_id)
		producers.append(StringName(str(definition.get("producer", "policy"))))
		var control_mode: StringName = StringName(str(definition.get("control_mode", "wire")))
		control_modes.append(control_mode)
		actuation_profiles.append(String(Actuation.profile_id_for(model_id)) if control_mode == &"metal" else "")
		actuation_capabilities.append(Actuation.profile(model_id) if control_mode == &"metal" else {})
	_actors = candidates
	_models = models
	_producers = producers
	_capabilities = capabilities
	_rig_capabilities = rig_capabilities
	_rig_sets = rig_sets
	_control_modes = control_modes
	_actuation_profiles = actuation_profiles
	_actuation_capabilities = actuation_capabilities
	_mutex.lock()
	_epoch = maxi(_epoch + 1, epoch_floor + 1)
	_tick = 0
	_count = _actors.size()
	_suspended = false
	for index: int in range(MAX_ACTORS):
		_slots[index].neutralize()
		_slots[index].sequence = -1
		_applied_sequences[index] = -1
		_demo_sequences[index] = 0
		if index < _count:
			_slots[index].producer = _producers[index]
			_slots[index].control_mode = _control_modes[index]
			_slots[index].model = _models[index]
			_homes[index] = _actors[index].position
			_directions[index] = 1.0 if index % 2 == 0 else -1.0
	_mutex.unlock()
	_applied_actions.fill(0.0)
	_flags.fill(CANCEL)
	query_count_last = 0
	ray_query_count_last = 0
	effect_read_count_last = 0
	edited_cell_count_last = 0
	return true


func clear() -> void:
	# Owner-only; invalidates late actions even when slot IDs are reused later.
	_actors.clear()
	_models.clear()
	_producers.clear()
	_capabilities.clear()
	_rig_capabilities.clear()
	_rig_sets.clear()
	_control_modes.clear()
	_actuation_profiles.clear()
	_actuation_capabilities.clear()
	_mutex.lock()
	_epoch += 1
	_tick = 0
	_count = 0
	_suspended = false
	for slot: ActionSlot in _slots:
		slot.neutralize()
		slot.sequence = -1
	_mutex.unlock()
	_applied_actions.fill(0.0)
	_applied_sequences.fill(-1)
	_flags.fill(CANCEL)
	query_count_last = 0
	ray_query_count_last = 0
	effect_read_count_last = 0
	edited_cell_count_last = 0


func active() -> bool:
	return not _actors.is_empty() # Owner-only.


func player() -> CyberActorPrototype:
	return _actors[0] if active() else null # Owner-only.


func submit_action(
	actor_id: int,
	epoch: int,
	sequence: int,
	observed_tick: int,
	movement: Vector2,
	primary: bool,
	secondary: bool,
	lease_ticks: int = DEFAULT_LEASE_TICKS,
	producer: StringName = &"policy"
) -> bool:
	# The original two-button path remains exact for setA. New rigs also have a
	# useful minimal adapter; independent parametric axes belong to the v2 path.
	return submit_rig_action(actor_id, epoch, sequence, observed_tick, movement,
		movement, 0.7, 0.0, 0.0, primary, secondary, false, lease_ticks, producer)


func submit_rig_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	movement: Vector2, aim: Vector2, effort: float, trim: float, reel: float,
	primary: bool, secondary: bool, auxiliary: bool,
	lease_ticks: int = DEFAULT_LEASE_TICKS, producer: StringName = &"policy"
) -> bool:
	if (
		not movement.is_finite() or not aim.is_finite() or not is_finite(effort)
		or not is_finite(trim) or not is_finite(reel) or sequence < 0
	):
		return false
	if lease_ticks < 1 or lease_ticks > MAX_LEASE_TICKS:
		return false
	# Clamp before actuator normalization so very large finite outputs stay finite.
	# Each rig decides how movement axes affect its actuators.
	var normalized: Vector2 = Vector2(
		clampf(movement.x, -1.0, 1.0), clampf(movement.y, -1.0, 1.0)
	)
	var aim_value: Vector2 = Vector2(clampf(aim.x, -1.0, 1.0), clampf(aim.y, -1.0, 1.0))
	if aim_value != Vector2.ZERO:
		# Scale before normalization so a tiny nonzero policy vector keeps its
		# direction instead of underflowing to a zero/facing-default command.
		aim_value = (aim_value / maxf(absf(aim_value.x), absf(aim_value.y))).normalized()
	_mutex.lock()
	if (
		_suspended or epoch != _epoch or actor_id < 0 or actor_id >= _count
		or observed_tick < 0 or observed_tick > _tick
		or observed_tick < _tick - MAX_LEASE_TICKS
		or observed_tick + lease_ticks <= _tick
	):
		_mutex.unlock()
		return false
	var slot: ActionSlot = _slots[actor_id]
	if sequence <= slot.sequence or producer != slot.producer or slot.control_mode != &"wire":
		_mutex.unlock()
		return false
	# Preserve a brief press/release between ticks. Multiple rises coalesce to one
	# bounded press per action per tick; held state always uses the newest packet.
	slot.primary_pressed = slot.primary_pressed or (primary and not slot.primary)
	slot.secondary_pressed = slot.secondary_pressed or (secondary and not slot.secondary)
	slot.auxiliary_pressed = slot.auxiliary_pressed or (auxiliary and not slot.auxiliary)
	slot.movement = normalized
	slot.aim = aim_value
	slot.effort = clampf(effort, 0.0, 1.0)
	slot.trim = clampf(trim, -1.0, 1.0)
	slot.reel = clampf(reel, -1.0, 1.0)
	slot.primary = primary
	slot.secondary = secondary
	slot.auxiliary = auxiliary
	slot.sequence = sequence
	slot.deadline = observed_tick + lease_ticks
	_mutex.unlock()
	return true


func submit_actuator_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	actuators: Vector4, lease_ticks: int = DEFAULT_LEASE_TICKS,
	producer: StringName = &"policy"
) -> bool:
	# ACT-003: direct held actuator values use the same bounded identity/lease
	# envelope, but never pass through the intent motor or its button edges.
	if not actuators.is_finite() or sequence < 0 or lease_ticks < 1 or lease_ticks > MAX_LEASE_TICKS:
		return false
	_mutex.lock()
	if (
		_suspended or epoch != _epoch or actor_id < 0 or actor_id >= _count
		or observed_tick < 0 or observed_tick > _tick
		or observed_tick < _tick - MAX_LEASE_TICKS
		or observed_tick + lease_ticks <= _tick
	):
		_mutex.unlock()
		return false
	var slot: ActionSlot = _slots[actor_id]
	if sequence <= slot.sequence or producer != slot.producer or slot.control_mode != &"metal" \
		or not Actuation.valid_command(slot.model, actuators):
		_mutex.unlock()
		return false
	slot.actuators = Actuation.clamp_command(slot.model, actuators)
	slot.sequence = sequence
	slot.deadline = observed_tick + lease_ticks
	_mutex.unlock()
	return true


func cancel_input(actor_id: int, epoch: int, producer: StringName) -> bool:
	_mutex.lock()
	if epoch != _epoch or actor_id < 0 or actor_id >= _count:
		_mutex.unlock()
		return false
	var slot: ActionSlot = _slots[actor_id]
	if slot.producer != producer:
		_mutex.unlock()
		return false
	slot.neutralize()
	_mutex.unlock()
	return true


func set_suspended(suspended: bool) -> void:
	if not active():
		return
	_mutex.lock()
	var changed: bool = suspended != _suspended
	if changed:
		_epoch += 1
		_suspended = suspended
		for slot: ActionSlot in _slots:
			slot.neutralize()
			slot.sequence = -1
	_mutex.unlock()
	if changed:
		_applied_actions.fill(0.0)
		_applied_sequences.fill(-1)
		_flags.fill(CANCEL)
		for actor: CyberActorPrototype in _actors:
			actor.clear_actions()


func step(delta: float, world) -> void:
	if not active() or _suspended or not is_finite(delta) or delta <= 0.0:
		return
	_submit_demo_actions()
	_mutex.lock()
	_tick += 1
	for index: int in range(_count):
		var slot: ActionSlot = _slots[index]
		var live: bool = slot.deadline >= _tick
		_moves[index] = slot.movement if live else Vector2.ZERO
		_aims[index] = slot.aim if live else Vector2.ZERO
		_efforts[index] = slot.effort if live else 0.0
		_trims[index] = slot.trim if live else 0.0
		_reels[index] = slot.reel if live else 0.0
		_actuators[index] = slot.actuators if live else Vector4.ZERO
		var flags: int = CANCEL if slot.cancel_pending or (slot.was_live and not live) else 0
		if live:
			if slot.primary: flags |= PRIMARY_HELD
			if slot.secondary: flags |= SECONDARY_HELD
			if slot.primary_pressed: flags |= PRIMARY_PRESSED
			if slot.secondary_pressed: flags |= SECONDARY_PRESSED
			if slot.auxiliary: flags |= AUXILIARY_HELD
			if slot.auxiliary_pressed: flags |= AUXILIARY_PRESSED
		else:
			slot.primary = false
			slot.secondary = false
			slot.auxiliary = false
		_flags[index] = flags
		slot.primary_pressed = false
		slot.secondary_pressed = false
		slot.auxiliary_pressed = false
		slot.cancel_pending = false
		slot.was_live = live
		_applied_sequences[index] = slot.sequence if live else -1
	_mutex.unlock()
	query_count_last = 0
	ray_query_count_last = 0
	effect_read_count_last = 0
	edited_cell_count_last = 0
	for index: int in range(_actors.size()):
		var actor: CyberActorPrototype = _actors[index]
		var flags: int = _flags[index]
		if flags & CANCEL:
			actor.clear_actions()
		if actor is CyberActorRigMotor:
			var rig_actor: CyberActorRigMotor = actor as CyberActorRigMotor
			if _control_modes[index] == &"metal":
				rig_actor.simulate_actuator_action(delta, _actuators[index], world)
			else:
				rig_actor.simulate_rig_action(delta, _moves[index], _aims[index], _efforts[index],
					_trims[index], _reels[index], bool(flags & PRIMARY_HELD), bool(flags & SECONDARY_HELD),
					bool(flags & AUXILIARY_HELD), world, bool(flags & PRIMARY_PRESSED),
					bool(flags & SECONDARY_PRESSED), bool(flags & AUXILIARY_PRESSED))
			ray_query_count_last += rig_actor.ray_queries_last
			effect_read_count_last += rig_actor.effect_reads_last
			edited_cell_count_last += rig_actor.edited_cells_last
		else:
			actor.simulate_action(
				delta, _moves[index], bool(flags & PRIMARY_HELD), bool(flags & SECONDARY_HELD),
				world, bool(flags & PRIMARY_PRESSED), bool(flags & SECONDARY_PRESSED)
			)
		var action_offset: int = index * ACTION_STRIDE
		_applied_actions[action_offset] = _moves[index].x
		_applied_actions[action_offset + 1] = _moves[index].y
		_applied_actions[action_offset + 2] = _aims[index].x
		_applied_actions[action_offset + 3] = _aims[index].y
		_applied_actions[action_offset + 4] = _efforts[index]
		_applied_actions[action_offset + 5] = _trims[index]
		_applied_actions[action_offset + 6] = _reels[index]
		_applied_actions[action_offset + 7] = float(bool(flags & PRIMARY_HELD))
		_applied_actions[action_offset + 8] = float(bool(flags & SECONDARY_HELD))
		_applied_actions[action_offset + 9] = float(bool(flags & AUXILIARY_HELD))
		query_count_last += actor.query_count_last


func _submit_demo_actions() -> void:
	# A deterministic 10 Hz example producer, not neural inference or pathfinding.
	# It uses actor-local values and the exact same admission path as other inputs.
	if _tick % DEMO_INTERVAL_TICKS != 0:
		return
	for index: int in range(_actors.size()):
		if _producers[index] != &"demo":
			continue
		var actor: CyberActorPrototype = _actors[index]
		var offset: float = actor.position.x - _homes[index].x
		if absf(offset) > 30.0:
			_directions[index] = -1.0 if offset > 0.0 else 1.0
		elif _tick > 0 and absf(actor.velocity.x) < 0.1:
			_directions[index] = -_directions[index]
		var movement: Vector2 = Vector2(_directions[index], 0.0)
		var primary: bool = (_tick + index * 18) % 90 < DEMO_INTERVAL_TICKS
		var secondary: bool = false
		if _models[index] == &"skimmer":
			movement.y = clampf((_homes[index].y - 10.0 - actor.position.y) / 12.0, -1.0, 1.0)
			primary = (_tick + index * 18) % 180 < DEMO_INTERVAL_TICKS
		_demo_sequences[index] += 1
		if MODEL_IDS.has(_models[index]):
			submit_action(index, _epoch, _demo_sequences[index], _tick, movement,
				primary, secondary, DEFAULT_LEASE_TICKS, &"demo")
		else:
			var phase: int = (_tick + index * 18) % 180
			var aim: Vector2 = Vector2(_directions[index], -0.75).normalized()
			if _models[index] == &"lineshank": aim.y = -0.15
			if _rig_sets[index] == &"setF":
				movement.y = clampf((_homes[index].y - 16.0 - actor.position.y) / 18.0, -1.0, 1.0)
			submit_rig_action(index, _epoch, _demo_sequences[index], _tick, movement,
				aim, 0.7, sin(float(_tick + index * 30) * 0.04) * 0.35,
				1.0 if phase < 80 else -0.25, phase < 24, phase >= 108 and phase < 120,
				phase >= 150 and phase < 156, DEFAULT_LEASE_TICKS, &"demo")


func snapshot() -> Dictionary:
	# Owner-only. New fixed-size state values never alias mutable actor objects.
	if not active():
		return {}
	var states: PackedFloat32Array = PackedFloat32Array()
	states.resize(_actors.size() * OBSERVATION_STRIDE)
	var rig_states: PackedFloat32Array = PackedFloat32Array()
	rig_states.resize(_actors.size() * RIG_OBSERVATION_STRIDE)
	var actuation_states: PackedFloat32Array = PackedFloat32Array()
	actuation_states.resize(_actors.size() * ACTUATION_STRIDE)
	for index: int in range(_actors.size()):
		var observation: PackedFloat32Array = _actors[index].observation()
		for field: int in range(OBSERVATION_STRIDE):
			states[index * OBSERVATION_STRIDE + field] = observation[field]
			if not _actors[index] is CyberActorRigMotor:
				rig_states[index * RIG_OBSERVATION_STRIDE + field] = observation[field]
		if _actors[index] is CyberActorRigMotor:
			var rig_actor: CyberActorRigMotor = _actors[index] as CyberActorRigMotor
			var rig_observation: PackedFloat32Array = rig_actor.rig_observation()
			for field: int in range(RIG_OBSERVATION_STRIDE):
				rig_states[index * RIG_OBSERVATION_STRIDE + field] = rig_observation[field]
			if _control_modes[index] == &"metal":
				var raw_observation: PackedFloat32Array = rig_actor.actuation_observation()
				for field: int in range(ACTUATION_STRIDE):
					actuation_states[index * ACTUATION_STRIDE + field] = raw_observation[field]
		else:
			rig_states[index * RIG_OBSERVATION_STRIDE + 35] = CyberSampledCharacter.BODY_SIZE.x
			rig_states[index * RIG_OBSERVATION_STRIDE + 36] = CyberSampledCharacter.BODY_SIZE.y
	var sequences: PackedInt64Array = PackedInt64Array()
	var remaining: PackedInt32Array = PackedInt32Array()
	sequences.resize(_actors.size())
	remaining.resize(_actors.size())
	_mutex.lock()
	var epoch: int = _epoch
	var tick: int = _tick
	var suspended: bool = _suspended
	for index: int in range(_count):
		sequences[index] = _slots[index].sequence
		remaining[index] = maxi(0, _slots[index].deadline - _tick)
	_mutex.unlock()
	return {
		"version": 1, "epoch": epoch, "tick": tick, "suspended": suspended,
		"count": _actors.size(), "capacity": MAX_ACTORS,
		"observation_stride": OBSERVATION_STRIDE, "states": states,
		"models": _models.duplicate(), "producers": _producers.duplicate(),
		"capabilities": _capabilities.duplicate(true),
		"sequences": sequences, "lease_remaining": remaining,
		"query_count_last": query_count_last,
		"rig_version": 2, "rig_observation_stride": RIG_OBSERVATION_STRIDE,
		"rig_states": rig_states, "rig_sets": _rig_sets.duplicate(),
		"rig_capabilities": _rig_capabilities.duplicate(true),
		"control_modes": _control_modes.duplicate(),
		"actuation_version": 1, "actuation_stride": ACTUATION_STRIDE,
		"actuation_states": actuation_states,
		"actuation_profiles": _actuation_profiles.duplicate(),
		"actuation_capabilities": _actuation_capabilities.duplicate(true),
		"action_stride": ACTION_STRIDE, "applied_actions": _applied_actions.slice(0, _actors.size() * ACTION_STRIDE),
		"applied_sequences": _applied_sequences.slice(0, _actors.size()),
		"applied_flags": _flags.slice(0, _actors.size()),
		"ray_query_count_last": ray_query_count_last,
		"effect_read_count_last": effect_read_count_last,
		"edited_cell_count_last": edited_cell_count_last,
	}
