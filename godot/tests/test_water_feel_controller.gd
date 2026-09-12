extends SceneTree

var failures: int=0

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures+=1
	push_error(message)

func _wait_applied(controller: Control, expected_hash: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+15_000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if (controller.pending_water_apply.is_empty()
			and str(controller.tower_context.get("water_policy_hash",""))==expected_hash):
			return true
	return false

func _policy(scenario_id: String, bits: int=5) -> Dictionary:
	return CyberWaterExperimentProfiles.resolve({},{},{"scenario_id":scenario_id,
		"mass_bits":bits,"coherence_ticks":7,"interface_mode":"oriented","seed":441})

func _run() -> void:
	var scene: PackedScene=load("res://main.tscn")
	_expect(scene!=null,"desktop Water controller scene did not load")
	if scene==null: quit(failures);return
	var controller: Control=scene.instantiate()
	root.add_child(controller)
	await process_frame

	var supported: Dictionary=_policy("supported-body-water")
	controller.water_lab_apply_result(supported)
	_expect(await _wait_applied(controller,str(supported.hash)),
		"supported-body Water Apply + Reset was not acknowledged")
	_expect(controller.rigid_bodies.size()==3,"supported-body scenario did not activate bodies")

	var ordinary: Dictionary=_policy("shallow-pool")
	controller.water_lab_apply_result(ordinary)
	_expect(await _wait_applied(controller,str(ordinary.hash)),
		"ordinary Water Apply + Reset was not acknowledged")
	_expect(controller.rigid_bodies.is_empty(),"ordinary Water scenario retained scene bodies")
	_expect(not controller.rapier_bridge.is_initialized(),"ordinary Water scenario retained Rapier")
	for body: RigidBody2D in [controller.test_rigid_body_1,
		controller.test_rigid_body_2,controller.test_rigid_body_3]:
		_expect(body.freeze,"ordinary Water scenario left a body active")
		_expect(body.collision_layer==0 and body.collision_mask==0,
			"ordinary Water scenario retained Godot collision participation")

	controller.paused=false
	var previous_hash: String=str(controller.tower_context.water_policy_hash)
	controller.pending_water_apply={"hash":"forced-invalid","previous_paused":false}
	controller.paused=true
	controller.tower_command({"water_reset":true,"water_policy":{"mass_bits":2},
		"water_policy_hash":"forced-invalid"})
	var rejection_deadline: int=Time.get_ticks_msec()+15_000
	while Time.get_ticks_msec()<rejection_deadline and not controller.pending_water_apply.is_empty():
		await process_frame
	_expect(controller.pending_water_apply.is_empty(),"rejected Water reset remained pending")
	_expect(not controller.paused,"rejected Water reset did not restore prior pause state")
	_expect(str(controller.tower_context.water_policy_hash)==previous_hash,
		"rejected Water reset changed the prior policy")

	var blind_candidates: Array[int]=[3,5]
	_expect(controller.water_lab_prepare_blind(blind_candidates,773),"blind run did not start")
	var label: String=str(controller.pending_water_apply.get("blind_label",""))
	var hidden_hash: String=str(controller.pending_water_apply.get("hash",""))
	_expect(not label.is_empty(),"blind run exposed no anonymous label")
	_expect(await _wait_applied(controller,hidden_hash),"blind candidate was not acknowledged")
	_expect(not controller.water_lab_save_profile(),"blind candidate could be saved before reveal")
	_expect(not str(controller.tower_context.status).contains(hidden_hash.left(12)),
		"ordinary blind status exposed the hidden policy hash")
	controller.water_lab_reset()
	_expect(await _wait_applied(controller,hidden_hash),"blind reset was not acknowledged")
	_expect(controller.water_active_blind_label==label,"blind reset changed/revealed its label")
	_expect(str(controller.tower_context.water_blind_label)==label,
		"worker metadata lost the blind label on reset")
	controller.tower_reset()
	_expect(controller.water_blind_set.is_empty(),"Fresh tower retained blind mapping")
	_expect(controller.water_active_blind_label.is_empty(),"Fresh tower retained blind label")
	_expect(str(controller.water_policy_resolved.hash)==previous_hash,
		"Fresh tower retained the hidden candidate instead of the pre-blind policy")
	_expect(controller.water_lab_save_profile(),"Fresh tower could not save the restored unblinded policy")

	controller.simulation_worker.stop_worker()
	controller.rapier_bridge.shutdown()
	controller.queue_free()
	await process_frame
	if failures==0:
		print("WATER_FEEL_CONTROLLER: transactional rejection/body collision isolation/blind lifecycle passed")
	quit(failures)
