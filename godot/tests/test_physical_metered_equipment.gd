extends SceneTree

# Real Rapier equipment/session and ordinary UI controls, with explicitly
# synthetic copied worker outcomes. This qualifies command custody, resources,
# cancellation and result delivery; it is not native liquid-quantity evidence.
const Session = preload("res://scripts/physical_actor_session.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Runtime = preload("res://scripts/physical_usable_runtime.gd")
const ActorPanel = preload("res://scripts/actor_prototype_panel.gd")
const Catalog = preload("res://scripts/usable_catalog.gd")
const DT: float = 1.0 / 60.0
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession
var feedback_tick: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("PHYSICAL_METERED_EQUIPMENT: " + message)


func start(epoch: int) -> bool:
	if session != null:
		session.close()
		session.free()
	session = Session.new()
	owner.add_child(session)
	feedback_tick = 0
	var configured: bool = session.configure([
		{"model": &"gyrocrate", "producer": &"policy", "position": Vector2(100, 100), "usable_index": 9}],
		owner.get_world_2d().space, epoch)
	for body: RigidBody2D in session.bodies():
		body.gravity_scale = 0.0
	return configured


func step() -> void:
	session.advance(DT)
	session.bridge.step()
	session.complete_step()


func item() -> Dictionary:
	return session.observation(0).equipment


func action(extra: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {"usable_index": item().usable_index, "aim": Vector2.RIGHT, "power": 1.0}
	value.merge(extra, true)
	return {"equipment": value}


func submit(extra: Dictionary = {}) -> bool:
	return session.submit_local(0, action(extra), &"policy", 18)


func context(water_removed: int = 0, brine_removed: int = 0) -> Dictionary:
	return {"profile": Equipment.METERED_PROFILE, "available": true, "terminal": false, "reason": "",
		"world_instance_id": -99, "native_generation": 4, "policy_hash": "a".repeat(64),
		"mass_bits": 3, "maximum": 7, "allowed_materials": [3, 24],
		"water_units_initial": 224, "water_units_remaining": 224 - water_removed, "water_units_removed": water_removed,
		"brine_cells_initial": 32, "brine_cells_remaining": 32 - brine_removed, "brine_cells_removed": brine_removed}


func resources(value: Dictionary, charge: float = 100.0, cooldown: float = 0.0) -> void:
	feedback_tick += 1
	var row: Dictionary = session.equipment_frame().actors[0].duplicate(true)
	row.merge({"run_id": session.run_id, "epoch": session.epoch, "charge": charge,
		"cooldown": cooldown, "metered_drain": value.duplicate(true)}, true)
	session.accept_equipment_feedback({"run_id": session.run_id, "epoch": session.epoch,
		"tick": feedback_tick, "actors": [row], "receipts": []})


func receipt(request: Dictionary, applied: bool, quantity: int = 0) -> Dictionary:
	var value: Dictionary = request.duplicate(true)
	value.merge({"accepted": applied, "consumed": true, "reason": "applied" if applied else "empty_intake",
		"charge": 99.15 if applied else 100.0, "cooldown": 0.1 if applied else 0.0,
		"changed_cells": 1 if applied else 0}, true)
	if request.version == 2:
		var water: bool = request.material == 3
		var remaining: int = int(item().metered_drain.water_units_remaining) if water \
			else int(item().metered_drain.brine_cells_remaining)
		value["metered_drain"] = {"status": "applied" if applied else "refused", "reason": value.reason,
			"water_units_removed": quantity if water else 0, "brine_cells_removed": 0 if water else quantity,
			"sink_debit": quantity, "remaining_budget": remaining - quantity}
	return value


func deliver(value: Dictionary) -> int:
	return session.accept_equipment_feedback({"run_id": session.run_id, "epoch": session.epoch, "receipts": [value]})


func velocity() -> Vector2:
	var held: RigidBody2D = session.bodies()[int(item().body_id) - 1]
	return PhysicsServer2D.body_get_state(held.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "real Rapier owner is required")
	if failures:
		quit(1)
		return
	var definition: Dictionary = Catalog.entry(9)
	expect(definition.id == &"liquid_drain" and definition.range == 29.0 and definition.radius == 4 \
		and definition.cost == 0.85 and definition.cooldown == 0.1, "ordinary U10 catalogue identity and resource values remain fixed")
	var base: Dictionary = {"usable_index": 9, "instance_id": "fixture", "equipment_epoch": 1}
	expect(not Equipment.normalized_action(base).has("profile"), "ordinary nested action does not opt into a profile")
	for change: Dictionary in [
		{"profile": "metered-drain-v2", "material": 3}, {"profile": Equipment.METERED_PROFILE, "material": true},
		{"profile": Equipment.METERED_PROFILE, "material": 3.0}, {"profile": Equipment.METERED_PROFILE, "material": 2},
		{"profile": Equipment.METERED_PROFILE, "material": 3, "usable_index": 8}, {"profile": "", "material": 3},
		{"material": 3}, {"profile": Equipment.METERED_PROFILE, "material": 3, "quantity_budget": 9999}]:
		var invalid: Dictionary = base.duplicate(true)
		invalid.merge(change, true)
		expect(Equipment.normalized_action(invalid).is_empty(), "malformed/foreign metered profile refused: %s" % str(change))
	expect(start(101), "ordinary equipped physical actor configures")
	if not session.active():
		quit(1)
		return
	expect(item().profile == "" and not session.equipment_frame().actors[0].has("profile"), "ordinary equipment/frame remain unmetered")
	resources(context())
	expect(item().metered_drain.world_instance_id == -99 and item().metered_drain.water_units_remaining == 224,
		"ordinary readback caches signed native owner identity without selecting a profile")
	expect(submit({"trigger": true}), "ordinary U10 trigger admitted")
	step()
	var requests: Array = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].version == 1 and not requests[0].has("profile") \
		and requests[0].size() == Runtime.REQUEST_KEYS.size(), "ordinary U10 preserves exact version-1 request fields")
	if requests.is_empty():
		quit(1)
		return
	expect(deliver(receipt(requests[0], false)) == 1, "ordinary refusal still retires pending equipment")
	var old_equipment_epoch: int = int(item().equipment_epoch)
	expect(submit({"profile": Equipment.METERED_PROFILE, "material": 3}), "explicit metered Water selection admitted")
	step()
	expect(item().profile == Equipment.METERED_PROFILE and item().material == 3 \
		and item().equipment_epoch == old_equipment_epoch + 1, "same-U10 profile selection revokes the old equipment epoch")
	expect(Runtime.frame_error(session.equipment_frame()).is_empty(), "selected metered frame uses the runtime schema")
	expect(submit({"trigger": true, "power": 0.7}), "metered hold uses the existing physical input envelope")
	step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1, "one metered pulse pending at a time")
	if requests.is_empty():
		quit(1)
		return
	var released: Dictionary = requests[0]
	expect(released.version == 2 and released.profile == Equipment.METERED_PROFILE and released.material == 3 \
		and released.quantity_budget == 112 and released.power == 0.7 and released.world_instance_id == -99,
		"version-2 pulse binds copied owner identity and the 16-cell Water-unit budget")
	expect(Runtime.request_error(released, session.equipment_frame()).is_empty(), "producer v2 command matches runtime admission")
	expect(item().metered_drain.water_units_remaining == 224, "request creation never debits the copied material allowance")
	expect(submit(), "release is admitted before another native/physical sample")
	expect(not item().pending and session.drain_equipment_requests().is_empty() \
		and session.equipment_frame().actors[0].metered_request_id == "", "release immediately retires the uncommitted metered token")
	expect(Runtime.request_error(released, session.equipment_frame()) == "metered_released", "already extracted metered request fails the current-frame fence")
	expect(deliver(receipt(released, true, 7)) == 0, "late outcome for a released token cannot apply recoil or acceptance")
	for _index: int in range(3):
		step()
	expect(session.drain_equipment_requests().is_empty(), "released hold remains off on subsequent physical samples")
	expect(submit({"trigger": true}) and submit(), "rapid press/release both enter the existing controller")
	for _index: int in range(3):
		step()
	expect(session.drain_equipment_requests().is_empty() and not item().pending,
		"rapid released intake is not replayed later from the ordinary button-edge queue")
	expect(submit({"trigger": true}), "fresh held activation re-arms after release")
	step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1, "fresh hold emits exactly one new pulse")
	if requests.is_empty():
		quit(1)
		return
	var pending: Dictionary = requests[0]
	var success: Dictionary = receipt(pending, true, 7)
	var before_velocity: Vector2 = velocity()
	for key: String in ["material", "native_generation", "world_instance_id", "quantity_budget"]:
		var wrong: Dictionary = success.duplicate(true)
		wrong[key] = int(wrong[key]) + 1
		expect(deliver(wrong) == 0, "metered outcome must match %s" % key)
	for key: String in ["profile", "policy_hash"]:
		var wrong: Dictionary = success.duplicate(true)
		wrong[key] = "other"
		expect(deliver(wrong) == 0, "metered outcome must match %s" % key)
	var phantom: Dictionary = success.duplicate(true)
	phantom.metered_drain.water_units_removed = 0
	phantom.metered_drain.sink_debit = 0
	expect(deliver(phantom) == 0, "a positive activation cannot claim zero measured effect")
	phantom = success.duplicate(true)
	phantom.metered_drain.water_units_removed = true
	expect(deliver(phantom) == 0, "boolean quantity is not a measured integer")
	phantom = success.duplicate(true)
	phantom.metered_drain.water_units_removed = int(pending.quantity_budget) + 1
	phantom.metered_drain.sink_debit = int(pending.quantity_budget) + 1
	phantom.metered_drain.remaining_budget = 0
	expect(deliver(phantom) == 0,"copied debit cannot exceed the issued quantity budget")
	phantom = success.duplicate(true)
	phantom.metered_drain.remaining_budget = 225
	expect(deliver(phantom) == 0,"copied remaining budget cannot exceed native owner initial stock")
	for before: Variant in [true,-1,225,223]:
		phantom = success.duplicate(true)
		phantom.metered_drain["budget_before"] = before
		expect(deliver(phantom) == 0,"supplied budget-before must be an integer in stock bounds and close exactly: " + str(before))
	success.metered_drain["budget_before"] = 224
	expect(velocity() == before_velocity and item().accepted_uses == 0, "invalid outcomes never produce a physical drain event")
	expect(deliver(success) == 1 and item().accepted_uses == 1 \
		and is_equal_approx(float(item().charge), 99.15) and is_equal_approx(float(item().cooldown), 0.1),
		"accepted copied outcome consumes the fixed charge/cooldown exactly once")
	var after_velocity: Vector2 = velocity()
	expect(after_velocity != before_velocity and item().last_recoil.length() > 0.0, "accepted outcome reaches the real held Rapier body once")
	expect(deliver(success) == 0 and velocity() == after_velocity, "duplicate delivery cannot repeat recoil or accepted-use accounting")
	resources(context(7), 99.15, 0.1)
	expect(item().metered_drain.water_units_remaining == 217 and item().metered_drain.water_units_removed == 7,
		"displayed sink and remaining allowance come from the copied worker ledger")
	var copied: Dictionary = item()
	copied.metered_drain.water_units_remaining = 9999
	expect(item().metered_drain.water_units_remaining == 217, "equipment observations do not alias the retained native ledger")
	step()
	expect(session.drain_equipment_requests().is_empty() and item().last_result == "cooldown", "held drain respects accepted cooldown")
	expect(submit({"usable_index": 6}), "switching away from the drain is admitted")
	step()
	expect(item().profile == "" and not session.equipment_frame().actors[0].has("profile"), "different usable returns to its ordinary v1 profile")
	expect(submit({"usable_index": 9, "profile": Equipment.METERED_PROFILE, "material": 3}), "metered Water can be selected again explicitly")
	step()
	expect(item().metered_drain.water_units_remaining == 217, "reselecting the equipment cannot refill the removal allowance")
	expect(submit({"profile": Equipment.METERED_PROFILE, "material": 24}), "Brine dimension can be selected explicitly")
	step()
	expect(item().metered_drain.water_units_remaining == 217 and item().metered_drain.brine_cells_remaining == 32,
		"material selection preserves separate Water-unit and Brine-cell histories")
	resources(context(7), 0.0, 0.0)
	expect(submit({"trigger": true}), "low-charge hold reaches the normal equipment gate")
	step()
	expect(session.drain_equipment_requests().is_empty() and item().last_result == "resource", "insufficient charge produces no metered request")
	for _index: int in range(8):
		step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].quantity_budget == 16, "normal six-charge-per-second recharge permits a later bounded Brine pulse")
	if not requests.is_empty():
		expect(deliver(receipt(requests[0], false)) == 1 and not item().pending, "normal no-effect metered refusal retires its pending token")
	expect(submit(), "Brine hold released")
	step()
	resources(context(7), 100.0, 0.0)
	expect(submit({"alternate": true}), "precision pulse uses the existing right-button operation")
	step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].operation == "alternate" and requests[0].power == 1.0,
		"precision retains full requested power for the native effect's existing 35-percent scaling")
	if not requests.is_empty():
		expect(deliver(receipt(requests[0], true, 1)) == 1 and is_equal_approx(float(item().charge), 99.15),
			"precision accepted activation has the same fixed 0.85 charge cost")
		expect(is_equal_approx(item().last_recoil.length(), 1.1 * 0.35), "precision preserves the existing reduced physical recoil")
	expect(submit(), "precision released")
	step()
	resources(context(7, 1), 100.0, 0.0)
	expect(submit({"trigger": true}), "new pulse before owner replacement")
	step()
	requests = session.drain_equipment_requests()
	var obsolete: Dictionary = requests[0] if not requests.is_empty() else {}
	var replacement: Dictionary = context()
	replacement.world_instance_id = -100
	replacement.native_generation = 5
	resources(replacement)
	expect(not item().pending and not item().ready, "genuine native owner change retires pending input and requires release to re-arm")
	if not obsolete.is_empty():
		expect(deliver(receipt(obsolete, true, 1)) == 0, "outcome from the retired native generation is rejected")
	step()
	expect(session.drain_equipment_requests().is_empty(), "held input does not cross native reconstruction")
	expect(submit(), "release after owner replacement")
	step()
	expect(submit({"trigger": true}), "fresh owner accepts a new held request after release")
	step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].native_generation == 5 and requests[0].world_instance_id == -100,
		"fresh command is bound to the copied replacement native identity")
	var suspended_request: Dictionary = requests[0] if not requests.is_empty() else {}
	session.set_suspended(true)
	expect(not item().pending and session.drain_equipment_requests().is_empty(), "pause cancels outstanding metered work")
	expect(not submit({"trigger": true}), "paused owner cannot accept a new drain command")
	if not suspended_request.is_empty():
		expect(deliver(receipt(suspended_request, true, 1)) == 0, "paused owner rejects delayed success")
	session.set_suspended(false)
	expect(submit(), "resume requires a fresh admitted observation")
	step()
	var terminal: Dictionary = replacement.duplicate(true)
	terminal.available = false
	terminal.terminal = true
	terminal.reason = "owner_terminal"
	resources(terminal)
	expect(submit({"trigger": true}), "terminal-owner request enters only the local control envelope")
	step()
	expect(session.drain_equipment_requests().is_empty() and item().last_result == "metered_owner_terminal",
		"terminal native owner cannot produce another material request")
	var retired_run: String = session.run_id
	var retained_frame: Dictionary = session.equipment_frame().duplicate(true)
	expect(start(102), "actor retirement and restart creates a new physical session")
	expect(session.run_id != retired_run and item().metered_drain.is_empty(), "new actor cannot invent a native budget before readback")
	expect(submit({"profile": Equipment.METERED_PROFILE, "material": 3}), "fresh actor selects metered Water explicitly")
	step()
	expect(submit({"trigger": true}), "fresh actor's unseeded input is admitted only as control")
	step()
	expect(session.drain_equipment_requests().is_empty() and item().last_result == "awaiting_native_owner_context",
		"missing native owner context refuses safely without a default quantity allowance")
	resources(context(7, 1))
	expect(item().metered_drain.water_units_remaining == 217 and item().metered_drain.brine_cells_remaining == 31,
		"recreated actor adopts the existing owner's remaining budgets instead of resetting them")
	expect(Runtime.frame_transition_error(retained_frame, session.equipment_frame()) == "epoch",
		"old session frame cannot transition into a replacement actor epoch")
	var exhausted: Dictionary = context(224, 32)
	resources(exhausted)
	step()
	expect(session.drain_equipment_requests().is_empty() and item().last_result == "experimental_budget_exhausted",
		"exhausted experimental quantity budget refuses despite full equipment charge")
	var invalid_context: Dictionary = context()
	invalid_context.maximum = true
	resources(invalid_context)
	expect(item().metered_drain.is_empty() and not item().pending and item().last_result == "invalid_metered_readback",
		"invalid quantity readback removes metered authority without fabricating a refill")
	step()
	expect(session.drain_equipment_requests().is_empty(), "invalidated readback prevents future held pulses")
	var panel = ActorPanel.new()
	root.add_child(panel)
	panel.configure_equipment(9, 0.8, true)
	expect(panel.drain_profile_choice.visible and panel.selected_drain_profile() == "", "ordinary physical U10 defaults to explicit opt-out in the existing panel")
	panel.drain_profile_choice.select(1)
	panel._refresh_usable(10)
	expect(panel.selected_drain_profile() == Equipment.METERED_PROFILE and panel.selected_drain_material() == 3,
		"existing equipment panel exposes explicit Metered Water selection")
	panel.drain_profile_choice.select(2)
	panel._refresh_usable(10)
	expect(panel.selected_drain_material() == 24, "existing equipment panel exposes explicit Metered Brine selection")
	panel.configure_equipment(9, 0.8, false, Equipment.METERED_PROFILE, 3)
	expect(not panel.drain_profile_choice.visible and panel.selected_drain_profile() == "", "sampled equipment cannot silently select the physical metered profile")
	panel.configure_equipment(8, 0.8, true, Equipment.METERED_PROFILE, 3)
	expect(not panel.drain_profile_choice.visible and panel.selected_drain_profile() == "", "other usable identities cannot select the drain profile")
	panel.free()
	session.close()
	session.free()
	owner.free()
	await process_frame
	print("Physical metered equipment: %d assertions, %d failures; copied-outcome controls, not native quantity qualification" % [assertions, failures])
	quit(0 if failures == 0 else 1)
