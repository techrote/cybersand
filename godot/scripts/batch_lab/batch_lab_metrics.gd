extends RefCounted
## Bounded material-plane diagnostics. These do not assign aesthetic or playable-design success.

static func evaluate_materials(config: Dictionary, before: PackedInt32Array, after: PackedInt32Array) -> Dictionary:
	var extent: Array = config.get("extent", [])
	if extent.size() != 2: return {"valid": false, "reason": "Missing extent."}
	var width := int(extent[0])
	var height := int(extent[1])
	if width < 1 or height < 1 or width > 512 or height > 512 or before.size() != width * height or after.size() != before.size():
		return {"valid": false, "reason": "Material plane does not match bounded extent."}
	var targets: Dictionary = config.get("metrics_targets", {})
	var structures: Array = targets.get("structural_materials", [58])
	# source_region selects an input crop in the source world's coordinates.
	# Captured result planes and authoring operations use tile-local coordinates.
	# The native owner separately checks the full arena outside this footprint.
	var scope := Rect2i(0, 0, width, height)
	var guards: Array = config.get("protection", [])
	var mask := PackedByteArray()
	mask.resize(after.size())
	var changed := 0
	var empty := 0
	var structure_cells := 0
	var protected_changed := 0
	var outside_scope_changed := 0
	for index: int in range(after.size()):
		var point := Vector2i(index % width, index / width)
		if after[index] == 0: empty += 1
		if after[index] in structures:
			mask[index] = 1
			structure_cells += 1
		if before[index] == after[index]: continue
		changed += 1
		if not scope.has_point(point): outside_scope_changed += 1
		var protected_cell := before[index] not in [0, 58]
		for guard: Variant in guards:
			if _rect(guard).has_point(point): protected_cell = true
		if protected_cell: protected_changed += 1
	var components := _components(mask, width, height)
	var features: Array = []
	var feature_pass := true
	for feature: Dictionary in targets.get("features", []):
		var box := _rect(feature.get("rect", [])).intersection(Rect2i(0, 0, width, height))
		var count := 0
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				if mask[y * width + x] != 0: count += 1
		var fraction := float(count) / float(maxi(1, box.get_area()))
		var present := box.get_area() > 0 and fraction >= float(feature.get("minimum_fraction", 0.1))
		feature_pass = feature_pass and present
		features.append({"name": feature.get("name", "unnamed"), "structural_cells": count, "fraction": fraction, "present_proxy": present})
	var route: Array = targets.get("route", [])
	var clearance: Dictionary = {"applicable": false, "connected": false}
	if route.size() == 2:
		clearance = _clearance(after, width, height, route, int(targets.get("clearance_radius", 2)))
	var empty_fraction := float(empty) / float(after.size())
	var void_fraction: Variant = null
	if targets.has("void_rect"):
		var box := _rect(targets.void_rect).intersection(Rect2i(0, 0, width, height))
		var void_count := 0
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				if after[y * width + x] == 0: void_count += 1
		void_fraction = float(void_count) / float(maxi(1, box.get_area()))
	var connected_ok := not bool(targets.get("require_connected", false)) or int(components.count) == 1
	var route_ok := not bool(clearance.applicable) or bool(clearance.connected)
	return {"valid": true, "changed_cells": changed, "protected_changed_cells": protected_changed,
		"outside_scope_changed_cells": outside_scope_changed, "empty_fraction": empty_fraction,
		"declared_void_empty_fraction": void_fraction, "structural_cells": structure_cells,
		"structural_components": components.count, "largest_component_cells": components.largest,
		"largest_component_fraction": float(components.largest) / float(maxi(1, structure_cells)),
		"clearance": clearance, "features": features, "all_feature_proxies_present": feature_pass,
		"structural_checks_pass": protected_changed == 0 and outside_scope_changed == 0 and connected_ok and route_ok and feature_pass and empty_fraction >= float(targets.get("minimum_empty_fraction", 0.0)),
		"scope": "Full native stored-material plane; geometric diagnostics only. No aesthetic, gravity-aware traversal, actor-physics or prompt-quality verdict."}

static func _rect(value: Variant) -> Rect2i:
	if value is Rect2i: return value
	if value is Array and value.size() == 4: return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))
	return Rect2i()

static func _components(mask: PackedByteArray, width: int, height: int) -> Dictionary:
	var seen := PackedByteArray()
	seen.resize(mask.size())
	var count := 0
	var largest := 0
	for start: int in range(mask.size()):
		if mask[start] == 0 or seen[start] != 0: continue
		count += 1
		var queue := PackedInt32Array([start])
		seen[start] = 1
		var cursor := 0
		while cursor < queue.size():
			var at := queue[cursor]
			cursor += 1
			for next: int in _neighbors(at, width, height):
				if mask[next] != 0 and seen[next] == 0:
					seen[next] = 1
					queue.append(next)
		largest = maxi(largest, queue.size())
	return {"count": count, "largest": largest}

static func _neighbors(index: int, width: int, height: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if index % width > 0: result.append(index - 1)
	if index % width + 1 < width: result.append(index + 1)
	if index >= width: result.append(index - width)
	if index + width < width * height: result.append(index + width)
	return result

static func _clearance(cells: PackedInt32Array, width: int, height: int, route: Array, radius: int) -> Dictionary:
	radius = clampi(radius, 0, 16)
	var prefix := PackedInt32Array()
	prefix.resize((width + 1) * (height + 1))
	for y: int in range(height):
		var row := 0
		for x: int in range(width):
			row += 0 if cells[y * width + x] == 0 else 1
			prefix[(y + 1) * (width + 1) + x + 1] = prefix[y * (width + 1) + x + 1] + row
	var free := PackedByteArray()
	free.resize(cells.size())
	for y: int in range(radius, height - radius):
		for x: int in range(radius, width - radius):
			var x0 := x - radius
			var y0 := y - radius
			var x1 := x + radius + 1
			var y1 := y + radius + 1
			var occupied := prefix[y1 * (width + 1) + x1] - prefix[y0 * (width + 1) + x1] - prefix[y1 * (width + 1) + x0] + prefix[y0 * (width + 1) + x0]
			if occupied == 0: free[y * width + x] = 1
	var a := Vector2i(int(route[0][0]), int(route[0][1]))
	var b := Vector2i(int(route[1][0]), int(route[1][1]))
	var bounds := Rect2i(0, 0, width, height)
	var connected := false
	var visited := 0
	if bounds.has_point(a) and bounds.has_point(b) and free[a.y * width + a.x] != 0 and free[b.y * width + b.x] != 0:
		var queue := PackedInt32Array([a.y * width + a.x])
		free[a.y * width + a.x] = 0
		while visited < queue.size():
			var at := queue[visited]
			visited += 1
			if at == b.y * width + b.x:
				connected = true
				break
			for next: int in _neighbors(at, width, height):
				if free[next] != 0:
					free[next] = 0
					queue.append(next)
	return {"applicable": true, "connected": connected, "square_width": radius * 2 + 1,
		"visited_centres": visited, "scope": "Geometric clearance only; no native actor traversal claim."}
