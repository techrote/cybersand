extends SceneTree

# Actual ordinary sandbox/exploratory F5 integration for all four drone IDs.
# Retained SetP and benchmark-scientific protections run in the existing suites.
const Flight = preload("res://scripts/physical_flight_profile.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
var desktop: Control
var assertions: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, reason: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("4LY_SELECTION: " + reason)


func wait_for_reset() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while (not desktop.pending_microscenario_apply.is_empty() or desktop._actor_reset_receipt != 0) \
			and Time.get_ticks_msec() < deadline:
		await process_frame
	expect(desktop.pending_microscenario_apply.is_empty() and desktop._actor_reset_receipt == 0,
		"actual reset receipt and host transition complete")
	await process_frame


func assert_current(model: StringName, producer: StringName) -> void:
	var session = desktop.physical_actor_session
	expect(session != null and session.active(), str(model) + " installed ordinary physical session")
	if session == null:
		return
	var state: Dictionary = session.snapshot()
	var view: Dictionary = session.observation(0)
	expect(str(view.model) == str(model) and str(view.producer) == str(producer),
		str(model) + " actual selected identity/producer")
	expect(str(view.action_profile) == Flight.ACTION_PROFILE
		and view.flight.capabilities.profile_hash == Flight.profile_hash(Flight.entry(model)),
		str(model) + " actual runtime profile/action identity")
	expect(state.body_count >= 1 and session.bodies().size() == state.body_count,
		str(model) + " actual bodies not visual-only")
	expect(str(view.flight.mode) in ["passive_no_lease", "suspended"] and not bool(view.flight.command_live),
		str(model) + " new selection starts without stale assistance")
	expect(view.equipment.get("preparation") == "none" and not bool(view.equipment.get("available", true)),
		str(model) + " remains an empty-loadout single chassis")
	desktop.refresh_actor_prototypes()
	expect(desktop.actor_prototype_button.text.contains("4LY: "),
		str(model) + " visible assistance status in ordinary player HUD")


func run() -> void:
	desktop = load("res://main.tscn").instantiate()
	root.add_child(desktop)
	await process_frame
	var panel = desktop.actor_prototype_panel
	expect(desktop.actor_prototypes_allowed(), "sandbox physical selector available")
	expect(Catalog.SET_IDS[-1] == &"set4LY" and Catalog.rigs_in_set(&"set4LY") == Flight.IDS,
		"4LY family appended after the original set indices")
	expect(Catalog.RIG_IDS.size() == 46
		and Catalog.rigs_in_set(&"setP") == [&"stuntbuggy", &"trialsbike", &"acrobat", &"arcadelander", &"jetbarrel"],
		"original physical actor IDs and SetP remain intact")
	for model: StringName in Flight.IDS:
		panel.configure_selection(StringName("rapier/" + str(model)), &"human", false)
		expect(panel.selected_set_id() == &"set4LY" and panel.model_choice.selected > 0,
			str(model) + " selectable in the ordinary F5 family")
		expect(panel.model_choice.get_item_text(panel.model_choice.selected).begins_with("4LY free-flight drone"),
			str(model) + " is visibly distinguished from all reference actors")
		expect(not panel.producer_choice.disabled and not panel.npc_choice.disabled,
			str(model) + " exposes the retained human/demo/policy selector")
		expect(panel.usable_choice.disabled and panel._equip_only_button.disabled,
			str(model) + " cannot select illegal drone equipment")
		expect(panel.description.text.contains("ASSISTED FREE-FLIGHT")
			and panel.description.text.contains("F5 Apply resets map + actor"),
			str(model) + " shows controls, assistance and reset semantics")
		expect(desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(model)), &"human", false),
			str(model) + " accepted by ordinary sandbox")
		await wait_for_reset()
		assert_current(model, &"human")
		var previous: Dictionary = desktop.physical_actor_session.snapshot()
		expect(not desktop.apply_actor_equipment_configuration(0, 0.7),
			str(model) + " host independently rejects equipment bypass")
		expect(desktop.apply_actor_prototype_configuration(StringName("rapier/" + str(model)), &"human", false),
			str(model) + " repeated Apply requests a fresh actor")
		await wait_for_reset()
		assert_current(model, &"human")
		var replacement: Dictionary = desktop.physical_actor_session.snapshot()
		expect(replacement.run_id != previous.run_id and replacement.epoch > previous.epoch,
			str(model) + " reset replaces the actor/run and fences stale commands")
	# Preserve the same action, owner and actuator route for scripted / external.
	for producer: StringName in [&"demo", &"policy"]:
		expect(desktop.apply_actor_prototype_configuration(&"rapier/4ly_trainer", producer, false),
			str(producer) + " ordinary 4LY producer selection")
		await wait_for_reset()
		assert_current(&"4ly_trainer", producer)
	expect(desktop.apply_actor_prototype_configuration(&"rapier/4ly_trainer", &"human", true),
		"all four demo companions accepted through ordinary F5")
	await wait_for_reset()
	expect(desktop.physical_actor_session.snapshot().actor_count == 4
		and desktop.physical_actor_session.snapshot().body_count == 4,
		"family demo companions preserve one body per drone")
	# An exploratory map retains its authored layout and uses this same selector.
	var map_id: String = CyberShowcaseTiles.scenario_ids()[0]
	expect(desktop.microscenario_launch(map_id, "Play", 0), "exploratory host enters selected map")
	await wait_for_reset()
	expect(desktop.actor_prototypes_allowed(), "exploratory host admits the ordinary selector")
	expect(desktop.apply_actor_prototype_configuration(&"rapier/4ly_drifter", &"human", false),
		"Drifter accepted in existing exploratory host")
	await wait_for_reset()
	expect(str(desktop.microscenario_definition.id) == map_id,
		"actor replacement preserves map identity")
	assert_current(&"4ly_drifter", &"human")
	desktop.microscenario_reset()
	await wait_for_reset()
	expect(desktop.physical_rig_id == &"4ly_drifter",
		"map reset preserves selected flight profile")
	# The ordinary game remains recoverable; no drone-only scene takes over.
	expect(desktop.apply_actor_prototype_configuration(&"", &"human", false),
		"original sampled baseline remains selectable")
	await wait_for_reset()
	expect(desktop.physical_actor_session == null and desktop.actor_model_selection == &"",
		"leaving 4LY restores sampled gameplay and retires the physical owner")
	desktop.queue_free()
	await process_frame
	await process_frame
	print("4LY ordinary flight selection: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
