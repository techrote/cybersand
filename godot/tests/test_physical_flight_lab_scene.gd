extends SceneTree

# Non-graphical scene/same-plant identity regression; visual fidelity and human
# feel remain separate. Uses actual Godot scene with native+Rapier, no mocks.
const Screen = preload("res://scripts/physical_flight_lab_screen.gd")
const Episode = preload("res://scripts/physical_flight_episode.gd")
const Profile = preload("res://scripts/physical_flight_profile.gd")
const Controller = preload("res://scripts/physical_flight_controller.gd")
var failures: int = 0
var assertions: int = 0


func _init() -> void:
	_run.call_deferred()


func expect(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("4LY003_SCENE: " + message)


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"RapierPhysicsServer2D"):
		expect(false, "pinned native/Rapier extension required")
		quit(1)
		return
	var file: PackedScene = load("res://flight_lab.tscn")
	expect(file != null, "playable flight scene loads")
	if file == null:
		quit(1)
		return
	var game: Variant = file.instantiate()
	root.add_child(game)
	expect(game.get_script() == Screen, "flight lab is the actual in-game frontend")
	expect(game.profile_choice.item_count == 4, "all four actual 4LY profiles selectable")
	expect(game.scenario_choice.item_count >= 14, "scenarios available via real game UI")
	var live: CyberPhysicalFlightEpisode = game.episode
	expect(live.arena.session != null and live.arena.session.bridge != null,
		"the interactive scene uses the existing physical session and Rapier bridge")
	expect(live.arena.session.bodies().size() == 1,
		"single original physical flight chassis in gameplay")
	expect(str(live.manifest().controller_sha256) == Controller.controller_hash(),
		"game scene binds the same immutable assistance source")
	game.profile_choice.select(1)
	game.producer_choice.select(1)
	game.fresh_reset()
	expect(live.profile_id == &"4ly_hauler" and live.source == &"teacher",
		"fresh UI selection installs Hauler with scripted action producer")
	expect(str(live.manifest().profile_hash) == Profile.profile_hash(Profile.entry(&"4ly_hauler")),
		"interactive/episode view reports identical real plant digest")
	for index: int in range(24):
		await physics_frame
	expect(int(live.transition(0).physical_ticks_total) > 0,
		"interactive Godot 60 Hz callback consumed real physics ticks")
	expect("position" in game.telemetry.text and "goal" in game.telemetry.text,
		"HUD reports actual state, stopping and episode progress")
	game.queue_free()
	await process_frame
	print("4LY003_SCENE_RESULT ", JSON.stringify({"assertions": assertions,
		"failures": failures, "graphical_fidelity_claim": false,
		"used_native_and_rapier": true}))
	quit(0 if failures == 0 else 1)
