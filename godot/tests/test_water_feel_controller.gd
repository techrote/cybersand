extends SceneTree

const CyberWaterExperimentProfiles=preload("res://scripts/water_experiment_profiles.gd")

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

func _wait_ordinary(controller: Control) -> bool:
	var deadline: int=Time.get_ticks_msec()+15_000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if (controller.pending_water_apply.is_empty()
			and controller.pending_water_exit.is_empty()
			and not bool(controller.tower_context.get("water_active",false))):
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
	var blind_mapping: Dictionary=controller.water_blind_set.hidden_mapping.duplicate(true)
	var blind_base_hash: String=str(controller.water_blind_base.get("hash",""))
	var nested_candidates: Array[int]=[7,8]
	_expect(not controller.water_lab_prepare_blind(nested_candidates,774),
		"nested desktop blind preparation was accepted")
	_expect(controller.water_blind_set.hidden_mapping==blind_mapping
		and str(controller.water_blind_base.get("hash",""))==blind_base_hash
		and controller.water_active_blind_label==label,
		"nested desktop blind preparation replaced the original session")
	var bypass: Dictionary=_policy("drips",7)
	controller.water_lab_apply_result(bypass)
	await process_frame
	_expect(str(controller.water_policy_resolved.hash)==hidden_hash
		and controller.water_blind_set.hidden_mapping==blind_mapping,
		"ordinary desktop policy apply bypassed the active blind session")
	_expect(not controller.water_lab_save_profile(),"blind candidate could be saved before reveal")
	_expect(not str(controller.tower_context.status).contains(hidden_hash.left(12)),
		"ordinary blind status exposed the hidden policy hash")
	controller.water_experiment_panel.hide()
	controller.water_lab_open()
	_expect(not controller.water_experiment_panel.visible,
		"ordinary policy editor opened during a desktop blind run")
	controller.tower_panel.refresh(true,controller.tower_floor,controller.tower_context)
	for release_button: Button in controller.tower_panel.release_buttons:
		_expect(release_button.disabled,"desktop Water mode left a Tower release enabled")
	_expect(controller.tower_panel.blind_button.disabled
		and controller.tower_panel.water_policy_button.disabled
		and controller.tower_panel.water_save_button.disabled,
		"desktop blind mode left a blind/policy/save control enabled")
	_expect(not controller.queue_brush_mutation(200,200,0,CyberCellWorld.WALL),
		"desktop Water run accepted an ordinary brush mutation")
	_expect(not controller.simulation_worker.queue_emit_disc(
		200,200,0,CyberCellWorld.WALL),
		"desktop worker accepted a direct ordinary brush mutation during Water")
	_expect(not controller.tower_command({"release":0})
		and not controller.tower_command({"schedule":0}),
		"desktop Water run accepted an ordinary Tower release")
	var desktop_view: Vector2i=controller.current_view_size
	var desktop_margin: Vector2i=controller.simulation_margin
	var desktop_floor: int=controller.tower_floor
	var desktop_camera: Vector2=controller.camera_origin
	var desktop_adhesion: bool=controller.liquid_surface_adhesion_enabled
	_expect(not controller.cycle_view_size()
		and not controller.cycle_simulation_margin()
		and not controller.set_liquid_surface_adhesion(not desktop_adhesion)
		and not controller.set_camera_follow(not controller.camera_follow_enabled)
		and not controller.set_simulation_window(not controller.simulation_window_enabled)
		and not controller.set_cadence_lod(not controller.cadence_lod_enabled),
		"desktop Water run accepted an execution-setting change")
	controller.tower_floor_select((desktop_floor+1)%5)
	controller.update_camera(1.0)
	_expect(controller.current_view_size==desktop_view
		and controller.simulation_margin==desktop_margin
		and controller.tower_floor==desktop_floor
		and controller.camera_origin==desktop_camera
		and controller.liquid_surface_adhesion_enabled==desktop_adhesion,
		"desktop Water execution settings changed after refusal")
	var worker_guard=CyberSimulationWorker.new()
	worker_guard._lab_active=true
	worker_guard._water_lab_active=true
	_expect(not worker_guard._apply_lab({"release":0})
		and not worker_guard._apply_lab({"schedule":0})
		and worker_guard._lab_schedule.is_empty(),
		"authoritative worker accepted a Water-mode Tower release")
	controller.water_lab_reset()
	_expect(await _wait_applied(controller,hidden_hash),"blind reset was not acknowledged")
	_expect(controller.water_active_blind_label==label,"blind reset changed/revealed its label")
	_expect(controller.water_blind_set.hidden_mapping==blind_mapping,
		"blind reset changed the desktop mapping")
	_expect(str(controller.tower_context.water_blind_label)==label,
		"worker metadata lost the blind label on reset")
	var ordinary_tuning: Dictionary=CyberTransportProfiles.resolve(
		CyberTransportProfiles.preset(0))
	controller.tower_apply_profile({"ok":false})
	var exit_rejection_deadline: int=Time.get_ticks_msec()+15_000
	while Time.get_ticks_msec()<exit_rejection_deadline and not controller.pending_water_exit.is_empty():
		await process_frame
	_expect(controller.pending_water_exit.is_empty()
		and bool(controller.tower_context.get("water_active",false)),
		"rejected desktop profile exit did not preserve the Water worker World")
	_expect(controller.water_blind_set.hidden_mapping==blind_mapping
		and controller.water_active_blind_label==label
		and str(controller.water_policy_resolved.hash)==hidden_hash,
		"rejected desktop profile exit cleared or revealed the blind session")
	controller.tower_apply_profile(ordinary_tuning)
	_expect(await _wait_ordinary(controller),
		"desktop Tower profile reset did not leave Water Feel")
	_expect(controller.water_blind_set.is_empty()
		and controller.water_blind_base.is_empty()
		and controller.water_active_blind_label.is_empty(),
		"desktop Tower profile reset retained blind session state")
	_expect(str(controller.water_policy_resolved.hash)==previous_hash,
		"desktop Tower profile reset retained the hidden policy")
	_expect(controller.queue_brush_mutation(200,200,0,CyberCellWorld.WALL),
		"ordinary desktop Tower rejected its brush")
	_expect(controller.tower_command({"schedule":0}),
		"ordinary desktop Tower rejected its release schedule")
	controller.tower_panel.refresh(true,controller.tower_floor,controller.tower_context)
	for release_button: Button in controller.tower_panel.release_buttons:
		_expect(not release_button.disabled,
			"ordinary desktop Tower retained a disabled release control")
	_expect(not controller.tower_panel.blind_button.disabled
		and not controller.tower_panel.water_policy_button.disabled,
		"ordinary desktop Tower retained disabled Water controls")

	_expect(controller.water_lab_prepare_blind(blind_candidates,775),
		"second desktop blind run did not start")
	var second_hidden_hash: String=str(controller.pending_water_apply.get("hash",""))
	_expect(await _wait_applied(controller,second_hidden_hash),
		"second desktop blind candidate was not acknowledged")
	controller.tower_reset()
	_expect(await _wait_ordinary(controller),
		"Fresh tower was not acknowledged after the blind run")
	_expect(controller.water_blind_set.is_empty(),"Fresh tower retained blind mapping")
	_expect(controller.water_active_blind_label.is_empty(),"Fresh tower retained blind label")
	_expect(str(controller.water_policy_resolved.hash)==previous_hash,
		"Fresh tower retained the hidden candidate instead of the pre-blind policy")
	_expect(controller.water_lab_save_profile(),"Fresh tower could not save the restored unblinded policy")

	controller.simulation_worker.stop_worker()
	controller.rapier_bridge.shutdown()
	controller.queue_free()
	await process_frame

	var web_scene: PackedScene=load("res://web_main.tscn")
	_expect(web_scene!=null,"Web Water controller scene did not load")
	if web_scene!=null:
		var web: Control=web_scene.instantiate()
		root.add_child(web)
		await process_frame
		_expect(web.ready_to_play,"Web Water controller did not become ready")
		var web_base: Dictionary=_policy("shallow-pool",8)
		web.water_lab_apply_result(web_base)
		_expect(str(web.tower_context.get("water_policy_hash",""))==str(web_base.hash),
			"Web base Water policy was not applied")
		_expect(web.water_lab_prepare_blind(blind_candidates,991),"Web blind run did not start")
		var web_label: String=web.water_active_blind_label
		var web_hidden_hash: String=str(web.water_policy_resolved.hash)
		var web_mapping: Dictionary=web.water_blind_set.hidden_mapping.duplicate(true)
		var web_base_hash: String=str(web.water_blind_base.get("hash",""))
		_expect(not web_label.is_empty() and not web_mapping.is_empty(),
			"Web blind run did not retain its hidden label and mapping")
		_expect(not web.water_lab_prepare_blind(nested_candidates,992),
			"nested Web blind preparation was accepted")
		_expect(web.water_blind_set.hidden_mapping==web_mapping
			and str(web.water_blind_base.get("hash",""))==web_base_hash
			and web.water_active_blind_label==web_label,
			"nested Web blind preparation replaced the original session")
		var web_bypass: Dictionary=_policy("drips",7)
		web.water_lab_apply_result(web_bypass)
		_expect(str(web.water_policy_resolved.hash)==web_hidden_hash
			and web.water_blind_set.hidden_mapping==web_mapping,
			"ordinary Web policy apply bypassed the active blind session")
		_expect(not web.water_lab_save_profile(),
			"Web blind candidate could be saved through the ordinary path")
		web.water_experiment_panel.hide()
		web.water_lab_open()
		_expect(not web.water_experiment_panel.visible,
			"ordinary policy editor opened during a Web blind run")
		web.tower_panel.refresh(true,web.tower_floor,web.tower_context)
		for release_button: Button in web.tower_panel.release_buttons:
			_expect(release_button.disabled,"Web Water mode left a Tower release enabled")
		_expect(web.tower_panel.blind_button.disabled
			and web.tower_panel.water_policy_button.disabled
			and web.tower_panel.water_save_button.disabled,
			"Web blind mode left a blind/policy/save control enabled")
		var web_before_brush: PackedByteArray=web.demo_bridge.export_level(web.native_world)
		_expect(not web.queue_brush_mutation(200,200,0,CyberCellWorld.WALL),
			"Web Water run accepted an ordinary brush mutation")
		_expect(web.demo_bridge.export_level(web.native_world)==web_before_brush,
			"rejected Web brush changed authoritative world bytes")
		_expect(not web.tower_command({"release":0})
			and not web.tower_command({"schedule":0})
			and web.tower_schedule.is_empty(),
			"Web Water run accepted an ordinary Tower release")
		var web_quality: int=web.quality
		var web_view: Vector2i=web.current_view_size
		var web_margin: Vector2i=web.simulation_margin
		var web_floor: int=web.tower_floor
		var web_camera: Vector2=web.camera_origin
		var web_adhesion: bool=web.liquid_surface_adhesion_enabled
		var web_imported: int=web.imported_count
		_expect(not web.set_quality((web_quality+1)%3)
			and not web.cycle_view_size()
			and not web.cycle_simulation_margin()
			and not web.set_liquid_surface_adhesion(not web_adhesion)
			and not web.set_camera_follow(not web.camera_follow_enabled)
			and not web.queue_explosion_mutation(200,200,20),
			"Web Water run accepted an execution-setting/general mutation")
		web.tower_floor_select((web_floor+1)%5)
		web.update_camera(1.0)
		_expect(web.quality==web_quality and web.current_view_size==web_view
			and web.simulation_margin==web_margin and web.tower_floor==web_floor
			and web.camera_origin==web_camera
			and web.liquid_surface_adhesion_enabled==web_adhesion,
			"Web Water execution settings changed after refusal")
		_expect(not bool(web._encode_current().get("ok",true)),
			"Web Water run could be saved through the ordinary level path")
		web._import_decoded({"ok":true})
		_expect(web.imported_count==web_imported
			and str(web.water_policy_resolved.hash)==web_hidden_hash,
			"Web Water run accepted an ordinary level import")
		web.focused=true
		web.ui.close_menu()
		var before_step: int=int(web.native_world.get_tick_index())
		_expect(web.tower_command({"step":true}),"Web Water single-step was rejected")
		web._physics_process(1.0/60.0)
		_expect(int(web.native_world.get_tick_index())==before_step+1,
			"live Web Water single-step did not advance exactly one tick")
		_expect(web.water_lab_apply_blind(1),"Web blind candidate switch failed")
		var switched_label: String=web.water_active_blind_label
		var switched_hash: String=str(web.water_policy_resolved.hash)
		_expect(switched_label!=web_label and switched_hash!=web_hidden_hash,
			"Web blind candidate switch did not change the hidden candidate")
		web.water_lab_reset()
		_expect(web.water_active_blind_label==switched_label,
			"in-run Web Water reset changed the blind label")
		_expect(web.water_blind_set.hidden_mapping==web_mapping,
			"in-run Web Water reset changed the blind mapping")
		_expect(str(web.water_policy_resolved.hash)==switched_hash,
			"in-run Web Water reset changed the hidden policy")

		web.tower_apply_profile(ordinary_tuning)
		_expect(web.water_blind_set.is_empty() and web.water_blind_base.is_empty()
			and web.water_active_blind_label.is_empty(),
			"Web Tower profile reset retained blind session state")
		_expect(str(web.water_policy_resolved.hash)==str(web_base.hash),
			"Web Tower profile reset retained the hidden policy")
		_expect(not bool(web.tower_context.get("water_active",false)),
			"Web Tower profile reset retained a Water Feel run")
		_expect(web.queue_brush_mutation(200,200,0,CyberCellWorld.WALL),
			"ordinary Web Tower rejected its brush")
		_expect(web.set_quality((web.quality+1)%3),
			"ordinary Web Tower rejected its quality setting")
		_expect(web.tower_command({"schedule":0}),
			"ordinary Web Tower rejected its release schedule")
		web.tower_schedule.clear()
		web.tower_panel.refresh(true,web.tower_floor,web.tower_context)
		for release_button: Button in web.tower_panel.release_buttons:
			_expect(not release_button.disabled,
				"ordinary Web Tower retained a disabled release control")

		_expect(web.water_lab_prepare_blind(blind_candidates,993),
			"second Web blind run did not start")

		web.select_demo("waterworks",false)
		_expect(web.water_blind_set.is_empty() and web.water_blind_base.is_empty(),
			"leaving Web Water Feel retained the blind mapping or base")
		_expect(web.water_blind_index==0 and web.water_active_blind_label.is_empty(),
			"leaving Web Water Feel retained the blind label or index")
		_expect(str(web.water_policy_resolved.hash)==str(web_base.hash),
			"leaving Web Water Feel retained the hidden policy")
		web.select_demo("experiment_tower",false)
		_expect(web.water_blind_set.is_empty() and web.water_active_blind_label.is_empty(),
			"returning to the Web tower revived blind session state")
		_expect(str(web.water_policy_resolved.hash)==str(web_base.hash),
			"returning to the Web tower revived the hidden policy")
		_expect(not bool(web.tower_context.get("water_active",false)),
			"ordinary Web tower return retained a Water Feel run")
		_expect(web.water_lab_save_profile(),
			"Web tower return could not save the restored unblinded policy")
		web.rapier_bridge.shutdown()
		web.queue_free()
		await process_frame
	if failures==0:
		print("WATER_FEEL_CONTROLLER: transactional rejection/body collision isolation/desktop+Web blind lifecycle passed")
	quit(failures)
