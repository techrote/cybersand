extends SceneTree

# Requires the rebuilt entry-side candidate. Actual native endpoints exercise
# admission/fallback without exposing a second solver or mutable observer API.
const SESSION: int=881
const SEED:=Vector2i(512,248)
const COM:=Vector2(512,250)
var checks: int=0
var failures: Array[String]=[]
var reports: Array[Dictionary]=[]

func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> bool:
	checks+=1
	if not ok: failures.append(why);printerr("FAIL SCOOPER ENTRY SIDE: ",why)
	return ok
func options(arm: String="selective",authored: bool=true) -> Dictionary:
	return {"workers":1,"telemetry":true,"bearing_candidate":"GCR-REST",
		"bearing_experiment":"GCR-REST-001-2026-11-02","gcr_rest_mode":"control",
		"gcr_base_budget":20.,"gcr_rest_gravity":38.,"gcr_granular_events":arm,
		"gcr_event_experiment":"GCR-SEL-001-2026-11-04","gcr_authored_compound":authored}
func packet(g: PackedFloat64Array,com: Vector2,angle: float,serial: int,session: int=SESSION) -> PackedFloat64Array:
	var values:=PackedFloat64Array()
	for i: int in range(g.size()/4):
		var k: int=i*4
		var centre: Vector2=com+Vector2(g[k],g[k+1]).rotated(angle)
		values.append_array(PackedFloat64Array([i+1,centre.x,centre.y,angle,g[k+2],g[k+3],0.,0.,0.,
			.18,serial,10.2,com.x,com.y,.8,1./60.,session]))
	return values
func prepare(native: Object,g: PackedFloat64Array,com: Vector2,angle: float,serial: int,authored: bool,session: int=SESSION,resolve: bool=true) -> bool:
	var values:=packet(g,com,angle,serial,session)
	return native.prepare_gcr_authored_compound_coupling(values,g,{"version":1,"session_id":session,"body_generation":1},resolve) if authored else native.prepare_gcr_coupling(values,resolve)
func census(native: Object) -> Dictionary:
	var result: Dictionary={}
	for origin: Vector2i in [Vector2i.ZERO,Vector2i(512,0),Vector2i(0,512),Vector2i(512,512)]:
		var tile: Dictionary=native.diagnostic_snapshot(origin,Vector2i(512,512),false,false)
		if not check(not tile.is_empty(),"complete native census tile"): return {}
		if result.is_empty(): result={"counts":tile.counts.duplicate(),"water_mass":int(tile.water_mass)}
		else:
			for i: int in range(tile.counts.size()): result.counts[i]+=int(tile.counts[i])
			result.water_mass+=int(tile.water_mass)
	return result
func coordinates(native: Object,material: int=2) -> Array[Vector2i]:
	var found: Array[Vector2i]=[]
	var s: Dictionary=native.diagnostic_snapshot(Vector2i(448,192),Vector2i(128,128),false,false)
	if not check(not s.is_empty(),"bounded actual endpoint observation"): return found
	var cells: PackedByteArray=s.cells
	var at: int=cells.find(material)
	while at>=0:
		found.append(Vector2i(448+at%128,192+at/128));at=cells.find(material,at+1)
	return found
func run_case(label: String,g: PackedFloat64Array,old_com: Vector2,new_com: Vector2,
		old_angle: float=0.,new_angle: float=0.,serial: int=2,authored: bool=true,
		retain_first_overlap: bool=false,hard_barrier: bool=false,arm: String="selective") -> Dictionary:
	var native: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check(native!=null,"native candidate exists "+label): return {}
	check(native.diagnostic_reset(options(arm,authored)),"fresh native candidate "+label)
	native.set_simulation_window_enabled(false);native.set_cadence_lod_enabled(false)
	check(native.diagnostic_fill_rect(SEED,Vector2i.ONE,2),"seed registered grain before any mask "+label)
	if hard_barrier: check(native.diagnostic_fill_rect(Vector2i(492,246),Vector2i(40,1),1),"hard entry-side barrier "+label)
	# Initial overlap is an explicit existing-penetration control: seed before
	# masks, then prime sample1 without resolution. Live masked authoring refuses
	# nonempty writes and cannot create this fixture after admission.
	check(prepare(native,g,old_com,old_angle,1,authored,SESSION,not retain_first_overlap),"initial admitted sample "+label)
	var before:=census(native)
	check(coordinates(native)==[SEED],"fixture grain starts at recorded coordinate "+label)
	check(prepare(native,g,new_com,new_angle,serial,authored),"new admitted sample "+label)
	var after: Array[Vector2i]=coordinates(native)
	check(after.size()==1,"one observed grain endpoint "+label)
	check(census(native)==before,"exact global native quantity "+label)
	check(native.get_tick_index()==0 and not native.has_failed(),"no native tick or quarantine "+label)
	var endpoint: Vector2i=after[0] if after.size()==1 else Vector2i(-1,-1)
	var result: Dictionary={"case":label,"arm":arm,"authored":authored,"endpoint":endpoint,
		"seed":SEED,"old_com":old_com,"new_com":new_com,"angles":[old_angle,new_angle],"samples":[1,serial]}
	reports.append({"case":label,"arm":arm,"authored":authored,"endpoint":[endpoint.x,endpoint.y],
		"seed":[SEED.x,SEED.y],"old_com":[old_com.x,old_com.y],"new_com":[new_com.x,new_com.y],
		"angles":[old_angle,new_angle],"samples":[1,serial],"quantity":before,
		"initial_sequence":"seed before mask; sample1 resolve=false; sample2 resolve=true" if retain_first_overlap else "seed before mask; both samples resolve=true",
		"scope":"Actual prepare endpoint; no response getter, mutable evaluator or native tick."})
	native=null
	return result

func reset_and_owner_fence(g: PackedFloat64Array) -> void:
	var native: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	check(native!=null and native.diagnostic_reset(options()),"fresh fenced authored owner")
	check(native.diagnostic_fill_rect(SEED,Vector2i.ONE,2) and prepare(native,g,COM,0.,1,true),"prime history before retirement")
	check(native.retire_gcr_authored_compound({"version":1,"session_id":SESSION,"body_generation":1}),"retire old authored owner")
	check(native.diagnostic_reset(options()),"reset clears old geometric history")
	check(native.diagnostic_fill_rect(SEED,Vector2i.ONE,2),"new reset fixture")
	var before:=census(native)
	check(not prepare(native,g,COM-Vector2(0,2),0.,2,true),"retired session cannot revive its old witness")
	check(coordinates(native)==[SEED] and census(native)==before,"rejected retired history preserves material")
	check(prepare(native,g,COM-Vector2(0,2),0.,1,true,SESSION+1),"fresh session admits without old witness")
	var after: Array[Vector2i]=coordinates(native)
	check(after.size()==1 and after[0].y>SEED.y,"fresh first sample keeps nearest-face fallback")
	var state: String=native.get_physical_state_hash()
	var foreign:=packet(g,COM-Vector2(0,4),0.,2,SESSION+1)
	check(not native.prepare_gcr_coupling(foreign,true),"foreign independent admission cannot acquire authored owner")
	check(native.get_physical_state_hash()==state and coordinates(native)==after,"mixed-owner refusal cannot move material")
	check(native.get_tick_index()==0 and not native.has_failed(),"fencing controls do not tick or quarantine")
	native=null

func _run() -> void:
	var g:=PackedFloat64Array([0.,0.,26.,2.])
	for arm: String in ["control","off","selective"]:
		var authored: Dictionary=run_case("entry-up2-"+arm,g,COM,COM-Vector2(0,2),0.,0.,2,true,false,false,arm)
		var independent: Dictionary=run_case("independent-up2-"+arm,g,COM,COM-Vector2(0,2),0.,0.,2,false,false,false,arm)
		check(not authored.is_empty() and authored.endpoint.y<SEED.y,"authored fresh crossing preserves upper entry side "+arm)
		check(not independent.is_empty() and independent.endpoint==Vector2i(512,251),"independent nearest-face control remains exact "+arm)
	for angle: float in [PI*.5,.4]:
		var seed_centre:=Vector2(SEED)+Vector2(.5,.5)
		var old: Vector2=seed_centre-Vector2(.5,-1.5).rotated(angle)
		var current: Vector2=old-Vector2(0,2).rotated(angle)
		var r: Dictionary=run_case("fixed-angle-"+str(angle),g,old,current,angle,angle)
		var local: Vector2=(Vector2(r.endpoint)+Vector2(.5,.5)-current).rotated(-angle)
		check(local.y< -1.,"unchanged rotated orientation preserves its local entry face")
	for variant: String in ["changed-angle","serial-gap","previous-inside","over-sweep-bound"]:
		var old: Vector2=COM+Vector2(0,31) if variant=="over-sweep-bound" else COM
		var current: Vector2=COM-Vector2(0,2)
		var serial: int=3 if variant=="serial-gap" else 2
		var angle: float=.00001 if variant=="changed-angle" else 0.
		var retained: bool=variant=="previous-inside"
		if retained: old=Vector2(512,249);current=Vector2(512,248)
		var a: Dictionary=run_case(variant,g,old,current,0.,angle,serial,true,retained)
		var b: Dictionary=run_case(variant+"-independent",g,old,current,0.,angle,serial,false,retained)
		check(a.endpoint==b.endpoint,"unwitnessed case retains exact independent fallback: "+variant)
	var seam:=PackedFloat64Array([-6.25,0.,13.5,2.,6.75,0.,12.5,2.])
	var seam_result: Dictionary=run_case("shared-seam",seam,COM,COM-Vector2(0,2))
	check(seam_result.endpoint.x>SEED.x,"shared seam refuses new entry witness and retains nearest side")
	# A separate thin piece lies across the relative-point path before the deck.
	# The seed is outside the entire old union, so the intersection guard matters.
	var intercepted:=PackedFloat64Array([0.,5./6.,26.,2.,0.,-5./3.,26.,1.])
	var intercepted_result: Dictionary=run_case("intervening-proxy",intercepted,Vector2(512,252.-5./6.),Vector2(512,248.-5./6.))
	check(intercepted_result.endpoint.y>SEED.y,"another proxy on the segment refuses the local entry witness")
	var blocked: Dictionary=run_case("hard-entry-side-barrier",g,COM,COM-Vector2(0,2),0.,0.,2,true,false,true)
	check(blocked.endpoint==SEED,"entry-side search cannot tunnel through hard terrain or fall back to far side")
	reset_and_owner_fence(g)
	print("GCR_SCOOPER_ENTRY_SIDE ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports,
		"scope":"Witnessed authored translation only. Foreign independent admission is refused; no foreign mask is fabricated. Rotation/seams remain fallback, not general union CCD."}))
	quit(0 if failures.is_empty() else 1)
