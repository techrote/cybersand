class_name CyberPlayableCourseLap
extends RefCounted

# Presentation-only progress for a source-bound human SetP course. No native
# World, Rapier bridge or worker ownership; source ticks arrive via copied
# completed snapshots, actor poses via the main-thread physical session.
const Course = preload("res://scripts/player_playground_course.gd")
const TICKS_PER_SECOND: float = 60.0
const GATE_RADIUS: float = 15.0

var rig_id: StringName = &""
var actor_epoch: int = -1
var world_generation: int = -1
var last_source_tick: int = -1
var last_physics_tick: int = -1
var started: bool = false
var elapsed_ticks: int = 0
var target_index: int = 0
var best_ticks: Dictionary = {}

# These high-water marks belong to this desktop host's lifetime, not a lap.
# Temporary presentation/terrain invalidity may clear the displayed session;
# it must not make an older actor, World, or source publication admissible.
# A replacement desktop host constructs a new tracker rather than rewinding
# these identities. Actor model identity cannot change within the same epoch.
var _accepted_actor_epoch: int = -1
var _accepted_world_generation: int = -1
var _accepted_rig: StringName = &""
var _source_tick_floor: int = -1
var _physics_tick_floor: int = -1


func clear_session() -> void:
	rig_id = &""
	actor_epoch = -1
	world_generation = -1
	last_source_tick = -1
	last_physics_tick = -1
	started = false
	elapsed_ticks = 0
	target_index = 0


func bind(rig: StringName, epoch: int, generation: int, source_tick: int) -> bool:
	if rig not in Course.MECHANICAL_PRESETS or epoch < 0 or generation < 0 or source_tick < 0:
		return false
	# Validate the complete candidate before clearing live progress or raising
	# any fence. A newer epoch does not legitimize an older World (or vice versa).
	if epoch < _accepted_actor_epoch or generation < _accepted_world_generation:
		return false
	if epoch == _accepted_actor_epoch and rig != _accepted_rig:
		return false
	if generation == _accepted_world_generation and source_tick < _source_tick_floor:
		return false
	if rig != rig_id or epoch != actor_epoch or generation != world_generation:
		clear_session()
		rig_id = rig
		actor_epoch = epoch
		world_generation = generation
		last_source_tick = source_tick
	if epoch != _accepted_actor_epoch:
		_physics_tick_floor = -1
	_accepted_actor_epoch = epoch
	_accepted_world_generation = generation
	_accepted_rig = rig
	_source_tick_floor = source_tick
	return true


func admit_movement(source_tick: int) -> bool:
	if rig_id == &"" or source_tick < _source_tick_floor or is_complete():
		return false
	_source_tick_floor = source_tick
	if not started:
		started = true
		last_source_tick = source_tick
	return true


func observe(source_tick: int, physics_tick: int, position: Vector2, paused: bool) -> bool:
	if (rig_id == &"" or source_tick < _source_tick_floor or physics_tick < _physics_tick_floor
		or physics_tick < 0 or not position.is_finite()):
		return false
	# Only completed native tick deltas advance elapsed time; keep the separate
	# main-thread Rapier cadence for actual checkpoint visits. A new physics
	# observation may reach a gate before the next native render publication.
	if started and not paused and not is_complete():
		elapsed_ticks += source_tick - last_source_tick
		if physics_tick > _physics_tick_floor:
			var checkpoints: PackedVector2Array = Course.checkpoints(rig_id)
			if target_index < checkpoints.size() and position.distance_to(checkpoints[target_index]) <= GATE_RADIUS:
				target_index += 1
				if is_complete():
					best_ticks[rig_id] = mini(elapsed_ticks, int(best_ticks.get(rig_id, 2147483647)))
	last_source_tick = source_tick
	last_physics_tick = physics_tick
	_physics_tick_floor = physics_tick
	_source_tick_floor = source_tick
	return true


func is_complete() -> bool:
	return rig_id != &"" and target_index == Course.checkpoints(rig_id).size()


func display_text() -> String:
	if rig_id == &"":
		return ""
	var gates: int = Course.checkpoints(rig_id).size()
	var result: String = "COURSE CLEAR" if is_complete() else "GATES %d / %d" % [target_index, gates]
	result += "    %05.2f s" % (float(elapsed_ticks) / TICKS_PER_SECOND)
	if best_ticks.has(rig_id):
		result += "    BEST %.2f s" % (float(best_ticks[rig_id]) / TICKS_PER_SECOND)
	return result
