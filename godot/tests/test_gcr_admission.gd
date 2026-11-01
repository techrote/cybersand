extends SceneTree

# Mechanical adapter checks only: no Rapier stepping or efficacy trajectories.
# The native independent geometry/state oracle is a separate prerequisite.
const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
var failures: int = 0
var assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("GCR admission adapter: "+message)

func states(serial: int = 1, velocity: Vector2 = Vector2(10,0)) -> PackedFloat64Array:
	return PackedFloat64Array([1,104,100,0,8,14,velocity.x,velocity.y,0,1,serial,13,104,100,.78,1.0/60.0,73])

func construct(arm: String, telemetry: bool = true) -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var token: String = Fixture.ADMISSION_TOKEN if arm == "GCR-A1" else Fixture.GCR_TOKEN
	check(world != null and world.diagnostic_reset({"workers":1,"telemetry":telemetry,"bearing_candidate":arm,"bearing_experiment":token}),"fresh "+arm)
	return world

func snapshot(world: Object) -> Dictionary:
	return world.diagnostic_snapshot(Vector2i(88,72),Vector2i(48,64),false,false)

func interior_empty(world: Object) -> bool:
	for y: int in range(93,107):
		for x: int in range(100,108):
			if int(world.material_at(x,y)) != 1: # occupancy is the body, not stored material
				return false
	var view: Dictionary = world.diagnostic_snapshot(Vector2i(100,93),Vector2i(8,14),false,false)
	return int(view.counts[0]) == 112

func bounds(body: Dictionary) -> void:
	var a: Dictionary = body.get("admission",{})
	check(not a.is_empty(),"A1 admission counters published")
	var sources: int = int(a.get("source_candidates",0))
	check(sources > 0,"side candidates counted")
	check(int(a.get("geometry_mask_checks",0)) <= 24*sources,"geometry-mask bound")
	check(int(a.get("mask_checks",0)) <= 31*sources,"full mask bound")
	check(int(a.get("path_checks",0)) <= 7*sources,"path bound")
	check(int(a.get("shared_witness_calls",0)) <= sources,"one packing call per source")

func clean_bank() -> void:
	for material: int in [2,13,14,19,23,25,26,27,29]:
		for arm: String in ["GCR","GCR-A1"]:
			var world: Object = construct(arm)
			check(world.diagnostic_fill_rect(Vector2i(108,80),Vector2i(12,40),material,1 if material == 13 else 0),"bank fill")
			var before: Dictionary = snapshot(world)
			check(world.prepare_gcr_coupling(states(),true),"post-ejection clean-side prepare")
			check(interior_empty(world),"no stored interior overlap")
			var after: Dictionary = snapshot(world)
			check(before.cells == after.cells and before.counts == after.counts and before.water_mass == after.water_mass,"clean admission preserved material observations")
			var diagnostic: Dictionary = world.gcr_diagnostics()
			check(diagnostic.admission_variant == ("A1" if arm == "GCR-A1" else "R2"),"actual variant identity")
			var body: Dictionary = diagnostic.bodies[0]
			var count: int = 0
			for bin: Dictionary in body.contact_bins:
				count += int(bin.count)
				if int(bin.count)>0:
					check(bin.normal == Vector2(-1,0),"original right-face normal")
					check(absf(float(bin.position_sum.x)-108.0*float(bin.count))<.000001,"witness did not move force point")
			if arm == "GCR-A1":
				check(count == 14,"fourteen exterior sources, no witness multiplicity")
				check(float(body.normal_capacity) == 20.0,"one capped body capacity")
				check(float(body.normal_accepted)>0,"admitted closing normal response")
				bounds(body)
			else: check(count == 0,"same-build R2 clean-side refusal reproduced")

func post_ejection_and_slip() -> void:
	var world: Object = construct("GCR-A1")
	check(world.diagnostic_fill_rect(Vector2i(108,80),Vector2i(12,40),2),"post-ejection bank fill")
	# A small left-edge overlap has real Empty targets along the unchanged
	# bounded ejection route. The independently packed right bank stays intact.
	# A deep right overlap into a solid bank is not a successful-ejection premise.
	check(world.diagnostic_fill_rect(Vector2i(100,98),Vector2i(2,4),2),"legal left overlap with free ejection volume")
	var before: Dictionary = snapshot(world)
	check(world.prepare_gcr_coupling(states(),true),"real ejection followed by A1 admission")
	check(interior_empty(world),"successful ejection left no stored interior overlap")
	var after: Dictionary = snapshot(world)
	check(before.counts == after.counts and before.water_mass == after.water_mass,"ejection conserved measured quantities")
	check(float(world.gcr_diagnostics().bodies[0].normal_accepted)>0,"response after actual ejection")
	world = construct("GCR-A1")
	check(world.diagnostic_fill_rect(Vector2i(108,80),Vector2i(12,40),2),"slip bank")
	check(world.prepare_gcr_coupling(states(1,Vector2(0,10)),true),"pure vertical slip")
	var body: Dictionary = world.gcr_diagnostics().bodies[0]
	check(int(body.bins)>0,"slipping side admitted")
	check(float(body.normal_accepted)==0 and float(body.tangent_accepted)==0 and float(body.passive_torque)==0,"no velocity-created normal load or friction from pure vertical slip")
	check(world.diagnostic_fill_rect(Vector2i(88,72),Vector2i(48,64),0),"support removal")
	check(world.prepare_gcr_coupling(states(2),true),"fresh support removal")
	body = world.gcr_diagnostics().bodies[0]
	check(int(body.bins)==0 and float(body.normal_accepted)==0,"next fresh sample retired support")

func identity_and_downward() -> void:
	var results: Array = []
	for arm: String in ["GCR","GCR-A1"]:
		var world: Object = construct(arm)
		check(world.diagnostic_fill_rect(Vector2i(96,107),Vector2i(16,20),2),"downward fill")
		check(world.prepare_gcr_coupling(states(1,Vector2(0,30)),true),"downward sample")
		results.append(world.gcr_body_results())
	check(results[0] == results[1],"ordinary downward branch exactly retained")
	var world: Object = construct("GCR-A1",false)
	check(world.get_gcr_admission_variant() == "A1","actual identity available with telemetry off")
	check(world.diagnostic_fill_rect(Vector2i(108,80),Vector2i(12,40),2),"telemetry-off bank")
	check(world.prepare_gcr_coupling(states(),true),"telemetry-off admission sample")
	var before: String = world.get_physical_state_hash()
	var counters: Array = world.get_gcr_admission_counters()
	check(counters.size()==1 and counters[0].admission_variant=="A1","cheap actual counter identity without solver diagnostics")
	if counters.size()==1: bounds({"admission":counters[0]})
	check(world.get_physical_state_hash()==before,"counter/identity observation did not mutate World")
	for invalid: Dictionary in [{"bearing_candidate":"GCR-A1","bearing_experiment":Fixture.GCR_TOKEN},
		{"bearing_candidate":"GCR","bearing_experiment":Fixture.ADMISSION_TOKEN},
		{"bearing_candidate":"GCR-A1"},{"bearing_experiment":Fixture.ADMISSION_TOKEN}]:
		check(not world.diagnostic_reset(invalid),"invalid/cross-token construction refused")
		check(world.get_physical_state_hash()==before and world.get_gcr_admission_variant()=="A1","refusal preserved existing authority")
	check(world.diagnostic_reset({}),"ordinary fresh reset")
	check(world.get_gcr_admission_variant()=="disabled","ordinary B0 default did not retain A1")
	for material: int in [0,1,3]:
		world = construct("GCR-A1")
		check(world.diagnostic_fill_rect(Vector2i(108,80),Vector2i(12,40),material),"negative source fill")
		check(world.prepare_gcr_coupling(states(),true),"negative source prepare")
		var body: Dictionary = world.gcr_diagnostics().bodies[0]
		check(int(body.bins)==0 and float(body.normal_accepted)==0 and float(body.tangent_accepted)==0,"hard/Water/Empty excluded from new granular admission")

func _run() -> void:
	clean_bank()
	post_ejection_and_slip()
	identity_and_downward()
	var args: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if args.has("output"):
		var report: Dictionary = {"schema":1,"gate":"adapter","ok":failures==0,"assertions":assertions,"failures":failures,
			"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"input_identity":OS.get_environment("CYBERSAND_INPUT_IDENTITY"),
			"protocol_sha256":FileAccess.get_sha256(str(args.get("protocol",""))),
			"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
			"limits":"Mechanical adapter controls only; independent native query/oracle gates remain separate. No coupled efficacy trajectory."}
		var file := FileAccess.open(str(args.output),FileAccess.WRITE)
		if file == null: check(false,"mechanical receipt output unavailable")
		else:
			file.store_string(JSON.stringify(report))
			file.close()
	print("GCR_ADMISSION_ADAPTER assertions=",assertions," failures=",failures,"; no trajectory efficacy or independent-oracle verdict")
	quit(0 if failures == 0 else 1)
