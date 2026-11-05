extends SceneTree

const Emitter = preload("res://scripts/workbench_emitter.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Fleet = preload("res://scripts/gcr_review_fleet.gd")
const Preferences = preload("res://scripts/flyer_preferences.gd")
var checks: int = 0
var failures: Array[String] = []

class TestWorld extends RefCounted:
	var cells: Dictionary = {}
	var masks: Dictionary = {}
	var reads: int = 0
	var writes: int = 0
	var refuse: bool = false
	func material_at(x: int, y: int) -> int:
		reads += 1
		return int(cells.get(Vector2i(x, y), 0))
	func rigid_body_id_at(x: int, y: int) -> int:
		reads += 1
		return int(masks.get(Vector2i(x, y), 0))
	func has_failed() -> bool: return false
	func emit_disc(x: int, y: int, radius: int, material: int) -> void:
		assert(radius == 0)
		writes += 1
		if not refuse: cells[Vector2i(x, y)] = material

class Controller extends RefCounted:
	func observation() -> Dictionary:
		return {"applied_force":Vector2(0, -5),"thrust":1.0,"side_thrust":-0.5}

class IntentRig extends RefCounted:
	var _profile: Dictionary = {"fleet_dispenser_q":12,"fleet_dispenser_e":8,"fleet_dispenser_s":0,
		"fleet_force":20.0,"fleet_control_mode":"body_thrust","fleet_side_thrusters":false,
		"fleet_emitter_origin":Vector2.ZERO}
	var _action: Dictionary = {"move":Vector2.UP,"effort":1.0,"primary":true}
	var _sizes := PackedVector2Array([Vector2(4, 7)])
	var _player_controller := Controller.new()

func _initialize() -> void: run.call_deferred()

func check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures.append(detail)
		push_error("FLYER_EMISSION: " + detail)

func request(amount: Variant = 1, material: Variant = 3) -> Dictionary:
	return {"instance_id":1,"epoch":1,"sequence":1,"tick":0,"first_proxy":1,"count":1,
		"source":Vector2(10.5, 20.5),"target":Vector2(18.5, 20.5),"material":material,
		"amount":amount,"nozzle":"test"}

func basic_amounts() -> void:
	for amount: int in [0, 1, 8]:
		var world := TestWorld.new()
		var rows: Array = Emitter.apply(world, [request(amount)], Vector2i(64, 64))
		check(rows.size() == 1 and rows[0].requested_cells == amount, "bounded request receipt " + str(amount))
		check(rows[0].changed_cells == amount and world.cells.size() == amount and world.writes == amount,
			"distinct exact amount " + str(amount))
		check(rows[0].attempted_cells == amount and rows[0].refused_cells == 0, "attempt accounting " + str(amount))
		check(world.reads <= Emitter.MAX_READS and rows[0].occupancy_reads == world.reads, "all reads charged " + str(amount))
	var legacy := request()
	legacy.erase("amount")
	var world := TestWorld.new()
	var row: Dictionary = Emitter.apply(world, [legacy], Vector2i(64, 64))[0]
	check(row.changed_cells == 1 and world.cells.has(Vector2i(18, 20)), "legacy omitted amount retains exact endpoint")
	for amount: Variant in [-1, 9, 1.5, NAN, "8"]:
		world = TestWorld.new()
		row = Emitter.apply(world, [request(amount)], Vector2i(64, 64))[0]
		check(row.reason == "amount" and world.writes == 0, "invalid amount cannot write " + str(amount))
	for material: Variant in [0, 10, 132, -1, 2.5]:
		world = TestWorld.new()
		row = Emitter.apply(world, [request(8, material)], Vector2i(64, 64))[0]
		check(row.reason == "material" and world.writes == 0, "invalid material cannot write " + str(material))
	for material: int in range(1, CyberCellWorld.LAST_MATERIAL + 1):
		if material == 10: continue
		world = TestWorld.new()
		row = Emitter.apply(world, [request(1, material)], Vector2i(64, 64))[0]
		check(row.changed_cells == 1 and world.cells[Vector2i(18, 20)] == material, "registered material admitted " + str(material))

func barriers_and_budget() -> void:
	for kind: String in ["hard", "foreign", "own_reentry"]:
		var world := TestWorld.new()
		world.masks[Vector2i(10, 20)] = 1
		world.masks[Vector2i(11, 20)] = 1
		for y: int in range(64):
			if kind == "hard": world.cells[Vector2i(13, y)] = 58
			else: world.masks[Vector2i(13, y)] = 2 if kind == "foreign" else 1
		var row: Dictionary = Emitter.apply(world, [request(8)], Vector2i(64, 64))[0]
		check(row.changed_cells == 0 and world.writes == 0 and row.refused_cells == 8,
			kind + " blocks the entire finite fan")
	var occupied := TestWorld.new()
	occupied.cells[Vector2i(18, 20)] = 3
	var row: Dictionary = Emitter.apply(occupied, [request(1, 8)], Vector2i(64, 64))[0]
	check(row.changed_cells == 0 and row.reason == "blocked" and occupied.cells[Vector2i(18, 20)] == 3,
		"occupied material survives source insertion")
	var rejected := TestWorld.new()
	rejected.refuse = true
	row = Emitter.apply(rejected, [request(8)], Vector2i(64, 64))[0]
	check(row.changed_cells == 0 and row.reason == "write_refused" and row.attempted_cells == 8,
		"adapter refusal never reports injection")
	var budget := TestWorld.new()
	var requests: Array = []
	for index: int in 3:
		var long := request(8)
		long.target = Vector2(60.5, 20.5 + index)
		long.nozzle = "budget" + str(index)
		requests.append(long)
	var rows: Array = Emitter.apply(budget, requests, Vector2i(80, 64))
	check(budget.reads <= Emitter.MAX_READS, "three nozzles share one fixed read budget")
	var exhausted := false
	for value: Dictionary in rows:
		if value.endpoint_reasons.has("read_budget"): exhausted = true
	check(exhausted, "read exhaustion explicitly refuses remaining endpoints")
	var too_many: Array = []
	for _i: int in 25: too_many.append(request())
	check(Emitter.apply(TestWorld.new(), too_many, Vector2i(64, 64)).is_empty(), "queue capacity retained")

func producer_and_fractional() -> void:
	for rate: float in [0.0, 0.125, 0.25, 0.5, 1.0, 2.5, 8.0]:
		var sum: int = 0
		for index: int in 16:
			var amount: int = Emitter.amount_for_tick(rate, index * Emitter.CADENCE_TICKS)
			check(amount >= 0 and amount <= 8, "fractional pulse remains bounded")
			sum += amount
		check(sum == floori(16.0 * rate), "fractional pulse exact cumulative count " + str(rate))
	var rig := IntentRig.new()
	var identity := {"instance_id":1,"epoch":1,"sequence":1,"tick":0,"first_proxy":1,"count":1}
	var binding := {"ports":{"q":true,"e":true,"s":true,"boost":false},"fire":false}
	var nozzles: Array = Emitter.intents(rig, Transform2D(0, Vector2(30, 30)), binding, identity)
	check(nozzles.size() == 2 and nozzles[0].material == 12 and nozzles[1].material == 8,
		"legacy authored ports retain materials and cadence count")
	rig._profile["fleet_customization"] = {"q_material":2,"q_amount":8.0,"e_material":24,"e_amount":0.0,"s_material":3,"s_amount":8.0,"fire_amount":0.0}
	nozzles = Emitter.intents(rig, Transform2D(0, Vector2(30, 30)), binding, identity)
	check(nozzles.size() == 1 and nozzles[0].amount == 8 and nozzles[0].material == 2,
		"override existing port; zero amount disables and cannot add absent S capability")
	binding.fire = true
	nozzles = Emitter.intents(rig, Transform2D(0, Vector2(30, 30)), binding, identity)
	check(nozzles.size() == 1, "zero chemical Fire quantity produces no Fire intent")

func native_water() -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not check_native(world): return
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(0, 0), Vector2i(64, 64))
	var row: Dictionary = Emitter.apply(world, [request(8, 3)], Vector2i(64, 64))[0]
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(0, 0), Vector2i(64, 64))
	check(row.changed_cells == 8 and int(after.water_mass) - int(before.water_mass) == 8 * 255,
		"real native Water injection quantity closes exactly")
	check(int(after.counts[3]) - int(before.counts[3]) == 8, "real native Water cells match the source receipt")
	var repeated: Dictionary = Emitter.apply(world, [request(8, 3)], Vector2i(64, 64))[0]
	check(repeated.changed_cells == 0 and world.diagnostic_snapshot(Vector2i.ZERO, Vector2i(64, 64)).water_mass == after.water_mass,
		"occupied native endpoints neither erase nor add quantity")

func check_native(world: Object) -> bool:
	check(world != null, "native source owner available")
	if world == null: return false
	var ok: bool = world.diagnostic_reset({"workers":1})
	check(ok, "actual native empty fixture reset")
	return ok

func definition(model: String, identity: int, tuning: Dictionary = {}) -> Dictionary:
	var value := {"model":model,"instance_id":identity,"producer":"human","position":Vector2(64, 48),
		"canvas_extent":Vector2i(512,512),"workbench_options":{"response":"LA-SELECTIVE","budget":20.0,
		"mass_multiplier":1.0,"inertia_multiplier":1.0,"thrust_multiplier":1.0,"torque_multiplier":1.0,"boost_multiplier":2.0}}
	if not tuning.is_empty(): value.workbench_options["customization"] = tuning
	return value

func session_visual_contract() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var session := Session.new()
	host.add_child(session)
	var tuning: Dictionary = Preferences.tuning_defaults(Fleet.capabilities(Fleet.index_for_id("scooper")))
	check(session.configure([definition("scooper",1,tuning)], host.get_world_2d().space, 1), "real compound session")
	if not session.active(): host.free(); return
	check(session.submit_workbench_action(1,{"move":Vector2.ZERO,"effort":1.0},
		{"q":false,"e":false,"s":false,"boost":false},false), "neutral hover lease with chemical Fire disabled")
	session.advance(1.0/60.0)
	var parts: Array = session.render_parts()
	var visuals: Array = parts.filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust"))
	check(parts.size() == 5 and visuals.size() == 1, "one exhaust payload for five Scooper hull proxies")
	check(not visuals.is_empty() and visuals[0].gcr_exhaust.main > 0.0, "neutral live deck displays its actual hover actuator")
	var pose: Transform2D = session.bridge.body_transform(0)
	check(not visuals.is_empty() and Transform2D(visuals[0].gcr_exhaust.pose).is_equal_approx(pose), "visual uses selected physical pose")
	var stale := {"session":session.bridge._session + 1,"epoch":session.epoch,"instances":{}}
	check(session.render_parts(stale).filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(),
		"stale display owner cannot display live jets")
	var copied := Transform2D(0.3, Vector2(110, 80))
	var frame := {"session":session.bridge._session,"epoch":session.epoch,
		"instances":{1:{"generation":session.epoch,"pose":copied}}}
	var copied_parts: Array = session.render_parts(frame)
	var copied_visuals: Array = copied_parts.filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust"))
	check(copied_visuals.size() == 1 and Transform2D(copied_visuals[0].gcr_exhaust.pose).is_equal_approx(copied),
		"exhaust follows the exact display publication rather than a newer live pose")
	session.set_suspended(true)
	check(session.render_parts().filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(),
		"suspend cancels exhaust immediately")
	session.set_suspended(false)
	session.submit_workbench_action(1,{"move":Vector2.UP,"effort":1.0},
		{"q":false,"e":false,"s":false,"boost":false},false)
	session.advance(1.0/60.0)
	for _step: int in 7:
		session.advance(1.0/60.0)
		session.bridge.step()
		session.complete_step()
	check(session.render_parts().filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(),
		"expired lease cannot retain decorative propulsion")
	session.free()
	tuning.thruster_visuals = false
	session = Session.new()
	host.add_child(session)
	check(session.configure([definition("midge",1,tuning)], host.get_world_2d().space, 2), "hidden-visual configured session")
	session.submit_workbench_action(1,{"move":Vector2.UP,"effort":1.0},
		{"q":false,"e":false,"s":false,"boost":false},false)
	session.advance(1.0/60.0)
	check(session.workbench_actor_state(1).controller.applied_force.length() > 0.0 \
		and session.render_parts().filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(),
		"cosmetic toggle hides jets without removing actuation")
	session.free()
	for swapped: bool in [false, true]:
		tuning = Preferences.tuning_defaults(Fleet.capabilities(Fleet.index_for_id("kestrel")))
		tuning.swap_side_thrusters = swapped
		session = Session.new()
		host.add_child(session)
		check(session.configure([definition("kestrel", 1, tuning)], host.get_world_2d().space, 3), "side-exhaust session")
		session.submit_workbench_action(1,{"trim":-1.0,"effort":1.0},
			{"q":true,"e":false,"s":false,"boost":false},false)
		session.advance(1.0/60.0)
		var side_parts: Array = session.render_parts()
		var observed: float = session.workbench_actor_state(1).controller.side_thrust
		check(side_parts[0].gcr_exhaust.side == observed and signf(observed) == (1.0 if swapped else -1.0),
			"side exhaust follows the actual swapped actuator sign")
		session.free()
	session = Session.new()
	host.add_child(session)
	var zero := definition("midge", 1)
	zero.workbench_options.thrust_multiplier = 0.0
	zero.workbench_options.torque_multiplier = 0.0
	check(session.configure([zero], host.get_world_2d().space, 4), "zero-actuation graph")
	session.submit_workbench_action(1,{"move":Vector2.UP,"primary":true,"effort":1.0},
		{"q":false,"e":false,"s":false,"boost":false},false)
	session.advance(1.0/60.0)
	check(session.render_parts().filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(),
		"zero force and torque cannot create a fake actuator graphic")
	session.free()
	session = Session.new()
	host.add_child(session)
	var passive := definition("reference_barrel", 1)
	passive.producer = "passive"
	check(session.configure([passive], host.get_world_2d().space, 5), "passive graph")
	check(session.render_parts().filter(func(part: Dictionary) -> bool: return part.has("gcr_exhaust")).is_empty(),
		"passive barrel has no propulsion graphic")
	host.free()

func run() -> void:
	basic_amounts()
	barriers_and_budget()
	producer_and_fractional()
	native_water()
	session_visual_contract()
	await process_frame
	print("FLYER_EMISSION ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
