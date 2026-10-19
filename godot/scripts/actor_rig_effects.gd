class_name CyberActorRigEffects
extends RefCounted

# Owner-local gameplay tools, deliberately separate from native explosion
# events/pressure or Rapier impulses. Each changed pixel uses the existing
# adapter write, preserving native waking/revision/material authority.
const NONE: int = 0
const DIG: int = 1
const BLAST: int = 2
const MAX_RADIUS: int = 4
const MAX_READS: int = 64
const MAX_WRITES: int = 64
const WORLD_LIMIT: int = 1024

var reads_last: int = 0
var writes_last: int = 0
var kind: int = NONE
var origin: Vector2 = Vector2.ZERO
var radius: float = 0.0
var strength: float = 0.0
var _materials: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_materials.resize(81)
	_materials.fill(1)


func clear() -> void:
	reads_last = 0
	writes_last = 0
	kind = NONE
	origin = Vector2.ZERO
	radius = 0.0
	strength = 0.0


func apply(world, requested_kind: int, target: Vector2, requested_radius: int, power: float = 1.0) -> void:
	# At most one effect per actor update. No deferred effect survives cancellation.
	if kind != NONE or world == null or not target.is_finite() or not is_finite(power):
		return
	# Guard the floating-point coordinates before narrowing to Vector2i: very
	# large finite values can otherwise wrap into apparently valid grid cells.
	if target.x < 0.0 or target.y < 0.0 or target.x >= float(WORLD_LIMIT) or target.y >= float(WORLD_LIMIT):
		return
	if requested_kind != DIG and requested_kind != BLAST:
		return
	if not world.has_method(&"material_at") or not world.has_method(&"emit_disc"):
		return
	if world.has_method(&"has_failed") and bool(world.has_failed()):
		return
	var centre: Vector2i = Vector2i(floori(target.x), floori(target.y))
	if centre.x < 0 or centre.y < 0 or centre.x >= WORLD_LIMIT or centre.y >= WORLD_LIMIT:
		return
	var bounded_radius: int = clampi(requested_radius, 1, MAX_RADIUS)
	kind = requested_kind
	origin = Vector2(centre) + Vector2(0.5, 0.5)
	radius = float(bounded_radius)
	strength = clampf(power, 0.0, 1.0)
	var squared_radius: int = bounded_radius * bounded_radius
	_materials.fill(1)
	# Sample the complete bounded footprint once. Cached supercover checks below
	# prevent a tool disc reaching through a protected one-cell wall, without a
	# ray/world query for every target pixel.
	for offset_y: int in range(-bounded_radius, bounded_radius + 1):
		for offset_x: int in range(-bounded_radius, bounded_radius + 1):
			if offset_x * offset_x + offset_y * offset_y > squared_radius:
				continue
			if reads_last >= MAX_READS:
				return
			var x: int = centre.x + offset_x
			var y: int = centre.y + offset_y
			if x < 0 or y < 0 or x >= WORLD_LIMIT or y >= WORLD_LIMIT:
				continue
			reads_last += 1
			_materials[_index(offset_x, offset_y)] = int(world.material_at(x, y))
	for offset_y: int in range(-bounded_radius, bounded_radius + 1):
		for offset_x: int in range(-bounded_radius, bounded_radius + 1):
			if offset_x * offset_x + offset_y * offset_y > squared_radius:
				continue
			if writes_last >= MAX_WRITES:
				return
			var x: int = centre.x + offset_x
			var y: int = centre.y + offset_y
			if x < 0 or y < 0 or x >= WORLD_LIMIT or y >= WORLD_LIMIT:
				continue
			var before: int = _materials[_index(offset_x, offset_y)]
			var fire_centre: bool = requested_kind == BLAST and offset_x == 0 and offset_y == 0
			# Wall includes the native composed Rapier mask and the boundary.
			# Protected surfaces stay protected, including at a blast's centre.
			if not editable_material(before) and not (fire_centre and before == 0):
				continue
			if not _unoccluded(offset_x, offset_y):
				continue
			var replacement: int = 6 if fire_centre else 0
			if replacement == before:
				continue
			world.emit_disc(x, y, 0, replacement)
			writes_last += 1


func _unoccluded(target_x: int, target_y: int) -> bool:
	if protected_material(_materials[_index(0, 0)]):
		return false
	var x: int = 0
	var y: int = 0
	var step_x: int = signi(target_x)
	var step_y: int = signi(target_y)
	var delta_x: float = 1.0 / absf(float(target_x)) if target_x != 0 else INF
	var delta_y: float = 1.0 / absf(float(target_y)) if target_y != 0 else INF
	var next_x: float = 0.5 * delta_x
	var next_y: float = 0.5 * delta_y
	for _step: int in range(9):
		if x == target_x and y == target_y:
			return true
		if absf(next_x - next_y) < 0.000001:
			if protected_material(_materials[_index(x + step_x, y)]) \
				or protected_material(_materials[_index(x, y + step_y)]):
				return false
			x += step_x
			y += step_y
			next_x += delta_x
			next_y += delta_y
		elif next_x < next_y:
			x += step_x
			next_x += delta_x
		else:
			y += step_y
			next_y += delta_y
		if protected_material(_materials[_index(x, y)]):
			return false
	return false


static func _index(x: int, y: int) -> int:
	return (y + MAX_RADIUS) * 9 + x + MAX_RADIUS


static func protected_material(material: int) -> bool:
	return material == 1 or material == 5 or material == 28 or material == 31 \
		or (material >= 38 and material <= CyberCellWorld.LAST_MATERIAL and not editable_material(material))


static func editable_material(material: int) -> bool:
	# Fixed authored tool envelope. Wall, Cloner, free liquids, load-bearing metal,
	# reinforced concrete, lamps and transient body masks cannot be excavated.
	match material:
		2, 7, 9, 11, 13, 14, 18, 19, 20, 21, 23, 25, 26, 27, 29, 30, 35, \
		38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 55, 56, 57, 59, \
		60, 61, 65, 70, 71, 72, 73, 74, 75:
			return true
		_:
			return false
