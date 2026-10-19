class_name CyberUsableSession
extends RefCounted

const Runtime = preload("res://scripts/usable_runtime.gd")
const Catalog = preload("res://scripts/usable_catalog.gd")
const MAX_ACTORS: int = Runtime.MAX_ACTORS
const MAX_LEASE_TICKS: int = 18
const DEFAULT_LEASE_TICKS: int = 12

class ActionSlot:
	extends RefCounted
	var usable_index: int = -1
	var aim: Vector2 = Vector2.RIGHT
	var power: float = 1.0
	var trigger: bool = false
	var alternate: bool = false
	var trigger_pressed: bool = false
	var alternate_pressed: bool = false
	var sequence: int = -1
	var deadline: int = -1
	var producer: StringName = &"policy"
	var was_live: bool = false
	var cancel_pending: bool = false
	var rearm_pending: bool = false

	func neutralize(reset_sequence: bool = false) -> void:
		trigger = false
		alternate = false
		trigger_pressed = false
		alternate_pressed = false
		deadline = -1
		was_live = false
		cancel_pending = true
		rearm_pending = false
		if reset_sequence:
			sequence = -1

var _mutex: Mutex = Mutex.new()
var _slots: Array[ActionSlot] = []
var _runtime: CyberUsableRuntime = Runtime.new()
var _count: int = 0
var _epoch: int = -1
var _tick: int = 0
var _producers: Array[StringName] = []
var _suspended: bool = false

func _init() -> void:
	for _i: int in range(MAX_ACTORS):
		_slots.append(ActionSlot.new())

func configure(actor_context: Dictionary) -> bool:
	var count: int = int(actor_context.get("count", 0))
	if count < 0 or count > MAX_ACTORS:
		return false
	var producers_value = actor_context.get("producers", [])
	if producers_value.size() != count:
		return false
	var producers: Array[StringName] = []
	for value in producers_value:
		producers.append(StringName(str(value)))
	_mutex.lock()
	_count = count
	_epoch = int(actor_context.get("epoch", -1))
	_tick = int(actor_context.get("tick", 0))
	_producers = producers
	_suspended = bool(actor_context.get("suspended", false))
	for index: int in range(MAX_ACTORS):
		var slot: ActionSlot = _slots[index]
		slot.usable_index = -1
		slot.aim = Vector2.RIGHT
		slot.power = 1.0
		slot.producer = producers[index] if index < count else &"policy"
		slot.neutralize(true)
	_mutex.unlock()
	return _runtime.configure(count)

func clear() -> void:
	_mutex.lock()
	_count = 0
	_epoch = -1
	_tick = 0
	_producers.clear()
	_suspended = false
	for slot: ActionSlot in _slots:
		slot.usable_index = -1
		slot.neutralize(true)
	_mutex.unlock()
	_runtime.clear()

func sync_actor_context(actor_context: Dictionary) -> bool:
	var count: int = int(actor_context.get("count", 0))
	if count != _count:
		return false
	var producers_value = actor_context.get("producers", [])
	if producers_value.size() != count:
		return false
	var epoch: int = int(actor_context.get("epoch", -1))
	var tick: int = int(actor_context.get("tick", 0))
	var suspended: bool = bool(actor_context.get("suspended", false))
	_mutex.lock()
	var epoch_changed: bool = epoch != _epoch
	_epoch = epoch
	_tick = tick
	_suspended = suspended
	for index: int in range(count):
		_producers[index] = StringName(str(producers_value[index]))
		_slots[index].producer = _producers[index]
		if epoch_changed:
			_slots[index].neutralize(true)
	_mutex.unlock()
	return true

func submit_action(
	actor_id: int, epoch: int, sequence: int, observed_tick: int,
	usable_index: int, aim: Vector2, power: float,
	trigger: bool, alternate: bool,
	lease_ticks: int = DEFAULT_LEASE_TICKS,
	producer: StringName = &"policy"
) -> bool:
	if (
		sequence < 0 or usable_index < -1 or usable_index >= Catalog.count()
		or not aim.is_finite() or not is_finite(power)
		or lease_ticks < 1 or lease_ticks > MAX_LEASE_TICKS
	):
		return false
	var normalized_aim: Vector2 = aim
	if normalized_aim != Vector2.ZERO:
		normalized_aim = normalized_aim.normalized()
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
	var switched: bool = usable_index != slot.usable_index
	if switched:
		slot.usable_index = usable_index
		slot.rearm_pending = trigger or alternate
		slot.trigger = false
		slot.alternate = false
		slot.trigger_pressed = false
		slot.alternate_pressed = false
	elif slot.rearm_pending:
		if not trigger and not alternate:
			slot.rearm_pending = false
		slot.trigger = false
		slot.alternate = false
	else:
		slot.trigger_pressed = slot.trigger_pressed or (trigger and not slot.trigger)
		slot.alternate_pressed = slot.alternate_pressed or (alternate and not slot.alternate)
		slot.trigger = trigger
		slot.alternate = alternate
	slot.aim = normalized_aim
	slot.power = clampf(power, 0.0, 1.0)
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
	slot.neutralize(false)
	_mutex.unlock()
	return true

func step(delta: float, world, actor_context: Dictionary) -> void:
	if _count <= 0:
		return
	if not sync_actor_context(actor_context):
		return
	if _suspended:
		return
	var centres := PackedVector2Array()
	centres.resize(_count)
	var bounds: Array[Rect2] = []
	var rig_states: PackedFloat32Array = actor_context.get("rig_states", PackedFloat32Array())
	var stride: int = int(actor_context.get("rig_observation_stride", 40))
	for index: int in range(_count):
		var offset: int = index * stride
		var origin := Vector2.ZERO
		var size := Vector2(8.0, 14.0)
		if rig_states.size() >= offset + stride:
			origin = Vector2(float(rig_states[offset]), float(rig_states[offset + 1]))
			if stride > 36:
				size = Vector2(maxf(0.25, float(rig_states[offset + 35])), maxf(0.25, float(rig_states[offset + 36])))
		centres[index] = origin + size * 0.5
		bounds.append(Rect2(origin, size))
	var actions: Array = []
	_mutex.lock()
	for index: int in range(_count):
		var slot: ActionSlot = _slots[index]
		var live: bool = slot.deadline >= _tick
		var cancel: bool = slot.cancel_pending or (slot.was_live and not live)
		actions.append({
			"usable_index": slot.usable_index,
			"aim": slot.aim,
			"power": slot.power,
			"trigger": slot.trigger if live else false,
			"alternate": slot.alternate if live else false,
			"trigger_pressed": slot.trigger_pressed if live else false,
			"alternate_pressed": slot.alternate_pressed if live else false,
			"cancel": cancel,
		})
		slot.trigger_pressed = false
		slot.alternate_pressed = false
		slot.cancel_pending = false
		slot.was_live = live
		if not live:
			slot.trigger = false
			slot.alternate = false
	_mutex.unlock()
	_runtime.step(delta, world, centres, bounds, actions)

func snapshot() -> Dictionary:
	if _count <= 0:
		return {}
	var value: Dictionary = _runtime.snapshot()
	var sequences := PackedInt64Array()
	var remaining := PackedInt32Array()
	var equipped := PackedInt32Array()
	sequences.resize(_count)
	remaining.resize(_count)
	equipped.resize(_count)
	_mutex.lock()
	value["epoch"] = _epoch
	value["tick"] = _tick
	value["suspended"] = _suspended
	value["producers"] = _producers.duplicate()
	for index: int in range(_count):
		sequences[index] = _slots[index].sequence
		remaining[index] = maxi(0, _slots[index].deadline - _tick)
		equipped[index] = _slots[index].usable_index
	_mutex.unlock()
	value["sequences"] = sequences
	value["lease_remaining"] = remaining
	value["equipped"] = equipped
	return value
