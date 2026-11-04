extends SceneTree

# Geometry comparison only. The old profile is installed as a validated copied
# registry before constructing an owner; no live body is reshaped in place.
const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Authoring=preload("res://scripts/gcr_flyer_authoring.gd")
const Base=preload("res://qualification/gcr_creep_capture.gd")
const Prior=preload("res://qualification/gcr_scooper_leak_capture.gd")
const REGISTRATION="GCR-UHULL-003"
const ROI_SIZE: int=128
var errors: Array[String]=[]

func _init() -> void: call_deferred("_run")
func require(ok: bool,reason: String) -> bool:
	if not ok: errors.append(reason)
	return ok

static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

static func configuration_error(protocol: Dictionary) -> String:
	for key: String in ["schema","registration","dt","workers","ticks","seed","profiles","cases","walls","move_from","move_to","brake_to","raster","cavity_center_world_x","floor_top_world_y"]:
		if not protocol.has(key): return "missing "+key
	if protocol.schema!=1 or protocol.registration!=REGISTRATION or absf(float(protocol.dt)-1.0/60.0)>1e-12 or protocol.workers!=1 or protocol.ticks!=450 or not Base.metadata_equal(protocol.seed,[504,249,16,1]): return "common frozen controls"
	if protocol.move_from!=120 or protocol.move_to!=240 or protocol.brake_to!=330: return "command schedule"
	if not protocol.profiles is Array or protocol.profiles.size()!=2: return "two explicit profiles"
	for p: Dictionary in protocol.profiles:
		for key: String in ["definition_path","cavity","core","floor_index","left_index","right_index","rim_y","corner_indices"]:
			if not p.has(key): return "profile "+key
		if not p.definition_path is String or not str(p.definition_path).begins_with("res://") or p.cavity.size()!=4 or p.core.size()!=4: return "profile fields"
	if not protocol.cases is Array or protocol.cases.size()!=12: return "case population"
	var ids: Dictionary={}
	for spec: Dictionary in protocol.cases:
		for key: String in ["id","response","material","move","boost","trim"]:
			if not spec.has(key): return "case "+key
		if ids.has(spec.id) or not spec.id is String or spec.response not in ["LA","LA-EVENT-OFF","LA-SELECTIVE"] or spec.material not in [2,14] or not spec.move is Array or spec.move.size()!=2 or not spec.boost is bool or float(spec.trim)<-1 or float(spec.trim)>1: return "case fields"
		for value: Variant in spec.move:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>1: return "move bounds"
		ids[spec.id]=true
	return ""

static func command(protocol: Dictionary,spec: Dictionary,tick: int) -> Dictionary:
	var moving: bool=tick>=int(protocol.move_from) and tick<int(protocol.move_to)
	var trim: float=float(spec.trim) if moving else 0.0
	return {"action":{"move":Vector2(float(spec.move[0]),float(spec.move[1])) if moving else Vector2.ZERO,"aim":Vector2.RIGHT,
		"effort":1.0,"trim":trim,"primary":false,"secondary":tick>=int(protocol.move_to) and tick<int(protocol.brake_to),"auxiliary":false},
		"ports":{"q":trim<0,"e":trim>0,"s":false,"boost":moving and bool(spec.boost)}}

static func classify_local(local: Vector2,rectangles: Array,com: Vector2,definition: Dictionary,profile: Dictionary) -> Dictionary:
	var raw: Vector2=local+com
	var indices: Array[int]=[]
	for index: int in range(rectangles.size()):
		var r: Dictionary=rectangles[index]
		var d: Vector2=local-Vector2(r.center)
		var half: Vector2=Vector2(r.size)*0.5
		if absf(d.x)<=half.x and absf(d.y)<=half.y: indices.append(index)
	var bounds: Rect2=rect(definition.hull.rects[0])
	for entry: Array in definition.hull.rects: bounds=bounds.merge(rect(entry))
	var floor_rect: Rect2=rect(definition.hull.rects[int(profile.floor_index)])
	var cavity: bool=rect(profile.cavity).has_point(raw) and indices.is_empty()
	var core: bool=rect(profile.core).has_point(raw) and indices.is_empty()
	var interior_x: bool=raw.x>=floor_rect.position.x+1 and raw.x<floor_rect.end.x-1
	var below: bool=interior_x and raw.y>floor_rect.end.y
	var left: bool=raw.x<bounds.position.x
	var right: bool=raw.x>bounds.end.x
	var side_height: bool=raw.y>=float(profile.rim_y) and raw.y<=floor_rect.end.y
	var rim: bool=raw.y<float(profile.rim_y)
	var category: String="free_near_hull"
	if not indices.is_empty(): category="floor" if int(profile.floor_index) in indices else "left_wall" if int(profile.left_index) in indices else "right_wall" if int(profile.right_index) in indices else "corner_or_nose"
	elif below: category="below_closed_floor"
	elif left: category="beyond_left"
	elif right: category="beyond_right"
	elif rim: category="above_rim"
	elif cavity: category="cavity"
	return {"local":local,"authored_local":raw,"class":category,"inside_rectangles":indices,"primary_cavity":cavity,"core_cavity":core,
		"floor_interior_x":interior_x,"below_closed_floor":below,"below_floor_margin":raw.y-floor_rect.end.y,
		"beyond_left":left,"beyond_right":right,"within_side_height":side_height,"above_rim":rim,
		"left_is_closed":int(profile.left_index)>=0,"right_is_closed":int(profile.right_index)>=0,
		"inside_corner":indices.any(func(index: int) -> bool: return index in profile.corner_indices)}

static func observe(world: Object,sample: Transform2D,current: Transform2D,rectangles: Array,com: Vector2,
		definition: Dictionary,profile: Dictionary,previous: Array,material: int,force_global: bool=false) -> Dictionary:
	var roi: Rect2i=Prior.observation_roi(current,rectangles,previous)
	var snapshot: Dictionary=world.diagnostic_snapshot(roi.position,roi.size,false,false)
	if snapshot.is_empty(): return {"failed":true,"reason":"ROI refused"}
	var local_points: Array[Vector2i]=Prior.points_from_snapshot(snapshot,roi.position,roi.size,material)
	var full: Dictionary={}
	var points: Array=local_points
	if force_global or local_points.size()!=16:
		full=Prior.whole_fixture(world,material)
		if full.failed: return full
		points=full.points
	var result: Dictionary={"failed":false,"roi":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],"coverage":"whole-fixture" if not full.is_empty() else "bounded-roi",
		"roi_count":local_points.size(),"observed_count":points.size(),"outside_roi_count":points.size()-local_points.size() if not full.is_empty() else null,
		"global_counts":full.get("counts"),"global_water_mass":full.get("water_mass"),"points":points,"grains":[]}
	for point: Vector2i in points:
		var centre:=Vector2(point)+Vector2(0.5,0.5)
		result.grains.append({"cell":point,"native_mask_proxy":int(world.rigid_body_id_at(point.x,point.y)),
			"sampled":classify_local(sample.affine_inverse()*centre,rectangles,com,definition,profile),
			"current":classify_local(current.affine_inverse()*centre,rectangles,com,definition,profile)})
	return result

static func native_options() -> Dictionary:
	return {"workers":1,"telemetry":true,"bearing_candidate":"GCR-REST","bearing_experiment":"GCR-REST-001-2026-11-02",
		"gcr_rest_mode":"control","gcr_base_budget":20.0,"gcr_rest_gravity":38.0,"gcr_granular_events":"selective",
		"gcr_event_experiment":"GCR-SEL-001-2026-11-04","gcr_authored_compound":true}

static func raster_packet(rectangles: Array,pose: Transform2D,mass: float,inertia: float,serial: int) -> PackedFloat64Array:
	var result:=PackedFloat64Array()
	for index: int in range(rectangles.size()):
		var r: Dictionary=rectangles[index]
		var centre: Vector2=pose*Vector2(r.center)
		result.append_array(PackedFloat64Array([index+1,centre.x,centre.y,pose.get_rotation(),r.size.x,r.size.y,0,0,0,mass,serial,inertia,pose.origin.x,pose.origin.y,.8,1./60.,977]))
	return result

static func packet_memberships(packet: PackedFloat64Array,cell: Vector2i) -> Array[int]:
	var result: Array[int]=[]
	for offset: int in range(0,packet.size(),17):
		# The native BodyState is real_t/float32 even though its admission carrier
		# is Float64. Packet centres/sizes were constructed as actual Vector2s.
		var angle: float=packet[offset+3]
		var d_x: float=cell.x+0.5-packet[offset+1]
		var d_y: float=cell.y+0.5-packet[offset+2]
		var local_x: float=cos(angle)*d_x+sin(angle)*d_y
		var local_y: float=-sin(angle)*d_x+cos(angle)*d_y
		if absf(local_x)<=packet[offset+4]*.5 and absf(local_y)<=packet[offset+5]*.5: result.append(int(packet[offset]))
	return result

static func mask_connectivity(mask: Dictionary,pose: Transform2D,com: Vector2,bounds: Rect2,profile: Dictionary,roi: Rect2i,diagonal: bool) -> Dictionary:
	var inverse:=pose.affine_inverse()
	var queue: Array[Vector2i]=[]
	var seen: Dictionary={}
	var parents: Dictionary={}
	for y: int in range(roi.position.y,roi.end.y):
		for x: int in range(roi.position.x,roi.end.x):
			var cell:=Vector2i(x,y)
			var raw: Vector2=inverse*(Vector2(cell)+Vector2(.5,.5))+com
			if not mask.has(cell) and rect(profile.core).has_point(raw): queue.append(cell);seen[cell]=true
	var directions: Array[Vector2i]=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
	if diagonal: directions.append_array([Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)])
	var exits: Dictionary={}
	var cursor: int=0
	while cursor<queue.size():
		var from: Vector2i=queue[cursor];cursor+=1
		for direction: Vector2i in directions:
			var cell: Vector2i=from+direction
			if not roi.has_point(cell) or mask.has(cell) or seen.has(cell): continue
			var raw: Vector2=inverse*(Vector2(cell)+Vector2(.5,.5))+com
			if raw.y<float(profile.rim_y): continue # virtual graph cap only
			var sides: Array[String]=[]
			if raw.x<bounds.position.x: sides.append("left")
			if raw.x>bounds.end.x: sides.append("right")
			if raw.y>bounds.end.y: sides.append("bottom")
			if not sides.is_empty():
				var name: String="+".join(sides)
				if not exits.has(name):
					var path: Array[Vector2i]=[cell,from]
					var node: Vector2i=from
					while parents.has(node): node=parents[node];path.append(node)
					path.reverse()
					var floor_span: Array=profile.get("floor_span",[bounds.position.x,bounds.end.x])
					var floor_covered_x: bool=raw.x>=float(floor_span[0]) and raw.x<=float(floor_span[1])
					exits[name]={"path":path,"open_side":("right" in sides and int(profile.right_index)<0) or ("left" in sides and int(profile.left_index)<0) or ("bottom" in sides and not floor_covered_x),"ambiguous_corner":sides.size()>1,"floor_span_covered_x":floor_covered_x}
				continue # never wrap around an open exit to claim a floor hole
			seen[cell]=true;parents[cell]=from;queue.append(cell)
	return {"neighbours":8 if diagonal else 4,"seed_count":queue.size()-parents.size(),"visited":seen.size(),"exit_paths":exits,
		"scope":"Static native endpoint-mask graph below a virtual rim plane; open exits terminate, no native lid or tick."}

func static_masks(protocol: Dictionary,definition: Dictionary,resolved: Dictionary,profile: Dictionary) -> Dictionary:
	var native: Object=ClassDB.instantiate("CyberNativeCellWorld")
	if not require(native!=null and native.diagnostic_reset(native_options()),"static native owner"): return {}
	var rectangles: Array=resolved.resolved_rects
	var geometry:=PackedFloat64Array()
	for r: Dictionary in rectangles: geometry.append_array(PackedFloat64Array([r.center.x,r.center.y,r.size.x,r.size.y]))
	var bounds: Rect2=rect(definition.hull.rects[0])
	for entry: Array in definition.hull.rects: bounds=bounds.merge(rect(entry))
	var flood_profile: Dictionary=profile.duplicate(true)
	var floor_rect: Rect2=rect(definition.hull.rects[int(profile.floor_index)])
	flood_profile.floor_span=[floor_rect.position.x,floor_rect.end.x]
	var records: Array=[]
	var serial: int=0
	for angle: float in protocol.raster.angles:
		for phase: Array in protocol.raster.offsets:
			serial+=1
			var pose:=Transform2D(angle,Vector2(float(protocol.raster.origin[0])+float(phase[0]),float(protocol.raster.origin[1])+float(phase[1])))
			var packet:=raster_packet(rectangles,pose,float(definition.physics.mass),float(resolved.resolved_inertia),serial)
			var admitted: bool=native.prepare_gcr_authored_compound_coupling(packet,geometry,{"version":1,"session_id":977,"body_generation":1},false)
			require(admitted,"static mask admitted")
			var roi: Rect2i=Prior.observation_roi(pose,rectangles,[]).grow(-32)
			var mask: Dictionary={}
			var mask_ids: Array[int]=[]
			mask_ids.resize(roi.size.x*roi.size.y);mask_ids.fill(0)
			var mismatches: Array=[]
			var ambiguous: int=0
			for y: int in range(roi.position.y,roi.end.y):
				for x: int in range(roi.position.x,roi.end.x):
					var cell:=Vector2i(x,y)
					var actual: int=int(native.rigid_body_id_at(x,y))
					mask_ids[(y-roi.position.y)*roi.size.x+x-roi.position.x]=actual
					var expected: Array[int]=packet_memberships(packet,cell)
					if actual>0: mask[cell]=actual
					if (actual>0)!=(not expected.is_empty()) or (actual>0 and actual not in expected):
						# Preserve exact discrepancies, including boundary-sensitive
						# ones. No expected pixel is silently painted into native.
						mismatches.append({"cell":cell,"actual":actual,"expected":expected})
					if expected.size()>1: ambiguous+=1
			records.append({"angle":angle,"phase":phase,"pose":{"position":pose.origin,"rotation":pose.get_rotation()},"packet":packet,
				"mask_roi":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],"mask_ids":mask_ids,
				"admitted":admitted,"occupied":mask.size(),"multi_proxy_boundary_centres":ambiguous,"mismatches":mismatches,
				"connectivity4":mask_connectivity(mask,pose,resolved.resolved_com,bounds,flood_profile,roi,false),
				"connectivity8":mask_connectivity(mask,pose,resolved.resolved_com,bounds,flood_profile,roi,true),"native_tick":native.get_tick_index()})
			require(native.get_tick_index()==0,"static observation advances no native tick")
	native=null
	return {"rows":records,"ok":errors.is_empty(),"errors":errors}

func physical(protocol: Dictionary,spec: Dictionary,definition: Dictionary,resolved: Dictionary,profile: Dictionary) -> Dictionary:
	var runtime=Runtime.new();root.add_child(runtime)
	var index: int=Fleet.index_for_id("scooper")
	var options: Dictionary={"response":spec.response,"budget":20.,"mass_multiplier":1.,"inertia_multiplier":1.,"thrust_multiplier":1.,"torque_multiplier":1.,"boost_multiplier":2.}
	var cavity: Rect2=rect(profile.cavity)
	var floor_rect: Rect2=rect(definition.hull.rects[int(profile.floor_index)])
	var com: Vector2=resolved.resolved_com
	var spawn:=Vector2(float(protocol.cavity_center_world_x)+com.x-cavity.get_center().x,float(protocol.floor_top_world_y)+com.y-floor_rect.position.y)
	if not require(runtime.configure_review_fleet(index,options,spawn),"fresh U-comparison owner: "+runtime.last_error):
		runtime.close();runtime.free();return {}
	var arena=runtime._arena
	var world: Object=arena._world
	var body: RigidBody2D=arena.session.bodies()[0]
	var rectangles: Array=resolved.resolved_rects
	require(arena.session.bodies().size()==1 and body.get_child_count()==rectangles.size(),"one actual body with all registered colliders")
	require(world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0),"clear initial course")
	for wall: Array in protocol.walls:
		require(world.diagnostic_fill_rect(Vector2i(wall[0],wall[1]),Vector2i(wall[2],wall[3]),58),"closed hard boundaries")
	var seed: Array=protocol.seed
	var seed_pose:=Transform2D(0,spawn)
	for y: int in range(seed[1],seed[1]+seed[3]):
		for x: int in range(seed[0],seed[0]+seed[2]):
			require(int(world.rigid_body_id_at(x,y))==0 and classify_local(seed_pose.affine_inverse()*Vector2(x+.5,y+.5),rectangles,com,definition,profile).inside_rectangles.is_empty(),"initial grain is outside sampled and exact hull")
	require(world.diagnostic_fill_rect(Vector2i(seed[0],seed[1]),Vector2i(seed[2],seed[3]),int(spec.material)),"initial native cargo")
	var before: Dictionary=Prior.whole_fixture(world,int(spec.material))
	require(not before.failed and before.points.size()==16,"initial exact16-grain quantity")
	var report: Dictionary={"options":options,"spawn":spawn,"mass":body.mass,"inertia":body.inertia,"before":before,"initial":Base.state(body),"rows":[],
		"observer_scope":{"snapshots":"Stored cells, bounded128-cell ROI with complete fallback/periodic census","endpoint_counters":null,"identity_limitation":"Coordinate sets, no persistent grain identities","phase":"pre-native sampled pose and post-Rapier current pose, no extra preparation/physics ticks"}}
	var previous: Array=before.points
	for tick: int in range(int(protocol.ticks)):
		if not errors.is_empty(): break
		var state_before: Dictionary=Base.state(body)
		var sample:=Transform2D(float(state_before.rotation),state_before.position)
		var pre: Dictionary=observe(world,sample,sample,rectangles,com,definition,profile,previous,int(spec.material),tick%60==0)
		if not require(not pre.failed and pre.observed_count==16,"complete pre-step coordinate set"): break
		var clocks: Array=[world.get_tick_index(),arena.session.bridge.manual_step_count(),int(arena.gcr_stats.responses),int(arena.gcr_stats.applications)]
		var request: Dictionary=command(protocol,spec,tick)
		require(runtime.submit_review_action(request.action,request.ports),"registered motor input")
		var started: int=Time.get_ticks_usec()
		var snapshot: Dictionary=runtime.step()
		var elapsed: int=Time.get_ticks_usec()-started
		var state_after: Dictionary=Base.state(body)
		if not require(not snapshot.failed,"normal owner step: "+runtime.last_error):
			report.failure={"tick":tick,"pre":pre,"sample_state":state_before,"state":state_after,"snapshot":snapshot,"native":world.gcr_compound_diagnostics(),"bridge":arena.session.bridge.gcr_application_diagnostics()};break
		var diag: Dictionary=world.gcr_compound_diagnostics()
		var selector: String={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}[spec.response]
		require(diag.get("admission_kind")=="authored" and diag.get("granular_events")==selector and int(diag.proxy_count)==rectangles.size(),"actual selector and complete profile union")
		var post: Dictionary=observe(world,sample,Transform2D(float(state_after.rotation),state_after.position),rectangles,com,definition,profile,pre.points,int(spec.material),tick%60==0 or tick==int(protocol.ticks)-1)
		if not require(not post.failed and post.observed_count==16,"complete post-step coordinate set"): break
		for observed: Dictionary in [pre,post]:
			if observed.global_counts!=null: require(observed.global_counts==before.counts and int(observed.global_water_mass)==int(before.water_mass),"exact closed quantities")
		var application: Dictionary=arena.session.bridge.gcr_application_diagnostics()
		var after_clocks: Array=[world.get_tick_index(),arena.session.bridge.manual_step_count(),int(arena.gcr_stats.responses),int(arena.gcr_stats.applications)]
		var steps: Array=[int(after_clocks[0])-int(clocks[0]),int(after_clocks[1])-int(clocks[1])]
		var responses: Array=[int(after_clocks[2])-int(clocks[2]),int(after_clocks[3])-int(clocks[3])]
		var applications: Array=application.get("bodies",[])
		var wrenches: int=int(applications[0].get("physical_wrench_applications",-1)) if applications.size()==1 else -1
		require(steps==[1,1] and responses[0]==1 and responses[1] in [0,1] and application.get("accepted",false) and applications.size()==1 and wrenches in [0,1],"one actual owner boundary/wrench")
		report.rows.append(Base.portable({"tick":tick,"sample_state":state_before,"state":state_after,"before":pre,"after":post,"request":request,
			"actuation":arena.session._rigs[0]._player_controller.observation(),"gcr":diag,"application":application,"observed_steps":steps,"observed_response_counts":responses,
			"physical_wrench_applications":wrenches,"step_us":elapsed,"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}))
		previous=post.points
	report.after=Prior.whole_fixture(world,int(spec.material))
	require(not report.after.failed and report.after.counts==before.counts and report.after.water_mass==before.water_mass,"final exact quantities")
	runtime.close();runtime.free()
	return report

func _run() -> void:
	var args: Dictionary={}
	for item: String in OS.get_cmdline_user_args():
		var pair:=item.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not parsed is Dictionary or not configuration_error(parsed).is_empty(): push_error("U-hull protocol refused");quit(1);return
	var protocol: Dictionary=parsed
	var profile: Dictionary={}
	for item: Dictionary in protocol.profiles:
		if item.id==args.get("profile",""): profile=item
	if profile.is_empty(): push_error("U-hull profile refused");quit(1);return
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(profile.definition_path)))
	var resolved: Dictionary=Authoring.resolve_record(raw) if raw is Dictionary else {"error":"definition JSON"}
	if resolved.has("error"): push_error("U-hull definition refused");quit(1);return
	var saved: Dictionary=Fleet.registry_snapshot()
	var records: Array=saved.records.duplicate(true)
	var index: int=Fleet.index_for_id("scooper")
	records[index]=raw.duplicate(true)
	if not require(Fleet.restore_registry({"records":records,"manifest":profile.definition_path}),"validated copied profile override"):
		quit(1);return
	var mode: String=str(args.get("mode","physical"))
	var spec: Dictionary={}
	if mode=="physical":
		for item: Dictionary in protocol.cases:
			if item.id==args.get("case",""): spec=item
		if spec.is_empty(): push_error("U-hull case refused");Fleet.restore_registry(saved);quit(1);return
	elif mode!="raster": push_error("U-hull mode refused");Fleet.restore_registry(saved);quit(1);return
	var report: Dictionary=static_masks(protocol,raw,resolved,profile) if mode=="raster" else physical(protocol,spec,raw,resolved,profile)
	report.merge({"registration":REGISTRATION,"mode":mode,"profile":profile,"case":spec,"platform":OS.get_name(),"definition":raw,
		"definition_canonical":JSON.stringify(raw,"",true,true),"resolved_com":resolved.resolved_com,"resolved_area":resolved.resolved_area,
		"resolved_inertia":resolved.resolved_inertia,"hull_rectangles":resolved.resolved_rects,"errors":errors,
		"identity":{"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"inputs":OS.get_environment("GCR_SCOOPER_INPUTS"),"protocol_sha256":FileAccess.get_sha256(str(args.protocol)),
			"definition_hash":resolved.definition_hash,"definition_file_sha256":FileAccess.get_sha256(str(profile.definition_path)),"engine_version":Engine.get_version_info().string,
			"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")}},true)
	require(Fleet.restore_registry(saved),"restore prior catalogue")
	report.ok=errors.is_empty() and report.get("rows",[]).size()==(24 if mode=="raster" else 450)
	var output:=FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if output==null: push_error("U-hull output refused");quit(1);return
	output.store_string(JSON.stringify(Base.portable(report)));output.close()
	print("GCR_SCOOPER_U_CAPTURE ",JSON.stringify({"mode":mode,"profile":profile.id,"case":spec.get("id",""),"rows":report.get("rows",[]).size(),"ok":report.ok,"errors":errors}))
	quit(0 if report.ok else 1)
