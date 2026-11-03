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
	protocol.fixture_flyer.bank=[301,192,339,128]
	check(not Capture.configuration_matches_protocol(protocol),"one-cell protocol/fixture geometry drift refuses")
	var copied: Dictionary = Capture.portable({"v":Vector2(1,2),"unknown":null,"contact_bins":[{"large":true}],"nested":{"cells":PackedByteArray([1]),"count":4}})
	check(copied.v==[1.0,2.0] and copied.unknown==null,"portable values preserve coordinates and explicit unknowns")
	check(not copied.has("contact_bins") and not copied.nested.has("cells") and copied.nested.count==4,"raw arrays omitted without discarding scalar evidence")
	print("GCR_CREEP_APPARATUS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"capture boundaries, conservation and rotated readback only; no physical efficacy"}))
	quit(0 if failures==0 else 1)
