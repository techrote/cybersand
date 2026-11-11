extends RefCounted

# PAINT-001: bounded, deterministic cell plans for the existing native worker.
# These are PREVIEWS / candidate commands, not applied-cell receipts. The shared
# workbench host must authorize the plan and retire it on source/World changes.
const MAX_CELLS: int = 4096
const MAX_OPERATION_CELLS: int = 262144
const MAX_RADIUS: int = 24
const MAX_EXTENT: int = 2048

# Accepted native/include/cybersand/material.hpp currently enumerates 0..131
# with slot 10 explicitly invalid. A rejection-only source compatibility
# fence, not an alternative material catalogue or a host authorization.
# Integration must requalify this bound when MAT-AUTH/native source evolves.
const MAX_ACCEPTED_NATIVE_MATERIAL_ID: int = 131


static func _valid_native_material_id(material_id: int) -> bool:
	return material_id >= 0 and material_id <= MAX_ACCEPTED_NATIVE_MATERIAL_ID and material_id != 10


static func _valid_cell_limit(cell_limit: int) -> bool:
	return cell_limit > 0 and cell_limit <= MAX_OPERATION_CELLS


static func _valid_extent(extent: Vector2i) -> bool:
	return extent.x >= 512 and extent.y >= 512 \
		and extent.x <= MAX_EXTENT and extent.y <= MAX_EXTENT \
		and extent.x % 64 == 0 and extent.y % 64 == 0


static func _inside(point: Vector2i, extent: Vector2i) -> bool:
	return point.x >= 0 and point.y >= 0 and point.x < extent.x and point.y < extent.y


static func _refuse(reason: String) -> Dictionary:
	return {"accepted": false, "error": reason, "cells": PackedInt32Array(), "count": 0}


# The key is a bounded row-major cell index, NOT a world pointer or material.
# Each clipped brush point is explicitly reported, never written out of bounds.
static func _include(selected: Dictionary, state: Dictionary, extent: Vector2i, x: int, y: int, cell_limit: int) -> bool:
	if x < 0 or y < 0 or x >= extent.x or y >= extent.y:
		state["clipped"] = true
		return true
	var key: int = y * extent.x + x
	if selected.has(key):
		return true
	if selected.size() >= cell_limit:
		return false
	selected[key] = true
	return true


static func _finish(selected: Dictionary, state: Dictionary, extent: Vector2i) -> Dictionary:
	if selected.is_empty():
		return _refuse("The operation contains no cells.")
	var ordered: Array = selected.keys()
	ordered.sort()
	var cells := PackedInt32Array()
	cells.resize(ordered.size() * 2)
	for i: int in range(ordered.size()):
		var key: int = int(ordered[i])
		cells[i * 2] = key % extent.x
		cells[i * 2 + 1] = int(key / extent.x)
	return {
		"accepted": true,
		"cells": cells,
		"count": ordered.size(),
		"clipped": bool(state.get("clipped", false)),
	}


# Bresenham centreline unioned with the exact integer-radius native disc lattice.
# Radius zero is a one-cell line; every cell is submitted at most once.
static func line(from_cell: Vector2i, to_cell: Vector2i, radius: int, extent: Vector2i, cell_limit: int = MAX_CELLS) -> Dictionary:
	if not _valid_cell_limit(cell_limit):
		return _refuse("Operation cell budget must be between 1 and 262144.")
	if not _valid_extent(extent):
		return _refuse("Canvas extent is not an admitted 512–2048 multiple of 64.")
	if not _inside(from_cell, extent) or not _inside(to_cell, extent):
		return _refuse("Both line endpoints must lie within the canvas.")
	if radius < 0 or radius > MAX_RADIUS:
		return _refuse("Line radius must be between 0 and 24 cells.")
	# Integer Bresenham breaks exact half-cell ties differently in opposite
	# traversal directions. Canonicalize endpoints so reversing a drag produces
	# the exact same material mask, including thick-disc outlines.
	var start_cell: Vector2i = from_cell
	var end_cell: Vector2i = to_cell
	if start_cell.x > end_cell.x or (start_cell.x == end_cell.x and start_cell.y > end_cell.y):
		start_cell = to_cell
		end_cell = from_cell
	var selected := {}
	var state := {"clipped": false}
	var x: int = start_cell.x
	var y: int = start_cell.y
	var dx: int = absi(end_cell.x - x)
	var dy: int = -absi(end_cell.y - y)
	var step_x: int = 1 if x < end_cell.x else -1
	var step_y: int = 1 if y < end_cell.y else -1
	var error: int = dx + dy
	while true:
		for offset_y: int in range(-radius, radius + 1):
			for offset_x: int in range(-radius, radius + 1):
				if offset_x * offset_x + offset_y * offset_y > radius * radius:
					continue
				if not _include(selected, state, extent, x + offset_x, y + offset_y, cell_limit):
					return _refuse("Line exceeds the %d-cell operation budget; shorten the line or reduce the radius." % cell_limit)
		if x == end_cell.x and y == end_cell.y:
			break
		var twice: int = 2 * error
		if twice >= dy:
			error += dy
			x += step_x
		if twice <= dx:
			error += dx
			y += step_y
	return _finish(selected, state, extent)


# Inclusive opposite corners, independent of drag direction. Filled rectangles
# are preflight bounded; outlines visit only the perimeter, not the whole area.
static func rectangle(from_cell: Vector2i, to_cell: Vector2i, filled: bool, extent: Vector2i, cell_limit: int = MAX_CELLS) -> Dictionary:
	if not _valid_cell_limit(cell_limit):
		return _refuse("Operation cell budget must be between 1 and 262144.")
	if not _valid_extent(extent):
		return _refuse("Canvas extent is not an admitted 512–2048 multiple of 64.")
	if not _inside(from_cell, extent) or not _inside(to_cell, extent):
		return _refuse("Both rectangle corners must lie within the canvas.")
	var left: int = mini(from_cell.x, to_cell.x)
	var right: int = maxi(from_cell.x, to_cell.x)
	var top: int = mini(from_cell.y, to_cell.y)
	var bottom: int = maxi(from_cell.y, to_cell.y)
	var width: int = right - left + 1
	var height: int = bottom - top + 1
	if filled and width * height > cell_limit:
		return _refuse("Filled rectangle exceeds the %d-cell operation budget." % cell_limit)
	var perimeter: int = width * height
	if width > 1 and height > 1:
		perimeter = 2 * width + 2 * height - 4
	if not filled and perimeter > cell_limit:
		return _refuse("Outline rectangle exceeds the %d-cell operation budget." % cell_limit)
	# The preflight has already proved the exact count and all bounds. Emit
	# unique rows directly; a large rectangle needs neither a cell dictionary
	# nor a sort. The outline still visits only its perimeter, including one-
	# row/one-column rectangles, and retains the canonical row-major raster.
	var count: int = width * height if filled else perimeter
	var cells := PackedInt32Array()
	cells.resize(count * 2)
	var index: int = 0
	for y: int in range(top, bottom + 1):
		if filled or y == top or y == bottom:
			for x: int in range(left, right + 1):
				cells[index] = x
				cells[index + 1] = y
				index += 2
		else:
			cells[index] = left
			cells[index + 1] = y
			index += 2
			if right != left:
				cells[index] = right
				cells[index + 1] = y
				index += 2
	return {"accepted": true, "cells": cells, "count": count, "clipped": false}

# Uniform-material stencil translation for future copy/paste. The caller must
# separately authorize material, source generation, native owner and revision.
# In particular these coordinates do NOT copy the source's material identities.
# Refuse the WHOLE paste if one point would lie outside either canvas.
static func stamp(
		source_cells: PackedInt32Array,
		source_origin: Vector2i,
		destination_origin: Vector2i,
		extent: Vector2i,
		cell_limit: int = MAX_CELLS
) -> Dictionary:
	if not _valid_cell_limit(cell_limit):
		return _refuse("Operation cell budget must be between 1 and 262144.")
	if not _valid_extent(extent):
		return _refuse("Canvas extent is not an admitted 512–2048 multiple of 64.")
	if not _inside(source_origin, extent) or not _inside(destination_origin, extent):
		return _refuse("Both stencil anchors must lie within the canvas.")
	if source_cells.is_empty() or (source_cells.size() & 1) != 0:
		return _refuse("Stencil requires complete interleaved x,y cell coordinates.")
	if source_cells.size() / 2 > cell_limit:
		return _refuse("Stencil source exceeds the %d-cell operation budget." % cell_limit)
	var offset: Vector2i = destination_origin - source_origin
	var selected := {}
	var state := {"clipped": false}
	for index: int in range(0, source_cells.size(), 2):
		var source_cell := Vector2i(source_cells[index], source_cells[index + 1])
		var destination_cell: Vector2i = source_cell + offset
		if not _inside(source_cell, extent):
			return _refuse("Stencil source contains an out-of-canvas cell.")
		if not _inside(destination_cell, extent):
			return _refuse("Stencil destination extends beyond the canvas; no partial paste.")
		if not _include(selected, state, extent, destination_cell.x, destination_cell.y, cell_limit):
			return _refuse("Stencil exceeds the %d-cell operation budget." % cell_limit)
	return _finish(selected, state, extent)


# Conservative four-neighbor flood-fill of an AUTHORITATIVE, bounded native
# material sample. This never reads a render-projection snapshot: Water pixels
# and ballistic overlays are not authoritative native stored-material IDs.
# A plan cannot be committed without separate current generation/revision
# fencing and an applied native receipt from the shared-workbench host.
# A component touching a cropped sample edge refuses rather than silently
# treating unobserved native cells as a filled boundary.
const MAX_FILL_SAMPLE_CELLS: int = 262144

# Expand only toward the unread boundary that the four-neighbour planner
# actually encountered. The next capture is always complete, within the
# same finite sample budget; it never writes or scans the whole World.
static func grow_fill_capture(region: Rect2i, unread_edge: String,
		extent: Vector2i, cell_limit: int = MAX_FILL_SAMPLE_CELLS) -> Rect2i:
	if not _valid_extent(extent) or not region.has_area() or cell_limit < 1 \
			or region.position.x < 0 or region.position.y < 0 \
			or region.end.x > extent.x or region.end.y > extent.y \
			or region.size.x * region.size.y >= cell_limit:
		return Rect2i()
	var position := region.position
	var size := region.size
	var room := 0
	var growth := 0
	match unread_edge:
		"left", "right":
			room = position.x if unread_edge == "left" else extent.x-region.end.x
			growth = mini(mini(room, size.x), int(cell_limit / size.y)-size.x)
			if growth <= 0: return Rect2i()
			if unread_edge == "left": position.x -= growth
			size.x += growth
		"top", "bottom":
			room = position.y if unread_edge == "top" else extent.y-region.end.y
			growth = mini(mini(room, size.y), int(cell_limit / size.x)-size.y)
			if growth <= 0: return Rect2i()
			if unread_edge == "top": position.y -= growth
			size.y += growth
		_: return Rect2i()
	return Rect2i(position,size)


static func fill_connected(
		seed_cell: Vector2i,
		sample_origin: Vector2i,
		sample_size: Vector2i,
		sample_materials: PackedInt32Array,
		extent: Vector2i,
		cell_limit: int = MAX_CELLS
) -> Dictionary:
	if not _valid_cell_limit(cell_limit):
		return _refuse("Operation cell budget must be between 1 and 262144.")
	if not _valid_extent(extent):
		return _refuse("Canvas extent is not an admitted 512–2048 multiple of 64.")
	if sample_size.x <= 0 or sample_size.y <= 0:
		return _refuse("Connected fill requires a nonempty native source sample.")
	if not _inside(sample_origin, extent) or sample_origin.x + sample_size.x > extent.x \
			or sample_origin.y + sample_size.y > extent.y:
		return _refuse("Connected fill source sample lies outside the native canvas.")
	var sample_area: int = sample_size.x * sample_size.y
	if sample_area > MAX_FILL_SAMPLE_CELLS:
		return _refuse("Connected fill source sample exceeds 262144 material cells.")
	if sample_materials.size() != sample_area:
		return _refuse("Connected fill requires exactly one authoritative material ID per sampled cell.")
	if seed_cell.x < sample_origin.x or seed_cell.y < sample_origin.y \
			or seed_cell.x >= sample_origin.x + sample_size.x \
			or seed_cell.y >= sample_origin.y + sample_size.y:
		return _refuse("Connected fill seed lies outside the captured source sample.")
	# The material snapshot is not a display RGB mask; invalid/unknown values
	# must refuse, not act as false component barriers.
	for material_id: int in sample_materials:
		if not _valid_native_material_id(material_id):
			return _refuse("Connected fill source contains an unknown or reserved native material ID.")
	var local_seed: Vector2i = seed_cell - sample_origin
	var seed_index: int = local_seed.y * sample_size.x + local_seed.x
	var source_material_id: int = sample_materials[seed_index]
	var visited := PackedByteArray()
	visited.resize(sample_area)
	visited[seed_index] = 1
	var pending := PackedInt32Array()
	pending.append(seed_index)
	var head: int = 0
	var selected := {}
	var state := {"clipped": false}
	while head < pending.size():
		var index: int = pending[head]
		head += 1
		var local_x: int = index % sample_size.x
		var local_y: int = int(index / sample_size.x)
		var world_x: int = sample_origin.x + local_x
		var world_y: int = sample_origin.y + local_y
		# A target component that reaches an unknown adjacent source cell
		# cannot be proved complete. Actual canvas edges are known boundaries.
		var unread_edge := ""
		if local_x == 0 and world_x > 0: unread_edge = "left"
		elif local_x == sample_size.x - 1 and world_x < extent.x - 1: unread_edge = "right"
		elif local_y == 0 and world_y > 0: unread_edge = "top"
		elif local_y == sample_size.y - 1 and world_y < extent.y - 1: unread_edge = "bottom"
		if not unread_edge.is_empty():
			var cropped := _refuse("Connected fill reaches an unread capture edge.")
			cropped["unread_edge"] = unread_edge
			return cropped
		if not _include(selected, state, extent, world_x, world_y, cell_limit):
			return _refuse("Connected fill exceeds the %d-cell operation budget." % cell_limit)
		# Explicit 4-neighbor connectivity; no diagonal leaks or recursive DFS.
		for direction: int in range(4):
			var neighbor_x: int = local_x
			var neighbor_y: int = local_y
			match direction:
				0: neighbor_x -= 1
				1: neighbor_x += 1
				2: neighbor_y -= 1
				3: neighbor_y += 1
			if neighbor_x < 0 or neighbor_y < 0 \
					or neighbor_x >= sample_size.x or neighbor_y >= sample_size.y:
				continue
			var neighbor_index: int = neighbor_y * sample_size.x + neighbor_x
			if visited[neighbor_index] != 0 \
					or sample_materials[neighbor_index] != source_material_id:
				continue
			if pending.size() >= cell_limit:
				return _refuse("Connected fill exceeds the %d-cell operation budget; no partial fill." % cell_limit)
			visited[neighbor_index] = 1
			pending.append(neighbor_index)
	var plan: Dictionary = _finish(selected, state, extent)
	plan["source_material_id"] = source_material_id
	return plan


# PAINT-001 staging-only multi-material paste. Each ID must come from ONE
# authoritative, revision-fenced native capture in exactly source-cell order.
# This function cannot establish that provenance: the host must provide and
# recheck it. All groups are a single indivisible future transaction, NEVER
# independent queue_emit_cells commands (which cannot roll back as a unit).
# Includes native Empty material 0, for which the host must authorize erase.
static func stamp_materials(
		source_cells: PackedInt32Array,
		source_materials: PackedInt32Array,
		source_origin: Vector2i,
		destination_origin: Vector2i,
		extent: Vector2i,
		cell_limit: int = MAX_CELLS
) -> Dictionary:
	if not _valid_cell_limit(cell_limit):
		return _refuse("Operation cell budget must be between 1 and 262144.")
	if not _valid_extent(extent):
		return _refuse("Canvas extent is not an admitted 512–2048 multiple of 64.")
	if not _inside(source_origin, extent) or not _inside(destination_origin, extent):
		return _refuse("Multi-material stencil anchors must lie within the canvas.")
	if source_cells.is_empty() or (source_cells.size() & 1) != 0:
		return _refuse("Multi-material stencil requires complete interleaved x,y coordinates.")
	var source_count: int = int(source_cells.size() / 2)
	if source_count > cell_limit:
		return _refuse("Multi-material stencil exceeds the %d-cell operation budget." % cell_limit)
	if source_materials.size() != source_count:
		return _refuse("Multi-material stencil must include one native material ID per source cell.")
	var shift: Vector2i = destination_origin - source_origin
	var selected := {}
	var material_at_key := {}
	var state := {"clipped": false}
	for i: int in range(source_count):
		var material_id: int = source_materials[i]
		if not _valid_native_material_id(material_id):
			return _refuse("Multi-material stencil contains an unknown or reserved native material ID.")
		var source: Vector2i = Vector2i(source_cells[i * 2], source_cells[i * 2 + 1])
		var destination: Vector2i = source + shift
		if not _inside(source, extent) or not _inside(destination, extent):
			return _refuse("Multi-material stencil extends beyond the canvas; no partial paste.")
		var key: int = destination.y * extent.x + destination.x
		if material_at_key.has(key):
			if int(material_at_key[key]) != material_id:
				return _refuse("Multi-material stencil assigns conflicting material IDs to one cell.")
			continue
		material_at_key[key] = material_id
		if not _include(selected, state, extent, destination.x, destination.y, cell_limit):
			return _refuse("Multi-material stencil exceeds the %d-cell operation budget." % cell_limit)
	var plan: Dictionary = _finish(selected, state, extent)
	if not plan.get("accepted", false):
		return plan
	# The worker consumes one immutable row-major cell/material packet. Keep
	# the existing grouped preview while exposing the same exact assignments
	# aligned with plan.cells, including Empty and overlapping-source pastes.
	var ordered_cells: PackedInt32Array = plan.cells
	var ordered_materials := PackedInt32Array()
	ordered_materials.resize(int(ordered_cells.size() / 2))
	for i: int in range(ordered_materials.size()):
		var key: int = ordered_cells[i * 2 + 1] * extent.x + ordered_cells[i * 2]
		ordered_materials[i] = int(material_at_key[key])
	plan["materials"] = ordered_materials
	# Deterministic group order by numeric native ID; within each group
	# _finish sorts world-space coordinates in row-major order.
	var by_material := {}
	for key: int in material_at_key:
		var material_id: int = int(material_at_key[key])
		if not by_material.has(material_id):
			by_material[material_id] = {}
		var members: Dictionary = by_material[material_id]
		members[key] = true
	var material_ids: Array = by_material.keys()
	material_ids.sort()
	var groups: Array[Dictionary] = []
	for id_value: int in material_ids:
		var subset: Dictionary = _finish(by_material[id_value], state, extent)
		groups.append({
			"material_id": id_value,
			"count": subset["count"],
			"cells": subset["cells"],
		})
	plan["groups"] = groups
	plan["staging_only"] = true
	plan["atomic_commit_required"] = true
	plan["applied"] = false
	return plan
