extends SceneTree

# #361 v3 equipment/session qualification with a real Rapier held body and
# copied worker outcomes. Native quantity truth is qualified separately by
# test_in_tools_361_adapter/leak_flow; this file proves command/receipt custody.
const Session = preload("res://scripts/physical_actor_session.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const Runtime = preload("res://scripts/physical_usable_runtime.gd")
const Panel = preload("res://scripts/actor_prototype_panel.gd")
var assertions: int = 0
var failures: int = 0
var owner: Node2D
var session: CyberPhysicalActorSession
var feedback_tick: int = 0


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("IN_TOOLS_361_EQUIPMENT: " + message)


func _start(usable: int, epoch: int) -> bool:
	if session != null:
		session.close()
		session.free()
	session = Session.new()
	owner.add_child(session)
	feedback_tick = 0
	var configured: bool = session.configure([
		{"model": &"gyrocrate", "producer": &"policy", "position": Vector2(100, 100),
		 "usable_index": usable}], owner.get_world_2d().space, epoch)
	for body: RigidBody2D in session.bodies():
		body.gravity_scale = 0.0
	return configured


func _step() -> void:
	session.advance(1.0 / 60.0)
	session.bridge.step()
	session.complete_step()


func _item() -> Dictionary:
	return session.observation(0).equipment


func _action(extra: Dictionary = {}) -> Dictionary:
	var value: Dictionary = {
		"usable_index": int(_item().usable_index), "aim": Vector2.RIGHT, "power": 1.0
	}
	value.merge(extra, true)
	return {"equipment": value}


func _submit(extra: Dictionary = {}) -> bool:
	return session.submit_local(0, _action(extra), &"policy", 18)


func _context(remaining: int = 224, admitted: int = 0, world_id: int = -99,
		generation: int = 4, aperture_open: bool = false) -> Dictionary:
	return {
		"controller": "in-tools-liquid-v1", "available": true, "terminal": false, "reason": "",
		"world_instance_id": world_id, "native_generation": generation,
		"policy_hash": "b".repeat(64), "mass_bits": 3, "maximum": 7,
		"allowed_profiles": [Equipment.IN_TOOLS_NOZZLE_PROFILE, Equipment.IN_TOOLS_LEAK_PROFILE],
		"water_units_initial": 224, "water_units_remaining": remaining,
		"water_units_admitted": admitted, "aperture_open": aperture_open,
		"aperture_point": Vector2i(20, 20) if aperture_open else Vector2i.ZERO,
	}


func _readback(context: Dictionary, charge: float = 100.0, cooldown: float = 0.0) -> void:
	feedback_tick += 1
	var row: Dictionary = session.equipment_frame().actors[0].duplicate(true)
	row.merge({"run_id": session.run_id, "epoch": session.epoch, "charge": charge,
		"cooldown": cooldown, "in_tools": context.duplicate(true)}, true)
	session.accept_equipment_feedback({
		"run_id": session.run_id, "epoch": session.epoch, "tick": feedback_tick,
		"actors": [row], "receipts": []})


func _nozzle_receipt(request: Dictionary, accepted: bool, quantity: int = 0) -> Dictionary:
	var value: Dictionary = request.duplicate(true)
	var remaining: int = int(request.quantity_budget) - quantity if accepted else int(request.quantity_budget)
	value.merge({
		"accepted": accepted, "consumed": true,
		"reason": "applied" if accepted else "destination_occupied",
		"charge": 99.0 if accepted else 100.0,
		"cooldown": 0.1 if accepted else 0.0,
		"changed_cells": 1 if accepted else 0,
		"in_tools": {
			"schema": "in-tools-liquid-outcome-v1",
			"status": "applied" if accepted else "refused",
			"reason": "applied" if accepted else "destination_occupied",
			"request_id": request.request_id,
			"profile": Equipment.IN_TOOLS_NOZZLE_PROFILE,
			"material": 3,
			"world_instance_id": request.world_instance_id,
			"native_generation": request.native_generation,
			"policy_hash": request.policy_hash,
			"physical_frame_tick": 12,
			"kind": "directed_in_nozzle",
			"transport_mode": "inertial_cellular_source_v1",
			"ballistic_transport": false,
			"water_units_added": quantity,
			"source_credit": quantity,
			"sink_debit": 0,
			"budget_before": int(request.quantity_budget),
			"remaining_budget": remaining,
		}
	}, true)
	return value


func _leak_receipt(request: Dictionary, accepted: bool, reason: String = "applied") -> Dictionary:
	var value: Dictionary = request.duplicate(true)
	value.merge({
		"accepted": accepted, "consumed": true, "reason": reason,
		"charge": 99.5 if accepted else 100.0,
		"cooldown": 0.1 if accepted else 0.0,
		"changed_cells": 1 if accepted else 0,
		"in_tools": {
			"schema": "in-tools-liquid-outcome-v1",
			"status": "applied" if accepted else "refused",
			"reason": reason,
			"request_id": request.request_id,
			"profile": Equipment.IN_TOOLS_LEAK_PROFILE,
			"material": 0,
			"world_instance_id": request.world_instance_id,
			"native_generation": request.native_generation,
			"policy_hash": request.policy_hash,
			"physical_frame_tick": 20,
			"kind": "reversible_leak",
			"source_credit": 0,
			"sink_debit": 0,
			"quantity_delta": 0,
		}
	}, true)
	return value


func _deliver(receipt: Dictionary) -> int:
	return session.accept_equipment_feedback({
		"run_id": session.run_id, "epoch": session.epoch, "receipts": [receipt]})


func _nozzle() -> void:
	expect(_start(Equipment.IN_TOOLS_NOZZLE_USABLE, 3611), "real Rapier U02 actor configures")
	_readback(_context())
	expect(_submit({"profile": Equipment.IN_TOOLS_NOZZLE_PROFILE, "material": 3}),
		"explicit U02 nozzle selection enters existing equipment envelope")
	_step()
	expect(_item().profile == Equipment.IN_TOOLS_NOZZLE_PROFILE and _item().material == 3,
		"nozzle profile is copied into the physical equipment identity")
	expect(_submit({"trigger": true, "power": 0.75}), "nozzle held trigger admitted")
	_step()
	var requests: Array = session.drain_equipment_requests()
	expect(requests.size() == 1, "one nozzle request is pending")
	if requests.is_empty():
		return
	var request: Dictionary = requests[0]
	expect(request.version == 3 and request.profile == Equipment.IN_TOOLS_NOZZLE_PROFILE
		and request.material == 3 and request.quantity_budget == 224,
		"v3 request binds exact copied source budget and material identity")
	expect(Runtime.request_error(request, session.equipment_frame()).is_empty(),
		"runtime admits the exact current-frame nozzle request")
	expect(_submit(), "release is admitted before worker completion")
	expect(not _item().pending and session.drain_equipment_requests().is_empty(),
		"release retires uncommitted nozzle authority immediately")
	expect(Runtime.request_error(request, session.equipment_frame()) == "experimental_released",
		"extracted nozzle token fails the current-frame release fence")
	expect(_deliver(_nozzle_receipt(request, true, 7)) == 0,
		"late success for released source token cannot apply recoil or source acceptance")

	expect(_submit({"trigger": true}), "fresh nozzle hold re-arms")
	_step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1, "fresh nozzle produces one new token")
	if requests.is_empty():
		return
	request = requests[0]
	var good: Dictionary = _nozzle_receipt(request, true, 7)
	var forged: Dictionary = good.duplicate(true)
	forged.in_tools.source_credit = 0
	expect(_deliver(forged) == 0, "source-credit mismatch is rejected before physical effect")
	forged = good.duplicate(true)
	forged.in_tools.ballistic_transport = true
	forged.in_tools.transport_mode = "ballistic_water_v1"
	expect(_deliver(forged) == 0,
		"ballistic-labelled copied outcome is rejected before it can masquerade as #361 IN transport")
	var before_uses: int = int(_item().accepted_uses)
	expect(_deliver(good) == 1 and int(_item().accepted_uses) == before_uses + 1,
		"valid source-credit receipt is consumed exactly once by real Rapier equipment")
	expect(_item().last_receipt.in_tools.transport_mode == "inertial_cellular_source_v1"
		and not bool(_item().last_receipt.in_tools.ballistic_transport),
		"effective copied receipt visibly retains IN/non-ballistic identity")
	expect(_deliver(good) == 0, "duplicate nozzle receipt cannot repeat accepted effect")
	_readback(_context(217, 7), float(_item().charge), float(_item().cooldown))
	expect(int(_item().in_tools.water_units_remaining) == 217
		and int(_item().in_tools.water_units_admitted) == 7,
		"source budget readback follows worker ledger; selection never debits locally")


func _leak() -> void:
	expect(_start(Equipment.IN_TOOLS_LEAK_USABLE, 3612), "real Rapier U10 actor configures")
	_readback(_context())
	expect(_submit({"profile": Equipment.IN_TOOLS_LEAK_PROFILE, "material": 0}),
		"explicit U10 leak selection enters existing equipment envelope")
	_step()
	expect(_item().profile == Equipment.IN_TOOLS_LEAK_PROFILE and _item().material == 0,
		"leak identity is explicit and separate from metered drain")
	expect(_submit({"trigger": true}), "leak-open trigger admitted")
	_step()
	var requests: Array = session.drain_equipment_requests()
	expect(requests.size() == 1, "one leak-open request is pending")
	if requests.is_empty():
		return
	var open_request: Dictionary = requests[0]
	expect(open_request.version == 3 and open_request.quantity_budget == 0,
		"geometry aperture carries no fabricated source/sink budget")
	var open_receipt: Dictionary = _leak_receipt(open_request, true)
	expect(_deliver(open_receipt) == 1 and _item().last_receipt.in_tools.quantity_delta == 0,
		"zero-quantity aperture outcome is accepted exactly once")
	_readback(_context(224, 0, -99, 4, true), float(_item().charge), float(_item().cooldown))
	for _tick: int in range(8):
		_step()
	expect(_submit(), "leak trigger releases after cooldown")
	_step()
	expect(_submit({"alternate": true}), "alternate closure enters existing U10 controls")
	_step()
	requests = session.drain_equipment_requests()
	expect(requests.size() == 1 and requests[0].operation == "alternate",
		"closure request is explicit alternate operation")
	if requests.is_empty():
		return
	var close_request: Dictionary = requests[0]
	var occupied: Dictionary = _leak_receipt(close_request, false, "occupied_aperture")
	var refused_before: int = int(_item().refused_uses)
	expect(_deliver(occupied) == 1 and int(_item().refused_uses) == refused_before + 1,
		"occupied closure is an explicit consumed refusal with zero quantity")
	expect(int(_item().last_receipt.in_tools.source_credit) == 0
		and int(_item().last_receipt.in_tools.sink_debit) == 0,
		"refused aperture closure cannot fabricate source or sink accounting")

	_readback(_context(224, 0, -100, 5, true))
	expect(not _item().pending and not _item().ready,
		"native owner replacement retires any old-generation experimental authority")
	_step()
	expect(session.drain_equipment_requests().is_empty(),
		"held state cannot cross owner generation replacement")


func _selector() -> void:
	var panel = Panel.new()
	root.add_child(panel)
	panel.configure_equipment(Equipment.IN_TOOLS_NOZZLE_USABLE, 0.8, true)
	expect(panel.drain_profile_choice.visible and panel.selected_drain_profile() == "",
		"U02 defaults to ordinary Water Lance with explicit opt-out")
	panel.drain_profile_choice.select(4)
	panel._refresh_usable(Equipment.IN_TOOLS_NOZZLE_USABLE + 1)
	expect(panel.selected_drain_profile() == Equipment.IN_TOOLS_NOZZLE_PROFILE
		and panel.selected_drain_material() == 3,
		"U02 selector exposes directed IN Water nozzle")
	panel.configure_equipment(Equipment.IN_TOOLS_LEAK_USABLE, 0.8, true)
	panel.drain_profile_choice.select(3)
	panel._refresh_usable(Equipment.IN_TOOLS_LEAK_USABLE + 1)
	expect(panel.selected_drain_profile() == Equipment.IN_TOOLS_LEAK_PROFILE
		and panel.selected_drain_material() == 0,
		"U10 selector exposes reversible zero-quantity leak")
	panel.configure_equipment(6, 0.8, true, Equipment.IN_TOOLS_NOZZLE_PROFILE, 3)
	expect(not panel.drain_profile_choice.visible and panel.selected_drain_profile() == "",
		"unrelated usable cannot silently inherit an experimental liquid profile")
	panel.free()


func run() -> void:
	owner = Node2D.new()
	root.add_child(owner)
	expect(ClassDB.class_exists("RapierPhysicsServer2D"), "actual Rapier server is required")
	if failures == 0:
		_nozzle()
		_leak()
		_selector()
	if session != null:
		session.close()
		session.free()
	owner.free()
	await process_frame
	print("IN_TOOLS_361_EQUIPMENT: %d assertions; %d failures; real Rapier copied-outcome custody" %
		[assertions, failures])
	quit(0 if failures == 0 else 1)
