extends SceneTree

# A real deep column transfers visible Water into PF overfill. A setup of
# stored material/state/temperature cannot encode that part of the inventory.
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
	var rectangles := PackedInt32Array([3,1,1,400,3,2,400,1,1,1,5,400,1,1,1,2,401,4,1,1,4,400,1,1,3])
	var options := {"workbench_extent":Vector2i(512,512), "workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),"geometry":PackedFloat64Array(),"bodies":[]},
		"region":PackedInt32Array([0,400,8,8]), "intent":"exploratory",
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
	check(world.simulation_tick(),"actual pressure transfer tick")
	var overfill: int = world.inspect_pressure_cell(Vector2i(3,400)).overfill + world.inspect_pressure_cell(Vector2i(4,400)).overfill
	check(overfill>0,"pressure created nonzero overfill")
	var before: String = world.get_physical_state_hash()
	var generation: int = world.get_liquid_policy_session_generation()
	for policy in [pf,bridge.default_liquid_policy()]:
		args[5] = policy
		token = bridge.callv("prepare_liquid_world",args)
		check(token==0 and "overfill" in str(bridge.get_last_error()),"lossy reconstruction refused with reason")
		if token>0: bridge.discard_liquid_world(world,token)
		check(world.get_physical_state_hash()==before and world.get_liquid_policy_session_generation()==generation,
			"retained World hash/generation unchanged")
	check(world.simulation_tick(),"retained World remains usable")
	print("WORKBENCH_RETAINED_PRESSURE overfill=",overfill," failures=",failures)
	quit(int(not failures.is_empty()))
