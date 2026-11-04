extends SceneTree

const Base = preload("res://qualification/gcr_creep_capture.gd")
const Flat = preload("res://qualification/gcr_creep_flat_capture.gd")
const OldEvent = preload("res://qualification/gcr_event_capture.gd")
const Arena = preload("res://qualification/gcr_causal_arena.gd")
const Barrel = preload("res://tests/support/y1_envelope_fixture.gd")
const REGISTRATION := "GCR-EVT-001-2026-11-04"
var errors: Array[String] = []

func _init() -> void: call_deferred("_run")

static func options(off: bool, gravity: float) -> Dictionary:
	var value: Dictionary = OldEvent.native_options(.025,gravity,true)
	value.merge({"gcr_granular_events":"off" if off else "control","gcr_event_experiment":REGISTRATION},true)
	return value

func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not protocol is Dictionary or protocol.get("registration")!=REGISTRATION or protocol.get("cases",[]).size()!=12:
		push_error("Granular events protocol refused"); quit(1); return
	var spec: Dictionary = {}
	for item: Dictionary in protocol.cases:
		if item.id==args.get("case",""): spec=item.duplicate(true)
	var arm: String = str(args.get("arm",""))
	if spec.is_empty() or arm not in ["C","E"]:
		push_error("Granular events case/arm refused"); quit(1); return
	var identity: Dictionary = OldEvent.report_identity(str(args.protocol))
	identity.source=OS.get_environment("GCR_EVENT_SOURCE")
	identity.input_identity=OS.get_environment("GCR_EVENT_INPUT_IDENTITY")
	var report: Dictionary = {"schema":1,"registration":REGISTRATION,"case":spec,"arm":arm,"identity":identity,
		"platform":OS.get_name(),"dt":1.0/60.0,"rows":[],"errors":[],"selector":"off" if arm=="E" else "control"}
	if spec.kind=="flyer": await flyer(spec,arm,report)
	else: await barrel(spec,arm,report)
	report.errors=errors
	report.ok=errors.is_empty() and report.rows.size()==1800
	var output := FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if output==null: push_error("Output refused"); quit(1); return
	output.store_string(JSON.stringify(Base.portable(report)))
	output.close()
	print("GCR_GRANULAR_EVENTS ",JSON.stringify({"case":spec.id,"arm":arm,"rows":report.rows.size(),"ok":report.ok,"errors":errors}))
	quit(0 if report.ok else 1)

func selector_valid(world: Object, arm: String) -> bool:
	var d: Dictionary = world.gcr_diagnostics()
	return d.get("granular_events")==("off" if arm=="E" else "control") and absf(float(d.get("legacy_contact_gain",-1))-.025)<1e-12

func barrel(spec: Dictionary, arm: String, report: Dictionary) -> void:
	var fixture = Barrel.new()
	var config: Dictionary = spec.configuration.duplicate(true)
	config.merge({"material":spec.material,"ticks":1800},true)
	if arm=="E": config.granular_events="off"
	if not await fixture.setup(root,config,"GCR-REST"):
		errors.append(fixture.error); fixture.close(); return
	if not selector_valid(fixture.world,arm): errors.append("barrel selector readback")
	report.configuration=config
	report.initial=fixture.pose(0)
	report.before=fixture.observation()
	report.initial_native_hash=fixture.world.get_physical_state_hash()
	report.actual_mass=fixture.bodies[0].mass
	report.actual_inertia=PhysicsServer2D.body_get_param(fixture.bodies[0].get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	for tick: int in range(1800):
		var prior_steps: int = fixture.bridge.manual_step_count()
		var prior_tick: int = fixture.world.get_tick_index()
		var rows: Array = fixture.step()
		if rows.size()!=1: errors.append(fixture.error); break
		var row: Dictionary = rows[0]
		row["hard_clearance"]=fixture.rest_hard_clearance()
		row["selector"]=fixture.world.gcr_diagnostics().get("granular_events")
		row["observed_native_steps"]=fixture.world.get_tick_index()-prior_tick
		row["observed_rapier_steps"]=fixture.bridge.manual_step_count()-prior_steps
		report.rows.append(row)
		if not row.conserved or not selector_valid(fixture.world,arm): errors.append("barrel quantity/selector"); break
	report.edits=fixture.edits
	report.after=fixture.observation()
	fixture.close()
	await process_frame

func flyer(spec: Dictionary, arm: String, report: Dictionary) -> void:
	var arena = Arena.new()
	root.add_child(arena)
	await process_frame
	var controls: Dictionary = Flat.options(spec.drive=="unactuated")
	if not arena.configure_review_fleet(Flat.configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,controls):
		errors.append(arena.last_error); arena.free(); return
	var world: Object = arena._world
	var body: RigidBody2D = arena.session.bodies()[0]
	var original: Dictionary = Base.state(body)
	if not world.diagnostic_reset(options(arm=="E",38.0)): errors.append("flyer fresh reset"); arena.close(); arena.free(); return
	world.set_simulation_window_enabled(false)
	world.set_cadence_lod_enabled(false)
	if not world.prepare_gcr_coupling(arena.session.bridge.pack_gcr_body_states(),false): errors.append("upright prime")
	var author: Dictionary = OldEvent.author_flyer_room(arena,spec.geometry,int(spec.material))
	if not author.accepted or not selector_valid(world,arm): errors.append("flyer author/selector")
	report.initial=Base.state(body)
	report.initial_native_hash=world.get_physical_state_hash()
	report.configuration={"controls":controls,"author":author,"upright_before_reset":original}
	report.before=Base.flyer_census(world)
	report.actual_mass=body.mass
	report.actual_inertia=PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_INERTIA)
	for tick: int in range(1800):
		var active: bool = spec.drive=="sustained" and tick>=120 and tick<1200
		var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":.15 if active else 0.0,"primary":false,"secondary":false,"auxiliary":false}
		var view: Dictionary = arena.observation(0)
		if not arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"):
			errors.append("flyer command"); break
		var snapshot: Dictionary = arena.step()
		if snapshot.get("failed",false): errors.append(str(snapshot)); break
		var state: Dictionary = Base.state(body)
		var diagnostics: Dictionary = world.gcr_diagnostics()
		var row: Dictionary = {"tick":tick,"state":state,"application":arena.session.bridge.gcr_application_diagnostics(),
			"gcr":diagnostics.bodies[0],"selector":diagnostics.granular_events,"phase":arena.causal_phase,
			"work":[world.get_scanned_last_tick(),world.get_moves_last_tick(),world.get_active_blocks_last_tick()],
			"movement_limited":arena.session._rigs[0]._movement_limited,"action":action}
		row.merge(Base.flyer_overlap(world,state))
		if Base.hard_contacts(body)>0: row.hard_clearance=false
		if tick%60==0 or tick==1799:
			row.census=Base.flyer_census(world)
			row.conserved=Base.same_quantity(report.before,row.census)
			if not row.conserved: errors.append("flyer conservation")
		report.rows.append(Base.portable(row))
		if not errors.is_empty(): break
	report.after=Base.flyer_census(world)
	arena.close()
	arena.free()
