extends SceneTree

# Registered native-only geometry replay. These are copied pose samples, not
# live Rapier motion, kernel ticks, force efficacy or persistent particle IDs.
const REGISTRATION: String="GCR-CARRY-002"
const SESSION: int=773
const OLD_COM:=Vector2(512,250)
const SEED:=Vector2i(512,248)
const GEOMETRY: Array=[0.,0.,26.,2.]
const ROI:=Rect2i(480,218,64,64)
var checks: int=0
var failures: Array[String]=[]
var reports: Array[Dictionary]=[]

func _init() -> void: call_deferred("_run")

func check(ok: bool, why: String) -> bool:
	checks+=1
	if not ok:
		failures.append(why)
		printerr("FAIL SCOOPER EJECTION REPLAY: ",why)
	return ok

func options(arm: String, authored: bool) -> Dictionary:
	return {"workers":1,"telemetry":true,"bearing_candidate":"GCR-REST",
		"bearing_experiment":"GCR-REST-001-2026-11-02","gcr_rest_mode":"control",
		"gcr_base_budget":20.,"gcr_rest_gravity":38.,
		"gcr_granular_events":arm,"gcr_event_experiment":"GCR-SEL-001-2026-11-04",
		"gcr_authored_compound":authored}

func packet(com: Vector2, serial: int) -> PackedFloat64Array:
	# Assigned mass/inertia are the same in every arm. Velocity stays zero:
	# only the copied geometry moves, isolating preparation's relocation rule.
	return PackedFloat64Array([1,com.x,com.y,0.,26.,2.,0.,0.,0.,.18,serial,
		10.2,com.x,com.y,.8,1./60.,SESSION])

func prepare(native: Object, com: Vector2, serial: int, authored: bool) -> bool:
	var values:=packet(com,serial)
	if authored:
		return native.prepare_gcr_authored_compound_coupling(values,PackedFloat64Array(GEOMETRY),
			{"version":1,"session_id":SESSION,"body_generation":1},true)
	return native.prepare_gcr_coupling(values,true)

func grain_set(native: Object) -> Array[Vector2i]:
	var found: Array[Vector2i]=[]
	var observed: Dictionary=native.diagnostic_snapshot(ROI.position,ROI.size,false,false)
	if not check(not observed.is_empty(),"bounded stored-cell snapshot admitted"): return found
	var cells: PackedByteArray=observed.cells
	var offset: int=cells.find(2)
	while offset>=0:
		found.append(ROI.position+Vector2i(offset%ROI.size.x,offset/ROI.size.x))
		offset=cells.find(2,offset+1)
	return found

func census(native: Object) -> Dictionary:
	# Diagnostic world is1024x1024. Four disjoint512x512 stored-cell
	# observations cover it exactly; masked cells remain material authority.
	var result: Dictionary={}
	for origin: Vector2i in [Vector2i.ZERO,Vector2i(512,0),Vector2i(0,512),Vector2i(512,512)]:
		var tile: Dictionary=native.diagnostic_snapshot(origin,Vector2i(512,512),false,false)
		if not check(not tile.is_empty(),"global stored-cell census tile admitted"): return {}
		if result.is_empty():
			result={"counts":tile.counts.duplicate(),"water_mass":int(tile.water_mass)}
		else:
			check(result.counts.size()==tile.counts.size(),"global material schema matches")
			for index: int in range(tile.counts.size()): result.counts[index]+=int(tile.counts[index])
			result.water_mass+=int(tile.water_mass)
	return result

func location(cell: Vector2i, com: Vector2) -> Dictionary:
	var local: Vector2=Vector2(cell)+Vector2(.5,.5)-com
	var inside: bool=absf(local.x)<=13. and absf(local.y)<=1.
	var side: String="inside"
	if not inside:
		if local.x< -13.: side="left"
		elif local.x>13.: side="right"
		elif local.y< -1.: side="above"
		else: side="below"
	return {"cell":[cell.x,cell.y],"centre":[cell.x+.5,cell.y+.5],
		"local":[local.x,local.y],"inside":inside,"side":side}

func population(arm: String, authored: bool, advance: float) -> void:
	var label: String="%s/%s/up%s" % [arm,"authored" if authored else "independent",advance]
	var native: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check(native!=null,"actual native owner "+label): return
	if not check(native.diagnostic_reset(options(arm,authored)),"fresh explicit construction "+label):
		native=null;return
	native.set_simulation_window_enabled(false)
	native.set_cadence_lod_enabled(false)
	check(native.diagnostic_fill_rect(SEED,Vector2i.ONE,2),"seed exactly one actual Sand cell "+label)
	var old_tick: int=native.get_tick_index()
	var first_admitted: bool=prepare(native,OLD_COM,1,authored)
	check(first_admitted,"old pose sample1 admitted "+label)
	var before: Array[Vector2i]=grain_set(native)
	var before_quantity:=census(native)
	check(before==[SEED],"old pose leaves the above-deck seed unchanged "+label)
	check(not before_quantity.is_empty() and int(before_quantity.counts[2])==1 and int(before_quantity.water_mass)==0,"initial global Sand/Water quantity "+label)
	if not before_quantity.is_empty():
		check(int(before_quantity.counts[0])==1024*1024-1,"fresh world contains only the registered grain "+label)
	var new_com: Vector2=OLD_COM-Vector2(0,advance)
	var second_admitted: bool=prepare(native,new_com,2,authored)
	check(second_admitted,"translated pose sample2 admitted "+label)
	# Observe stored endpoints immediately after the existing preparation. No
	# simulation_tick, result getter or body evaluator intervenes.
	var after: Array[Vector2i]=grain_set(native)
	var after_quantity:=census(native)
	check(not before_quantity.is_empty() and after_quantity==before_quantity,"exact global native material/Water conservation "+label)
	check(after.size()==1,"the one grain remains in the bounded endpoint observation "+label)
	check(native.get_tick_index()==old_tick and old_tick==0,"both preparations advance no native tick "+label)
	check(not native.has_failed(),"preparation remains healthy "+label)
	var endpoint: Variant=null
	var displacement: Variant=null
	var wrong_side: Variant=null
	if after.size()==1:
		endpoint={"relative_old":location(after[0],OLD_COM),"relative_current":location(after[0],new_com),
			"native_current_mask":native.rigid_body_id_at(after[0].x,after[0].y)}
		displacement=[after[0].x-SEED.x,after[0].y-SEED.y]
		wrong_side=endpoint.relative_current.side=="below" and absf(float(endpoint.relative_current.local[0]))<13.
		check((int(endpoint.native_current_mask)>0)==bool(endpoint.relative_current.inside),"actual native mask matches current rectangle at endpoint "+label)
	var before_geometry: Dictionary=location(SEED,OLD_COM)
	var encountered_geometry: Dictionary=location(SEED,new_com)
	reports.append({"arm":arm,"admission":"authored-single-rectangle" if authored else "independent",
		"advance_up_cells":advance,"old_com":[OLD_COM.x,OLD_COM.y],"current_com":[new_com.x,new_com.y],
		"geometry":[0.,0.,26.,2.],"mass":.18,"inertia":10.2,"copied_velocity":[0.,0.],
		"samples":[1,2],"session_id":SESSION,"body_generation":1 if authored else null,
		"admitted":[first_admitted,second_admitted],"native_ticks":[old_tick,native.get_tick_index()],
		"before":before_geometry,"seed_relative_current_before_prepare":encountered_geometry,
		"after":endpoint,"relocation_cells":displacement,"observed_closed_deck_wrong_side":wrong_side,
		"quantity_before":before_quantity,"quantity_after":after_quantity,"native_failed":native.has_failed(),
		"aggregate_overlap":null,"aggregate_displaced":null,"endpoint_reason_census":null,
		"unavailable_diagnostics":"No force-result/per-proxy evaluation is requested. Cell endpoints directly observe relocation; response counters remain uncomputed."})
	native=null

func _run() -> void:
	for arm: String in ["control","off","selective"]:
		for authored: bool in [false,true]:
			for advance: float in [0.,.5,1.,1.5,2.,3.]: population(arm,authored,advance)
	check(reports.size()==36,"all registered36 native-only replay cases acquired")
	var report: Dictionary={"registration":REGISTRATION,"checks":checks,"failures":failures,"reports":reports,
		"source":OS.get_environment("CYBERSAND_SOURCE_REVISION"),"platform":OS.get_name(),
		"engine_version":Engine.get_version_info().string,
		"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),
		"scope":"Native copied geometry only; no live Rapier body, native tick, response application, invented grain identity or material-law change. Wrong-side flags are physical results, not renamed apparatus failures."}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var output:=FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE)
			if check(output!=null,"replay output admitted"):
				report.checks=checks
				output.store_string(JSON.stringify(report));output.close()
	report.checks=checks
	print("GCR_SCOOPER_EJECTION_REPLAY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
