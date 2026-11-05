extends SceneTree
# Actual native square-wheel-mask support. Same source buggy wheel diameter8,
# mass.48,disk inertia3.84; symmetric packed flat bed, downward speed3.
const Contract=preload("res://scripts/microscenario_contract.gd")
const DAM="res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var checked: Dictionary
var adapter: Variant
var world: Variant
var checks: int=0
var failures: Array[String]=[]
var results: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); push_error("ROTATED_SUPPORT: "+reason)
func observe(degrees: int, material: int, epoch: int) -> Dictionary:
	var angle: float=Vector2(deg_to_rad(degrees),0).x
	# Raster contact uses neighbouring cell centres. Flooring places the first
	# bed row adjacent to the lowest occupied raster row at these orientations.
	var bottom: int=floori(100.0+4.0*(absf(cos(angle))+absf(sin(angle))))
	var owner: Dictionary={"id":1,"instance_id":42,"generation":epoch,"part_index":0,"first_proxy":1,"count":1,"budget":20.0,"gravity":150.0,"external_drive":false}
	var states:=PackedFloat64Array([1,100,100,angle,8,8,0,3,0,.48,1,3.84,100,100,1.0,1.0/60.0,epoch])
	var geometry:=PackedFloat64Array([0,0,8,8])
	var sample: Dictionary={"session":epoch,"epoch":epoch,"states":states,"geometry":geometry,"bodies":[owner]}
	var token: int=adapter.prepare_liquid_world(world,PackedInt32Array([80,bottom,40,40,material]),checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),adapter.default_liquid_policy(),
		{"workbench_extent":Vector2i(256,256),"workbench_response":"LA-SELECTIVE","workbench_sample":sample,
		"region":PackedInt32Array([0,0,256,256]),"intent":"exploratory","definition_hash":checked.hash,
		"initial_bodies":PackedFloat32Array([1,100,100,angle,8,8,0,3,0,.48,1])})
	check(token>0 and adapter.commit_liquid_world(world,token),"prepared "+str(degrees))
	check(world.prepare_workbench_coupling(states,geometry,[owner],epoch,epoch,true),"live sample "+str(degrees))
	var packet: Dictionary=world.workbench_coupling_results()
	check(packet.get("valid",false) and packet.rows.size()==1,"native result "+str(degrees))
	if not packet.get("valid",false) or packet.rows.size()!=1: return {}
	var row: Dictionary=packet.rows[0]
	return {"degrees":degrees,"angle":angle,"material":material,"bed_y":bottom,"contacts":row.contacts,"normal_accepted":row.normal_accepted,
		"passive_impulse":row.passive_impulse,"passive_torque":row.passive_torque,"normal_capacity":row.normal_capacity,"support":row.support,
		"wrench_bits":var_to_bytes([row.impulse,row.torque,row.correction,row.normal_accepted,row.passive_impulse,row.passive_torque,
			row.normal_capacity,row.body_capacity,row.event_accepted,row.event_torque]).hex_encode()}
func run() -> void:
	adapter=ClassDB.instantiate(&"CyberDemoBridge"); world=ClassDB.instantiate(&"CyberNativeCellWorld")
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	for degrees: int in [0,45,90]:
		var row: Dictionary=observe(degrees,2,1+degrees); results.append(row)
		if row.is_empty(): continue
		check(row.normal_accepted>0 and row.passive_impulse.y<0,"genuine bearing "+str(degrees))
		check(not row.support.is_empty(),"support witness "+str(degrees))
		if not row.support.is_empty(): check(absf(row.support.normal.x)<.01 and row.support.normal.y<-.99,"unbiased upward support on symmetric bed "+str(degrees))
	var water: Dictionary=observe(45,3,100); results.append(water)
	if not water.is_empty(): check(water.support.is_empty() and water.normal_accepted==0.0,"Water negative control")
	var reference_path: String=OS.get_environment("CYBERSAND_ROTATED_SUPPORT_REFERENCE")
	if not reference_path.is_empty():
		var reference: Variant=JSON.parse_string(FileAccess.get_file_as_string(reference_path))
		check(reference is Array and reference.size()==results.size(),"counterfactual reference population")
		if reference is Array and reference.size()==results.size():
			for index: int in results.size(): check(reference[index].wrench_bits==results[index].wrench_bits,"native wrench bits unchanged at "+str(results[index].degrees)+" material "+str(results[index].material))
	var write_path: String=OS.get_environment("CYBERSAND_ROTATED_SUPPORT_WRITE_REFERENCE")
	if not write_path.is_empty():
		var file=FileAccess.open(write_path,FileAccess.WRITE)
		check(file!=null,"write original wrench reference")
		if file!=null: file.store_string(JSON.stringify(results)); file.close()
	adapter=null; world=null
	print("WORKBENCH_ROTATED_SUPPORT ",JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	quit(int(not failures.is_empty()))
