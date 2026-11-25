extends RefCounted

## Independent observers for the opt-in goblin application test scene.
## Policies never call these checks and never supply expected native outcomes.
## Deliberately inconsistent dictionaries belong only in the contract unit test.
const Expanded = preload("res://goblin/goblin_gameplay_oracles.gd")
const EDITS := ["brush", "erase", "rectangle", "outline", "line", "fill", "paste", "stroke"]
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _clipboard: Dictionary = {}
var _saved_identity: String = ""
var _saved_native_tick := -1
var _saved_capture: Dictionary = {}
var _saved_observation: Dictionary = {}
var _last_native: Dictionary = {}
var _material_state := "unknown"
var _material_source: Dictionary = {}
var _material_reset: Dictionary = {}
var _material_exposure: Dictionary = {}
var _saved_material_state := "unknown"
var _saved_material_lineage: Dictionary = {}


func reset(initialization: Dictionary = {}) -> void:
	_undo.clear()
	_redo.clear()
	_clipboard.clear()
	_saved_identity = ""
	_saved_native_tick = -1
	_saved_capture.clear()
	_saved_observation.clear()
	_last_native.clear()
	_material_state = "unknown"
	_material_source.clear()
	_material_reset.clear()
	_material_exposure.clear()
	_saved_material_state = "unknown"
	_saved_material_lineage.clear()
	var observed: Dictionary = initialization.get("observation", {})
	var native: Dictionary = observed.get("native", {})
	var receipt: Dictionary = initialization.get("native_receipt", {})
	if initialization.get("ok") == true and observed.get("paused") == true and native.get("paused") == true \
		and native.get("tick") == 0 and not str(observed.get("scene_identity", "")).is_empty() \
		and observed.get("authored_digest") == observed.get("scene_identity") and _lineage_receipt(receipt, native):
		_material_state = "authored_compatible"
		_material_source = _lineage_source(native)
		_material_reset = {"source": _material_source.duplicate(true), "receipt_hash": receipt.receipt_hash}


static func _assert(rows: Array[Dictionary], id: String, ok: bool, expected: Variant,
		actual: Variant, kind: String = "gameplay", reason: String = "") -> void:
	rows.append({"id": id, "status": "pass" if ok else "fail", "kind": kind,
		"expected": expected, "actual": actual, "reason": reason})


static func _unavailable(rows: Array[Dictionary], id: String, reason: String) -> void:
	rows.append({"id": id, "status": "not_applicable", "kind": "evidence",
		"expected": null, "actual": null, "reason": reason})


static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _same(first: Variant, second: Variant) -> bool:
	# JSON parses numbers as doubles; actual Vector2 camera origins are doubles
	# too. Compare numerical values, never Array's integral/floating type tags.
	if (first is int or first is float) and (second is int or second is float): return first == second
	if first is Array and second is Array:
		if first.size() != second.size(): return false
		for index: int in range(first.size()):
			if not _same(first[index], second[index]): return false
		return true
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size(): return false
		for key: Variant in first:
			if not second.has(key) or not _same(first[key], second[key]): return false
		return true
	return first == second


static func _capture_valid(capture: Dictionary) -> bool:
	var region: Variant = capture.get("region", [])
	var values: Variant = capture.get("materials", [])
	if not region is Array or region.size() != 4 or not values is Array: return false
	for value: Variant in region:
		if not _integer(value): return false
	if region[2] <= 0 or region[3] <= 0 or region[2] * region[3] > 4096: return false
	if values.size() != int(region[2]) * int(region[3]): return false
	for value: Variant in values:
		if not _integer(value) or value < 0 or value > 131 or value == 10: return false
	var receipt: Dictionary = capture.get("native_receipt", {})
	return receipt.get("status") == "completed" and receipt.get("kind") == "capture" \
		and receipt.get("backend") == "CyberNativeCellWorld"


static func _capture_matches(capture: Dictionary, native: Dictionary) -> bool:
	var receipt: Dictionary = capture.get("native_receipt", {})
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(receipt.get(key)) or receipt[key] != native.get(key): return false
	return receipt.get("observed_generation") == native.get("generation") \
		and _same(receipt.get("region"), capture.get("region"))


static func _persistence_capture_state(capture: Dictionary, observation: Dictionary) -> String:
	# A whole-layout capture can be unavailable where a real body protects its
	# covered cells. Only this exact observed refusal admits that limitation.
	for key: String in ["native_receipt", "admission", "source_before", "source_after"]:
		if not capture.get(key, {}) is Dictionary: return "invalid"
	if not observation.get("native", {}) is Dictionary or not observation.get("actor_ids", []) is Array \
		or not observation.get("actors", []) is Array: return "invalid"
	var receipt: Dictionary = capture.get("native_receipt", {})
	var admission: Dictionary = capture.get("admission", {})
	var source_before: Dictionary = capture.get("source_before", {})
	var source_after: Dictionary = capture.get("source_after", {})
	var native: Dictionary = observation.get("native", {})
	if not _same(capture.get("region"), [0, 0, 512, 512]) or not _capture_matches(capture, native): return "invalid"
	if receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld": return "invalid"
	if admission.get("status") != "queued" or not _integer(admission.get("operation_id")) \
		or receipt.get("operation_id") != admission.get("operation_id"): return "invalid"
	for source: Dictionary in [source_before, source_after]:
		if source.get("paused") != true or source.get("failed") != false: return "invalid"
		for key: String in ["generation", "revision", "tick"]:
			if not _integer(source.get(key)) or source.get(key) != native.get(key): return "invalid"
	if observation.get("paused") != true or native.get("failed") != false: return "invalid"
	if receipt.get("status") == "completed" and not capture.has("error") \
		and capture.get("count") == 512 * 512 and str(capture.get("material_sha256", "")).length() == 64: return "completed"
	if receipt.get("status") != "refused" or receipt.get("reason") != "Move or remove the body before editing or copying its covered cells." \
		or receipt.get("applied") != 0 or receipt.get("changed") != 0 or not capture.has("error"): return "invalid"
	var actor_ids: Array = observation.get("actor_ids", [])
	for actor: Variant in observation.get("actors", []):
		if actor is Dictionary and actor.get("observed") == true and actor.get("id") in actor_ids: return "native_body_protection"
	return "invalid"


static func _native_valid(native: Dictionary) -> bool:
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(native.get(key)) or native[key] < 0: return false
	return native.get("failed") is bool


static func _adapter_version(observation: Dictionary) -> int:
	var value: Variant = observation.get("adapter_version", 1)
	return int(value) if _integer(value) and value >= 1 and value <= 3 else 0


static func _lineage_source(native: Dictionary) -> Dictionary:
	return {"generation": native.get("generation", -1), "revision": native.get("revision", -1), "tick": native.get("tick", -1)}


static func _lineage_receipt(receipt: Dictionary, native: Dictionary) -> bool:
	# Independent receipt custody, without invoking the adapter's tracker.
	if not _native_valid(native) or native.get("failed") != false or receipt.get("kind") != "applied_run" \
		or not _integer(receipt.get("schema_version")) or receipt.schema_version != 1 \
		or not _integer(receipt.get("completed_tick")) or receipt.completed_tick != 0 \
		or not _integer(receipt.get("session_generation")) or receipt.session_generation != native.get("generation"): return false
	var bytes: Variant = receipt.get("canonical_bytes")
	if not bytes is Array or bytes.size() < 52 or bytes.size() > 1048576: return false
	for value: Variant in bytes:
		if not _integer(value) or value < 0 or value > 255: return false
	var domain: PackedByteArray = "cybersand-run-receipt-v1".to_utf8_buffer()
	if bytes[0] != 24 or bytes[1] != 0 or bytes[2] != 0 or bytes[3] != 0 \
		or bytes[28] != 1 or bytes[29] != 0: return false
	for index: int in range(24):
		if bytes[index + 4] != domain[index]: return false
	var encoded_generation: int = 0
	for index: int in range(8):
		encoded_generation |= int(bytes[index + 36]) << (index * 8)
		if bytes[index + 44] != 0: return false
	if encoded_generation != int(native.generation): return false
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(PackedByteArray(bytes))
	return digest.finish().hex_encode() == receipt.get("receipt_hash")


func _lineage_observe(observation: Dictionary) -> void:
	var native: Dictionary = observation.get("native", {})
	if not _native_valid(native) or native.get("failed") != false:
		_material_state = "unknown"
	elif int(native.tick) > 0:
		_material_state = "simulation_exposed"
		_material_exposure = _lineage_source(native)
	elif _material_source.is_empty() or _material_source.get("generation") != native.generation:
		_material_state = "unknown"
	elif _material_state != "simulation_exposed":
		if observation.get("paused") != true or native.get("paused") != true \
			or native.tick < _material_source.get("tick", 0) or native.revision < _material_source.get("revision", 0):
			_material_state = "unknown"
	_material_source = _lineage_source(native)


func _lineage_claim_valid(observation: Dictionary) -> bool:
	var lineage: Variant = observation.get("material_lineage")
	var native: Dictionary = observation.get("native", {})
	if not lineage is Dictionary or lineage.get("schema") != "cybersand-goblin-material-lineage-v1" \
		or lineage.get("state") != _material_state or not lineage.get("source") is Dictionary \
		or lineage.source.size() != 3 or not _same(lineage.source, _lineage_source(native)): return false
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(lineage.source.get(key)) or lineage.source[key] < 0: return false
	var witness: Variant = lineage.get("witness")
	if not witness is Dictionary or not witness.get("source") is Dictionary: return false
	var origin: Dictionary = witness.source
	if origin.size() != 3: return false
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(origin.get(key)) or origin[key] < 0: return false
	if origin.generation > native.get("generation", -1): return false
	match _material_state:
		"authored_compatible":
			return witness.get("kind") == "authored_construction" and origin.tick == 0 \
				and witness.get("action") in ["fixture_install", "reset_fixture", "replace_fixture", "restore_start", "reopen_layout"] \
				and not _material_reset.is_empty() and _same(origin, _material_reset.source) \
				and witness.get("receipt_hash") == _material_reset.receipt_hash
		"simulation_exposed":
			return witness.get("kind") == "native_progress" and origin.tick > 0 \
				and not _material_exposure.is_empty() and _same(origin, _material_exposure)
		"unknown":
			return witness.get("kind") in ["invalid_source", "unobserved_generation", "unobserved_running", "nonmonotonic_source",
				"unproven_retained_lineage", "unacknowledged_replacement", "partial_native_effect"]
	return false


func _lineage_checks(record: Dictionary, rows: Array[Dictionary]) -> void:
	var before: Dictionary = record.get("before", {})
	var after: Dictionary = record.get("after", {})
	var first: Dictionary = before.get("native", {})
	var last: Dictionary = after.get("native", {})
	_lineage_observe(before)
	_assert(rows, "material_lineage_before", _lineage_claim_valid(before),
		{"state": _material_state, "source": _material_source}, before.get("material_lineage"), "evidence")
	var prior: String = _material_state
	var id: String = str(record.get("action", {}).get("id", ""))
	var complete: bool = record.get("status") == "completed" and record.get("admission", {}).get("accepted") == true
	var replaced: bool = _native_valid(first) and _native_valid(last) and int(last.generation) > int(first.generation)
	var fresh: bool = id in ["reset_fixture", "replace_fixture", "restore_start", "reopen_layout"]
	var retaining: bool = id in ["actor_place", "actor_reset", "actor_remove", "actor_move", "actor_replace", "actor_equipment", "response_mode", "actor_settings"]
	if replaced and complete and (fresh or retaining):
		var receipt: Dictionary = record.get("native_receipt", {})
		var acknowledged: bool = _lineage_receipt(receipt, last)
		_assert(rows, "material_lineage_replacement_evidence", acknowledged,
			"actual canonical construction receipt for this replacement generation", receipt.get("receipt_hash"), "evidence")
		if fresh and acknowledged and after.get("paused") == true and last.get("paused") == true and last.get("tick") == 0:
			_material_state = "authored_compatible"
			_material_source = _lineage_source(last)
			_material_reset = {"source": _material_source.duplicate(true), "receipt_hash": receipt.receipt_hash}
		elif retaining and acknowledged:
			if prior == "simulation_exposed": _material_state = prior
			elif prior == "authored_compatible" and before.get("paused") == true and first.get("paused") == true \
				and after.get("paused") == true and last.get("paused") == true and first.get("tick") == 0 and last.get("tick") == 0:
				_material_state = prior
			else: _material_state = "unknown"
			_material_source = _lineage_source(last)
		else: _material_state = "unknown"
	elif replaced: _material_state = "unknown"
	elif not complete and _native_valid(first) and _native_valid(last) and first.revision != last.revision \
		and prior != "simulation_exposed": _material_state = "unknown"
	_lineage_observe(after)
	_assert(rows, "material_lineage_after", _lineage_claim_valid(after),
		{"state": _material_state, "source": _material_source}, after.get("material_lineage"), "evidence")


static func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func _shape_points(id: String, args: Dictionary) -> Dictionary:
	var points := {}
	if id in ["brush", "erase"]:
		var radius: int = int(args.get("radius", 0))
		for y: int in range(int(args.y) - radius, int(args.y) + radius + 1):
			for x: int in range(int(args.x) - radius, int(args.x) + radius + 1):
				if (x - int(args.x)) ** 2 + (y - int(args.y)) ** 2 <= radius ** 2:
					points[_point_key(x, y)] = true
	elif id in ["rectangle", "outline"]:
		var left: int = mini(int(args.x0), int(args.x1))
		var right: int = maxi(int(args.x0), int(args.x1))
		var top: int = mini(int(args.y0), int(args.y1))
		var bottom: int = maxi(int(args.y0), int(args.y1))
		for y: int in range(top, bottom + 1):
			for x: int in range(left, right + 1):
				if id == "rectangle" or x in [left, right] or y in [top, bottom]:
					points[_point_key(x, y)] = true
	elif id in ["line", "stroke"]:
		# Independent direct integer interpolation, not the editor's incremental
		# Bresenham state machine. Canonical orientation defines half-cell ties.
		var start := Vector2i(int(args.x0), int(args.y0))
		var finish := Vector2i(int(args.x1), int(args.y1))
		if start.x > finish.x or (start.x == finish.x and start.y > finish.y):
			var swap := start
			start = finish
			finish = swap
		var dx: int = finish.x - start.x
		var dy: int = absi(finish.y - start.y)
		var direction: int = 1 if finish.y >= start.y else -1
		var span: int = maxi(dx, dy)
		for step: int in range(span + 1):
			var x: int = start.x
			var y: int = start.y
			if span > 0 and dx >= dy:
				x += step
				y += direction * int((2 * step * dy + dx) / (2 * dx))
			elif span > 0:
				x += int((2 * step * dx + dy) / (2 * dy))
				y += direction * step
			if id == "stroke":
				var radius: int = int(args.get("radius", 0))
				for oy: int in range(-radius, radius + 1):
					for ox: int in range(-radius, radius + 1):
						if ox * ox + oy * oy <= radius * radius:
							points[_point_key(x + ox, y + oy)] = true
			else:
				points[_point_key(x, y)] = true
	return points


static func _fill_points(capture: Dictionary, args: Dictionary) -> Dictionary:
	var region: Array = capture.region
	var width: int = int(region[2])
	var height: int = int(region[3])
	var sx: int = int(args.x) - int(region[0])
	var sy: int = int(args.y) - int(region[1])
	if sx < 0 or sy < 0 or sx >= width or sy >= height: return {}
	var material: int = int(capture.materials[sy * width + sx])
	var queue: Array[Vector2i] = [Vector2i(sx, sy)]
	var visited := {}
	var points := {}
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height: continue
		var key: int = cell.y * width + cell.x
		if visited.has(key): continue
		visited[key] = true
		if int(capture.materials[key]) != material: continue
		points[_point_key(cell.x + int(region[0]), cell.y + int(region[1]))] = true
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(cell + offset)
	return points


func _material_checks(rows: Array[Dictionary], record: Dictionary, id: String,
		args: Dictionary, before: Dictionary) -> void:
	var first: Dictionary = record.get("capture_before", {})
	var last: Dictionary = record.get("capture_after", {})
	var capture_ok: bool = _capture_valid(first) and _capture_valid(last) \
		and _same(first.get("region"), last.get("region"))
	_assert(rows, "independent_material_readback", capture_ok, "matching completed native captures",
		{"before": first.get("native_receipt", {}), "after": last.get("native_receipt", {})}, "evidence")
	if not capture_ok: return
	_assert(rows, "native_capture_source_identity", _capture_matches(first, before.get("native", {})) \
		and _capture_matches(last, record.get("after", {}).get("native", {})),
		"capture generation/revision/tick matches observed native source", {"before": first.native_receipt, "after": last.native_receipt}, "evidence")
	var receipt: Dictionary = record.get("native_receipt", {})
	_assert(rows, "native_edit_completed", receipt.get("status") == "completed" \
		and receipt.get("kind") == "edit" and receipt.get("backend") == "CyberNativeCellWorld", "completed native edit receipt",
		{"status": receipt.get("status"), "kind": receipt.get("kind"), "backend": receipt.get("backend")}, "evidence")
	var actual_native: Dictionary = record.get("after", {}).get("native", {})
	var receipt_matches: bool = receipt.get("observed_generation") == actual_native.get("generation")
	for key: String in ["generation", "revision", "tick"]:
		receipt_matches = receipt_matches and _integer(receipt.get(key)) and receipt.get(key) == actual_native.get(key)
	_assert(rows, "native_edit_source_identity", receipt_matches, actual_native,
		{"generation": receipt.get("generation"), "observed_generation": receipt.get("observed_generation"),
		"revision": receipt.get("revision"), "tick": receipt.get("tick")}, "evidence")
	var expected: Array = first.materials.duplicate()
	var points: Dictionary = _fill_points(first, args) if id == "fill" else _shape_points(id, args)
	var material: int = 0 if id == "erase" else int(before.get("material", -1))
	if id == "paste":
		if _clipboard.is_empty():
			_unavailable(rows, "paste_materials", "No independently observed prior Copy in this tape.")
			return
		var clipboard_region: Array = _clipboard.region
		for index: int in range(_clipboard.materials.size()):
			points[_point_key(int(args.x) + index % int(clipboard_region[2]),
				int(args.y) + int(index / int(clipboard_region[2])))] = int(_clipboard.materials[index])
	var region: Array = first.region
	var covered := 0
	for index: int in range(expected.size()):
		var key: String = _point_key(int(region[0]) + index % int(region[2]),
			int(region[1]) + int(index / int(region[2])))
		if points.has(key):
			expected[index] = points[key] if id == "paste" else material
			covered += 1
	_assert(rows, "complete_brush_footprint_observed", covered == points.size() and covered > 0,
		points.size(), covered, "evidence")
	_assert(rows, "native_material_footprint", _same(expected, last.materials),
		{"sha256": JSON.stringify(expected).sha256_text(), "cells": expected.size()},
		{"sha256": JSON.stringify(last.materials).sha256_text(), "cells": last.materials.size()})
	_assert(rows, "native_applied_accounting", int(receipt.get("applied", -1)) == points.size(),
		points.size(), receipt.get("applied"))
	var changed := 0
	for index: int in range(expected.size()):
		if int(first.materials[index]) != int(last.materials[index]): changed += 1
	_assert(rows, "native_changed_accounting", int(receipt.get("changed", -1)) == changed,
		changed, receipt.get("changed"))
	if int(receipt.get("applied", 0)) > 0:
		_undo.append({"region": first.region.duplicate(), "before": first.materials.duplicate(),
			"after": last.materials.duplicate()})
		if _undo.size() > 32: _undo.pop_front()
		_redo.clear()


func _history_checks(rows: Array[Dictionary], record: Dictionary, id: String) -> void:
	var source: Array[Dictionary] = _undo if id == "undo" else _redo
	var destination: Array[Dictionary] = _redo if id == "undo" else _undo
	if source.is_empty():
		_unavailable(rows, id + "_native_materials", "This tape has no independent corresponding edit capture.")
		return
	var history: Dictionary = source.back()
	var capture: Dictionary = record.get("capture_after", {})
	var capture_ok: bool = _capture_valid(capture) and _same(capture.get("region"), history.region)
	_assert(rows, id + "_readback", capture_ok, history.region, capture.get("region"), "evidence")
	if not capture_ok: return
	var expected: Array = history.before if id == "undo" else history.after
	_assert(rows, id + "_native_materials", _same(capture.materials, expected),
		JSON.stringify(expected).sha256_text(), JSON.stringify(capture.materials).sha256_text())
	_assert(rows, id + "_capture_source_identity", _capture_matches(capture, record.get("after", {}).get("native", {})),
		"current native capture", capture.native_receipt, "evidence")
	if _same(capture.materials, expected): destination.append(source.pop_back())


func evaluate(record: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = Expanded.evaluate(record)
	var action: Dictionary = record.get("action", {})
	var id: String = str(action.get("id", ""))
	var args: Dictionary = action.get("args", {})
	var before: Dictionary = record.get("before", {})
	var after: Dictionary = record.get("after", {})
	var first_native: Dictionary = before.get("native", {})
	var last_native: Dictionary = after.get("native", {})
	var status: String = str(record.get("status", ""))
	var classification: String = str(record.get("classification", ""))
	var before_version: int = _adapter_version(before)
	var after_version: int = _adapter_version(after)
	var modern_lineage: bool = before_version == 3 and after_version == 3
	if before_version == 0 or after_version == 0 or ((before_version == 3 or after_version == 3) and not modern_lineage):
		_assert(rows, "adapter_observation_version", false, "supported consistent observation contract", [before_version, after_version], "evidence")
		return rows
	if modern_lineage:
		_assert(rows, "adapter_observation_version", true, 3, 3, "evidence")
		_lineage_checks(record, rows)
	if classification in ["not_applicable", "invalid_action", "adapter_failure"]:
		_unavailable(rows, "gameplay_observation", str(record.get("error", classification)))
		return rows
	var valid_native: bool = _native_valid(first_native) and _native_valid(last_native)
	_assert(rows, "native_observation_available", valid_native, "copied native identities and failure state",
		{"before": first_native, "after": last_native}, "evidence")
	if not valid_native: return rows
	_assert(rows, "native_world_healthy", not bool(last_native.failed), false, last_native.failed)
	if int(first_native.generation) == int(last_native.generation):
		_assert(rows, "native_tick_monotonic", int(last_native.tick) >= int(first_native.tick),
			"at least " + str(first_native.tick), last_native.tick)
	if not _last_native.is_empty() and (int(_last_native.generation) != int(first_native.generation) \
		or int(_last_native.tick) != int(first_native.tick) or int(_last_native.revision) != int(first_native.revision)):
		_undo.clear()
		_redo.clear()
	_last_native = last_native.duplicate(true)
	if int(first_native.tick) != int(last_native.tick) or int(first_native.generation) != int(last_native.generation):
		_undo.clear()
		_redo.clear()
	if status != "completed":
		if status == "refused" and not bool(record.get("admission", {}).get("accepted", false)) \
			and before.get("paused", false) and after.get("paused", false) \
			and id in EDITS:
			_assert(rows, "refused_edit_did_not_change_native", first_native.generation == last_native.generation \
				and first_native.revision == last_native.revision and first_native.tick == last_native.tick,
				first_native, last_native)
		return rows
	if id in ["actor_place", "actor_reset"]:
		var receipt: Dictionary = record.get("native_receipt", {})
		var bytes: Variant = receipt.get("canonical_bytes", [])
		var valid_bytes: bool = bytes is Array and not bytes.is_empty() and bytes.size() <= 1048576
		if valid_bytes:
			for value: Variant in bytes:
				if not _integer(value) or value < 0 or value > 255:
					valid_bytes = false
					break
		var observed_hash := ""
		if valid_bytes:
			var hasher := HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(PackedByteArray(bytes))
			observed_hash = hasher.finish().hex_encode()
		# The native initial packet counts collision proxies, not logical actors.
		# Articulated actors have several parts; compound flyers may have several
		# occupancy proxies per part. Catalogue geometry and the adopted bridge
		# provide independent expected/admitted counts alongside the native receipt.
		var expected_proxies := 0
		for actor: Dictionary in after.get("actors", []):
			expected_proxies += int(actor.get("capabilities", {}).get("proxy_count", 1))
		_assert(rows, "actor_native_construction_receipt", valid_bytes and observed_hash == receipt.get("receipt_hash") \
			and receipt.get("session_generation") == last_native.generation \
			and receipt.get("initial_body_count") == expected_proxies \
			and int(after.get("physical_proxy_count", expected_proxies)) == expected_proxies,
			{"canonical_receipt": "source-matched", "proxy_count": expected_proxies},
			{"hash": observed_hash, "receipt": receipt.get("receipt_hash"), "native_count": receipt.get("initial_body_count"),
			"adopted_count": after.get("physical_proxy_count", expected_proxies)}, "evidence")
	var interval: Dictionary = record.get("interval", {})
	match id:
		"pause":
			_assert(rows, "pause_ui_state", after.get("paused") == true, true, after.get("paused"))
			var observed: bool = int(interval.get("observed_frames", 0)) >= 3 \
				and _integer(interval.get("start_tick")) and _integer(interval.get("end_tick"))
			_assert(rows, "pause_interval_observed", observed, "at least 3 settled process frames", interval, "evidence")
			if observed:
				_assert(rows, "paused_native_inactivity", interval.start_tick == interval.end_tick,
					interval.start_tick, interval.end_tick)
		"play", "wait_ticks":
			_assert(rows, "play_ui_state", after.get("paused") == false, false, after.get("paused"))
			var observed: bool = _integer(interval.get("start_tick")) and _integer(interval.get("end_tick"))
			_assert(rows, "play_interval_observed", observed, "native start/end tick", interval, "evidence")
			if observed:
				var advance: int = int(interval.end_tick) - int(interval.start_tick)
				_assert(rows, "native_simulation_progress", advance >= int(args.get("ticks", 4)),
					"at least " + str(args.get("ticks", 4)), advance)
		"select_material":
			_assert(rows, "selected_material", after.get("material") == args.get("material"), args.get("material"), after.get("material"))
		"brush", "erase", "rectangle", "outline", "line", "fill", "paste", "stroke":
			_material_checks(rows, record, id, args, before)
		"undo", "redo":
			_history_checks(rows, record, id)
		"copy":
			var capture: Dictionary = record.get("capture_after", {})
			if not _capture_valid(capture): capture = record.get("capture_before", {})
			_assert(rows, "copy_native_capture", _capture_valid(capture), "completed independent native capture", capture.get("native_receipt"), "evidence")
			if _capture_valid(capture):
				_assert(rows, "copy_clipboard_materials", _same(after.get("clipboard", {}).get("materials"), capture.materials),
				JSON.stringify(capture.materials).sha256_text(), JSON.stringify(after.get("clipboard", {}).get("materials")).sha256_text())
				_assert(rows, "copy_capture_source_identity", _capture_matches(capture, after.get("native", {})),
					"current native capture", capture.native_receipt, "evidence")
				_clipboard = capture.duplicate(true)
		"select_region":
			var expected: Array = [mini(int(args.x0), int(args.x1)), mini(int(args.y0), int(args.y1)),
				absi(int(args.x1) - int(args.x0)) + 1, absi(int(args.y1) - int(args.y0)) + 1]
			_assert(rows, "selected_region", _same(after.get("selection"), expected), expected, after.get("selection"))
		"camera":
			var expected := {"origin": [mini(int(args.x), 512 - int(args.width)), mini(int(args.y), 512 - int(args.height))],
				"size": [args.width, args.height]}
			var camera: Dictionary = after.get("camera", {})
			var actual := {"origin": camera.get("origin"), "size": camera.get("size")}
			_assert(rows, "camera_state", _same(actual, expected), expected, actual)
		"panel":
			_assert(rows, "panel_state", after.get("details_open") == args.get("open"), args.get("open"), after.get("details_open"))
		"actor_select":
			_assert(rows, "actor_selection", after.get("selected_actor") == args.get("actor_id"), args.get("actor_id"), after.get("selected_actor"))
			_assert(rows, "inspection_preserves_pilot", after.get("pilot_actor") == before.get("pilot_actor"), before.get("pilot_actor"), after.get("pilot_actor"))
		"actor_pilot":
			_assert(rows, "explicit_pilot_identity", after.get("pilot_actor") == args.get("actor_id"), args.get("actor_id"), after.get("pilot_actor"))
			_assert(rows, "pilot_retains_actor_roster", _same(before.get("actor_ids"), after.get("actor_ids")), before.get("actor_ids"), after.get("actor_ids"))
			var actor: Dictionary = {}
			for candidate: Dictionary in after.get("actors", []):
				if candidate.get("id") == args.get("actor_id"): actor = candidate
			_assert(rows, "explicit_pilot_producer", actor.get("control_observation", {}).get("producer") == "human",
				"human", actor.get("control_observation", {}).get("producer"))
			_assert(rows, "pilot_retains_native_physical_session", first_native.generation == last_native.generation \
				and before.get("physical_epoch") == after.get("physical_epoch"),
				{"generation": first_native.generation, "physical_epoch": before.get("physical_epoch")},
				{"generation": last_native.generation, "physical_epoch": after.get("physical_epoch")})
			for prior: Dictionary in before.get("actors", []):
				for current: Dictionary in after.get("actors", []):
					if prior.get("id") == current.get("id"):
						_assert(rows, "pilot_retains_body_pose", _same(prior.get("position"), current.get("position")) \
							and prior.get("rotation") == current.get("rotation"),
							{"id": prior.get("id"), "position": prior.get("position"), "rotation": prior.get("rotation")},
							{"id": current.get("id"), "position": current.get("position"), "rotation": current.get("rotation")})
		"single_step":
			_assert(rows, "single_step_remains_paused", after.get("paused") == true, true, after.get("paused"))
			_assert(rows, "single_step_native_progress", int(last_native.tick) == int(first_native.tick) + 1,
				int(first_native.tick) + 1, last_native.tick)
		"actor_place":
			var old_ids: Array = before.get("actor_ids", [])
			var new_ids: Array = after.get("actor_ids", [])
			var added := []
			for value: Variant in new_ids:
				if value not in old_ids: added.append(value)
			var retains := true
			for value: Variant in old_ids:
				if value not in new_ids: retains = false
			_assert(rows, "actor_place_roster", added.size() == 1 and new_ids.size() == old_ids.size() + 1 and retains,
				"one additional actor; all existing actors retained", {"before": old_ids, "after": new_ids})
			var placed: Dictionary = {}
			for actor: Dictionary in after.get("actors", []):
				if actor.get("id") in added: placed = actor
			_assert(rows, "actor_place_model", placed.get("model") == args.get("model"), args.get("model"), placed.get("model"))
			var spawn := [args.x, args.y]
			var authoring: Dictionary = record.get("actor_authoring", {})
			var root := Expanded.actor_origin_root(str(args.model), spawn)
			var origin_strict: bool = int(after.get("adapter_version", 1)) >= 2
			if origin_strict:
				_assert(rows, "actor_place_authored_spawn", _same(placed.get("authored_spawn"), spawn) \
					and _same(authoring.get("spawn"), spawn) and _same(authoring.get("authored_after", {}).get("spawn"), spawn),
					spawn, {"observed": placed.get("authored_spawn"), "authored": authoring.get("spawn")})
				_assert(rows, "actor_place_part_origins", Expanded.actor_origin_parts(placed, str(args.model), spawn),
					"fresh physical parts at requested authored origin plus fixed model offsets", placed.get("state"))
			else:
				_unavailable(rows, "actor_place_authored_spawn", "authored/part proof requires adapter v2 observations")
				_unavailable(rows, "actor_place_part_origins", "authored/part proof requires adapter v2 observations")
			_assert(rows, "actor_place_position", not root.is_empty() and _same(placed.get("position"), root) \
				and (not origin_strict or _same(authoring.get("body", {}).get("position"), root)), root, placed.get("position"))
			_assert(rows, "actor_place_native_publication", int(last_native.generation) > int(first_native.generation),
				"new native generation", last_native.generation)
		"actor_reset":
			_assert(rows, "actor_reset_roster", _same(before.get("actor_ids"), after.get("actor_ids")), before.get("actor_ids"), after.get("actor_ids"))
			_assert(rows, "actor_reset_native_publication", int(last_native.generation) > int(first_native.generation),
				"new native generation", last_native.generation)
			var authoring: Dictionary = record.get("actor_authoring", {})
			var original_spawn: Variant = null
			var reset_model := ""
			for prior: Dictionary in before.get("actors", []):
				if prior.get("id") == before.get("selected_actor"):
					original_spawn = prior.get("authored_spawn")
					reset_model = str(prior.get("model", ""))
			var reset_actor := Expanded._actor(after, int(before.get("selected_actor", 0)))
			var root := Expanded.actor_origin_root(reset_model, original_spawn)
			var origin_strict: bool = int(after.get("adapter_version", 1)) >= 2
			_assert(rows, "actor_reset_authored_position", original_spawn is Array and original_spawn.size() == 2 \
				and not root.is_empty() and _same(original_spawn, authoring.get("spawn")) \
				and _same(root, authoring.get("body", {}).get("position")) \
				and (not origin_strict or (_same(original_spawn, reset_actor.get("authored_spawn")) and _same(root, reset_actor.get("position")))),
				{"authored": original_spawn, "physical_root": root},
				{"authored": authoring.get("spawn"), "actual": authoring.get("body", {}).get("position")})
			if origin_strict:
				_assert(rows, "actor_reset_part_origins", Expanded.actor_origin_parts(reset_actor, reset_model, original_spawn),
					"fresh physical parts at saved authored origin plus fixed model offsets", reset_actor.get("state"))
			else:
				_unavailable(rows, "actor_reset_part_origins", "part proof requires adapter v2 observations")
			_assert(rows, "actor_reset_physical_publication", int(authoring.get("physical_epoch_after", -1)) > int(authoring.get("physical_epoch_before", -1)),
				"new physical session epoch", authoring.get("physical_epoch_after"))
		"actor_drive":
			var observed: bool = _integer(interval.get("start_actor_tick")) and _integer(interval.get("end_actor_tick"))
			_assert(rows, "actor_completed_samples_observed", observed, "completed physical input sample range", interval, "evidence")
			if observed:
				_assert(rows, "actor_physical_samples_advanced", int(interval.end_actor_tick) > int(interval.start_actor_tick),
					"greater than " + str(interval.start_actor_tick), interval.end_actor_tick)
			var delivery: Dictionary = record.get("actor_delivery", {})
			var initial: Dictionary = delivery.get("before", {})
			var during: Dictionary = delivery.get("during", {})
			var command: Dictionary = delivery.get("sampled_command", {})
			var pilot: int = int(before.get("pilot_actor", 0))
			var owner_ok: bool = pilot > 0 and delivery.get("instance_id") == pilot \
				and during.get("instance_id") == pilot and during.get("producer") == "human" \
				and int(during.get("lease_remaining", 0)) > 0 \
				and initial.get("generation") == during.get("generation")
			_assert(rows, "actor_input_ownership", owner_ok, "current human pilot and live unchanged generation lease", during)
			_assert(rows, "actor_input_admission_observed", int(during.get("accepted", 0)) > int(initial.get("accepted", 0)) \
				and int(during.get("last_sequence", 0)) > int(initial.get("last_sequence", 0)),
				"actual accepted input and sequence advanced", {"before": initial, "during": during}, "evidence")
			var move: Variant = command.get("move", [])
			var requested: String = str(args.get("direction", ""))
			var delivered := false
			if move is Array and move.size() == 2 and (move[0] is int or move[0] is float) \
				and (move[1] is int or move[1] is float):
				match requested:
					"left": delivered = float(move[0]) < 0.0
					"right": delivered = float(move[0]) > 0.0
					"up": delivered = float(move[1]) < 0.0
					"down":
						delivered = float(move[1]) > 0.0
						if during.get("observation", {}).get("model") == "kestrel":
							delivered = delivery.get("sampled_ports", {}).get("ports", {}).get("s", false) == true
			_assert(rows, "actor_requested_input_sampled", delivered, requested,
				{"command": command, "ports": delivery.get("sampled_ports", {})})
			var released: Dictionary = delivery.get("released_command", {})
			_assert(rows, "actor_input_released", _same(released.get("move"), [0, 0]), [0, 0], released.get("move"))
			var released_ports: Dictionary = delivery.get("released_ports", {}).get("ports", {})
			var ports_neutral := true
			for port: String in ["q", "e", "s", "boost"]:
				if released_ports.get(port, false) != false: ports_neutral = false
			_assert(rows, "actor_ports_released", ports_neutral, "released Q/E/S/boost", released_ports)
		"save_layout":
			var persistence: Dictionary = record.get("persistence", {})
			var saved: String = str(persistence.get("read_authored_digest", ""))
			var current: String = str(after.get("authored_digest", ""))
			_assert(rows, "authored_save_readback", not current.is_empty() and saved == current, current, saved)
			if not current.is_empty() and saved == current:
				_saved_identity = saved
				_saved_native_tick = int(last_native.tick)
				_saved_capture = record.get("persistence_capture", {}).duplicate(true)
				_saved_observation = after.duplicate(true)
				if modern_lineage:
					_saved_material_state = _material_state
					_saved_material_lineage = after.get("material_lineage", {}).duplicate(true)
			if modern_lineage:
				_assert(rows, "save_material_lineage_identity", _same(persistence.get("saved_material_lineage"), _saved_material_lineage),
					_saved_material_lineage, persistence.get("saved_material_lineage"), "evidence")
				if not record.has("persistence_capture"):
					_assert(rows, "save_capture_evidence", false, "actual source-fenced whole-layout capture", "missing", "evidence")
			if record.has("persistence_capture"):
				var capture_state: String = _persistence_capture_state(_saved_capture, after)
				_assert(rows, "save_capture_evidence", capture_state != "invalid", "completed capture or exact observed body protection", capture_state, "evidence")
				_assert(rows, "save_native_tick_identity", persistence.get("saved_native_tick") == last_native.tick, last_native.tick, persistence.get("saved_native_tick"), "evidence")
				_assert(rows, "save_material_capture_identity", persistence.get("material_sha256", "") == _saved_capture.get("material_sha256", ""),
					_saved_capture.get("material_sha256", ""), persistence.get("material_sha256", ""), "evidence")
				var authored_materials: bool = _saved_material_state == "authored_compatible" if modern_lineage else _saved_native_tick == 0
				_assert(rows, "save_material_applicability", (not modern_lineage or persistence.get("native_material_equality_applicable") is bool) \
					and persistence.get("native_material_equality_applicable") == (authored_materials and capture_state == "completed"),
					authored_materials and capture_state == "completed", persistence.get("native_material_equality_applicable"), "evidence")
		"reopen_layout":
			if _saved_identity.is_empty():
				_unavailable(rows, "authored_reopen_identity", "No independently observed Save in this tape.")
			else:
				_assert(rows, "authored_reopen_identity", after.get("authored_digest") == _saved_identity,
					_saved_identity, after.get("authored_digest"))
			var persistence: Dictionary = record.get("persistence", {})
			if modern_lineage:
				_assert(rows, "reopen_saved_material_lineage", not _saved_material_lineage.is_empty() \
					and _same(persistence.get("saved_material_lineage"), _saved_material_lineage),
					_saved_material_lineage, persistence.get("saved_material_lineage"), "evidence")
			var saved_state: String = _persistence_capture_state(_saved_capture, _saved_observation) if not _saved_capture.is_empty() else "unrecorded"
			var current_capture: Dictionary = record.get("persistence_capture", {})
			var current_state: String = _persistence_capture_state(current_capture, after) if record.has("persistence_capture") else "unrecorded"
			var capture_custody: bool = not modern_lineage
			if record.has("persistence_capture"):
				capture_custody = saved_state in ["completed", "native_body_protection"] and current_state in ["completed", "native_body_protection"] \
					and _same(persistence.get("saved_capture"), _saved_capture) and persistence.get("saved_native_tick") == _saved_native_tick
				_assert(rows, "reopen_capture_evidence", capture_custody, "current native capture and exact previously observed Save capture", {"saved": saved_state, "current": current_state}, "evidence")
				_assert(rows, "reopen_material_capture_identity", persistence.get("saved_material_sha256", "") == _saved_capture.get("material_sha256", "") \
					and persistence.get("reopened_material_sha256", "") == current_capture.get("material_sha256", ""),
					{"saved": _saved_capture.get("material_sha256", ""), "current": current_capture.get("material_sha256", "")},
					{"saved": persistence.get("saved_material_sha256", ""), "current": persistence.get("reopened_material_sha256", "")}, "evidence")
			if modern_lineage:
				var expected_comparison: bool = _saved_material_state == "authored_compatible" and capture_custody \
					and saved_state == "completed" and current_state == "completed"
				_assert(rows, "reopen_material_applicability", persistence.get("native_material_equality_applicable") is bool \
					and persistence.native_material_equality_applicable == expected_comparison,
					expected_comparison, persistence.get("native_material_equality_applicable"), "evidence")
			if persistence.get("native_material_equality_applicable", false):
				if not modern_lineage:
					_assert(rows, "reopen_material_applicability", _saved_native_tick == 0 and (not record.has("persistence_capture") \
						or (capture_custody and saved_state == "completed" and current_state == "completed")), "captured authored native state at tick zero", _saved_native_tick, "evidence")
				var expected_materials: String = str(_saved_capture.get("material_sha256", "")) if record.has("persistence_capture") else str(persistence.get("saved_material_sha256", ""))
				var actual_materials: String = str(current_capture.get("material_sha256", "")) if record.has("persistence_capture") else str(persistence.get("reopened_material_sha256", ""))
				_assert(rows, "authored_reopen_materials", not expected_materials.is_empty() and expected_materials == actual_materials, expected_materials, actual_materials)
			else:
				var reason: String = str(persistence.get("native_material_equality_reason", ""))
				var lineage_na: bool = (_saved_material_state == "simulation_exposed" and reason == "simulation_exposed_lineage") \
					or (_saved_material_state == "unknown" and reason == "unknown_material_lineage")
				var justified: bool = ((lineage_na if modern_lineage else (_saved_native_tick > 0 and reason in ["", "evolved_native_tick"])) and capture_custody) \
					or (reason == "native_body_protection" and capture_custody and (saved_state == "native_body_protection" or current_state == "native_body_protection"))
				_assert(rows, "reopen_material_na_evidence", justified, "independently observed incompatible/unknown material lineage or exact body protection" if modern_lineage else "observed evolved Save tick or exact native body-protection refusal", {"reason": reason, "saved_tick": _saved_native_tick, "saved_capture": saved_state, "current_capture": current_state}, "evidence")
				if justified: _unavailable(rows, "authored_reopen_materials", "Native body protection prevents full capture." if reason == "native_body_protection" else (
					"Material equality needs independently established authored-compatible lineage." if modern_lineage else "Authored starts do not restore evolved material state."))
			_undo.clear()
			_redo.clear()
			_clipboard.clear()
		"reset_fixture":
			_assert(rows, "reset_fixture_identity", before.get("fixture_id") == after.get("fixture_id"),
				before.get("fixture_id"), after.get("fixture_id"))
			_assert(rows, "reset_authored_layout", not str(after.get("scene_identity", "")).is_empty() \
				and after.get("authored_digest") == after.get("scene_identity"), after.get("scene_identity"), after.get("authored_digest"))
			_assert(rows, "reset_native_replacement", int(last_native.generation) > int(first_native.generation) \
				and int(last_native.tick) == 0, "new native generation at tick zero", last_native)
			_undo.clear()
			_redo.clear()
			_clipboard.clear()
			_saved_identity = ""
			_saved_native_tick = -1
			_saved_capture.clear()
			_saved_observation.clear()
			_saved_material_state = "unknown"
			_saved_material_lineage.clear()
	var actor_ids := {}
	for actor: Dictionary in after.get("actors", []):
		var actor_id: Variant = actor.get("id")
		_assert(rows, "actor_identity_unique", _integer(actor_id) and not actor_ids.has(str(actor_id)), "unique live actor ID", actor_id)
		actor_ids[str(actor_id)] = true
		_assert(rows, "actor_observation_available", actor.get("observed") == true, "actual physical body observation", actor.get("observed"), "evidence")
		for field: String in ["position", "linear_velocity"]:
			var coordinates: Variant = actor.get(field, [])
			var coordinates_valid: bool = coordinates is Array and coordinates.size() == 2
			_assert(rows, "actor_" + field + "_available", coordinates_valid, "two observed coordinates", coordinates, "evidence")
			if not coordinates_valid: continue
			for value: Variant in coordinates:
				_assert(rows, "actor_finite_" + field, (value is int or value is float) and is_finite(float(value)), "finite", value)
	return rows
