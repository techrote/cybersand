extends SceneTree

# The incremental hard-surface chunk packet (#406) must equal a full rebuild
# from the display projection after every terrain change: wall/stone/glass
# paint and erasure, Fire burning Wood, Lava melting Glass and Acid eating Metal,
# across collision-chunk seams. It must also reuse unchanged chunks.

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("HARD_SURFACE_INCREMENTAL: " + message)


func _same(world: Object, label: String) -> void:
	var incremental: PackedInt32Array = world.get_hard_surface_chunk_rectangles()
	var full: PackedInt32Array = world.diagnostic_full_hard_surface_chunk_rectangles()
	_expect(incremental.size() > 0 and incremental == full, "incremental packet differs from the full rebuild: " + label)


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if _failures != 0:
		quit(_failures)
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.simulation_window_enabled = false
	_same(world, "initial demo world")
	var rng := RandomNumberGenerator.new()
	rng.seed = 406
	# Reactive structures straddling 64-cell collision seams.
	world.emit_disc(128, 256, 20, CyberCellWorld.WOOD)
	world.emit_disc(128, 256, 4, CyberCellWorld.FIRE)
	world.emit_disc(320, 192, 14, CyberCellWorld.GLASS)
	world.emit_disc(320, 170, 8, CyberCellWorld.LAVA)
	world.emit_disc(512, 384, 12, CyberCellWorld.METAL)
	world.emit_disc(512, 364, 8, CyberCellWorld.ACID)
	var materials: Array[int] = [CyberCellWorld.WALL, CyberCellWorld.STONE, CyberCellWorld.GLASS,
		CyberCellWorld.EMPTY, CyberCellWorld.WOOD, CyberCellWorld.SAND, CyberCellWorld.WATER]
	for step: int in range(90):
		if step % 3 == 0:
			var x: int = rng.randi_range(8, 1015)
			var y: int = rng.randi_range(8, 1015)
			world.emit_disc(x, y, rng.randi_range(2, 18), materials[rng.randi_range(0, materials.size() - 1)])
		_expect(bool(world.simulation_tick()), "native tick failed at step %d" % step)
		_same(world, "step %d" % step)
	var stats: Dictionary = world.diagnostic_hard_surface_packet_stats()
	_expect(int(stats.get("chunks_reused", 0)) > int(stats.get("chunks_rebuilt", 0)),
		"unchanged collision chunks were not reused (%s)" % str(stats))
	print("HARD_SURFACE_INCREMENTAL %d checks, %d failures, %s" % [_checks, _failures, JSON.stringify(stats)])
	quit(_failures)
