extends RefCounted

## A finite, copied, zero-write contract. Native observations, approval and ACKs
## belong to StrataConstructionSession and the ordinary Workbench owner adapter.
const Module = preload("res://scripts/depth/strata_native_module.gd")
const FORMAT := "cybersand-strata-plan-v1"
const COMPOSITION_FORMAT := "cybersand-strata-composition-v1"
const MAX_STAGES := 16
const MAX_CELLS := 262144
const MAX_INSPECTED_CELLS := 1048576
const MAX_BYTES := 8 * 1024 * 1024
const CHUNK_CELLS := 4096
const KEYS := ["format", "id", "name", "scene_id", "kind", "source_sha256", "modules", "stages", "metadata"]
const STAGE_KEYS := ["id", "plane", "region", "expected_revision", "depends_on", "allowed_materials", "protected_regions", "placements"]
const PLACEMENT_KEYS := ["module_id", "module_sha256", "origin", "transform", "palette", "empty_mode"]


static func _text(value: Variant, maximum: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= maximum


static func _plane(value: Variant) -> bool:
	return value is String and value in ["play", "scripted", "effects", "background"]


static func from_module(module: Dictionary, plane: String, options: Dictionary, plane_state: Dictionary) -> Dictionary:
	if not _plane(plane) or not plane_state.get("ok", false) or not plane_state.has_all(["scene_id", "revision"]): return Module.failure("The selected target must provide a current copied native identity.")
	if not Module.keys(options, ["origin"], ["transform", "palette", "empty_mode"]) or not Module.pair(options.origin, 0, 2047): return Module.failure("Native placement requires an explicit origin and known exact-grid controls.")
	if not module.has_all(["id", "extent", "content_sha256", "provenance", "geometry"]) or not Module.identifier(module.id) or not Module.hex_digest(module.content_sha256) or not module.provenance is Dictionary or not module.geometry is Dictionary or not module.geometry.get("cells_base64") is String: return Module.failure("A validated native module is required.")
	var transform: Variant = options.get("transform", "identity")
	if not transform is String or transform not in Module.TRANSFORMS or not Module.pair(module.extent, 1, 2048): return Module.failure("Invalid exact-grid module transform.")
	var size := Module.transformed_size(Vector2i(int(module.extent[0]), int(module.extent[1])), transform)
	var materials: Dictionary = {0: true}
	var decoded := Marshalls.base64_to_raw(str(module.get("geometry", {}).get("cells_base64", "")))
	if decoded.size() != int(module.extent[0]) * int(module.extent[1]) * 2: return Module.failure("Incomplete native module bytes.")
	for i: int in decoded.size() / 2: materials[decoded.decode_u16(i * 2)] = true
	var palette: Variant = options.get("palette", {})
	if not palette is Dictionary: return Module.failure("Invalid native material-role mapping.")
	for material: Variant in palette.values():
		if not Module.integer(material, 1, 255): return Module.failure("Invalid native material-role replacement.")
		materials[int(material)] = true
	var allowed: Array = materials.keys(); allowed.sort()
	var source_sha := str(module.provenance.get("source_sha256", module.content_sha256))
	if not Module.hex_digest(source_sha): source_sha = str(module.content_sha256)
	var kind := "raster_import" if module.provenance.get("source_kind") == "raster-proposal" else "native_module"
	var plan := {"format": FORMAT, "id": "place-" + str(module.content_sha256).left(20), "name": "Place " + str(module.get("name", module.id)),
		"scene_id": plane_state.scene_id, "kind": kind, "source_sha256": source_sha,
		"modules": [module.duplicate(true)], "metadata": {"scope": "Owner-reviewed native material placement; no physics or structural solver claim."},
		"stages": [{"id": "place", "plane": plane, "region": [int(options.origin[0]), int(options.origin[1]), size.x, size.y],
			"expected_revision": int(plane_state.revision), "depends_on": [], "allowed_materials": allowed, "protected_regions": [],
			"placements": [{"module_id": module.id, "module_sha256": module.content_sha256, "origin": options.origin.duplicate(), "transform": transform,
				"palette": palette.duplicate(true), "empty_mode": options.get("empty_mode", "preserve")}]}]}
	return {"ok": true, "plan": Module.canonical(plan), "error": ""}


static func from_composition(raw: Dictionary, anchor: Vector2i, modules: Array, plane_states: Dictionary, admitted: PackedInt32Array) -> Dictionary:
	if not Module.keys(raw, ["format", "id", "name", "modules", "stages", "metadata"]) or raw.format != COMPOSITION_FORMAT or not Module.identifier(raw.id) or not _text(raw.name, 128) or not raw.modules is Array or raw.modules.is_empty() or raw.modules.size() > 32 or not raw.stages is Array or raw.stages.is_empty() or raw.stages.size() > MAX_STAGES or not raw.metadata is Dictionary or not Module.safe_json(raw.metadata): return Module.failure("Unsupported layered composition fields or format.")
	if anchor.x < 0 or anchor.y < 0 or anchor.x > 2047 or anchor.y > 2047: return Module.failure("Composition anchor must be an admitted native coordinate.")
	var by_id: Dictionary = {}
	for module: Variant in modules:
		var validated := Module.validate(module, admitted)
		if not validated.ok: return validated
		if by_id.has(module.id): return Module.failure("Repeated composition module identity.")
		by_id[module.id] = validated.module
	if raw.modules.size() != by_id.size(): return Module.failure("Composition module dependencies are incomplete.")
	var declared_modules: Dictionary = {}
	for id: Variant in raw.modules:
		if not Module.identifier(id) or not by_id.has(id): return Module.failure("Composition references an unavailable native part.")
		if declared_modules.has(id): return Module.failure("Composition module dependencies must declare each supplied part exactly once.")
		declared_modules[id] = true
	var stages: Array = []
	var scene_id := ""
	for item: Variant in raw.stages:
		if not Module.keys(item, ["id", "plane", "region", "depends_on", "allowed_materials", "protected_regions", "placements"]) or not _plane(item.plane) or not plane_states.has(item.plane): return Module.failure("Composition needs explicit initialized plane-local stages.")
		var state: Variant = plane_states[item.plane]
		if not state is Dictionary or not state.get("ok", false) or not state.has_all(["scene_id", "revision"]): return Module.failure("Composition target has no current source identity.")
		if scene_id.is_empty(): scene_id = str(state.scene_id)
		if scene_id != state.scene_id: return Module.failure("Composition stages must share one live scene identity.")
		var stage: Dictionary = item.duplicate(true)
		stage.expected_revision = int(state.revision)
		if not stage.region is Array: return Module.failure("Composition regions use explicit integer rectangle arrays.")
		var region := Module.rectangle(stage.region)
		region.position += anchor
		stage.region = Module.rect_array(region)
		if not stage.protected_regions is Array or not stage.placements is Array: return Module.failure("Invalid stage protection or placements.")
		for i: int in stage.protected_regions.size():
			if not stage.protected_regions[i] is Array: return Module.failure("Composition protection uses explicit rectangle arrays.")
			var protection := Module.rectangle(stage.protected_regions[i]); protection.position += anchor
			stage.protected_regions[i] = Module.rect_array(protection)
		for placement: Variant in stage.placements:
			if not Module.keys(placement, ["module_id", "origin", "transform", "palette", "empty_mode"]) or not by_id.has(placement.module_id) or not Module.pair(placement.origin): return Module.failure("Invalid composition part placement.")
			placement.module_sha256 = by_id[placement.module_id].content_sha256
			placement.origin = [int(placement.origin[0]) + anchor.x, int(placement.origin[1]) + anchor.y]
		stages.append(stage)
	var plan := {"format": FORMAT, "id": raw.id, "name": raw.name, "scene_id": scene_id, "kind": "construction",
		"source_sha256": Module.digest(Module.json_bytes(raw)), "modules": by_id.values(), "stages": stages,
		"metadata": {"composition": raw.metadata.duplicate(true), "composition_anchor": [anchor.x, anchor.y], "scope": "Ordered plane-local stages; approval is not cross-plane atomicity."}}
	var checked := compile(plan, admitted)
	if not checked.ok: return checked
	return {"ok": true, "plan": checked.plan, "error": ""}


static func compile(raw: Variant, admitted: PackedInt32Array) -> Dictionary:
	if not Module.keys(raw, KEYS) or raw.format != FORMAT or not Module.identifier(raw.id) or not _text(raw.name, 128) or not _text(raw.scene_id, 128): return Module.failure("Unsupported finite Strata plan fields or identity.")
	if not raw.kind is String or raw.kind not in ["raster_import", "native_module", "construction"] or not Module.hex_digest(raw.source_sha256): return Module.failure("Plan needs an explicit source kind and byte identity.")
	if not raw.modules is Array or raw.modules.is_empty() or raw.modules.size() > 32 or not raw.stages is Array or raw.stages.is_empty() or raw.stages.size() > MAX_STAGES: return Module.failure("A plan admits 1–32 native parts and 1–16 finite stages.")
	if not raw.metadata is Dictionary or not Module.safe_json(raw.metadata) or Module.json_bytes(raw.metadata).size() > 8192 or Module.json_bytes(raw).size() > MAX_BYTES: return Module.failure("Plan metadata or document exceeds its bounded budget.")
	var modules: Dictionary = {}
	for module: Variant in raw.modules:
		var checked := Module.validate(module, admitted)
		if not checked.ok: return checked
		if modules.has(module.id): return Module.failure("Plan module identities must be unique.")
		modules[module.id] = checked.module
	var stages: Array = []
	var stage_ids: Dictionary = {}
	var used_modules: Dictionary = {}
	var total := 0
	var inspected := 0
	for item: Variant in raw.stages:
		if not Module.keys(item, STAGE_KEYS) or not Module.identifier(item.id) or stage_ids.has(item.id) or not _plane(item.plane) or not item.region is Array or not Module.integer(item.expected_revision, 0, 2147483647): return Module.failure("Invalid stage identity, target plane, rectangle or expected authored revision.")
		var region := Module.rectangle(item.region)
		if region.get_area() < 1 or region.size.x < 1 or region.size.y < 1 or not Rect2i(0, 0, 2048, 2048).encloses(region): return Module.failure("Stage region must be an explicit positive in-canvas native rectangle.")
		inspected += region.get_area()
		if inspected > MAX_INSPECTED_CELLS: return Module.failure("Plan exceeds its 1048576-cell copied-inspection budget.")
		if not item.depends_on is Array or item.depends_on.size() > MAX_STAGES: return Module.failure("Invalid finite stage dependencies.")
		var seen_dependencies: Dictionary = {}
		for dependency: Variant in item.depends_on:
			if not Module.identifier(dependency) or not stage_ids.has(dependency) or seen_dependencies.has(dependency): return Module.failure("Dependencies must refer uniquely to earlier stages; hidden or skipped work cannot count as completed.")
			seen_dependencies[dependency] = true
		if not item.allowed_materials is Array or item.allowed_materials.is_empty() or item.allowed_materials.size() > 256: return Module.failure("Stage must declare a bounded native material palette.")
		var seen_materials: Dictionary = {}
		for material: Variant in item.allowed_materials:
			if not Module.integer(material, 0, 255) or int(material) not in admitted or seen_materials.has(int(material)): return Module.failure("Stage palette contains an unknown or repeated native material.")
			seen_materials[int(material)] = true
		if not item.protected_regions is Array or item.protected_regions.size() > 64 or not item.placements is Array or item.placements.is_empty() or item.placements.size() > 128: return Module.failure("Stage protection or placement count exceeds its bounds.")
		for guard: Variant in item.protected_regions:
			if not guard is Array: return Module.failure("Stage protection uses explicit rectangle arrays.")
			var box := Module.rectangle(guard)
			if box.size.x < 1 or box.size.y < 1 or not region.encloses(box): return Module.failure("Stage protection must lie wholly inside its declared region.")
		var writes: Dictionary = {}
		var clearances: Array = []
		var protections: Array = item.protected_regions.duplicate(true)
		var sources: Array = []
		for placement: Variant in item.placements:
			if not Module.keys(placement, PLACEMENT_KEYS) or not Module.identifier(placement.module_id) or not modules.has(placement.module_id) or placement.module_sha256 != modules[placement.module_id].content_sha256: return Module.failure("Placement source module is missing or its frozen identity differs.")
			var controls: Dictionary = placement.duplicate(true)
			controls.erase("module_id"); controls.erase("module_sha256")
			var built := Module.compile(modules[placement.module_id], controls, {"region": item.region, "allowed_materials": item.allowed_materials, "protected": item.protected_regions}, admitted)
			if not built.ok: return built
			for i: int in range(0, built.cells.size(), 3):
				var key: int = int(built.cells[i + 1]) * 2048 + int(built.cells[i])
				if writes.has(key): return Module.failure("Same-stage native placements overlap; split intentional overlap into explicit ordered stages.")
				writes[key] = int(built.cells[i + 2])
			clearances.append_array(built.clearances)
			protections.append_array(built.protected_regions)
			used_modules[placement.module_id] = true
			sources.append({"module_id": placement.module_id, "module_sha256": placement.module_sha256, "provenance": modules[placement.module_id].provenance.duplicate(true)})
		if writes.is_empty(): return Module.failure("A construction stage must propose at least one explicit native write.")
		var ordered: Array = writes.keys(); ordered.sort()
		var cells := PackedInt32Array()
		for key: int in ordered:
			var point := Vector2i(key % 2048, key / 2048)
			for guard: Array in clearances + protections:
				if Module.rectangle(guard).has_point(point): return Module.failure("A stage write conflicts with a part clearance or protection.")
			cells.append_array(PackedInt32Array([point.x, point.y, int(writes[key])]))
		total += cells.size() / 3
		if total > MAX_CELLS: return Module.failure("Finite plan exceeds 262144 proposed native writes.")
		var metadata := {"plan_id": raw.id, "stage_id": item.id, "region": item.region, "placements": item.placements,
			"source_modules": sources, "allowed_materials": item.allowed_materials, "protected_regions": item.protected_regions,
			"depends_on": item.depends_on, "plan_metadata": raw.metadata, "history": "One existing owner history operation per acknowledged <=4096-cell chunk; no group rollback or physical continuation."}
		if Module.json_bytes(metadata).size() > 8192: return Module.failure("Stage provenance exceeds its 8192-byte retained record budget; split or simplify source metadata before approval.")
		stages.append({"id": item.id, "plane": item.plane, "region": item.region.duplicate(), "expected_revision": int(item.expected_revision),
			"depends_on": item.depends_on.duplicate(), "cells": cells, "clearances": clearances, "protected_regions": protections,
			"geometry_sha256": Module.digest(cells.to_byte_array()), "metadata": Module.canonical(metadata), "chunks": ceili(float(cells.size() / 3) / CHUNK_CELLS)})
		stage_ids[item.id] = true
	if used_modules.size() != modules.size(): return Module.failure("Unused module payloads are refused; the finite plan declares only needed resources.")
	return {"ok": true, "plan": Module.canonical(raw), "stages": stages, "total": total, "inspected_cells": inspected,
		"proposal_sha256": Module.digest(Module.json_bytes(raw)), "zero_writes": true, "error": ""}
