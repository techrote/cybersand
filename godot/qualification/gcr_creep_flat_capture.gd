extends SceneTree

# Separate preregistered premise control. No tall bank, no pose reset, no
# response-law intervention; the existing side jet remains free to rotate.
const Base = preload("res://qualification/gcr_creep_capture.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const REGISTRATION: String = "GCR-CREEP-FLAT-001-2026-11-03"
const POSITION := Vector2(296,312)
var errors: Array[String] = []

func _init() -> void:
	call_deferred("_run")

static func protocol_error(protocol: Dictionary) -> String:
	var common: Dictionary = {"registration":REGISTRATION,"pulse_start":120,"pulse_end":180,"drive_end":1200,"drive_fraction":.15,"effort":.7}
	for key: String in common:
		if not protocol.has(key) or not Base.metadata_equal(protocol[key],common[key]):
			return "protocol."+key+" differs from flat registration"
	var fixture: Dictionary = protocol.get("fixture_flyer",{})
	var expected: Dictionary = {"fleet_index":2,"position":[296,312],"angle":0.0,"region":[128,128,512,384],
		"base":[129,320,510,191],"bank":null,"border_material":1,"gravity":38,"mass":.1,"inertia":.975,
		"mass_multiplier":1,"inertia_multiplier":1,"thrust_multiplier":1,"torque_multiplier":1,"census_interval":60,"fire":false,"dispensers":false}
	for key: String in expected:
		if not fixture.has(key) or not Base.metadata_equal(fixture[key],expected[key]):
			return "protocol.fixture_flyer."+key+" differs from flat registration"
	return ""

static func options(unactuated: bool) -> Dictionary:
	return {"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,
		"thrust_multiplier":0.0 if unactuated else 1.0,"torque_multiplier":0.0 if unactuated else 1.0}

static func configuration() -> Dictionary:
	return {"version":Arena.VERSION,"seed":0,"max_ticks":1801,"local_patch_radius":0,
		"course":"manoeuvre","actors":[{"model":"arcadelander","producer":"human","position":POSITION}]}

static func author_room(arena) -> Dictionary:
	var bridge: CyberRapierPhysicsBridge = arena.session.bridge
	var world: Object = arena._world
	var body: RigidBody2D = arena.session.bodies()[0]
	var before: Dictionary = Base.state(body)
	var result: Dictionary = {"accepted":false,"method":"material authoring only; constructor pose and primed native/bridge sample retained",
		"session_before":bridge._gcr_session_id,"sample_before":bridge._sample_serial,"native_tick_before":world.get_tick_index()}
	var rectangles: Array = [[Vector2i(128,128),Vector2i(512,384),0],
		[Vector2i(128,128),Vector2i(512,1),1],[Vector2i(128,511),Vector2i(512,1),1],
		[Vector2i(128,128),Vector2i(1,384),1],[Vector2i(639,128),Vector2i(1,384),1],
		[Vector2i(129,320),Vector2i(510,191),2]]
	for rectangle: Array in rectangles:
		if not world.diagnostic_fill_rect(rectangle[0],rectangle[1],rectangle[2]):
			result["error"]="flat native material authoring refused"
			return result
	var after: Dictionary = Base.state(body)
	result["session_after"]=bridge._gcr_session_id
	result["sample_after"]=bridge._sample_serial
	result["native_tick_after"]=world.get_tick_index()
	result["pose_unchanged"]=before==after
	result["position"]=after.position
	result["rotation"]=after.rotation
	result["census"]=Base.flyer_census(world)
	result["accepted"]=result.session_before==result.session_after and result.sample_before==result.sample_after and int(result.native_tick_before)==0 and int(result.native_tick_after)==0 and result.pose_unchanged and Vector2(after.position)==POSITION and absf(float(after.rotation))<=1e-12 and int(result.census.counts[2])==97410 and int(result.census.counts[1])==1788 and int(result.census.water_mass)==0
	if not result.accepted:
		result["error"]="flat constructor/sample/geometry witness refused"
	return result

static func measure_controller_delivery(application: Dictionary, rest_receipt: Dictionary) -> Dictionary:
	var result: Dictionary = {"measured":false,"impulse":null,"torque_impulse":null,
		"method":"same-phase-backend-velocity-difference",
		"scope":"single-hull rig actuation between native sampling and main response; includes rig safety impulses when movement_limited"}
	var applied: Array = application.get("bodies",[])
	var sampled: Array = rest_receipt.get("bodies",[])
	if not application.get("accepted",false) or applied.size()!=1 or sampled.size()!=1:
		return result
	var actual: Dictionary = applied[0]
	var initial: Dictionary = sampled[0]
	if int(actual.get("age",-1))!=0 or int(actual.get("sample",-1))!=int(initial.get("sample",-2)) or int(actual.get("session",-1))!=int(initial.get("session",-2)):
		return result
	if not actual.get("velocity_before_correction") is Vector2 or not initial.get("sample_velocity") is Vector2:
		return result
	if not actual.has("omega_before_correction") or not initial.has("sample_omega") or not actual.has("actual_mass") or not actual.has("actual_inertia"):
		return result
	var mass: float = float(actual.actual_mass)
	var inertia: float = float(actual.actual_inertia)
	var impulse: Vector2 = (Vector2(actual.velocity_before_correction)-Vector2(initial.sample_velocity))*mass
	var torque: float = (float(actual.omega_before_correction)-float(initial.sample_omega))*inertia
	if not impulse.is_finite() or not is_finite(torque) or mass<=0.0 or inertia<=0.0:
		return result
	result.merge({"measured":true,"impulse":impulse,"torque_impulse":torque,"sample":actual.sample,"session":actual.session,
		"sample_velocity":initial.sample_velocity,"sample_omega":initial.sample_omega,
		"velocity_before_correction":actual.velocity_before_correction,"omega_before_correction":actual.omega_before_correction,
		"actual_mass":mass,"actual_inertia":inertia},true)
	return result

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:
			arguments[pair[0]]=pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(arguments.get("protocol",""))))
	if not protocol is Dictionary or not protocol_error(protocol).is_empty():
		push_error("Flat protocol refused: "+protocol_error(protocol) if protocol is Dictionary else "Flat protocol is not an object")
		quit(1)
		return
	var spec: Dictionary = {}
	for entry: Dictionary in protocol.cases:
		if entry.id==arguments.get("case",""):
			spec=entry
	if spec.is_empty() or spec.get("kind","")!="flyer" or spec.get("material")!=2 or spec.get("ticks")!=1800 or spec.get("drive","") not in ["coast","unactuated","pulse","sustained"]:
		push_error("Flat case refused")
		quit(1)
		return
	var report: Dictionary = {"schema":1,"registration":REGISTRATION,"case":spec,"platform":OS.get_name(),"dt":1.0/60.0,
		"rows":[],"errors":[],"ok":false,"outcome":"CAPTURED",
		"scope":"Flat-bed premise control; unchanged GCR-LA, actual side-jet controls and free rotation; no sleep or response-law intervention",
		"identity":{"source":OS.get_environment("GCR_CREEP_SOURCE"),"input_identity":OS.get_environment("GCR_CREEP_INPUT_IDENTITY"),
			"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine_version":Engine.get_version_info().string,
			"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"protocol_sha256":FileAccess.get_sha256(str(arguments.protocol)),
			"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")}}
	await capture(spec,report)
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==1800
	var file := FileAccess.open(str(arguments.get("output","")),FileAccess.WRITE)
	if file==null:
		push_error("Flat output refused")
		quit(1)
		return
	file.store_string(JSON.stringify(Base.portable(report)))
	file.close()
	print("GCR_CREEP_FLAT_CAPTURE ",JSON.stringify({"case":spec.id,"ok":report.ok,"rows":report.rows.size(),"errors":errors}))
	quit(0 if report.ok else 1)

func capture(spec: Dictionary, report: Dictionary) -> void:
	var arena = Arena.new()
	root.add_child(arena)
	await process_frame
	var controls: Dictionary = options(spec.drive=="unactuated")
	if not arena.configure_review_fleet(configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,controls):
		errors.append("flat configure: "+arena.last_error)
		arena.free()
		return
	var world: Object = arena._world
	var body: RigidBody2D = arena.session.bodies()[0]
	report["initial_authoring"]=author_room(arena)
	if not report.initial_authoring.accepted:
		errors.append(str(report.initial_authoring.get("error","flat authoring refused")))
		arena.close()
		arena.free()
		return
	report.configuration={"controls":controls,"fleet_index":2,"fleet_name":"Kestrel","room":[128,128,512,384],
		"base":[129,320,510,191],"bank":null,"initial_position":POSITION,"initial_angle":0.0,"material":2,
		"drive_fraction":.15,"effort":.7,"census_cadence":60,"drive_axis":"existing body-local Q/E side-thruster through action.trim"}
	report.schedule=Arena.SCHEDULE
	report.actual_mass=body.mass
	report.actual_inertia=PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	report.gravity=38.0
	report.runtime_identity={"native_candidate":"GCR-REST","admission_variant":world.get_gcr_admission_variant(),"rest_mode":"control","base_budget":20.0}
	if str(report.runtime_identity.admission_variant)!="A1" or not is_equal_approx(float(report.actual_mass),.1) or not is_equal_approx(float(report.actual_inertia),.975):
		errors.append("flat native identity/mass/inertia refused")
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
			errors.append("flat command refused at "+str(tick))
			break
		var prior: Dictionary = Base.state(body)
		var started: int = Time.get_ticks_usec()
		var snapshot: Dictionary = arena.step()
		var step_us: int = Time.get_ticks_usec()-started
		if snapshot.get("failed",false):
			errors.append("flat owner step "+str(tick)+": "+str(snapshot.get("reason","")))
			break
		var observed: Dictionary = Base.state(body)
		var application: Dictionary = arena.session.bridge.gcr_application_diagnostics()
		var receipt: Dictionary = world.gcr_rest_receipt()
		var delivery: Dictionary = measure_controller_delivery(application,receipt)
		var diagnostics: Dictionary = world.gcr_diagnostics()
		var rig = arena.session._rigs[0]
		var controller: Dictionary = rig._player_controller.observation()
		controller.merge({"enabled":spec.drive!="unactuated","actual_impulse":delivery.impulse,"actual_torque_impulse":delivery.torque_impulse,
			"measured_controller_impulse":delivery.impulse,"measured_controller_torque_impulse":delivery.torque_impulse,
			"rig_reported_impulse":rig._last_impulse,"rig_reported_torque_impulse":rig._last_torque_impulse,
			"impulse_measurement":delivery.method,"force_measurement":"controller-request","measurement_valid":delivery.measured,
			"movement_limited":rig._movement_limited,"accepted_action":rig._action.duplicate(true)})
		var row: Dictionary = {"tick":tick,"position":observed.position,"rotation":observed.rotation,"velocity":observed.velocity,"omega":observed.omega,
			"command_active":driven,"drive_phase":"driven" if driven else "quiet" if tick<120 else "released",
			"input_action":action,"controller":controller,"controller_delivery":delivery,"application":application,
			"application_step":Base.application_step(application,previous_snapshot,tick),
			"gcr":diagnostics.get("bodies",[{}])[0] if not diagnostics.get("bodies",[]).is_empty() else {},
			"pre_overlap":null,"material_count":null,"water":null,"conserved":null,"incoming_state":prior,
			"rest_receipt":receipt,"step_us":step_us,"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}
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
				errors.append("flat quantity conservation at "+str(tick))
		report.rows.append(Base.portable(row))
		if not delivery.measured:
			errors.append("flat same-phase controller delivery unavailable at "+str(tick))
		if not Vector2(observed.position).is_finite() or not Vector2(observed.velocity).is_finite() or not is_finite(float(observed.rotation)) or not is_finite(float(observed.omega)):
			errors.append("flat nonfinite physical state")
		if not errors.is_empty():
			break
	report.after=Base.portable(Base.flyer_census(world))
	report.final_state=Base.state(body)
	if not Base.same_quantity(expected,report.after):
		errors.append("flat final conservation")
	arena.close()
	arena.free()
	await process_frame
