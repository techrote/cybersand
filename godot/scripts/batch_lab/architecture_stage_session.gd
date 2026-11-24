extends Node
## Offline/typed-plan adapter. It owns decisions, never a World or provider.
## Existing Art executor, native worker and PAINT history remain authoritative.
signal changed
signal terminal(record: Dictionary)
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const FORMAT := "cybersand-architecture-session-v1"
const MAX_FILE_BYTES := 64*1024*1024
const MAX_RECORDS := 256
const EVIDENCE_SCOPE := "Decisions and native material evidence. Ordinary Workbench Save start owns authored geometry. Reopen never resumes work or asserts current-World completion."
var wb: Node
var library: RefCounted
var plan: Dictionary = {}
var states: Dictionary = {}
var records: Array = []
var imported_history: Array = []
var preview: Dictionary = {}
var selected := 0
var message := "Load an offline typed plan or select an example."
var _action := false
var _executing := false
var _verifying := false
var _revision := 0
var _executor: RefCounted
var _submission := -1
var _receipts: Array = []
var _execution: Dictionary = {}
var _stopping := false
var _placed_protection: Array = []
var _protection_generation := -1
var _retained_bytes := 0
var _imported_history_bytes := 0

func _envelope(value: Dictionary, state_value: Dictionary, record_value: Array, history_value: Array) -> Dictionary:
	return {"format":FORMAT,"plan":value,"plan_sha256":Compiler.digest(Compiler.canonical(value).to_utf8_buffer()),
		"states":state_value,"records":record_value,"imported_history":history_value,"scope":EVIDENCE_SCOPE}

func _envelope_bytes(value: Dictionary, state_value: Dictionary) -> int:
	# Empty arrays contribute their brackets already. Account for every retained
	# record, separator and imported historical byte without serializing 64 MiB
	# of unchanged evidence for each preview or owner decision.
	return Compiler.canonical(_envelope(value,state_value,[],[])).to_utf8_buffer().size() \
		+_retained_bytes+maxi(records.size()-1,0)+_imported_history_bytes

func _can_retain(extra_bytes: int, value: Dictionary, state_value: Dictionary) -> bool:
	return records.size()<MAX_RECORDS and _envelope_bytes(value,state_value)+extra_bytes+1<=MAX_FILE_BYTES

func _retain(record: Dictionary) -> void:
	var copied: Dictionary=record.duplicate(true)
	_retained_bytes += Compiler.canonical(copied).to_utf8_buffer().size()
	records.append(copied)

func busy() -> bool:
	return _action or _executing or _verifying

func stage() -> Dictionary:
	if plan.is_empty() or selected<0 or selected>=plan.stages.size(): return {}
	return plan.stages[selected]

func stage_state() -> String:
	return str(states.get(stage().get("id",""),"proposed"))

func _answer(ok: bool, reason: String) -> Dictionary:
	message = reason
	changed.emit()
	return {"ok":ok,"reason":reason}

func load_plan(value: Variant) -> Dictionary:
	if busy(): return _answer(false,"Stop and wait for native acknowledgement before replacing the plan.")
	var valid: Dictionary = Compiler.validate_plan(value)
	if not valid.ok: return _answer(false,valid.reason)
	var next_states: Dictionary = {}
	for item: Dictionary in valid.plan.stages: next_states[item.id] = "proposed"
	if _envelope_bytes(valid.plan,next_states)>MAX_FILE_BYTES:
		return _answer(false,"The new plan and retained evidence exceed this session's 64 MiB capacity. Save its history and start a separate session.")
	plan = valid.plan
	states = next_states
	selected = 0
	preview.clear()
	_revision += 1
	return _answer(true,"Plan loaded. Inspect and preview each stage before approval.")

func select(index: int) -> Dictionary:
	if busy(): return _answer(false,"Finish or Stop the current stage before selecting another.")
	if plan.is_empty() or index<0 or index>=plan.stages.size(): return _answer(false,"Unknown stage.")
	selected = index
	preview.clear()
	_revision += 1
	return _answer(true,"Selected "+str(stage().id)+". Preview requires a fresh native inspection.")

func revise(value: Variant) -> Dictionary:
	if busy(): return _answer(false,"Stop and wait for native acknowledgement before revision.")
	if stage().is_empty() or not value is Dictionary: return _answer(false,"Select a stage and supply a typed stage object.")
	if stage_state()=="completed": return _answer(false,"Completed geometry has native history. Add a new stage or Undo it before changing the plan.")
	var candidate: Dictionary = plan.duplicate(true)
	if value.get("id")!=stage().id: return _answer(false,"A revision preserves its stage id and dependency identity.")
	candidate.stages[selected] = value.duplicate(true)
	var valid: Dictionary = Compiler.validate_plan(candidate)
	if not valid.ok: return _answer(false,valid.reason)
	var decision: Dictionary = {"kind":"revision","stage_id":stage().id,"previous_stage":stage().duplicate(true),"replacement":value.duplicate(true)}
	var next_states: Dictionary = states.duplicate()
	next_states[stage().id] = "proposed"
	if not _can_retain(Compiler.canonical(decision).to_utf8_buffer().size(),valid.plan,next_states):
		return _answer(false,"Session evidence capacity reached. Save and reopen a fresh review session before further revision.")
	_retain(decision)
	plan = valid.plan
	states[stage().id] = "proposed"
	preview.clear()
	_revision += 1
	return _answer(true,"Revision retained. Preview the revised stage before approval.")

func completed_ids() -> Array:
	var completed: Array = []
	for identity: String in states:
		if states[identity]=="completed": completed.append(identity)
	return completed

func _workbench_ready() -> String:
	if not is_instance_valid(wb) or not wb.is_inside_tree() or wb.host==null or wb.applied.is_empty(): return "Open an installed native Workbench."
	if not wb.host.paused: return "Pause the Workbench before static architectural construction."
	if wb.busy(): return "Wait for the current Workbench transaction."
	if wb.host.simulation_worker.has_failed(): return "Native owner failed; recover the World before construction."
	var human: Dictionary = wb.art_authoring_state()
	if human.get("busy",false) or not str(human.get("reason","")).is_empty(): return str(human.get("reason","Finish the current human paint gesture.")) if not str(human.get("reason","")).is_empty() else "Finish the current human paint gesture."
	if is_instance_valid(wb.art_batches):
		if wb.art_batches.executor.active or wb.art_batches.provider.active: return "Wait for the existing Art request or native batch."
	return ""

func _inspect(value: Dictionary) -> Dictionary:
	var reason := _workbench_ready()
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	var region: Rect2i = Compiler.rect(value.get("region"))
	var captured: Dictionary = await wb.capture_batch_source(region)
	if not captured.get("ok",false): return captured
	var config: Dictionary = captured.config
	var provenance: Dictionary = config.source_provenance
	if _protection_generation!=-1 and _protection_generation!=int(provenance.source_world_generation): _placed_protection.clear()
	_protection_generation=int(provenance.source_world_generation)
	return {"ok":true,"source_cells":config.source_cells,"source_sha256":provenance.crop_sha256,
		"region":Compiler.rect_array(region),"world_region":Compiler.rect_array(Rect2i(Vector2i.ZERO,Setup.extent_of(wb.applied))),
		"generation":provenance.source_world_generation,"paused":wb.host.paused,"allowed_materials":Setup.MATERIALS,
		"provenance":provenance.duplicate(true),"protected":_placed_protection.duplicate(true)}

func _verify_dependencies(value: Dictionary, inspected: Dictionary) -> Dictionary:
	var additional_inspection := false
	for identity: Variant in value.get("depends_on",[]):
		if states.get(identity)!="completed": return {"ok":false,"reason":"Dependency has no completed native stage: "+str(identity)}
		var record: Dictionary = {}
		for i: int in range(records.size()-1,-1,-1):
			if records[i].get("kind")=="native-stage" and records[i].get("stage_id")==identity and records[i].get("status")=="completed":
				record = records[i]
				break
		if record.is_empty(): return {"ok":false,"reason":"Dependency is missing its retained native evidence."}
		var region: Rect2i = Compiler.rect(inspected.region)
		var dependency_region: Rect2i = Compiler.rect(record.stage.region)
		var current := inspected
		if not region.encloses(dependency_region):
			additional_inspection = true
			current = await _inspect(record.stage)
			if not current.get("ok",false): return current
			region = dependency_region
		if int(current.generation)!=int(record.generation): return {"ok":false,"reason":"Dependency belongs to a replaced World; preview its construction again."}
		var cells: PackedByteArray = current.source_cells
		for receipt: Dictionary in record.native_receipts:
			for row: Array in receipt.get("readback",[]):
				var point := Vector2i(int(row[0]),int(row[1]))
				if not region.has_point(point): return {"ok":false,"reason":"Dependency evidence escapes its inspected region."}
				var local := point-region.position
				if cells.decode_u16((local.y*region.size.x+local.x)*2)!=int(row[3]):
					states[identity] = "proposed"
					return {"ok":false,"reason":"A completed dependency was changed or undone. Reinspect it before continuing: "+str(identity)}
	return {"ok":true,"additional_inspection":additional_inspection}

func preview_selected() -> Dictionary:
	if busy(): return _answer(false,"Wait for the current stage action.")
	if stage().is_empty(): return _answer(false,"Load a finite typed plan first.")
	if stage_state()=="completed": return _answer(false,"This stage is already complete. Inspect its retained native receipt, or make a new stage.")
	var revision := _revision
	var value := stage().duplicate(true)
	_action = true
	states[value.id] = "inspecting"
	message = "Inspecting authoritative native material geometry…"
	changed.emit()
	var context: Dictionary = await _inspect(value)
	if revision!=_revision: _action = false; return _answer(false,"Preview cancelled before compilation; no construction was queued.")
	if not context.get("ok",false):
		_action = false
		states[value.id] = "refused"
		preview.clear()
		return _answer(false,str(context.get("reason","Native inspection refused.")))
	var dependencies: Dictionary = await _verify_dependencies(value,context)
	if revision!=_revision: _action=false; return _answer(false,"Preview cancelled during dependency inspection.")
	if not dependencies.ok:
		_action = false
		states[value.id] = "refused"
		preview.clear()
		return _answer(false,dependencies.reason)
	var compiler := Compiler.new()
	var answer: Dictionary = compiler.begin(value,context,library,completed_ids())
	while answer.ok and not compiler.done and revision==_revision:
		answer = compiler.step()
		if not compiler.done: await get_tree().process_frame
	_action = false
	if revision!=_revision: return _answer(false,"Preview cancelled; no construction was queued.")
	if not answer.ok:
		states[value.id] = "refused"
		preview.clear()
		var refusal: Dictionary = {"kind":"preview-refusal","stage_id":value.id,"reason":answer.reason,"zero_writes":true}
		if _can_retain(Compiler.canonical(refusal).to_utf8_buffer().size(),plan,states): _retain(refusal)
		return _answer(false,answer.reason)
	preview = compiler.result
	preview["inspection"] = context.provenance
	states[value.id] = "previewed"
	message = "Zero-write preview: %d checked / %d distinct / %d changed cells. Approve, Revise or Skip." % [preview.budget.checked_cells,preview.budget.unique_cells,preview.budget.changed_cells]
	changed.emit()
	return {"ok":true,"preview":preview.duplicate(true)}

func approve() -> Dictionary:
	if busy(): return _answer(false,"Wait for the current stage action.")
	if preview.is_empty() or stage_state()!="previewed": return _answer(false,"A fresh zero-write preview is required before approval.")
	var revision := _revision
	var value := stage().duplicate(true)
	var approved: Dictionary = preview.duplicate(true)
	var region: Rect2i=Compiler.rect(approved.region)
	var retained_module_bytes:=Compiler.canonical(approved.resolved_modules).to_utf8_buffer().size()+Compiler.canonical(approved.new_protected_regions).to_utf8_buffer().size()
	var retention_bound:=Compiler.canonical(value).to_utf8_buffer().size()+retained_module_bytes+int(approved.budget.checked_cells)*128+region.get_area()*4+65536
	if not _can_retain(retention_bound,plan,states):
		return _answer(false,"Exact receipt retention, the complete plan and imported history exceed this session's 64 MiB capacity. Save its evidence and start a separate session before executing.")
	_action = true
	message = "Rechecking native source before approval…"
	changed.emit()
	var context: Dictionary = await _inspect(value)
	if revision!=_revision: _action=false; return _answer(false,"Approval cancelled before native submission.")
	if not context.get("ok",false): _action=false; return _answer(false,str(context.get("reason","Native approval inspection refused.")))
	var dependencies: Dictionary = await _verify_dependencies(value,context)
	if revision!=_revision: _action=false; return _answer(false,"Approval cancelled during dependency inspection.")
	if not dependencies.ok: _action=false; preview.clear(); return _answer(false,dependencies.reason)
	if dependencies.get("additional_inspection",false):
		# A separate dependency capture yielded control after the stage source
		# was inspected. Rebind the stage to its actual current bytes before
		# synchronous submission, including any intervening human edits.
		context = await _inspect(value)
		if revision!=_revision: _action=false; return _answer(false,"Approval cancelled during final source inspection.")
		if not context.get("ok",false): _action=false; return _answer(false,str(context.get("reason","Final source inspection refused.")))
	_action = false
	if context.source_sha256!=approved.source_sha256 or int(context.generation)!=int(approved.generation):
		preview.clear()
		states[value.id] = "proposed"
		return _answer(false,"World geometry changed since preview. Inspect and preview again; no stage writes occurred.")
	if Compiler.digest(Compiler.canonical(value).to_utf8_buffer())!=approved.stage_sha256:
		preview.clear()
		return _answer(false,"Stage changed since preview. Preview the revision again.")
	for selected_module: Dictionary in approved.resolved_modules:
		var current: Dictionary = library.get_module(selected_module.id)
		if current.get("content_sha256")!=selected_module.sha256:
			preview.clear()
			return _answer(false,"A selected module changed since preview. Preview again.")
	var reason := _workbench_ready()
	if not reason.is_empty(): return _answer(false,reason)
	_executor = wb._ensure_art_batches().executor
	if not _executor.native_receipt.is_connected(_native_receipt): _executor.native_receipt.connect(_native_receipt)
	_receipts.clear()
	_stopping = false
	_execution = {"kind":"native-stage","stage_id":value.id,"stage":value,"preview_sha256":approved.preview_sha256,
		"source_sha256":approved.source_sha256,"expected_sha256":approved.projected_sha256,
		"generation":approved.generation,"budget":approved.budget.duplicate(),"resolved_modules":approved.resolved_modules.duplicate(true),
		"new_protected_regions":approved.new_protected_regions.duplicate(true),
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"godot":Engine.get_version_info().string,"platform":OS.get_name(),
		"started_usec":Time.get_ticks_usec(),"status":"queued","native_receipts":[]}
	var submitted: Dictionary = _executor.submit(approved.operations,Compiler.rect(approved.region),approved.protected,approved.materials)
	if submitted.get("status")!="queued":
		states[value.id] = "refused"
		_execution.status = "refused"
		_execution.reason = str(submitted.get("reason","Native stage admission refused."))
		_retain(_execution)
		return _answer(false,_execution.reason)
	_submission = _executor.batch_sequence
	_executing = true
	states[value.id] = "queued"
	return _answer(true,"Approved and queued. Native construction is not complete until receipts and readback are verified.")

func _native_receipt(receipt: Dictionary) -> void:
	if not _executing or _executor.batch_sequence!=_submission: return
	_receipts.append(receipt.duplicate(true))
	changed.emit()

func _process(_delta: float) -> void:
	if not _executing or _verifying or _executor==null: return
	if _executor.batch_sequence!=_submission:
		_executing = false
		states[_execution.stage_id] = "partial"
		_execution.status = "partial"
		_execution.reason = "The shared native executor submission changed; explicit recovery is required."
		_execution.native_receipts = _receipts.duplicate(true)
		_execution["final_readback_available"] = false
		_execution["native_receipts_sha256"] = Compiler.digest(Compiler.canonical(_receipts).to_utf8_buffer())
		_execution["elapsed_usec"] = Time.get_ticks_usec()-int(_execution.started_usec)
		_retain(_execution)
		preview.clear()
		_answer(false,_execution.reason)
		terminal.emit(_execution.duplicate(true))
		return
	if _executor.active:
		states[_execution.stage_id] = "applying"
		return
	_verifying = true
	_finish.call_deferred()

static func receipt_accounting(receipts: Array, budget: Dictionary) -> Dictionary:
	var checked := 0
	var changed_cells := 0
	var exact := true
	for receipt: Dictionary in receipts:
		var receipt_checked := int(receipt.get("checked",0))
		checked += receipt_checked
		changed_cells += int(receipt.get("changed",0))
		if receipt.get("backend")!="CyberNativeCellWorld" or receipt.get("status")!="completed" \
			or int(receipt.get("confirmed",0))!=receipt_checked or int(receipt.get("confirmed",0))!=receipt.get("readback",[]).size() \
			or int(receipt.get("excluded",0))!=0 or int(receipt.get("refused",0))!=0:
			exact = false
	return {"checked":checked,"changed":changed_cells,"exact":exact,
		"complete":exact and checked==int(budget.checked_cells) and changed_cells==int(budget.changed_cells)}

func _finish() -> void:
	var native_result: Dictionary = _executor.result.duplicate(true)
	var value: Dictionary = _execution.stage
	states[value.id] = "verifying"
	message = "Native executor retired. Verifying actual material readback…"
	changed.emit()
	var captured: Dictionary = await _inspect(value)
	var accounting := receipt_accounting(_receipts,_execution.budget)
	var checked := int(accounting.checked)
	var changed_cells := int(accounting.changed)
	var status := "partial" if checked>0 else ("cancelled" if _stopping else "refused")
	var reason := str(native_result.get("reason",""))
	if native_result.get("status")=="completed" and captured.get("ok",false) and accounting.complete \
			and captured.source_sha256==_execution.expected_sha256 and int(captured.generation)==int(_execution.generation):
		status = "completed"
		reason = "No material changes were required; fresh native readback matches the approved projection." if checked==0 else "Complete native receipts and authoritative material readback match every approved change."
	elif reason.is_empty():
		reason = str(captured.get("reason","Native prefix retained; current material geometry differs from the approved projection."))
	_execution.status = status
	_execution.reason = reason
	_execution["native_result"] = native_result
	_execution["native_receipts"] = _receipts.duplicate(true)
	_execution["native_receipts_sha256"] = Compiler.digest(Compiler.canonical(_receipts).to_utf8_buffer())
	_execution["checked_cells"] = checked
	_execution["changed_cells"] = changed_cells
	_execution["elapsed_usec"] = Time.get_ticks_usec()-int(_execution.started_usec)
	_execution["final_readback_available"] = captured.get("ok",false)
	if captured.get("ok",false):
		_execution["result_sha256"] = captured.source_sha256
		_execution["inspection"] = captured.provenance
		_execution["result_materials_base64"] = Marshalls.raw_to_base64(captured.source_cells)
		_execution["module_observations"] = _qualify_module_observations(captured) if status=="completed" else []
	_retain(_execution)
	if status=="completed":
		for guard: Array in _execution.get("new_protected_regions",[]):
			if guard not in _placed_protection: _placed_protection.append(guard.duplicate())
	states[value.id] = status
	preview.clear()
	_executing = false
	_verifying = false
	message = status.capitalize()+": "+reason
	changed.emit()
	terminal.emit(_execution.duplicate(true))

func _qualify_module_observations(captured: Dictionary) -> Array:
	var observations: Array = []
	if library==null: return observations
	var region: Rect2i = Compiler.rect(captured.region)
	var cells: PackedByteArray = captured.source_cells
	for resolved: Dictionary in _execution.resolved_modules:
		var placement: Dictionary = resolved.placement
		if placement.get("transform","identity")!="identity": continue
		if not placement.get("palette",{}).is_empty() or float(placement.get("variation",{}).get("keep_fraction",1.0))!=1.0: continue
		var module: Dictionary = library.get_module(resolved.id)
		if module.is_empty() or module.content_sha256!=resolved.sha256: continue
		var extent:=Vector2i(int(module.extent[0]),int(module.extent[1]))
		var origin:=Vector2i(int(placement.origin[0]),int(placement.origin[1]))
		if not region.encloses(Rect2i(origin,extent)): continue
		var crop:=PackedByteArray()
		crop.resize(extent.x*extent.y*2)
		for y: int in extent.y:
			for x: int in extent.x:
				var local:=origin-region.position+Vector2i(x,y)
				crop.encode_u16((y*extent.x+x)*2,cells.decode_u16((local.y*region.size.x+local.x)*2))
		# The library independently compares every byte against original geometry.
		# Palettes/variation/overlap qualify only if they actually preserve it.
		var answer: Dictionary=library.mark_native_replay_verified(resolved.id,crop,extent,
			{"ok":true,"status":"completed","backend":"CyberNativeCellWorld","generation":int(captured.generation),"capture_sha256":Compiler.digest(crop)})
		observations.append({"module_id":resolved.id,"exact_original_geometry":answer.get("ok",false),"capture_sha256":Compiler.digest(crop),
			"scope":"Fresh native identity-orientation material observation; transformed variants retain separate stage evidence."})
	return observations

func cancel() -> Dictionary:
	if not busy() and stage_state()=="completed": return _answer(false,"This stage already completed. Its native evidence remains retained; use ordinary Undo to change geometry.")
	_revision += 1
	preview.clear()
	_stopping = true
	if _executing and _executor!=null and _executor.batch_sequence==_submission:
		_executor.stop("Architecture stage cancelled by owner")
		return _answer(true,"Stop requested. Waiting for the exact native prefix and final readback.")
	if not stage().is_empty(): states[stage().id] = "cancelled"
	return _answer(true,"Proposal cancelled. No queued construction is resumed automatically.")

func skip() -> Dictionary:
	if busy(): return _answer(false,"Stop and wait before skipping a stage.")
	if stage().is_empty(): return _answer(false,"No selected stage.")
	if stage_state()=="completed": return _answer(false,"Completed geometry cannot be relabelled as skipped; use ordinary Undo.")
	var decision: Dictionary = {"kind":"decision","stage_id":stage().id,"status":"skipped","zero_writes":true}
	var next_states: Dictionary = states.duplicate()
	next_states[stage().id] = "skipped"
	if not _can_retain(Compiler.canonical(decision).to_utf8_buffer().size(),plan,next_states): return _answer(false,"Session evidence capacity reached; save the evidence before starting a separate session.")
	states[stage().id] = "skipped"
	_retain(decision)
	preview.clear()
	_revision += 1
	return _answer(true,"Stage skipped. Stages depending on it remain blocked until revised.")

func save_session(path: String) -> Dictionary:
	if busy(): return _answer(false,"Wait for native acknowledgement before saving the architecture session.")
	if plan.is_empty(): return _answer(false,"Load a plan before saving.")
	var value := _envelope(plan,states,records,imported_history)
	var bytes := Compiler.canonical(value).to_utf8_buffer()
	if bytes.size()>MAX_FILE_BYTES: return _answer(false,"Session evidence exceeds 64 MiB. Export the completed plan before starting another.")
	var module_library: Script = load("res://scripts/batch_lab/native_module_library.gd")
	var saved: Dictionary = module_library._atomic_write(path,value,MAX_FILE_BYTES)
	return _answer(saved.get("ok",false),"Session saved; save the ordinary Workbench start separately to retain authored geometry." if saved.get("ok",false) else str(saved.get("reason","Session write failed; previous file retained.")))

func open_session(path: String) -> Dictionary:
	if busy(): return _answer(false,"Stop and wait before opening a session.")
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return _answer(false,"Could not open the architecture session.")
	if file.get_length()>MAX_FILE_BYTES: return _answer(false,"Architecture session exceeds 64 MiB.")
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not value is Dictionary or value.get("format")!=FORMAT or not value.get("plan") is Dictionary: return _answer(false,"Malformed architecture session.")
	if Compiler.digest(Compiler.canonical(value.plan).to_utf8_buffer())!=str(value.get("plan_sha256","")): return _answer(false,"Saved plan identity does not match its content.")
	if not value.get("records",[]) is Array or not value.get("imported_history",[]) is Array: return _answer(false,"Saved evidence arrays are malformed.")
	var valid: Dictionary = Compiler.validate_plan(value.plan)
	if not valid.ok: return _answer(false,valid.reason)
	var history: Array = value.get("imported_history",[]).duplicate(true)
	history.append({"source_file":path,"file_sha256":FileAccess.get_sha256(path),"records":value.get("records",[]).duplicate(true),
		"scope":"Imported historical claims, not fresh native execution in this process."})
	var next_states: Dictionary = {}
	for item: Dictionary in valid.plan.stages: next_states[item.id] = "proposed"
	var history_bytes := Compiler.canonical(history).to_utf8_buffer().size()-2
	if Compiler.canonical(_envelope(valid.plan,next_states,[],[])).to_utf8_buffer().size()+history_bytes>MAX_FILE_BYTES:
		return _answer(false,"Preserving this complete imported history and its provenance would exceed 64 MiB. The current session and source file remain intact.")
	plan = valid.plan
	states = next_states
	selected = 0
	preview.clear()
	_revision += 1
	imported_history = history
	records.clear()
	_retained_bytes=0
	_imported_history_bytes=history_bytes
	return _answer(true,"Session reopened for review. Every stage requires fresh inspection and approval in this process.")

func _exit_tree() -> void:
	_revision += 1
	if _executing and _executor!=null and _executor.batch_sequence==_submission: _executor.stop("Architecture session closed")
	if _executor!=null and _executor.native_receipt.is_connected(_native_receipt): _executor.native_receipt.disconnect(_native_receipt)
