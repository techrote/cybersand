extends SceneTree

# Experiment-owned event-channel intervention. The native diagnostic contact
# option is applied during fresh construction, before material authoring/ticks.
# Existing native accumulation and the passive solver remain their sole owners.
const Base = preload("res://qualification/gcr_creep_capture.gd")
const Flat = preload("res://qualification/gcr_creep_flat_capture.gd")
const CausalArena = preload("res://qualification/gcr_causal_arena.gd")
const Barrel = preload("res://tests/support/y1_envelope_fixture.gd")
const REGISTRATION := "GCR-CAUSAL-EVENT-001-2026-11-03"
var errors: Array[String] = []

static func zero_vector(value: Variant) -> bool:
	return value==Vector2.ZERO if value is Vector2 else value is Array and value.size()==2 and value[0]==0 and value[1]==0

func _init(auto_run: bool = true) -> void:
	if auto_run:
		call_deferred("_run")

static func native_options(gain: float, gravity: float, telemetry: bool) -> Dictionary:
	return {"workers":1,"telemetry":telemetry,"bearing_candidate":"GCR-REST",
		"bearing_experiment":"GCR-REST-001-2026-11-02","gcr_rest_mode":"control",
		"gcr_base_budget":20.0,"gcr_rest_gravity":gravity,"contact":gain}

static func calibration(gain: float) -> Dictionary:
	var out: Dictionary = {"ok":false,"gain_requested":gain,"errors":[],
		"method":"effective event gain from native blocked-attempt counter delta; no Rapier step"}
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if world==null or not world.diagnostic_reset(native_options(gain,38.0,true)):
		out.errors.append("fresh calibration reset refused")
		return out
	# Translate the retained native blocked-grain regression into this domain.
	world.diagnostic_fill_rect(Vector2i(128,127),Vector2i.ONE,2)
	world.diagnostic_fill_rect(Vector2i(127,127),Vector2i.ONE,1)
	world.diagnostic_fill_rect(Vector2i(129,127),Vector2i.ONE,1)
	var states := PackedFloat64Array([1,128.5,128.5,0,3,1,0,0,0,.1,1,.975,128.5,128.5,.8,1.0/60.0,1])
	if not world.prepare_gcr_coupling(states,false):
		out.errors.append("calibration mask refused")
		return out
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(126,126),Vector2i(5,5),false,false)
	out["native_hash_before"]=world.get_physical_state_hash()
	out["counter_before"]=world.get_rigid_body_contacts_last_tick()
	out["tick_ok"]=world.simulation_tick()
	out["counter_after"]=world.get_rigid_body_contacts_last_tick()
	out["native_blocked_contacts"]=int(out.counter_after)-int(out.counter_before)
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(126,126),Vector2i(5,5),false,false)
	var results: PackedFloat64Array = world.gcr_body_results()
	var diagnostic: Dictionary = world.gcr_diagnostics()
	var body: Dictionary = diagnostic.get("bodies",[{}])[0] if diagnostic.get("bodies",[]).size()==1 else {}
	out["native_hash_after"]=world.get_physical_state_hash()
	out["native_hash_version"]=world.get_physical_state_hash_version()
	out["moves"]=world.get_moves_last_tick()
	out["material_cells_unchanged"]=before.get("cells")==after.get("cells")
	out["counts_before"]=before.get("counts",[])
	out["counts_after"]=after.get("counts",[])
	out["water_before"]=before.get("water_mass",-1)
	out["water_after"]=after.get("water_mass",-1)
	out["computed_result"]=results
	out["gcr"]=body
	var n: int = int(out.native_blocked_contacts)
	if n>0 and body.get("event_raw") is Vector2:
		out["effective_gain"]=float(body.event_raw.y)*1000.0/(float(n)*1600.0)
	else:
		out["effective_gain"]=null
	if not out.tick_ok or n<=0 or out.moves!=0 or not out.material_cells_unchanged or out.counts_before!=out.counts_after or out.water_before!=0 or out.water_after!=0:
		out.errors.append("calibration native contact/material premise failed")
	if body.is_empty() or int(body.get("nodes",-1))!=0 or body.get("legacy_non_granular",Vector2.ONE)!=Vector2.ZERO or not is_equal_approx(float(body.get("event_scale",-1)),1.0):
		out.errors.append("calibration isolated event premise failed")
	if out.effective_gain==null or absf(float(out.effective_gain)-gain)>1e-7:
		out.errors.append("effective gain disagrees with construction")
	out.ok=out.errors.is_empty()
	return out

static func reconstruct_flyer(arena, gain: float) -> Dictionary:
	var world: Object = arena._world
	var bridge = arena.session.bridge
	var body: RigidBody2D = arena.session.bodies()[0]
	var out: Dictionary = {"accepted":false,"requested_options":native_options(gain,38.0,false),
		"body_before":Base.state(body),"session_before":bridge._gcr_session_id,"sample_before":bridge._sample_serial,
		"native_tick_before":world.get_tick_index(),"hard_revision_before":world.get_hard_surface_revision(),
		"terrain_revision_before":arena._terrain_revision}
	if int(out.native_tick_before)!=0 or not world.diagnostic_reset(out.requested_options):
		out["error"]="event fresh native reconstruction refused"
		return out
	world.set_simulation_window_enabled(false)
	world.set_cadence_lod_enabled(false)
	# The old constructor primes the upright hull before painting. Retain that
	# occupancy so the bank's original six excluded cells remain part of setup.
	var states: PackedFloat64Array = bridge.pack_gcr_body_states()
	out["upright_prime"]=states.size()==17 and world.prepare_gcr_coupling(states,false)
	out["body_after"]=Base.state(body)
	out["session_after"]=bridge._gcr_session_id
	out["sample_after"]=bridge._sample_serial
	out["native_tick_after"]=world.get_tick_index()
	out["native_admission"]=world.get_gcr_admission_variant()
	out["simulation_window_enabled"]=world.get_simulation_window_enabled()
	out["cadence_lod_enabled"]=world.get_cadence_lod_enabled()
	out.accepted=out.upright_prime and out.body_before==out.body_after and out.session_before==out.session_after and int(out.sample_after)==int(out.sample_before)+1 and int(out.native_tick_after)==0 and str(out.native_admission)=="A1" and not out.simulation_window_enabled and not out.cadence_lod_enabled
	if not out.accepted:
		out["error"]="event fresh reconstruction altered body/session or failed prime"
	return out

static func author_flyer_room(arena, geometry: String, material: int) -> Dictionary:
	var world: Object = arena._world
	var rectangles: Array = [[Vector2i(128,128),Vector2i(512,384),0],
		[Vector2i(128,128),Vector2i(512,1),1],[Vector2i(128,511),Vector2i(512,1),1],
		[Vector2i(128,128),Vector2i(1,384),1],[Vector2i(639,128),Vector2i(1,384),1],
		[Vector2i(129,320),Vector2i(510,191),material]]
	if geometry=="bank":
		rectangles.append([Vector2i(300,192),Vector2i(339,128),material])
	for rectangle: Array in rectangles:
		if not world.diagnostic_fill_rect(rectangle[0],rectangle[1],rectangle[2]):
			return {"accepted":false,"error":"event room authoring refused"}
	var pose: Dictionary = Base.author_flyer_initial_pose(arena) if geometry=="bank" else {"accepted":true,"method":"constructor angle0 retained"}
	var census: Dictionary = Base.flyer_census(world)
	var expected: int = 140796 if geometry=="bank" else 97410
	pose["material_cells"]=census.counts[material]
	pose["expected_material_cells"]=expected
	pose["hard_cells"]=census.counts[1]
	pose["native_tick"]=world.get_tick_index()
	pose["hard_revision"]=world.get_hard_surface_revision()
	pose["native_physical_hash"]=world.get_physical_state_hash()
	pose.accepted=pose.get("accepted",false) and int(pose.material_cells)==expected and int(pose.hard_cells)==1788 and int(pose.native_tick)==0
	if not pose.accepted:
		pose["error"]="event authored material/mask/pose premise failed"
	return pose

static func row_controller(rig, phase: Dictionary) -> Dictionary:
	var actuation: Dictionary = phase.get("actuation",{})
	var controller: Dictionary = rig._player_controller.observation()
	controller.merge({"enabled":false,"actual_impulse":actuation.get("actual_impulse"),
		"actual_torque_impulse":actuation.get("actual_torque_impulse"),
		"measured_controller_impulse":actuation.get("actual_impulse"),"measured_controller_torque_impulse":actuation.get("actual_torque_impulse"),
		"rig_reported_impulse":rig._last_impulse,"rig_reported_torque_impulse":rig._last_torque_impulse,
		"impulse_measurement":"direct-actuation-stage-backend-velocity-difference","force_measurement":"controller-request",
		"measurement_valid":actuation.get("count",0)==1,"movement_limited":rig._movement_limited,"accepted_action":rig._action.duplicate(true)},true)
	return controller

static func report_identity(protocol_path: String) -> Dictionary:
	return {"source":OS.get_environment("GCR_CAUSAL_SOURCE"),"input_identity":OS.get_environment("GCR_CAUSAL_INPUT_IDENTITY"),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine_version":Engine.get_version_info().string,
		"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"protocol_sha256":FileAccess.get_sha256(protocol_path)}

static func protocol_valid(protocol: Dictionary, spec: Dictionary) -> bool:
	return protocol.get("registration","")==REGISTRATION and protocol.get("cases",[]).size()==8 and int(spec.get("ticks",0))==1800 and str(spec.get("arm","")) in ["C","E0"] and Base.metadata_equal(spec.get("contact_gain"),.025 if spec.arm=="C" else 0.0) and str(spec.get("geometry","")) in ["bank","flat","barrel-high"] and int(spec.get("material",-1)) in [2,23] and str(spec.get("drive","")) in ["unactuated","passive"]

func _run() -> void:
	var arguments: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:
			arguments[pair[0]]=pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(arguments.get("protocol",""))))
	var spec: Dictionary = {}
	if protocol is Dictionary:
		for entry: Dictionary in protocol.get("cases",[]):
			if entry.id==arguments.get("case",""):
				spec=entry
	if not protocol is Dictionary or spec.is_empty() or not protocol_valid(protocol,spec):
		push_error("Event causal protocol/case refused")
		quit(1)
		return
	var report: Dictionary = {"schema":1,"registration":REGISTRATION,"case":spec,"platform":OS.get_name(),"dt":1.0/60.0,
		"identity":report_identity(str(arguments.protocol)),"rows":[],"errors":[],"ok":false,
		"scope":"Fresh-construction blocked-event response removal; native cells/attempts and existing passive solve remain authoritative",
		"event_gain_requested":spec.contact_gain,"pipeline_arm":"C","response_arm":spec.arm}
	if spec.kind=="flyer":
		await capture_flyer(spec,report)
	else:
		await capture_barrel(spec,report,protocol.fixture_barrel_high)
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==int(spec.ticks)
	var output := FileAccess.open(str(arguments.get("output","")),FileAccess.WRITE)
	if output==null:
		push_error("Event causal output refused")
		quit(1)
		return
	output.store_string(JSON.stringify(Base.portable(report)))
	output.close()
	print("GCR_EVENT_CAPTURE ",JSON.stringify({"case":spec.id,"ok":report.ok,"rows":report.rows.size(),"errors":errors}))
	quit(0 if report.ok else 1)

func capture_flyer(spec: Dictionary, report: Dictionary) -> void:
	var arena = CausalArena.new()
	root.add_child(arena)
	await process_frame
	if not arena.set_causal_arm("C") or not arena.configure_review_fleet(Flat.configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,Flat.options(true)):
		errors.append("event flyer configuration refused: "+arena.last_error)
		arena.free()
		return
	var world: Object = arena._world
	var body: RigidBody2D = arena.session.bodies()[0]
	report["native_reconstruction"]=reconstruct_flyer(arena,float(spec.contact_gain))
	report["initial_authoring"]=author_flyer_room(arena,str(spec.geometry),int(spec.material)) if report.native_reconstruction.accepted else {"accepted":false}
	if not report.native_reconstruction.accepted or not report.initial_authoring.accepted:
		errors.append("event flyer reconstruction/authoring refused")
		arena.close()
		arena.free()
		return
	report.configuration={"controls":Flat.options(true),"geometry":spec.geometry,"room":[128,128,512,384],"base":[129,320,510,191],
		"bank":[300,192,339,128] if spec.geometry=="bank" else null,"initial_angle":PI/2.0 if spec.geometry=="bank" else 0.0,
		"census_cadence":60,"contact_gain_requested":spec.contact_gain}
	report.actual_mass=body.mass
	report.actual_inertia=PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	report.gravity=38.0
	report.schedule="Retained C pipeline; event gain set during symmetric fresh reconstruction before authoring"
	report.runtime_identity={"native_candidate":"GCR-REST","admission_variant":world.get_gcr_admission_variant(),"rest_mode":"control","base_budget":20.0}
	var expected: Dictionary = Base.flyer_census(world)
	report.before=Base.portable(expected)
	report.initial_state=Base.state(body)
	report.initial_native_hash=world.get_physical_state_hash()
	var previous_snapshot: int = -1
	for tick: int in range(1800):
		var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
		var view: Dictionary = arena.observation(0)
		if not arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"):
			errors.append("event neutral command refused at "+str(tick))
			break
		var prior: Dictionary = Base.state(body)
		var snapshot: Dictionary = arena.step()
		if snapshot.get("failed",false):
			errors.append("event flyer owner step: "+str(snapshot.get("reason","")))
			break
		var observed: Dictionary = Base.state(body)
		var application: Dictionary = arena.session.bridge.gcr_application_diagnostics()
		var receipt: Dictionary = arena.causal_rest_receipt
		var diagnostics: Dictionary = world.gcr_diagnostics()
		var gcr: Dictionary = diagnostics.get("bodies",[{}])[0] if diagnostics.get("bodies",[]).size()==1 else {}
		var phase: Dictionary = arena.causal_phase.duplicate(true)
		var rig = arena.session._rigs[0]
		var row: Dictionary = {"tick":tick,"position":observed.position,"rotation":observed.rotation,"velocity":observed.velocity,"omega":observed.omega,
			"command_active":false,"drive_phase":"quiet" if tick<120 else "released","input_action":action,
			"controller":row_controller(rig,phase),"application":application,"application_step":Base.application_step(application,previous_snapshot,tick),
			"causal_phase":phase,"response_arm":spec.arm,"gcr":gcr,"rest_receipt":receipt,"pre_overlap":null,
			"material_count":null,"water":null,"conserved":null,"incoming_state":prior,
			"event_channel":{"gain_requested":spec.contact_gain,"native_counter_before":phase.get("native_contact_counter_before"),
				"native_counter_after":phase.get("native_contact_counter_after"),"native_blocked_contacts":int(phase.get("native_contact_counter_after",0))-int(phase.get("native_contact_counter_before",0)),
				"counter_scope":"after-minus-before the native tick; preparation has reset native contact observations"},
			"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()]}
		previous_snapshot=int(application.get("snapshot",-1))
		row.merge(Base.flyer_overlap(world,observed))
		row["hard_contact_count"]=Base.hard_contacts(body)
		if int(row.hard_contact_count)>0:
			row.hard_clearance=false
		if tick%60==0 or tick==1799:
			var census: Dictionary = Base.flyer_census(world)
			row.census=census
			row.material_count=census.counts[int(spec.material)]
			row.water=census.water_mass
			row.conserved=Base.same_quantity(expected,census)
			if not row.conserved:
				errors.append("event flyer quantity conservation at "+str(tick))
		if not application.get("accepted",false) or gcr.get("legacy_non_granular",Vector2.ONE)!=Vector2.ZERO:
			errors.append("event flyer delivery/legacy isolation at "+str(tick))
		report.rows.append(Base.portable(row))
		if not errors.is_empty():
			break
	report.after=Base.portable(Base.flyer_census(world))
	report.final_state=Base.state(body)
	report.terrain_after={"native_hard_revision":world.get_hard_surface_revision(),"consumed_hard_revision":arena._terrain_revision,
		"tick":world.get_tick_index()}
	arena.close()
	arena.free()
	await process_frame

func capture_barrel(spec: Dictionary, report: Dictionary, fixture_spec: Dictionary, tick_count: int = 1800, host_root: Node = null) -> void:
	var fixture = Barrel.new()
	var configuration: Dictionary = fixture_spec.duplicate(true)
	configuration.merge({"material":2,"ticks":1800,"rest_mode":"control","base_budget":20.0},true)
	if not await fixture.setup(root if host_root==null else host_root,configuration,"GCR-REST"):
		errors.append("event barrel initial setup: "+fixture.error)
		fixture.close()
		return
	var body: RigidBody2D = fixture.bodies[0]
	var before_body: Dictionary = Base.state(body)
	var options: Dictionary = native_options(float(spec.contact_gain),92.12,true)
	var rebuilt: bool = fixture.world.get_tick_index()==0 and fixture.world.diagnostic_reset(options)
	if rebuilt:
		fixture.world.set_simulation_window(Vector2i(fixture.left-4,0),Vector2i(fixture.width+8,fixture.floor_y+4),0,0)
		fixture.fill(fixture.left-1,0,1,fixture.floor_y+1,1)
		fixture.fill(fixture.left+fixture.width,0,1,fixture.floor_y+1,1)
		fixture.fill(fixture.left-1,fixture.floor_y,fixture.width+2,1,1)
		fixture.fill(fixture.left-1,0,fixture.width+2,1,1)
		fixture.fill(fixture.left,192,fixture.width,int(configuration.depth),2)
		fixture.expected=fixture.observation()
		fixture.bridge.rebuild_hard_surface_colliders_from_rectangles(fixture.world.get_hard_surface_rectangles())
	var after_body: Dictionary = Base.state(body)
	report.native_reconstruction={"accepted":rebuilt and fixture.error.is_empty() and before_body==after_body and fixture.world.get_tick_index()==0,
		"requested_options":options,"body_before":before_body,"body_after":after_body,"native_tick_after":fixture.world.get_tick_index(),
		"hard_revision_after":fixture.world.get_hard_surface_revision(),"terrain_rebuilt":rebuilt}
	if not report.native_reconstruction.accepted:
		errors.append("event barrel fresh reconstruction/reauthoring refused")
		fixture.close()
		return
	report.configuration=configuration
	report.schedule="Retained barrel: no pilot actuation, Rapier, sample, native tick, existing bridge correction/zeroing/wrench"
	report.actual_mass=body.mass
	report.actual_inertia=PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	report.gravity=92.12
	report.runtime_identity=fixture.runtime_identity()
	report.before=Base.portable(fixture.observation())
	report.initial_state=Base.state(body)
	report.initial_native_hash=fixture.world.get_physical_state_hash()
	var previous_snapshot: int = -1
	for tick: int in range(tick_count):
		var counter_before: Dictionary = {"native_tick":int(fixture.world.get_tick_index()),"rapier_steps":fixture.bridge.manual_step_count(),
			"session_tick":fixture.tick,"packed_sample":fixture.bridge._sample_serial,"last_applied_sample":fixture.bridge._applied_sample_serials[0],
			"last_snapshot":fixture.bridge._last_result_snapshot_serial,"rig_tick":0}
		var captured: Array = fixture.step()
		if captured.size()!=1:
			errors.append("event barrel step: "+fixture.error)
			break
		var source: Dictionary = captured[0]
		var pose: Array = source.out
		var application: Dictionary = source.application
		var counter_after: Dictionary = {"native_tick":int(fixture.world.get_tick_index()),"rapier_steps":fixture.bridge.manual_step_count(),
			"session_tick":fixture.tick,"packed_sample":fixture.bridge._sample_serial,"last_applied_sample":fixture.bridge._applied_sample_serials[0],
			"last_snapshot":fixture.bridge._last_result_snapshot_serial,"rig_tick":0}
		var fresh: bool = application.get("accepted",false) and application.get("bodies",[]).size()==1 and int(application.bodies[0].get("age",-1))==0 and int(application.bodies[0].sample)==int(counter_after.packed_sample) and int(counter_after.last_applied_sample)!=int(counter_before.last_applied_sample) and int(counter_after.last_applied_sample)==int(application.bodies[0].sample) and int(counter_after.last_snapshot)==int(application.snapshot) and int(counter_after.last_snapshot)==int(counter_before.session_tick)+1
		var counts: Dictionary = {"actuation":0,"sample":(int(counter_after.packed_sample)-int(counter_before.packed_sample)+fixture.bridge.SAMPLE_SERIAL_LIMIT)%fixture.bridge.SAMPLE_SERIAL_LIMIT,
			"native_tick":int(counter_after.native_tick)-int(counter_before.native_tick),"rapier_step":int(counter_after.rapier_steps)-int(counter_before.rapier_steps),"response_calls":int(fresh)}
		if counts!={"actuation":0,"sample":1,"native_tick":1,"rapier_step":1,"response_calls":1} or int(counter_after.session_tick)-int(counter_before.session_tick)!=1:
			errors.append("event barrel observed boundary counter mismatch at "+str(tick))
			break
		var row: Dictionary = {"tick":tick,"position":[pose[0],pose[1]],"rotation":pose[2],"velocity":[pose[3],pose[4]],"omega":pose[5],
			"command_active":false,"drive_phase":"quiet" if tick<120 else "released","input_action":{"drive":"passive","drive_active":false,"impulse_x":0.0},
			"controller":{"kind":"unactuated retained barrel","enabled":false,"applied_force":Vector2.ZERO,"applied_torque":0.0,
				"actual_impulse":Vector2.ZERO,"actual_torque_impulse":0.0,"impulse_measurement":"no pilot actuator in registered barrel"},
			"application":application,"application_step":Base.application_step(application,previous_snapshot,tick),
			"causal_phase":{"arm":"C","actuation":{"count":0,"actual_impulse":Vector2.ZERO,"actual_torque_impulse":0.0},
				"counts":counts,
				"counter_before":counter_before,"counter_after":counter_after,"fresh_sample_applied":fresh,
				"observed_session_tick_delta":int(counter_after.session_tick)-int(counter_before.session_tick)},
			"response_arm":spec.arm,"gcr":source.gcr,"rest_receipt":source.rest_receipt,
			"pre_overlap":source.pre_overlap,"post_overlap":source.post_overlap,"tick_overlap":source.tick_overlap,
			"effective_overlap":source.tick_overlap,"effective_overlap_phase":"retained post-material/post-bridge pose; no cancellation",
			"material_count":source.material_count,"water":source.water,"conserved":source.conserved,
			"hard_floor_contact":source.hard_floor_contact,"hard_clearance":fixture.rest_hard_clearance(),
			"incoming_state":source["in"],"computed_result":source.computed_result,"result":source.result,"vertical_depth":source.vertical_depth,
			"event_channel":{"gain_requested":spec.contact_gain,"native_blocked_contacts":null,
				"aggregate_contacts":fixture.world.get_rigid_body_contacts_last_tick(),"counter_scope":"aggregate adapter plus native contacts; pure native tick delta unavailable in retained barrel helper"},
			"times_us":source.times_us,"work":source.work}
		previous_snapshot=int(application.get("snapshot",-1))
		report.rows.append(Base.portable(row))
		if not source.conserved or not zero_vector(source.gcr.get("legacy_non_granular")):
			errors.append("event barrel conservation/legacy isolation at "+str(tick))
			break
	report.after=Base.portable(fixture.observation())
	report.final_state=Base.state(body)
	fixture.close()
	if host_root==null:
		await process_frame
	else:
		await host_root.get_tree().process_frame
