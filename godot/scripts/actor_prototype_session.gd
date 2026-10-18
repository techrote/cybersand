class_name CyberActorPrototypeSession
extends RefCounted

# ACT-001: only the simulation owner may configure, advance or observe motors.
# Producers may submit/cancel copied scalar actions through the bounded mailbox.
# No producer is allowed to retain the World or an actor reference.
const Prototype = preload("res://scripts/actor_prototype.gd")
const MAX_ACTORS: int = 8
const MAX_LEASE_TICKS: int = 18
const DEFAULT_LEASE_TICKS: int = 12
const OBSERVATION_STRIDE: int = 16
const DEMO_INTERVAL_TICKS: int = 6
const MODEL_IDS: Array[StringName] = [&"runner", &"skimmer", &"crawler"]
const PRODUCERS: Array[StringName] = [&"human", &"policy", &"demo"]
const PRIMARY_HELD: int = 1
const SECONDARY_HELD: int = 2
const PRIMARY_PRESSED: int = 4
const SECONDARY_PRESSED: int = 8
const CANCEL: int = 16

class ActionSlot:
	extends RefCounted
	var movement: Vector2 = Vector2.ZERO
	var primary: bool = false
	var secondary: bool = false
	var primary_pressed: bool = false
	var secondary_pressed: bool = false
	var cancel_pending: bool = false
	var sequence: int = -1
	var deadline: int = -1
	var producer: StringName = &"policy"
	var was_live: bool = false

	func neutralize() -> void:
		movement = Vector2.ZERO
		primary = false
		secondary = false
		primary_pressed = false
		secondary_pressed = false
		deadline = -1
		was_live = false
		cancel_pending = true

var _mutex: Mutex = Mutex.new()
var _slots: Array[ActionSlot] = []
var _actors: Array[CyberActorPrototype] = []
var _moves: PackedVector2Array = PackedVector2Array()
var _flags: PackedInt32Array = PackedInt32Array()
var _homes: PackedVector2Array = PackedVector2Array()
var _directions: PackedFloat32Array = PackedFloat32Array()
var _demo_sequences: PackedInt64Array = PackedInt64Array()
var _models: Array[StringName] = []
var _producers: Array[StringName] = []
var _capabilities: Array[Dictionary] = []
var _epoch: int = 0
var _tick: int = 0
var _count: int = 0 # Mailbox count; guarded together with epoch/tick/suspension.
var _suspended: bool = false
var query_count_last: int = 0


func _init() -> void:
	_moves.resize(MAX_ACTORS)
	_flags.resize(MAX_ACTORS)
	_homes.resize(MAX_ACTORS)
	_directions.resize(MAX_ACTORS)
	_demo_sequences.resize(MAX_ACTORS)
	for _index: int in range(MAX_ACTORS):
		_slots.append(ActionSlot.new())


static func valid_definitions(definitions: Array) -> bool:
	if definitions.size() > MAX_ACTORS:
		return false
	for definition in definitions:
		if not definition is Dictionary:
			return false
		if not MODEL_IDS.has(StringName(str(definition.get("model", "")))):
			return false
		if not PRODUCERS.has(StringName(str(definition.get("producer", "policy")))):
			return false
		var spawn = definition.get("position", null)
		if not spawn is Vector2 or not spawn.is_finite():
			return false
		# Prototype spawns belong to the existing finite demo world.
		if spawn.x < 0.0 or spawn.y < 0.0:
			return false
		if spawn.x > CyberCellWorld.WORLD_WIDTH - CyberSampledCharacter.BODY_SIZE.x:
			return false
		if spawn.y > CyberCellWorld.WORLD_HEIGHT - CyberSampledCharacter.BODY_SIZE.y:
			return false
	return true


func configure(definitions: Array, world) -> bool:
	if not valid_definitions(definitions):
		return false
	var candidates: Array[CyberActorPrototype] = []
	var capabilities: Array[Dictionary] = []
	var models: Array[StringName] = []
	var producers: Array[StringName] = []
	for definition: Dictionary in definitions:
		var actor: CyberActorPrototype = Prototype.new()
		if not actor.configure_model(StringName(str(definition.model))):
			return false
		actor.reset(definition.position)
		# The only automatic repair is this explicit, bounded spawn operation.
		actor.recover_invalid_spawn(world)
		candidates.append(actor)
		capabilities.append(actor.capabilities())
		models.append(StringName(str(definition.model)))
		producers.append(StringName(str(definition.get("producer", "policy"))))
	_actors = candidates
	_models = models
	_producers = producers
	_capabilities = capabilities
	_mutex.lock()
	_epoch += 1
	_tick = 0
	_count = _actors.size()
	_suspended = false
	for index: int in range(MAX_ACTORS):
		_slots[index].neutralize()
		_slots[index].sequence = -1
		_demo_sequences[index] = 0
		if index < _count:
			_slots[index].producer = _producers[index]
			_homes[index] = _actors[index].position
			_directions[index] = 1.0 if index % 2 == 0 else -1.0
	_mutex.unlock()
	query_count_last = 0
	return true


func clear() -> void:
	# Owner-only; invalidates late actions even when slot IDs are reused later.
	_actors.clear()
	_models.clear()
	_producers.clear()
	_capabilities.clear()
	_mutex.lock()
	_epoch += 1
	_tick = 0
	_count = 0
	_suspended = false
	for slot: ActionSlot in _slots:
		slot.neutralize()
		slot.sequence = -1
	_mutex.unlock()
	query_count_last = 0


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
	if not movement.is_finite() or sequence < 0:
		return false
	if lease_ticks < 1 or lease_ticks > MAX_LEASE_TICKS:
		return false
	# Clamp before actuator normalization so very large finite outputs stay finite.
	# Ground models ignore Y; only Skimmer normalizes the two-axis vector.
	var normalized: Vector2 = Vector2(
		clampf(movement.x, -1.0, 1.0), clampf(movement.y, -1.0, 1.0)
	)
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
	if sequence <= slot.sequence or producer != slot.producer:
		_mutex.unlock()
		return false
	# Preserve a brief press/release between ticks. Multiple rises coalesce to one
	# bounded press per action per tick; held state always uses the newest packet.
	slot.primary_pressed = slot.primary_pressed or (primary and not slot.primary)
	slot.secondary_pressed = slot.secondary_pressed or (secondary and not slot.secondary)
	slot.movement = normalized
	slot.primary = primary
	slot.secondary = secondary
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
		var flags: int = CANCEL if slot.cancel_pending or (slot.was_live and not live) else 0
		if live:
			if slot.primary: flags |= PRIMARY_HELD
			if slot.secondary: flags |= SECONDARY_HELD
			if slot.primary_pressed: flags |= PRIMARY_PRESSED
			if slot.secondary_pressed: flags |= SECONDARY_PRESSED
		else:
			slot.primary = false
			slot.secondary = false
		_flags[index] = flags
		slot.primary_pressed = false
		slot.secondary_pressed = false
		slot.cancel_pending = false
		slot.was_live = live
	_mutex.unlock()
	query_count_last = 0
	for index: int in range(_actors.size()):
		var actor: CyberActorPrototype = _actors[index]
		var flags: int = _flags[index]
		if flags & CANCEL:
			actor.clear_actions()
		actor.simulate_action(
			delta, _moves[index], bool(flags & PRIMARY_HELD), bool(flags & SECONDARY_HELD),
			world, bool(flags & PRIMARY_PRESSED), bool(flags & SECONDARY_PRESSED)
		)
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
		submit_action(index, _epoch, _demo_sequences[index], _tick, movement,
			primary, secondary, DEFAULT_LEASE_TICKS, &"demo")


func snapshot() -> Dictionary:
	# Owner-only. New fixed-size state values never alias mutable actor objects.
	if not active():
		return {}
	var states: PackedFloat32Array = PackedFloat32Array()
	states.resize(_actors.size() * OBSERVATION_STRIDE)
	for index: int in range(_actors.size()):
		var observation: PackedFloat32Array = _actors[index].observation()
		for field: int in range(OBSERVATION_STRIDE):
			states[index * OBSERVATION_STRIDE + field] = observation[field]
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
	}
