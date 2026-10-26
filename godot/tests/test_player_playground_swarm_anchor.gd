extends SceneTree

const Field = preload("res://scripts/player_playground_material_field.gd")
const Setup = preload("res://scripts/player_playground_world.gd")
const Transport = preload("res://scripts/transport_profiles.gd")
var assertions: int = 0
var failures: int = 0
var metrics: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("SWARM_ANCHOR: "+message)


func positions(world: Object, material: int) -> Dictionary:
	var snapshot: Dictionary = world.diagnostic_snapshot(Vector2i(64,64),Vector2i(384,384))
	# Pressure quantity includes non-rendered overfill. The diagnostic visible
	# state_a sum alone is not a conservation ledger for the pressure family.
	var water: Dictionary = world.water_experiment_observation(Vector2i(64,64),Vector2i(384,384)) \
		if material == 3 else {}
	var cells: PackedByteArray = snapshot.cells
	var furthest: float = 0.0
	var total := Vector2.ZERO
	var count: int = 0
	# Census every actual copied cell, rather than trusting sampled/composite
	# receipts as a unique population or circular-containment proof.
	for index: int in range(cells.size()):
		if cells[index] == material:
			var position := Vector2(64+index%384,64+index/384)
			furthest = maxf(furthest,position.distance_to(Vector2(256,256)))
			total += position
			count += 1
	return {"count":count,"furthest":furthest,"centroid":total/maxf(1,count),
		"quantity":water.water_integer if material == 3 else snapshot.counts[2],
		"visible_quantity":water.get("water_visible",0),"overfill":water.get("water_overfill",0),"hash":snapshot.hash}


func prepare_policy(world: Object, solver: int) -> bool:
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var request: PackedInt32Array = bridge.default_liquid_policy()
	if solver > 0:
		var chosen: bool = false
		for row: Dictionary in bridge.liquid_policy_assignment_choices(request,3):
			if row.family == Setup.FAMILIES[solver] and row.variant == Setup.VARIANTS[solver] and row.accepted:
				request = row.request
				chosen = true
		if not chosen: return false
	var profile: Dictionary = Transport.resolve(Transport.preset(0))
	var rectangles := PackedInt32Array([64,440,384,8,1,248,248,16,16,3])
	var token: int = bridge.prepare_liquid_world(world,rectangles,profile.packed,PackedInt32Array([1,8,12,0]),
		PackedInt32Array(),request,{"definition_hash":("swarm-anchor/"+str(solver)).sha256_text(),
		"seed":0,"intent":"exploratory","pacing":"host_paced","region":PackedInt32Array([0,0,1024,1024]),
		"simulation_window_enabled":false,"cadence_lod_enabled":false,"maximum_rule_radius":3 if solver == 5 else 2})
	if token <= 0 or not bridge.commit_liquid_world(world,token):
		push_error("Swarm fixture constructor refused: "+str(bridge.get_last_error()))
		return false
	var correct: bool = false
	for row: Dictionary in world.get_liquid_solver_policy().assignments:
		if int(row.material) == 3:
			correct = row.applied_family == Setup.FAMILIES[solver] and row.applied_variant == Setup.VARIANTS[solver]
	expect(correct,"actual prepared native policy is the selected Water family/variant")
	return correct


func test_idle(material: int, solver: int = 0) -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"fresh native world")
	world.set_simulation_window_enabled(false)
	world.set_cadence_lod_enabled(false)
	# Allocated finite native region with an actual remote boundary only. No
	# invisible circular containment wall, rewriting or parcel restoration.
	world.diagnostic_fill_rect(Vector2i(64,64),Vector2i(384,384),0)
	world.diagnostic_fill_rect(Vector2i(64,440),Vector2i(384,8),1)
	if material == 3:
		if not prepare_policy(world,solver):
			expect(false,"selected Water fixture constructs "+str(solver))
			return
	else:
		expect(world.diagnostic_fill_rect(Vector2i(248,248),Vector2i(16,16),material),"seed exactly256 real parcels")
	var initial: Dictionary = positions(world,material)
	var largest: float = 0.0
	var moved: int = 0
	var different: Dictionary = {}
	for tick: int in range(360):
		var receipt: Dictionary = Field.apply(world,Vector2(256,256),Vector2.ZERO,material,0,tick)
		expect(receipt.accepted and receipt.anchor == Vector2(256,256) and receipt.radius == 60,
			"neutral operation retains fixed advertised anchor/radius")
		expect(receipt.native_calls == 5 and receipt.scanned_cells <= 21125 \
			and receipt.controlled_cells <= 2560 and receipt.movement_steps <= 10240,
			"composite work remains bounded by five existing native calls")
		moved += int(receipt.moved_cells)
		expect(world.simulation_tick(),"ordinary material gravity/flow still executes")
		var actual: Dictionary = positions(world,material)
		largest = maxf(largest,actual.furthest)
		different[actual.hash] = true
		expect(actual.quantity == initial.quantity,"independent complete-window quantity conserved")
		expect(actual.count > 0 and actual.furthest <= 60.0,"entire seeded idle population remains inside static circle everytick")
	var final: Dictionary = positions(world,material)
	expect(moved > 256 and different.size() >= 12,"idle population has active local patterns")
	metrics[str(material)+"/"+str(solver)] = {"maximum_distance":largest,"initial_quantity":initial.quantity,
		"final_quantity":final.quantity,"final_centroid":final.centroid,"final_cells":final.count,
		"final_visible_quantity":final.visible_quantity,"final_overfill":final.overfill,
		"different_snapshots":different.size(),"sampled_moves":moved,"ticks":360}


func test_obstacles_and_refusal() -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1}),"fresh wall fixture")
	world.set_simulation_window_enabled(false)
	world.set_cadence_lod_enabled(false)
	world.diagnostic_fill_rect(Vector2i(64,64),Vector2i(384,384),0)
	world.diagnostic_fill_rect(Vector2i(264,64),Vector2i(5,384),1)
	world.diagnostic_fill_rect(Vector2i(248,248),Vector2i(16,16),2)
	for tick: int in range(100):
		var receipt: Dictionary = Field.apply(world,Vector2(256,256),Vector2.ZERO,2,0,tick)
		expect(receipt.accepted and world.simulation_tick(),"actual solid obstacle retains admitted native tick")
	var actual: Dictionary = world.diagnostic_snapshot(Vector2i(64,64),Vector2i(384,384))
	var cells: PackedByteArray = actual.cells
	var beyond_wall: int = 0
	for index: int in range(cells.size()):
		if cells[index] == 2 and 64+index%384 >= 269: beyond_wall += 1
	expect(actual.counts[2] == 256 and beyond_wall == 0,"native wall blocks all parcels without replacement or quantity loss")
	expect(world.material_at(264,256) == 1 and world.material_at(268,256) == 1,"native wall remains authoritative")
	var before: String = world.get_physical_state_hash()
	for row: Array in [[Vector2(NAN,0),Vector2.ZERO,2,0,0], [Vector2(256,256),Vector2(INF,0),2,0,0],
		[Vector2(256,256),Vector2.ONE,2,0,0], [Vector2(256,256),Vector2.ZERO,4,0,0],
		[Vector2(256,256),Vector2.ZERO,2,4,0], [Vector2(256,256),Vector2.ZERO,2,0,-1],
		[Vector2(1024,256),Vector2.ZERO,2,0,0]]:
		expect(not Field.apply(world,row[0],row[1],row[2],row[3],row[4]).accepted,
			"invalid composite request refuses before any satellite mutation")
	expect(before == world.get_physical_state_hash(),"all refused composites preserve exact stored World")
	var retained: Dictionary = Field.apply(world,Vector2(256,256),Vector2.ZERO,2,0,101)
	var copied: Dictionary = retained.duplicate(true)
	Field.apply(world,Vector2(256,256),Vector2.ZERO,2,0,102)
	expect(retained == copied,"native subreceipts and aggregate are immutable copied values")


func run() -> void:
	test_idle(2)
	for solver: int in range(Setup.WATER_NAMES.size()): test_idle(3,solver)
	test_obstacles_and_refusal()
	print("SWARM_ANCHOR_METRICS ",JSON.stringify(metrics))
	print("SWARM_ANCHOR: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
