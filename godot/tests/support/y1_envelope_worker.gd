extends CyberSimulationWorker

# Test-only observation subclass. Production mailbox, cadence and publication
# remain authoritative. Main thread reads trace only after stop_worker() joins.
const STRIDE := 20
var trace := PackedFloat64Array()
var limit: int = 1000
var recorded_tick: int = -1
var excavation: bool = false
var bed_left: int = 96
var bed_width: int = 64
var bed_depth: int = 96
var material: int = 2
var edit_count: int = 0
var edit_receipt: Dictionary = {}
var expected_arm: String = "B0"
var selector_failures: int = 0

func _activate_sampled_character(spawn_position: Vector2, runtime_recovery_enabled: bool) -> void:
	# Body-only fixture uses the production configuration boundary before start.
	_configure_sampled_character(spawn_position,false,runtime_recovery_enabled)

func prepare_trace() -> void:
	trace.resize((limit+1)*STRIDE)
	trace.fill(0.0)

func _publish_snapshot(step_ms: float, paused: bool, interval: int, force_full: bool = false,
		rigid_body_states: PackedFloat32Array = PackedFloat32Array(), rigid_body_epoch: int = 0) -> void:
	super._publish_snapshot(step_ms,paused,interval,force_full,rigid_body_states,rigid_body_epoch)
	var tick: int = int(_world.get_tick_index())
	if tick > recorded_tick and tick <= limit and not _simulation_failed:
		var offset: int = tick*STRIDE
		trace[offset] = tick
		trace[offset+1] = step_ms
		var metrics: Array = _world.diagnostic_body_metrics()
		if not metrics.is_empty():
			var d: Array = metrics[0]
			if d[20].candidate != expected_arm: selector_failures += 1
			trace[offset+2] = d[1]
			trace[offset+3] = d[18]
			trace[offset+4] = d[20].raw_support
			trace[offset+5] = d[20].boundaries
			trace[offset+6] = d[20].attempts
			trace[offset+7] = d[20].no_target
			trace[offset+8] = d[20].relocation_refused
		var result: PackedFloat32Array = _world.rigid_body_results()
		if result.size() >= 9: trace[offset+9] = result[4]
		var value: Dictionary = _world.diagnostic_snapshot(Vector2i(bed_left-1,0),Vector2i(bed_width+2,192+bed_depth+1),false,false)
		trace[offset+10] = value.counts[material]
		trace[offset+11] = value.water_mass
		trace[offset+12] = _world.get_scanned_last_tick()
		trace[offset+13] = _world.get_moves_last_tick()
		trace[offset+14] = _world.get_active_blocks_last_tick()
		if rigid_body_states.size() >= 11:
			trace[offset+15] = rigid_body_states[1]
			trace[offset+16] = rigid_body_states[2]
			trace[offset+17] = rigid_body_states[7]
		trace[offset+18] = edit_count
		trace[offset+19] = 1.0
		recorded_tick = tick
	# Edit belongs exclusively to the cellular owner after the tick599 result.
	# The next accepted sample recomputes support, including normal mailbox delay.
	if excavation and tick == 599 and edit_count == 0:
		var before: Dictionary = _world.diagnostic_snapshot(Vector2i(bed_left-1,0),Vector2i(bed_width+2,192+bed_depth+1),false,false)
		if _world.diagnostic_fill_rect(Vector2i(bed_left,192),Vector2i(bed_width,bed_depth),0): edit_count = 1
		var after: Dictionary = _world.diagnostic_snapshot(Vector2i(bed_left-1,0),Vector2i(bed_width+2,192+bed_depth+1),false,false)
		edit_receipt = {"tick":tick,"before":before.counts,"after":after.counts,"water_before":before.water_mass,"water_after":after.water_mass}
	if tick >= limit:
		_mutex.lock()
		_running = false
		_mutex.unlock()
