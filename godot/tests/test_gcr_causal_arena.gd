extends SceneTree

const OriginalArena = preload("res://scripts/physical_actor_arena.gd")
const CausalArena = preload("res://qualification/gcr_causal_arena.gd")
const Capture = preload("res://qualification/gcr_timing_capture.gd")
const Base = preload("res://qualification/gcr_creep_capture.gd")
const Flat = preload("res://qualification/gcr_creep_flat_capture.gd")
var checks: int = 0
var failures: int = 0
var summaries: Array = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("Causal arena mechanical: "+reason)

func open_arena(experimental: bool, arm: String, unactuated: bool):
	var arena = CausalArena.new() if experimental else OriginalArena.new()
	root.add_child(arena)
	if experimental:
		check(arena.set_causal_arm(arm),"initial causal arm accepted")
	check(arena.configure_review_fleet(Flat.configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,Flat.options(unactuated)),"actual default LA owner constructs")
	if arena.session!=null:
		check(Flat.author_room(arena).accepted,"same flat native fixture authored")
	return arena

func apply_action(arena, tick: int, driven: bool) -> Dictionary:
	var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":.15 if driven and tick>=120 else 0.0,"primary":false,"secondary":false,"auxiliary":false}
	var view: Dictionary = arena.observation(0)
	check(arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"),"same fresh actor command admitted")
	var result: Dictionary = arena.step()
	check(not result.get("failed",true),"actual owner frame completes")
	return result

func compare_body(a, b, label: String) -> void:
	var first: Dictionary = Base.state(a.session.bodies()[0])
	var second: Dictionary = Base.state(b.session.bodies()[0])
	check(Vector2(first.position).distance_to(Vector2(second.position))<=1e-5,label+" position")
	check(absf(float(first.rotation)-float(second.rotation))<=1e-5,label+" rotation")
	check(Vector2(first.velocity).distance_to(Vector2(second.velocity))<=1e-5,label+" velocity")
	check(absf(float(first.omega)-float(second.omega))<=1e-5,label+" angular velocity")
	var values_a: PackedFloat64Array = a._world.gcr_body_results()
	var values_b: PackedFloat64Array = b._world.gcr_body_results()
	var equal: bool = values_a.size()==14 and values_b.size()==14
	if equal:
		for field: int in range(14):
			if field!=CyberRigidBodyCoupling.GCR_RESULT_SESSION and absf(values_a[field]-values_b[field])>1e-6*maxf(1.0,maxf(absf(values_a[field]),absf(values_b[field]))):
				equal=false
	check(equal,label+" result packet with declared session-token normalization")
	if values_a.size()==14 and values_b.size()==14:
		check(int(values_a[13])==a.session.bridge._gcr_session_id and int(values_b[13])==b.session.bridge._gcr_session_id,label+" each native packet retains its own actual session")

func compare_census(a, b, label: String) -> void:
	var first: Dictionary = a._world.diagnostic_snapshot(Vector2i(128,128),Vector2i(512,384),false,true)
	var second: Dictionary = b._world.diagnostic_snapshot(Vector2i(128,128),Vector2i(512,384),false,true)
	check(first.counts==second.counts and first.water_mass==second.water_mass,label+" exact quantity")
	check(first.cells==second.cells,label+" exact native cell material field")
	check(first.hash==second.hash,label+" exact native authoritative state hash")

func phase_checks(arena, label: String) -> void:
	var phase: Dictionary = arena.causal_phase
	check(phase.counts=={"actuation":1,"sample":1,"native_tick":1,"rapier_step":1,"response_calls":1},label+" one execution per intended boundary")
	check(phase.actuation.pose_unchanged,label+" actuation preserves pose")
	var expected: Dictionary = phase.actuation.after if phase.arm=="T" else phase.actuation.before
	check(Vector2(phase.sample.velocity)==Vector2(expected.velocity) and float(phase.sample.omega)==float(expected.omega),label+" native sample uses declared actual velocity phase")
	check(Vector2(phase.sample.position)==Vector2(expected.position) and float(phase.sample.rotation)==float(expected.rotation),label+" native sample uses unchanged actual geometry")
	check(phase.correction_setter.accepted,label+" post-response operation preserves velocity and identity")
	check(int(phase.counter_after.native_tick)-int(phase.counter_before.native_tick)==1,label+" actual native tick advances once")
	check(int(phase.counter_after.rapier_steps)-int(phase.counter_before.rapier_steps)==1,label+" actual bridge manual-step counter advances once")
	check(int(phase.counter_after.session_tick)-int(phase.counter_before.session_tick)==1,label+" actual session completion advances once")
	check(int(phase.counter_after.packed_sample)-int(phase.counter_before.packed_sample)==1,label+" actual packing serial advances once")
	check(int(phase.actuation.rig_tick_after)-int(phase.actuation.rig_tick_before)==1,label+" actual rig actuator tick advances once")
	check(phase.fresh_sample_applied,label+" intended current sample is freshly accepted exactly once")

func parity_suite() -> void:
	var retained = open_arena(false,"C",false)
	var copied = open_arena(true,"C",false)
	if retained.session==null or copied.session==null:
		return
	for tick: int in range(180):
		apply_action(retained,tick,true)
		apply_action(copied,tick,true)
		compare_body(retained,copied,"retained/C "+str(tick))
		phase_checks(copied,"C "+str(tick))
		if tick%60==0 or tick==179:
			compare_census(retained,copied,"retained/C "+str(tick))
	summaries.append({"comparison":"retainedArena versus experiment C","ticks":180,"quantity":"exact","session_normalization":"result field13 only"})
	retained.close()
	copied.close()
	retained.free()
	copied.free()
	await process_frame
	var control = open_arena(true,"C",true)
	var after = open_arena(true,"T",true)
	for tick: int in range(120):
		apply_action(control,tick,false)
		apply_action(after,tick,false)
		compare_body(control,after,"zero-actuator C/T "+str(tick))
		phase_checks(after,"T zero "+str(tick))
		check(Vector2(after.causal_phase.actuation.actual_impulse)==Vector2.ZERO and float(after.causal_phase.actuation.actual_torque_impulse)==0.0,"unactuated T is an actual zero-input null control")
		if tick%60==0 or tick==119:
			compare_census(control,after,"zero-actuator C/T "+str(tick))
	summaries.append({"comparison":"unactuated C versus T","ticks":120,"quantity":"exact"})
	control.close()
	after.close()
	control.free()
	after.free()
	await process_frame

func setter_suite() -> void:
	for arm: String in ["S","X"]:
		var arena = open_arena(true,arm,true)
		var setters: int = 0
		for tick: int in range(90):
			apply_action(arena,tick,false)
			phase_checks(arena,arm+" "+str(tick))
			var operation: Dictionary = arena.causal_phase.correction_setter
			var app: Dictionary = arena.session.bridge.gcr_application_diagnostics().bodies[0]
			check(operation.retained_angular_impulse==app.angular_impulse,arm+" original delivered angular impulse retained")
			check(operation.proposed_correction==app.correction,arm+" native/bridge correction retained as original evidence")
			check(operation.velocity_before_setter==operation.velocity_after_setter and operation.omega_before_setter==operation.omega_after_setter,arm+" setter contributes zero linear/angular impulse")
			if operation.observed_translation!=Vector2.ZERO:
				setters+=1
				check(operation.setter_count==1,arm+" one setter on actual observed translation")
				check(operation.final_origin==(operation.pre_response_origin if arm=="X" else operation.after_response_origin),arm+" exact registered target origin")
				if arm=="X":
					check(absf(float(operation.offset_potential_delta)+float(operation.observed_bridge_potential_delta))<=1e-9,"X cancels observed translation potential exactly")
			else:
				check(operation.setter_count==0,arm+" zero setter when translation unobserved")
		check(setters>0,arm+" actual correction intervention exercised")
		summaries.append({"arm":arm,"ticks":90,"actual_setters":setters})
		arena.close()
		arena.free()
		await process_frame
	var driven = open_arena(true,"T",false)
	apply_action(driven,120,true)
	phase_checks(driven,"nonzero T")
	check(Vector2(driven.causal_phase.actuation.actual_impulse).x>0.0,"T samples actual nonzero side-jet actuation")
	driven.close()
	driven.free()
	await process_frame

func barrel_setter_boundary() -> void:
	var fixture = preload("res://tests/support/y1_envelope_fixture.gd").new()
	var configured: bool = await fixture.setup(root,{"left":96,"width":96,"depth":160,"layout":"packed","size":1,"mass":1.0,
		"angle":.08,"gap":2,"speed":0,"gravity":92.12,"friction":.78,"workers":1,"material":2,"ticks":1800,
		"rest_mode":"control","base_budget":20.0},"GCR-REST")
	check(configured,"retained actual barrel fixture constructs")
	if not configured:
		fixture.close()
		return
	var setters: int = 0
	for tick: int in range(90):
		var before_native: int = int(fixture.world.get_tick_index())
		var before_rapier: int = fixture.bridge.manual_step_count()
		var before_sample: int = fixture.bridge._sample_serial
		var before_fixture: int = fixture.tick
		var rows: Array = fixture.step()
		check(rows.size()==1,"retained barrel frame completes")
		if rows.size()!=1:
			break
		check(rows[0].application.bodies[0].current_origin is Array,"historical fixture row retains its portable array boundary")
		var live: Dictionary = fixture.bridge.gcr_application_diagnostics()
		check(int(fixture.world.get_tick_index())-before_native==1,"actual retained barrel native tick advances once")
		check(fixture.bridge.manual_step_count()-before_rapier==1,"actual retained barrel Rapier step advances once")
		check(fixture.bridge._sample_serial-before_sample==1 and fixture.tick-before_fixture==1,"actual retained barrel sample and fixture tick advance once")
		check(int(live.bodies[0].sample)==fixture.bridge._sample_serial and fixture.bridge._applied_sample_serials[0]==fixture.bridge._sample_serial,"actual retained barrel applies the intended fresh sample")
		check(live.bodies[0].current_origin is Vector2,"new experiment obtains live copied receipt for its geometric operation")
		var operation: Dictionary = CausalArena.correction_intervention(fixture.bridge,fixture.bodies[0],live,"X",92.12)
		if not operation.accepted:
			print("BARREL_SETTER_MECHANICAL_FAILURE ",tick," ",JSON.stringify(Base.portable(operation)))
		check(operation.accepted,"actual barrel X preserves live bridge guards and velocity")
		if operation.setter_count==1:
			setters+=1
			check(operation.final_origin==operation.pre_response_origin,"actual barrel X restores exact pre-response origin")
		check(fixture.conserved(fixture.observation()),"barrel inverse translation preserves exact native quantity")
	check(setters>0,"barrel X setter exercised in actual retained fixture")
	summaries.append({"comparison":"retained barrel live/portable receipt boundary and X mechanics","ticks":90,"actual_setters":setters})
	fixture.close()
	await process_frame

func negative_controls() -> void:
	for material: int in [1,3]:
		for arm: String in ["T","S","X"]:
			var arena = open_arena(true,arm,false)
			check(arena._world.diagnostic_fill_rect(Vector2i(129,320),Vector2i(510,191),material),"mechanical hard/Water base authoring")
			var before: Dictionary = Base.flyer_census(arena._world)
			for tick: int in range(60):
				apply_action(arena,120,true)
				phase_checks(arena,"negative "+str(material)+" "+arm+" "+str(tick))
				var diagnostics: Dictionary = arena._world.gcr_diagnostics()
				var body: Dictionary = diagnostics.bodies[0]
				check(int(body.nodes)==0 and float(body.normal_accepted)==0.0 and float(body.tangent_accepted)==0.0,"hard/Water supplies zero granular contact response")
				check(Vector2(body.event_accepted)==Vector2.ZERO,"hard/Water supplies zero granular event response")
				check(arena.causal_phase.correction_setter.setter_count==0,"hard/Water introduces no granular correction setter")
			var after: Dictionary = Base.flyer_census(arena._world)
			check(Base.same_quantity(before,after),"negative control exact native material and Water quantity")
			check(int(after.counts[2])==0,"negative room contains no accidental granular Sand")
			summaries.append({"negative_material":material,"arm":arm,"ticks":60,"quantity":"exact","granular_response":"zero"})
			arena.close()
			arena.free()
			await process_frame

func _run() -> void:
	var timing_path: String = ""
	var legacy_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--timing-protocol="):
			timing_path=argument.trim_prefix("--timing-protocol=")
		elif argument.begins_with("--protocol="):
			legacy_path=argument.trim_prefix("--protocol=")
	if timing_path.is_empty():
		timing_path=legacy_path
	check(not timing_path.is_empty() and (legacy_path.is_empty() or legacy_path==timing_path),"explicit timing protocol required; conflicting aliases refuse")
	if timing_path.is_empty() or (not legacy_path.is_empty() and legacy_path!=timing_path):
		quit(1)
		return
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(timing_path))
	var protocol_valid: bool = protocol is Dictionary and Capture.protocol_error(protocol).is_empty()
	check(protocol_valid,"actual committed protocol binds timing fixture")
	if not protocol_valid:
		quit(1)
		return
	await parity_suite()
	await setter_suite()
	await barrel_setter_boundary()
	await negative_controls()
	print("GCR_CAUSAL_ARENA ",JSON.stringify({"checks":checks,"failures":failures,"summaries":summaries,
		"scope":"actual copied-control parity, zero-actuator timing null, same-phase timing and post-response setter mechanics; no physical candidate acceptance"}))
	quit(0 if failures==0 else 1)
