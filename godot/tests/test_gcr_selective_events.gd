extends SceneTree

const Prior = preload("res://qualification/gcr_granular_events_capture.gd")
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why); push_error(why)
func options(arm: String, workers: int = 1) -> Dictionary:
	var value: Dictionary = Prior.options(false,38.0)
	value.merge({"gcr_granular_events":arm,"gcr_event_experiment":"GCR-SEL-001-2026-11-04","workers":workers},true)
	return value
func witness(arm: String, workers: int, paint_again: bool = false, material: int = 2) -> Array:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset(options(arm,workers)),"fresh witness construction")
	world.diagnostic_fill_rect(Vector2i(128,125),Vector2i.ONE,material)
	world.diagnostic_fill_rect(Vector2i(127,125),Vector2i(1,3),1)
	world.diagnostic_fill_rect(Vector2i(129,125),Vector2i(1,3),1)
	var states := PackedFloat64Array([1,128.5,128.5,0,3,1,0,0,0,.1,1,.975,128.5,128.5,.8,1.0/60.0,1])
	var rows: Array = []
	for tick: int in range(4):
		if paint_again and tick==1: world.diagnostic_fill_rect(Vector2i(128,126),Vector2i.ONE,material)
		states[16]=tick+1
		check(world.prepare_gcr_coupling(states,false),"fresh mask boundary")
		check(world.simulation_tick(),"successful native tick")
		var d: Dictionary = world.gcr_diagnostics()
		check(d.granular_events==arm and d.arrival_witness and d.arrival_storage_bytes>0,"actual selector and bounded storage")
		rows.append(d.bodies[0])
	return rows
func _run() -> void:
	for workers: int in [1,4]:
		var c: Array = witness("control",workers)
		var e: Array = witness("off",workers)
		var s: Array = witness("selective",workers)
		check(s[0].arrival_count==0 and s[0].event_accepted==Vector2.ZERO,"painting itself cannot grant arrival")
		check(s[1].arrival_count==1 and Vector2(s[1].arrival_raw).length()>0,"one real incoming move grants one arrival across mask refresh")
		check(Vector2(s[1].event_accepted).length()>0,"fresh transport recovers delivered event")
		check(s[2].arrival_count==0 and s[3].arrival_count==0 and s[2].event_accepted==Vector2.ZERO,"repeated blocked attempts cannot refresh witness")
		check(c[1].event_raw==e[1].event_raw and e[1].event_raw==s[1].event_raw,"raw event remains unchanged in all arms")
		check(e[1].event_accepted==Vector2.ZERO and e[1].event_budget_cost==0.0,"E remains event free")
		var p: Array = witness("selective",workers,true)
		check(p[1].arrival_count==0 and p[1].event_accepted==Vector2.ZERO,"same-material direct paint retires transport authority")
		var water: Array = witness("selective",workers,false,3)
		check(water[1].arrival_count==0 and water[1].event_raw==Vector2.ZERO,"Water grants no granular arrival")
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset(options("selective")),"admission initial")
	var before: String = world.get_physical_state_hash()
	for override: Dictionary in [{"gcr_event_experiment":"GCR-EVT-001-2026-11-04"},{"gcr_event_experiment":"wrong"},{"gcr_rest_mode":"P"},{"gcr_granular_events":true}]:
		var value: Dictionary = options("selective"); value.merge(override,true)
		check(not world.diagnostic_reset(value) and world.get_physical_state_hash()==before,"invalid selector preserves owner")
	check(not world.prepare_gcr_compound_coupling(PackedFloat64Array(),{},false),"unqualified selective compound refuses")
	check(world.diagnostic_reset({}),"ordinary reset")
	check(not world.gcr_diagnostics().arrival_witness and world.gcr_diagnostics().arrival_storage_bytes==0,"ordinary owner has no witness sidecar")
	var scene = load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene);scene.set_physics_process(false);await process_frame
	check(scene.response_select.item_count==4 and scene.response_select.selected==0,"four explicit choices and LA default")
	scene.response_select.select(3)
	check(scene.apply_controls(),"UI applies selective through fresh native construction")
	for craft: int in range(7):
		check(scene.select_preset(craft),"selective craft selection")
		check(scene.runtime._arena._world.gcr_diagnostics().granular_events=="selective","UI/native selector agrees")
	check(scene.paint_at(Vector2i(150,150),23),"painting remains available")
	check(scene.paint_at(Vector2i(150,150),0),"erasing remains available")
	scene.restore_controls()
	check(scene.applied_controls.response=="LA" and not scene.runtime._arena._world.gcr_diagnostics().arrival_witness,"Restore retires experimental history")
	scene.queue_free();await process_frame
	print("GCR_SELECTIVE_EVENT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
