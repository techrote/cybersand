extends SceneTree

# Native adapter unit tests only. A synthetic body mask is not a claim of a
# Rapier/player-enabled headless scenario or of desktop/Web player parity.
var assertions: int = 0
var failures: int = 0
func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.has_method(&"inspect_cell") or not bridge.has_method(&"inspect_statistics"):
		push_error("Current rebuilt native observation adapter is required; stale runtime is not acceptance")
		quit(1)
		return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"Fresh native owner reset failed")
	expect(bridge.build_world(world,PackedInt32Array([24,24,1,1,3,32,32,2,2,2,20,40,40,2,1])),"Ordinary geometry setup failed")
	world.set_simulation_window_enabled(false)
	var before: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))
	var revision: int = int(world.get_revision())
	var cell: Dictionary = bridge.inspect_cell(world,Vector2i(24,24))
	expect(cell.ok and cell.material == 3 and cell.state_a == 255,"Probe did not report authoritative stored Water")
	expect(cell.temperature_available and cell.temperature_raw == 200,"Unmasked raw temperature missing")
	expect(cell.transient_body_id == 0 and cell.completed_tick == 0,"Probe boundary identity incorrect")
	expect(cell.chunk_coordinate == [0,0] and cell.activity_block_coordinate == [0,0],"Probe coordinate domains incorrect")
	var stats: Dictionary = bridge.inspect_statistics(world)
	expect(stats.ok and stats.completed_tick == 0,"Initial statistics unavailable")
	expect(stats.limits.maximum_chunks >= int(stats["values"].resident_chunks),"Runtime storage limit omitted")
	expect(stats.limits.active_cores > 0 and stats.limits.deferred_events > 0,"Protected capacities not reported")
	expect(stats.unavailable.has("per-worker utilization"),"Unavailable utilization counter invented")
	for repeat: int in range(32):
		expect(bridge.inspect_cell(world,Vector2i(24,24)) == cell,"Read-only point probe changed on repeat")
		expect(bridge.inspect_statistics(world) == stats,"Read-only statistics changed on repeat")
	expect(world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)) == before,"Observation mutated cell/hash/accounting state")
	expect(int(world.get_revision()) == revision,"Observation dirtied rendering")
	cell.material = 77
	cell.chunk_coordinate[0] = 999
	stats["values"]["resident_chunks"] = -1
	expect(bridge.inspect_cell(world,Vector2i(24,24)).material == 3,"Probe returned live material authority")
	expect(bridge.inspect_cell(world,Vector2i(24,24)).chunk_coordinate == [0,0],"Probe shared nested mutable coordinates")
	expect(int(bridge.inspect_statistics(world)["values"].resident_chunks) >= 1,"Statistics returned live storage state")
	for point: Vector2i in [Vector2i(-1,0),Vector2i(0,-1),Vector2i(1024,0),Vector2i(0,1024)]:
		expect(not bridge.inspect_cell(world,point).ok,"Out-of-world probe admitted")
	expect(not bridge.inspect_cell(null,Vector2i.ZERO).ok,"Null probe owner accepted")
	expect(not bridge.inspect_statistics(null).ok,"Null statistics owner accepted")
	world.prepare_rigid_body_coupling(PackedFloat32Array([1,24.5,24.5,0,4,4,0,0,0,1,1]),false)
	before = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))
	cell = bridge.inspect_cell(world,Vector2i(24,24))
	expect(cell.ok and cell.material == 3 and cell.transient_body_id == 1,"Probe silently substituted body occupancy for stored material")
	expect(not cell.temperature_available and cell.temperature_raw == null,"Masked ambient was falsely reported as stored temperature")
	expect(world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024)) == before,"Inspection cleared body masks or altered authority")
	world.prepare_rigid_body_coupling(PackedFloat32Array(),false)
	for tick: int in range(4): expect(world.simulation_tick(),"Native tick failed")
	stats = bridge.inspect_statistics(world)
	expect(stats.completed_tick == 4 and stats["values"].visited_cells == world.get_scanned_last_tick(),"Tick statistics did not identify completed native work")
	var previous: Variant = ProjectSettings.get_setting("cybersand/native_active_core_capacity",null)
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",1)
	var limited: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	ProjectSettings.set_setting("cybersand/native_active_core_capacity",previous)
	limited.set_simulation_window_enabled(false)
	expect(bridge.build_world(limited,PackedInt32Array([20,20,1,1,2,160,20,1,1,2])),"Capacity fixture setup failed")
	expect(not limited.simulation_tick() and limited.has_failed(),"Capacity failure not quarantined")
	var attempted: int = int(limited.get_attempted_tick_index())
	expect(not bridge.inspect_cell(limited,Vector2i(20,20)).ok,"Quarantined cell state exported as a successful probe")
	expect(not bridge.inspect_statistics(limited).ok,"Partial failed-tick counters exported as success")
	expect(int(limited.get_attempted_tick_index()) == attempted,"Inspection retried a failed tick")
	expect(bridge.build_world(limited,PackedInt32Array([20,20,1,1,2])),"Fresh replacement failed to recover quarantine")
	expect(bridge.inspect_statistics(limited).ok and bridge.inspect_statistics(limited).limits.active_cores == 1,"Inspection silently raised capacity on reset")
	print("MICROSCENARIO_NATIVE_OBSERVATION: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
