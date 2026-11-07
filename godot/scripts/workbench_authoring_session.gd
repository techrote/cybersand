extends RefCounted
## WB-AGENT-001. Private to the existing simulation worker.
## Never pass its World argument, this object or a mutable proposal to the UI.
## The worker serializes this handler after ordinary owner-side emissions.
const Geometry = preload("res://scripts/workbench_agent_footprint.gd")
const Setup = preload("res://scripts/workbench_setup.gd")

const SCHEMA_VERSION: int = 1
const MAX_OBSERVATION_CELLS: int = 4096
const MAX_RETAINED_RECEIPTS: int = 64
const ALLOWED_OUTPUTS: Array = [0, 58]
# First-stage construction may only replace Empty / Hard Wall, not Sand.
const ALLOWED_SOURCES: Array = [0, 58]

var _task: Dictionary = {}
var _observation: Dictionary = {}
var _proposal: Dictionary = {}
var _receipts: Dictionary = {}
var _next_token: int = 0
var _quarantined: bool = false


static func _refused(reason: String) -> Dictionary:
	return {"status":"refused", "reason":reason}


func _token(prefix: String, generation: int) -> String:
	_next_token += 1
	return "%s:%d:%d" % [prefix, generation, _next_token]


static func _world_ids(world: Object, cells: Array[Vector2i]) -> Dictionary:
	var ids: Dictionary = {}
	for point: Vector2i in cells:
		ids[point] = int(world.material_at(point.x, point.y))
	return ids


static func _identity(world: Object, generation: int, manual_revision: int) -> Dictionary:
	return {
		"world_generation":generation,
		"world_revision":int(world.revision),
		"completed_tick":int(world.tick_index),
		"manual_intent_revision":manual_revision
	}


func _current(world: Object, generation: int, manual_revision: int, basis: Dictionary) -> bool:
	return generation == int(basis.get("world_generation",-1)) \
		and int(world.revision) == int(basis.get("world_revision",-1)) \
		and int(world.tick_index) == int(basis.get("completed_tick",-1)) \
		and manual_revision == int(basis.get("manual_intent_revision",-1))


func _scope_ok(rect: Rect2i, extent: Vector2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 \
		and rect.position.x >= 0 and rect.position.y >= 0 \
		and rect.end.x <= extent.x and rect.end.y <= extent.y


func _authorized(command: Dictionary, extent: Vector2i, generation: int) -> Dictionary:
	var task_id: Variant = command.get("task_id",null)
	var scope: Variant = command.get("scope",null)
	var protected_regions: Variant = command.get("protected",null)
	var allowed: Variant = command.get("allowed_materials",null)
	if typeof(task_id) != TYPE_STRING or (task_id as String).is_empty() \
			or (task_id as String).length() > 128:
		return _refused("invalid_task_id")
	if not scope is Rect2i or not _scope_ok(scope,extent):
		return _refused("invalid_scope")
	if not protected_regions is Array or protected_regions.size() > 32:
		return _refused("invalid_protection")
	for region: Variant in protected_regions:
		if not region is Rect2i or not _scope_ok(region,extent):
			return _refused("invalid_protection")
	if not allowed is Array or allowed.is_empty() or allowed.size() > ALLOWED_OUTPUTS.size():
		return _refused("invalid_allowlist")
	for material: Variant in allowed:
		if typeof(material) != TYPE_INT or material not in ALLOWED_OUTPUTS:
			return _refused("invalid_allowlist")
	if _receipts.size() >= MAX_RETAINED_RECEIPTS:
		return _refused("receipt_history_full")
	_task = {
		"task_id": task_id,
		"world_generation": generation,
		"scope": scope,
		"protected": protected_regions.duplicate(true),
		"allowed_materials": allowed.duplicate()
	}
	_observation.clear()
	_proposal.clear()
	return {"status":"authorized", "task_id":task_id, "generation":generation,
		"scope":scope, "allowed_materials":allowed.duplicate()}


func _observe(command: Dictionary, world: Object, extent: Vector2i,
		generation: int, manual_revision: int) -> Dictionary:
	var region: Variant = command.get("region",null)
	if not region is Rect2i or not _scope_ok(region,extent):
		return _refused("invalid_observation_region")
	var scope: Rect2i = _task.scope
	if not scope.encloses(region):
		return _refused("observation_outside_task")
	if region.size.x > MAX_OBSERVATION_CELLS or region.size.y > MAX_OBSERVATION_CELLS \
			or region.size.x * region.size.y > MAX_OBSERVATION_CELLS:
		return _refused("observation_cell_budget")
	var points: Array[Vector2i] = []
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			points.append(Vector2i(x,y))
	var ids: Dictionary = _world_ids(world,points)
	var counts: Dictionary = {}
	var materials: Array[int] = []
	for point: Vector2i in points:
		var native_id: int = ids[point]
		counts[native_id] = int(counts.get(native_id,0)) + 1
		materials.append(native_id)
	var basis: Dictionary = _identity(world,generation,manual_revision)
	var token: String = _token("observation",generation)
	_observation = basis.duplicate()
	_observation["id"] = token
	_proposal.clear()
	return {
		"status":"native_observed",
		"observation_id":token,
		"task_id":_task.task_id,
		"region":region,
		"native_material_ids":materials,
		"native_counts":counts,
		# Palette is a named workbench source contract; no IDs from RGB pixels.
		"palette_material_ids":Setup.MATERIALS.duplicate(),
		"identity":basis,
		# The main thread MUST join these values to a true post-draw image,
		# with matching generation, World revision, tick and render ACK.
		"image_status":"awaiting_matched_framebuffer"
	}


func _prepare(command: Dictionary, world: Object, extent: Vector2i,
		generation: int, manual_revision: int) -> Dictionary:
	if str(command.get("observation_id","")) != str(_observation.get("id","")) \
			or _observation.is_empty():
		return _refused("missing_or_stale_observation")
	if not _current(world,generation,manual_revision,_observation):
		_proposal.clear()
		return _refused("stale_observation")
	if not _proposal.is_empty():
		return _refused("proposal_already_pending")
	if _receipts.size() >= MAX_RETAINED_RECEIPTS:
		return _refused("receipt_history_full")
	var compiled: Dictionary = Geometry.compile(
		command.get("operations",null),extent,
		_task.scope,_task.protected,_task.allowed_materials,Setup.MATERIALS)
	if compiled.status != "validated_geometry":
		return compiled
	var footprint: Array[Vector2i] = compiled.footprint
	var initial: Dictionary = _world_ids(world,footprint)
	var simulated: Dictionary = initial.duplicate()
	var excluded: int = 0
	var ordered_writes: Array = []
	for raster: Dictionary in compiled.raster_operations:
		var filter_enabled: bool = raster.has("replace_only_material")
		var filtered_id: int = int(raster.get("replace_only_material",-1))
		var material: int = int(raster.material)
		for point: Vector2i in raster.cells:
			var previous: int = simulated[point]
			# Even a conditional filter may not read/change an unlicensed source
			# material in this first-stage task. Sand is not editable.
			if previous not in ALLOWED_SOURCES:
				return _refused("source_material_protected")
			if filter_enabled and previous != filtered_id:
				excluded += 1
				continue
			if previous != material:
				simulated[point] = material
				ordered_writes.append({"position":point,"material":material})
	var changed: int = 0
	var final_cells: Array = []
	for point: Vector2i in footprint:
		if initial[point] != simulated[point]:
			changed += 1
		final_cells.append({
			"x":point.x, "y":point.y,
			"before":initial[point], "after":simulated[point]
		})
	var proposal_id: String = _token("proposal",generation)
	var basis: Dictionary = _identity(world,generation,manual_revision)
	_proposal = {
		"id": proposal_id,
		"task_id":_task.task_id,
		"identity":basis,
		"source":initial,
		"final":simulated,
		"writes":ordered_writes.duplicate(true),
		"cells":final_cells.duplicate(true),
		"changed":changed,
		"excluded":excluded,
		"distinct_cells":footprint.size()
	}
	return {
		"status":"proposed",
		"proposal_id":proposal_id,
		"task_id":_task.task_id,
		"identity":basis,
		"footprint":final_cells,
		"distinct_cells":footprint.size(),
		"changed_cells":changed,
		"excluded_operations":excluded
	}


func _apply(command: Dictionary, world: Object,
		generation: int, manual_revision: int) -> Dictionary:
	var proposal_id: String = str(command.get("proposal_id",""))
	# Consume-first receipts must remain available across later task restarts.
	if _receipts.has(proposal_id):
		return _receipts[proposal_id].duplicate(true)
	if _proposal.is_empty() or proposal_id != str(_proposal.get("id","")):
		return _refused("unknown_or_retired_proposal")
	var receipt: Dictionary = {
		"status":"refused", "proposal_id":proposal_id,
		"task_id":_proposal.task_id, "reason":"stale_proposal"
	}
	if not _current(world,generation,manual_revision,_proposal.identity):
		_proposal.clear()
		_receipts[proposal_id] = receipt.duplicate(true)
		return receipt
	for point: Vector2i in _proposal.source.keys():
		if int(world.material_at(point.x,point.y)) != int(_proposal.source[point]):
			receipt.reason = "source_cells_changed"
			_proposal.clear()
			_receipts[proposal_id] = receipt.duplicate(true)
			return receipt
	# From here the existing worker is the only World writer. Its external
	# queue refuses human brush admission while this bounded call is in-flight.
	var issued: int = 0
	var confirmed: int = 0
	for instruction: Dictionary in _proposal.writes:
		var point: Vector2i = instruction.position
		var material: int = instruction.material
		world.emit_disc(point.x,point.y,0,material)
		issued += 1
		if int(world.material_at(point.x,point.y)) != material:
			receipt.status = "unconfirmed"
			receipt.reason = "native_write_readback_mismatch"
			break
		confirmed += 1
	var readback: Array = []
	var all_match: bool = issued == _proposal.writes.size()
	for cell: Dictionary in _proposal.cells:
		var now_id: int = int(world.material_at(cell.x,cell.y))
		var row: Dictionary = cell.duplicate()
		row["actual"] = now_id
		readback.append(row)
		if now_id != int(cell.after):
			all_match = false
	if all_match:
		receipt.status = "applied"
		receipt.reason = ""
	else:
		receipt.status = "unconfirmed"
		if receipt.reason == "stale_proposal":
			receipt.reason = "native_final_readback_mismatch"
		_quarantined = true
	receipt["issued_writes"] = issued
	receipt["confirmed_writes"] = confirmed
	receipt["distinct_cells"] = _proposal.distinct_cells
	receipt["changed_cells"] = _proposal.changed
	receipt["excluded_operations"] = _proposal.excluded
	receipt["readback"] = readback
	receipt["identity_before"] = _proposal.identity.duplicate(true)
	receipt["identity_after"] = _identity(world,generation,manual_revision)
	_receipts[proposal_id] = receipt.duplicate(true)
	_proposal.clear()
	_observation.clear()
	return receipt


## Callable ONLY from the existing worker's exclusive owner loop.
## This is not a network/API dispatch and never provides a World reference.
func execute(command: Dictionary, world: Object, generation: int,
		extent: Vector2i, paused: bool, manual_revision: int) -> Dictionary:
	var action: String = str(command.get("action",""))
	if typeof(command.get("schema_version",null)) != TYPE_INT \
			or int(command.schema_version) != SCHEMA_VERSION:
		return _refused("unsupported_tool_schema_version")
	if _quarantined:
		if action == "apply_edit":
			var old_id: String = str(command.get("proposal_id",""))
			if _receipts.has(old_id):
				return _receipts[old_id].duplicate(true)
		return _refused("authoring_quarantined_after_uncertain_native_outcome")
	if not paused or extent.x <= 0 or extent.y <= 0:
		return _refused("workbench_not_paused_or_unavailable")
	if world.has_method(&"has_failed") and bool(world.has_failed()):
		return _refused("native_world_failed")
	if action == "authorize_task":
		return _authorized(command,extent,generation)
	if _task.is_empty() or generation != int(_task.world_generation):
		_task.clear()
		_observation.clear()
		_proposal.clear()
		return _refused("task_not_authorized_for_world")
	match action:
		"observe":
			return _observe(command,world,extent,generation,manual_revision)
		"prepare_edit":
			return _prepare(command,world,extent,generation,manual_revision)
		"apply_edit":
			return _apply(command,world,generation,manual_revision)
		"retire_task":
			_task.clear()
			_observation.clear()
			_proposal.clear()
			return {"status":"retired"}
		_:
			return _refused("unknown_action")
