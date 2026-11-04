extends SceneTree

# Observational apparatus only: normal owner boundaries, immutable stored-cell
# snapshots, no material writes after setup and no additional physics steps.
const Runtime=preload("res://scripts/player_playground_runtime.gd")
const Fleet=preload("res://scripts/gcr_review_fleet.gd")
const Authoring=preload("res://scripts/gcr_flyer_authoring.gd")
const Base=preload("res://qualification/gcr_creep_capture.gd")
const REGISTRATION: String="GCR-CARRY-002"
const Historical=preload("res://tests/support/gcr_historical_scooper.gd")
const WORLD_RECT:=Rect2i(0,0,1024,512)
const ROI_SIZE: int=128
const GLOBAL_PERIOD: int=60
const EXPECTED_CASES: Dictionary={
	"stationary":["LA-SELECTIVE",[0,0],false],
	"rise-slow":["LA-SELECTIVE",[0,-0.1],false],
	"rise-moderate":["LA-SELECTIVE",[0,-0.5],false],
	"rise-full":["LA-SELECTIVE",[0,-1],false],
	"rise-boost":["LA-SELECTIVE",[0,-1],true],
	"closed-end":["LA-SELECTIVE",[1,0],false],
	"open-end":["LA-SELECTIVE",[-1,0],false],
	"diagonal":["LA-SELECTIVE",[1,-1],false],
	"rise-full-LA":["LA",[0,-1],false],
	"rise-full-LA-EVENT-OFF":["LA-EVENT-OFF",[0,-1],false]}
var errors: Array[String]=[]

func _init() -> void: call_deferred("_run")
func require(ok: bool, why: String) -> bool:
	if not ok: errors.append(why)
	return ok

static func configuration_protocol_error(protocol: Dictionary) -> String:
	var expected: Dictionary={"schema":1,"registration":REGISTRATION,"dt":1.0/60.0,"workers":1,"ticks":450,
		"spawn":[512,250],"material":2,"grains":16,"material_rects":[[504,249,16,1]],
		"walls":[[16,396,992,6],[16,16,6,386],[1002,16,6,386],[16,16,992,6]],
		"move_from":120,"move_to":240,"brake_to":330}
	if protocol.size()!=expected.size()+1: return "protocol fields"
	for key: String in expected:
		if not protocol.has(key) or not Base.metadata_equal(protocol[key],expected[key]): return "protocol "+key
	if not protocol.get("cases") is Array or protocol.cases.size()!=EXPECTED_CASES.size(): return "case capacity"
	var seen: Dictionary={}
	for item: Variant in protocol.cases:
		if not item is Dictionary or item.size()!=4 or not item.has("id") or not EXPECTED_CASES.has(item.id) or seen.has(item.id): return "case fields or identity"
		var row: Array=EXPECTED_CASES[item.id]
		if not Base.metadata_equal(item.get("response"),row[0]) or not Base.metadata_equal(item.get("move"),row[1]) or not Base.metadata_equal(item.get("boost"),row[2]): return "case configuration"
		seen[item.id]=true
	return ""

static func command(protocol: Dictionary, spec: Dictionary, tick: int) -> Dictionary:
	var moving: bool=tick>=int(protocol.move_from) and tick<int(protocol.move_to)
	var braking: bool=tick>=int(protocol.move_to) and tick<int(protocol.brake_to)
	return {"action":{"move":Vector2(float(spec.move[0]),float(spec.move[1])) if moving else Vector2.ZERO,
		"aim":Vector2.RIGHT,"effort":1.0,"trim":0.0,"primary":false,"secondary":braking,"auxiliary":false},
		"ports":{"q":false,"e":false,"s":false,"boost":moving and bool(spec.boost)}}

static func classify_local(local: Vector2, rectangles: Array, authored_com: Vector2) -> Dictionary:
	# Geometry membership mirrors the native inclusive centre test, rather than
	# Rect2.has_point's half-open upper edge. Primary cavity retains the earlier
	# half-open rectangle for an exact comparison with GCR-AUTHORED-001.
	var raw: Vector2=local+authored_com
	var indices: Array[int]=[]
	for index: int in range(rectangles.size()):
		var rectangle: Dictionary=rectangles[index]
		var delta: Vector2=local-Vector2(rectangle.center)
		var half: Vector2=Vector2(rectangle.size)*0.5
		if absf(delta.x)<=half.x and absf(delta.y)<=half.y: indices.append(index)
	var primary: bool=Rect2(-12,-4,24,6).has_point(raw)
	var inner_x: bool=raw.x>=-12 and raw.x<12
	var category: String="free_near_hull"
	if not indices.is_empty(): category="deck" if indices[0]==0 else "closed_stop" if indices[0]==1 else "nose"
	elif raw.y>4 and inner_x: category="below_closed_deck"
	elif raw.x < -15: category="beyond_closed_stop"
	elif raw.x > 18: category="beyond_open_nose"
	elif raw.y < -5: category="above_rim"
	elif raw.x>=-13 and raw.x<13 and raw.y>=-5 and raw.y<2: category="cavity"
	return {"local":local,"authored_local":raw,"class":category,"inside_rectangles":indices,
		"primary_cavity":primary,"closed_deck_interior_x":inner_x,
		"below_closed_deck":inner_x and raw.y>4,"below_deck_margin":raw.y-4,
		"beyond_closed_stop":raw.x < -15,"closed_stop_margin":-15-raw.x,
		"beyond_open_nose":raw.x > 18,"open_nose_margin":raw.x-18,
		"above_rim":raw.y < -5,"rim_margin":-5-raw.y}

static func points_from_snapshot(snapshot: Dictionary, origin: Vector2i, size: Vector2i, material: int) -> Array[Vector2i]:
	var points: Array[Vector2i]=[]
	var cells: PackedByteArray=snapshot.get("cells",PackedByteArray())
	if cells.size()!=size.x*size.y: return points
	# Search native packed bytes directly; do not run a GDScript loop for every
	# empty cell of the diagnostic window.
	var cursor: int=cells.find(material)
	while cursor>=0:
		points.append(origin+Vector2i(cursor%size.x,floori(float(cursor)/float(size.x))))
		cursor=cells.find(material,cursor+1)
	return points

static func whole_fixture(world: Object, material: int) -> Dictionary:
	var result: Dictionary={"points":[],"counts":[],"water_mass":0,"failed":false}
	for origin: Vector2i in [Vector2i.ZERO,Vector2i(512,0)]:
		var snapshot: Dictionary=world.diagnostic_snapshot(origin,Vector2i(512,512),false,false)
		if snapshot.is_empty(): return {"failed":true,"reason":"whole fixture snapshot refused"}
		if result.counts.is_empty(): result.counts=snapshot.counts.duplicate()
		else:
			if result.counts.size()!=snapshot.counts.size(): return {"failed":true,"reason":"quantity schema differs"}
			for index: int in range(result.counts.size()): result.counts[index]=int(result.counts[index])+int(snapshot.counts[index])
		result.water_mass+=int(snapshot.water_mass)
		result.points.append_array(points_from_snapshot(snapshot,origin,Vector2i(512,512),material))
	return result

static func observation_roi(pose: Transform2D, rectangles: Array, previous: Array) -> Rect2i:
	var low: Vector2=pose.origin
	var high: Vector2=pose.origin
	for rectangle: Dictionary in rectangles:
		var rect:=Rect2(Vector2(rectangle.center)-Vector2(rectangle.size)*0.5,rectangle.size)
		for vertex: Vector2 in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			var point: Vector2=pose*vertex;low=low.min(point);high=high.max(point)
	for value: Variant in previous:
		var point:=Vector2(value)+Vector2(0.5,0.5);low=low.min(point);high=high.max(point)
	var centre: Vector2=(low+high)*0.5
	return Rect2i(Vector2i(clampi(floori(centre.x)-64,0,WORLD_RECT.size.x-ROI_SIZE),
		clampi(floori(centre.y)-64,0,WORLD_RECT.size.y-ROI_SIZE)),Vector2i(ROI_SIZE,ROI_SIZE))

static func observe(world: Object, sample_pose: Transform2D, actual_pose: Transform2D, rectangles: Array,
		authored_com: Vector2, previous: Array, material: int, expected: int, force_global: bool=false) -> Dictionary:
	var roi: Rect2i=observation_roi(actual_pose,rectangles,previous)
	var snapshot: Dictionary=world.diagnostic_snapshot(roi.position,roi.size,false,false)
	if snapshot.is_empty(): return {"failed":true,"reason":"ROI snapshot refused"}
	var local_points: Array[Vector2i]=points_from_snapshot(snapshot,roi.position,roi.size,material)
	var all: Dictionary={}
	var points: Array=local_points
	if force_global or local_points.size()!=expected:
		all=whole_fixture(world,material)
		if all.failed: return all
		points=all.points
	var result: Dictionary={"failed":false,"roi":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],
		"coverage":"whole-fixture" if not all.is_empty() else "bounded-roi",
		"roi_count":local_points.size(),"observed_count":points.size(),
		"outside_roi_count":points.size()-local_points.size() if not all.is_empty() else null,
		"global_counts":all.get("counts"),"global_water_mass":all.get("water_mass"),"points":[],"grains":[]}
	var sample_inverse: Transform2D=sample_pose.affine_inverse()
	var actual_inverse: Transform2D=actual_pose.affine_inverse()
	for point: Vector2i in points:
		var centre:=Vector2(point)+Vector2(0.5,0.5)
		result.points.append(point)
		result.grains.append({"cell":point,"native_mask_proxy":int(world.rigid_body_id_at(point.x,point.y)),
			"sampled":classify_local(sample_inverse*centre,rectangles,authored_com),
			"current":classify_local(actual_inverse*centre,rectangles,authored_com)})
	return result

static func pose_from_state(value: Dictionary) -> Transform2D:
	return Transform2D(float(value.rotation),Vector2(value.position))

func _run() -> void:
	if not require(Historical.install(),"retain registered stepped Scooper definition"):
		quit(1);return
	var args: Dictionary={}
	for item: String in OS.get_cmdline_user_args():
		var pair:=item.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not parsed is Dictionary or not configuration_protocol_error(parsed).is_empty():
		push_error("Scooper leakage protocol refused");quit(1);return
	var protocol: Dictionary=parsed
	var spec: Dictionary={}
	for entry: Dictionary in protocol.cases:
		if entry.id==args.get("case",""): spec=entry
	if spec.is_empty() or (args.has("response") and args.response!=spec.response):
		push_error("Scooper leakage case/response refused");quit(1);return
	var index: int=Fleet.index_for_id("scooper")
	var rectangles: Array=Fleet.collision_rects(index)
	var resolved: Dictionary=Authoring.resolve_record(Fleet.authoring_record(index))
	var authored_com: Vector2=resolved.resolved_com
	var runtime=Runtime.new();root.add_child(runtime)
	var options: Dictionary={"response":spec.response,"budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
		"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}
	if not runtime.configure_review_fleet(index,options,Vector2(protocol.spawn[0],protocol.spawn[1])):
		push_error("Scooper leakage owner refused: "+runtime.last_error);runtime.close();runtime.free();quit(1);return
	var arena=runtime._arena
	var world: Object=arena._world
	var body: RigidBody2D=arena.session.bodies()[0]
	require(world.diagnostic_fill_rect(Vector2i.ZERO,WORLD_RECT.size,0),"clear diagnostic fixture")
	for rectangle: Array in protocol.walls:
		require(world.diagnostic_fill_rect(Vector2i(rectangle[0],rectangle[1]),Vector2i(rectangle[2],rectangle[3]),58),"closed hard fixture")
	for rectangle: Array in protocol.material_rects:
		require(world.diagnostic_fill_rect(Vector2i(rectangle[0],rectangle[1]),Vector2i(rectangle[2],rectangle[3]),int(protocol.material)),"initial registered load")
	var before: Dictionary=whole_fixture(world,int(protocol.material))
	require(not before.failed and before.points.size()==int(protocol.grains),"initial complete16-grain census")
	var report: Dictionary={"registration":REGISTRATION,"case":spec,"platform":OS.get_name(),"options":options,
		"identity":{"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"inputs":OS.get_environment("GCR_SCOOPER_INPUTS"),
			"protocol_sha256":FileAccess.get_sha256(str(args.protocol)),"definition_hash":Fleet.definition_hash(index),
			"engine_version":Engine.get_version_info().string,"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),
			"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")},
		"hull_rectangles":rectangles,"authored_com":authored_com,"mass":body.mass,"inertia":body.inertia,
		"before":before,"initial":Base.state(body),"rows":[],"errors":[],
		"observer_scope":{"roi_size":ROI_SIZE,"global_period":GLOBAL_PERIOD,"endpoint_counters":null,
			"endpoint_limitation":"diagnostic_body_metrics evaluates per-proxy response and mutates rest history; deliberately not invoked",
			"unobserved_stages":"No observation between ordinary preparation/ejection and native tick or between response and Rapier integration",
			"identity_limitation":"Copied coordinate sets; no persistent cell identities inferred"}}
	var previous: Array=before.get("points",[])
	var expected_selector: String={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}[spec.response]
	for tick: int in range(int(protocol.ticks)):
		if not errors.is_empty(): break
		var state_before: Dictionary=Base.state(body)
		var sample_pose: Transform2D=pose_from_state(state_before)
		var pre: Dictionary=observe(world,sample_pose,sample_pose,rectangles,authored_com,previous,int(protocol.material),int(protocol.grains),tick%GLOBAL_PERIOD==0)
		if not require(not pre.failed,"pre-step observation"): break
		require(pre.observed_count==int(protocol.grains),"pre-step16-grain set")
		var clocks: Array=[world.get_tick_index(),arena.session.bridge.manual_step_count(),int(arena.gcr_stats.responses),int(arena.gcr_stats.applications)]
		var request: Dictionary=command(protocol,spec,tick)
		require(runtime.submit_review_action(request.action,request.ports),"registered pilot action")
		var start: int=Time.get_ticks_usec()
		var snapshot: Dictionary=runtime.step()
		var step_us: int=Time.get_ticks_usec()-start
		var state_after: Dictionary=Base.state(body)
		if not require(not snapshot.failed,"normal owner step: "+runtime.last_error):
			report["failure"]={"tick":tick,"pre":pre,"before_state":state_before,"state_after":state_after,"snapshot":snapshot,
				"native":world.gcr_compound_diagnostics(),"bridge":arena.session.bridge.gcr_application_diagnostics(),"clocks_before":clocks,
				"clocks_after":[world.get_tick_index(),arena.session.bridge.manual_step_count(),int(arena.gcr_stats.responses),int(arena.gcr_stats.applications)]}
			break
		var diag: Dictionary=world.gcr_compound_diagnostics()
		require(diag.get("admission_kind")=="authored" and diag.get("granular_events")==expected_selector,"actual authored mode/selector")
		var post: Dictionary=observe(world,sample_pose,pose_from_state(state_after),rectangles,authored_com,pre.points,int(protocol.material),int(protocol.grains),tick%GLOBAL_PERIOD==0 or tick==int(protocol.ticks)-1)
		if not require(not post.failed,"post-step observation"): break
		require(post.observed_count==int(protocol.grains),"post-step16-grain set")
		for observed: Dictionary in [pre,post]:
			if observed.global_counts!=null:
				require(observed.global_counts==before.counts and int(observed.global_water_mass)==int(before.water_mass),"exact closed native quantities")
		var application: Dictionary=arena.session.bridge.gcr_application_diagnostics()
		var after_clocks: Array=[world.get_tick_index(),arena.session.bridge.manual_step_count(),int(arena.gcr_stats.responses),int(arena.gcr_stats.applications)]
		var observed_steps: Array=[int(after_clocks[0])-int(clocks[0]),int(after_clocks[1])-int(clocks[1])]
		var observed_responses: Array=[int(after_clocks[2])-int(clocks[2]),int(after_clocks[3])-int(clocks[3])]
		var applied: Array=application.get("bodies",[])
		var physical_wrenches: int=int(applied[0].get("physical_wrench_applications",-1)) if applied.size()==1 else -1
		require(observed_steps==[1,1] and observed_responses[0]==1 and observed_responses[1] in [0,1],"one native/Rapier/response boundary")
		require(application.get("accepted",false) and applied.size()==1 and physical_wrenches in [0,1],"one accepted body and at most one wrench")
		report.rows.append(Base.portable({"tick":tick,"sample_state":state_before,"state":state_after,"before":pre,"after":post,
			"request":request,"actuation":arena.session._rigs[0]._player_controller.observation(),"gcr":diag,"application":application,
			"observed_steps":observed_steps,"observed_response_counts":observed_responses,"physical_wrench_applications":physical_wrenches,
			"step_us":step_us,"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}))
		previous=post.points
	report.after=whole_fixture(world,int(protocol.material))
	require(not report.after.failed and report.after.counts==before.counts and report.after.water_mass==before.water_mass,"final exact closed quantities")
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==int(protocol.ticks)
	runtime.close();runtime.free()
	var file:=FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if file==null: push_error("Scooper leakage output refused");quit(1);return
	file.store_string(JSON.stringify(Base.portable(report)));file.close()
	print("GCR_SCOOPER_LEAK_CAPTURE ",JSON.stringify({"case":spec.id,"ticks":report.rows.size(),"ok":report.ok,"errors":errors}))
	quit(0 if report.ok else 1)
