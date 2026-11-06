extends CyberSimulationWorker

# COUPLING-LOCKSTEP-001 test-only subclass. Production pacing, publication and
# ownership are exercised unchanged; the exclusive owner additionally copies the
# World physical_state_hash of each newly completed tick into fixed storage.
# The main thread reads tick_hashes only after stop_worker() joins the owner.
var tick_limit: int = 600
var tick_hashes: PackedStringArray = PackedStringArray()
var recorded_tick: int = 0
# Amendment_001 load arm: synthetic extra native-owner time per completed tick.
var native_delay_usec: int = 0

func prepare_trace(limit: int) -> bool:
	if limit < 1 or limit > CyberPhysicsCharacterisation.MAX_TICKS:
		return false
	tick_limit = limit
	tick_hashes.resize(limit + 1)
	return true

func _publish_snapshot(
		step_ms: float,
		paused: bool,
		interval: int,
		force_full: bool = false,
		rigid_body_states: PackedFloat32Array = PackedFloat32Array(),
		rigid_body_epoch: int = 0
) -> void:
	var tick: int = int(_world.get_tick_index())
	if native_delay_usec > 0 and tick > recorded_tick:
		OS.delay_usec(native_delay_usec)
	super._publish_snapshot(step_ms, paused, interval, force_full, rigid_body_states, rigid_body_epoch)
	if tick > recorded_tick and tick <= tick_limit and not _simulation_failed:
		tick_hashes[tick] = str(_world.get_physical_state_hash())
		recorded_tick = tick
	if tick >= tick_limit:
		_mutex.lock()
		_running = false
		_mutex.unlock()
