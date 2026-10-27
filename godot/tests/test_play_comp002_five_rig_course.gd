extends SceneTree

# PLAY-COMP-002 / #267: five real SetP rigs in the single existing asynchronous
# desktop host, on the original course geometry and source-matched rig origins.
# A test-only focus seam preserves real physics, controller and native ownership.
const Course = preload("res://scripts/player_playground_course.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")

var desktop: Control
var assertions: int = 0
var failures: int = 0
var expected_model: StringName = &""
var start_physics_tick: int = 0


class DesktopHarness:
	extends "res://scripts/main.gd"
	# Same headless-only focus seam as PLAY-COMP-001; no synthetic actor.
	func actor_keyboard_allowed() -> bool:
		return (not paused and actor_prototypes_allowed()
			and _physical_terrain_ready and _actor_reset_receipt == 0
			and not actor_prototype_panel.visible)


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, reason: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("PLAY_COMP002: " + reason)


func wait_for(predicate: Callable, timeout_ms: int = 30000) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await process_frame
	return false


func course_installed() -> bool:
	return (desktop.pending_microscenario_apply.is_empty()
		and desktop.tower_context.get("micro_active", false)
		and desktop.microscenario_definition.get("id", "") == Catalogue.PLAYER_COURSE_ID)


func actor_installed() -> bool:
	return (course_installed() and desktop._actor_reset_receipt == 0
		and desktop.physical_actor_session != null
		and desktop.physical_rig_id == expected_model
		and desktop._physical_terrain_ready)


func input_rearmed() -> bool:
	return (desktop.physical_actor_session != null
		and desktop.physical_actor_session.tick > start_physics_tick
		and not desktop._actor_input_rearm)


func physics_advanced() -> bool:
	return (desktop.physical_actor_session != null
		and desktop.physical_actor_session.tick >= start_physics_tick + 30)


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func finish() -> void:
	key(KEY_D, false)
	key(KEY_W, false)
	if is_instance_valid(desktop):
		desktop.queue_free()
	await process_frame
	await process_frame
	print("PLAY_COMP002_RESULT ", JSON.stringify({
		"assertions":assertions, "failures":failures,
		"mechanical_presets":Course.MECHANICAL_PRESETS.size(),
		"route":"existing-CyberSimulationWorker+main-Rapier",
		"swarm_qualified":false, "gamepad_qualified":false,
		"frame_pacing_measured":false, "parallel_speedup_proven":false
	}))
	quit(0 if failures == 0 else 1)


func run() -> void:
	var definition: Dictionary = Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 0)
	var checked: Dictionary = Contract.validate(definition)
	expect(bool(checked.get("ok", false)), "authored course validates")
	expect(Catalogue.PLAYER_COURSE_ID in Catalogue.ids(),
		"existing MicroScenario picker exposes the authored player course")
	expect(Course.MECHANICAL_PRESETS.size() == 5,
		"exactly five SetP mechanical presets, not either material swarm")
	expect(Catalogue.definition(Catalogue.PLAYER_COURSE_ID, 1).is_empty(),
		"unspecified procedural seed is refused without replacing the authored course")
	if not checked.get("ok", false):
		await finish()
		return

	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	expect(desktop.worker_start_error == OK
		and desktop.simulation_worker._thread.is_started(),
		"original asynchronous worker thread was started")

	expect(desktop.microscenario_launch(Catalogue.PLAYER_COURSE_ID, "Play", 0),
		"real existing desktop admits original course")
	var installed: bool = await wait_for(Callable(self, "course_installed"))
	if not installed:
		expect(false, "course installation was not acknowledged")
		await finish()
		return
	expect(desktop.microscenario_definition.rectangles == checked.definition.rectangles,
		"exact authored course geometry is retained by the existing owner")

	for model_id: StringName in Course.MECHANICAL_PRESETS:
		expected_model = model_id
		var prepared: Dictionary = Equipment.definition(Catalog.entry(model_id))
		expect(not prepared.is_empty(), "actual SetP equipment/rig definition exists: " + str(model_id))
		if prepared.is_empty():
			continue
		var intended: Vector2 = Course.mechanical_origin(model_id,
			float(prepared.spawn_floor_clearance))
		expect(intended.is_finite(), "original authoring has a bounded mechanical spawn: " + str(model_id))
		var generated: Array = desktop.physical_actor_definitions(model_id, &"human", false,
			Vector2(178, 304), Catalogue.PLAYER_COURSE_ID)
		expect(generated.size() == 1 and generated[0].position.distance_to(intended) < 0.01,
			"normal actor-session constructor preserves original course spawn: " + str(model_id))

		expect(desktop.apply_actor_prototype_configuration(
			StringName("rapier/" + str(model_id)), &"human", false),
			"existing F5 path admits physical course preset: " + str(model_id))
		var accepted: bool = await wait_for(Callable(self, "actor_installed"))
		expect(accepted, "actor/terrain receipt acknowledged by existing worker: " + str(model_id))
		if not accepted:
			await finish()
			return
		var session = desktop.physical_actor_session
		var first: Dictionary = session.observation(0)
		expect(desktop.camera_follow_enabled,
			"authored mechanical course enables actor-follow instead of generic MicroScenario overview: " + str(model_id))
		expect(desktop.character_centre().distance_to(Vector2(first.get("position",Vector2.INF))) < 0.01,
			"shared desktop course camera centre observes actual Rapier SetP pose: " + str(model_id))
		expect(desktop.current_view_size == Vector2i(256,128),
			"the selected mechanical course defaults to source-authored 256x128 close follow: " + str(model_id))
		key(KEY_F,true)
		key(KEY_F,false)
		expect(not desktop.camera_follow_enabled and desktop.current_view_size == Course.VIEW.size
			and desktop.camera_origin.distance_to(Vector2(Course.VIEW.position)) < 0.01,
			"F shows the original 512x256 panorama without a World or Rapier change: " + str(model_id))
		key(KEY_F,true)
		key(KEY_F,false)
		expect(desktop.camera_follow_enabled and desktop.current_view_size == Vector2i(256,128),
			"the next F restores actor-follow close view: " + str(model_id))
		expect(str(first.get("model", "")) == str(model_id)
			and str(first.get("producer", "")) == "human"
			and session.bodies().size() > 0,
			"actual Rapier SetP session owns selected human actor: " + str(model_id))
		expect(desktop.microscenario_definition.rectangles == checked.definition.rectangles,
			"changing player has not replaced/edited the authored map: " + str(model_id))
		var body = session.bodies()[0]
		var body_expected: Vector2 = intended + Vector2(prepared.parts[0].offset)
		expect(body.global_position.distance_to(body_expected) < 2.0,
			"real first Rapier body starts at authored clearance: " + str(model_id))

		start_physics_tick = session.tick
		desktop.paused = false
		var rearmed: bool = await wait_for(Callable(self, "input_rearmed"))
		expect(rearmed, "neutral frame clears production reset/rearm fence: " + str(model_id))
		if not rearmed:
			await finish()
			return
		var initial: Vector2 = session.observation(0).get("position", Vector2.INF)
		start_physics_tick = session.tick
		var input_key: Key = KEY_D if model_id == &"acrobat" else KEY_W
		key(input_key, true)
		var advanced: bool = await wait_for(Callable(self, "physics_advanced"))
		var after: Dictionary = session.observation(0)
		key(input_key, false)
		expect(advanced, "real Rapier physics advances with native World live: " + str(model_id))
		if advanced:
			var action: Dictionary = after.get("action", {})
			var move: Vector2 = action.get("move", Vector2.ZERO)
			expect((move.x > 0.5 if input_key == KEY_D else move.y < -0.5),
				"key command reaches actual SetP movement controller: " + str(model_id))
			var final_position: Vector2 = after.get("position", Vector2.INF)
			expect(final_position.is_finite() and initial.distance_to(final_position) > 0.25,
				"physical actor changes pose while commanded: " + str(model_id))
			print("PLAY_COMP002_RIG ", JSON.stringify({
				"rig":str(model_id), "initial_position":initial,
				"final_position":final_position, "authored_spawn":intended,
				"physics_tick":session.tick,
				"native_tick":desktop.latest_snapshot.tick_index if desktop.latest_snapshot != null else -1,
				"resolved_native_workers":desktop.latest_snapshot.scheduler_thread_capacity_hint if desktop.latest_snapshot != null else -1,
				"terrain_ready":desktop._physical_terrain_ready
			}))
		# Event ordering remains the production submit_local edge queue. The
		# two arrow events are delivered without a physics-frame yield.
		if model_id == &"acrobat" and advanced:
			var before_edge: int = int(session.observation(0).get("last_sequence",0))
			key(KEY_RIGHT,true)
			key(KEY_RIGHT,false)
			var after_edge: Dictionary = session.observation(0)
			expect(int(after_edge.get("last_sequence",0)) >= before_edge + 2,
				"shared course arrow press/release both submit through actor lease before the next physics tick")
			expect(desktop.camera_follow_enabled,
				"arrow steering did not silently disable the course's actor-follow camera")
		expect(desktop.latest_snapshot != null and desktop.latest_snapshot.tick_index > 0,
			"native cellular World publishes independently of main-thread Rapier: " + str(model_id))
		desktop.paused = true
		await process_frame

	# Reset must preserve the most recently selected rig and map identity.
	desktop.microscenario_reset()
	var reset_ok: bool = await wait_for(Callable(self, "actor_installed"))
	expect(reset_ok and desktop.microscenario_definition.rectangles == checked.definition.rectangles,
		"existing owner resets while retaining course and selected rig")
	expect(reset_ok and desktop.camera_follow_enabled and desktop.current_view_size == Vector2i(256,128),
		"R reset restores default close-follow camera, not a stale previous epoch view")
	# PLAY-COMP-002 follow-on: re-use the shipped native per-material solver
	# selector and prepared World transaction on the *same* authored course.
	# This is explicit construction-time admission, never a live native mutation.
	expect(int(desktop.microscenario_definition.get("schema_version",0)) == 2
		and desktop.microscenario_definition.get("source_recipe","") == "CyberPlayerPlaygroundCourse/v1",
		"authored gameplay source admits a versioned prepared liquid configuration")
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.session_picker.select(1)
	panel.select_preset(2) # Water pressure/reference, all other material assignments retained.
	panel.refresh(desktop.tower_context)
	var selection_accepted: bool = bool(panel._validation.get("accepted",false)) and not panel.apply_button.disabled
	expect(selection_accepted, "existing UI enables an admitted per-material solver rebuild on the course")
	if selection_accepted:
		var requested: PackedInt32Array = panel.requested_policy.duplicate()
		var prior: Dictionary = desktop.tower_context.get("liquid_solver_policy",{}).duplicate(true)
		var prior_generation: int = int(prior.get("session_generation",-1))
		expect(panel.apply_active(), "existing UI queues a prepared pressure-Water course replacement")
		var replaced: bool = await wait_for(func() -> bool:
			return (desktop.pending_microscenario_apply.is_empty()
				and int(desktop.tower_context.get("liquid_solver_policy",{}).get("session_generation",-1)) > prior_generation
				and desktop.physical_actor_session != null and desktop._physical_terrain_ready))
		expect(replaced, "actual worker and main-thread Rapier jointly acknowledge the new native World")
		if replaced:
			var applied: Dictionary = desktop.tower_context.get("liquid_solver_policy",{}).duplicate(true)
			var receipt: Dictionary = desktop.tower_context.get("liquid_construction_receipt",{}).duplicate(true)
			var pressure_water: bool = false
			for assignment: Dictionary in applied.get("assignments",[]):
				if int(assignment.material) == 3:
					pressure_water = str(assignment.applied_family) == "pressure_flow_v1" \
						and str(assignment.applied_variant) == "reference"
			expect(pressure_water and applied.get("envelope",PackedInt32Array()) == requested
				and receipt.get("policy_hash","") == applied.get("policy_hash",""),
				"native readback proves the requested pressure family, variant and immutable envelope")
			expect(receipt.get("kind","") == "applied_run"
				and receipt.get("run_intent","") == "exploratory"
				and not bool(receipt.get("eligible_for_full_matched_evidence",true)),
				"typed tick-zero receipt records exploratory intent without invented full-host qualification")
			expect(actor_installed() and desktop.microscenario_definition.rectangles == checked.definition.rectangles
				and desktop.microscenario_definition.source_recipe_hash == checked.definition.source_recipe_hash,
				"solver reconstruction retains SetP player, terrain and exact authored recipe identity")
			var receipt_hash: String = str(receipt.get("receipt_hash",""))
			var retained_generation: int = int(applied.get("session_generation",-1))
			expect(not desktop.microscenario_apply_controlled_liquid(
				desktop.microscenario_definition,requested,false,"Play",2),
				"controlled/actor-free policy cannot silently replace the playable physical host")
			expect(desktop.pending_microscenario_apply.is_empty()
				and str(desktop.tower_context.get("liquid_construction_receipt",{}).get("receipt_hash","")) == receipt_hash
				and int(desktop.tower_context.get("liquid_solver_policy",{}).get("session_generation",-1)) == retained_generation
				and actor_installed(),
				"unsupported route preserves the accepted World, typed receipt and actual actor")
			desktop.microscenario_reset()
			var reinstalled: bool = await wait_for(func() -> bool:
				return (actor_installed() and int(desktop.tower_context.get("liquid_solver_policy",{}).get("session_generation",-1)) > retained_generation))
			expect(reinstalled, "R/reset rebuilds original map and committed solver through the same owner")
			if reinstalled:
				var reset_policy: Dictionary = desktop.tower_context.get("liquid_solver_policy",{})
				expect(reset_policy.get("policy_hash","") == applied.get("policy_hash","")
					and desktop.microscenario_definition.rectangles == checked.definition.rectangles,
					"new generation retains selected per-material family and authored course")
				# F5 actor change is a separate transaction, retaining the committed
				# policy while constructing a different real mechanical rig.
				expected_model = &"acrobat"
				expect(desktop.apply_actor_prototype_configuration(&"rapier/acrobat",&"human",false),
					"F5 actor replacement admits on a policy-prepared playground course")
				var switched: bool = await wait_for(Callable(self,"actor_installed"))
				expect(switched, "different actual Rapier rig and terrain become ready after F5 rebuild")
				if switched:
					expect(desktop.tower_context.get("liquid_solver_policy",{}).get("policy_hash","") == applied.get("policy_hash","")
						and desktop.microscenario_definition.rectangles == checked.definition.rectangles
						and str(desktop.physical_actor_session.observation(0).get("model","")) == "acrobat",
						"F5 retains original course, new SetP controller and committed solver family")
				print("PLAY_COMP002_LIQUID ", JSON.stringify({
					"policy_hash":str(applied.get("policy_hash","")),
					"native_receipt":receipt_hash,
					"initial_generation":prior_generation,
					"applied_generation":retained_generation,
					"reset_generation":int(reset_policy.get("session_generation",-1)),
					"switched_actor":expected_model,
					"recipe_hash":str(checked.definition.source_recipe_hash),
					"selected_water_family":"pressure_flow_v1",
					"real_frame_pacing_measured":false
				}))
	await finish()
