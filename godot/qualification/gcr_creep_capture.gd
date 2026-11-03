extends SceneTree

# Investigation apparatus only. Calls the retained synchronous owners unchanged;
# never replaces their mask, force, correction, controller or material laws.
const BarrelFixture = preload("res://tests/support/y1_envelope_fixture.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const REGISTRATION: String = "GCR-CREEP-001-2026-11-03"
const ROOM := Rect2i(128,128,512,384)
const FLYER_POSITION := Vector2(296,312)
const FLYER_ANGLE: float = PI/2.0
const FLYER_SIZE := Vector2(9,6)
var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

static func portable(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if str(key) not in ["cells","contact_bins","terrain_chunks","members","witness_offset_counts"]:
				result[str(key)]=portable(value[key])
		return result
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat64Array or value is PackedFloat32Array:
		var result: Array = []
		for item: Variant in value:
			result.append(portable(item))
		return result
	return value

static func phase_drive(spec: Dictionary, step: int) -> bool:
	var mode: String = str(spec.drive)
	return step>=120 and step<(180 if mode=="pulse" else 1200) and mode in ["pulse","sustained"]

static func configuration_matches_protocol(protocol: Dictionary) -> bool:
	return configuration_protocol_error(protocol).is_empty()

static func metadata_equal(actual: Variant, expected: Variant) -> bool:
	# JSON decimal parsing may differ from a source float literal by a few ULPs.
	# This absolute1e-12 tolerance applies only to floating configuration metadata;
	# integer geometry, schedules, material quantities and physical gates stay exact.
	if expected is float:
		return (actual is int or actual is float) and is_finite(float(actual)) and absf(float(actual)-expected)<=1e-12
	if expected is int:
		return (actual is int or actual is float) and is_finite(float(actual)) and float(actual)==float(expected)
	if expected is Array:
		if not actual is Array or actual.size()!=expected.size():
			return false
		for index: int in range(expected.size()):
			if not metadata_equal(actual[index],expected[index]):
				return false
		return true
	return typeof(actual)==typeof(expected) and actual==expected

static func configuration_protocol_error(protocol: Dictionary) -> String:
	var common: Dictionary = {"registration":REGISTRATION,"pulse_start":120,"pulse_end":180,"drive_end":1200,"drive_fraction":.15,"effort":.7}
	for key: String in common:
		if not protocol.has(key) or not metadata_equal(protocol[key],common[key]):
			return "protocol."+key+" differs from registered capture value"
	var flyer: Dictionary = protocol.get("fixture_flyer",{})
	var expected: Dictionary = {"fleet_index":2,"position":[296,312],"angle":PI/2.0,"region":[128,128,512,384],
		"base":[129,320,510,191],"bank":[300,192,339,128],"border_material":1,"gravity":38,
		"mass":.1,"inertia":.975,"mass_multiplier":1,"inertia_multiplier":1,"thrust_multiplier":1,"torque_multiplier":1,
		"census_interval":60,"fire":false,"dispensers":false}
	for key: String in expected:
		if not flyer.has(key) or not metadata_equal(flyer[key],expected[key]):
			return "protocol.fixture_flyer."+key+" differs from registered capture value"
	var barrel: Dictionary = protocol.get("fixture_barrel",{})
	for key: String in ["drive_impulse","gravity"]:
		if not barrel.has(key) or not metadata_equal(barrel[key],.02 if key=="drive_impulse" else 92.12):
			return "protocol.fixture_barrel."+key+" differs from registered capture value"
	return ""

static func state(body: RigidBody2D) -> Dictionary:
	var rid: RID = body.get_rid()
	var pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
	return {"position":pose.origin,"rotation":pose.get_rotation(),
		"velocity":PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY),
		"omega":PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)}

static func same_quantity(before: Dictionary, after: Dictionary) -> bool:
	if before.is_empty() or after.is_empty() or before.counts.size()!=after.counts.size():
		return false
	if int(before.water_mass)!=int(after.water_mass):
		return false
	for index: int in range(before.counts.size()):
		# Water may occupy a different number of cells with unchanged quantity.
		if index not in [0,3] and int(before.counts[index])!=int(after.counts[index]):
			return false
	return true

static func application_step(application: Dictionary, previous: int, step: int) -> Dictionary:
	var current: int = int(application.get("snapshot",-1))
	return {"version":1,"physics_call":step,"snapshot_before":previous,"snapshot_after":current,
		"delivered_this_step":current>previous and application.get("accepted",false)}

static func flyer_census(world: Object) -> Dictionary:
	var census: Dictionary = world.diagnostic_snapshot(ROOM.position,ROOM.size,false,false)
	census.erase("cells")
	census["domain"]=[ROOM.position.x,ROOM.position.y,ROOM.size.x,ROOM.size.y]
	return census

static func author_flyer_initial_pose(arena) -> Dictionary:
	# configure_review_fleet already primes a native sample. reset_body would
	# create a different bridge session, which the primed native owner correctly
	# refuses. Initial authoring instead retires that sample's occupancy, keeps
	# its session/serial history, and primes the final pose with resolve=false.
	# The empty preparation also retires the old previous geometry so setup
	# cannot manufacture a swept path between two authored orientations.
	var result: Dictionary = {"accepted":false,"phase":"initial authoring before baseline or physics",
		"retired_ack":false,"primed_ack":false}
	if arena==null or arena.session==null or arena.session.bodies().size()!=1:
		result["error"]="fixture requires its one configured flyer"
		return result
	var world: Object = arena._world
	var bridge: CyberRapierPhysicsBridge = arena.session.bridge
	var body: RigidBody2D = arena.session.bodies()[0]
	var before: Dictionary = flyer_census(world)
	result["session_before"]=bridge._gcr_session_id
	result["sample_before"]=bridge._sample_serial
	result["native_tick_before"]=int(world.get_tick_index())
	result["retired_ack"]=bool(world.prepare_gcr_coupling(PackedFloat64Array(),false))
	result["mask_after_retire"]=[world.rigid_body_id_at(296,312),world.rigid_body_id_at(299,312),world.rigid_body_id_at(296,315)]
	if not result.retired_ack:
		result["error"]="initial occupancy retirement refused"
		return result
	PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(FLYER_ANGLE,FLYER_POSITION))
	bridge.refresh_all_states()
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	if states.size()!=17:
		result["error"]="initial authored sample packing refused"
		return result
	result["primed_ack"]=bool(world.prepare_gcr_coupling(states,false))
	result["session_after"]=bridge._gcr_session_id
	result["sample_after"]=bridge._sample_serial
	result["packed_session"]=states[16]
	result["packed_sample"]=states[10]
	result["native_tick_after"]=int(world.get_tick_index())
	result["mask_after_prime"]=[world.rigid_body_id_at(296,312),world.rigid_body_id_at(299,312),world.rigid_body_id_at(296,315)]
	var after: Dictionary = flyer_census(world)
	result["counts_unchanged"]=before.counts==after.counts
	result["water_before"]=before.water_mass
	result["water_after"]=after.water_mass
	result["water_unchanged"]=int(before.water_mass)==int(after.water_mass)
	result["accepted"]=result.primed_ack and result.session_before==result.session_after and float(result.packed_session)==float(result.session_before) and int(result.sample_after)==int(result.sample_before)+1 and int(result.packed_sample)==int(result.sample_after) and result.native_tick_before==result.native_tick_after and result.counts_unchanged and result.water_unchanged and result.mask_after_retire==[0,0,0] and result.mask_after_prime==[1,0,1]
	if not result.accepted:
		result["error"]="initial authoring ownership, mask or conservation witness refused"
	return result

static func hard_contacts(body: RigidBody2D) -> int:
	var direct: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.get_rid())
	if direct==null:
		return 0
	var count: int = 0
	for index: int in range(direct.get_contact_count()):
		var collider: RID = direct.get_contact_collider(index)
		if collider.is_valid() and PhysicsServer2D.body_get_mode(collider)==PhysicsServer2D.BODY_MODE_STATIC:
			count+=1
	return count

static func flyer_overlap(world: Object, body_state: Dictionary) -> Dictionary:
	var position: Vector2 = body_state.position
	var angle: float = float(body_state.rotation)
	var extent := Vector2(absf(cos(angle))*FLYER_SIZE.x+absf(sin(angle))*FLYER_SIZE.y,
		absf(sin(angle))*FLYER_SIZE.x+absf(cos(angle))*FLYER_SIZE.y)*.5
	# Read a two-cell expanded footprint as well, so hard support adjacent to
	# the body cannot be mislabelled as granular-only just because overlap is0.
	var first := Vector2i(maxi(0,floori(position.x-extent.x-2.0)),maxi(0,floori(position.y-extent.y-2.0)))
	var last := Vector2i(mini(1024,ceili(position.x+extent.x+2.0)),mini(1024,ceili(position.y+extent.y+2.0)))
	if last.x<=first.x or last.y<=first.y:
		return {"post_overlap":null,"hard_overlap":null,"hard_floor_contact":true,"hard_clearance":false}
	var snapshot: Dictionary = world.diagnostic_snapshot(first,last-first,false,false)
	if snapshot.is_empty():
		return {"post_overlap":null,"hard_overlap":null,"hard_floor_contact":null,"hard_clearance":null}
	var cells: PackedByteArray = snapshot.cells
	var overlap: int = 0
	var hard_overlap: int = 0
	var nearby_hard: int = 0
	for y: int in range(first.y,last.y):
		for x: int in range(first.x,last.x):
			var local := Vector2(x+.5-position.x,y+.5-position.y).rotated(-angle)
			var material: int = cells[(y-first.y)*(last.x-first.x)+x-first.x]
			if material==1 and absf(local.x)<=FLYER_SIZE.x*.5+2.0 and absf(local.y)<=FLYER_SIZE.y*.5+2.0:
				nearby_hard+=1
			if absf(local.x)>FLYER_SIZE.x*.5 or absf(local.y)>FLYER_SIZE.y*.5:
				continue
			if material!=0 and material!=1:
				overlap+=1
			elif material==1:
				hard_overlap+=1
	return {"post_overlap":overlap,"post_overlap_phase":"after Rapier integration; stored non-Empty/non-Wall cell centres",
		"hard_overlap":hard_overlap,"nearby_hard_cell_count":nearby_hard,
		"hard_floor_contact":position.y+extent.y>=510.5,
		"hard_clearance":nearby_hard==0 and position.x-extent.x>131.0 and position.x+extent.x<637.0 and position.y-extent.y>131.0 and position.y+extent.y<509.0,
		"body_bounds":[position.x-extent.x,position.y-extent.y,position.x+extent.x,position.y+extent.y]}

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:
			arguments[pair[0]]=pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(arguments.get("protocol",""))))
	if not protocol is Dictionary or not configuration_matches_protocol(protocol):
		push_error("GCR creep protocol identity refused: "+configuration_protocol_error(protocol) if protocol is Dictionary else "GCR creep protocol is not an object")
		quit(1)
		return
	var spec: Dictionary = {}
	for entry: Dictionary in protocol.cases:
		if entry.id==arguments.get("case",""):
			spec=entry
	if spec.is_empty() or int(spec.get("ticks",0))!=1800 or spec.kind not in ["barrel","flyer"] or spec.get("drive","") not in ["passive","coast","unactuated","pulse","sustained"] or int(spec.get("material",-1)) not in [1,2,3,23]:
		push_error("GCR creep case refused")
		quit(1)
		return
	var report: Dictionary = {"schema":1,"registration":REGISTRATION,"case":spec,"platform":OS.get_name(),
		"rows":[],"errors":[],"ok":false,"outcome":"CAPTURED","dt":1.0/60.0,
		"scope":"Apparatus-only synchronous independent-body observation; unchanged GCR-LA control, no sleep or causal correction intervention",
		"identity":{"source":OS.get_environment("GCR_CREEP_SOURCE"),"input_identity":OS.get_environment("GCR_CREEP_INPUT_IDENTITY"),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
			"engine_version":Engine.get_version_info().string,"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),
			"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
			"protocol_sha256":FileAccess.get_sha256(str(arguments.protocol))}}
	if spec.kind=="barrel":
		await capture_barrel(spec,report,protocol.fixture_barrel)
	else:
		await capture_flyer(spec,report)
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==int(spec.ticks)
	var file := FileAccess.open(str(arguments.get("output","")),FileAccess.WRITE)
	if file==null:
		push_error("GCR creep output refused")
		quit(1)
		return
	file.store_string(JSON.stringify(portable(report)))
	file.close()
	print("GCR_CREEP_CAPTURE ",JSON.stringify({"case":spec.id,"ok":report.ok,"rows":report.rows.size(),"errors":errors}))
	quit(0 if report.ok else 1)

func capture_barrel(spec: Dictionary, report: Dictionary, registered_fixture: Dictionary) -> void:
	var fixture = BarrelFixture.new()
	var drive_schedule: Array = []
	if str(spec.drive) in ["pulse","sustained"]:
		drive_schedule.append([120,180 if spec.drive=="pulse" else 1200,.02])
	var configuration: Dictionary = registered_fixture.duplicate(true)
	configuration.erase("drive_impulse")
	configuration.merge({"material":int(spec.material),"ticks":1800,"rest_mode":"control","base_budget":20.0,"drive_impulse_schedule":drive_schedule},true)
	report.schedule="retained-y1-envelope: drive -> Rapier -> sample -> native -> correction/zeroing/wrench"
	report.configuration=configuration
	if not await fixture.setup(root,configuration,"GCR-REST"):
		errors.append("barrel setup: "+fixture.error)
		fixture.close()
		return
	report.before=portable(fixture.observation())
	report.initial_state=state(fixture.bodies[0])
	report.actual_mass=fixture.bodies[0].mass
	report.actual_inertia=PhysicsServer2D.body_get_param(fixture.bodies[0].get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	report.gravity=92.12
	report.runtime_identity=fixture.runtime_identity()
	if str(report.runtime_identity.get("admission_variant",""))!="A1":
		errors.append("barrel LA admission identity mismatch")
		fixture.close()
		return
	var previous_snapshot: int = -1
	for step: int in range(1800):
		var captured: Array = fixture.step()
		if captured.size()!=1:
			errors.append("barrel step "+str(step)+": "+fixture.error)
			break
		var source: Dictionary = captured[0]
		var pose: Array = source.out
		var application: Dictionary = source.get("application",{})
		var driven: bool = phase_drive(spec,step)
		var row: Dictionary = {"tick":step,"position":[pose[0],pose[1]],"rotation":pose[2],"velocity":[pose[3],pose[4]],"omega":pose[5],
			"command_active":driven,"drive_phase":"driven" if driven else "quiet" if step<120 else "released",
			"input_action":{"drive":str(spec.drive),"drive_active":driven,"impulse_x":.02 if driven else 0.0},
			"controller":{"kind":"authored bounded impulse schedule","enabled":driven,"applied_force":[1.2 if driven else 0.0,0.0],
				"applied_torque":0.0,"actual_impulse":[.02 if driven else 0.0,0.0],"actual_torque_impulse":0.0},
			"application":application,"application_step":application_step(application,previous_snapshot,step),
			"gcr":source.get("gcr",{}),"pre_overlap":source.pre_overlap,"post_overlap":source.post_overlap,"tick_overlap":source.tick_overlap,
			"post_overlap_phase":"after native ejection at incoming pose; tick_overlap is after material tick and correction",
			"material_count":source.material_count,"water":source.water,"conserved":source.conserved,
			"hard_floor_contact":source.hard_floor_contact,"hard_clearance":fixture.rest_hard_clearance(),
			"incoming_state":source["in"],"computed_result":source.computed_result,"result":source.result,
			"admission":source.get("admission",{}),"rest_receipt":source.rest_receipt,"vertical_depth":source.vertical_depth,
			"times_us":source.times_us,"work":source.work}
		previous_snapshot=int(application.get("snapshot",-1))
		report.rows.append(portable(row))
		if not source.conserved:
			errors.append("barrel conservation at "+str(step))
			break
		if not fixture.error.is_empty():
			errors.append(fixture.error)
			break
	report.after=portable(fixture.observation())
	report.final_state=state(fixture.bodies[0])
	fixture.close()
	await process_frame

func capture_flyer(spec: Dictionary, report: Dictionary) -> void:
	var arena = Arena.new()
	root.add_child(arena)
	await process_frame
	var unactuated: bool = str(spec.drive)=="unactuated"
	var controls: Dictionary = {"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
		"thrust_multiplier":0.0 if unactuated else 1.0,"torque_multiplier":0.0 if unactuated else 1.0}
	var configuration: Dictionary = {"version":Arena.VERSION,"seed":0,"max_ticks":1801,"local_patch_radius":0,
		"course":"manoeuvre","actors":[{"model":"arcadelander","producer":"human","position":FLYER_POSITION}]}
	if not arena.configure_review_fleet(configuration,"GCR-REST","GCR-REST-001-2026-11-02",2,controls):
		errors.append("flyer configure: "+arena.last_error)
		arena.free()
		return
	var world: Object = arena._world
	if str(world.get_gcr_admission_variant())!="A1":
		errors.append("flyer LA admission identity mismatch")
		arena.close()
		arena.free()
		return
	var authored: Array = [
		[ROOM.position,ROOM.size,0],
		[Vector2i(128,128),Vector2i(512,1),1],[Vector2i(128,511),Vector2i(512,1),1],
		[Vector2i(128,128),Vector2i(1,384),1],[Vector2i(639,128),Vector2i(1,384),1],
		[Vector2i(129,320),Vector2i(510,191),int(spec.material)],
		[Vector2i(300,192),Vector2i(339,128),int(spec.material)]]
	for rectangle: Array in authored:
		if not world.diagnostic_fill_rect(rectangle[0],rectangle[1],rectangle[2]):
			errors.append("flyer authored room refused")
			arena.free()
			return
	var body: RigidBody2D = arena.session.bodies()[0]
	report["initial_authoring"]=author_flyer_initial_pose(arena)
	if not report.initial_authoring.get("accepted",false):
		errors.append("flyer initial authoring: "+str(report.initial_authoring.get("error","")))
		arena.close()
		arena.free()
		return
	# Terrain authoring uses the arena's existing revision consumer on its next
	# normal step; setup changes no production scheduling or response path.
	report.configuration={"controls":controls,"fleet_index":2,"fleet_name":Fleet.NAMES[2],
		"room":[128,128,512,384],"base":[129,320,510,191],"bank":[300,192,339,128],
		"initial_position":FLYER_POSITION,"initial_angle":FLYER_ANGLE,"material":int(spec.material),
		"drive_fraction":.15,"effort":.7,"census_cadence":60}
	report.schedule=Arena.SCHEDULE
	report.actual_mass=body.mass
	report.actual_inertia=PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	if not is_equal_approx(float(report.actual_mass),.1) or not is_equal_approx(float(report.actual_inertia),.975):
		errors.append("flyer actual payload mass or inertia mismatch")
		arena.close()
		arena.free()
		return
	report.gravity=38.0
	report.runtime_identity={"native_candidate":"GCR-REST","admission_variant":world.get_gcr_admission_variant(),"rest_mode":"control","base_budget":20.0}
	report.before=portable(flyer_census(world))
	report.initial_state=state(body)
	var expected: Dictionary = flyer_census(world)
	var previous_snapshot: int = -1
	for step: int in range(1800):
		var driven: bool = phase_drive(spec,step)
		var action: Dictionary = {"move":Vector2(0,-.15 if driven else 0.0),"aim":Vector2.RIGHT,"effort":.7,
			"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
		var view: Dictionary = arena.observation(0)
		var command: Dictionary = arena.session.make_command(view,int(view.last_sequence)+1,action)
		if not arena.submit(command,&"human"):
			errors.append("flyer command refused at "+str(step)+": "+arena.last_error)
			break
		var prior: Dictionary = state(body)
		var started: int = Time.get_ticks_usec()
		var snapshot: Dictionary = arena.step()
		var step_us: int = Time.get_ticks_usec()-started
		if snapshot.get("failed",false):
			errors.append("flyer owner step "+str(step)+": "+str(snapshot.get("reason","")))
			break
		var observed: Dictionary = state(body)
		var application: Dictionary = arena.session.bridge.gcr_application_diagnostics()
		var diagnostics: Dictionary = world.gcr_diagnostics()
		var body_diagnostics: Dictionary = diagnostics.get("bodies",[{}])[0] if not diagnostics.get("bodies",[]).is_empty() else {}
		var rig = arena.session._rigs[0]
		var controller: Dictionary = rig._player_controller.observation()
		controller["enabled"]=not unactuated
		controller["actual_impulse"]=rig._last_impulse
		controller["actual_torque_impulse"]=rig._last_torque_impulse
		controller["movement_limited"]=rig._movement_limited
		controller["accepted_action"]=rig._action.duplicate(true)
		var row: Dictionary = {"tick":step,"position":observed.position,"rotation":observed.rotation,"velocity":observed.velocity,"omega":observed.omega,
			"command_active":driven,"drive_phase":"driven" if driven else "quiet" if step<120 else "released",
			"input_action":action.duplicate(true),"input_drive_active":driven,"controller":controller,
			"application":application,"application_step":application_step(application,previous_snapshot,step),"gcr":body_diagnostics,
			"pre_overlap":null,"material_count":null,"water":null,"conserved":null,"incoming_state":prior,
			"rest_receipt":world.gcr_rest_receipt(),"step_us":step_us,
			"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}
		previous_snapshot=int(application.get("snapshot",-1))
		row.merge(flyer_overlap(world,observed))
		row["hard_contact_count"]=hard_contacts(body)
		if int(row.hard_contact_count)>0:
			row.hard_clearance=false
		if step%60==0 or step==1799:
			var census: Dictionary = flyer_census(world)
			row["census"]=census
			row.material_count=census.counts[int(spec.material)]
			row.water=census.water_mass
			row.conserved=same_quantity(expected,census)
			if not row.conserved:
				errors.append("flyer conservation at "+str(step))
		report.rows.append(portable(row))
		if not Vector2(observed.position).is_finite() or not Vector2(observed.velocity).is_finite() or not is_finite(float(observed.rotation)) or not is_finite(float(observed.omega)):
			errors.append("flyer nonfinite state at "+str(step))
		if not application.get("accepted",false):
			errors.append("flyer response refused at "+str(step))
		if not errors.is_empty():
			break
	report.after=portable(flyer_census(world))
	report.final_state=state(body)
	if not same_quantity(expected,report.after):
		errors.append("flyer final quantity conservation")
	arena.close()
	arena.free()
	await process_frame
