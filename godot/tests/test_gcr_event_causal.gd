extends SceneTree

const Event = preload("res://qualification/gcr_event_capture.gd")
const Base = preload("res://qualification/gcr_creep_capture.gd")
const Flat = preload("res://qualification/gcr_creep_flat_capture.gd")
const Arena = preload("res://scripts/physical_actor_arena.gd")
const CausalArena = preload("res://qualification/gcr_causal_arena.gd")
const Barrel = preload("res://tests/support/y1_envelope_fixture.gd")
var checks: int = 0
var errors: Array[String] = []
var report: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		errors.append(message)
		push_error(message)

func baseline_rows(reconstruct: bool) -> Dictionary:
	var arena = CausalArena.new() if reconstruct else Arena.new()
	root.add_child(arena)
	await process_frame
	var result: Dictionary = {"ok":false,"rows":[],"errors":[]}
	if reconstruct and not arena.set_causal_arm("C"):
		result.errors.append("causal arm refused")
	if not arena.configure_review_fleet(Flat.configuration(),"GCR-REST","GCR-REST-001-2026-11-02",2,Flat.options(true)):
		result.errors.append("control configure refused")
		arena.free()
		return result
	if reconstruct:
		result.reconstruction=Event.reconstruct_flyer(arena,.025)
		if not result.reconstruction.accepted:
			result.errors.append("control reconstruction refused")
	result.authoring=Event.author_flyer_room(arena,"bank",2)
	if not result.authoring.accepted:
		result.errors.append("bank authoring refused")
	result.initial=Base.state(arena.session.bodies()[0])
	result.before=Base.flyer_census(arena._world)
	for tick: int in range(60):
		var view: Dictionary = arena.observation(0)
		var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":0.0,
			"primary":false,"secondary":false,"auxiliary":false}
		if not arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"):
			result.errors.append("control command refused")
			break
		var snapshot: Dictionary = arena.step()
		if snapshot.get("failed",false):
			result.errors.append("control step: "+str(snapshot.get("reason","")))
			break
		var body: Dictionary = Base.state(arena.session.bodies()[0])
		var diagnostics: Dictionary = arena._world.gcr_diagnostics()
		var gcr: Dictionary = diagnostics.get("bodies",[{}])[0] if diagnostics.get("bodies",[]).size()==1 else {}
		result.rows.append({"tick":tick,"state":body,"event":gcr.get("event_accepted"),"impulse":gcr.get("impulse"),"nodes":gcr.get("nodes"),
			"phase":arena.causal_phase.duplicate(true) if reconstruct else {}})
	result.after=Base.flyer_census(arena._world)
	result.ok=result.errors.is_empty() and result.rows.size()==60
	arena.close()
	arena.free()
	await process_frame
	return result

func _run() -> void:
	var protocol_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--event-protocol="):
			protocol_path=arg.trim_prefix("--event-protocol=")
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path)) if not protocol_path.is_empty() else null
	check(protocol is Dictionary and protocol.get("registration","")==Event.REGISTRATION and protocol.get("cases",[]).size()==8,"explicit registered event protocol")
	if not errors.is_empty():
		quit(1)
		return
	for spec: Dictionary in protocol.cases:
		check(Event.protocol_valid(protocol,spec),"registered event case "+str(spec.id))
	var control: Dictionary = Event.calibration(.025)
	var muted: Dictionary = Event.calibration(0.0)
	report.calibration={"control":control,"muted":muted}
	check(control.ok,"positive-gain native witness")
	check(muted.ok,"muted-gain native witness")
	check(int(control.get("native_blocked_contacts",0))>0 and int(control.get("native_blocked_contacts",0))==int(muted.get("native_blocked_contacts",-1)),"gain removal retains native blocked attempts")
	check(control.get("native_hash_after")!="" and control.get("native_hash_after")==muted.get("native_hash_after"),"gain removal preserves identical post-tick native physical state")
	check(control.get("counts_before")==muted.get("counts_before") and control.get("counts_after")==muted.get("counts_after"),"gain witness identical native counts")
	check(control.get("effective_gain")!=null and absf(float(control.effective_gain)-.025)<1e-7,"positive effective gain readback")
	check(muted.get("effective_gain")!=null and float(muted.effective_gain)==0.0,"zero effective gain readback")
	var old: Dictionary = await baseline_rows(false)
	var current: Dictionary = await baseline_rows(true)
	report.control_parity={"old_ok":old.ok,"new_ok":current.ok,"old_initial":old.get("initial"),"new_initial":current.get("initial"),
		"reconstruction":current.get("reconstruction"),"authoring":current.get("authoring"),"old_errors":old.errors,"new_errors":current.errors}
	check(old.ok and current.ok,"retained/reconstructed controls completed")
	check(old.get("initial")==current.get("initial"),"control initial physical body parity")
	check(old.get("before",{}).get("counts")==current.get("before",{}).get("counts"),"control initial material parity")
	var maximum_position: float = 0.0
	var maximum_velocity: float = 0.0
	var maximum_rotation: float = 0.0
	var maximum_omega: float = 0.0
	var maximum_impulse: float = 0.0
	if old.rows.size()==60 and current.rows.size()==60:
		for tick: int in range(60):
			var a: Dictionary = old.rows[tick]
			var b: Dictionary = current.rows[tick]
			maximum_position=maxf(maximum_position,Vector2(a.state.position).distance_to(b.state.position))
			maximum_velocity=maxf(maximum_velocity,Vector2(a.state.velocity).distance_to(b.state.velocity))
			maximum_rotation=maxf(maximum_rotation,absf(float(a.state.rotation)-float(b.state.rotation)))
			maximum_omega=maxf(maximum_omega,absf(float(a.state.omega)-float(b.state.omega)))
			maximum_impulse=maxf(maximum_impulse,Vector2(a.impulse).distance_to(b.impulse))
			check(int(b.phase.get("counts",{}).get("native_tick",0))==1 and int(b.phase.counts.get("sample",0))==1 and int(b.phase.counts.get("response_calls",0))==1,"one control boundary at "+str(tick))
	check(maximum_position<=1e-5,"fresh reconstruction control position parity")
	check(maximum_velocity<=1e-5,"fresh reconstruction control velocity parity")
	check(maximum_rotation<=1e-5 and maximum_omega<=1e-5,"fresh reconstruction control angular parity")
	check(maximum_impulse<=1e-5,"fresh reconstruction control wrench parity")
	report.control_parity.merge({"maximum_position_error":maximum_position,"maximum_velocity_error":maximum_velocity,
		"maximum_rotation_error":maximum_rotation,"maximum_omega_error":maximum_omega,"maximum_impulse_error":maximum_impulse},true)
	# Exercise the portable retained barrel rows: these contain Array vectors,
	# unlike the live flyer diagnostics. Both gains must survive actual impacts.
	var barrel_spec: Dictionary = protocol.fixture_barrel_high.duplicate(true)
	barrel_spec.merge({"material":2,"ticks":1800,"rest_mode":"control","base_budget":20.0},true)
	var retained = Barrel.new()
	var retained_ok: bool = await retained.setup(root,barrel_spec,"GCR-REST")
	check(retained_ok,"retained barrel control setup")
	var retained_rows: Array = []
	if retained_ok:
		for tick: int in range(90):
			var rows: Array = retained.step()
			if rows.size()!=1:
				break
			retained_rows.append(rows[0])
	retained.close()
	check(retained_rows.size()==90,"retained barrel control population")
	report.barrel={}
	for gain: float in [.025,0.0]:
		var capture = Event.new(false)
		var observed: Dictionary = {"rows":[]}
		await capture.capture_barrel({"contact_gain":gain,"arm":"C" if gain>0 else "E0"},observed,barrel_spec,90,root)
		check(capture.errors.is_empty() and observed.rows.size()==90,"event barrel portable ledger gain "+str(gain))
		var parity: float = 0.0
		for tick: int in range(observed.rows.size()):
			var row: Dictionary = observed.rows[tick]
			check(row.conserved and Event.zero_vector(row.gcr.legacy_non_granular),"barrel conservation/legacy isolation "+str(gain)+" "+str(tick))
			check(row.causal_phase.fresh_sample_applied and row.causal_phase.counts.native_tick==1 and row.causal_phase.counts.rapier_step==1 and row.causal_phase.counts.sample==1,"barrel fresh observed stages "+str(gain)+" "+str(tick))
			var before: Dictionary = row.causal_phase.counter_before
			var after: Dictionary = row.causal_phase.counter_after
			check(int(after.native_tick)-int(before.native_tick)==1 and int(after.rapier_steps)-int(before.rapier_steps)==1 and int(after.session_tick)-int(before.session_tick)==1,"barrel actual native/Rapier/fixture tick deltas "+str(gain)+" "+str(tick))
			check(int(after.packed_sample)-int(before.packed_sample)==1 and int(after.last_applied_sample)==int(after.packed_sample) and int(after.last_snapshot)==int(before.session_tick)+1,"barrel actual intended sample and snapshot "+str(gain)+" "+str(tick))
			check(int(before.rig_tick)==0 and int(after.rig_tick)==0 and row.causal_phase.counts.actuation==0,"barrel explicitly has no pilot actuator tick "+str(gain)+" "+str(tick))
			if gain==0.0:
				check(Event.zero_vector(row.gcr.event_raw) and Event.zero_vector(row.gcr.event_accepted) and row.gcr.event_budget_cost==0,"barrel muted before passive "+str(tick))
			elif tick<retained_rows.size():
				var old_row: Dictionary = retained_rows[tick]
				for axis: int in range(6):
					var current_value: float = float(row.position[axis]) if axis<2 else float(row.rotation) if axis==2 else float(row.velocity[axis-3]) if axis<5 else float(row.omega)
					parity=maxf(parity,absf(current_value-float(old_row.out[axis])))
		if gain>0:
			check(parity<=1e-5,"fresh event barrel control trajectory parity")
		report.barrel[str(gain)]={"rows":observed.rows.size(),"errors":capture.errors.duplicate(),"maximum_control_state_error":parity if gain>0 else null,"reconstruction":observed.get("native_reconstruction")}
		capture.free()
	report.checks=checks
	report.errors=errors
	report.ok=errors.is_empty()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--event-protocol="):
			report.identity=Event.report_identity(arg.trim_prefix("--event-protocol="))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:
				file.store_string(JSON.stringify(Base.portable(report)))
				file.close()
	print("GCR_EVENT_CAUSAL_CHECKS ",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
