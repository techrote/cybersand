extends RefCounted

# Physical observation helpers for LCB acceptance contracts. Read-only queries
# against the native World; they never write cells or wake activity.

# Rightmost Water cell on row y within [x_from, x_to], or -1 when there is none.
static func front_x(world: Variant, y: int, x_from: int, x_to: int) -> int:
	var x: int = x_to
	while x >= x_from:
		if int(world.material_at(x, y)) == 3: return x
		x -= 1
	return -1

# First Water row scanning down column x from y_top, or -1.
static func surface_y(world: Variant, x: int, y_top: int, y_bottom: int) -> int:
	for y: int in range(y_top, y_bottom):
		if int(world.material_at(x, y)) == 3: return y
	return -1

# Mass-weighted mean column of Water inside a region (per-column integer mass).
static func centroid_x(world: Variant, region: Array) -> float:
	var total: int = 0
	var weighted: float = 0.0
	for x: int in range(int(region[0]), int(region[0]) + int(region[2])):
		var mass: int = int(world.water_experiment_observation(Vector2i(x, int(region[1])),
			Vector2i(1, int(region[3]))).water_integer)
		total += mass
		weighted += float(x) * float(mass)
	return weighted / float(total) if total > 0 else -1.0

static func water(world: Variant, region: Array) -> int:
	return int(world.water_experiment_observation(Vector2i(int(region[0]), int(region[1])),
		Vector2i(int(region[2]), int(region[3]))).water_integer)

static func world_hashes(world: Variant) -> Array:
	var o: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(1024, 1024))
	return [o.content_hash, o.state_hash, int(o.water_integer)]
