extends SceneTree

# Uses the actual Main scene, native worker, UI input dispatch and persistence.
# Two OS processes are required: create, then reopen the exact saved start.
const Setup=preload("res://scripts/workbench_setup.gd")
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
var host:Control
var bench:Control
var panel:Control
var checks:=0
var failures:Array[String]=[]
var completed:=false
var capture_index:=0
var evidence:=OS.get_environment("SWARM004_UI_EVIDENCE")
var mode:=OS.get_environment("SWARM004_UI_MODE")
var example:=OS.get_environment("SWARM004_UI_EXAMPLE")
var native_planes:Dictionary={}
var transport_refusals:Dictionary={}

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
	return check(false,label)

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

func capture()->Dictionary:
	var state:Dictionary=host.simulation_worker.paint_state()
	var admitted:Dictionary=host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not check(admitted.get("ok",false),"independent full native capture admitted"): return {}
	var result:Dictionary={}
	var deadline:=Time.get_ticks_msec()+15000
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

func map_name()->String:
	return "swarm005-v3-irregular-evaluation" if example=="swarm005_irregular" else "swarm004-interactive-evaluation"

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
		"scope":"array-derived native reciprocal revision and joint/closure witness; offer causality is independently controlled"}

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
	if example.begins_with("swarm005_"):
		recipe["compact_native_termination"]=options.get("compact_native_termination",false)
		recipe["supported_native_receptors"]=options.get("supported_native_receptors",false)
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
	check((await capture()).cells==baseline.cells,"failed-exit refusal leaves native material and authoring unchanged")

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

func lifecycle(baseline:Dictionary)->void:
	for action:String in ["cancel","hide","timeout"]:
		if not panel.visible:panel.open_panel()
		await click(panel._generate)
		if not await until(func()->bool:return panel.phase=="running" and panel._pid>0,"real bounded lifecycle child starts"):return
		var pid:int=panel._pid
		check(OS.is_process_running(pid),action+" fixture is an actual running OS child")
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
	if not check(bench.apply(Setup.fresh(PackedInt32Array(bench.applied.liquid_policy),Vector2i(512,512))),"finite blank source admitted"): return
	if not await until(settled,"finite blank source installed"): return
	var baseline:=await capture()
	if baseline.is_empty(): return
	native_planes["baseline"]=Protocol.digest(baseline.cells)
	check(bench.reciprocal_panel==null,"experimental dock has no hidden startup instance or computation")
	var open:=find_button(bench,"Reciprocal assembly…")
	if not check(open!=null,"experimental composition entry is available"): return
	await click(open)
	panel=bench.reciprocal_panel
	if not check(panel!=null and panel.visible,"real button opens one lazy inline dock"): return
	check(panel._pid<0 and panel._thread==null,"opening the dock launches no generation")
	if mode=="create" or mode=="blocked":known_recipe()
	await paint_activation(mode=="create" or mode=="blocked")
	if mode=="lifecycle":await lifecycle(baseline);return
	if mode=="smoke":
		await screenshot("dock-open")
		await click(find_button(panel,"Close"))
		check(not panel.visible and panel._pid<0,"Close retires preview work")
		completed=true;return
	if mode=="create":await stale_job_refusal(baseline)
	var request_seed:=OS.get_environment("SWARM004_UI_SEED")
	# Registered create/reopen recipes are immutable. A legacy global605 must
	# never silently substitute for the independently selected reciprocal4099.
	if mode!="create" and not request_seed.is_empty(): panel.controls.seed.value=int(request_seed)
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase in ["ready","idle"],"native child generation reaches terminal result"):return
	if not check(panel.phase=="ready" and not panel.document.is_empty(),"source-matched native evidence produced: "+panel.status):return
	check(panel._pid<0 and panel._thread==null,"completed native child and parsing worker are reaped")
	var preview:=await capture()
	native_planes["preview"]=Protocol.digest(preview.cells)
	check(preview.cells==baseline.cells,"real native preview leaves all World cells unchanged")
	await screenshot("native-preview")
	if mode=="blocked":
		check(example=="swarm005_viaduct","only explicit V3 Viaduct negative is designated blocked")
		check(not panel.document.can_apply and panel._apply.disabled,"blocked native proposal cannot be installed")
		check(panel.document.get("status","")=="blocked" and reciprocal_witness().unresolved>0,
			"V3 Viaduct negative retains genuinely required unresolved foreign obligations")
		check(bool(panel.prepared.recipe.get("compact_native_termination",false)) and bool(panel.prepared.recipe.get("supported_native_receptors",false)),
			"blocked V3 case actually exercises both explicit experimental switches")
		for i:int in panel._layer.item_count:
			panel._layer.select(i);panel._render();await process_frame
		check(panel.prepared.recipe.parameters.clutter==0.15 and panel.prepared.recipe.parameters.destruction==0,
			"V3 negative retains independent native decoration and destruction")
		await screenshot("native-unresolved")
		await click(panel._apply)
		check((await capture()).cells==baseline.cells and bench.applied.edits.is_empty(),"disabled Apply preserves World and authored history")
		await click(find_button(panel,"Close"))
		check(panel._pid<0 and panel._thread==null and not panel.visible,"closing blocked preview leaves no computation")
		completed=true;return
	if mode=="create":
		if not check(panel.document.can_apply,"failed-exit challenge starts from an actual native-positive result"):return
		await failed_exit_refusal(baseline)
		await click(panel._generate)
		if not await until(func()->bool:return panel.phase in ["ready","idle"],"fresh generation follows failed-exit refusal"):return
		if not check(panel.phase=="ready" and panel.document.get("can_apply",false),"fresh successful native execution restores Apply authority"):return
	if not check(panel.document.can_apply,"native composition independently authorizes Apply: "+panel.status):return
	native_identity_refusals()
	if example=="swarm005_irregular":
		check(panel.prepared.recipe.origin==Vector2i.ZERO and panel.prepared.recipe.activation==[Vector2i(64,48)]
			and panel.prepared.recipe.layout=="left_right" and panel.prepared.recipe.border==4
			and panel.prepared.recipe.get("size",Vector2i.ZERO)==Vector2i(192,112),
			"native V3 authoring uses the owner's 192x112 left-right source geometry")
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
		expected.encode_u16((cells[at+1]*512+cells[at])*2,cells[at+2])
	await click(panel._apply)
	if not await until(func()->bool:return panel.completed_applies==1,"actual Apply receives native acknowledgement"):return
	var applied:=await capture()
	native_planes["applied"]=Protocol.digest(applied.cells)
	check(applied.cells==expected,"Apply equals the exact complete native proposal and all retained source cells")
	await screenshot("native-applied")
	await click(panel._undo_button)
	if not await until(func()->bool:return panel.completed_undos==1,"actual Undo receives native acknowledgement"):return
	var undone:=await capture()
	native_planes["undone"]=Protocol.digest(undone.cells)
	check(undone.cells==baseline.cells and bench.applied.edits.is_empty(),"Undo restores all native cells and original authored history")
	await screenshot("native-undone")
	await click(panel._generate)
	if not await until(func()->bool:return panel.phase=="ready","same-seed regeneration completes"):return
	await click(panel._apply)
	if not await until(func()->bool:return panel.completed_applies==2,"second actual Apply receives acknowledgement"):return
	var regenerated:=await capture()
	native_planes["regenerated"]=Protocol.digest(regenerated.cells)
	check(regenerated.cells==expected,"same-seed regenerated native construction is exact")
	bench._name.text=map_name()
	var save:=find_button(bench,"Save start [Ctrl+S]")
	if not check(save!=null,"ordinary Save start button exists"):return
	await click(save)
	var saved:=Setup.read_named(bench._name.text)
	check(not saved.has("error") and saved.setup.edits==bench.applied.edits,"ordinary Save persists acknowledged composition history")
	check(FileAccess.file_exists(Setup._path(bench._name.text)+".swarm004.json"),"saved map has optional source/revision evidence receipt")
	var saved_plane:=await capture()
	native_planes["saved"]=Protocol.digest(saved_plane.cells)
	check(saved_plane.cells==expected,"ordinary Save preserves the complete acknowledged native plane")
	var file:=FileAccess.open(evidence+"/expected-native.le16",FileAccess.WRITE)
	if not check(file!=null,"fresh-process expected plane can be recorded"):return
	file.store_buffer(expected);file.close()
	native_planes["expected"]=Protocol.digest(expected)
	await screenshot("native-saved")
	completed=true

func reopen_map()->void:
	bench._name.text=map_name()
	await click(find_button(bench,"Load start"))
	if not await until(settled,"saved map installs in a fresh OS process"):return
	var actual:=await capture()
	var expected:=FileAccess.get_file_as_bytes(evidence+"/expected-native.le16")
	native_planes["reopened"]=Protocol.digest(actual.cells)
	native_planes["expected"]=Protocol.digest(expected)
	check(actual.get("cells")==expected and expected.size()==512*512*2,"fresh-process native World exactly matches saved composition plane")
	check(not bench.applied.edits.is_empty(),"fresh-process authored history includes construction stamps")
	await click(find_button(bench,"Reciprocal assembly…"));panel=bench.reciprocal_panel
	await click(find_button(panel,"Inspect saved evidence"))
	if not await until(func()->bool:return panel.phase=="historical","saved native evidence opens in the fresh process"):return
	check(panel._apply.disabled and panel._pid<0
		and panel.prepared.recipe.layout==("left_right" if example=="swarm005_irregular" else "centered_frame_rectangle")
		and panel.prepared.recipe.border==4,"saved ownership and revision evidence is inspection-only without child generation")
	if example=="reciprocal":
		var witness:=reciprocal_witness()
		check(witness.both_footprints_changed and witness.joint_count>0 and witness.obligation_count>0 and witness.all_foreign_closed \
			and not panel.prepared.recipe.shared_ownership,"fresh process retains exact reciprocal witness and fixed ownership")
	await screenshot("native-reopened")
	completed=true

func run()->void:
	if example.is_empty():example="transaction"
	if not check(example in ["transaction","reciprocal","swarm005_irregular","swarm005_viaduct"],"explicit registered authoring example"):
		quit(1);return
	root.size=Vector2i(1920,1080)
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	if OS.get_environment("SWARM004_REQUIRE_GRAPHICS")=="1" and not check(DisplayServer.get_name()!="headless","graphical qualification has a real display"):
		quit(1);return
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate();root.add_child(host)
	bench=host.shared_workbench
	if await until(settled,"real Shared Workbench startup completed",60):
		if mode=="reopen":await reopen_map()
		else:await create_map()
	check(completed,"complete interactive test sequence reached its final assertion")
	var report:Dictionary={"schema":2,"mode":mode,"example":example,"checks":checks,"failures":failures,"completed":completed,
		"engine":Engine.get_version_info().string,"platform":OS.get_name(),"process_id":OS.get_process_id(),
		"display":DisplayServer.get_name(),"native_planes_sha256":native_planes,"transport_refusals":transport_refusals,
		"owner_visual_acceptance":"pending","reciprocal_programme_acceptance":false,
		"test_sha256":FileAccess.get_sha256("res://tests/test_workbench_reciprocal_ui.gd")}
	if panel!=null:
		report["native_receipt"]=panel.last_receipt;report["native_source"]=panel._runtime
		if panel.phase=="historical":report["native_receipt"]=panel.proposal.get("receipt",{}).get("native_receipt",{})
		report["native_status"]=panel.document.get("status","");report["native_reason"]=panel.document.get("reason","")
		report["native_can_apply"]=panel.document.get("can_apply",false)
		report["native_recipe"]=native_recipe();report["proposal_sha256"]=panel.proposal.get("proposal_sha256","")
		report["joint_count"]=panel.document.get("joints",[]).size();report["obligation_count"]=panel.document.get("obligations",[]).size()
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
