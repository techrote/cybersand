extends SceneTree

# Direct native API mechanics only. Held, identical poses and authored gravity0
# establish exact-zero synthetic quiet witnesses. They exercise admission/cache
# retirement, never nonzero-catch efficacy or Rapier/gameplay rest.
const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL REST MATERIAL FRESHNESS ",message)

func fresh(mode: String) -> Object:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world != null and world.diagnostic_reset({"workers":1,"telemetry":true,"conservative_displacement":true,
		"bearing_candidate":"GCR-REST","bearing_experiment":"GCR-REST-001-2026-11-02",
		"gcr_rest_mode":mode,"gcr_base_budget":20.,"gcr_rest_gravity":0.}),"fresh native "+mode)
	world.set_simulation_window_enabled(false)
	return world

func context(serial: int) -> Dictionary:
	return {"version":1,"sample":serial,"session":73,"last_applied_sample":serial-1,
		"gravity":0.,"external_drive":false,"hard_clearance":true}

func states(serial: int, y: float = 100., velocity: Vector2 = Vector2.ZERO) -> PackedFloat64Array:
	return PackedFloat64Array([1,104,y,0,8,14,velocity.x,velocity.y,0,1,serial,13,104,y,.78,1./60.,73])

func row(world: Object) -> Dictionary:
	var receipt: Dictionary = world.gcr_rest_receipt()
	check(receipt.get("version",0)==1 and receipt.get("material_revalidated",false),"versioned current material receipt")
	check(int(receipt.get("revalidation_boundary_checks",-1))==4*int(receipt.get("revalidation_raster_cells",-2)),"one bounded four-face raster pass")
	check(int(receipt.get("revalidation_support_queries",-1))<=int(receipt.get("revalidation_boundary_checks",-2)),"support query bound")
	var bodies: Array = receipt.get("bodies",[])
	check(bodies.size()==1,"one physical rest receipt")
	return bodies[0] if bodies.size()==1 else {}

func prime(world: Object, mode: String) -> int:
	check(world.diagnostic_fill_rect(Vector2i(96,107),Vector2i(24,20),2),"packed synthetic support")
	for serial: int in range(1,33):
		check(world.prepare_gcr_coupling(states(serial),true,context(serial)),"held quiet sample "+str(serial))
		check(world.gcr_body_results().size()==14,"one synthetic wrench")
	var witness: Dictionary = row(world)
	check(int(witness.get("quiet_count",-1))==30 and witness.get("quiet_admitted",false),"positive held quiet witness "+mode)
	check(witness.get("warm_started",false)==(mode in ["P","PRC"]),"positive persistence witness "+mode)
	check(witness.get("catch_applied",false)==(mode in ["C","PRC"]),"positive catch witness "+mode)
	return 33

func retired(world: Object, label: String) -> void:
	var witness: Dictionary = row(world)
	check(not witness.get("catch_applied",true) and not witness.get("warm_started",true),label+" retires catch and warmstart")
	check(int(witness.get("quiet_count",-1))==0 and not witness.get("quiet_admitted",true),label+" retires quiet history")
	check(world.gcr_rest_receipt().get("material_changed_since_prepare",false),label+" records prepared/current mismatch")
	var first: PackedFloat64Array = world.gcr_body_results()
	var again: Dictionary = row(world)
	check(world.gcr_body_results()==first and int(again.get("quiet_count",-1))==0,label+" repeated getters cannot restore authority")

func nonzero_prepared_force() -> void:
	# One copied descending state, with no simulated trajectory, isolates the
	# requirement that safety revalidation preserves the prepared baseline law.
	for mode: String in ["P","C","PRC"]:
		var world: Object = fresh(mode)
		check(world.diagnostic_fill_rect(Vector2i(96,107),Vector2i(24,20),2),"nonquiet packed source")
		check(world.prepare_gcr_coupling(states(1,100.,Vector2(3,30)),true,context(1)),"nonquiet descending sample")
		var prepared: PackedFloat64Array = world.gcr_body_results()
		check(prepared.size()==14 and Vector2(prepared[1],prepared[2]).length()>1.,"nonzero baseline witness "+mode)
		check(world.diagnostic_fill_rect(Vector2i(96,107),Vector2i(24,20),0),"nonquiet source erase")
		var current: PackedFloat64Array = world.gcr_body_results()
		check(current.size()==14 and prepared.size()==14 and current[1]==prepared[1] and current[2]==prepared[2] and current[9]==prepared[9],"nonzero prepared J/L exactly preserved "+mode)
		retired(world,"nonquiet "+mode)

func independent_edits() -> void:
	var control: Object = fresh("control")
	check(control.diagnostic_fill_rect(Vector2i(96,107),Vector2i(24,20),2),"baseline control support")
	check(control.prepare_gcr_coupling(states(33),true,context(33)),"baseline control sample")
	var baseline: PackedFloat64Array = control.gcr_body_results()
	for mode: String in ["P","C","PRC"]:
		for timing: String in ["before-result","cached-same-tick","after-native-tick"]:
			var world: Object = fresh(mode)
			var serial: int = prime(world,mode)
			check(world.prepare_gcr_coupling(states(serial),true,context(serial)),"fresh edit sample")
			if timing=="cached-same-tick":
				world.gcr_body_results()
				check(row(world).get("quiet_admitted",false),"cached proposal admitted before edit")
			check(world.diagnostic_fill_rect(Vector2i(96,107),Vector2i(24,20),0),"erase admitted support")
			if timing=="after-native-tick": check(world.simulation_tick(),"native step after support edit")
			var before: String = world.get_physical_state_hash()
			var packet: PackedFloat64Array = world.gcr_body_results()
			check(packet.size()==14,"baseline prepared force remains available")
			check(packet.size()==14 and baseline.size()==14 and packet[1]==baseline[1] and packet[2]==baseline[2] and packet[9]==baseline[9],"rest veto preserves exact baseline prepared wrench")
			retired(world,mode+" "+timing)
			check(world.get_physical_state_hash()==before,"revalidation makes no material edit or rerelocation")
			check(str(row(world).get("support_signature","unknown"))=="0","current support is absent")
			if timing=="cached-same-tick":
				check(world.diagnostic_fill_rect(Vector2i(96,107),Vector2i(24,20),2),"restore old cell arrangement without a new sample")
				world.gcr_body_results()
				retired(world,mode+" restored same sample")
		# A still-capable source replacement must also retire the old proposal.
		var changed: Object = fresh(mode)
		var serial: int = prime(changed,mode)
		check(changed.prepare_gcr_coupling(states(serial),true,context(serial)),"source replacement sample")
		changed.gcr_body_results()
		check(changed.diagnostic_fill_rect(Vector2i(103,107),Vector2i.ONE,23),"replace one source by Salt")
		changed.gcr_body_results()
		retired(changed,mode+" capable source replacement")
		check(str(row(changed).get("support_signature","0"))!="0","current replacement remains support capable")
		var hard: Object = fresh(mode)
		serial=prime(hard,mode)
		check(hard.prepare_gcr_coupling(states(serial),true,context(serial)),"hard-revision sample")
		hard.gcr_body_results()
		var signature: String = str(row(hard).get("support_signature","0"))
		check(hard.diagnostic_fill_rect(Vector2i(140,100),Vector2i.ONE,1),"late hard edit away from sources")
		hard.gcr_body_results()
		retired(hard,mode+" hard revision fence")
		check(str(row(hard).get("support_signature",""))==signature,"hard fence is independent of source signature")

func current_overlap_correction() -> void:
	for mode: String in ["R","PRC"]:
		var world: Object = fresh(mode)
		# This overlap exists before body masks, rather than bypassing native
		# authority by trying to paint nonempty material into a live mask.
		check(world.diagnostic_fill_rect(Vector2i(64,64),Vector2i(80,80),2),"packed unresolved correction fixture")
		check(world.prepare_gcr_coupling(states(1,100.,Vector2(0,.1)),true,context(1)),"previous correction pose")
		world.gcr_body_results()
		check(world.prepare_gcr_coupling(states(2,100.01,Vector2(0,.1)),true,context(2)),"nonzero legacy correction sample")
		var packed: PackedFloat64Array = world.gcr_body_results()
		var before: Dictionary = row(world)
		check(float(before.get("requested_correction",Vector2.ZERO).y)<0.,"old correction is measurable")
		check(packed.size()==14 and packed[4]<0. and int(before.get("post_overlap",0))>0,"current positive overlap retains correction")
		check(world.diagnostic_fill_rect(Vector2i(100,93),Vector2i(8,14),0),"erase stored interior after cached result")
		var cleared: PackedFloat64Array = world.gcr_body_results()
		var after: Dictionary = row(world)
		check(int(after.get("post_overlap",-1))==0,"current zero overlap replaces stale positive certificate")
		check(cleared.size()==14 and cleared[4]==0. and float(after.requested_correction.y)<0.,"current zero overlap suppresses previously retained correction")
		check(not after.get("catch_applied",true) and not after.get("warm_started",true),"overlap vetoes rest mechanisms")

func compound_world(mode: String) -> Dictionary:
	var world: Object = fresh(mode)
	for item: Array in [[0,72,128,4,1],[50,40,4,32,43],[44,27,29,13,43],[54,40,11,4,43],[8,45,3,27,43],[60,32,1,1,0]]:
		check(world.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]),"native compound recipe")
	check(world.simulation_tick(),"native source inclusion")
	check(world.solid_detachment_command({"action":"configure","members":1024,"shapes":128}).get("ok",false),"native compound configuration")
	var source: Dictionary = world.solid_detachment_command({"action":"cut_prepare","domain":Session.DOMAIN,"anchors":Session.ANCHORS,"seed":Session.SEED,"cut":Session.CUT})
	check(source.get("ok",false),"native compound preparation")
	if not source.get("ok",false): return {}
	check(world.solid_detachment_command({"action":"acknowledge","token":source.token,"body_id":1,"body_generation":7,
		"shape_count":source.shape_count,"payload_digest":source.payload_digest,"shape_digest":source.shape_digest}).get("ok",false),"native compound acknowledgement")
	var committed: Dictionary = world.solid_detachment_command({"action":"commit","token":source.token})
	check(committed.get("ok",false),"native compound commit")
	check(world.solid_detachment_command({"action":"finalize","token":source.token,"body_id":1,"body_generation":7,
		"terrain_revision":committed.commit_revision,"physics_epoch":1}).get("ok",false),"native compound finalize")
	check(world.diagnostic_fill_rect(Vector2i(0,65),Vector2i(128,20),0),"retire stump and hard floor for mechanical witness")
	check(world.diagnostic_fill_rect(Vector2i(46,65),Vector2i(12,20),2),"compound synthetic packed support")
	check(world.diagnostic_fill_rect(Vector2i(46,85),Vector2i(12,2),1),"distant synthetic bed floor")
	check(world.simulation_tick(),"native settling tick retires newly painted source epoch")
	return {"world":world,"source":source,"lease":{"token":source.token,"body_id":1,"body_generation":7,"physics_epoch":1}}

func compound_states(source: Dictionary,serial: int) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	var rectangles: PackedInt32Array = source.rectangles
	for offset: int in range(0,rectangles.size(),4):
		values.append_array(PackedFloat64Array([offset/4+1,rectangles[offset]+rectangles[offset+2]*.5,rectangles[offset+1]+rectangles[offset+3]*.5,
			0,rectangles[offset+2],rectangles[offset+3],0,0,0,source.mass,serial,source.inertia,source.center.x,source.center.y,.78,1./60.,73]))
	return values

func compound_edits() -> void:
	for mode: String in ["P","C","PRC"]:
		for advance_tick: bool in [false,true]:
			var fixture: Dictionary = compound_world(mode)
			if fixture.is_empty(): continue
			var world: Object = fixture.world
			for serial: int in range(1,33):
				check(world.prepare_gcr_compound_coupling(compound_states(fixture.source,serial),fixture.lease,true,context(serial)),"held compound sample")
				check(world.gcr_compound_results().size()==14,"one compound wrench")
			var witness: Dictionary = row(world)
			check(witness.get("quiet_admitted",false),"positive native compound quiet witness")
			check(witness.get("warm_started",false)==(mode in ["P","PRC"]),"positive native compound persistence witness")
			check(witness.get("catch_applied",false)==(mode in ["C","PRC"]),"positive native compound catch witness")
			check(world.prepare_gcr_compound_coupling(compound_states(fixture.source,33),fixture.lease,true,context(33)),"compound edit sample")
			world.gcr_compound_results() # Establish the actual compound cached path.
			check(world.diagnostic_fill_rect(Vector2i(46,65),Vector2i(12,20),0),"compound support removal")
			if advance_tick: check(world.simulation_tick(),"native compound step after edit")
			check(world.gcr_compound_results().size()==14,"compound baseline survives rest veto")
			var current: Dictionary = row(world)
			check(not current.get("catch_applied",true) and not current.get("warm_started",true) and int(current.get("quiet_count",-1))==0,"compound current material retires rest authority")
			check(world.gcr_rest_receipt().get("material_changed_since_prepare",false),"compound mismatch recorded")
			var packet: PackedFloat64Array = world.gcr_compound_results()
			check(world.gcr_compound_results()==packet and int(row(world).get("quiet_count",-1))==0,"compound repeated getters cannot rebuild dwell")

func _run() -> void:
	nonzero_prepared_force()
	independent_edits()
	current_overlap_correction()
	compound_edits()
	print("GCR_REST_MATERIAL_FRESHNESS ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),
		"scope":"actual native direct API; exact-zero held gravity0 admission/retirement witnesses plus a separate nonquiet nonzero prepared-wrench comparison; no nonzero-catch efficacy or gameplay rest claim"}))
	quit(0 if failures.is_empty() else 1)
