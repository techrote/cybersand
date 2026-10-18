extends SceneTree

const Trial = preload("res://scripts/physical_actor_trial.gd")
const Blacksite = preload("res://scripts/blacksite_nine.gd")
var failures: int = 0
var assertions: int = 0

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var input = Trial.new()
	expect(not input.sample(0.1, true, 1.0, 1.0, true).pulse, "Held input must not arm a reset")
	input.sample(0.1, true, 0.0, 0.0, false)
	expect(input.sample(0.1, true, 1.0, 1.0, true).pulse, "First armed pulse must fire")
	expect(not input.sample(1.0, true, 0.0, 0.0, true).pulse, "Holding must not repeat the pulse")
	input.sample(0.1, false, 1.0, 1.0, true)
	expect(input.sample(0.1, true, 1.0, 1.0, true).drive == 0.0, "Focus/modal cancellation must require release")
	input.sample(0.1, true, 0.0, 0.0, false)
	expect(input.sample(0.1, true, 0.0, 0.0, true).pulse, "Release must rearm")
	input.sample(0.01, true, 0.0, 0.0, false)
	expect(not input.sample(0.01, true, 0.0, 0.0, true).pulse, "Cooldown must reject fast repeated taps")
	var original: Dictionary = Blacksite.definition()
	for arm: String in Trial.ARMS:
		var definition: Dictionary = Trial.definition(Trial.PREFIX + arm)
		expect(CyberMicroScenarioContract.validate(definition).get("ok", false), "Trial must satisfy the shared contract: " + arm)
		expect(definition.rectangles == original.rectangles and definition.player_start == original.player_start, "Comparison must preserve Blacksite geometry and start")
	var desktop: Control = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	for arm: String in Trial.ARMS:
		var id: String = Trial.PREFIX + arm
		expect(desktop.microscenario_launch(id, "Play", 0), "Desktop must admit trial " + arm)
		var deadline: int = Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			if desktop.pending_microscenario_apply.is_empty() and str(desktop.microscenario_definition.get("id", "")) == id: break
		expect(str(desktop.microscenario_definition.get("id", "")) == id, "Owner must acknowledge trial " + arm)
		expect(desktop.blacksite_nine_presentation.active(), "Camera map must remain available")
		expect(desktop.paused, "Each comparison starts paused")
		if arm not in ["barrel", "ripper"]:
			expect(not desktop.player_uses_barrel(), "Sampled arms retain sampled ownership")
			continue
		expect(desktop.rigid_bodies.size() == 1 and desktop.rapier_bridge.is_initialized(), "Physical trial must own one live Rapier body")
		expect(desktop.physical_trial_arm == arm, "Physical identity must survive accepted installation")
		var shape: RectangleShape2D = desktop.test_rigid_body_1.get_node("CollisionShape2D").shape
		expect(shape.size == Trial.body_size(arm), "Collision hull must match the coupling/render extent")
		var bridge = desktop.rapier_bridge
		var spawn: Vector2 = bridge.body_transform(0).origin
		expect(not bridge.apply_trial_impulses(0, Vector2(NAN,0), 0.0), "Nonfinite control must reject")
		expect(not bridge.apply_trial_impulses(16, Vector2.ZERO, 0.0), "Unknown body must reject")
		expect(bridge.apply_horizontal_control(0, 1.0, 42.0, 180.0, 3.0, 1.0/60.0) > 0.0, "Drive must add an impulse")
		bridge.apply_trial_impulses(0, Vector2(0,-24), 0.2)
		bridge.step()
		expect(bridge.body_linear_velocity(0).x > 0.0, "Real Rapier body must gain horizontal velocity")
		expect(bridge.body_linear_velocity(0).y < 0.0, "Pulse must produce upward motion")
		expect(absf(bridge.body_transform(0).get_rotation()) > 0.0, "Torque must rotate the real hull")
		desktop.blacksite_nine_presentation.frame_tile(1)
		expect(bridge.body_transform(0).origin.distance_to(spawn) > 0.0, "Camera framing must preserve physical state")
		desktop.microscenario_reset()
		deadline = Time.get_ticks_msec() + 60000
		while not desktop.pending_microscenario_apply.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		expect(desktop.rapier_bridge.body_transform(0).origin.is_equal_approx(spawn), "Reset restores physical start")
		expect(not desktop.physical_trial_input.armed, "Reset must cancel input")
	desktop.queue_free()
	await process_frame
	await process_frame
	print("Physical actor trial: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
