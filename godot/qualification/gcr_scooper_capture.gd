extends SceneTree

# Registered apparatus: ordinary owner/actuator/tick path, no pose correction,
# material inventory, invented arrival history or alternate response solver.
const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Source=preload("res://scripts/gcr_painting_powder_source.gd")
const Base=preload("res://qualification/gcr_creep_capture.gd")
const REGISTRATION="GCR-AUTHORED-001"
const WORLD_RECT=Rect2i(0,0,1024,512)
var errors: Array[String]=[]

func _init() -> void: call_deferred("_run")
func require(ok: bool, why: String) -> bool:
	if not ok: errors.append(why)
	return ok

func census(world: Object) -> Dictionary:
	var result: Dictionary=world.diagnostic_snapshot(WORLD_RECT.position,WORLD_RECT.size,false,false)
	result.erase("cells")
	return result

func cavity_rect() -> Rect2:
	var raw: Array[Rect2]=[Rect2(-13,2,26,2),Rect2(-15,-5,2,9),Rect2(13,1,2,3),Rect2(15,0,1,3),Rect2(16,-1,1,3),Rect2(17,-2,1,3)]
	var centre:=Vector2.ZERO
	var area: float=0.0
	for rect: Rect2 in raw:
		var weight: float=rect.size.x*rect.size.y
		centre+=rect.get_center()*weight;area+=weight
	return Rect2(Vector2(-12,-4)-centre/area,Vector2(24,6))

func cavity_count(world: Object, pose: Transform2D, material: int) -> int:
	var cavity:=cavity_rect()
	var low:=Vector2.INF
	var high:=-Vector2.INF
	for vertex: Vector2 in [cavity.position,cavity.position+Vector2(cavity.size.x,0),cavity.end,cavity.position+Vector2(0,cavity.size.y)]:
		var point: Vector2=pose*vertex
		low=low.min(point);high=high.max(point)
	var first:=Vector2i(maxi(0,floori(low.x)-1),maxi(0,floori(low.y)-1))
	var last:=Vector2i(mini(1024,ceili(high.x)+1),mini(512,ceili(high.y)+1))
	if last.x<=first.x or last.y<=first.y: return 0
	var snapshot: Dictionary=world.diagnostic_snapshot(first,last-first,false,false)
	if snapshot.is_empty(): errors.append("cavity observation refused");return -1
	var cells: PackedByteArray=snapshot.cells
	var count: int=0
	var inverse: Transform2D=pose.affine_inverse()
	for y: int in range(first.y,last.y):
		for x: int in range(first.x,last.x):
			if int(cells[(y-first.y)*(last.x-first.x)+x-first.x])==material and cavity.has_point(inverse*Vector2(x+0.5,y+0.5)): count+=1
	return count

func action(spec: Dictionary, tick: int) -> Dictionary:
	var result: Dictionary={"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":1.0,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
	if spec.id=="carry-spill":
		if tick>=120 and tick<210: result.move=Vector2(0,-0.5)
		elif tick>=210 and tick<300: result.secondary=true
		elif tick>=300 and tick<600: result.trim=1.0
	return result

func _run() -> void:
	var args: Dictionary={}
	for item: String in OS.get_cmdline_user_args():
		var pair:=item.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var protocol: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not protocol is Dictionary or protocol.get("registration")!=REGISTRATION:
		push_error("Scooper protocol refused");quit(1);return
	var spec: Dictionary={}
	for entry: Dictionary in protocol.cases:
		if entry.id==args.get("case",""): spec=entry
	var response: String=str(args.get("response",""))
	if spec.is_empty() or response not in ["LA","LA-EVENT-OFF","LA-SELECTIVE"]:
		push_error("Scooper case/response refused");quit(1);return
	var index: int=Fleet.NAMES.find("Scooper")
	var runtime=Runtime.new()
	root.add_child(runtime)
	var options: Dictionary={"response":response,"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
	if not runtime.configure_review_fleet(index,options,Vector2(spec.spawn[0],spec.spawn[1])):
		push_error("Scooper owner refused: "+runtime.last_error);runtime.close();runtime.free();quit(1);return
	var arena=runtime._arena
	var world: Object=arena._world
	var body: RigidBody2D=arena.session.bodies()[0]
	var source=Source.new()
	require(world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear fixture cells")
	for rect: Array in [[16,396,992,6],[16,16,6,386],[1002,16,6,386],[16,16,992,6]]:
		require(world.diagnostic_fill_rect(Vector2i(rect[0],rect[1]),Vector2i(rect[2],rect[3]),58),"closed hard boundary")
	for rect: Array in spec.get("material_rects",[]):
		require(world.diagnostic_fill_rect(Vector2i(rect[0],rect[1]),Vector2i(rect[2],rect[3]),int(spec.material)),"registered material fixture")
	if spec.has("velocity"):
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(spec.velocity[0],spec.velocity[1]))
	if spec.has("source"):
		require(source.configure(Vector2i(spec.source[0],spec.source[1]),int(spec.material)),"registered source")
		if spec.id=="burst": require(source.queue_burst(),"queue burst")
		else: require(source.set_stream(true),"start stream")
	var before:=census(world)
	var report: Dictionary={"registration":REGISTRATION,"case":spec,"response":response,"platform":OS.get_name(),"options":options,
		"identity":{"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"inputs":OS.get_environment("GCR_SCOOPER_INPUTS"),
		"protocol_sha256":FileAccess.get_sha256(str(args.protocol)),"definition_hash":Fleet.definition_hash(index),
		"engine_version":Engine.get_version_info().string,"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")},
		"mass":body.mass,"inertia":body.inertia,"before":before,"initial":Base.state(body),"rows":[],"censuses":[],"errors":[]}
	var expected_selector: String={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}[response]
	for tick: int in range(int(spec.ticks)):
		if source.armed: require(source.before_step(arena),"source owner step")
		var start: int=Time.get_ticks_usec()
		require(runtime.submit_review_action(action(spec,tick),{"q":tick>=300 and tick<600 and spec.id=="carry-spill","e":false,"s":false,"boost":false}),"admit pilot action")
		var snapshot: Dictionary=runtime.step()
		var elapsed: int=Time.get_ticks_usec()-start
		if not require(not snapshot.failed,"normal owner step: "+runtime.last_error): break
		var state: Dictionary=Base.state(body)
		var diag: Dictionary=world.gcr_compound_diagnostics()
		if not require(diag.get("admission_kind")=="authored" and diag.get("granular_events")==expected_selector,"authored mode/selector readback"): break
		var pose:=Transform2D(float(state.rotation),state.position)
		var row: Dictionary={"tick":tick,"state":state,"step_us":elapsed,"actuation":arena.session._rigs[0]._player_controller.observation(),
			"application":arena.session.bridge.gcr_application_diagnostics(),"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}
		var metrics: Dictionary={}
		for key: String in ["proxy_count","physical_body_id","sample_serial","session_id","nodes","updates","contacts","displaced","unresolved","global_capacity","source_capacity","normal_accepted","tangent_accepted","event_budget_cost","event_accepted","event_torque","arrival_count","arrival_missing","arrival_misaligned","passive_impulse","passive_torque","energy_before","energy_after","impulse","torque","correction","cellular_overlap_pre","cellular_overlap_post","overlap_measured"]:
			if diag.has(key): metrics[key]=diag[key]
		row.gcr=metrics
		if tick%15==0 or tick==int(spec.ticks)-1: row.cavity_count=cavity_count(world,pose,int(spec.material))
		if tick%60==0 or tick==int(spec.ticks)-1:
			var current:=census(world)
			var expected_counts: PackedInt64Array=before.counts.duplicate()
			expected_counts[int(spec.material)]+=source.inserted
			var expected: Dictionary={"counts":expected_counts,"water_mass":before.water_mass}
			var conserved: bool=Base.same_quantity(expected,current)
			report.censuses.append({"tick":tick,"observed":current,"source_inserted":source.inserted,"conserved":conserved})
			require(conserved,"closed native quantity plus actual source additions")
		report.rows.append(Base.portable(row))
		if not errors.is_empty(): break
	report.after=census(world)
	report.source=source.receipt()
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==int(spec.ticks)
	runtime.close();runtime.free()
	var file:=FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if file==null: push_error("Scooper output refused");quit(1);return
	file.store_string(JSON.stringify(Base.portable(report)));file.close()
	print("GCR_SCOOPER_CAPTURE ",JSON.stringify({"case":spec.id,"response":response,"ticks":report.rows.size(),"ok":report.ok,"errors":errors}))
	quit(0 if report.ok else 1)
