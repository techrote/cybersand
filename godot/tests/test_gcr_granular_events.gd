extends SceneTree

const Capture = preload("res://qualification/gcr_granular_events_capture.gd")
const Base = preload("res://qualification/gcr_creep_capture.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
var failures: Array[String] = []
var checks: int = 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures.append(why); push_error(why)

func witness(material: int, off: bool, legacy_zero: bool = false) -> Dictionary:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	var options: Dictionary = Capture.options(off,38.0)
	if legacy_zero: options.contact=0.0
	check(world.diagnostic_reset(options),"witness construction")
	world.diagnostic_fill_rect(Vector2i(128,127),Vector2i.ONE,material)
	world.diagnostic_fill_rect(Vector2i(127,127),Vector2i.ONE,1)
	world.diagnostic_fill_rect(Vector2i(129,127),Vector2i.ONE,1)
	var states := PackedFloat64Array([1,128.5,128.5,0,3,1,0,0,0,.1,1,.975,128.5,128.5,.8,1.0/60.0,1])
	check(world.prepare_gcr_coupling(states,false),"witness boundary")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(126,126),Vector2i(5,5),false,false)
	check(world.simulation_tick(),"witness native tick")
	var result: Dictionary = world.gcr_diagnostics()
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(126,126),Vector2i(5,5),false,false)
	check(before.water_mass==after.water_mass,"exact witness Water mass")
	return {"body":result.bodies[0],"selector":result.granular_events,"gain":result.legacy_contact_gain,
		"hash":world.get_physical_state_hash(),"before":before,"after":after}

func _run() -> void:
	var c: Dictionary = witness(2,false)
	var e: Dictionary = witness(2,true)
	var z: Dictionary = witness(2,false,true)
	check(c.selector=="control" and e.selector=="off" and e.gain==.025,"selector and unchanged legacy gain readback")
	check(c.hash==e.hash and c.before.cells==e.before.cells and c.after.cells==e.after.cells,"selector leaves physical native material/attempt state identical")
	check(c.body.event_raw==e.body.event_raw and Vector2(c.body.event_raw).length()>0,"raw attempted granular impulse retained")
	check(e.body.event_accepted==Vector2.ZERO and e.body.event_torque==0.0 and e.body.event_budget_cost==0.0,"granular J/L and cost omitted before passive solve")
	check(e.body.normal_impulse==z.body.normal_impulse and e.body.tangent_impulse==z.body.tangent_impulse,"powder-only event-off passive result matches prior gain-zero treatment")
	var wc: Dictionary = witness(3,false)
	var we: Dictionary = witness(3,true)
	check(wc.hash==we.hash and wc.body.legacy_non_granular==we.body.legacy_non_granular,"Water legacy/material path retained")
	check(Vector2(wc.body.legacy_non_granular).length()>0,"Water legacy control exercises nonzero response")
	check(we.body.event_raw==Vector2.ZERO and we.body.event_accepted==Vector2.ZERO,"Water alone supplies no granular event")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset(Capture.options(true,38.0)),"admission initial candidate")
	var original: String = world.get_physical_state_hash()
	for override: Dictionary in [{"gcr_granular_events":true},{"gcr_granular_events":"unknown"},{"gcr_event_experiment":"wrong"},{"gcr_rest_mode":"P"},{"bearing_candidate":"Y1","bearing_experiment":"Y1-ENVELOPE-2026-11-01"}]:
		var options: Dictionary = Capture.options(true,38.0)
		options.merge(override,true)
		check(not world.diagnostic_reset(options) and world.get_physical_state_hash()==original,"invalid event admission preserves original authority")
	var missing: Dictionary = Capture.options(true,38.0)
	missing.erase("gcr_event_experiment")
	check(not world.diagnostic_reset(missing),"missing token refused")
	check(not world.prepare_gcr_compound_coupling(PackedFloat64Array(),{},false),"unqualified event-off compound admission refuses")
	check(world.diagnostic_reset({}),"ordinary reset")
	check(world.gcr_diagnostics().granular_events=="control","ordinary reset retires event selector")
	var runtime = Runtime.new()
	root.add_child(runtime)
	var controls: Dictionary = {"response":"LA-EVENT-OFF","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0}
	for index: int in range(7):
		check(runtime.configure_review_fleet(index,controls),"fresh event-off craft "+str(index))
		check(runtime._arena._world.gcr_diagnostics().granular_events=="off","actual fleet native selector")
		check(runtime._arena.reset() and runtime._arena._world.gcr_diagnostics().granular_events=="off","fleet reset retains explicit candidate")
	runtime.close()
	runtime.free()
	print("GCR_GRANULAR_EVENT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
