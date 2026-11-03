extends SceneTree

const Base = preload("res://qualification/gcr_creep_capture.gd")
const Flat = preload("res://qualification/gcr_creep_flat_capture.gd")
const CausalArena = preload("res://qualification/gcr_causal_arena.gd")
const Barrel = preload("res://tests/support/y1_envelope_fixture.gd")
const REGISTRATION: String = "GCR-CAUSAL-TC-001-2026-11-03"
var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

static func protocol_error(protocol: Dictionary) -> String:
	var common: Dictionary = {"registration":REGISTRATION,"ticks":1800,"pulse_start":120,"pulse_end":180,"drive_end":1200,"drive_fraction":.15,"effort":.7}
	for key: String in common:
		if not protocol.has(key) or not Base.metadata_equal(protocol[key],common[key]):
			return "protocol."+key+" does not bind the timing capture"
	var fixture: Dictionary = protocol.get("fixture_flyer",{})
	var expected: Dictionary = {"fleet_index":2,"position":[296,312],"flat_angle":0,"region":[128,128,512,384],
		"base":[129,320,510,191],"gravity":38,"mass":.1,"inertia":.975,"mass_multiplier":1,"inertia_multiplier":1,
		"census_interval":60,"fire":false,"dispensers":false}
	for key: String in expected:
		if not fixture.has(key) or not Base.metadata_equal(fixture[key],expected[key]):
			return "protocol.fixture_flyer."+key+" differs from the timing fixture"
	return ""

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:
			arguments[pair[0]]=pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(arguments.get("protocol",""))))
	if not protocol is Dictionary or not protocol_error(protocol).is_empty():
		push_error("Causal timing protocol refused: "+protocol_error(protocol) if protocol is Dictionary else "Causal timing protocol is not an object")
		quit(1)
		return
	var spec: Dictionary = {}
	for entry: Dictionary in protocol.cases:
		if entry.id==arguments.get("case",""):
			spec=entry
	if spec.is_empty() or spec.get("ticks")!=1800 or spec.get("material")!=2 or not Base.metadata_equal(spec.get("contact_gain"),.025) or spec.get("arm","") not in ["C","T","S","X"]:
		push_error("Causal timing case refused")
		quit(1)
		return
	var report: Dictionary = {"schema":1,"registration":REGISTRATION,"case":spec,"platform":OS.get_name(),"dt":1.0/60.0,
		"rows":[],"errors":[],"ok":false,"outcome":"CAPTURED","scope":"Separately registered timing/contact interventions; native response law and source unchanged",
		"identity":{"source":OS.get_environment("GCR_CAUSAL_SOURCE"),"input_identity":OS.get_environment("GCR_CAUSAL_INPUT_IDENTITY"),
			"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine_version":Engine.get_version_info().string,
			"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"protocol_sha256":FileAccess.get_sha256(str(arguments.protocol)),
			"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")}}
	if spec.kind=="flyer" and spec.geometry=="flat" and spec.drive in ["unactuated","sustained"]:
		await capture_flyer(spec,report)
	elif spec.kind=="barrel" and spec.arm in ["C","X"] and spec.geometry in ["barrel-gentle","barrel-high"] and spec.drive=="passive":
		await capture_barrel(spec,report,protocol.fixture_barrel_high if spec.geometry=="barrel-high" else protocol.fixture_barrel)
	else:
		errors.append("case geometry/drive is outside the registered producer")
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==1800
	var file := FileAccess.open(str(arguments.get("output","")),FileAccess.WRITE)
	if file==null:
		push_error("Causal timing output refused")
		quit(1)
		return
	file.store_string(JSON.stringify(Base.portable(report)))
	file.close()
	print("GCR_CAUSAL_TIMING_CAPTURE ",JSON.stringify({"case":spec.id,"ok":report.ok,"rows":report.rows.size(),"errors":errors}))
	quit(0 if report.ok else 1)

func capture_flyer(spec: Dictionary, report: Dictionary) -> void:
	var arena = CausalArena.new()
	root.add_child(arena)
	await process_frame
	var controls: Dictionary = Flat.options(spec.drive=="unactuated")
	if not arena.set_causal_arm(spec.arm) or not arena.configure_review_fleet(Flat.configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,controls):
		errors.append("causal flyer setup: "+arena.last_error)
		arena.free()
		return
	report["initial_authoring"]=Flat.author_room(arena)
	if not report.initial_authoring.accepted:
		errors.append("causal flat authoring refused")
		arena.close()
		arena.free()
		return
	var world: Object = arena._world
	var body: RigidBody2D = arena.session.bodies()[0]
	report.configuration={"controls":controls,"fleet_index":2,"fleet_name":"Kestrel","room":[128,128,512,384],"base":[129,320,510,191],
		"bank":null,"initial_position":Flat.POSITION,"initial_angle":0.0,"material":2,"drive_fraction":.15,"effort":.7,"census_cadence":60,
		"arm":spec.arm,"contact_gain":.025,"contact_gain_binding":"unchanged runtime default, source-input bound; no coefficient setter called"}
	report.schedule="experiment-owned copy of "+arena.SCHEDULE
	report.actual_mass=body.mass
	report.actual_inertia=body.inertia
	report.gravity=38.0
	report.runtime_identity={"native_candidate":"GCR-REST","admission_variant":world.get_gcr_admission_variant(),"rest_mode":"control","base_budget":20.0}
	if str(report.runtime_identity.admission_variant)!="A1" or not is_equal_approx(body.mass,.1) or not is_equal_approx(body.inertia,.975):
		errors.append("causal flyer physical identity refused")
		arena.close()
		arena.free()
		return
	var expected: Dictionary = Base.flyer_census(world)
	report.before=Base.portable(expected)
	report.initial_state=Base.state(body)
	var previous_snapshot: int = -1
	for tick: int in range(1800):
		var driven: bool = Base.phase_drive(spec,tick)
		var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":.15 if driven else 0.0,"primary":false,"secondary":false,"auxiliary":false}
		var view: Dictionary = arena.observation(0)
		if not arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"):
			errors.append("causal flyer command refused at "+str(tick))
			break
		var prior: Dictionary = Base.state(body)
		var start: int = Time.get_ticks_usec()
		var snapshot: Dictionary = arena.step()
		var step_us: int = Time.get_ticks_usec()-start
		if snapshot.get("failed",false):
			errors.append("causal flyer owner refused at "+str(tick)+": "+str(snapshot.get("reason","")))
			break
		var observed: Dictionary = Base.state(body)
		var application: Dictionary = arena.session.bridge.gcr_application_diagnostics()
		var phase: Dictionary = arena.causal_phase.duplicate(true)
		var actuation: Dictionary = phase.actuation
		var diagnostics: Dictionary = world.gcr_diagnostics()
		var rig = arena.session._rigs[0]
		var controller: Dictionary = rig._player_controller.observation()
		controller.merge({"enabled":spec.drive!="unactuated","actual_impulse":actuation.actual_impulse,"actual_torque_impulse":actuation.actual_torque_impulse,
			"measured_controller_impulse":actuation.actual_impulse,"measured_controller_torque_impulse":actuation.actual_torque_impulse,
			"rig_reported_impulse":rig._last_impulse,"rig_reported_torque_impulse":rig._last_torque_impulse,"impulse_measurement":"direct-actuation-stage-backend-velocity-difference",
			"force_measurement":"controller-request","measurement_valid":true,"movement_limited":rig._movement_limited,"accepted_action":rig._action.duplicate(true)})
		var row: Dictionary = {"tick":tick,"position":observed.position,"rotation":observed.rotation,"velocity":observed.velocity,"omega":observed.omega,
			"command_active":driven,"drive_phase":"driven" if driven else "quiet" if tick<120 else "released","input_action":action,"controller":controller,
			"causal_phase":phase,"application":application,"application_step":Base.application_step(application,previous_snapshot,tick),
			"gcr":diagnostics.get("bodies",[{}])[0] if not diagnostics.get("bodies",[]).is_empty() else {},
			"pre_overlap":null,"material_count":null,"water":null,"conserved":null,"incoming_state":prior,
			"rest_receipt":arena.causal_rest_receipt.duplicate(true),"computed_result":Array(arena.causal_native_results),"step_us":step_us,
			"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}
		previous_snapshot=int(application.get("snapshot",-1))
		row.merge(Base.flyer_overlap(world,observed))
		row["hard_contact_count"]=Base.hard_contacts(body)
		if int(row.hard_contact_count)>0:
			row.hard_clearance=false
		if tick%60==0 or tick==1799:
			var census: Dictionary = Base.flyer_census(world)
			row["census"]=census
			row.material_count=census.counts[2]
			row.water=census.water_mass
			row.conserved=Base.same_quantity(expected,census)
			if not row.conserved:
				errors.append("causal flyer conservation at "+str(tick))
		report.rows.append(Base.portable(row))
		if not Vector2(observed.position).is_finite() or not Vector2(observed.velocity).is_finite() or not is_finite(float(observed.rotation)) or not is_finite(float(observed.omega)):
			errors.append("causal nonfinite body state")
		if not errors.is_empty():
			break
	report.after=Base.portable(Base.flyer_census(world))
	report.final_state=Base.state(body)
	if not Base.same_quantity(expected,report.after):
		errors.append("causal final material quantity")
	arena.close()
	arena.free()
	await process_frame

func capture_barrel(spec: Dictionary, report: Dictionary, registered: Dictionary) -> void:
	var fixture = Barrel.new()
	var configuration: Dictionary = registered.duplicate(true)
	configuration.merge({"material":2,"ticks":1800,"rest_mode":"control","base_budget":20.0},true)
	if not await fixture.setup(root,configuration,"GCR-REST"):
		errors.append("causal barrel setup: "+fixture.error)
		fixture.close()
		return
	report.configuration=configuration
	report.configuration["arm"]=spec.arm
	report.configuration["contact_gain"]=.025
	report.schedule="retained barrel drive-Rapier-sample-native-originalBridge-optionalPositionSetter; setter before following Rapier"
	report.before=Base.portable(fixture.observation())
	report.initial_state=Base.state(fixture.bodies[0])
	report.actual_mass=fixture.bodies[0].mass
	report.actual_inertia=PhysicsServer2D.body_get_param(fixture.bodies[0].get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	report.gravity=92.12
	report.runtime_identity=fixture.runtime_identity()
	var previous_snapshot: int = -1
	for tick: int in range(1800):
		var boundary_before: Dictionary = {"native_tick":int(fixture.world.get_tick_index()),"rapier_steps":fixture.bridge.manual_step_count(),
			"session_tick":fixture.tick,"packed_sample":fixture.bridge._sample_serial,"last_applied_sample":fixture.bridge._applied_sample_serials[0],
			"last_snapshot":fixture.bridge._last_result_snapshot_serial,"rig_tick":0}
		var captured: Array = fixture.step()
		if captured.size()!=1:
			errors.append("causal barrel step: "+fixture.error)
			break
		var source: Dictionary = captured[0]
		# Fixture rows are already JSON-portable (Vector2 values become arrays).
		# The experiment setter consumes the unchanged live copied bridge receipt.
		var application: Dictionary = fixture.bridge.gcr_application_diagnostics()
		var setter: Dictionary = CausalArena.correction_intervention(fixture.bridge,fixture.bodies[0],application,spec.arm,92.12)
		if not setter.accepted:
			errors.append("causal barrel setter refused")
			break
		var effective: Array = fixture.pose(0)
		var boundary_after: Dictionary = {"native_tick":int(fixture.world.get_tick_index()),"rapier_steps":fixture.bridge.manual_step_count(),
			"session_tick":fixture.tick,"packed_sample":fixture.bridge._sample_serial,"last_applied_sample":fixture.bridge._applied_sample_serials[0],
			"last_snapshot":fixture.bridge._last_result_snapshot_serial,"rig_tick":0}
		var fresh: bool = application.get("accepted",false) and application.bodies.size()==1 and int(application.bodies[0].age)==0 and int(application.bodies[0].sample)==int(boundary_after.packed_sample) and int(boundary_after.last_applied_sample)==int(boundary_after.packed_sample) and int(boundary_after.last_snapshot)==int(boundary_before.session_tick)+1 and int(boundary_after.last_applied_sample)!=int(boundary_before.last_applied_sample)
		var counts: Dictionary = {"actuation":0,"sample":(int(boundary_after.packed_sample)-int(boundary_before.packed_sample)+fixture.bridge.SAMPLE_SERIAL_LIMIT)%fixture.bridge.SAMPLE_SERIAL_LIMIT,
			"native_tick":int(boundary_after.native_tick)-int(boundary_before.native_tick),"rapier_step":int(boundary_after.rapier_steps)-int(boundary_before.rapier_steps),"response_calls":int(fresh)}
		if counts!={"actuation":0,"sample":1,"native_tick":1,"rapier_step":1,"response_calls":1} or int(boundary_after.session_tick)-int(boundary_before.session_tick)!=1:
			errors.append("causal barrel observed boundary counter mismatch")
			break
		var census: Dictionary = fixture.observation(true)
		var effective_overlap: int = fixture.overlap(census,effective)
		var row: Dictionary = {"tick":tick,"position":[effective[0],effective[1]],"rotation":effective[2],"velocity":[effective[3],effective[4]],"omega":effective[5],
			"command_active":false,"drive_phase":"quiet","input_action":{"drive":"passive","impulse_x":0.0},
			"controller":{"kind":"unactuated barrel","enabled":false,"applied_force":[0.0,0.0],"applied_torque":0.0,"actual_impulse":[0.0,0.0],"actual_torque_impulse":0.0},
			"application":application,"application_step":Base.application_step(application,previous_snapshot,tick),"gcr":source.gcr,
			"pre_overlap":source.pre_overlap,"post_overlap":source.post_overlap,"tick_overlap":source.tick_overlap,
			"post_overlap_phase":"original native post-ejection at sampled pose; original tick_overlap at bridge-delivered pose",
			"effective_overlap":effective_overlap,"effective_overlap_phase":"stored cell centres at actual pose after experiment setter",
			"material_count":source.material_count,"water":source.water,"conserved":source.conserved,"hard_clearance":fixture.rest_hard_clearance(),
			"hard_floor_contact":float(effective[1])+absf(cos(effective[2]))*fixture.body_size.y*.5+absf(sin(effective[2]))*fixture.body_size.x*.5>=fixture.floor_y-.5,
			"incoming_state":source["in"],"original_outgoing_state":source.out,"computed_result":source.computed_result,"result":source.result,
			"rest_receipt":source.rest_receipt,"times_us":source.times_us,"work":source.work,
			"vertical_depth":maxf(0.0,float(effective[1])+absf(cos(effective[2]))*fixture.body_size.y*.5+absf(sin(effective[2]))*fixture.body_size.x*.5-float(Barrel.SURFACE)),
			"original_vertical_depth":source.vertical_depth,
			"causal_phase":{"arm":spec.arm,"schedule":"retained barrel with post-response positional intervention",
				"actuation":{"count":0,"actual_impulse":Vector2.ZERO,"actual_torque_impulse":0.0},
				"counts":counts,"counter_before":boundary_before,"counter_after":boundary_after,"fresh_sample_applied":fresh,
				"observed_session_tick_delta":int(boundary_after.session_tick)-int(boundary_before.session_tick),"correction_setter":setter}}
		previous_snapshot=int(application.get("snapshot",-1))
		report.rows.append(Base.portable(row))
		if not source.conserved or not fixture.error.is_empty():
			errors.append("causal barrel quantity or owner failure: "+fixture.error)
			break
	report.after=Base.portable(fixture.observation())
	report.final_state=Base.state(fixture.bodies[0])
	fixture.close()
	await process_frame
