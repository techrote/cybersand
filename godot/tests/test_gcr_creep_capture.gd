extends SceneTree

const Capture = preload("res://qualification/gcr_creep_capture.gd")
var checks: int = 0
var failures: int = 0

class CellProbe:
	extends RefCounted
	var values: Dictionary = {}
	func diagnostic_snapshot(origin: Vector2i, size: Vector2i, _histogram: bool, _hash: bool) -> Dictionary:
		var cells := PackedByteArray()
		cells.resize(size.x*size.y)
		for y: int in range(size.y):
			for x: int in range(size.x):
				cells[y*size.x+x]=int(values.get(origin+Vector2i(x,y),0))
		return {"cells":cells}

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, reason: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error("GCR creep apparatus: "+reason)

func check_actual_initial_authoring() -> void:
	var arena = Capture.Arena.new()
	root.add_child(arena)
	await process_frame
	var configuration: Dictionary = {"version":Capture.Arena.VERSION,"seed":0,"max_ticks":2,"local_patch_radius":0,
		"course":"manoeuvre","actors":[{"model":"arcadelander","producer":"human","position":Capture.FLYER_POSITION}]}
	var controls: Dictionary = {"response":"LA","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0}
	var configured: bool = arena.configure_review_fleet(configuration,"GCR-REST","GCR-REST-001-2026-11-02",2,controls)
	check(configured,"actual default LA Kestrel constructs and primes")
	if not configured:
		arena.free()
		return
	var body: RigidBody2D = arena.session.bodies()[0]
	var mass_before: float = body.mass
	var inertia_before: float = body.inertia
	var receipt: Dictionary = Capture.author_flyer_initial_pose(arena)
	check(receipt.get("accepted",false),"initial authoring retires and re-primes through existing owner API")
	check(receipt.get("retired_ack",false) and receipt.get("primed_ack",false),"both native preparation acknowledgements succeed")
	check(receipt.get("session_before",-1)==receipt.get("session_after",-2),"fixture authoring preserves exact bridge session")
	check(int(receipt.get("sample_after",-1))==int(receipt.get("sample_before",-3))+1,"authored sample advances existing serial once")
	check(receipt.get("native_tick_before",-1)==receipt.get("native_tick_after",-2) and int(receipt.get("native_tick_after",-1))==0,"initial authoring executes zero native ticks")
	check(receipt.get("counts_unchanged",false) and receipt.get("water_unchanged",false),"initial authoring preserves every material count and Water quantity")
	check(receipt.get("mask_after_retire",[])==[0,0,0],"old occupancy fully retires before final pose authoring")
	check(receipt.get("mask_after_prime",[])==[1,0,1],"registered rotated occupancy replaces old orientation without swept residue")
	check(body.mass==mass_before and body.inertia==inertia_before,"initial authoring preserves actual mass and inertia")
	var action: Dictionary = {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":.7,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
	var view: Dictionary = arena.observation(0)
	check(arena.submit(arena.session.make_command(view,int(view.last_sequence)+1,action),&"human"),"actual neutral command admitted after authoring")
	var snapshot: Dictionary = arena.step()
	check(not snapshot.get("failed",true),"first actual synchronous frame succeeds after authoring")
	check(arena.session.bridge.gcr_application_diagnostics().get("accepted",false),"first fresh native response is accepted without weakening session guards")
	arena.close()
	arena.free()
	await process_frame

func _run() -> void:
	for mode: String in ["passive","coast","unactuated","pulse","sustained"]:
		var spec: Dictionary = {"drive":mode}
		for tick: int in [0,119,120,179,180,1199,1200,1799]:
			var expected: bool = mode in ["pulse","sustained"] and tick>=120 and tick<(180 if mode=="pulse" else 1200)
			check(Capture.phase_drive(spec,tick)==expected,"exact registered drive boundary "+mode+" "+str(tick))
	var before: Dictionary = {"counts":[20,4,8,4],"water_mass":255}
	check(Capture.same_quantity(before,{"counts":[21,4,8,3],"water_mass":255}),"Water cell count may change while authoritative quantity remains exact")
	check(not Capture.same_quantity(before,{"counts":[21,4,8,3],"water_mass":254}),"one-unit Water loss refuses")
	check(not Capture.same_quantity(before,{"counts":[21,4,7,4],"water_mass":255}),"one-grain loss refuses")
	check(not Capture.same_quantity(before,{"counts":[20,4,8],"water_mass":255}),"truncated census refuses")
	check(not Capture.same_quantity(before,{}),"absent census refuses")
	var old: Dictionary = {"accepted":true,"snapshot":7}
	check(not Capture.application_step(old,7,20).delivered_this_step,"held accepted receipt is not a new application")
	check(Capture.application_step(old,6,20).delivered_this_step,"fresh accepted receipt is current")
	check(not Capture.application_step({"accepted":false,"snapshot":8},7,20).delivered_this_step,"fresh refused receipt is not delivery")
	var probe := CellProbe.new()
	probe.values={Vector2i(20,20):2,Vector2i(25,25):2}
	var geometry: Dictionary = Capture.flyer_overlap(probe,{"position":Vector2(20,20),"rotation":PI/4.0})
	check(geometry.post_overlap==1,"rotated overlap excludes the AABB corner")
	probe.values={Vector2i(20,20):1}
	geometry=Capture.flyer_overlap(probe,{"position":Vector2(20,20),"rotation":PI/4.0})
	check(geometry.post_overlap==0 and geometry.hard_overlap==1,"hard contact remains separate from material overlap")
	check(not geometry.hard_clearance,"nearby hard cells invalidate a granular-only clearance claim")
	# The actual protocol is outside an isolated Godot project; test registered
	# geometry with an independent literal and mutation rather than a local path.
	var protocol: Dictionary = {"registration":Capture.REGISTRATION,"pulse_start":120,"pulse_end":180,"drive_end":1200,"drive_fraction":.15,"effort":.7,
		"fixture_barrel":{"drive_impulse":.02,"gravity":92.12},
		"fixture_flyer":{"fleet_index":2,"position":[296,312],"angle":PI/2.0,"region":[128,128,512,384],"base":[129,320,510,191],"bank":[300,192,339,128],"border_material":1,"gravity":38,"mass":.1,"inertia":.975,"mass_multiplier":1,"inertia_multiplier":1,"thrust_multiplier":1,"torque_multiplier":1,"census_interval":60,"fire":false,"dispensers":false}}
	check(Capture.configuration_matches_protocol(protocol),"actual fixture constants bind the registered geometry and controls")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(protocol))
	check(Capture.configuration_matches_protocol(parsed),"JSON-roundtripped actual configuration retains float metadata identity")
	check(Capture.metadata_equal(PI/2.0+5e-13,PI/2.0),"metadata-only decimal tolerance permits sub-picounit parser drift")
	check(not Capture.metadata_equal(PI/2.0+2e-12,PI/2.0),"metadata tolerance has a strict absolute1e-12 bound")
	check(not Capture.metadata_equal(300.0000000000005,300),"integer geometry retains exact equality")
	check(Capture.metadata_equal([296.0,312.0],[296,312]),"JSON float-typed integer coordinate arrays compare by exact values")
	check(not Capture.metadata_equal([296.0000000000005,312.0],[296,312]),"fractional coordinate drift refuses inside an array")
	check(not Capture.metadata_equal(true,1),"numeric metadata cannot be supplied as a boolean")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--protocol="):
			var real_protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--protocol=")))
			check(real_protocol is Dictionary and Capture.configuration_matches_protocol(real_protocol),"actual committed JSON protocol binds capture configuration")
	protocol.fixture_flyer.bank=[301,192,339,128]
	check(not Capture.configuration_matches_protocol(protocol),"one-cell protocol/fixture geometry drift refuses")
	check(Capture.configuration_protocol_error(protocol)=="protocol.fixture_flyer.bank differs from registered capture value","refusal identifies the exact mismatched field")
	var copied: Dictionary = Capture.portable({"v":Vector2(1,2),"unknown":null,"contact_bins":[{"large":true}],"nested":{"cells":PackedByteArray([1]),"count":4}})
	check(copied.v==[1.0,2.0] and copied.unknown==null,"portable values preserve coordinates and explicit unknowns")
	check(not copied.has("contact_bins") and not copied.nested.has("cells") and copied.nested.count==4,"raw arrays omitted without discarding scalar evidence")
	await check_actual_initial_authoring()
	print("GCR_CREEP_APPARATUS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"capture boundaries, conservation and rotated readback only; no physical efficacy"}))
	quit(0 if failures==0 else 1)
