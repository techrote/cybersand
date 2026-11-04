extends SceneTree

var failures: Array[String] = []
var checks: int = 0
func _init() -> void: call_deferred("_run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason); push_error(reason)
func _run() -> void:
	var scene = load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	check(scene.response_select.item_count==3 and scene.response_select.selected==0,"three responses, LA remains default")
	check(scene.applied_controls.response=="LA","initial applied control")
	check(scene.event_runtime_identity.contains("verified"),"actual runtime artifact verified against source provenance")
	scene.response_select.select(2)
	check(scene.apply_controls(),"actual UI applies event-off through fresh construction")
	check(scene.applied_controls.response=="LA-EVENT-OFF" and scene.runtime._arena._world.gcr_diagnostics().granular_events=="off","UI/native selector agreement")
	check(scene.paint_at(Vector2i(150,150),23),"material painting with event-off")
	var painted: Dictionary = scene.runtime._arena._world.diagnostic_snapshot(Vector2i(150,150),Vector2i.ONE,false,false)
	check(int(painted.cells[0])==23,"paint reaches native authority")
	check(scene.paint_at(Vector2i(150,150),0),"erase with event-off")
	var erased: Dictionary = scene.runtime._arena._world.diagnostic_snapshot(Vector2i(150,150),Vector2i.ONE,false,false)
	check(int(erased.cells[0])==0,"erase reaches native authority")
	for index: int in range(7):
		check(scene.select_preset(index),"event-off craft selection")
		check(scene.applied_controls.response=="LA-EVENT-OFF" and scene.runtime._arena._world.gcr_diagnostics().granular_events=="off","craft selection retains actual selector")
	scene.restore_controls()
	check(scene.response_select.selected==0 and scene.applied_controls.response=="LA" and scene.runtime._arena._world.gcr_diagnostics().granular_events=="control","restore resets to baseline LA")
	scene.response_select.select(1)
	check(scene.apply_controls() and scene.runtime._arena._world.get_gcr_admission_variant()=="R2","RFT retained as separate reference")
	scene.queue_free()
	await process_frame
	print("GCR_EVENT_PLAYGROUND ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
