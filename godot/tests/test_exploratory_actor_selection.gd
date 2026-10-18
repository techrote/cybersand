extends SceneTree

const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Trial = preload("res://scripts/physical_actor_trial.gd")
var failures: int = 0
var assertions: int = 0
var desktop: Control

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func installed() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while (not desktop.pending_microscenario_apply.is_empty() or desktop._actor_reset_receipt != 0) and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(desktop.pending_microscenario_apply.is_empty() and desktop._actor_reset_receipt == 0, "Owner must acknowledge replacement")
	await process_frame

func run() -> void:
	desktop = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	# The same panel works in the original actor sandbox, including real bodies.
	for model: StringName in [&"physical/ripper", &"runner", &"physical/barrel", &""]:
		expect(desktop.apply_actor_prototype_configuration(model, &"human", false), "Sandbox accepts " + str(model))
		await installed()
		expect(desktop.player_uses_barrel() == str(model).begins_with("physical/"), "Sandbox ownership follows physics choice")
		if not desktop.player_uses_barrel():
			expect(desktop.rigid_bodies.size() == 3, "Leaving a physical hull restores reference bodies")
	expect(desktop.apply_actor_prototype_configuration(&"physical/ripper", &"human", false), "Physical Ripper before legacy F6")
	await installed()
	expect(desktop.cycle_player_representation(), "Legacy F6 must leave physical Ripper")
	var legacy_deadline: int = Time.get_ticks_msec() + 60000
	while desktop.latest_snapshot.player_representation == "barrel-rapier" and Time.get_ticks_msec() < legacy_deadline:
		await process_frame
	expect(not desktop.player_uses_barrel() and desktop.rigid_bodies.size() == 3, "Legacy F6 must restore all three reference bodies")
	var reference_shape: RectangleShape2D = desktop.test_rigid_body_1.get_node("CollisionShape2D").shape
	expect(reference_shape.size == Vector2(8,14), "Legacy F6 must restore reference collider and render extent")
	var maps: Array[String] = CyberShowcaseTiles.scenario_ids()
	maps.append(CyberBlacksiteNine.SCENARIO_ID)
	for id: String in maps:
		var original: Dictionary = Catalogue.definition(id)
		expect(desktop.microscenario_launch(id, "Play", 0), "Map opens: " + id)
		await installed()
		expect(desktop.actor_prototypes_allowed(), "Exploratory map must enable actor selection")
		for model: StringName in [&"physical/barrel", &"physical/ripper", &"ripper", &"gyrocrate", &""]:
			expect(desktop.apply_actor_prototype_configuration(model, &"human", false), "Map accepts " + str(model))
			await installed()
			expect(desktop.microscenario_definition.id == id, "Switch must retain map identity")
			expect(desktop.microscenario_definition.rectangles == original.rectangles, "Switch must retain authored map geometry")
			expect(desktop.microscenario_definition.player_start == original.player_start, "Switch must retain map spawn")
			expect(desktop.paused, "Replacement starts paused")
			var physical: bool = str(model).begins_with("physical/")
			expect(desktop.player_uses_barrel() == physical, "Exactly one player representation is active")
			if physical:
				expect(desktop.latest_snapshot.actor_prototypes.is_empty(), "Physical player must clear sampled rig session")
				expect(desktop.rigid_bodies.size() == 1, "Physical player owns one body")
				var shape: RectangleShape2D = desktop.test_rigid_body_1.get_node("CollisionShape2D").shape
				expect(shape.size == Trial.body_size(desktop.physical_trial_arm), "Hull must match selected physical actor")
			elif model != &"":
				expect(not desktop.latest_snapshot.actor_prototypes.is_empty(), "Sampled rig session must be published")
				expect(desktop.latest_snapshot.actor_prototypes.models[0] == model, "Correct rig must own player")
			else:
				expect(desktop.latest_snapshot.actor_prototypes.is_empty(), "Baseline must clear previous rig")
			desktop.microscenario_reset()
			await installed()
			expect(desktop.actor_model_selection == (model if not physical else &""), "R must retain selected sampled actor")
			expect(desktop.player_uses_barrel() == physical, "R must retain physical ownership")
	# Every rig can use the shared exploratory owner boundary, including demo NPCs.
	for set_id: StringName in CyberActorRigCatalog.SET_IDS:
		for model: StringName in CyberActorRigCatalog.rigs_in_set(set_id):
			expect(desktop.apply_actor_prototype_configuration(model, &"demo", true), "All sampled rigs admitted: " + str(model))
			await installed()
			expect(desktop.latest_snapshot.actor_prototypes.models[0] == model, "All sampled rig identities preserved")
			expect(desktop.latest_snapshot.actor_prototypes.models.size() == CyberActorRigCatalog.rigs_in_set(set_id).size(), "Demo companions stay in selected set")
	# Changing exploratory districts retains the actor but adopts the destination spawn.
	expect(desktop.microscenario_launch(CyberShowcaseTiles.scenario_ids()[0], "Play"), "Exploratory navigation accepts destination")
	await installed()
	expect(desktop.latest_snapshot.actor_prototypes.models[0] == &"gemini", "Navigation retains sampled rig")
	expect(desktop.apply_actor_prototype_configuration(&"physical/ripper", &"human", false), "Physical choice before map navigation")
	await installed()
	expect(desktop.microscenario_launch(CyberBlacksiteNine.SCENARIO_ID, "Play"), "Physical actor can navigate to Blacksite")
	await installed()
	expect(desktop.physical_trial_arm == "ripper" and desktop.player_uses_barrel(), "Navigation retains physical Ripper")
	# UI labels distinguish sampled Ripper from its physical namesake.
	desktop.toggle_actor_prototypes()
	var panel = desktop.actor_prototype_panel
	panel.configure_selection(&"physical/ripper", &"demo", true)
	expect(panel.model_choice.get_item_text(panel.model_choice.selected).begins_with("Rapier"), "Physical choice must have explicit Rapier label")
	expect(panel.producer_choice.disabled and panel.npc_choice.disabled, "Physical trial must not advertise unsupported demo/policy control")
	expect(panel.producer_choice.selected == 0 and not panel.npc_choice.button_pressed, "Physical trial must display its actual keyboard-only configuration")
	expect(not panel.effort_label.get_parent().visible, "Physical trial must hide sampled-only power control")
	panel.hide()
	# Fixed apparatus and Benchmark mode retain their protected ownership.
	expect(desktop.microscenario_launch("fixtures/sand-release", "Inspect", 0), "Protected fixture opens")
	await installed()
	expect(not desktop.actor_prototypes_allowed(), "Fixed fixture must disable picker")
	expect(not desktop.apply_actor_prototype_configuration(&"physical/barrel", &"human", false), "Protected fixture refuses replacement")
	expect(desktop.microscenario_launch(CyberBlacksiteNine.SCENARIO_ID, "Benchmark", 0), "Benchmark opens")
	await installed()
	expect(not desktop.actor_prototypes_allowed(), "Benchmark must disable picker even on exploratory map")
	expect(desktop.latest_snapshot.actor_prototypes.is_empty(), "Benchmark must not inherit sampled actor")
	# Owner-side admission independently rejects an actor request even if UI guards are bypassed.
	var worker := CyberSimulationWorker.new()
	for command: Dictionary in [
		{"scenario_reset":Catalogue.definition("fixtures/sand-release"), "scenario_mode":"Inspect"},
		{"scenario_reset":Catalogue.definition(CyberBlacksiteNine.SCENARIO_ID), "scenario_mode":"Benchmark"}]:
		command.exploratory_actor_definitions = [{"model":&"runner", "producer":&"human", "position":Vector2(24,24)}]
		expect(not worker._apply_lab(command), "Owner must independently refuse controlled-scenario actors")
		expect(not worker._scenario_host.active(), "Refusal must occur before replacing World")
	desktop.queue_free()
	await process_frame
	await process_frame
	print("Exploratory actor selection: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
