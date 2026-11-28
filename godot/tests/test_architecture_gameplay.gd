extends SceneTree
## Actual ordinary Workbench actor movement/contact witness. A route result is
## scoped to its recorded actor, authored start and bounded feedback procedure.
const Setup=preload("res://scripts/workbench_setup.gd")
const Catalog=preload("res://scripts/workbench_actor_catalog.gd")
const ActorSession=preload("res://scripts/physical_actor_session.gd")
const Module=preload("res://scripts/batch_lab/native_module.gd")
const Witness=preload("res://tests/support/architecture_actor_witness.gd")
const Watchdogs=preload("res://tests/support/ci_execution_policy.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool:
		return DisplayServer.get_name()=="headless" or super._actor_window_has_focus()

var host: Control
var wb: Control
var checks:=0
var failures: Array[String]=[]
var attempts: Array=[]
var evidence:=""
var manifest_path:=""
var output: Dictionary={}
var development_core_capacity:=0

func _initialize() -> void:
	var requested:=OS.get_environment("ARCHITECTURE_DEVELOPMENT_CORE_CAPACITY")
	if not requested.is_empty() and requested.is_valid_int() and int(requested)>=1 and int(requested)<=128:
		development_core_capacity=int(requested)
		ProjectSettings.set_setting("cybersand/native_active_core_capacity",development_core_capacity)
	run.call_deferred()

func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); push_error("ARCHITECTURE_GAMEPLAY: "+label)
	return value

func until(predicate: Callable,label: String) -> bool:
	var deadline:=Time.get_ticks_msec()+Watchdogs.milliseconds("operation_seconds")
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		if host!=null and host.simulation_worker!=null and host.simulation_worker.has_failed(): break
		await process_frame
	return check(false,label+" / "+str(wb.message if wb!=null else "No Workbench"))

func installed() -> bool:
	return wb!=null and not wb.applied.is_empty() and not wb.busy() and host.pending_microscenario_apply.is_empty()

func native_tick() -> int:
	# Match main._physics_process: immutable worker completion can precede the
	# render callback that refreshes host.latest_snapshot. Peeking consumes no
	# publication or render acknowledgment and changes no simulation behavior.
	var snapshot: RefCounted=host.simulation_worker.take_latest_snapshot(0) if host!=null and host.simulation_worker!=null else null
	return int(snapshot.tick_index) if snapshot!=null else -1

func render_cached_native_tick() -> int:
	return int(host.latest_snapshot.tick_index) if host!=null and host.latest_snapshot!=null else -1

func start_host() -> bool:
	root.size=Vector2i(1280,900)
	set_meta("cybersand_feature","shared_workbench")
	print("ARCHITECTURE_GAMEPLAY_PHASE ordinary-native-startup / development_core_capacity=",development_core_capacity)
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	if not await until(func() -> bool: return host.shared_workbench!=null,"ordinary Workbench opens"): return false
	wb=host.shared_workbench
	if not await until(installed,"native Workbench owner installed"): return false
	print("ARCHITECTURE_GAMEPLAY_PHASE native-workbench-installed")
	return true

func run() -> void:
	evidence=OS.get_environment("ARCHITECTURE_GAMEPLAY_EVIDENCE_DIR")
	manifest_path=OS.get_environment("ARCHITECTURE_GAMEPLAY_MANIFEST")
	if evidence.is_empty(): evidence=ProjectSettings.globalize_path("user://architecture/gameplay")
	DirAccess.make_dir_recursive_absolute(evidence)
	if not await start_host(): await finish(); return
	var descriptors: Array=[]
	if OS.get_environment("ARCHITECTURE_GAMEPLAY_CONTROL")=="1":
		var start:=Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
		start.edits=[[16,300,480,8,58],[16,180,8,120,58],[488,180,8,120,58]]
		descriptors=[{"id":"development-midge-corridor","setup":start,"spawn":[80,244],"waypoints":[[180,244],[320,244],[400,244]],
			"corridor":[30,196,444,100],"landing":[400,298],"max_ticks":1800,"goal_radius":10,"model":"midge","scope":"Development control; not a flagship architectural witness."}]
	else:
		var file:=FileAccess.open(manifest_path,FileAccess.READ)
		if not check(file!=null and file.get_length()<=2*1024*1024,"bounded explicit gameplay manifest available"): await finish(); return
		var parsed: Variant=JSON.parse_string(file.get_as_text()); file.close()
		if parsed is Dictionary: descriptors=parsed.get("witnesses",parsed.get("examples",[]))
		if not check(descriptors.size()>=1 and descriptors.size()<=6,"finite gameplay witness descriptors"): await finish(); return
	for raw: Dictionary in descriptors:
		var descriptor:=Witness.descriptor(raw)
		var requested:=OS.get_environment("ARCHITECTURE_GAMEPLAY_FAMILY")
		if not requested.is_empty() and descriptor.id!=requested: continue
		if OS.get_environment("ARCHITECTURE_GAMEPLAY_CROP")=="1":
			descriptor=_crop_descriptor(descriptor)
			if not check(not descriptor.is_empty(),"source-bound native route crop can be replayed in a labelled 512 World"): continue
		await run_route(descriptor)
	output={"format":Witness.FORMAT,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"native_tick_source":Witness.NATIVE_TICK_SOURCE,
		"native_active_core_capacity":int(ProjectSettings.get_setting("cybersand/native_active_core_capacity",1024)),
		"development_memory_configuration":development_core_capacity>0,
		"cropped_route_worlds":OS.get_environment("ARCHITECTURE_GAMEPLAY_CROP")=="1",
		"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),"controller":Witness.CONTROLLER,
		"controller_sha256":FileAccess.get_sha256("res://tests/support/architecture_actor_witness.gd"),"manifest_path":manifest_path,
		"manifest_sha256":FileAccess.get_sha256(manifest_path) if not manifest_path.is_empty() else "",
		"attempts":attempts,"scope":"Selected actual coupled actor movement and contact under bounded issued commands. No general playability, subjective feel or owner acceptance claim."}
	await finish()

func _read_start(descriptor: Dictionary) -> Dictionary:
	if descriptor.get("setup") is Dictionary: return descriptor.setup.duplicate(true)
	var path: String=descriptor.get("start_path","")
	if not path.is_absolute_path(): path=manifest_path.get_base_dir().path_join(path)
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>Setup.BYTE_LIMIT: return {}
	var value: Variant=JSON.parse_string(file.get_as_text()); file.close()
	if value is Dictionary and value.get("setup") is Dictionary: value=value.setup
	if not value is Dictionary or not Setup.validate(value).is_empty(): return {}
	return value

func _crop_descriptor(value: Dictionary) -> Dictionary:
	# A labelled local geometry/control witness. This deliberately does not
	# qualify full-World gameplay or substitute for the default-capacity campaign.
	var source_start:=_read_start(value)
	if source_start.is_empty() or not value.get("original_extent") is Array: return {}
	var size:=Vector2i(int(value.original_extent[0]),int(value.original_extent[1]))
	var path:=manifest_path.get_base_dir().path_join(str(value.get("original_plane","")))
	var cells:=FileAccess.get_file_as_bytes(path)
	if cells.size()!=size.x*size.y*2 or Module.digest(cells)!=value.get("original_sha256"): return {}
	var region:=Witness.inspection_region(value,size)
	var destination:=Vector2i(64,64)
	if region.get_area()<=0 or region.size.x+128>512 or region.size.y+128>512: return {}
	var setup:=Setup.fresh(PackedInt32Array(source_start.liquid_policy),Vector2i(512,512))
	var crop:=PackedByteArray(); crop.resize(region.get_area()*2)
	for y: int in region.size.y:
		var x:=0
		while x<region.size.x:
			var material_id:=cells.decode_u16(((region.position.y+y)*size.x+region.position.x+x)*2)
			var end:=x+1
			while end<region.size.x and cells.decode_u16(((region.position.y+y)*size.x+region.position.x+end)*2)==material_id: end+=1
			for column: int in range(x,end): crop.encode_u16((y*region.size.x+column)*2,material_id)
			if material_id!=0: setup.edits.append([destination.x+x,destination.y+y,end-x,1,material_id])
			x=end
	if not Setup.validate(setup).is_empty(): return {}
	var delta:=destination-region.position
	var result:=value.duplicate(true)
	result["id"]=str(value.id)+"-route-crop"; result["setup"]=setup
	for key: String in ["spawn","landing"]:
		result[key]=[float(value[key][0])+delta.x,float(value[key][1])+delta.y]
	for index: int in result.waypoints.size(): result.waypoints[index]=[float(value.waypoints[index][0])+delta.x,float(value.waypoints[index][1])+delta.y]
	result.corridor=[int(value.corridor[0])+delta.x,int(value.corridor[1])+delta.y,int(value.corridor[2]),int(value.corridor[3])]
	result["source_derivation"]={"kind":"exact-native-route-crop-replayed-in-512-world","original_family":value.id,
		"original_plane_sha256":value.original_sha256,"original_region":[region.position.x,region.position.y,region.size.x,region.size.y],
		"destination":[destination.x,destination.y],"crop_sha256":Module.digest(crop),"world_extent":[512,512],
		"scope":"Selected native geometry and accepted actor-control witness only. Full original World Play and default1024 scheduler-capacity qualification remain separate."}
	return result

func run_route(descriptor: Dictionary) -> void:
	var start:=_read_start(descriptor)
	var identity: String=descriptor.get("id","witness")
	print("ARCHITECTURE_GAMEPLAY_PHASE route-prepare / ",identity)
	if not check(not start.is_empty(),identity+": portable authored starting setup validates"): return
	if not check(descriptor.get("model","midge")=="midge" and Catalog.has_model("midge"),identity+": accepted Midge actor is available"): return
	if not check(descriptor.get("waypoints") is Array and descriptor.waypoints.size()>=1 and descriptor.waypoints.size()<=12 and int(descriptor.get("max_ticks",0))>=60 and int(descriptor.get("max_ticks",0))<=3600,identity+": finite route and physical tick budget"): return
	start.actors=[]; start.selected=0; start.next_id=1
	if not check(wb.apply(start),identity+": native authored start admitted") or not await until(installed,identity+": native authored start installed"): return
	var size:=Setup.extent_of(wb.applied)
	var inspection_region:=Witness.inspection_region(descriptor,size)
	if descriptor.has("source_derivation"):
		# Preserve the exact original crop, including original World-edge clipping.
		# Recomputing its grown bounds in a larger Empty margin can add cells that
		# were outside the original World and correctly break the custody hash.
		var derived: Dictionary=descriptor.source_derivation
		inspection_region=Rect2i(int(derived.destination[0]),int(derived.destination[1]),int(derived.original_region[2]),int(derived.original_region[3]))
	if not check(inspection_region.get_area()>0,identity+": bounded inspection covers the actual route and landing"): return
	var before: Dictionary=await wb.capture_batch_source(inspection_region)
	if not check(before.get("ok",false),identity+": actual native source crop captured"): return
	if descriptor.has("source_derivation"):
		if not check(before.config.source_provenance.crop_sha256==descriptor.source_derivation.crop_sha256,identity+": native replay exactly matches every material cell from the original flagship crop"): return
	var spawn:=Setup.point(descriptor.get("spawn",[]))
	if not check(wb.place("midge",spawn),identity+": actual Midge placed through ordinary actor admission") or not await until(installed,identity+": actor and native owner agree"): return
	var actor_id:=int(wb.applied.selected)
	var control:=Catalog.default_control("midge")
	control.source="policy"; control.policy="external"; control.decision_ticks=1
	if not check(wb.set_actor_control(actor_id,control),identity+": issued-command policy control admitted"): return
	var name_text: String=("arch-witness-"+identity).left(48)
	wb._name.text=name_text
	check(wb.save_setup(),identity+": ordinary Save start retains actor spawn and external controller")
	var authored: Dictionary=Setup.read_named(name_text)
	check(authored.has("setup") and authored.setup.actors.size()==1,identity+": saved start contains authored actor, not a live trajectory")
	if authored.has("setup"):
		var file:=FileAccess.open(evidence.path_join(identity+"-workbench-start.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(authored.setup)); file.close()
	var actor_before: Dictionary=wb.actor_observation(actor_id)
	var session_identity: int=host.physical_actor_session.get_instance_id()
	var native_begin:=native_tick()
	var render_cached_begin:=render_cached_native_tick()
	var actor_begin:=int(actor_before.get("tick",0))
	if not check(wb.toggle_pause(),identity+": Play begins actual coupled simulation"): return
	print("ARCHITECTURE_GAMEPLAY_PHASE route-playing / ",identity)
	var waypoints: Array=descriptor.waypoints.duplicate(true)
	var target_index:=0
	var landing: Vector2=Setup.point(descriptor.get("landing",waypoints.back()))
	var corridor:=Module.rect(descriptor.get("corridor",[0,0,size.x,size.y]))
	var radius: float=descriptor.get("goal_radius",10.0)
	var samples: Array=[]
	var first_command: Dictionary={}
	var contacts:=0
	var refusals:=0
	var left_corridor:=false
	var waypoint_ticks: Array=[]
	var last_tick:=-1
	var latest: Dictionary=actor_before
	var start_usec:=Time.get_ticks_usec()
	# The physical tick budget is fixed by the route. A separate finite watchdog
	# retains stalled/failed attempts instead of waiting for a nonexistent tick.
	var watchdog:=Time.get_ticks_msec()+mini(180000,Watchdogs.milliseconds("operation_seconds"))
	var last_progress:=Time.get_ticks_msec()
	var last_reported:=actor_begin
	var stop_reason:="route-budget"
	while Time.get_ticks_msec()<watchdog:
		var view: Dictionary=wb.actor_observation(actor_id,true)
		var tick:=int(view.get("tick",-1))
		if host.simulation_worker.has_failed() or not str(view.get("fault","")).is_empty():
			if not view.is_empty(): latest=view
			stop_reason="native-or-actor-fault"; break
		if Time.get_ticks_msec()-last_progress>mini(30000,Watchdogs.milliseconds("diagnostic_capture_seconds")):
			latest=view; stop_reason="no-actor-progress"; break
		if tick<=last_tick: await process_frame; continue
		last_tick=tick; latest=view; last_progress=Time.get_ticks_msec()
		if tick-last_reported>=120:
			last_reported=tick
			print("ARCHITECTURE_GAMEPLAY_PROGRESS ",JSON.stringify({"id":identity,"actor_tick":tick,"native_tick":native_tick(),"render_cached_native_tick":render_cached_native_tick(),"position":Witness._json(view.get("position",Vector2.ZERO)),"target_index":target_index,"contacts":contacts,"suspended":view.get("suspended",false),"fault":view.get("fault","")}))
		if tick-actor_begin>int(descriptor.max_ticks): break
		var position: Vector2=view.get("position",Vector2.ZERO)
		if not position.is_finite() or not str(view.get("fault","")).is_empty(): break
		if target_index<waypoints.size() and position.distance_to(Setup.point(waypoints[target_index]))<=radius:
			waypoint_ticks.append({"index":target_index,"tick":tick,"position":[position.x,position.y]})
			target_index+=1
		var is_landing:=target_index>=waypoints.size()
		if not Rect2(corridor).grow(8.0).has_point(position) and not is_landing: left_corridor=true
		var target:=landing if is_landing else Setup.point(waypoints[target_index])
		var action:=Witness.action(view,target,is_landing)
		var command:=ActorSession.make_command(view,int(view.get("last_sequence",-1))+1,action,12)
		if first_command.is_empty(): first_command=Witness._json(command)
		var accepted: bool=wb.submit_actor_policy(actor_id,command)
		if not accepted: refusals+=1
		if is_landing and bool(view.get("grounded",false)) and absf(position.x-landing.x)<=16.0: contacts+=1
		samples.append(Witness.sample(view,native_tick(),command,accepted,render_cached_native_tick()))
		if contacts>=12: stop_reason="landed-with-persistent-contact"; break
		await process_frame
	var native_end:=native_tick()
	var render_cached_end:=render_cached_native_tick()
	var actor_end:=int(latest.get("tick",0))
	var finished_waypoints:=target_index==waypoints.size()
	var outcome:="completed" if finished_waypoints and contacts>=12 and refusals==0 and not left_corridor else "route-failed"
	var publication: RefCounted=host.simulation_worker.take_latest_snapshot(-1)
	var native_diagnostic:={"simulation_failed":publication.simulation_failed,"failed_tick_index":publication.failed_tick_index,
		"tick_failure_count":publication.tick_failure_count,"last_tick_error":publication.last_tick_error,"published_tick":publication.tick_index} if publication!=null else {}
	var record:={"id":identity,"model":"midge","definition_sha256":Catalog.definition_hash("midge"),"authored_start_sha256":Module.digest(Module.json_bytes(start)),
		"spawn":descriptor.spawn,"waypoints":waypoints,"landing":[landing.x,landing.y],"corridor":descriptor.get("corridor",[]),"max_ticks":descriptor.max_ticks,
		"status":outcome,"waypoints_reached":target_index,"waypoint_ticks":waypoint_ticks,"contact_samples":contacts,"command_refusals":refusals,
		"stop_reason":stop_reason,"worker_failed":host.simulation_worker.has_failed(),"actor_fault":latest.get("fault",""),
		"native_diagnostic":native_diagnostic,
		"source_derivation":descriptor.get("source_derivation",{}),
		"last_observation":Witness._json(latest),"workbench_frame_error":str(host.get("_workbench_frame_error")),
		"left_corridor":left_corridor,"native_tick_source":Witness.NATIVE_TICK_SOURCE,
		"native_tick_bounds":{"begin":native_begin,"end":native_end},
		"render_cached_native_tick_bounds":{"begin":render_cached_begin,"end":render_cached_end},
		"render_cached_native_ticks":render_cached_end-render_cached_begin,"native_ticks":native_end-native_begin,"actor_ticks":actor_end-actor_begin,"elapsed_usec":Time.get_ticks_usec()-start_usec,
		"samples":samples,"saved_start_name":name_text,"start_path":identity+"-workbench-start.json",
		"saved_start_sha256":FileAccess.get_sha256(evidence.path_join(identity+"-workbench-start.json")),
		"retained_session_id":str(session_identity),"first_command":first_command,
		"inspection_region":[inspection_region.position.x,inspection_region.position.y,inspection_region.size.x,inspection_region.size.y],
		"source_crop_sha256":before.get("config",{}).get("source_provenance",{}).get("crop_sha256","")}
	attempts.append(record)
	print("ARCHITECTURE_GAMEPLAY_ROUTE_RESULT ",JSON.stringify({"id":identity,"status":outcome,"stop_reason":stop_reason,"actor_ticks":actor_end-actor_begin,"native_ticks":native_end-native_begin,"native_tick_source":Witness.NATIVE_TICK_SOURCE,"render_cached_native_ticks":render_cached_end-render_cached_begin,"fault":latest.get("fault",""),"frame_error":record.workbench_frame_error,"native_diagnostic":native_diagnostic}))
	check(finished_waypoints,identity+": actual actor enters every requested waypoint")
	check(contacts>=12,identity+": actual support contacts persist at the landing pad")
	check(refusals==0 and not left_corridor,identity+": issued commands are admitted and recorded flight stays in the selected corridor")
	check(native_end-native_begin>=actor_end-actor_begin-2 and actor_end>actor_begin,identity+": native and Rapier owners both advance the sampled route")
	check(host.physical_actor_session.get_instance_id()==session_identity,identity+": route does not replace the live actor owner")
	if not await pause_owners(actor_id,identity): return
	record["acknowledged_pause_ticks"]={"native_published":native_tick(),"native_render_cached":render_cached_native_tick(),"actor":int(wb.actor_observation(actor_id).get("tick",-1))}
	var settled: Dictionary=await wb.capture_batch_source(inspection_region)
	check(settled.get("ok",false) and settled.config.source_cells==before.config.source_cells,identity+": exact route material geometry survives the measured actor trial")
	if settled.get("ok",false): record["ordinary_history"]=await verify_paint_history(inspection_region,settled.config.source_cells,actor_id,identity)
	check(wb.save_setup(),identity+": Save start remains available after Play, Pause and ordinary history")
	var saved: Dictionary=Setup.read_named(name_text)
	check(saved.has("setup") and saved.setup.actors==authored.setup.actors,identity+": saved authoring retains the original spawn and controls, not the live landed pose")
	if saved.has("setup"):
		var file:=FileAccess.open(evidence.path_join(identity+"-workbench-start.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(saved.setup)); file.close()
		record["saved_start_sha256"]=FileAccess.get_sha256(evidence.path_join(identity+"-workbench-start.json"))
	print("ARCHITECTURE_GAMEPLAY_ROUTE ",JSON.stringify({"id":identity,"status":outcome,"waypoints":target_index,"contacts":contacts,"native_ticks":native_end-native_begin,"actor_ticks":actor_end-actor_begin,"last_position":Witness._json(latest.get("position",Vector2.ZERO))}))
	if DisplayServer.get_name()!="headless":
		wb.set_camera(2)
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		check(image!=null and image.save_png(evidence.path_join(identity+"-actual-workbench.png"))==OK,identity+": actual graphical Workbench witness captured")

func pause_owners(actor_id: int,identity: String) -> bool:
	if not host.paused and not check(wb.toggle_pause(),identity+": Pause requested after measured route"): return false
	var serial: int=host.simulation_worker.workbench_pause_request_serial()
	if not await until(func() -> bool: return host.paused and host.latest_snapshot.paused and not wb.busy() \
		and int(host.latest_snapshot.lab_context.get("workbench_pause_ack_serial",-1))>=serial \
		and bool(wb.actor_observation(actor_id).get("suspended",false)),identity+": native and Rapier owners acknowledge this exact Pause command"): return false
	var stopped_native:=native_tick()
	var stopped_actor: int=wb.actor_observation(actor_id).tick
	for frame: int in 6: await process_frame
	return check(native_tick()==stopped_native and int(wb.actor_observation(actor_id).tick)==stopped_actor,identity+": acknowledged Pause freezes native and actor progression")

func verify_paint_history(region: Rect2i,baseline: PackedByteArray,actor_id: int,identity: String) -> Dictionary:
	var points:=PackedInt32Array()
	# Two genuinely empty observed cells, away from the landed actor. This is
	# ordinary paint-authoring authority, followed by exact every-cell Undo.
	var actor_position: Vector2=wb.actor_observation(actor_id).position
	for offset: int in region.get_area():
		var point:=Vector2i(region.position.x+offset%region.size.x,region.position.y+offset/region.size.x)
		if baseline.decode_u16(offset*2)==0 and Vector2(point).distance_to(actor_position)>24:
			points.append_array(PackedInt32Array([point.x,point.y,58]))
			if points.size()==6: break
	if not check(points.size()==6,identity+": exact empty cells available for ordinary paint witness"): return {"ok":false}
	var session_id: int=host.physical_actor_session.get_instance_id()
	var editor: Control=wb.paint_editor
	if not check(editor.commit_cells(points,"Architecture actor witness paint"),identity+": ordinary paint admitted after architectural Play"): return {"ok":false}
	var idle:=func() -> bool: return not editor.busy() and not host.simulation_worker.paint_state().busy
	if not await until(idle,identity+": ordinary paint receipt retires"): return {"ok":false}
	var expected:=baseline.duplicate()
	for offset: int in range(0,points.size(),3): expected.encode_u16(((points[offset+1]-region.position.y)*region.size.x+points[offset]-region.position.x)*2,58)
	var painted: Dictionary=await wb.capture_batch_source(region)
	check(painted.get("ok",false) and painted.config.source_cells==expected,identity+": ordinary paint changes exactly the two approved cells")
	if not check(editor.undo(),identity+": ordinary Undo remains available"): return {"ok":false}
	if not await until(idle,identity+": Undo native receipt retires"): return {"ok":false}
	var undone: Dictionary=await wb.capture_batch_source(region)
	check(undone.get("ok",false) and undone.config.source_cells==baseline,identity+": Undo restores every inspected native cell")
	if not check(editor.redo(),identity+": ordinary Redo remains available"): return {"ok":false}
	if not await until(idle,identity+": Redo native receipt retires"): return {"ok":false}
	var redone: Dictionary=await wb.capture_batch_source(region)
	check(redone.get("ok",false) and redone.config.source_cells==expected,identity+": Redo restores exactly the observed paint result")
	if not check(editor.undo(),identity+": final Undo retains the original architectural route"): return {"ok":false}
	if not await until(idle,identity+": final Undo native receipt retires"): return {"ok":false}
	var final: Dictionary=await wb.capture_batch_source(region)
	var exact: bool=final.get("ok",false) and final.config.source_cells==baseline
	check(exact and session_id==host.physical_actor_session.get_instance_id(),identity+": original native geometry and live actor owner survive paint history")
	return {"ok":exact,"cells":Array(points),"before_sha256":Module.digest(baseline),"painted_sha256":Module.digest(expected),"restored_sha256":Module.digest(final.config.source_cells) if final.get("ok",false) else ""}

func finish() -> void:
	output["checks"]=checks; output["failures"]=failures; output["passed"]=failures.is_empty()
	if not evidence.is_empty():
		var file:=FileAccess.open(evidence.path_join("architecture-gameplay.json"),FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(output,"",true,true)); file.close()
	print("ARCHITECTURE_GAMEPLAY: %d checks, %d failures" % [checks,failures.size()])
	if is_instance_valid(host): host.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
