extends RefCounted

# PAINT-001: bounded, deterministic cell plans for the existing native worker.
# These are PREVIEWS / candidate commands, not applied-cell receipts. The shared
# workbench host must authorize the plan and retire it on source/World changes.
const MAX_CELLS: int = 4096
const MAX_RADIUS: int = 24
const MAX_EXTENT: int = 2048


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
static func _include(selected: Dictionary, state: Dictionary, extent: Vector2i, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= extent.x or y >= extent.y:
		state["clipped"] = true
		return true
	var key: int = y * extent.x + x
	if selected.has(key):
		return true
	if selected.size() >= MAX_CELLS:
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
static func line(from_cell: Vector2i, to_cell: Vector2i, radius: int, extent: Vector2i) -> Dictionary:
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
				if not _include(selected, state, extent, x + offset_x, y + offset_y):
					return _refuse("Line exceeds one native 4096-cell command; shorten the line or reduce the radius.")
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
static func rectangle(from_cell: Vector2i, to_cell: Vector2i, filled: bool, extent: Vector2i) -> Dictionary:
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
	if filled and width * height > MAX_CELLS:
		return _refuse("Filled rectangle exceeds one native 4096-cell command.")
	var perimeter: int = width * height
	if width > 1 and height > 1:
		perimeter = 2 * width + 2 * height - 4
	if not filled and perimeter > MAX_CELLS:
		return _refuse("Outline rectangle exceeds one native 4096-cell command.")
	var selected := {}
	var state := {"clipped": false}
	if filled:
		for y: int in range(top, bottom + 1):
			for x: int in range(left, right + 1):
				if not _include(selected, state, extent, x, y):
					return _refuse("Filled rectangle exceeds the command capacity.")
	else:
		for x: int in range(left, right + 1):
			if not _include(selected, state, extent, x, top) or not _include(selected, state, extent, x, bottom):
				return _refuse("Outline rectangle exceeds the command capacity.")
		for y: int in range(top + 1, bottom):
			if not _include(selected, state, extent, left, y) or not _include(selected, state, extent, right, y):
				return _refuse("Outline rectangle exceeds the command capacity.")
	return _finish(selected, state, extent)
