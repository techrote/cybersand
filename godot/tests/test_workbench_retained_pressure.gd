extends SceneTree

# A deep column creates real overfill while an enclosed pocket owns sealed gas.
# Actor edits inherit both. Explicit conversion measures what the target cannot carry.
const Contract = preload("res://scripts/microscenario_contract.gd")
const DAM = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var failures: Array[String] = []

func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		push_error(detail)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var checked: Dictionary = Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	var pf: PackedInt32Array = bridge.default_liquid_policy()
	pf[21] = 3 # pressure_flow_v1/reference, validated by the native preparer
	var rectangles := PackedInt32Array([3,1,1,400,3,2,400,1,1,1,5,400,1,1,1,2,401,4,1,1,4,400,1,1,3, 24,390,7,7,1, 25,391,5,5,0, 25,395,5,1,3])
	var options := {"workbench_extent":Vector2i(512,512), "workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]},
		"region":PackedInt32Array([0,384,48,32]), "intent":"exploratory",
		"definition_hash":checked.hash, "initial_bodies":PackedFloat32Array()}
	var args := [world,rectangles,checked.transport.packed,PackedInt32Array(checked.definition.water_semantics),
		PackedInt32Array(),pf,options]
	var token: int = bridge.callv("prepare_liquid_world",args)
	if token <= 0 or not bridge.commit_liquid_world(world,token):
		push_error("Failed to install pressure fixture: "+bridge.get_last_error())
		quit(1)
		return
	options.workbench_retain_cells = true
	token = bridge.callv("prepare_liquid_world",args)
	check(token>0,"zero-overfill control admitted")
	if token>0: bridge.discard_liquid_world(world,token)
	args[5]=bridge.default_liquid_policy()
	check(bridge.callv("prepare_liquid_world",args)==0 and "conversion" in str(bridge.get_last_error()),
		"non-forced policy change refused even with zero overfill and gas")
	args[5]=pf
	check(world.simulation_tick(),"actual pressure transfer tick")
	var overfill: int = world.inspect_pressure_cell(Vector2i(3,400)).overfill + world.inspect_pressure_cell(Vector2i(4,400)).overfill
	check(overfill>0,"pressure created nonzero overfill")
	var compartments: Array = world.inspect_gas_compartments().compartments
	var gas := 0
	for c:Dictionary in compartments: gas += int(c.amount)
	check(gas>0,"sealed pocket owns gas")
	check(world.water_experiment_fill_rect(Vector2i(150,400),Vector2i.ONE,75,0),"paint fractional Water")
	check(world.water_experiment_fill_rect(Vector2i(151,400),Vector2i.ONE,180,0),"paint second fractional Water")
	var before: String = world.get_physical_state_hash()
	var generation: int = world.get_liquid_policy_session_generation()

	# A retained actor/response edit does not grant any loss.
	token=bridge.callv("prepare_liquid_world",args)
	if token<=0 or not bridge.commit_liquid_world(world,token):
		check(false,"unchanged PF policy retained live inventory: "+str(bridge.get_last_error()))
		quit(1)
		return
	var receipt:Dictionary=world.get_applied_liquid_construction_receipt().workbench_conversion
	check(not receipt.requested and receipt.discarded_water_overfill==0 and receipt.preserved_water_overfill==overfill,
		"same-policy pressure edit retains all overfill")
	check(receipt.preserved_gas_amount==gas and receipt.water_before==receipt.water_after,
		"same-policy edit preserves gas and total Water")
	check(int(world.inspect_pressure_cell(Vector2i(3,400)).overfill)+int(world.inspect_pressure_cell(Vector2i(4,400)).overfill)==overfill,
		"pressure sidecars physically installed in replacement")
	var restored:Array=world.inspect_gas_compartments().compartments
	check(not restored.is_empty() and restored.size()==compartments.size() and restored[0].id==compartments[0].id and
		restored[0].amount==compartments[0].amount,"active gas identity and amount retained")
	check(world.simulation_tick(),"native pressure pass reuses inherited gas labels")
	overfill=int(world.inspect_pressure_cell(Vector2i(3,400)).overfill)+int(world.inspect_pressure_cell(Vector2i(4,400)).overfill)
	check(overfill>0,"pressure inventory still present after re-entry")
	check(world.water_experiment_fill_rect(Vector2i(150,400),Vector2i.ONE,75,0),"fractional input before conversion")
	check(world.water_experiment_fill_rect(Vector2i(151,400),Vector2i.ONE,180,0),"fractional input rounded up")
	before=world.get_physical_state_hash()
	generation=world.get_liquid_policy_session_generation()
	var fm:PackedInt32Array=bridge.default_liquid_policy()
	args[5]=fm
	token=bridge.callv("prepare_liquid_world",args)
	check(token==0 and "conversion" in str(bridge.get_last_error()),"strict PF inventory loss still rejected")
	check(world.get_physical_state_hash()==before and world.get_liquid_policy_session_generation()==generation,
		"failed strict replacement leaves retained World untouched")
	options.workbench_convert_liquid_inventory=true
	args[5]=pf
	check(bridge.callv("prepare_liquid_world",args)==0,"force cannot authorize same-policy inventory loss")

	# Changing only Brine must leave existing PF Water and gas in their
	# native sidecars. Neither fractional visible cell is rounded.
	var mixed:PackedInt32Array
	for choice:Dictionary in bridge.liquid_policy_assignment_choices(pf,24):
		if choice.family=="inertial_cellular_v1" and choice.variant=="reference" and choice.accepted:
			mixed=choice.request
			break
	args[5]=mixed
	options.maximum_rule_radius=3
	token=bridge.callv("prepare_liquid_world",args)
	if token<=0 or not bridge.commit_liquid_world(world,token):
		check(false,"Brine-only change installed: "+str(bridge.get_last_error()))
		quit(1)
		return
	receipt=world.get_applied_liquid_construction_receipt().workbench_conversion
	check(receipt.preserved_water_overfill==overfill and receipt.preserved_gas_amount==gas and
		receipt.discarded_water_overfill==0 and receipt.discarded_gas_amount==0 and
		receipt.normalization_produced==0 and receipt.normalization_consumed==0,"Brine-only edit preserved PF inventory")
	check(world.water_experiment_observation(Vector2i(150,400),Vector2i.ONE).water_visible==75 and
		world.water_experiment_observation(Vector2i(151,400),Vector2i.ONE).water_visible==180,
		"unrelated Brine assignment retains fractional Water cells")
	# Fractional FM can carry the visible fractional cells exactly. Candidate
	# readback already contains the real immutable receipt; discard this trial.
	args[5]=fm
	token=bridge.callv("prepare_liquid_world",args)
	if token>0:
		var pending:Dictionary=bridge.prepared_liquid_run_capture(world,token).native_run_encoding.workbench_conversion
		check(pending.requested and pending.discarded_water_overfill==overfill and pending.discarded_gas_amount==gas,
			"explicit PF to FM drop accounted")
		check(pending.normalization_produced==0 and pending.normalization_consumed==0 and pending.water_before-pending.water_after==overfill,
			"fractional target does not normalize")
		bridge.discard_liquid_world(world,token)
	else: check(false,"force PF to FM admitted: "+str(bridge.get_last_error()))

	# IN and CY need whole cells. Test native admission with no normalization
	# checkbox; the force intent selects the registered rounding operation.
	for family:int in [4,2]:
		var whole:PackedInt32Array=fm.duplicate()
		for choice:Dictionary in bridge.liquid_policy_assignment_choices(fm,3):
			if choice.family==("inertial_cellular_v1" if family==4 else "cellular_yield_v1") and choice.variant=="reference" and choice.accepted:
				whole=choice.request
				break
		args[5]=whole
		options.maximum_rule_radius=3 if family==4 else 2
		token=bridge.callv("prepare_liquid_world",args)
		if token<=0:
			check(false,"force whole-cell target %s admitted: %s" % [family,bridge.get_last_error()])
			continue
		var conversion:Dictionary=bridge.prepared_liquid_run_capture(world,token).native_run_encoding.workbench_conversion
		check(conversion.normalization_produced>0 and conversion.normalization_consumed>0,
			"whole-cell rounding has measured visible sources and sinks")
		check(conversion.water_before+conversion.normalization_produced==conversion.water_after+
			conversion.normalization_consumed+conversion.discarded_water_overfill,"Water conversion ledger closes")
		if family==4:
			bridge.discard_liquid_world(world,token)
		else:
			check(bridge.commit_liquid_world(world,token),"commit deliberately lossy CY policy")
			check(world.get_applied_liquid_construction_receipt().workbench_conversion==conversion,
				"applied conversion readback matches prepared receipt")
			check(world.material_at(150,400)==0 and world.material_at(151,400)==3,
				"registered threshold rounds one actual cell down and another up")
	check(world.simulation_tick(),"converted World remains usable")
	print("WORKBENCH_RETAINED_PRESSURE overfill=",overfill," gas=",gas," failures=",failures)
	quit(int(not failures.is_empty()))
