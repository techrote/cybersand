extends SceneTree

# Native response metadata only. The separate Scooper stream regression checks
# the actual strict Rapier bridge for the original 900-tick gameplay trajectory.
var checks: int=0
var failures: Array[String]=[]
var reports: Array[Dictionary]=[]
const SESSION: int=97

func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures.append(why);printerr("FAIL NO-CATCH RECEIPT: ",why)

func packet(geometry: PackedFloat64Array,serial: int,velocity: Vector2,omega: float) -> PackedFloat64Array:
	var values:=PackedFloat64Array()
	for i: int in range(geometry.size()/4):
		var k: int=i*4
		values.append_array(PackedFloat64Array([i+1,128.5+geometry[k],128.5+geometry[k+1],0.,
			geometry[k+2],geometry[k+3],velocity.x,velocity.y,omega,.18,serial,22.0998687744141,
			128.5,128.5,.8,1./60.,SESSION]))
	return values

func population(arm: String,compound: bool) -> void:
	var native: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	check(native!=null,"actual native class exists")
	if native==null: return
	check(native.diagnostic_reset({"workers":1,"telemetry":true,"bearing_candidate":"GCR-REST",
		"bearing_experiment":"GCR-REST-001-2026-11-02","gcr_rest_mode":"control",
		"gcr_base_budget":20.,"gcr_rest_gravity":38.,"gcr_granular_events":arm,
		"gcr_event_experiment":"GCR-SEL-001-2026-11-04","gcr_authored_compound":compound}),"fresh native owner "+arm)
	native.set_simulation_window_enabled(false)
	native.set_cadence_lod_enabled(false)
	# Local supported deck plus falling top grains supplies both a passive and
	# an event contribution, without changing any material or response law.
	check(native.diagnostic_fill_rect(Vector2i(120,132),Vector2i(18,14),2),"real granular support")
	check(native.diagnostic_fill_rect(Vector2i(125,118),Vector2i(7,8),2),"real falling granular load")
	check(native.diagnostic_fill_rect(Vector2i(119,116),Vector2i(1,31),1),"hard left containment")
	check(native.diagnostic_fill_rect(Vector2i(138,116),Vector2i(1,31),1),"hard right containment")
	check(native.diagnostic_fill_rect(Vector2i(119,146),Vector2i(20,1),1),"hard bed backing")
	var geometry:=PackedFloat64Array([0.,2.,12.,2.,-5.,-2.,2.,6.,5.,-2.,2.,6.]) if compound else PackedFloat64Array([0.,2.,12.,2.])
	# A one-rectangle independent body is centred on its own COM; the compound
	# uses the uniform-area-centred three-rectangle bowl from native API tests.
	if not compound: geometry=PackedFloat64Array([0.,0.,12.,2.])
	var simultaneous: int=0
	var rounding_cases: int=0
	var max_event: float=0.
	var max_passive: float=0.
	for tick: int in range(48):
		var velocity:=Vector2((tick%7-3)*.0137,.384452790021896 if tick%2 else -.384452790021896)
		var values: PackedFloat64Array=packet(geometry,tick+1,velocity,.0457497984170914)
		var admitted: bool=native.prepare_gcr_authored_compound_coupling(values,geometry,
			{"version":1,"session_id":SESSION,"body_generation":1},true) if compound else native.prepare_gcr_coupling(values,true)
		check(admitted and native.simulation_tick(),"fresh bounded native sample "+arm)
		var result: PackedFloat64Array=native.gcr_compound_results() if compound else native.gcr_body_results()
		check(result.size()==14,"one actual native wrench")
		if result.size()!=14: break
		var diagnostics: Dictionary=native.gcr_diagnostics()
		var response: Dictionary=diagnostics if compound else diagnostics.get("bodies",[{}])[0]
		var physical_before: String=native.get_physical_state_hash()
		var receipt: Dictionary=native.gcr_rest_receipt()
		check(receipt.get("bodies",[]).size()==1,"one native rest receipt")
		if receipt.get("bodies",[]).size()!=1: break
		var row: Dictionary=receipt.bodies[0]
		check(not row.catch_applied and not row.catch_admitted,"control mode applies no catch")
		check(row.catch_delta_impulse==Vector2.ZERO and float(row.catch_delta_torque)==0.,"no catch exports exact zero catch delta")
		check(row.uncaught_impulse==Vector2(result[1],result[2]) and float(row.uncaught_torque)==result[9],"uncaught metadata is the actual exported physical wrench")
		var again: PackedFloat64Array=native.gcr_compound_results() if compound else native.gcr_body_results()
		check(again==result and native.get_physical_state_hash()==physical_before,"receipt reading changes no result or physical state")
		var event: Vector2=response.get("event_accepted",Vector2.ZERO)
		var passive: Vector2=response.passive_impulse if compound else Vector2(response.normal_impulse)+Vector2(response.tangent_impulse)
		max_event=maxf(max_event,event.length())
		max_passive=maxf(max_passive,passive.length())
		if event!=Vector2.ZERO and passive!=Vector2.ZERO: simultaneous+=1
		# This is the old expression, retained only as a precision witness. Its
		# rounded components must never be treated as an actual extra catch.
		if compound:
			var reassembled: Vector2=Vector2(response.legacy_impulse)+event+passive
			if reassembled!=Vector2(result[1],result[2]): rounding_cases+=1
	reports.append({"arm":arm,"compound":compound,"samples":48,
		"simultaneous_event_and_passive":simultaneous,"component_rounding_witnesses":rounding_cases,
		"max_event":max_event,"max_passive":max_passive})
	if arm=="control" and compound:
		check(simultaneous>0,"fixture actually combines event and passive sources")
		check(rounding_cases>0,"fixture exposes double-to-Vector2 regrouping at the original defect")
	native=null

func _run() -> void:
	for arm: String in ["control","off","selective"]:
		population(arm,true)
		population(arm,false)
	print("GCR_NOCATCH_RECEIPT ",JSON.stringify({"checks":checks,"failures":failures,"reports":reports,
		"scope":"No-catch native metadata closure; actual forces and strict bridge remain independently checked"}))
	quit(0 if failures.is_empty() else 1)
