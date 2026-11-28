extends SceneTree

# Runs the real Shared Workbench, native worker and patched Rapier backend.
# FocusHost only supplies the OS-focus predicate absent in headless execution.
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
class FocusHost extends "res://scripts/main.gd":
	func _actor_window_has_focus() -> bool:
		return DisplayServer.get_name() == "headless" or super._actor_window_has_focus()

var host: Control
var bench: Control
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var frames: Array[float] = []
var uploads: Array[float] = []
var frame_gaps: Array[float] = []
var equipment_success: Dictionary = {}
var measuring := false
var last_frame_usec := 0
var maximum_gap_usec := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func _process(_delta: float) -> bool:
	if measuring and host != null:
		var now := Time.get_ticks_usec()
		if last_frame_usec:
			maximum_gap_usec = maxi(maximum_gap_usec, now-last_frame_usec)
			frame_gaps.append(float(now-last_frame_usec)/1000.0)
		last_frame_usec = now
		frames.append(float(host.frame_time_ms))
		uploads.append(float(host.upload_time_ms))
		if host.latest_snapshot != null:
			for receipt: Dictionary in host.latest_snapshot.physical_usables.get("receipts",[]):
				if bool(receipt.get("accepted",false)):
					equipment_success[int(receipt.actor_id)] = true
	return false


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		push_error("WB_ACTOR_CAPACITY: " + label)
	return value


func until(predicate: Callable, label: String, seconds := 180) -> bool:
	var deadline := Time.get_ticks_msec() + seconds*1000
	var report_at := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		if host != null and host.simulation_worker != null and host.simulation_worker.has_failed(): break
		if Time.get_ticks_msec() > report_at:
			print("WB_ACTOR_CAPACITY_WAIT ", label, " / ", bench.message if bench != null else "opening",
				" / ", host.microscenario_error if host != null else "")
			report_at = Time.get_ticks_msec()+10000
		await process_frame
	return check(false, label+" / "+str(bench.message if bench != null else "no Workbench"))


func installed() -> bool:
	return bench != null and not bench.applied.is_empty() and not bench.busy() \
		and host.pending_microscenario_apply.is_empty() and host.physical_actor_session != null


func native_tick() -> int:
	return int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else -1


func rapier_tick() -> int:
	return int(host.physical_actor_session.tick) if host.physical_actor_session != null else -1


func rss_bytes() -> int:
	# Actual process resident memory where available, distinct from Godot's
	# allocator count (which does not include every native backend allocation).
	var status := FileAccess.open("/proc/self/status",FileAccess.READ)
	if status != null:
		# procfs reports zero file size; get_as_text() therefore returns no bytes.
		for _line: int in 100:
			var line := status.get_line()
			if line.begins_with("VmRSS:"):
				var kib := int(line.trim_prefix("VmRSS:").strip_edges().trim_suffix("kB").strip_edges())
				status.close()
				return kib*1024
		status.close()
	return -1


func schema_checks() -> void:
	var recipe := fixture("barrels",16)
	var original := JSON.stringify(recipe)
	for malformed: Variant in ["wrong", [], 9, null, {"version":1}]:
		var definitions := Setup.physical_definitions(recipe)
		definitions[0].workbench_capacity = malformed
		check(not Session.valid_definitions(definitions),"malformed runtime capacity refuses without typed assignment")
	var mismatch := Setup.physical_definitions(recipe)
	mismatch.back().workbench_capacity.logical_limit += 1
	check(not Session.valid_definitions(mismatch),"all runtime definitions share one capacity contract")
	check(JSON.stringify(recipe)==original,"capacity refusal preserves authored source")
	var roundtrip: Variant = JSON.parse_string(original)
	check(Setup.validate(roundtrip).is_empty() and roundtrip.actors.size()==16,
		"JSON roundtrip preserves expanded population and integer-valued budget")


func fixture(family: String, count: int) -> Dictionary:
	var policy: PackedInt32Array = bench._liquids.bridge.default_liquid_policy()
	var setup := Setup.fresh(policy,Vector2i(1024,1024))
	var choices: Array[String] = [Setup.BARREL]
	if family == "mixed": choices = ["midge","runner","crawler","skimmer","stuntbuggy",Setup.BARREL,"4ly_trainer","monowheel"]
	elif family == "articulated": choices = ["stuntbuggy","ripper","crawler","winchbug","runner","tiltrotor","monowheel","inchworm"]
	var columns := 16 if count > 64 else 8
	var spacing := 56.0 if count > 64 else 112.0
	for index: int in count:
		var model: String = choices[index % choices.size()]
		var actor := Setup.instance(model,index+1,Vector2(64+(index%columns)*spacing,64+(index/columns)*spacing))
		actor.control = Catalog.default_control(model)
		if model != Setup.BARREL:
			actor.control.source = "policy" if index%5 == 4 else "scripted"
			if index == 0 and family == "mixed": actor.control.source = "human"
			# Exercise real copied equipment commands at a high slot, through
			# the ordinary external-policy lease, alongside independent NPCs.
			if model == "runner" and index >= count-8:
				actor.control.source = "policy"
				actor.control.policy = "external"
				actor.control.usable_index = 12
		setup.actors.append(actor)
	setup.next_id = count+1
	setup.selected = 1
	var used := Catalog.resource_usage(setup.actors)
	setup.sandbox_capacity = {"version":1,"logical_limit":count,
		"body_limit":maxi(64,int(used.bodies)),"proxy_limit":maxi(64,int(used.proxies))}
	# Large clear floor, a granular strip, and ample air between independent
	# assemblies: this measures actors, not an intentionally overlapping pile.
	Setup._box(setup.edits,Vector2i(0,980),Vector2i(1024,1000),Setup.WALL)
	Setup._box(setup.edits,Vector2i(32,960),Vector2i(420,980),Setup.SAND)
	return setup


func measure(family: String, count: int) -> bool:
	var failures_before := failures.size()
	var setup := fixture(family,count)
	var label := "%s-%d" % [family,count]
	var expected := Catalog.resource_usage(setup.actors)
	if not check(Setup.validate(setup).is_empty(),label+": authored admission / "+Setup.validate(setup)): return false
	var old_session = host.physical_actor_session
	var old_bodies: Array = old_session.bodies() if old_session != null else []
	var preparation := Time.get_ticks_usec()
	if not check(bench.apply(setup),label+": real prepared-owner request"): return false
	if not await until(installed,label+": native preparation"): return false
	var latency := Time.get_ticks_usec()-preparation
	var session = host.physical_actor_session
	check(session != old_session,label+": fresh authoritative session")
	for body in old_bodies: check(not is_instance_valid(body),label+": previous body retired")
	check(session._rigs.size()==count,label+": actual logical actors")
	check(session.bodies().size()==int(expected.bodies),label+": actual physical bodies")
	var actual_joints := 0
	for rig in session._rigs: actual_joints += rig.physical_joint_count()
	var equipment_actors: int = session.equipment_frame().actors.size()
	check(actual_joints == int(expected.joints),label+": actual Rapier joints")
	var packet: Dictionary = session.pack_workbench_sample()
	check(packet.get("bodies",[]).size()==int(expected.bodies),label+": distinct response owners")
	check(packet.get("states",PackedFloat64Array()).size()/17==int(expected.proxies),label+": actual native proxy sample")
	var identities := {}
	for offset: int in range(0,packet.get("states",PackedFloat64Array()).size(),17):
		identities[int(packet.states[offset])] = true
	check(identities.size()==int(expected.proxies),label+": distinct full-width proxy identities")
	# Refused budgets preserve this session and the accepted composition.
	var refused := setup.duplicate(true)
	refused.sandbox_capacity.logical_limit = count-1
	var retained: Dictionary = bench.applied.duplicate(true)
	check(not bench.apply(refused),label+": over-capacity operation refused")
	check(host.physical_actor_session==session and bench.applied==retained,label+": refusal is atomic")
	frames.clear(); uploads.clear(); frame_gaps.clear(); equipment_success.clear()
	maximum_gap_usec=0; last_frame_usec=0
	var first_native := native_tick()
	var first_rapier := rapier_tick()
	var start := Time.get_ticks_usec()
	measuring = true
	if host.paused: check(bench.toggle_pause(),label+": ordinary Play")
	var equipment_slot := -1
	if family != "barrels":
		equipment_slot = count-7 if family == "mixed" else count-4
		var instance_id := equipment_slot+1
		var ready := await until(func() -> bool: return bool(bench.actor_observation(instance_id).get("equipment",{}).get("ready",false)),label+": high-slot equipment ready")
		if ready:
			var view: Dictionary = bench.actor_observation(instance_id,true)
			check(bench.submit_actor_policy(instance_id,Session.make_command(view,int(view.last_sequence)+1,
				{"equipment":{"trigger":true,"aim":Vector2.RIGHT,"power":0.7}},6)),label+": high-slot equipment command admitted")
	var progressed := await until(func() -> bool: return native_tick()>=first_native+30 and rapier_tick()>=first_rapier+30,label+": 30 coupled ticks")
	measuring = false
	var elapsed := Time.get_ticks_usec()-start
	var native_steps := native_tick()-first_native
	var rapier_steps := rapier_tick()-first_rapier
	if not host.paused: check(bench.toggle_pause(),label+": pause after sample")
	var native_result: Dictionary = host.latest_snapshot.lab_context.get("workbench_gcr",{})
	var physical_usables: Dictionary = host.latest_snapshot.physical_usables
	check(int(physical_usables.get("actor_count",-1))==equipment_actors,label+": equipment owner admitted every equipped actor")
	check(int(physical_usables.get("frame_tick",-1))>0,label+": actual equipment worker frame progressed")
	check(str(physical_usables.get("last_error",""))!="actor_capacity_transition",label+": no first-frame equipment capacity refusal")
	if equipment_slot>=0:
		check(equipment_success.has(equipment_slot),label+": high-slot native equipment execution acknowledged")
	check(bool(native_result.get("valid",false)),label+": native response packet valid")
	check(native_result.get("rows",[]).size()==int(expected.bodies),label+": native actually registered every response owner")
	check(int(native_result.get("active_proxies",-1))==int(expected.proxies),label+": native actually registered every occupancy proxy")
	var native_identities := {}
	for native_row: Dictionary in native_result.get("rows",[]):
		native_identities[int(native_row.id)] = true
	check(native_identities.size()==int(expected.bodies),label+": unique native response identities")
	for body: RigidBody2D in session.bodies():
		check(body.get_rid().is_valid() and body.global_transform.is_finite()
			and body.linear_velocity.is_finite() and is_finite(body.angular_velocity),
			label+": finite living Rapier body")
	var decision_total := 0
	var accepted := 0
	for index: int in count:
		var view: Dictionary = session.workbench_control(index+1)
		decision_total += int(view.get("total_decision_usec",0))
		accepted += int(view.get("accepted",0))
	check(not host.simulation_worker.has_failed(),label+": healthy native owner")
	check(session.active() and session.bodies().size()==int(expected.bodies),label+": no automatic population reduction")
	var row := {"family":family,"actors":count,"bodies":session.bodies().size(),"joints":actual_joints,
		"proxies":identities.size(),"native_ticks":native_steps,"rapier_ticks":rapier_steps,
		"elapsed_usec":elapsed,"preparation_usec":latency,"frame_ms_mean":mean(frames),
		"frame_ms_max":frames.max() if not frames.is_empty() else 0.0,"upload_ms_mean":mean(uploads),
		"wall_frame_ms_mean":mean(frame_gaps),"measured_frames":frames.size(),
		"upload_ms_max":uploads.max() if not uploads.is_empty() else 0.0,"maximum_frame_gap_usec":maximum_gap_usec,
		"memory_static_bytes":OS.get_static_memory_usage(),"process_rss_bytes":rss_bytes(),
		"controller_decision_total_usec":decision_total,"accepted_commands":accepted,
		"native_registered_bodies":int(native_result.get("active_bodies",-1)),
		"native_registered_proxies":int(native_result.get("active_proxies",-1)),
		"native_response_workspace_bytes":int(native_result.get("response_workspace_bytes",-1)),
		"native_body_observation_bytes":int(native_result.get("body_observation_storage_bytes",-1)),
		"equipment_owner_actors":int(physical_usables.get("actor_count",-1)),
		"equipment_prepared_actors":equipment_actors,
		"equipment_worker_frame_tick":int(physical_usables.get("frame_tick",-1)),
		"equipment_last_error":str(physical_usables.get("last_error","")),
		"equipment_accepted_actors":equipment_success.size(),
		"headless":DisplayServer.get_name()=="headless","passed":progressed and failures.size()==failures_before}
	rows.append(row)
	print("WB_ACTOR_CAPACITY_ROW ",JSON.stringify(row))
	return bool(row.passed)


func mean(values: Array[float]) -> float:
	var total := 0.0
	for value: float in values: total += value
	return total/values.size() if not values.is_empty() else 0.0


func run() -> void:
	root.size=Vector2i(1280,800)
	set_meta("cybersand_feature","shared_workbench")
	host=load("res://main.tscn").instantiate()
	host.set_script(FocusHost)
	root.add_child(host)
	if await until(func() -> bool: return host.shared_workbench != null,"ordinary Workbench opens"):
		bench=host.shared_workbench
		if await until(func() -> bool: return not bench.applied.is_empty() and not bench.busy() and host.pending_microscenario_apply.is_empty(),"initial native owner"):
			schema_checks()
			var args := OS.get_cmdline_user_args()
			var counts: Array[int] = [16,32,64]
			var families: Array[String] = ["barrels","mixed","articulated"]
			if args.has("--count"): counts=[int(args[args.find("--count")+1])]
			if args.has("--family"): families=[str(args[args.find("--family")+1])]
			for family: String in families:
				for count: int in counts:
					if not await measure(family,count): break
			if not args.has("--count"):
				for count: int in [128,256]:
					if not await measure("barrels",count): break
				for family: String in ["mixed","articulated"]:
					if not await measure(family,128): break
	var report := {"case":"WB-ACTOR-COMPOSE-002R real Workbench capacity", "checks":checks,
		"failures":failures,"rows":rows,"godot":Engine.get_version_info(),
		"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method()}
	var path:=OS.get_environment("CYBERSAND_ACTOR_CAPACITY_REPORT")
	if not path.is_empty():
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WB_ACTOR_CAPACITY ",JSON.stringify(report))
	if host!=null:
		host.queue_free()
		await process_frame
		await process_frame
	quit(0 if failures.is_empty() else 1)
