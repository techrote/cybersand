extends SceneTree

# Regression (WAVE-WATERWALL-001 crash): bound status getters must never let an
# exception from a failed World reach Godot. Before the fix this process
# aborted (0xC0000409, libc++abi "world is failed") inside get_wave_flow_status.
func _init() -> void:
	ProjectSettings.set_setting("cybersand/native_active_core_capacity", 1)
	var failures: Array[String] = []
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	world.set_simulation_window(Vector2i.ZERO, Vector2i(320, 180), 0, 0)
	if not bridge.build_world(world, PackedInt32Array([20, 20, 1, 1, 2])): failures.append("world did not build")
	world.simulation_tick()
	# Activity in two distant cores exceeds the forced capacity of one core.
	world.paint_disc(20, 20, 0, 1)
	world.paint_disc(21, 20, 0, 1)
	world.paint_disc(160, 20, 0, 2)
	world.simulation_tick()
	if not world.has_failed(): failures.append("setup did not fail the World")
	var status: Dictionary = world.get_wave_flow_status()
	if status.get("healthy", true) != false: failures.append("failed World reported healthy")
	var spray: Dictionary = world.get_water_spray()
	if spray.is_empty(): failures.append("water spray status missing")
	print("FAILED_WORLD_STATUS ", JSON.stringify({"failures": failures, "error": world.get_last_tick_error()}))
	quit(0 if failures.is_empty() else 1)
