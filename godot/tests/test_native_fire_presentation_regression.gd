extends SceneTree

# One focused regression for the Fire presentation checkpoint. Fire must remain
# visibly alive while destructive contact work is slow enough that a freshly
# ignited hard surface is not erased during the first second.

var _failures: int = 0
const HARD_SURFACE_CHUNK_SIZE: int = 64
const HARD_SURFACE_CHUNK_COUNT: int = (
	(CyberCellWorld.WORLD_WIDTH / HARD_SURFACE_CHUNK_SIZE)
	* (CyberCellWorld.WORLD_HEIGHT / HARD_SURFACE_CHUNK_SIZE)
)
const HARD_SURFACE_HEADER_SIZE: int = HARD_SURFACE_CHUNK_COUNT + 2


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if _failures != 0:
		quit(_failures)
		return

	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	world.simulation_window_enabled = false
	var centre: Vector2i = Vector2i(700, 400)
	world.emit_disc(centre.x, centre.y, 24, CyberCellWorld.EMPTY)
	world.emit_disc(centre.x, centre.y, 12, CyberCellWorld.WOOD)
	world.emit_disc(centre.x, centre.y, 4, CyberCellWorld.FIRE)
	var initial_wood: int = _count_material(world, centre, 14, CyberCellWorld.WOOD)

	for _tick: int in range(60):
		_expect(bool(world.simulation_tick()), "native Fire tick reported a failure")

	var wood_after_one_second: int = _count_material(
		world,
		centre,
		14,
		CyberCellWorld.WOOD
	)
	var fire_after_one_second: int = _count_material(
		world,
		centre,
		40,
		CyberCellWorld.FIRE
	)
	_expect(
		wood_after_one_second * 10 >= initial_wood * 9,
		"Fire destroyed more than 10% of nearby Wood during its first second"
	)
	_expect(fire_after_one_second > 0, "Fire lifetime ended before slow chemistry could run")
	_expect(int(world.tick_failure_count) == 0, "native tick fault counter changed")
	var rectangles: PackedInt32Array = world.get_hard_surface_rectangles()
	_expect(rectangles.size() % 4 == 0, "hard-surface rectangles are malformed")
	var chunk_rectangles: PackedInt32Array = world.get_hard_surface_chunk_rectangles()
	_expect(
		chunk_rectangles.size() >= HARD_SURFACE_HEADER_SIZE,
		"chunked hard-surface snapshot is too short"
	)
	if chunk_rectangles.size() >= HARD_SURFACE_HEADER_SIZE:
		_expect(
			chunk_rectangles[0] == HARD_SURFACE_CHUNK_COUNT,
			"chunked hard-surface count does not match the 64x64 partition"
		)
		_expect(
			chunk_rectangles[1] == HARD_SURFACE_HEADER_SIZE,
			"first chunk offset is malformed"
		)
		_expect(
			chunk_rectangles[HARD_SURFACE_CHUNK_COUNT + 1] == chunk_rectangles.size(),
			"final chunk offset does not match snapshot size"
		)
		for chunk_index: int in range(HARD_SURFACE_CHUNK_COUNT):
			_expect(
				(chunk_rectangles[chunk_index + 2] - chunk_rectangles[chunk_index + 1]) % 4 == 0,
				"chunk rectangle payload is malformed"
			)

	if _failures == 0:
		print(
			"Native Fire regression passed; Wood %d -> %d after 60 ticks, Fire %d" % [
				initial_wood,
				wood_after_one_second,
				fire_after_one_second,
			]
		)
	quit(_failures)


func _count_material(world: Object, centre: Vector2i, radius: int, material_id: int) -> int:
	var count: int = 0
	for y: int in range(centre.y - radius, centre.y + radius + 1):
		for x: int in range(centre.x - radius, centre.x + radius + 1):
			if int(world.material_at(x, y)) == material_id:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
