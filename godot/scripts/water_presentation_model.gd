class_name CyberWaterPresentationModel
extends RefCounted

# Presentation-only reference model for the Water four-level shader path. A
# mask bit represents one logical 2x2 subcell in this fixed order:
# bottom-left, bottom-right, top-left, top-right.
const SUBCELL_BOTTOM_LEFT: int = 0
const SUBCELL_BOTTOM_RIGHT: int = 1
const SUBCELL_TOP_LEFT: int = 2
const SUBCELL_TOP_RIGHT: int = 3

const MODE_REFERENCE: int = 0
const MODE_FOUR_LEVEL_COVERAGE: int = 1
const MODE_FOUR_LEVEL_ORIENTED: int = 2

const COVERAGE_MASKS: Array[int] = [0x0, 0x1, 0x3, 0x7, 0xF]
const GRADIENT_MAGNITUDE_THRESHOLD: int = 2
const DOMINANCE_THRESHOLD: int = 1


static func coverage_samples(condition_byte: int) -> int:
	var normalized_byte: int = clampi(condition_byte, 0, 255)
	if normalized_byte == 0:
		return 0
	# ceil(normalized_byte / 255 * 4), expressed entirely in integers.
	return mini(4, (normalized_byte * 4 + 254) / 255)


static func coverage_mask(condition_byte: int) -> int:
	return COVERAGE_MASKS[coverage_samples(condition_byte)]


static func presentation_mask(
	condition_byte: int,
	water_neighborhood: PackedByteArray,
	world_cell: Vector2i,
	oriented: bool
) -> int:
	if not oriented:
		return coverage_mask(condition_byte)
	return oriented_mask(condition_byte, water_neighborhood, world_cell)


static func oriented_mask(
	condition_byte: int,
	water_neighborhood: PackedByteArray,
	world_cell: Vector2i
) -> int:
	var samples: int = coverage_samples(condition_byte)
	if samples == 0:
		return 0
	if water_neighborhood.size() != 9:
		return COVERAGE_MASKS[samples]

	# Row-major 3x3 input. Non-Water neighbours must be supplied as zero.
	var gradient_x: int = (
		int(water_neighborhood[5]) - int(water_neighborhood[3])
	)
	var gradient_y: int = (
		int(water_neighborhood[7]) - int(water_neighborhood[1])
	)
	var magnitude_x: int = absi(gradient_x)
	var magnitude_y: int = absi(gradient_y)
	var magnitude: int = maxi(magnitude_x, magnitude_y)

	# The 2/255 magnitude and 1/255 dominance tests are exact byte tests.
	# Equal diagonal components, uniform/isolated cells and weak gradients use
	# the registered coverage fallback.
	if magnitude <= GRADIENT_MAGNITUDE_THRESHOLD:
		return COVERAGE_MASKS[samples]
	if absi(magnitude_x - magnitude_y) < DOMINANCE_THRESHOLD:
		return COVERAGE_MASKS[samples]

	var fuller_x: int = 1 if gradient_x > 0 else 0
	var fuller_y: int = 1 if gradient_y > 0 else 0
	var order: Array[int] = []

	if mini(magnitude_x, magnitude_y) > GRADIENT_MAGNITUDE_THRESHOLD:
		# Both components are meaningful: start at the corresponding fuller
		# corner, retain the dominant component for the second sample, then
		# cross the dominant axis and finish at the opposite corner.
		order.append(_subcell_index(fuller_x, fuller_y))
		if magnitude_x > magnitude_y:
			order.append(_subcell_index(fuller_x, 1 - fuller_y))
			order.append(_subcell_index(1 - fuller_x, fuller_y))
		else:
			order.append(_subcell_index(1 - fuller_x, fuller_y))
			order.append(_subcell_index(fuller_x, 1 - fuller_y))
		order.append(_subcell_index(1 - fuller_x, 1 - fuller_y))
	else:
		# Axial gradients contain exact score ties. Coverage order is the
		# base tie-break and world-cell parity reverses each tied pair without
		# introducing frame, camera or scale dependence.
		var odd_cell: bool = posmod(world_cell.x + world_cell.y, 2) == 1
		if magnitude_x > magnitude_y:
			var full_bottom: int = _subcell_index(fuller_x, 1)
			var full_top: int = _subcell_index(fuller_x, 0)
			var empty_bottom: int = _subcell_index(1 - fuller_x, 1)
			var empty_top: int = _subcell_index(1 - fuller_x, 0)
			if odd_cell:
				order.append_array([full_top, full_bottom, empty_top, empty_bottom])
			else:
				order.append_array([full_bottom, full_top, empty_bottom, empty_top])
		else:
			var full_left: int = _subcell_index(0, fuller_y)
			var full_right: int = _subcell_index(1, fuller_y)
			var empty_left: int = _subcell_index(0, 1 - fuller_y)
			var empty_right: int = _subcell_index(1, 1 - fuller_y)
			if odd_cell:
				order.append_array([full_right, full_left, empty_right, empty_left])
			else:
				order.append_array([full_left, full_right, empty_left, empty_right])

	return _mask_from_order(samples, order)


static func sample_is_covered(mask: int, subcell: int) -> bool:
	if subcell < 0 or subcell > 3:
		return false
	return (mask & (1 << subcell)) != 0


static func subcell_at_world_sample(world_sample: Vector2) -> int:
	var local: Vector2 = Vector2(
		fposmod(world_sample.x, 1.0),
		fposmod(world_sample.y, 1.0)
	)
	return _subcell_index(1 if local.x >= 0.5 else 0, 1 if local.y >= 0.5 else 0)


static func covered_sample_count(mask: int) -> int:
	var count: int = 0
	for subcell: int in range(4):
		if sample_is_covered(mask, subcell):
			count += 1
	return count


static func coverage_error(condition_byte: int) -> float:
	return absf(
		float(coverage_samples(condition_byte)) / 4.0
		- float(clampi(condition_byte, 0, 255)) / 255.0
	)


static func changed_sample_count(first_mask: int, second_mask: int) -> int:
	return covered_sample_count(first_mask ^ second_mask)


static func _subcell_index(x: int, y: int) -> int:
	if y == 0:
		return SUBCELL_TOP_RIGHT if x == 1 else SUBCELL_TOP_LEFT
	return SUBCELL_BOTTOM_RIGHT if x == 1 else SUBCELL_BOTTOM_LEFT


static func _mask_from_order(samples: int, order: Array[int]) -> int:
	var mask: int = 0
	for index: int in range(mini(samples, order.size())):
		mask |= 1 << order[index]
	return mask
