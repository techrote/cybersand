extends RefCounted
## Cooperative no-write preview. The existing Art raster is evaluated against
## copied native materials. Only the ordinary Art executor may later mutate.
const Context = preload("res://scripts/art_world_context.gd")
const Plan = preload("res://scripts/art_batch_plan.gd")
var active := false
var result: Dictionary = {}
var _compiled: Dictionary = {}
var _materials := PackedInt32Array()
var _region := Rect2i()
var _extent := Vector2i()
var _plan: RefCounted
var _index := 0
var _stage: Dictionary = {}
var _stage_stats: Dictionary = {}
var _stages: Array = []
var _conflicts: Array = []
var _conflict_count := 0
var _requested := 0
var _changed := 0
var _unchanged := 0
var _started_usec := 0
var _maximum_poll_usec := 0
var _configure_usec := 0

func configure(compiled: Dictionary, context: Dictionary) -> bool:
	var configure_started := Time.get_ticks_usec()
	if active: return false
	if not compiled.get("ok",false) or not context.get("ok",false) \
			or not context.has("_capture") or compiled.get("context_digest") != context.get("digest") \
			or compiled.get("source") != context.get("source") \
			or compiled.get("policy_digest") != context.get("policy_digest"):
		result = {"ok":false,"status":"refused","error":"Preview requires the exact captured source and owner constraints.","zero_native_writes":true}
		return false
	var capture: Dictionary = context._capture
	if not capture.get("materials") is PackedInt32Array or not capture.get("region") is Rect2i:
		result = {"ok":false,"status":"refused","error":"Missing copied native material plane.","zero_native_writes":true}
		return false
	_compiled = compiled.duplicate(true)
	_region = capture.region
	_materials = capture.materials.duplicate()
	if _materials.size() != _region.size.x*_region.size.y:
		result = {"ok":false,"status":"refused","error":"Incomplete copied native material plane.","zero_native_writes":true}
		return false
	_extent = Vector2i(int(context.model.world_size[0]),int(context.model.world_size[1]))
	_index = 0
	_stages.clear()
	_conflicts.clear()
	_conflict_count = 0
	_requested = 0
	_changed = 0
	_unchanged = 0
	_maximum_poll_usec = 0
	_started_usec = Time.get_ticks_usec()
	active = true
	result = {"ok":true,"status":"previewing","stage":0,"stages":compiled.stages.size(),
		"requested":0,"zero_native_writes":true}
	_begin_stage()
	_configure_usec = Time.get_ticks_usec()-configure_started
	return true

func _begin_stage() -> void:
	_stage = _compiled.stages[_index]
	_plan = Plan.new()
	if not _plan.configure(_stage.operations,Rect2i(Vector2i.ZERO,_extent)):
		_finish("refused","Previously validated geometry no longer parses: "+_plan.error)
		return
	_stage_stats = {"id":_stage.id,"title":_stage.title,"requested":0,"predicted_changed":0,
		"predicted_unchanged":0,"conflicts":0,"introduced":{},"removed":{},
		"before_materials_sha256":Context.hash_materials(_materials)}

func _conflict(point: Vector2i, reason: String, before: int, desired: int) -> void:
	_conflict_count += 1
	_stage_stats.conflicts += 1
	if _conflicts.size() < 32:
		_conflicts.append({"stage":_stage.id,"x":point.x,"y":point.y,"before":before,
			"desired":desired,"reason":reason})

func poll() -> Dictionary:
	if not active: return result
	var began := Time.get_ticks_usec()
	# ArtBatchPlan already budgets candidate work, including sparse misses.
	# One chunk per call retains its existing cooperative frame yielding.
	var chunk: Dictionary = _plan.next_chunk(4096)
	if not chunk.is_empty():
		var points: PackedInt32Array = chunk.points
		var desired := int(chunk.material)
		for at: int in range(0,points.size(),2):
			var point := Vector2i(points[at],points[at+1])
			_requested += 1
			_stage_stats.requested += 1
			if not _region.has_point(point) or not _stage.scope.has_point(point):
				_conflict(point,"Outside the admitted native observation",-1,desired)
				continue
			var index := (point.y-_region.position.y)*_region.size.x+point.x-_region.position.x
			var before := int(_materials[index])
			var protected := false
			for guard: Rect2i in _stage.guards:
				if guard.has_point(point): protected = true; break
			if protected:
				_conflict(point,"Owner-protected region",before,desired)
			elif desired not in _stage.allowed:
				_conflict(point,"Destination material is outside the owner palette",before,desired)
			elif before not in Context.SOURCE_POLICY:
				_conflict(point,"Ordinary Art protects this existing material; only Empty and Hard Wall are editable",before,desired)
			elif before != 0 and before != desired and not bool(_compiled.allow_destructive):
				_conflict(point,"Replacing occupied material requires explicit destructive permission",before,desired)
			elif desired == 0 and not bool(_compiled.allow_destructive):
				_conflict(point,"Erase requires explicit destructive permission",before,desired)
			else:
				if before == desired:
					_unchanged += 1
					_stage_stats.predicted_unchanged += 1
				else:
					_changed += 1
					_stage_stats.predicted_changed += 1
					_stage_stats.introduced[desired] = int(_stage_stats.introduced.get(desired,0))+1
					_stage_stats.removed[before] = int(_stage_stats.removed.get(before,0))+1
					_materials[index] = desired
	if _plan.exhausted():
		_stage_stats.after_materials_sha256 = Context.hash_materials(_materials)
		_stages.append(_stage_stats.duplicate(true))
		_index += 1
		if _index >= _compiled.stages.size():
			if _conflict_count > 0:
				_finish("refused","Proposal has "+str(_conflict_count)+" requested cells conflicting with owner/native policy. Revise it before approval.")
			elif not _compiled.proposal.get("unresolved",[]).is_empty():
				_finish("refused","Resolve the proposal's outstanding questions before native approval.")
			else:
				_finish("ready","")
		else: _begin_stage()
	_maximum_poll_usec = maxi(_maximum_poll_usec,Time.get_ticks_usec()-began)
	if not active:
		result.maximum_poll_usec = _maximum_poll_usec
		result.elapsed_usec = Time.get_ticks_usec()-_started_usec
	if active:
		result = {"ok":true,"status":"previewing","stage":_index,"stages":_compiled.stages.size(),
			"requested":_requested,"predicted_changed":_changed,"conflicts":_conflict_count,
			"zero_native_writes":true}
	return result

func cancel() -> void:
	if active: _finish("cancelled","Preview cancelled; no native edits were submitted.")

func _finish(status: String, error: String) -> void:
	active = false
	result = {"ok":status == "ready","status":status,"error":error,
		"proposal_digest":_compiled.get("proposal_digest",""),"context_digest":_compiled.get("context_digest",""),
		"policy_digest":_compiled.get("policy_digest",""),"source":_compiled.get("source",{}).duplicate(),
		"stages":_stages.duplicate(true),"requested":_requested,"predicted_changed":_changed,
		"predicted_unchanged":_unchanged,"conflict_count":_conflict_count,"conflicts":_conflicts.duplicate(true),
		"conflicts_omitted":maxi(0,_conflict_count-_conflicts.size()),
		"predicted_materials_sha256":Context.hash_materials(_materials),
		"maximum_poll_usec":_maximum_poll_usec,"configure_usec":_configure_usec,"elapsed_usec":Time.get_ticks_usec()-_started_usec,
		"zero_native_writes":true,
		"notice":"Predictions from copied stored materials, not execution receipts or actor/body-mask predictions. Native body exclusions, fresh source validation and explicit approval still apply."}
	_plan = null

func predicted_materials() -> PackedInt32Array:
	# Developer/UI diagnostic only; not part of model-visible context.
	return _materials.duplicate()
