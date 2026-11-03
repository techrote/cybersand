extends SceneTree

const Fleet = preload("res://scripts/gcr_review_fleet.gd")
class InputScene extends "res://scripts/gcr_fleet_playground.gd":
	# Headless DisplayServer has no physical keyboard mapping. Inject only
	# sampled button levels; exercise the actual scene normalization, leased
	# submission, native owner, reset and rearm paths beneath that boundary.
	var test_ports: Dictionary = {"q":false,"e":false,"s":false}
	var test_up: bool = false
	func _review_ports() -> Dictionary: return test_ports.duplicate()
	func _thrust_up_pressed() -> bool: return test_up
var failures: int = 0
var reports: Array = []
func check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error("Fleet: "+reason)
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene: Control = InputScene.new()
	scene.applied_controls={"response":"RFT","budget":20.0,"mass_multiplier":1.0,"inertia_multiplier":1.0}
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	for index: int in range(7):
		check(scene.select_preset(index),"fresh profile "+str(index))
		var arena = scene.runtime._arena
		var rig = arena.session._rigs[0]
		var body: RigidBody2D = arena.session.bodies()[0]
		check(arena.session.bodies().size()==1,"no hidden equipment mass")
		check(is_equal_approx(body.mass,float(Fleet.ROWS[index][1])) and body.mass<=.32,"actual lightweight mass")
		var size: Vector2 = Fleet.ROWS[index][0]
		check(is_equal_approx(body.inertia,body.mass*size.length_squared()/12.),"geometric inertia")
		check(arena._world.get_gcr_admission_variant()=="R2","retained RFT owner")
		var max_force: float = 0.
		var max_torque: float = 0.
		for tick: int in range(180):
			var action: Dictionary = {"move":Vector2(.4,-1) if tick<90 else Vector2.ZERO,"aim":Vector2.UP,"trim":.2 if tick<60 else 0.,"primary":tick<90,"secondary":tick>=120,"auxiliary":false}
			check(scene.runtime.submit_action(action),"leased command")
			var state: Dictionary = scene.runtime.step()
			check(not state.failed,"live material/hard/owner tick")
			var observation: Dictionary = rig._player_controller.observation()
			max_force = maxf(max_force,Vector2(observation.applied_force).length())
			max_torque = maxf(max_torque,absf(float(observation.applied_torque)))
		check(max_force<=float(Fleet.ROWS[index][8])+.00001,"combined force cap")
		check(max_torque<=float(Fleet.ROWS[index][9])+.00001,"torque cap")
		scene.runtime.cancel()
		check(rig._player_controller.observation().applied_force==Vector2.ZERO,"cancel stops actuation")
		check(scene.paint_at(Vector2i(400,100),14),"paint with fleet")
		check(scene.paint_at(Vector2i(400,100),0),"erase with fleet")
		reports.append({"name":Fleet.NAMES[index],"mass":body.mass,"inertia":body.inertia,"parts":1,"max_force":max_force,"max_torque":max_torque,"ticks":180,"human_acceptance":false})
		check(arena.reset(),"arena reset preserves explicit fleet arm")
		check(is_equal_approx(arena.session.bodies()[0].mass,float(Fleet.ROWS[index][1])) and arena._world.get_gcr_admission_variant()=="R2","reset preserves actual fleet and response identity")
	check(not scene.select_preset(-1) and not scene.select_preset(7),"invalid profile refused")
	check(not scene.runtime.configure_review_fleet(99),"invalid owner route refused")
	# Text entry must never pass through the room's numeric craft shortcuts.
	var old_selection: int = scene.selected
	var editor: LineEdit = scene.control_fields.mass_multiplier.get_line_edit()
	editor.grab_focus()
	var number := InputEventKey.new()
	number.pressed=true
	number.keycode=KEY_4
	scene._input(number)
	check(scene.selected==old_selection,"typing4 does not switch craft")
	check(not scene._can_control(),"editing cancels leased flight input")
	scene.control_fields.mass_multiplier.value=64.0
	check(scene.applied_controls.mass_multiplier==1.0,"edited value stays staged")
	scene.restore_controls()
	check(scene.applied_controls.response=="LA" and scene.applied_controls.mass_multiplier==1.0,"restore defaults rebuilds explicit LA control")
	check(scene.runtime._arena._world.get_gcr_admission_variant()=="A1","new default uses current LA admission")
	check(scene.control_fields.thrust_multiplier.min_value==0 and scene.control_fields.thrust_multiplier.max_value==64,"thrust limit field bounds")
	check(scene.control_fields.torque_multiplier.min_value==0 and scene.control_fields.torque_multiplier.max_value==64,"torque limit field bounds")
	scene.control_fields.thrust_multiplier.value=0.5
	scene.control_fields.torque_multiplier.value=0.25
	check(scene.apply_controls(),"actuator fields rebuild actual fleet owner")
	var applied_profile: Dictionary = scene.runtime._arena.session._rigs[0]._profile
	check(is_equal_approx(applied_profile.fleet_force,float(Fleet.ROWS[scene.selected][8])*.5),"UI thrust reaches controller cap")
	check(is_equal_approx(applied_profile.fleet_torque,float(Fleet.ROWS[scene.selected][9])*.25),"UI torque reaches controller cap")
	scene.restore_controls()
	check(scene.applied_controls.thrust_multiplier==1 and scene.applied_controls.torque_multiplier==1,"restore resets actuator multipliers")
	check(scene.thruster_fire != null and not scene.thruster_fire.button_pressed,"real-fire toggle starts off")
	scene.thruster_fire.button_pressed=true
	check(scene.runtime.snapshot().review_emissions.fire_enabled,"live toggle reaches current owner without rebuilding")
	var previous_arena = scene.runtime._arena
	scene.thruster_fire.button_pressed=false
	check(scene.runtime._arena==previous_arena and not scene.runtime.snapshot().review_emissions.fire_enabled,"fire toggle preserves terrain/session")
	scene.thruster_fire.button_pressed=true
	check(scene.select_preset(2) and scene.runtime.snapshot().review_emissions.fire_enabled,"fire selection persists across fresh craft")
	# Independent sampled levels retain simultaneous actions lost by an axis.
	scene.test_ports={"q":true,"e":true,"s":true}
	scene.test_up=true
	var ports: Dictionary = scene._review_ports()
	check(ports.q and ports.e and ports.s,"independent Q/E/S remain held together")
	check(scene._sample_action().move.y==-1.0,"Kestrel W thrust survives simultaneous S dispenser")
	scene._rearm=true
	scene.advance_frame({"move":Vector2.ZERO,"aim":Vector2.UP,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false},true)
	check(scene._rearm,"held independent ports cannot rearm after cancellation")
	scene.test_ports={"q":false,"e":false,"s":false}
	scene.test_up=false
	scene.advance_frame({"move":Vector2.ZERO,"aim":Vector2.UP,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false},true)
	check(not scene._rearm,"releasing all ports permits normal neutral rearm")
	scene.queue_free()
	await process_frame
	var output := FileAccess.open("res://../fleet-test-report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures":failures,"reports":reports},"  "))
	print("GCR_REVIEW_FLEET reports=",reports.size()," failures=",failures)
	quit(0 if failures==0 else 1)
