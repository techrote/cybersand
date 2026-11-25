extends RefCounted

## Bounded observational projection, never a world model. Missing observations
## remain "unknown". Exact identities are retained separately from novelty keys
## so increasing request/tick/actor IDs cannot manufacture unlimited novelty.
const SCHEMA := "cybersand-goblin-state-v2"
const LEGACY_SCHEMA := "cybersand-goblin-state-v1"
const UNSUPPORTED_SCHEMA := "cybersand-goblin-state-unsupported"
const UNKNOWN := "unknown"
const MAX_CAPTURE_CELLS := 4096
const MAX_ACTORS := 8

static func abstract(observation: Dictionary, capture: Dictionary = {}) -> Dictionary:
	var version := projection_version(observation)
	if version == 0: return {"schema": UNSUPPORTED_SCHEMA, "reason": "unsupported_adapter_version"}
	var native: Dictionary = observation.get("native", {})
	var camera: Dictionary = observation.get("camera", {})
	var actors: Array = observation.get("actors", [])
	var actor_modes: Array[String] = []
	var actor_zones: Array[String] = []
	var actor_controls: Array[String] = []
	var actor_capabilities: Array[String] = []
	for item: Variant in actors.slice(0, MAX_ACTORS):
		if not item is Dictionary or item.get("observed", false) != true: continue
		var model := str(item.get("model", UNKNOWN)).left(64)
		actor_modes.append(model)
		var control: Dictionary = item.get("authored_control", {})
		actor_controls.append(model + ":" + str(control.get("source", UNKNOWN)) + ":" + str(control.get("enabled", UNKNOWN)) + ":" + str(control.get("usable_index", UNKNOWN)))
		for capability: Variant in item.get("capabilities", {}).get("capabilities", []).slice(0, 16):
			if capability is String: actor_capabilities.append(model + ":" + capability.left(64))
		actor_zones.append(model + ":" + position_zone(item.get("position"), observation.get("world_size", [])))
	actor_modes.sort()
	actor_zones.sort()
	actor_controls.sort()
	actor_capabilities.sort()
	var sample := sample_summary(capture, native)
	if not sample.available: sample = probe_summary(observation.get("material_probe", {}), native)
	var result := {"schema": LEGACY_SCHEMA if version == 1 else SCHEMA, "fixture": str(observation.get("fixture_id", UNKNOWN)).left(80),
		"world_size": _pair(observation.get("world_size", []), 1, 4096),
		"paused": _truth(observation, "paused"), "tool": str(observation.get("tool", UNKNOWN)).left(64),
		"material": observation.get("material", UNKNOWN), "brush_radius": observation.get("brush_radius", UNKNOWN),
		"native_busy": _truth(native, "busy"), "native_failed": _truth(native, "failed"),
		"progress_phase": _phase(native.get("tick"), version), "history": [_truth(observation, "undo_available"), _truth(observation, "redo_available")],
		"selection": _area_bucket(observation.get("selection", []), true),
		"clipboard": _area_bucket(observation.get("clipboard_size", []), false),
		"actor_models": actor_modes, "actor_zones": actor_zones, "actor_controls": actor_controls, "actor_capabilities": actor_capabilities,
		"actor_count": actors.size() if observation.has("actors") else UNKNOWN,
		"selected": _actor_role(observation, "selected_actor"), "pilot": _actor_role(observation, "pilot_actor"),
		"saved": not str(observation.saved_authored_digest).is_empty() if observation.has("saved_authored_digest") else UNKNOWN,
		"camera_origin": _coarse_pair(camera.get("origin", []), 64.0), "camera_size": _pair(camera.get("size", []), 1, 4096),
		"details_open": _truth(observation, "details_open"), "material_sample": sample,
		"response_mode": observation.get("configuration", {}).get("response", UNKNOWN), "camera_mode": camera.get("mode", UNKNOWN),
		"preview_active": _truth(observation.get("paint_preview", {}), "dragging"),
		"source_present": not observation.get("source", {}).get("authored", []).is_empty() if observation.has("source") else UNKNOWN}
	return result

static func signature(observation: Dictionary, capture: Dictionary = {}) -> String:
	return JSON.stringify(abstract(observation, capture), "", true).sha256_text()

static func identity(observation: Dictionary) -> Dictionary:
	var native: Dictionary = observation.get("native", {})
	return {"fixture_id": str(observation.get("fixture_id", "")), "scene_identity": str(observation.get("scene_identity", "")),
		"generation": native.get("generation"), "revision": native.get("revision"), "tick": native.get("tick"),
		"physical_epoch": observation.get("physical_epoch"), "snapshot_tick": observation.get("snapshot_tick")}

static func observed(observation: Dictionary) -> bool:
	if projection_version(observation) == 0: return false
	var native: Variant = observation.get("native")
	return observation.get("mounted", false) == true and native is Dictionary \
		and _integer(native.get("generation"), 0, 2147483647) and _integer(native.get("tick"), 0, 2147483647)

static func valid_capture(capture: Dictionary, native: Dictionary = {}) -> bool:
	if capture.has("error") or capture.get("source_matches", false) != true: return false
	var before: Variant = capture.get("source_before")
	var after: Variant = capture.get("source_after")
	var admission: Variant = capture.get("admission")
	var receipt: Variant = capture.get("native_receipt")
	var cells: Variant = capture.get("materials")
	var region: Variant = capture.get("region")
	if not before is Dictionary or not after is Dictionary or not admission is Dictionary or not receipt is Dictionary: return false
	if not cells is Array or cells.is_empty() or cells.size() > MAX_CAPTURE_CELLS or not region is Array or region.size() != 4: return false
	if JSON.stringify(before, "", true) != JSON.stringify(after, "", true): return false
	if admission.get("status") != "queued" or receipt.get("status") != "completed" \
		or receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld": return false
	if not _integer(admission.get("operation_id"), 0, 2147483647) or admission.get("operation_id") != receipt.get("operation_id"): return false
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(before.get(key), 0, 2147483647) or receipt.get(key) != before.get(key): return false
		if not native.is_empty() and native.get(key) != before.get(key): return false
	if receipt.get("observed_generation") != before.get("generation") or before.get("paused") != true or before.get("failed") != false: return false
	for value: Variant in region:
		if not _integer(value, 0, 4096): return false
	if int(region[2]) <= 0 or int(region[3]) <= 0 or int(region[2]) * int(region[3]) != cells.size(): return false
	for cell: Variant in cells:
		if not _integer(cell, 0, 65535): return false
	return true

static func sample_summary(capture: Dictionary, native: Dictionary = {}) -> Dictionary:
	if not valid_capture(capture, native): return {"available": false, "scope": "unobserved"}
	var histogram: Dictionary = {}
	var occupied := 0
	for cell: Variant in capture.materials:
		var key := str(int(cell))
		histogram[key] = int(histogram.get(key, 0)) + 1
		if int(cell) != 0: occupied += 1
	var material_ids: Array[String] = []
	for key: String in histogram: material_ids.append(key)
	material_ids.sort()
	var fraction: float = float(occupied) / float(capture.materials.size())
	return {"available": true, "scope": "captured_region_only", "materials": material_ids,
		"occupancy": "empty" if occupied == 0 else ("trace" if fraction < 0.05 else ("sparse" if fraction < 0.25 else ("mixed" if fraction < 0.75 else "dense")))}

static func progression(before: Dictionary, after: Dictionary) -> String:
	var first: Variant = before.get("native")
	var last: Variant = after.get("native")
	if not first is Dictionary or not last is Dictionary: return UNKNOWN
	if not _integer(first.get("generation"), 0, 2147483647) or not _integer(last.get("generation"), 0, 2147483647): return UNKNOWN
	if first.generation != last.generation: return "world_replaced"
	if not _integer(first.get("tick"), 0, 2147483647) or not _integer(last.get("tick"), 0, 2147483647): return UNKNOWN
	return "advanced" if last.tick > first.tick else ("unchanged" if last.tick == first.tick else "regressed")

static func position_zone(position: Variant, extent: Variant) -> String:
	if not position is Array or position.size() != 2 or not extent is Array or extent.size() != 2: return UNKNOWN
	if not _number(position[0]) or not _number(position[1]) or not _number(extent[0]) or not _number(extent[1]): return UNKNOWN
	var x: float = float(position[0])
	var y: float = float(position[1])
	if x < 0 or y < 0 or x >= float(extent[0]) or y >= float(extent[1]): return "outside"
	if x < 16 or y < 16 or x >= float(extent[0]) - 16 or y >= float(extent[1]) - 16: return "edge"
	return "zone_%d_%d" % [clampi(int(x / maxf(1.0, float(extent[0]) / 4.0)), 0, 3), clampi(int(y / maxf(1.0, float(extent[1]) / 4.0)), 0, 3)]

static func _actor_role(observation: Dictionary, key: String) -> String:
	if not observation.has(key): return UNKNOWN
	if int(observation[key]) <= 0: return "none"
	for item: Variant in observation.get("actors", []):
		if item is Dictionary and item.get("id") == observation[key] and item.get("observed", false) == true: return str(item.get("model", UNKNOWN)).left(64)
	return "selected_unobserved"

static func _truth(value: Dictionary, key: String) -> Variant:
	return value[key] if typeof(value.get(key)) == TYPE_BOOL else UNKNOWN

static func projection_version(observation: Dictionary) -> int:
	# Preserve old coverage hashes exactly. "authored_start" is only a legacy
	# key: tick zero never proves that retained native cells are authored cells.
	# Future/invalid observation versions earn no coverage until supported.
	if not observation.has("adapter_version"): return 1
	var version: Variant = observation.adapter_version
	if _integer(version, 1, 2): return 1
	if _integer(version, 3, 3): return 2
	return 0

static func _phase(value: Variant, version: int) -> String:
	if not _integer(value, 0, 2147483647): return UNKNOWN
	if int(value) == 0: return "authored_start" if version == 1 else "zero_tick"
	if int(value) < 32: return "early"
	if int(value) < 256: return "developing"
	return "sustained"

static func _area_bucket(value: Variant, rect: bool) -> String:
	if not value is Array or value.size() != (4 if rect else 2): return UNKNOWN
	var offset := 2 if rect else 0
	if not _integer(value[offset], 0, 4096) or not _integer(value[offset + 1], 0, 4096): return UNKNOWN
	var area := int(value[offset]) * int(value[offset + 1])
	return "none" if area == 0 else ("small" if area <= 64 else ("medium" if area <= 1024 else "large"))

static func _pair(value: Variant, low: int, high: int) -> Variant:
	if not value is Array or value.size() != 2: return UNKNOWN
	return [int(value[0]), int(value[1])] if _integer(value[0], low, high) and _integer(value[1], low, high) else UNKNOWN

static func _coarse_pair(value: Variant, bucket: float) -> Variant:
	if not value is Array or value.size() != 2 or not _number(value[0]) or not _number(value[1]): return UNKNOWN
	return [clampi(floori(float(value[0]) / bucket), -64, 64), clampi(floori(float(value[1]) / bucket), -64, 64)]

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high



static func probe_summary(probe: Dictionary, native: Dictionary) -> Dictionary:
	var unknown := {"available": false, "scope": "unobserved"}
	if probe.get("current") != true or probe.get("evidence_kind") != "actual_native_material_capture": return unknown
	for key: String in ["generation", "revision", "tick"]:
		if not _integer(probe.get(key), 0, 2147483647) or probe.get(key) != native.get(key): return unknown
	var region: Variant = probe.get("region")
	var counts: Variant = probe.get("counts")
	if not region is Array or region.size() != 4 or not counts is Dictionary or counts.is_empty() or counts.size() > 128: return unknown
	for value: Variant in region:
		if not _integer(value, 0, 4096): return unknown
	var area: int = int(region[2]) * int(region[3])
	if area <= 0 or area > MAX_CAPTURE_CELLS: return unknown
	var total := 0
	var occupied := 0
	var ids: Array[String] = []
	for key: Variant in counts:
		if not key is String or not key.is_valid_int() or not _integer(int(key), 0, 65535) or not _integer(counts[key], 1, MAX_CAPTURE_CELLS): return unknown
		total += int(counts[key])
		if int(key) != 0: occupied += int(counts[key])
		ids.append(str(int(key)))
	if total != area: return unknown
	ids.sort()
	var fraction: float = float(occupied) / float(total)
	return {"available": true, "scope": "captured_region_only", "materials": ids,
		"occupancy": "empty" if occupied == 0 else ("trace" if fraction < 0.05 else ("sparse" if fraction < 0.25 else ("mixed" if fraction < 0.75 else "dense")))}
