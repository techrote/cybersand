extends SceneTree

# Value-only admission, material authority and C/E/S controls. Live Rapier hull,
# rendering and subjective carry feel are qualified by separate host fixtures.
var checks: int=0
var failures: Array[String]=[]
var reports: Array[Dictionary]=[]
const SESSION: int=73
const COM:=Vector2(128,128)

func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> bool:
	checks+=1
	if not ok: failures.append(why);printerr("FAIL AUTHORED COMPOUND: ",why)
	return ok
func near(a: float,b: float,why: String,tolerance: float=1e-8) -> void:
	check(absf(a-b)<=tolerance*maxf(1.,absf(b)),why)
func options(arm: String="control",authored: bool=true) -> Dictionary:
	return {"workers":1,"telemetry":true,"bearing_candidate":"GCR-REST",
		"bearing_experiment":"GCR-REST-001-2026-11-02","gcr_rest_mode":"control",
		"gcr_base_budget":20.0,"gcr_rest_gravity":38.0,
		"gcr_granular_events":arm,"gcr_event_experiment":"GCR-SEL-001-2026-11-04",
		"gcr_authored_compound":authored}
func world(arm: String="control",authored: bool=true) -> Object:
	var native: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	check(native!=null,"actual native class")
	check(native.diagnostic_reset(options(arm,authored)),"fresh explicit native construction "+arm)
	native.set_simulation_window_enabled(false)
	native.set_cadence_lod_enabled(false)
	return native
func identity(session: int=SESSION,generation: int=7) -> Dictionary:
	return {"version":1,"session_id":session,"body_generation":generation}
func bowl() -> PackedFloat64Array:
	# Uniform-area COM is exactly zero; empty cavity x[-4,4],y[-5,1].
	return PackedFloat64Array([0,2,12,2,-5,-2,2,6,5,-2,2,6])
func states(geometry: PackedFloat64Array,serial: int=1,com: Vector2=COM,
		angle: float=0.,session: int=SESSION,mass: float=.18,inertia: float=3.6) -> PackedFloat64Array:
	var value:=PackedFloat64Array()
	for index: int in range(geometry.size()/4):
		var k: int=index*4
		var centre: Vector2=com+Vector2(geometry[k],geometry[k+1]).rotated(angle)
		value.append_array(PackedFloat64Array([index+1,centre.x,centre.y,angle,
			geometry[k+2],geometry[k+3],0,0,0,mass,serial,inertia,com.x,com.y,.8,1./60.,session]))
	return value
func snapshot(native: Object) -> Dictionary:
	return native.diagnostic_snapshot(Vector2i(80,80),Vector2i(96,96),false,false)
func mask(native: Object) -> PackedInt32Array:
	var result:=PackedInt32Array()
	for y: int in range(116,141):
		for x: int in range(116,141): result.append(native.rigid_body_id_at(x,y))
	return result
func prepare(native: Object,g: PackedFloat64Array,serial: int=1,com: Vector2=COM,
		angle: float=0.,session: int=SESSION,resolve: bool=true) -> bool:
	return native.prepare_gcr_authored_compound_coupling(states(g,serial,com,angle,session),g,identity(session),resolve)

func protocol() -> void:
	var native: Object=world()
	var g:=bowl()
	for malformed: PackedFloat64Array in [PackedFloat64Array([0,0,4,4,0,0,4,4]),
			PackedFloat64Array([1,0,4,4]),PackedFloat64Array([0,0,129,4]),PackedFloat64Array([NAN,0,4,4])]:
		var first: Object=world()
		var unchanged: String=first.get_physical_state_hash()
		check(not first.prepare_gcr_authored_compound_coupling(states(malformed),malformed,identity(),false),"invalid geometry cannot bind a fresh authored owner")
		check(first.get_physical_state_hash()==unchanged and mask(first).count(0)==625,"invalid first geometry preserves cells and empty occupancy")
		check(prepare(first,g),"invalid first admission does not reserve the session")
		first=null
	var good: Dictionary=options()
	var before: String=native.get_physical_state_hash()
	for override: Dictionary in [{"gcr_authored_compound":1},{"conservative_displacement":true},
			{"bearing_candidate":"B0","bearing_experiment":"Y1-ENVELOPE-2026-11-01"},{"gcr_rest_mode":"P"}]:
		var bad: Dictionary=good.duplicate(true);bad.merge(override,true)
		check(not native.diagnostic_reset(bad) and native.get_physical_state_hash()==before,"invalid construction preserves old native owner")
	check(not native.prepare_gcr_coupling(states(g),false),"authored construction cannot prime an independent AABB")
	check(not native.prepare_gcr_compound_coupling(states(g),{},false),"authored construction cannot impersonate detached payload")
	check(not native.solid_detachment_command({"action":"configure","members":32,"shapes":8}).get("ok",false),"authored owner cannot acquire detached material authority")
	check(prepare(native,g),"one physical authored union admitted")
	var d: Dictionary=native.gcr_compound_diagnostics()
	check(d.get("admission_kind")=="authored" and d.get("proxy_count")==3 and d.get("physical_body_id")==1,"explicit authored kind, three proxies and one physical owner")
	check(native.gcr_body_results().is_empty() and native.gcr_compound_results().size()==14,"one v2 wrench only; no independent result path")
	near(d.get("mass",-1),.18,"proxy count cannot multiply mass")
	near(d.get("inertia",-1),3.6,"one copied physical inertia")
	var serial: int=2
	for fault: String in ["empty","count","nan_geometry","overlap","centroid","extent","geometry_change",
			"identity_version","identity_type","identity_extra","generation","session","missing","duplicate","fractional",
			"size","mass","inertia","friction","velocity","angle","angle_overflow","dt","stale","rest_context"]:
		var bad_g: PackedFloat64Array=g.duplicate()
		var bad_states: PackedFloat64Array=states(g,serial)
		var bad_identity: Dictionary=identity()
		var context: Dictionary={}
		match fault:
			"empty": bad_g=PackedFloat64Array()
			"count": bad_g.resize(36)
			"nan_geometry": bad_g[0]=NAN
			"overlap": bad_g[4]=0;bad_g[5]=2
			"centroid": bad_g[0]+=1
			"extent": bad_g[0]=200
			"geometry_change": bad_g[0]+=.125
			"identity_version": bad_identity.version=2
			"identity_type": bad_identity.body_generation=7.0
			"identity_extra": bad_identity["unexpected"]=1
			"generation": bad_identity.body_generation=8
			"session": bad_identity.session_id=74
			"missing": bad_states.resize(34)
			"duplicate": bad_states[17]=1
			"fractional": bad_states[0]=1.5
			"size": bad_states[4]+=1
			"mass":
				for k: int in range(3): bad_states[k*17+9]=.19
			"inertia":
				for k: int in range(3): bad_states[k*17+11]=4.0
			"friction":
				for k: int in range(3): bad_states[k*17+14]=.9
			"velocity": bad_states[17+6]=1
			"angle": bad_states[3]=NAN
			"angle_overflow": bad_states[3]=1e300
			"dt": bad_states[15]=0
			"stale": bad_states=states(g,serial-1)
			"rest_context": context={"version":2}
		var old_mask: PackedInt32Array=mask(native)
		var old: Dictionary=snapshot(native)
		var tick: int=native.get_tick_index()
		check(not native.prepare_gcr_authored_compound_coupling(bad_states,bad_g,bad_identity,true,context),"refuse malformed/stale immutable input: "+fault)
		check(mask(native)==old_mask and snapshot(native).cells==old.cells and native.get_tick_index()==tick,"refusal preserves occupancy/material/clock: "+fault)
		check(native.gcr_compound_results().is_empty(),"refusal cannot publish previous response: "+fault)
		check(prepare(native,g,serial),"next valid fresh sample recovers after refusal: "+fault)
		serial+=1
	var old_mask: PackedInt32Array=mask(native)
	check(not native.retire_gcr_authored_compound(identity(SESSION,8)) and mask(native)==old_mask,"stale retire cannot clear live geometry")
	var old_cells: PackedByteArray=snapshot(native).cells
	check(native.retire_gcr_authored_compound(identity()),"matching owner retires explicitly")
	check(mask(native).count(0)==625 and snapshot(native).cells==old_cells,"retirement clears masks without erasing material")
	check(not native.retire_gcr_authored_compound(identity()) and not prepare(native,g,serial),"retired owner cannot replay or rebind before reset")
	check(native.diagnostic_reset(options()),"fresh native reconfiguration")
	check(not prepare(native,g,serial),"old copied session cannot revive after reset")
	check(prepare(native,g,1,COM,0.,SESSION+1),"new session can bind after reset")
	check(native.reset_demo_world(),"ordinary reset retires experimental path")
	check(not prepare(native,g,serial,COM,0.,SESSION+1),"ordinary owner cannot accept authored packets")
	check(native.diagnostic_reset({"bearing_candidate":"GCR","bearing_experiment":"GCR-001-2026-11-01","gcr_authored_compound":true}),"RFT supplemental mechanical construction")
	check(prepare(native,g,1,COM,0.,SESSION+2) and native.gcr_compound_results().size()==14,"RFT uses the same admitted one-body compound machinery")
	native=null

func geometry_and_material() -> void:
	var g:=bowl()
	for arm: String in ["control","off","selective"]:
		var native: Object=world(arm)
		var serial: int=1
		for angle: float in [0.,.37,PI*.5]:
			check(prepare(native,g,serial,COM,angle),"level/rotated rectangle union admitted "+arm)
			for y: int in range(116,141):
				for x: int in range(116,141):
					var local: Vector2=(Vector2(x+.5,y+.5)-COM).rotated(-angle)
					var occupied: bool=false
					for k: int in range(3):
						var delta: Vector2=local-Vector2(g[k*4],g[k*4+1])
						occupied=occupied or (absf(delta.x)<=g[k*4+2]*.5 and absf(delta.y)<=g[k*4+3]*.5)
					check((native.rigid_body_id_at(x,y)>0)==occupied,"native mask matches union rather than AABB "+arm)
			serial+=1
		check(prepare(native,g,serial),"restore level cavity")
		serial+=1
		check(native.rigid_body_id_at(128,126)==0 and native.rigid_body_id_at(128,130)>0,"open cavity and real deck are distinct")
		check(native.diagnostic_fill_rect(Vector2i(128,126),Vector2i.ONE,2),"author one real grain inside cavity")
		var before: Dictionary=snapshot(native)
		check(prepare(native,g,serial) and native.material_at(128,126)==2,"cavity material is neither masked nor ejected")
		check(snapshot(native).counts==before.counts,"cavity preparation conserves all native material")
		native=null
	# Every admitted powder keeps native authority even when initially overlapping
	# one hull pixel; no supported material is a special yellow-Sand shortcut.
	for material: int in [2,14,29,13,19,23,25,26,27,3]:
		var native: Object=world("selective")
		check(native.diagnostic_fill_rect(Vector2i(128,130),Vector2i.ONE,material),"authored overlap material "+str(material))
		var before: Dictionary=snapshot(native)
		check(prepare(native,g),"bounded actual overlap resolution "+str(material))
		var after: Dictionary=snapshot(native)
		check(before.counts==after.counts and before.water_mass==after.water_mass,"exact material and Water quantity conserved "+str(material))
		check(native.gcr_compound_results().size()==14,"material response produces one physical wrench")
		var d: Dictionary=native.gcr_compound_diagnostics()
		check(float(d.event_budget_cost)+float(d.normal_accepted)<=float(d.global_capacity)+1e-8,"one shared load-aware allowance "+str(material))
		check(float(d.energy_after)<=float(d.energy_before)+1e-8*maxf(1.,float(d.energy_before)),"passive energy guard "+str(material))
		check(int(d.nodes)<=48 and int(d.updates)<=384,"bounded three-proxy solver work "+str(material))
		native=null

func arrivals(arm: String,compound: bool,split: bool=false,material: int=2) -> Array[Dictionary]:
	var native: Object=world(arm,compound)
	# One real grain falls between hard side controls onto an off-centre hull.
	native.diagnostic_fill_rect(Vector2i(128,126),Vector2i.ONE,material)
	native.diagnostic_fill_rect(Vector2i(127,125),Vector2i(1,3),1)
	native.diagnostic_fill_rect(Vector2i(129,125),Vector2i(1,3),1)
	var g:=PackedFloat64Array([-1.5,0,2,1,1,0,3,1]) if split else PackedFloat64Array([0,0,5,1])
	var rows: Array[Dictionary]=[]
	for tick: int in range(4):
		var packed: PackedFloat64Array=states(g,tick+1,Vector2(129.5,128.5),0.,SESSION,.1,1.)
		var admitted: bool=native.prepare_gcr_authored_compound_coupling(packed,g,identity(),false) if compound else native.prepare_gcr_coupling(packed,false)
		check(admitted and native.simulation_tick(),"actual native arrival boundary "+arm)
		var packet: PackedFloat64Array=native.gcr_compound_results() if compound else native.gcr_body_results()
		var d: Dictionary=native.gcr_diagnostics()
		var row: Dictionary=d if compound else d.get("bodies",[{}])[0]
		check(not row.is_empty(),"native arrival diagnostics exist")
		rows.append(row)
		check(packet.size()==14,"exactly one physical output")
	var quantities: Dictionary=snapshot(native)
	check(quantities.counts[material]==(7 if material==1 else 1),"closed arrival material quantity")
	native=null
	return rows

func event_controls() -> void:
	var populations: Dictionary={}
	for arm: String in ["control","off","selective"]:
		var compound: Array[Dictionary]=arrivals(arm,true)
		var independent: Array[Dictionary]=arrivals(arm,false)
		var split: Array[Dictionary]=arrivals(arm,true,true)
		populations[arm]=compound
		for tick: int in range(4):
			check(compound[tick].event_raw==independent[tick].event_raw and compound[tick].event_accepted==independent[tick].event_accepted,"one-rectangle authored event matches independent law "+arm)
			near(compound[tick].event_torque,independent[tick].event_torque,"physical COM event torque matches independent law")
			check(compound[tick].arrival_count==split[tick].arrival_count and compound[tick].event_raw==split[tick].event_raw,"shared seam cannot duplicate raw event or transport witness "+arm)
			check(compound[tick].event_accepted==split[tick].event_accepted,"decomposition cannot multiply accepted event budget "+arm)
			near(compound[tick].event_torque,split[tick].event_torque,"split geometry retains one physical event moment")
			check(float(compound[tick].event_budget_cost)<=float(compound[tick].global_capacity)+1e-8,"event consumes one physical budget")
		if arm=="off":
			for row: Dictionary in compound: check(row.event_accepted==Vector2.ZERO and row.event_budget_cost==0.,"events off suppresses event force/torque/cost")
		if arm=="selective":
			check(compound[0].arrival_count==0 and compound[0].event_accepted==Vector2.ZERO,"direct authoring grants no transport witness")
			check(compound[1].arrival_count==1 and Vector2(compound[1].event_accepted).length()>0 and absf(compound[1].event_torque)>0,"fresh falling grain recovers one loading/torque arrival")
			check(compound[2].arrival_count==0 and compound[3].arrival_count==0 and compound[2].event_accepted==Vector2.ZERO,"blocked attempts cannot renew selective arrival")
		var water: Array[Dictionary]=arrivals(arm,true,false,3)
		var hard: Array[Dictionary]=arrivals(arm,true,false,1)
		for tick: int in range(4):
			check(water[tick].event_raw==Vector2.ZERO and water[tick].event_accepted==Vector2.ZERO and water[tick].arrival_count==0,"Water alone cannot grant granular bearing/arrival")
			check(hard[tick].event_raw==Vector2.ZERO and hard[tick].event_accepted==Vector2.ZERO and hard[tick].arrival_count==0,"hard terrain keeps its separate collision owner")
	for tick: int in range(4):
		check(populations.control[tick].event_raw==populations.off[tick].event_raw and populations.off[tick].event_raw==populations.selective[tick].event_raw,"C/E/S raw native contact mechanism unchanged")
	reports.append({"event_modes":["control","off","selective"],"proxies":[1,2],"samples":4})

func negative_controls() -> void:
	var g:=PackedFloat64Array([0,0,5,1])
	for arm: String in ["control","off","selective"]:
		for material: int in [2,3,1]:
			var native: Object=world(arm)
			native.diagnostic_fill_rect(Vector2i(127,129),Vector2i(5,12),material)
			var before: Dictionary=snapshot(native)
			var packed: PackedFloat64Array=states(g,1,Vector2(129.5,128.5),0.,SESSION,.1,1.)
			packed[7]=30.
			check(native.prepare_gcr_authored_compound_coupling(packed,g,identity(),true),"downward-bearing negative/positive fixture "+arm)
			check(native.gcr_compound_results().size()==14,"negative control produces one physical response")
			var d: Dictionary=native.gcr_compound_diagnostics()
			if material==2:
				check(float(d.normal_accepted)>0 and float(d.source_capacity)>0,"Sand positive control actually admits bearing")
			else:
				check(float(d.normal_accepted)==0 and float(d.source_capacity)==0 and d.event_raw==Vector2.ZERO,"Water/hard controls cannot grant granular support")
			check(snapshot(native).counts==before.counts and snapshot(native).water_mass==before.water_mass,"negative-control preparation conserves exact material quantities")
			native=null

func _run() -> void:
	var probe: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check(probe!=null and probe.has_method("prepare_gcr_authored_compound_coupling") and probe.has_method("retire_gcr_authored_compound"),"source-matched native authored API exists"):
		quit(1);return
	probe=null
	protocol()
	geometry_and_material()
	event_controls()
	negative_controls()
	print("GCR_AUTHORED_COMPOUND_NATIVE ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports}))
	quit(0 if failures.is_empty() else 1)
