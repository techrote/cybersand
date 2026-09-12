class_name CyberInteractionPolicy
extends RefCounted

# Mirror of native InteractionPolicy v1 and MaterialRules::supports_granular_load.
# The fallback still has discrete Water and a reduced reaction/Stone model.
const VERSION: int = 1
const DOWNWARD_CELLS: int = 8
const SIDE_CELLS: int = 9
const MERCURY_PERIOD: int = 30

static func supports_load(material: int) -> bool:
	match material:
		2, 13, 14, 19, 23, 25, 26, 27, 29:
			return true
		_:
			return false

static func stable(world, x: int, y: int, include_transient_obstacles: bool = true) -> bool:
	var material: int = (
		world.material_at(x, y)
		if include_transient_obstacles
		else world.stored_material_at(x, y)
	)
	if world._is_hard_surface_material(material):
		return true
	return supports_load(material) and (world.tick_index == 0 or world.updated_at[world.cell_index(x, y)] != world.update_epoch)

static func supports_at(
	world,
	x: int,
	y: int,
	side: bool,
	include_transient_obstacles: bool = true
) -> bool:
	var material: int = (
		world.material_at(x, y)
		if include_transient_obstacles
		else world.stored_material_at(x, y)
	)
	if not supports_load(material) or not stable(world, x, y, include_transient_obstacles):
		return false
	var below: int = 0
	for dy: int in range(3):
		for dx: int in range(-1, 2):
			below += int(stable(world, x + dx, y + dy, include_transient_obstacles))
	if below < world.downward_support_cells:
		return false
	if not side:
		return true
	var around: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			around += int(stable(world, x + dx, y + dy, include_transient_obstacles))
	return around >= SIDE_CELLS
