extends SceneTree

# Uses the actual Main scene, native worker, UI input dispatch and persistence.
# Two OS processes are required: create, then reopen the exact saved start.
# Mandatory scoped fixture: the unified qualifier supplies mode, example and
# an isolated evidence destination. Ordinary headless discovery cannot do so.
const Setup=preload("res://scripts/workbench_setup.gd")
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
const Inspector=preload("res://tests/support/workbench_reciprocal_inspector_checks.gd")
var host:Control
var bench:Control
var panel:Control
var checks:=0
var failures:Array[String]=[]
var completed:=false
var capture_index:=0
var startup_state:Dictionary={}
var timeout_diagnostics:Array[Dictionary]=[]
var integration_refusals:Dictionary={}
const RECOVERY_CASES:Dictionary={
	"swarm006_industrial_off":{"profile":0,"clutter":0.0,"size":Vector2i(192,112),"recovery":false},
	"swarm006_industrial_on":{"profile":0,"clutter":0.0,"size":Vector2i(192,112),"recovery":true},
	"swarm006_viaduct_on":{"profile":1,"clutter":0.15,"size":Vector2i(192,112),"recovery":true},
	"swarm006_irregular_on":{"profile":2,"clutter":0.25,"size":Vector2i(192,112),"recovery":true},
	"swarm006_irregular_square_on":{"profile":2,"clutter":0.25,"size":Vector2i(128,128),"recovery":true}}

func world_side()->int:
	return 2048 if RECOVERY_CASES.has(example) else 512
var evidence:=OS.get_environment("SWARM004_UI_EVIDENCE")
var mode:=OS.get_environment("SWARM004_UI_MODE")
var example:=OS.get_environment("SWARM004_UI_EXAMPLE")
var native_planes:Dictionary={}
var transport_refusals:Dictionary={}
var native_evidence:Dictionary={}
var inspector_evidence:Dictionary={}
var native_transactions:Dictionary={}
var saved_artifacts:Dictionary={}

func _initialize() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	run.call_deferred()

func check(ok:bool,label:String)->bool:
	checks+=1
	if not ok: failures.append(label);push_error("SWARM004_WORKBENCH "+label)
	return ok

func until(predicate:Callable,label:String,seconds:int=30)->bool:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	if timeout_diagnostics.size()<8:
		var diagnostic:=owner_diagnostics(label)
		diagnostic["timeout_seconds"]=seconds
		if not evidence.is_empty() and DisplayServer.get_name()!="headless":
			var path:=evidence+"/timeout-%02d.png" % timeout_diagnostics.size()
			var captured:=root.get_texture().get_image()
			diagnostic["screenshot_error"]=captured.save_png(path)
			diagnostic["screenshot"]=path.get_file()
		timeout_diagnostics.append(diagnostic)
		print("SWARM004_WORKBENCH_TIMEOUT ",JSON.stringify(diagnostic))
	return check(false,label)

func owner_diagnostics(label:String)->Dictionary:
	# Read bounded, already-published owner state only. Do not copy a terrain
	# publication or query the worker-exclusive World while diagnosing a stall.
	var result:Dictionary={"waiting_for":label,"process_frame":Engine.get_process_frames(),
		"physics_frame":Engine.get_physics_frames(),"elapsed_msec":Time.get_ticks_msec()}
	if host==null or not is_instance_valid(host):return result
	result.merge({"paused":host.paused,"microscenario_error":str(host.microscenario_error).left(1024),
		"pending_serial":int(host.pending_microscenario_apply.get("serial",-1)),
		"pending_workbench":host.pending_microscenario_apply.has("workbench"),
		"physical_candidate":host._pending_physical_candidate!=null,
		"physical_ready_sent":host._prepared_physical_ready_sent,
		"physical_identity_present":not host._prepared_physical_identity.is_empty(),
		"physical_epoch":host._physical_epoch,"physical_terrain_ready":host._physical_terrain_ready,
		"workbench_frame_error":str(host._workbench_frame_error).left(1024)})
	if host.simulation_worker!=null:
		result["worker_failed"]=host.simulation_worker.has_failed()
		result["paint"]=diagnostic_fields(host.simulation_worker.paint_state(),["generation","revision","tick",
			"authoring_generation","epoch","paused","busy","executing","queued","receipt_ready","art_busy",
			"legacy_busy","transition_busy","flatten_busy","status","reason","checked","applied"])
		result["art"]=diagnostic_fields(host.simulation_worker.art_state(),["epoch","executing","queued",
			"receipt_ready","paint_busy","legacy_busy","transition_busy","flatten_busy"])
	if host._pending_physical_candidate!=null:
		var candidate:RefCounted=host._pending_physical_candidate
		result["physical_candidate_state"]={"last_error":str(candidate.get("last_error")).left(1024),
			"verified_physics_frames":candidate.get("_verified_physics_frames"),
			"terrain_installed":candidate.get("_terrain_installed"),"terrain_ready":candidate.get("_terrain_ready")}
	if bench!=null and is_instance_valid(bench):
		result["workbench"]={"applied":not bench.applied.is_empty(),"busy":bench.busy(),
			"message":str(bench.message).left(1024),"pending_serial":bench._pending_request_serial,
			"step_pending":bench.step_pending,"flatten_pending":bench.is_flatten_pending()}
	if panel!=null and is_instance_valid(panel):
		result["reciprocal"]={"phase":panel.phase,"status":str(panel.status).left(1024),
			"child_pid":panel._pid,"thread_alive":panel._thread!=null and panel._thread.is_alive()}
	return result

func diagnostic_fields(source:Dictionary,keys:Array)->Dictionary:
	var result:Dictionary={}
	for key:String in keys:
		var value:Variant=source.get(key)
		if value is String:result[key]=value.left(1024)
		elif value is bool or value is int or value is float:result[key]=value
	return result

func settled()->bool:
	return bench!=null and not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty()

func find_button(node:Node,text:String)->Button:
	if node is Button and node.text==text: return node
	for child:Node in node.get_children():
		var found:=find_button(child,text)
		if found!=null: return found
	return null

func click(control:Control)->void:
	var position:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=position;Input.parse_input_event(motion)
	await process_frame
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event);await process_frame

func type_spin_text(field:SpinBox,text:String)->bool:
	var scroll:Node=field.get_parent()
	while scroll!=null and not scroll is ScrollContainer:scroll=scroll.get_parent()
	if scroll!=null:scroll.ensure_control_visible(field)
	await process_frame
	var editor:=field.get_line_edit()
	editor.grab_focus();await process_frame;editor.select_all()
	var before:=field.value
	for index:int in text.length():
		for down:bool in [true,false]:
			var event:=InputEventKey.new();event.keycode=text.unicode_at(index);event.unicode=text.unicode_at(index);event.pressed=down
			editor.get_viewport().push_input(event,true);await process_frame
	return check(editor.text==text and field.value==before and editor.has_focus(),
		"actual typed numeric text remains pending without Enter, Tab or direct value assignment")

func pointer(point:Vector2,pressed:bool)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	root.push_input(event,true);await process_frame

func gesture_invalidation(baseline:Dictionary)->bool:
	if not check(panel.phase=="ready" and panel.document.can_apply and not panel._apply.disabled,
		"gesture refusal starts from genuine native Apply authority"):return false
	var activation:Array=panel.activation.duplicate()
	panel._tool.select(1)
	var content:Rect2=host.view_content_rect()
	var point:Vector2=host.world_view.global_position+content.position+content.size*Vector2(0.4,0.5)
	await pointer(point,true)
	check(panel._dragging and not panel.protected_points.is_empty() and panel.document.is_empty() and panel._apply.disabled,
		"first protected mark retires native Apply before mouse release")
	var outside:Vector2=panel._status.get_global_rect().get_center()
	check(not host.world_view.get_global_rect().has_point(outside),"release fixture is outside the native canvas")
	await pointer(outside,false)
	check(not panel._dragging and panel._apply.disabled and panel.activation==activation,
		"release outside the canvas settles the gesture without restoring stale Apply")
	panel._tool.select(0)
	await pointer(point,true)
	var sampled:Array=panel._points.duplicate()
	check(panel._dragging and not sampled.is_empty(),"outside-release activation has a real sampled press")
	await pointer(outside,false)
	check(not panel._dragging and panel._points.is_empty() and panel.activation==sampled,
		"outside-canvas release commits the exact activation sample before resetting the gesture")
	activation=panel.activation.duplicate()
	# Cancel an incomplete activation gesture before its release. It must not
	# replace the prior committed activation points when that release arrives.
	panel._tool.select(0)
	await pointer(point,true)
	check(panel._dragging and not panel._points.is_empty(),"activation gesture is genuinely in progress")
	for down:bool in [true,false]:
		var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=down
		root.push_input(key,true);await process_frame
	await pointer(outside,false)
	check(not panel._dragging and panel._points.is_empty() and panel.activation==activation and panel._apply.disabled,
		"Escape cancels the unfinished activation gesture and its later release")
	check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),
		"protected/cancelled gestures leave every native cell and authored history unchanged")
	await click(find_button(panel,"Clear marks"))
	await paint_activation(true)
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"fresh native proposal follows gesture changes"):return false
	integration_refusals["gesture_lifecycle"]=check(panel.phase=="ready" and panel.document.get("can_apply",false),"fresh native execution restores Apply after gesture changes")
	return integration_refusals.gesture_lifecycle

func pending_field_invalidation(baseline:Dictionary)->bool:
	if not check(panel.phase=="ready" and panel.document.can_apply and not panel._apply.disabled,
		"pending-field refusal starts from genuine native Apply authority"):return false
	var original_seed:int=int(panel.controls.seed.value)
	if not await type_spin_text(panel.controls.seed,str(original_seed+1)):return false
	check(panel.document.is_empty() and panel.phase=="idle" and panel._apply.disabled,
		"uncommitted shared numeric text immediately retires the native proposal")
	await click(panel._apply)
	check(host.pending_microscenario_apply.is_empty() and panel.completed_applies==0 \
		and (await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),
		"clicking Apply after a pending numeric edit cannot install the old native proposal")
	if not await type_spin_text(panel.controls.seed,str(original_seed)):return false
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"regeneration commits the visible restored seed"):return false
	integration_refusals["pending_shared_text"]=check(panel.phase=="ready" and panel.document.get("can_apply",false) and panel.prepared.recipe.seed==original_seed,
		"Generate requalifies the visible recipe before Apply is enabled again")
	return integration_refusals.pending_shared_text

func capture()->Dictionary:
	var state:Dictionary=host.simulation_worker.paint_state()
	var admitted:Dictionary=host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not check(admitted.get("ok",false),"independent full native capture admitted: "+str(admitted.get("reason",""))): return {}
	var result:Dictionary={}
	var deadline:=Time.get_ticks_msec()+30000
	while result.is_empty() and Time.get_ticks_msec()<deadline:
		result=host.simulation_worker.material_capture_poll(int(admitted.token))
		await process_frame
	var finished:Dictionary=host.simulation_worker.material_capture_finish(int(admitted.token),false)
	check(result.get("ok",false) and finished.get("ok",false),"independent capture completed and lease released")
	return result

func screenshot(name_value:String)->void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence+"/"+name_value+".png")==OK,"original interactive capture "+name_value)

func retain_world(stage:String,cells:PackedByteArray)->void:
	native_planes[stage]=Protocol.digest(cells)
	var file:=FileAccess.open(evidence+"/"+stage+"-native.le16",FileAccess.WRITE)
	if not check(file!=null,"full native World plane destination opens: "+stage):return
	file.store_buffer(cells);file.close()

func retain_transaction(stage:String,operation:String,source:Dictionary,installed:Dictionary)->void:
	# The source witness comes from a separate native capture immediately before
	# the real UI action, never from the proposed patch or its acknowledgement.
	# Original full planes remain separate files; the reducer independently
	# reconstructs the canonical patch digest from their actual material changes.
	var extent:Vector2i=source.extent
	var receipt:Dictionary=panel.last_receipt.duplicate(true)
	check(receipt.get("operation")==operation and receipt.get("source_native_generation")==source.native_generation
		and receipt.get("source_revision")==source.revision and receipt.get("source_tick")==source.tick,
		stage+" native acknowledgement matches the independent pre-action source capture")
	check(installed.extent==extent and installed.native_generation>source.native_generation,
		stage+" acknowledgement installs a new native generation at the same extent")
	native_transactions[stage]={"operation":operation,
		"source_capture":{"native_generation":source.native_generation,"revision":source.revision,
			"tick":source.tick,"extent":[extent.x,extent.y]},
		"installed_capture":{"native_generation":installed.native_generation,"revision":installed.revision,
			"tick":installed.tick,"extent":[installed.extent.x,installed.extent.y]},
		"receipt":receipt,"source_material_sha256":Protocol.digest(source.cells),
		"installed_material_sha256":Protocol.digest(installed.cells)}

func retain_saved_artifacts()->void:
	var map_path:=Setup._path(bench._name.text)
	saved_artifacts={"map_sha256":FileAccess.get_sha256(map_path),
		"sidecar_sha256":FileAccess.get_sha256(map_path+".swarm004.json"),
		"evidence_sha256":FileAccess.get_sha256(map_path+".swarm004-evidence.json")}
	for key:String in saved_artifacts:
		check(str(saved_artifacts[key]).length()==64,"original saved artifact hash recorded: "+key)

func retain_native(name_value:String)->void:
	# Preserve original file bytes before invalidation cleans the child directory.
	# JSON contains the complete native request, rounds, receipts and final cells.
	var record:Dictionary={}
	for filename:String in ["request.txt","result.json"]:
		var source_path:String=panel._job_dir+"/"+filename
		var bytes:=FileAccess.get_file_as_bytes(source_path)
		if not check(not bytes.is_empty(),"retain complete native "+filename):return
		var name_out:String=name_value+"-"+filename
		var file:=FileAccess.open(evidence+"/"+name_out,FileAccess.WRITE)
		if not check(file!=null,"native evidence destination opens"):return
		file.store_buffer(bytes);file.close();record[name_out]=Protocol.digest(bytes)
	var size:Vector2i=panel.prepared.recipe.size
	var pixels:=Protocol.raster(panel.document,panel.prepared,-1,"Materials")
	var preview:=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,pixels)
	var pixel_name:=name_value+"-native-pixels.png"
	check(preview.save_png(evidence+"/"+pixel_name)==OK,"native material crop records actual accepted pixels")
	record[pixel_name]=FileAccess.get_sha256(evidence+"/"+pixel_name)
	var plane:=PackedByteArray();plane.resize(panel.document.cells.size()*2)
	for at:int in panel.document.cells.size():plane.encode_u16(at*2,int(panel.document.cells[at]))
	var plane_name:=name_value+"-material.le16"
	var plane_file:=FileAccess.open(evidence+"/"+plane_name,FileAccess.WRITE)
	if not check(plane_file!=null,"native proposed material plane destination opens"):return
	plane_file.store_buffer(plane);plane_file.close();record[plane_name]=Protocol.digest(plane)
	native_evidence[name_value]=record

func paint_activation(single_location:bool=false)->void:
	var content:Rect2=host.view_content_rect()
	var view:Control=host.world_view
	var a:=view.global_position+content.position+content.size*Vector2(0.38,0.52)
	var b:=view.global_position+content.position+content.size*Vector2(0.58,0.52)
	if single_location:
		# The preregistered known-seed transaction example uses one indicator
		# dab at local64,48. Dispatch actual canvas input; never inject masks.
		a=view.global_position+content.position+(Vector2(64.5,48.5)-Vector2(host.camera_origin).floor())/Vector2(host.current_view_size)*content.size
		b=a
	var event:=InputEventMouseButton.new();event.position=a;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	Input.parse_input_event(event);await process_frame
	for i:int in 8:
		var motion:=InputEventMouseMotion.new();motion.position=a.lerp(b,float(i)/7.0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion);await process_frame
	event=InputEventMouseButton.new();event.position=b;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
	Input.parse_input_event(event);await process_frame
	check(not panel.activation.is_empty(),"actual canvas brush sets approximate native activation territory")

func known_recipe()->void:
	# Fixed before evaluation from the registered605 layout matrix. This is a
	# zero-joint authoring example, not a reciprocal-construction certificate.
	panel.controls.width.value=128;panel.controls.height.value=96
	panel.controls.profile.select(1);panel.controls.profile.item_selected.emit(1)
	panel.controls.layout.select(2);panel.controls.layout.item_selected.emit(2)
	panel.controls.border.value=4;panel.controls.shared_extent.value=13
	panel.controls.seed.value=605;panel.controls.rounds.value=2
	panel.controls.clutter.value=0.15;panel.controls.destruction.value=0
	panel.controls.orientation.select(0);panel.controls.optional.button_pressed=true
	panel.controls.shared_ownership.button_pressed=true
	if example=="reciprocal":
		# Known-seed authoring compatibility study, independently checked with
		# exact-mask/no-offer and frozen-peer controls. The original seed605
		# zero-joint transaction remains a separate regression.
		panel.controls.seed.value=4099
		panel.controls.shared_ownership.button_pressed=false
		panel.controls.clutter.value=0
	if example.begins_with("swarm005_"):
		var profile_index:int=2 if example=="swarm005_irregular" else 1
		panel.controls.width.value=192;panel.controls.height.value=112
		panel.controls.profile.select(profile_index);panel.controls.profile.item_selected.emit(profile_index)
		panel.controls.layout.select(0);panel.controls.layout.item_selected.emit(0)
		panel.controls.seed.value=605
		panel.controls.shared_ownership.button_pressed=true
		panel.controls.clutter.value=0.25 if example=="swarm005_irregular" else 0.15
		panel.controls.compact_native_termination.button_pressed=true
		panel.controls.supported_native_receptors.button_pressed=true

	if RECOVERY_CASES.has(example):
		var selected:Dictionary=RECOVERY_CASES[example]
		panel.controls.width.value=selected.size.x;panel.controls.height.value=selected.size.y
		panel.controls.profile.select(selected.profile);panel.controls.profile.item_selected.emit(selected.profile)
		panel.controls.layout.select(0);panel.controls.layout.item_selected.emit(0)
		panel.controls.seed.value=605;panel.controls.rounds.value=2
		panel.controls.shared_ownership.button_pressed=true
		panel.controls.clutter.value=selected.clutter;panel.controls.destruction.value=0
		panel.controls.compact_native_termination.button_pressed=true
		panel.controls.supported_native_receptors.button_pressed=true
		panel.controls.negotiated_recovery.button_pressed=selected.recovery

static func map_name(selected:String)->String:
	if RECOVERY_CASES.has(selected):return selected+"-synthetic-eval"
	return "swarm005-v3-irregular-evaluation" if selected=="swarm005_irregular" else "swarm004-interactive-evaluation"

func reciprocal_witness()->Dictionary:
	var document:Dictionary=panel.document
	var rounds:Array=document.get("rounds",[])
	var changes:Dictionary={"frame":0,"mosaic":0}
	for index:int in range(1,rounds.size()):
		for owner:String in ["frame","mosaic"]:
			var before:Array=rounds[index-1][owner].result.cells
			var after:Array=rounds[index][owner].result.cells
			if before.size()!=after.size():continue
			for at:int in after.size():
				if (int(before[at])==0)!=(int(after[at])==0):changes[owner]+=1
	var unresolved:=0
	var foreign_joined:=0
	for obligation:Dictionary in document.get("obligations",[]):
		if obligation.get("state")=="STILL_REQUIRED":unresolved+=1
		if obligation.get("state")=="FOREIGN_JOINED" and obligation.get("foreign_joined")==true:foreign_joined+=1
	var obligation_count:int=document.get("obligations",[]).size()
	return {"frame_occupied_changes":changes.frame,"mosaic_occupied_changes":changes.mosaic,
		"joint_count":document.get("joints",[]).size(),"unresolved":unresolved,
		"obligation_count":obligation_count,"foreign_joined":foreign_joined,
		"all_foreign_closed":unresolved==0 and foreign_joined==obligation_count,
		"both_footprints_changed":changes.frame>0 and changes.mosaic>0,
		"scope":"array-derived native reciprocal revision and joint/closure witness; synthetic World only, offer causality independently controlled"}

func native_recipe()->Dictionary:
	# Read actual decoded immutable native requests, not controls that may have
	# changed after generation. Layout and border are hash-bound saved metadata.
	if panel.document.is_empty() or panel.prepared.is_empty():return {}
	var input:Dictionary=panel.document.input
	var options:Dictionary=input.options
	var profiles:Dictionary={}
	for owner:String in ["frame","mosaic"]:
		var values:Dictionary={}
		for key:String in Protocol.PARAMETERS:values[key]=input[owner].profile[key]
		profiles[owner]=values

	var recipe:Dictionary={"size":[input.frame.width,input.frame.height],"origin":input.frame.origin,
		"seed":input.frame.seed,"profile":input.frame.profile.name,"activation":input.frame.activation,
		"layout":panel.prepared.recipe.layout,"border":panel.prepared.recipe.border,
		"rounds":options.rounds,"shared_extent":options.shared_extent,"orientation":options.orientation_preference,
		"optional":options.optional_negotiation,"shared_ownership":options.shared_ownership,"gentek_parameters":profiles}
	if example.begins_with("swarm005_") or RECOVERY_CASES.has(example):
		recipe["compact_native_termination"]=options.get("compact_native_termination",false)
		recipe["supported_native_receptors"]=options.get("supported_native_receptors",false)
	if RECOVERY_CASES.has(example):
		recipe["negotiated_recovery"]=options.get("negotiated_recovery",false)
		recipe["world_extent"]=[host.world_extent.x,host.world_extent.y]
	return recipe

func stale_job_refusal(baseline:Dictionary)->void:
	# A crashed process may leave this PID/serial folder. It must be refused
	# before launch, without overwriting or adopting any older output.
	var path:=ProjectSettings.globalize_path("user://swarm004/job-%d-%d" % [OS.get_process_id(),panel._serial+1])
	DirAccess.make_dir_recursive_absolute(path)
	var file:=FileAccess.open(path+"/result.json",FileAccess.WRITE)
	file.store_string("stale-output-marker");file.close()
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase=="idle","stale output folder is refused before native launch"):return
	var refused:=check(panel._pid<0 and panel.document.is_empty() and panel._apply.disabled and "previous job folder" in panel.status,
		"PID reuse cannot admit stale evidence or launch an overlapping child")
	check(FileAccess.get_file_as_string(path+"/result.json")=="stale-output-marker","refused older output is not overwritten or adopted")
	check((await capture()).cells==baseline.cells,"stale-output refusal leaves every native World cell unchanged")
	transport_refusals["preexisting_job_directory"]=refused
	DirAccess.remove_absolute(path+"/result.json");DirAccess.remove_absolute(path)

func failed_exit_refusal(baseline:Dictionary)->void:
	# Transport seam only: retain the actual freshly generated native record
	# unchanged, while challenging its completion with a failed child status.
	var result:Dictionary=panel.proposal
	panel._thread=Thread.new();panel._thread_kind="decode";panel._thread_cancelled=false
	panel._child_exit_code=42;panel.phase="decoding"
	if not check(panel._thread.start(func()->Dictionary:return result)==OK,"failed-exit transport challenge starts bounded decoding completion"):return
	if not await until(func()->bool:return panel.phase=="idle","failed child execution retires an otherwise valid native record"):return
	transport_refusals["failed_child_positive"]=check(panel._apply.disabled and panel._pid<0 and "Failed native execution" in panel.status,
		"a native-positive result cannot authorize Apply after a failed child exit")
	Inspector.reset(panel,check,"failed child completion")
	check((await capture()).cells==baseline.cells,"failed-exit refusal leaves native material and authoring unchanged")

func runtime_manifest_refusal(baseline:Dictionary)->void:
	var prior:Dictionary={}
	for key:String in ["CYBERSAND_SWARM004_CLI","CYBERSAND_SWARM004_SOURCE","CYBERSAND_SWARM004_SHA256"]:
		prior[key]={"present":OS.has_environment(key),"value":OS.get_environment(key)}
	OS.set_environment("CYBERSAND_SWARM004_CLI",panel._runtime.path)
	OS.set_environment("CYBERSAND_SWARM004_SOURCE",panel._runtime.source)
	OS.set_environment("CYBERSAND_SWARM004_SHA256","0".repeat(64))
	var refused:bool=not panel.generate()
	for key:String in prior:
		if prior[key].present:OS.set_environment(key,prior[key].value)
		else:OS.unset_environment(key)
	transport_refusals["runtime_manifest_changed"]=check(refused and panel.phase=="idle" and panel._apply.disabled
		and panel.document.is_empty() and "source manifest" in panel.status,
		"failed fresh runtime identity retires the previous native-positive Apply authority")
	Inspector.reset(panel,check,"runtime identity refusal")
	check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),
		"runtime identity refusal preserves every native cell and the original authored history")
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"same candidate regenerates after runtime identity is restored"):return
	check(panel.phase=="ready" and panel.document.get("can_apply",false) and panel._round.selected==0,
		"fresh source-matched generation alone restores Apply and the final inspector")

func native_identity_refusals()->void:
	# Challenge a freshly generated native result, without modifying the actual
	# proposal, World, seed, controls or compiled generator. These are admission
	# regressions; altered receipts are never architectural success evidence.
	var original:Dictionary=panel.document
	var source:String=original.source
	check(Protocol.decode_document(original,JSON.stringify(original).to_utf8_buffer(),panel.prepared,source).ok,
		"genuine native output retains the exact qualified definition and limits")
	for owner:String in ["frame","mosaic"]:
		for key:String in Protocol.NATIVE_IDENTITIES[owner]:
			var altered:Dictionary=original.duplicate(true);altered.input[owner][key]=123
			check(not Protocol.decode_document(altered,JSON.stringify(altered).to_utf8_buffer(),panel.prepared,source).ok,
				"actual native output refuses changed "+owner+" "+key)
		for key:String in Protocol.NATIVE_LIMITS:
			var altered:Dictionary=original.duplicate(true);altered.input[owner].limits[key]+=1
			check(not Protocol.decode_document(altered,JSON.stringify(altered).to_utf8_buffer(),panel.prepared,source).ok,
				"actual native output refuses increased "+owner+" "+key+" ceiling")

func changed_world_refusal(baseline:Dictionary)->void:
	var outside:=Vector2i(world_side()-32,world_side()-32)
	if not check(bench.paint(outside,58),"ordinary native brush changes the live World after preview"):return
	# The ordinary brush queues native work before the authored-history fence
	# retires the preview. Wait for that separate queue to settle before readback.
	if not await until(func()->bool:return panel.phase=="idle" and panel.document.is_empty() and not bench.busy() \
		and not host.simulation_worker.paint_state().get("legacy_busy",false),
		"changed source retires the provisional native result"):return
	var changed:=await capture()
	if changed.is_empty():return
	Inspector.reset(panel,check,"changed native World source")
	var changed_at:=(outside.y*world_side()+outside.x)*2
	transport_refusals["changed_world_source"]=check(panel._apply.disabled and changed.cells!=baseline.cells
		and changed.cells.decode_u16(changed_at)==58 and panel.completed_applies==0,
		"changed World source cannot install a previously generated proposal")
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(world_side(),world_side()))),
		"fresh declared baseline restores after source-fence challenge"):return
	if not await until(settled,"fresh declared baseline installs after source-fence challenge",60):return
	Inspector.reset(panel,check,"native World replacement")
	check((await capture()).cells==baseline.cells,"source-fence challenge restores every original native cell")
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"same candidate regenerates against restored World"):return
	check(panel.phase=="ready" and panel.document.get("can_apply",false),"only fresh native success restores Apply after World change")

func corrupted_evidence_refusal(expected:PackedByteArray)->void:
	var map_path:=Setup._path(bench._name.text)
	var path:=map_path+".swarm004-evidence.json"
	var bytes:=FileAccess.get_file_as_bytes(path)
	if not check(not bytes.is_empty(),"acknowledged saved evidence is present for corruption challenge"):return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not check(file!=null,"saved evidence corruption challenge opens"):return
	file.store_buffer(bytes);file.store_string("corrupted-evidence");file.close()
	var refused:Dictionary=Protocol.load_saved(map_path)
	await click(find_button(panel,"Inspect saved evidence"))
	if not await until(func()->bool:return panel.phase=="idle","actual saved inspector refuses corrupt evidence"):return
	var ui_refused:bool=panel.document.is_empty() and panel._apply.disabled and "changed after acknowledgement" in panel.status
	Inspector.reset(panel,check,"corrupt saved evidence")
	file=FileAccess.open(path,FileAccess.WRITE)
	if not check(file!=null,"original saved evidence can be restored"):return
	file.store_buffer(bytes);file.close()
	var restored:Dictionary=Protocol.load_saved(map_path)
	transport_refusals["corrupted_saved_evidence"]=check(not refused.ok and restored.ok and ui_refused
		and (await capture()).cells==expected,"corrupted saved evidence refuses inspection and cannot mutate native World")
	await click(find_button(panel,"Inspect saved evidence"))
	if not await until(func()->bool:return panel.phase=="historical","restored saved evidence opens through the actual inspector"):return
	check(panel._round.selected==0 and panel._selected_proposal_round_index()==-1 and panel._apply.disabled,
		"restored saved evidence starts at final composition without Apply authority")

func lifecycle(baseline:Dictionary)->void:
	for action:String in ["cancel","hide","timeout"]:
		if not panel.visible:panel.open_panel()
		await click(panel._generate)
		if not await until(func()->bool:return panel.phase=="running" and panel._pid>0,"real bounded lifecycle child starts"):return
		var pid:int=panel._pid
		check(OS.is_process_running(pid),action+" fixture is an actual running OS child")
		var old_activation:Array=panel.activation.duplicate()
		var content:Rect2=host.view_content_rect()
		var point:Vector2=host.world_view.global_position+content.position+content.size*Vector2(0.4,0.5)
		await pointer(point,true);await pointer(point,false)
		check(panel.activation==old_activation and not bench.paint_editor.busy(),
			"territory input during "+action+" generation cannot fall through into native PAINT")
		if action=="cancel":await click(find_button(panel,"Cancel"))
		elif action=="hide":await click(find_button(panel,"Close"))
		if not await until(func()->bool:return panel.phase=="idle" and panel._pid<0 and panel._thread==null,
			"native child is reaped after "+action,35):return
		check(await until(func()->bool:return process_absent(pid),"independent native probe confirms child retirement",2),action+" leaves no child process")
		check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),action+" preserves native World and authored history")
		if action=="timeout":check("30-second" in panel.status,"actual wall-clock timeout reports its bounded refusal")
	panel.open_panel();await click(panel._generate)
	if not await until(func()->bool:return panel.phase=="running" and panel._pid>0,"shutdown lifecycle child starts"):return
	var pid:int=panel._pid
	host.queue_free();await process_frame;await process_frame;host=null;panel=null
	check(await until(func()->bool:return process_absent(pid),"shutdown native child retirement",2),"actual Workbench tree teardown retires the running child")
	completed=true

func process_absent(pid:int)->bool:
	# OS.kill retires Godot's child bookkeeping. The test fixture independently
	# probes the OS so the assertion does not query an already reaped handle.
	return OS.execute(OS.get_environment("CYBERSAND_SWARM004_CLI"),PackedStringArray(["probe",str(pid)]))==0

func create_map()->void:
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(world_side(),world_side()))),"finite blank source admitted"): return
	if not await until(settled,"finite blank source installed",60): return
	var baseline:=await capture()
	if baseline.is_empty(): return
	retain_world("baseline",baseline.cells)
	check(bench.reciprocal_panel==null and bench.art_batches==null,"ordinary startup leaves experimental generation off and Art unconstructed")
	var open:=find_button(bench,"Reciprocal assembly…")
	if not check(open!=null,"experimental composition entry is available"): return
	await click(open)
	panel=bench.reciprocal_panel
	if not check(panel!=null and panel.visible,"real button opens one lazy inline dock"): return
	Inspector.reset(panel,check,"fresh actual Workbench dock")
	check(panel._pid<0 and panel._thread==null and bench.art_batches==null,"opening the dock launches no generation or Art restoration")
	check(not panel.controls.compact_native_termination.button_pressed and not panel.controls.supported_native_receptors.button_pressed
		and not panel.controls.negotiated_recovery.button_pressed,"all three experimental native policies remain separately off when the dock opens")
	if mode in ["create","blocked","evaluate"]:known_recipe()
	await paint_activation(mode in ["create","blocked","evaluate"])
	if mode=="lifecycle":await lifecycle(baseline);return
	if mode=="smoke":
		await screenshot("dock-open")
		await click(find_button(panel,"Close"))
		check(not panel.visible and panel._pid<0,"Close retires preview work")
		completed=true;return
	if mode in ["create","evaluate"]:await stale_job_refusal(baseline)
	var request_seed:=OS.get_environment("SWARM004_UI_SEED")
	# Registered create/reopen recipes are immutable. A legacy global605 must
	# never silently substitute for the independently selected reciprocal4099.
	if mode not in ["create","evaluate"] and not request_seed.is_empty(): panel.controls.seed.value=int(request_seed)
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"native child generation reaches terminal result"):return
	if not check(panel.phase=="ready" and not panel.document.is_empty(),"source-matched native evidence produced: "+panel.status):return
	check(panel._pid<0 and panel._thread==null,"completed native child and parsing worker are reaped")
	inspector_evidence["initial"]=Inspector.verify(panel,check,"initial native generation")
	var preview:=await capture()
	retain_world("preview",preview.cells)
	check(preview.cells==baseline.cells,"real native preview leaves all World cells unchanged")
	retain_native("initial")
	await screenshot("native-preview")
	for name_value:String in ["Joints","Unresolved","Clearance","Revisions"]:
		Inspector.select_layer(panel,name_value)
		await screenshot("inspector-final-"+name_value.to_lower())
	Inspector.select_layer(panel,"Materials")
	if mode=="blocked" or (mode=="evaluate" and not panel.document.can_apply):
		check(example=="swarm005_viaduct" or RECOVERY_CASES.has(example),"explicit negative or recorded SWARM006 synthetic evaluation")
		check(not panel.document.can_apply and panel._apply.disabled,"blocked native proposal cannot be installed")
		if example=="swarm005_viaduct":
			check(panel.document.get("status","")=="blocked" and reciprocal_witness().unresolved>0,
				"V3 Viaduct negative retains genuinely required unresolved foreign obligations")
		else:
			check(panel.document.get("status","") in ["blocked","unsat","exhausted","oscillation"],
				"unsuccessful recovery is retained under its actual bounded native classification")
		check(bool(panel.prepared.recipe.get("compact_native_termination",false)) and bool(panel.prepared.recipe.get("supported_native_receptors",false)),
			"blocked V3 case actually exercises both explicit experimental switches")
		for i:int in panel._layer.item_count:
			panel._layer.select(i);panel._render();await process_frame
		check(panel.prepared.recipe.parameters.clutter==(RECOVERY_CASES[example].clutter if RECOVERY_CASES.has(example) else 0.15) and panel.prepared.recipe.parameters.destruction==0,
			"V3 negative retains independent native decoration and destruction")
		Inspector.select_layer(panel,"Unresolved")
		await screenshot("native-unresolved")
		await click(panel._apply)
		check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),"disabled Apply preserves World and authored history")
		await click(find_button(panel,"Close"))
		check(panel._pid<0 and panel._thread==null and not panel.visible,"closing blocked preview leaves no computation")
		completed=true;return
	if mode in ["create","evaluate"]:
		if not check(panel.document.can_apply,"failed-exit challenge starts from an actual native-positive result"):return
		if example=="transaction":
			if not await pending_field_invalidation(baseline):return
			if not await gesture_invalidation(baseline):return
		await runtime_manifest_refusal(baseline)
		if not check(panel.phase=="ready" and panel.document.get("can_apply",false),"fresh positive candidate survives runtime identity refusal"):return
		await failed_exit_refusal(baseline)
		await click(panel._generate)
		if not await until(func()->bool:return panel.phase in ["ready","idle"],"fresh generation follows failed-exit refusal"):return
		if not check(panel.phase=="ready" and panel.document.get("can_apply",false),"fresh successful native execution restores Apply authority"):return
	if not check(panel.document.can_apply,"native composition independently authorizes Apply: "+panel.status):return
	if RECOVERY_CASES.has(example):
		await changed_world_refusal(baseline)
		if not check(panel.phase=="ready" and panel.document.get("can_apply",false),"fresh recovery candidate survives source-fence exercise"):return
	native_identity_refusals()
	if example=="swarm005_irregular" or RECOVERY_CASES.has(example):
		check(panel.prepared.recipe.origin==Vector2i.ZERO and panel.prepared.recipe.activation==[Vector2i(64,48)]
			and panel.prepared.recipe.layout=="left_right" and panel.prepared.recipe.border==4
			and panel.prepared.recipe.get("size",Vector2i.ZERO)==(RECOVERY_CASES[example].size if RECOVERY_CASES.has(example) else Vector2i(192,112)),
			"native authoring retains the declared finite synthetic left-right geometry")
		check(bool(panel.prepared.recipe.get("compact_native_termination",false)) and bool(panel.prepared.recipe.get("supported_native_receptors",false)),
			"both SWARM005 source-feasibility/receptor options passed to native V3")
	else:
		check(panel.prepared.recipe.origin==Vector2i.ZERO and panel.prepared.recipe.activation==[Vector2i(64,48)]
			and panel.prepared.recipe.layout=="centered_frame_rectangle" and panel.prepared.recipe.border==4,
			"visible controls and actual brush reproduce the declared transaction territory")
	if example=="reciprocal":
		var witness:=reciprocal_witness()
		if not check(witness.both_footprints_changed and witness.joint_count>0 and witness.obligation_count>0 and witness.all_foreign_closed,
			"both native occupied footprints revise with real joints and full foreign closure"):return
		check(not panel.prepared.recipe.shared_ownership and panel.prepared.recipe.shared_extent==13 \
			and panel.prepared.recipe.seed==4099,"selected fixed-territory recipe retains its independent negotiation band")
	var expected:PackedByteArray=baseline.cells.duplicate()
	for at:int in range(0,panel.proposal.cells.size(),3):
		var cells:PackedInt32Array=panel.proposal.cells
		expected.encode_u16((cells[at+1]*world_side()+cells[at])*2,cells[at+2])
	var first_source:=await capture()
	if not check(not first_source.is_empty() and first_source.get("ok",false)
		and first_source.cells==baseline.cells,"first Apply independently captures the unchanged native source"):return
	await click(panel._apply)
	if not await until(func()->bool:return panel.completed_applies==1,"actual Apply receives native acknowledgement"):return
	var applied:=await capture()
	retain_world("applied",applied.cells)
	retain_transaction("first_apply","build",first_source,applied)
	check(applied.cells==expected,"Apply equals the exact complete native proposal and all retained source cells")
	await screenshot("native-applied")
	var undo_source:=await capture()
	if not check(not undo_source.is_empty() and undo_source.get("ok",false)
		and undo_source.cells==applied.cells,"Undo independently captures the exact installed native source"):return
	await click(panel._undo_button)
	if not await until(func()->bool:return panel.completed_undos==1,"actual Undo receives native acknowledgement"):return
	var undone:=await capture()
	retain_world("undone",undone.cells)
	retain_transaction("undo","remove",undo_source,undone)
	check(undone.cells==baseline.cells and bench.applied.edits.is_empty(),"Undo restores all native cells and original authored history")
	await screenshot("native-undone")
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase=="ready","same-seed regeneration completes"):return
	inspector_evidence["regenerated"]=Inspector.verify(panel,check,"regeneration after Undo")
	retain_native("regenerated")
	var reapply_source:=await capture()
	if not check(not reapply_source.is_empty() and reapply_source.get("ok",false)
		and reapply_source.cells==undone.cells,"second Apply independently captures the unchanged post-Undo source"):return
	await click(panel._apply)
	if not await until(func()->bool:return panel.completed_applies==2,"second actual Apply receives acknowledgement"):return
	var regenerated:=await capture()
	retain_world("regenerated",regenerated.cells)
	retain_transaction("reapply","build",reapply_source,regenerated)
	check(regenerated.cells==expected,"same-seed regenerated native construction is exact")
	bench._name.text=map_name(example)
	var save:=find_button(bench,"Save start [Ctrl+S]")
	if not check(save!=null,"ordinary Save start button exists"):return
	await click(save)
	var saved:=Setup.read_named(bench._name.text)
	check(not saved.has("error") and saved.setup.edits==bench.applied.edits,"ordinary Save persists acknowledged composition history")
	check(FileAccess.file_exists(Setup._path(bench._name.text)+".swarm004.json"),"saved map has optional source/revision evidence receipt")
	retain_saved_artifacts()
	var saved_plane:=await capture()
	retain_world("saved",saved_plane.cells)
	check(saved_plane.cells==expected,"ordinary Save preserves the complete acknowledged native plane")
	if RECOVERY_CASES.has(example):await corrupted_evidence_refusal(expected)
	var file:=FileAccess.open(evidence+"/expected-native.le16",FileAccess.WRITE)
	if not check(file!=null,"fresh-process expected plane can be recorded"):return
	file.store_buffer(expected);file.close()
	native_planes["expected"]=Protocol.digest(expected)
	await screenshot("native-saved")
	completed=true

func historical_latch_refusals(expected:PackedByteArray,saved_proposal_sha:String)->bool:
	var map_path:=Setup._path(bench._name.text)
	var saved_hashes:Dictionary={}
	for suffix:String in ["",".swarm004.json",".swarm004-evidence.json"]:
		saved_hashes[suffix]=FileAccess.get_sha256(map_path+suffix)
	var history:Array=bench.applied.edits.duplicate(true)
	await click(panel._apply)
	await click(find_button(panel,"Cancel"))
	integration_refusals["historical_cancel_latched"]=check(panel._read_only_evidence() and panel._apply.disabled and panel._undo_button.disabled,
		"actual Cancel cannot discard saved evidence's read-only latch")
	if not await type_spin_text(panel.controls.seed,str(int(panel.controls.seed.value)+1)):return false
	Inspector.reset(panel,check,"historical pending numeric edit")
	integration_refusals["historical_edit_latched"]=check(panel._read_only_evidence() and not panel.apply_construction()
		and not panel.undo_construction() and not panel._submit(bench.applied,{"operation":"build"},"build")
		and not panel.attests(bench.applied,{"operation":"build"}),"edited historical evidence still refuses every transaction entry")
	var runtime:Dictionary=panel._runtime_info()
	if not check(runtime.get("ok",false),"fresh-generation latch test uses the admitted current runtime"):return false
	known_recipe()
	await paint_activation(true)
	var environment:Dictionary={}
	for key:String in ["CYBERSAND_SWARM004_CLI","CYBERSAND_SWARM004_SOURCE","CYBERSAND_SWARM004_SHA256"]:
		environment[key]=OS.get_environment(key)
	OS.set_environment("CYBERSAND_SWARM004_CLI",runtime.path)
	OS.set_environment("CYBERSAND_SWARM004_SOURCE",runtime.source)
	OS.set_environment("CYBERSAND_SWARM004_SHA256","0".repeat(64))
	await click(panel._generate)
	for key:String in environment:OS.set_environment(key,environment[key])
	integration_refusals["historical_failed_generation_latched"]=check(panel.phase=="idle" and panel._read_only_evidence()
		and panel.document.is_empty() and panel._apply.disabled and panel._pid<0,
		"failed replacement runtime admission cannot release saved evidence's transaction latch")
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"fresh current-source generation replaces actual saved inspection"):return false
	integration_refusals["historical_fresh_generation"]=check(panel.phase=="ready" and panel._child_exit_code==0
		and not panel._read_only_evidence() and not panel.proposal.get("historical_only",true)
		and panel.document.input.frame.definition=="frameweaver.frontier-growth-v0."+Protocol.NATIVE_DEFINITION
		and panel.document.input.mosaic.definition=="mosaic.prepared-regions-v0."+Protocol.NATIVE_DEFINITION,
		"only a successful fresh combined-definition child restores current transaction authority")
	if not integration_refusals.historical_fresh_generation:return false
	retain_native("historical-refresh")
	check(panel.completed_applies==0 and panel.completed_undos==0 and bench.applied.edits==history
		and (await capture()).cells==expected,"fresh generation after historical inspection preserves the reopened World and history")
	await click(find_button(panel,"Inspect saved evidence"))
	if not await until(func()->bool:return panel.phase=="historical","original saved receipt reopens after fresh generation"):return false
	var identical:=true
	for suffix:String in saved_hashes:identical=identical and FileAccess.get_sha256(map_path+suffix)==saved_hashes[suffix]
	integration_refusals["historical_files_unchanged"]=check(identical and panel._read_only_evidence()
		and panel.proposal.proposal_sha256==saved_proposal_sha and panel.document.get("can_apply",false),
		"saved map, receipt and native result retain all original bytes and raw can_apply evidence")
	inspector_evidence["reopened"]=Inspector.verify(panel,check,"saved evidence after authority recovery")
	return integration_refusals.historical_files_unchanged

func reopen_map()->void:
	bench._name.text=map_name(example)
	await click(find_button(bench,"Load start"))
	if not await until(settled,"saved map installs in a fresh OS process"):return
	retain_saved_artifacts()
	var actual:=await capture()
	var expected:=FileAccess.get_file_as_bytes(evidence+"/expected-native.le16")
	retain_world("reopened",actual.cells)
	native_planes["expected"]=Protocol.digest(expected)
	check(actual.get("cells")==expected and expected.size()==world_side()*world_side()*2,"fresh-process native World exactly matches saved composition plane")
	check(not bench.applied.edits.is_empty(),"fresh-process authored history includes construction stamps")
	await click(find_button(bench,"Reciprocal assembly…"));panel=bench.reciprocal_panel
	await click(find_button(panel,"Inspect saved evidence"))
	if not await until(func()->bool:return panel.phase=="historical","saved native evidence opens in the fresh process"):return
	inspector_evidence["reopened"]=Inspector.verify(panel,check,"fresh-process saved evidence")
	check(panel._apply.disabled and panel._pid<0
		and panel.prepared.recipe.layout==("left_right" if example=="swarm005_irregular" or RECOVERY_CASES.has(example) else "centered_frame_rectangle")
		and panel.prepared.recipe.border==4,"saved ownership and revision evidence is inspection-only without child generation")
	check(panel.proposal.get("historical_only",false) and panel._historical_only and panel._undo_button.disabled,
		"saved inspection has explicit read-only authority and no construction Undo")
	check(panel.document.get("can_apply",false),"inspection retains the original successful native result without rewriting its can_apply evidence")
	var saved_history:Array=bench.applied.edits.duplicate(true)
	var saved_proposal_sha:String=panel.proposal.proposal_sha256
	check(not panel.apply_construction() and not panel.undo_construction()
		and not panel._submit(bench.applied,{"operation":"build"},"build")
		and not panel.attests(bench.applied,{"operation":"build"}),
		"historical evidence refuses Apply, Undo, submission and attestation")
	check(panel.phase=="historical" and panel._pid<0 and panel.proposal.proposal_sha256==saved_proposal_sha
		and bench.applied.edits==saved_history and (await capture()).cells==expected,
		"historical inspection and refused actions preserve exact native cells, authored history and evidence")
	if example=="reciprocal":
		var witness:=reciprocal_witness()
		check(witness.both_footprints_changed and witness.joint_count>0 and witness.obligation_count>0 and witness.all_foreign_closed \
			and not panel.prepared.recipe.shared_ownership,"fresh process retains exact reciprocal witness and fixed ownership")
	if example=="transaction" and not await historical_latch_refusals(expected,saved_proposal_sha):return
	await screenshot("native-reopened")
	completed=true

func run()->void:
	if not check(mode in ["create","reopen","blocked","evaluate","lifecycle","smoke"],"explicit scoped Workbench UI mode is required"):
		quit(1);return
	if not check(not evidence.is_empty(),"explicit isolated Workbench UI evidence directory is required"):
		quit(1);return
	if not check(example in ["transaction","reciprocal","swarm005_irregular","swarm005_viaduct"] or RECOVERY_CASES.has(example),"explicit registered authoring example"):
		quit(1);return
	# Validate every synthetic label against the real saved-map contract before
	# spending time on graphical startup or native construction.
	for selected:String in RECOVERY_CASES:
		if not check(not Setup._path(map_name(selected)).is_empty(),"valid synthetic saved-map name: "+selected):
			quit(1);return
	root.size=Vector2i(1920,1080)
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	if OS.get_environment("SWARM004_REQUIRE_GRAPHICS")=="1" and not check(DisplayServer.get_name()!="headless","graphical qualification has a real display"):
		quit(1);return
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate();root.add_child(host)
	bench=host.shared_workbench
	var startup_begin:=Time.get_ticks_msec()
	var startup_ok:=await until(settled,"real Shared Workbench startup completed",120)
	startup_state={"milliseconds":Time.get_ticks_msec()-startup_begin,"watchdog_msec":120000,
		"applied":not bench.applied.is_empty(),"busy":bench.busy(),"pending":host.pending_microscenario_apply.duplicate(true),
		"worker_failed":host.simulation_worker.has_failed(),"message":bench.message,"native_error":host.microscenario_error}
	if startup_ok:
		if mode=="reopen":await reopen_map()
		else:await create_map()
	check(completed,"complete interactive test sequence reached its final assertion")
	var report:Dictionary={"schema":2,"mode":mode,"example":example,"checks":checks,"failures":failures,"completed":completed,
		"engine":Engine.get_version_info().string,"platform":OS.get_name(),"process_id":OS.get_process_id(),
		"display":DisplayServer.get_name(),"startup":startup_state,"native_planes_sha256":native_planes,"transport_refusals":transport_refusals,
		"native_evidence_sha256":native_evidence,
		"native_transactions":native_transactions,"saved_artifacts":saved_artifacts,
		"inspector_evidence":inspector_evidence,"integration_refusals":integration_refusals,"timeout_diagnostics":timeout_diagnostics,
		"owner_visual_acceptance":"pending","reciprocal_programme_acceptance":false,
		"test_sha256":FileAccess.get_sha256("res://tests/swarm456_reciprocal_ui.gd")}
	if panel!=null:
		report["historical_only"]=panel._read_only_evidence();report["controller_phase"]=panel.phase
		report["apply_disabled"]=panel._apply.disabled;report["undo_disabled"]=panel._undo_button.disabled
		report["native_receipt"]=panel.last_receipt;report["native_source"]=panel._runtime
		if panel.phase=="historical":report["native_receipt"]=panel.proposal.get("receipt",{}).get("native_receipt",{})
		report["native_status"]=panel.document.get("status","");report["native_reason"]=panel.document.get("reason","")
		report["native_can_apply"]=panel.document.get("can_apply",false)
		report["native_recipe"]=native_recipe();report["proposal_sha256"]=panel.proposal.get("proposal_sha256","")
		report["applied"]=panel.completed_applies>0
		report["joint_count"]=panel.document.get("joints",[]).size();report["obligation_count"]=panel.document.get("obligations",[]).size()
		report["material_count"]=panel.proposal.get("cells",[]).size()/3
		report["native_stop_reason"]=panel.document.get("stop_reason","")
		report["native_work"]=panel.document.get("metrics",{})
		report["scope"]="actual native authoring transaction and persistence; reciprocal research acceptance remains separate"
		report["reciprocal_witness"]=reciprocal_witness()
		report["reciprocal_witness_passed"]=example=="reciprocal" and completed and failures.is_empty() \
			and report.reciprocal_witness.both_footprints_changed and report.reciprocal_witness.joint_count>0 \
			and report.reciprocal_witness.obligation_count>0 and report.reciprocal_witness.all_foreign_closed
	if host!=null:host.queue_free();await process_frame;await process_frame
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence+"/"+mode+".json",FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SWARM004_WORKBENCH ",JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
