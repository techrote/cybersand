extends SceneTree

# Actual Main, asynchronous native owner, prepared construction and Rapier.
# Inputs are synthetic Godot events. Aim/focus seams are explicit; this does
# not claim graphical pacing or physical-device execution.
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Catalogue = preload("res://scripts/microscenario_catalogue.gd")
const Showcase = preload("res://scripts/showcase_tiles.gd")
const Retention = preload("res://tests/support/physical_retention_readback.gd")
const FIXTURE: String = "res://tests/fixtures/in-tools-metered-desktop.v1.json"
var desktop: Control
var bridge: Object
var assertions: int = 0
var failures: int = 0
var fixture: Dictionary = {}
var fixture_hash: String = ""
var reports: Array = []
var active_material: int = 3
var active_variant: String = "normal"
var active_initial_cells: int = 0
var active_walls: Array = []


class DesktopHarness:
	extends "res://scripts/main.gd"
	var test_focus: bool = true
	var test_aim: Vector2 = Vector2(0.6, 1.0).normalized()
	func _actor_window_has_focus() -> bool:
		return test_focus
	func actor_pointer_aim() -> Vector2:
		return test_aim


class DebitedTerrainRefusal extends "res://scripts/prepared_physical_session.gd":
	var terrain_attempted: bool = false
	func install_terrain(_chunks: PackedInt32Array) -> bool:
		terrain_attempted = true
		last_error = "fixture declared terrain refusal after actual metered debit"
		return false


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_METERED_DESKTOP: " + message)
	return value


func wait_for(predicate: Callable, timeout_ms: int = -1) -> bool:
	if timeout_ms < 0:
		timeout_ms = Watchdogs.milliseconds("operation_seconds")
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call():
			return true
	return false


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap(code: Key) -> void:
	key(code, true)
	key(code, false)


func equipment() -> Dictionary:
	return desktop.physical_actor_observation().get("equipment", {})


func ledger() -> Dictionary:
	return equipment().get("metered_drain", {})


func sink() -> int:
	return int(ledger().get("water_units_removed" if active_material == 3 else "brine_cells_removed", 0))


func same_stock(first: Dictionary, second: Dictionary) -> bool:
	for field: String in ["world_instance_id","native_generation","policy_hash","water_units_initial",
		"water_units_remaining","water_units_removed","brine_cells_initial","brine_cells_remaining","brine_cells_removed"]:
		if first.get(field) != second.get(field):
			return false
	return true


func owner_ready() -> bool:
	return desktop.pending_microscenario_apply.is_empty() and desktop.physical_actor_session != null \
		and desktop._physical_terrain_ready and desktop._actor_reset_receipt == 0 \
		and not desktop.simulation_worker.has_failed()


func resume() -> bool:
	desktop.actor_prototype_panel.hide()
	desktop.playable_session_panel.hide()
	var focus: Control = desktop.get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	desktop.paused = false
	return await wait_for(func() -> bool:
		return owner_ready() and not desktop.latest_snapshot.paused \
			and not desktop._actor_input_rearm and not desktop._actor_usable_pointer_rearm)


func equip(profile_index: int = 1, usable: int = 9, power: float = 0.5,
	fresh_ui_boundary: bool = false) -> bool:
	desktop.toggle_actor_prototypes()
	if fresh_ui_boundary:
		# stop_worker retires the old control generation. Exercise the ordinary
		# blocking F5/neutral input boundary to obtain a fresh owner command;
		# do not try to reuse the suspended generation after joining.
		var old_generation: int = int(desktop.physical_actor_observation().control_generation)
		if not expect(await wait_for(func() -> bool:
			return int(desktop.physical_actor_observation().control_generation) > old_generation),
			"ordinary F5 boundary retires the stopped control generation"):
			return false
	var panel: CyberActorPrototypePanel = desktop.actor_prototype_panel
	panel.usable_choice.select(usable + 1)
	panel.usable_choice.item_selected.emit(usable + 1)
	panel.drain_profile_choice.select(profile_index)
	panel.drain_profile_choice.item_selected.emit(profile_index)
	panel.usable_power_slider.value = power
	panel._equip_only_button.pressed.emit()
	var done: bool = await wait_for(func() -> bool:
		return not desktop._actor_usable_transition_pending and int(equipment().get("usable_index", -99)) == usable \
			and equipment().get("profile", "") == (Equipment.METERED_PROFILE if profile_index > 0 else "") \
			and not desktop.actor_prototype_panel.visible)
	if done:
		await wait_for(func() -> bool: return not desktop._actor_input_rearm and not desktop._actor_usable_pointer_rearm)
	return done


func _play_panel_smoke() -> bool:
	var panel = desktop.playable_session_panel
	panel.actor_choice.select(2) # Existing Afterimage / acrobat, with physical equipment.
	panel.control_choice.select(1)
	panel.rule_choice.select(1)
	panel.policy_editor.select_preset(5) # Existing Water: inertial; no PF family.
	panel.policy_editor.geometry_picker.select(1) # Explicit radius three.
	panel.build_button.pressed.emit()
	if not expect(await wait_for(owner_ready), "actual PLAY Build constructs the unmodified authored course and physical owner"):
		return false
	var construction: Dictionary = desktop.tower_context.get("liquid_construction_receipt", {}).duplicate(true)
	expect(not construction.is_empty() and int(construction.get("initial_body_count", 0)) > 0 \
		and int(construction.get("maximum_rule_radius", 0)) == 3,
		"PLAY receipt binds actual initial Rapier masks and explicit IN geometry")
	if not expect(await resume(), "PLAY owner resumes through ordinary Main processing"):
		return false
	if not expect(await equip(), "actual F5 selector and Equip only enable versioned metered Water on PLAY actor"):
		return false
	expect(await wait_for(func() -> bool: return ledger().get("available", false)),
		"PLAY Water-IN exposes eligible native owner context without a comparison host")
	reports.append({"case":"unmodified-play-panel", "scope":"policy/owner/equipment admission; no liquid removal claimed",
		"construction":construction,"actor":desktop.physical_actor_observation(),"ledger":ledger().duplicate(true)})
	return true


func definition(material: int) -> Dictionary:
	# Keep the existing exploratory map admission ID; this source-labelled
	# variation is a test fixture, not an edit to the authored scene catalogue.
	var value: Dictionary = Catalogue.definition(Showcase.scenario_ids()[0])
	active_initial_cells = int(fixture.initial_liquid_cells)
	active_walls = fixture.wall_rectangles.duplicate()
	if active_variant == "wall":
		active_walls.append_array(fixture.hard_occluder)
	value.rectangles = active_walls.duplicate()
	var liquid: Array = fixture.liquid_rectangle.duplicate()
	liquid.append(material)
	value.rectangles.append_array(liquid)
	if active_variant == "under_actor":
		var source: Array = fixture.under_actor_source.duplicate()
		source.append(material)
		value.rectangles.append_array(source)
		active_initial_cells += int(fixture.under_actor_source_cells)
	value.player_start = fixture.player_start.duplicate()
	value.camera_origin = [64,64]
	value.interest = {"policy":"fixed","region":[64,64,160,112]}
	value.execution = {"policy":"owner","cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":false}
	value.water_semantics = [1,int(fixture.mass_bits),0,0]
	value.partial_water_fills = []
	value.events = []
	value.observations = []
	value.conditions = []
	value.tools = ["player"]
	value.source_recipe = str(fixture.source_recipe) + "/" + active_variant
	value.source_recipe_hash = fixture_hash
	value.presentation.title = "IN-TOOLS metered drain / controlled desktop fixture v1"
	value.presentation.instructions = "Registered headless native/Rapier control; no graphical qualification."
	value.presentation.profile = fixture.id
	value.presentation.regions = []
	return value


func install(material: int, family: int = 4, variant: String = "normal") -> bool:
	print("PHYSICAL_METERED_DESKTOP_PHASE install material=",material," family=",family," variant=",variant)
	key(KEY_M, false)
	desktop.test_focus = true
	desktop.test_aim = Vector2(fixture.aim[0],fixture.aim[1]).normalized()
	desktop.simulation_window_enabled = false
	desktop.cadence_lod_enabled = false
	desktop.liquid_surface_adhesion_enabled = false
	active_material = material
	active_variant = variant
	var value: Dictionary = definition(material)
	var checked: Dictionary = Contract.validate(value)
	if not expect(checked.get("ok",false), "controlled desktop fixture validates: " + str(checked.get("error",""))):
		return false
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	var family_name: String = "inertial_cellular_v1" if family == 4 else "freemass_v1"
	var chosen: bool = false
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(policy,material):
		if choice.family == family_name and choice.variant == "reference" and choice.accepted:
			policy = choice.request
			chosen = true
			break
	if not expect(chosen,"actual policy choices admit requested material/family"):
		return false
	var accepted: bool = desktop.microscenario_apply_exploratory_liquid(value,policy,false,"Play",
		desktop._playable_actor_configuration(StringName(str(fixture.physical_rig))),3)
	if not expect(accepted,"existing Main prepared route accepts controlled tank: " + desktop.microscenario_error):
		return false
	if not expect(await wait_for(owner_ready), "controlled native/physical prepared owner completes"):
		return false
	if not expect(await resume(), "controlled real physical actor resumes"):
		return false
	if not expect(await equip(1 if material == 3 else 2), "actual panel equips selected metered liquid"):
		return false
	return expect(await wait_for(func() -> bool: return ledger().get("available",false)),
		"copied native context admits the selected material: " + str(ledger()))


func _accepted_pulses(count: int) -> bool:
	var previous: int = int(equipment().get("accepted_uses", 0))
	var started_tick: int = desktop.physical_actor_session.tick
	key(KEY_M,true)
	await wait_for(func() -> bool:
		return int(equipment().get("accepted_uses",0)) >= previous + count \
			or desktop.physical_actor_session.tick - started_tick >= int(fixture.activation_observation_physical_ticks))
	var applied: bool = int(equipment().get("accepted_uses",0)) >= previous + count
	key(KEY_M,false)
	expect(applied, "real held M produces %d accepted native pulse(s): %s" % [count,str(equipment())])
	if applied:
		var result: Dictionary = equipment().last_receipt.metered_drain
		expect(result.status == "applied" and result.provenance == "host-local-native-observation-v1" \
			and int(result.sink_debit) > 0 and result.completed_tick_before == result.completed_tick_after,
			"positive result describes measured owner-local effects at one completed native tick")
		expect(is_equal_approx(float(equipment().last_receipt.cooldown),0.1) \
			and is_equal_approx(float(result.charge_cost),0.85),
			"accepted pulse consumes exactly .85 charge and installs .10 cooldown")
		reports.append({"case":"accepted-pulses","material":active_material,"receipt":equipment().last_receipt.duplicate(true),
			"ledger":ledger().duplicate(true),"actor":desktop.physical_actor_observation()})
	return applied


func _cancellation_checks() -> void:
	await create_timer(0.16).timeout
	var before: int = sink()
	tap(KEY_M)
	await create_timer(0.16).timeout
	expect(sink() == before and not equipment().pending,"press/release entirely between native ticks cannot replay a metered pulse")
	key(KEY_M,true)
	desktop.test_focus = false
	desktop._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	desktop.test_focus = true
	await create_timer(0.16).timeout
	expect(sink() == before and not equipment().pending,"brief focus loss/regain revokes uncommitted intake and held input stays disarmed")
	key(KEY_M,false)
	await create_timer(0.05).timeout
	key(KEY_M,true)
	desktop.toggle_actor_prototypes()
	desktop.actor_prototype_panel.hide()
	await create_timer(0.16).timeout
	expect(sink() == before,"blocking F5 open/close revokes uncommitted intake without a phantom drain")
	key(KEY_M,false)
	await create_timer(0.05).timeout
	key(KEY_M,true)
	tap(KEY_P)
	if expect(await wait_for(func() -> bool: return desktop.latest_snapshot.paused),"ordinary P pause reaches native owner"):
		var paused_sink: int = sink()
		await create_timer(0.10).timeout
		expect(paused_sink == before and sink() == before,"pause cancels pending drain and freezes its registered sink")
	tap(KEY_P)
	await create_timer(0.16).timeout
	expect(sink() == before,"resume does not rearm a held M")
	key(KEY_M,false)
	await create_timer(0.06).timeout
	var retained: Dictionary = ledger().duplicate(true)
	expect(await equip(0,0),"switch to ordinary U01 through existing equipment selector")
	expect(await equip(1 if active_material == 3 else 2),"reselect metered U10 through existing selector")
	expect(same_stock(ledger(),retained),"equipment reselection does not replenish the live native material budget")
	expect(await equip(0),"ordinary U10 remains separately selectable")
	expect(equipment().profile == "" and not desktop.physical_actor_session.equipment_frame().actors[0].has("profile"),
		"ordinary U10 frame remains the unextended v1 contract")
	expect(await equip(1 if active_material == 3 else 2),"explicit opt-in can be restored without a new World")
	expect(same_stock(ledger(),retained),"profile off/on also preserves the native source/sink ledger")


func _joined_census(label: String, ordinary_before: Dictionary = {}) -> Dictionary:
	desktop.paused = true
	desktop.cancel_playable_course_input()
	desktop.update_worker_frame_state()
	expect(await wait_for(func() -> bool:
		return desktop.latest_snapshot.paused and desktop.physical_actor_session.snapshot().suspended),
		label + " ordinary pause reaches both physical and native owners before joining")
	desktop.simulation_worker.stop_worker()
	# The join above retires the exclusive worker. Only now may the harness
	# inspect the actual World; no active main-thread native access occurs.
	var world: Object = desktop.simulation_worker._world
	# An ordinary Main World deliberately refuses diagnostic-only snapshots.
	# This observation sums authoritative stored Water state_a (including masks).
	# copy_material_cells preserves every Brine ID; its Water dithering makes
	# rendered Water IDs unsuitable for any Water quantity calculation.
	var water_readback: Dictionary = world.water_experiment_observation(Vector2i.ZERO,Vector2i(1024,1024))
	var water: int = int(water_readback.get("water_integer",-1))
	var cells: PackedByteArray = world.get_cells()
	var brine: int = cells.count(24)
	expect(water >= 0 and cells.size() == 1024 * 1024,label + " full ordinary native census is available")
	var native_meter: Dictionary = desktop.simulation_worker._physical_usables._engine.metered.observation(0)
	var initial: int = active_initial_cells * (255 if active_material == 3 else 1)
	var debit: int = int(native_meter.get("water_units_removed" if active_material == 3 else "brine_cells_removed",0))
	var ordinary_debit: int = 0
	if ordinary_before.is_empty():
		expect(initial - debit == (water if active_material == 3 else brine), label + " full stored source/sink closure after native transport")
	else:
		# Ordinary U10 has no native quantity receipt. This separately labelled
		# control measures total removal between two joined native censuses;
		# chemistry and every other external material edit are absent.
		ordinary_debit = int(ordinary_before.water_units_final) - water
		expect(ordinary_debit > 0 and debit == 0 and brine == 0,
			label + " ordinary U10 removes actual FreeMass quantity without inventing a metered debit")
	var walls_preserved: bool = true
	var walls: Array = active_walls
	for offset: int in range(0,walls.size(),5):
		for y: int in range(int(walls[offset+1]),int(walls[offset+1])+int(walls[offset+3])):
			for x: int in range(int(walls[offset]),int(walls[offset])+int(walls[offset+2])):
				walls_preserved = walls_preserved and bridge.inspect_cell(world,Vector2i(x,y)).get("material") == 1
	expect(walls_preserved,label + " every original Wall position remains Wall")
	var forbidden: Array = fixture.forbidden_side_region
	var crossed: bool = false
	for y: int in range(int(forbidden[1]),int(forbidden[1])+int(forbidden[3])):
		for x: int in range(int(forbidden[0]),int(forbidden[0])+int(forbidden[2])):
			crossed = crossed or int(bridge.inspect_cell(world,Vector2i(x,y)).material) in [3,24]
	expect(not crossed,label + " no liquid is stored on the forbidden side of the actual wall")
	var masked_source: Array = []
	if active_variant == "under_actor":
		for y: int in range(70,149):
			for x: int in range(81,175):
				var value: Dictionary = bridge.inspect_cell(world,Vector2i(x,y))
				if value.material == active_material and int(value.transient_body_id) > 0:
					masked_source.append(value)
		expect(not masked_source.is_empty(),label + " actual current Rapier mask still covers stored source liquid")
	elif active_variant == "wall":
		var region: Array = fixture.occluder_forbidden_side_region
		var crossed_occluder: bool = false
		for y: int in range(int(region[1]),int(region[1])+int(region[3])):
			for x: int in range(int(region[0]),int(region[0])+int(region[2])):
				crossed_occluder = crossed_occluder or int(bridge.inspect_cell(world,Vector2i(x,y)).material) in [3,24]
		expect(not crossed_occluder,label + " intake-side cells behind the hard occluder remain liquid-free")
	var record: Dictionary = {"case":label,"initial":initial,"water_units_final":water,"brine_cells_final":brine,
		"sink_debit":debit,"ledger":native_meter,"native_tick":world.get_tick_index(),
		"ordinary_control_sink_from_joined_censuses":ordinary_debit,"stored_masked_source":masked_source,
		"quantity_readback":"water_experiment_observation stored Water; copy_material_cells unchanged Brine IDs",
		"physical_hash":world.get_physical_state_hash(),"construction":world.get_applied_liquid_construction_receipt(),
		"worker_readback":bridge.inspect_statistics(world)}
	reports.append(record)
	return record


func _negative_control(variant: String, reasons: Array) -> void:
	if not await install(3,4,variant):
		return
	if variant == "under_actor":
		desktop.test_aim = Vector2(fixture.negative_control_aim[0],fixture.negative_control_aim[1])
	var aim_tick: int = desktop.physical_actor_session.tick
	await wait_for(func() -> bool:
		return desktop.physical_actor_session.tick - aim_tick >= int(fixture.aim_settle_physical_ticks))
	if variant == "under_actor":
		var actual_aim: Vector2 = equipment().aim_direction
		if not expect(actual_aim.x < -0.5 and actual_aim.y < -0.5,
			"actual held mount turns up-left before the body-occlusion control: " + str(equipment())):
			await _joined_census("under-actor-aim-precondition-failed")
			return
	var protected_before: Dictionary = {}
	if variant == "under_actor":
		# Establish actual stored-liquid/mask positions, after settling, through
		# the joined owner. Initial overlap alone is not a live mask witness.
		protected_before = await _joined_census("actual-rapier-under-actor-before")
		expect(desktop.simulation_worker.start_worker(desktop.character_position) == OK,
			"body-mask witness owner restarts with the same native World")
		if not expect(await resume() and await equip(1,9,0.5,true),
			"body-occlusion control obtains fresh input after its joined witness"):
			return
	var before: int = sink()
	var uses: int = int(equipment().accepted_uses)
	var refusals: int = int(equipment().refused_uses)
	var request_id: String = str(equipment().last_receipt.get("request_id",""))
	var started_tick: int = desktop.physical_actor_session.tick
	key(KEY_M,true)
	await wait_for(func() -> bool:
		return (equipment().last_receipt.get("request_id","") != request_id \
			and equipment().last_receipt.get("reason","") in reasons) \
			or (variant == "wall" and equipment().last_result == "muzzle_blocked" \
				and int(equipment().refused_uses) > refusals) \
			or desktop.physical_actor_session.tick - started_tick >= int(fixture.activation_observation_physical_ticks))
	key(KEY_M,false)
	var receipt: Dictionary = equipment().last_receipt.duplicate(true)
	var local_block: bool = variant == "wall" and equipment().last_result == "muzzle_blocked" \
		and not bool(equipment().clearance) and int(equipment().refused_uses) > refusals
	if local_block:
		expect(receipt.is_empty() and not equipment().pending,
			"actual Rapier muzzle clearance refuses before native dispatch; no native receipt is invented")
	else:
		expect(receipt.get("reason","") in reasons and not receipt.get("accepted",true),
			variant + " real native owner explicitly refuses intake: " + str(receipt))
	if receipt.get("reason") == "source_blocked":
		var diagnostic: Dictionary = receipt.get("source_diagnostic",{})
		expect(diagnostic.get("reason") in (["body_occlusion","muzzle_occupied"] if variant == "under_actor" \
			else ["material_occlusion","muzzle_occupied"]),
			variant + " existing source preflight identifies the concrete obstruction")
	expect(sink() == before and int(equipment().accepted_uses) == uses,
		variant + " has no phantom drain or experimental debit")
	if local_block:
		expect(float(equipment().charge) == 100.0 and float(equipment().cooldown) == 0.0,
			"local blocked-muzzle refusal consumes no charge or cooldown")
	elif not receipt.is_empty():
		expect(float(receipt.get("charge",-1)) == 100.0 and float(receipt.get("cooldown",-1)) == 0.0,
			variant + " refusal consumes no charge or cooldown")
	reports.append({"case":"actual-rapier-" + variant + "-refusal","receipt":receipt,
		"refusal_owner":"physical equipment muzzle clearance; no native dispatch" if local_block else "native physical runtime source/intake preflight",
		"actor":desktop.physical_actor_observation(),"ledger":ledger().duplicate(true)})
	var protected_after: Dictionary = await _joined_census("actual-rapier-" + variant)
	if not protected_before.is_empty():
		# Both reads are under joined ownership. The live operation itself is
		# separately bound to its captured native masks by the source receipt.
		var after_cells: Array = []
		var positions_intact: bool = true
		for before_cell: Dictionary in protected_before.stored_masked_source:
			var point := Vector2i(int(before_cell.x),int(before_cell.y))
			var after_cell: Dictionary = bridge.inspect_cell(desktop.simulation_worker._world,point)
			after_cells.append(after_cell)
			positions_intact = positions_intact and after_cell.get("ok",false) \
				and after_cell.get("material") == before_cell.material and after_cell.get("state_a") == before_cell.state_a \
				and int(after_cell.get("transient_body_id",0)) > 0
		expect(positions_intact,"every witnessed stored Water position and quantity remains protected by an actual body mask")
		expect(receipt.get("metered_drain",{}).get("transitions",[]).is_empty(),
			"actual body-occlusion refusal reports no accepted material transition")
		reports.append({"case":"actual-rapier-protected-source-positions",
			"before_tick":protected_before.native_tick,"after_tick":protected_after.native_tick,
			"before_cells":protected_before.stored_masked_source,"after_cells":after_cells,
			"command_id":receipt.get("request_id",""),"source_diagnostic":receipt.get("source_diagnostic",{}),
			"scope":"joined endpoint mask/quantity witnesses plus native owner-local source refusal; ordinary transport ticks remain separate"})


func _ordinary_control() -> void:
	if not await install(3,1):
		return
	expect(await equip(0),"ordinary U10 is explicitly selected for the actual gameplay control")
	var before: Dictionary = await _joined_census("ordinary-u10-before")
	desktop.simulation_worker.start_worker(desktop.character_position)
	if not expect(await resume(),"ordinary U10 control resumes the same measured native owner"):
		return
	if not expect(await equip(0,9,0.5,true),"ordinary U10 restarts from a fresh neutral F5 input boundary"):
		return
	var uses: int = int(equipment().accepted_uses)
	var started_tick: int = desktop.physical_actor_session.tick
	key(KEY_M,true)
	await wait_for(func() -> bool:
		return int(equipment().accepted_uses) > uses \
			or desktop.physical_actor_session.tick - started_tick >= int(fixture.activation_observation_physical_ticks))
	key(KEY_M,false)
	var receipt: Dictionary = equipment().last_receipt.duplicate(true)
	expect(int(equipment().accepted_uses) > uses and receipt.get("accepted",false) \
		and receipt.get("version") == 1 and not receipt.has("metered_drain") and int(receipt.get("changed_cells",0)) > 0,
		"actual ordinary U10 retains v1 accepted physical material-edit behavior")
	reports.append({"case":"ordinary-u10-activation","receipt":receipt,"actor":desktop.physical_actor_observation(),
		"quantity_provenance":"separate joined endpoint census; ordinary v1 has no exact command quantity receipt"})
	await _joined_census("ordinary-u10-after",before)


func _retention_values() -> Dictionary:
	return {"publication_serial": desktop.latest_snapshot.serial,
		"frame": desktop.physical_actor_session.equipment_frame(),
		"publication": desktop.latest_snapshot.physical_usables,
		"view": desktop.physical_actor_session._view(0, false)}


func _debited_refusal_retains_budget(label: String) -> bool:
	# The accepted pulse above genuinely changed native stored liquid. Pause
	# through the existing owner boundary before pinning complete equipment;
	# no World query is made while the asynchronous worker owns it.
	key(KEY_M, false)
	desktop.paused = true
	desktop.cancel_playable_course_input()
	desktop.update_worker_frame_state()
	if not expect(await wait_for(func() -> bool:
		return desktop.latest_snapshot.paused and desktop.physical_actor_session.snapshot().suspended),
		label + " pauses physical and native owners before the retention baseline"):
		return false
	var frame: Dictionary = desktop.physical_actor_session.equipment_frame()
	var row: Dictionary = frame.actors[0]
	var native_identity: Dictionary = ledger().duplicate(true)
	var applied: Dictionary = desktop.tower_context.liquid_solver_policy
	var expected: Dictionary = {"run_id": frame.run_id, "epoch": frame.epoch, "actor_id": 0,
		"instance_id": row.instance_id, "equipment_epoch": row.equipment_epoch,
		"usable_index": row.usable_index, "body_id": row.body_id,
		"native_generation": int(applied.session_generation), "policy_hash": str(applied.policy_hash),
		"world_instance_id": int(native_identity.get("world_instance_id", 0)),
		"minimum_publication_serial": desktop.latest_snapshot.serial,
		"minimum_control_generation": int(row.generation),
		"completed_tick": desktop.latest_snapshot.tick_index,
		"context": {"initial_construction_receipt_available": true}}
	var readiness: Dictionary = {}
	if not expect(await wait_for(func() -> bool:
		readiness.clear()
		readiness.merge(Retention.evaluate(expected, _retention_values()), true)
		return readiness.ready), label + " receives matching accepted-owner readback before taking exact baseline"):
		reports.append({"case": label, "phase": "baseline-not-ready", "readiness": readiness})
		return false
	var stock: Dictionary = readiness.context.duplicate(true)
	var selected_removed: int = int(stock.water_units_removed) if active_material == 3 else int(stock.brine_cells_removed)
	var selected_remaining: int = int(stock.water_units_remaining) if active_material == 3 else int(stock.brine_cells_remaining)
	var selected_initial: int = int(stock.water_units_initial) if active_material == 3 else int(stock.brine_cells_initial)
	if not expect(selected_removed > 0 and selected_remaining + selected_removed == selected_initial \
		and selected_remaining < selected_initial, label + " starts from a genuine nonzero native debit and spent allowance"):
		return false
	expected.context = stock.duplicate(true)
	expected.ledgers = {}
	for field: String in ["water_units_initial", "water_units_remaining", "water_units_removed",
		"brine_cells_initial", "brine_cells_remaining", "brine_cells_removed"]:
		expected.ledgers[field] = stock[field]
	var session_before: CyberPhysicalActorSession = desktop.physical_actor_session
	var candidate_before: RefCounted = desktop._accepted_physical_candidate
	var equipment_before: Dictionary = session_before._view(0, false).equipment
	var bytes_before: PackedByteArray = var_to_bytes(equipment_before)
	var canonical_before: PackedByteArray = desktop.tower_context.liquid_construction_receipt.canonical_bytes.duplicate()
	var host_before: Dictionary = desktop.tower_context.liquid_host_observation.duplicate(true)
	var serial_before: int = desktop.latest_snapshot.serial
	var refusal := DebitedTerrainRefusal.new()
	var original_factory: Callable = desktop._prepared_physical_factory
	desktop._prepared_physical_factory = func() -> RefCounted: return refusal
	var requested: bool = desktop.microscenario_apply_exploratory_liquid(
		desktop.microscenario_definition.duplicate(true), applied.envelope.duplicate(), false, "Play",
		desktop._playable_actor_configuration(StringName(str(fixture.physical_rig))), 3)
	desktop._prepared_physical_factory = original_factory
	if not expect(requested, label + " enters the actual Main prepared replacement route"):
		return false
	var observed_changes: Array[String] = []
	var observed_frames: Array[int] = []
	if not Retention.equipment_unchanged(bytes_before, session_before._view(0, false).equipment):
		observed_changes.append("immediate")
	if not expect(await wait_for(func() -> bool:
		observed_frames.append(Engine.get_process_frames())
		if not Retention.equipment_unchanged(bytes_before, session_before._view(0, false).equipment):
			observed_changes.append("frame " + str(Engine.get_process_frames()))
		return desktop.pending_microscenario_apply.is_empty()), label + " receives the real terrain-refusal acknowledgement"):
		return false
	expected.minimum_publication_serial = serial_before + 1
	if not expect(await wait_for(func() -> bool:
		readiness.clear()
		readiness.merge(Retention.evaluate(expected, _retention_values()), true)
		return readiness.ready), label + " retains the exact spent ledger in current accepted-owner readback after refusal"):
		reports.append({"case": label, "phase": "after-not-ready", "readiness": readiness, "stock_before": stock})
		return false
	var equipment_after: Dictionary = session_before._view(0, false).equipment
	var retained: bool = (refusal.terrain_attempted and not desktop.microscenario_error.is_empty()
		and desktop.physical_actor_session == session_before and desktop._accepted_physical_candidate == candidate_before
		and desktop._pending_physical_candidate == null and Retention.equipment_unchanged(bytes_before, equipment_after)
		and observed_changes.is_empty()
		and desktop.tower_context.liquid_construction_receipt.canonical_bytes == canonical_before
		and desktop.tower_context.liquid_host_observation == host_before)
	expect(retained, label + " refuses before native replacement while retaining full equipment, both spent ledgers and native/host receipts")
	reports.append({"case": label, "material": active_material, "terrain_refusal_executed": refusal.terrain_attempted,
		"observed_frames": observed_frames, "equipment_changes_observed": observed_changes,
		"stock_before": stock, "stock_after": readiness.context,
		"equipment_before": equipment_before, "equipment_after": equipment_after,
		"difference_paths": Retention.equipment_differences(bytes_before, equipment_after),
		"scope": "real native debit followed by actual Main terrain refusal; final joined census separately checks stored quantity"})
	return retained


func run() -> void:
	var source: String = FileAccess.get_file_as_string(FIXTURE)
	fixture = JSON.parse_string(source)
	fixture_hash = source.sha256_text()
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	desktop = load("res://main.tscn").instantiate()
	desktop.set_script(DesktopHarness)
	root.add_child(desktop)
	await process_frame
	if not await _play_panel_smoke():
		finish()
		return
	if not await install(3):
		finish()
		return
	if not await _accepted_pulses(2):
		finish()
		return
	await _cancellation_checks()
	await _debited_refusal_retains_budget("water-spent-ledger-terrain-refusal")
	var retained: Dictionary = desktop.latest_snapshot.physical_usables.duplicate(true)
	var old_identity: Dictionary = ledger().duplicate(true)
	var old_run: String = str(desktop.physical_actor_observation().run_id)
	await _joined_census("water-in-main")
	expect(desktop.simulation_worker.start_worker(desktop.character_position) == OK,"stopped healthy owner restarts without clearing the sink")
	if not expect(await resume(),"restarted owner resumes physical processing"):
		finish()
		return
	expect(ledger().world_instance_id == old_identity.world_instance_id and sink() == int(old_identity.water_units_removed),
		"stop/restart keeps native generation and finite budget")
	desktop.reset_world()
	if not expect(await wait_for(func() -> bool:
		return owner_ready() and desktop.physical_actor_observation().run_id != old_run),"explicit reset reconstructs fresh physical/native owners"):
		finish()
		return
	if not expect(await resume() and await equip(),"fresh reset owner can explicitly opt in again"):
		finish()
		return
	if not expect(await wait_for(func() -> bool: return ledger().get("available",false)),
		"fresh owner publishes eligible native context before any new request"):
		finish()
		return
	expect(ledger().native_generation != old_identity.native_generation or ledger().world_instance_id != old_identity.world_instance_id,
		"fresh native owner identity fences old commands")
	expect(sink() == 0 and int(ledger().water_units_remaining) == 32 * 255,"only real reconstruction refreshes experimental stock")
	var before_feedback: Dictionary = equipment().duplicate(true)
	desktop.physical_actor_session.accept_equipment_feedback(retained)
	expect(equipment() == before_feedback,"delayed old-generation receipt delivery cannot affect rebuilt equipment")
	if await _accepted_pulses(1):
		await _joined_census("water-in-reset")
	desktop.simulation_worker.start_worker(desktop.character_position)
	if await install(24):
		if await _accepted_pulses(1):
			await _debited_refusal_retains_budget("brine-spent-ledger-terrain-refusal")
			await _joined_census("brine-in-main")
	desktop.simulation_worker.start_worker(desktop.character_position)
	if await install(3,1):
		if await _accepted_pulses(1):
			await _joined_census("water-freemass-main")
	desktop.simulation_worker.start_worker(desktop.character_position)
	await _negative_control("wall",["wrong_material","blocked_target","source_blocked"])
	desktop.simulation_worker.start_worker(desktop.character_position)
	await _negative_control("under_actor",["body_masked","source_blocked"])
	desktop.simulation_worker.start_worker(desktop.character_position)
	await _ordinary_control()
	finish()


func finish() -> void:
	key(KEY_M,false)
	if desktop != null:
		desktop.free()
	var packet: String = JSON.stringify({"schema":"in-tools-metered-drain-desktop-host-v1",
		"fixture":fixture.id,"fixture_sha256":fixture_hash,"assertions":assertions,"failures":failures,
		"platform":OS.get_name(),"godot":Engine.get_version_info(),"input":"headless-synthetic-key-events-fixed-aim-focus-seam",
		"reports":reports},"\t") + "\n"
	var packet_file := FileAccess.open("user://metered-drain-desktop-host.json",FileAccess.WRITE)
	expect(packet_file != null,"qualification packet is writable")
	if packet_file != null:
		packet_file.store_string(packet)
		packet_file.close()
		print("PHYSICAL_METERED_DESKTOP_PACKET path=",ProjectSettings.globalize_path("user://metered-drain-desktop-host.json"),
			" sha256=",packet.sha256_text()," rows=",reports.size())
	print("PHYSICAL_METERED_DESKTOP_RESULT assertions=",assertions," failures=",failures)
	quit(1 if failures else 0)
