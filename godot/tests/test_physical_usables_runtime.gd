extends SceneTree

# These are real native material/mask effects. No fake adapter fallback can turn
# a missing GDExtension into a passing physical integration result.
const Runtime = preload("res://scripts/physical_usable_runtime.gd")
const Catalog = preload("res://scripts/usable_catalog.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var failures: int = 0
var checks: int = 0
var world: Object
var runtime = Runtime.new()
var frame: Dictionary = {}
var sequence: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("USABLE002_NATIVE " + message)


func _actor(index: int, owner: int = 0, center: Vector2 = Vector2(100.5, 100.5), body: int = 1) -> Dictionary:
	return {"actor_id": owner, "generation": 0, "equipment_epoch": 1,
		"instance_id": "native-actor-%d" % owner, "usable_index": index, "state": "held",
		"body_id": body, "position": center, "rotation": 0.0, "half_extents": Vector2(2, 2),
		"muzzle": center + Vector2(4, 0), "direction": Vector2.RIGHT,
		"owner_origin": center - Vector2(8, 0), "active": true, "lease_deadline": 100000,
		"parts": [{"body_id": body, "position": center, "rotation": 0.0, "half_extents": Vector2(2, 2)}]}


func _reset(index: int) -> void:
	_check(bool(world.diagnostic_reset({"workers": 1})), "native diagnostic reset")
	runtime.reset()
	sequence = 0
	frame = {"version": 1, "run_id": "native-physical-usables", "epoch": 1,
		"tick": 0, "suspended": false, "actors": [_actor(index)], "devices": []}
	_masks()


func _masks() -> void:
	var states := PackedFloat32Array()
	for actor: Dictionary in frame.actors:
		for part: Dictionary in actor.parts:
			Coupling.append_input(states, int(part.body_id), part.position, float(part.rotation),
				Vector2(part.half_extents) * 2.0, Vector2.ZERO, 0.0, 1.0, 1)
	world.prepare_rigid_body_coupling(states, false)


func _request(operation: String = "use", owner: int = 0) -> Dictionary:
	sequence += 1
	var actor: Dictionary = Runtime.actor_row(frame, owner)
	var result: Dictionary = {"version": 1, "run_id": frame.run_id, "epoch": frame.epoch,
		"sequence": sequence, "request_id": "request-%d" % sequence,
		"operation": operation, "power": 1.0}
	for key: String in ["actor_id", "generation", "equipment_epoch", "instance_id", "usable_index", "body_id"]:
		result[key] = actor[key]
	return result


func _step(requests: Array = [], delta: float = 1.0 / 60.0) -> Dictionary:
	frame.tick = int(frame.tick) + 1
	return runtime.step(delta, world, frame, requests)


func _emit(point: Vector2i, material: int) -> void:
	world.emit_disc(point.x, point.y, 0, material)


func _ports(output: bool) -> Array[Vector2i]:
	var actor: Dictionary = frame.actors[0]
	var x: float = ceilf(Vector2(actor.half_extents).x + 2.0) * (1.0 if output else -1.0)
	return [Vector2i((Vector2(actor.position) + Vector2(x, -1).rotated(float(actor.rotation))).round()),
		Vector2i((Vector2(actor.position) + Vector2(x, 1).rotated(float(actor.rotation))).round())]


func _device_frame() -> void:
	var actor: Dictionary = frame.actors[0]
	actor.state = "fixed"
	var device: Dictionary = {}
	for key: String in ["instance_id", "actor_id", "equipment_epoch", "usable_index", "body_id", "position", "rotation", "half_extents", "state"]:
		device[key] = actor[key]
	frame.devices = [device]


func _all_catalogue_native() -> void:
	_check(Catalog.count() == 32, "stable U01-U32 catalogue size")
	for index: int in range(12):
		_reset(index)
		if index in [6, 7, 8, 9, 10]:
			var material: int = 2 if index == 8 else (3 if index == 9 else (35 if index == 10 else 13))
			for y: int in range(96, 105):
				for x: int in range(108, 154):
					_emit(Vector2i(x, y), material)
		var result: Dictionary = _step([_request()])
		_check(result.receipts.size() == 1 and bool(result.receipts[0].accepted),
			"U%02d tool failed at physical muzzle: %s" % [index + 1, str(result.receipts)])
		_check(int(result.write_count_last) > 0, "tool reported success without a native cell change")
		_check(world.rigid_body_id_at(100, 100) == 1 and world.material_at(100, 100) == 1,
			"tool edited its owning native body mask")
	for index: int in range(12, 22):
		_reset(index)
		var result: Dictionary = _step([_request()])
		_check(result.receipts.size() == 1 and bool(result.receipts[0].accepted) and result.projectiles.size() == 1,
			"U%02d projectile did not launch" % (index + 1))
		if result.projectiles.size() == 1:
			_check(result.projectiles[0].position == frame.actors[0].muzzle,
				"projectile retained sampled centre/+3 origin")
	for index: int in range(22, 32):
		_reset(index)
		frame.actors[0].rotation = PI / 2.0
		frame.actors[0].parts[0].rotation = PI / 2.0
		_device_frame()
		_masks()
		var definition: Dictionary = Catalog.entry(index)
		var inputs: Array[Vector2i] = _ports(false)
		var outputs: Array[Vector2i] = _ports(true)
		var input_values: Array = []
		for ingredient: Array in definition.get("inputs", []):
			for _slot: int in range(int(ingredient[1])):
				input_values.append(int(ingredient[0]))
		for slot: int in range(input_values.size()):
			_emit(inputs[slot], int(input_values[slot]))
		var catalyst: Array = definition.get("catalyst_any", [])
		if not catalyst.is_empty():
			_emit(Vector2i(104, 101), int(catalyst[0]))
		if index == 31:
			_emit(Vector2i(104, 101), 6)
		var result: Dictionary = _step([_request("deploy")])
		_check(result.receipts.size() == 1 and bool(result.receipts[0].accepted) and result.objects.size() == 1,
			"U%02d real processor admission failed: %s" % [index + 1, str(result.receipts)])
		if result.objects.size() != 1:
			continue
		var produced: Array = []
		for product: Array in definition.outputs:
			for _slot: int in range(int(product[1])):
				produced.append(int(product[0]))
		# Block the final output, not only the first output. All intake remains.
		_emit(outputs[produced.size() - 1], 13)
		result = _step()
		_check(result.objects[0].status == "blocked-output", "processor did not publish last-output jam")
		for slot: int in range(input_values.size()):
			_check(world.material_at(inputs[slot].x, inputs[slot].y) == int(input_values[slot]),
				"blocked processor consumed intake U%02d" % (index + 1))
		_emit(outputs[produced.size() - 1], 0)
		result = _step()
		_check(result.objects[0].status == "processed" and int(result.objects[0].cycles) == 1,
			"U%02d recipe failed at rotated native ports: %s" % [index + 1, str(result.objects[0])])
		for slot: int in range(produced.size()):
			_check(world.material_at(outputs[slot].x, outputs[slot].y) == int(produced[slot]),
				"processor output differs from authored U%02d recipe" % (index + 1))
		_check(int(result.objects[0].stock) == int(definition.stock) - 1, "processor stock accounting drift")


func _identity_resources_and_copying() -> void:
	_reset(12)
	var command: Dictionary = _request()
	var first: Dictionary = _step([command])
	_check(bool(first.receipts[0].accepted), "initial identity launch")
	var saved: Dictionary = first.duplicate(true)
	var duplicate: Dictionary = _step([command])
	_check(duplicate.receipts[0].reason == "sequence" and duplicate.projectiles.size() == 1,
		"duplicate command created a projectile")
	var cooldown: Dictionary = _step([_request()])
	_check(cooldown.receipts[0].reason == "cooldown" and bool(cooldown.receipts[0].consumed),
		"cooldown refusal absent or retryable")
	frame.actors[0].equipment_epoch += 1
	frame.actors[0].usable_index = 16
	var switched: Dictionary = _step([_request()])
	_check(switched.receipts[0].reason == "cooldown" and float(switched.actors[0].charge) < 100.0,
		"selection reset shared actor cooldown or charge")
	_check(first == saved, "published nested state aliases mutable owner data")
	first.projectiles[0].position = Vector2(-500, -500)
	_check(runtime.snapshot().projectiles[0].position != Vector2(-500, -500), "consumer edited authoritative projectile")
	var fresh_command: Dictionary = _request()
	for change: Dictionary in [{"epoch": 0}, {"generation": -1}, {"equipment_epoch": 0},
		{"body_id": 64}, {"actor_id": 7}, {"instance_id": "another-instance"},
		{"power": NAN}, {"power": INF}, {"power": true}, {"sequence": true}]:
		var invalid: Dictionary = fresh_command.duplicate(true)
		invalid.merge(change, true)
		var count: int = runtime.snapshot().projectiles.size()
		var result: Dictionary = _step([invalid])
		_check(not result.receipts[0].accepted and result.projectiles.size() <= count,
			"invalid equipment identity/value became an effect: " + str(change))
	frame.actors[0].generation += 1
	frame.actors[0].active = false
	var cancelled: Dictionary = _step([_request()])
	_check(cancelled.receipts[0].reason == "lease_or_cancel", "cancelled input became an effect")
	frame.actors[0].active = true
	frame.actors[0].lease_deadline = int(frame.tick) + 1
	var expired: Dictionary = _step([_request()])
	_check(expired.receipts[0].reason == "lease_or_cancel", "deadline boundary admitted expired input")
	var old_frame: Dictionary = frame.duplicate(true)
	frame.epoch = 2
	frame.tick = 1
	frame.actors[0].lease_deadline = 100000
	var reset_result: Dictionary = _step()
	_check(reset_result.projectiles.is_empty() and reset_result.objects.is_empty(), "new epoch retained committed state")
	runtime.step(1.0 / 60.0, world, old_frame, [fresh_command])
	_check(runtime.snapshot().projectiles.is_empty() and runtime.snapshot().epoch == 2, "old epoch resurrected projectiles")
	# Spend charge through successful launches, with real cooldown time between.
	_reset(16)
	var resource_refused: bool = false
	for _attempt: int in range(45):
		var result: Dictionary = _step([_request()])
		if result.receipts[0].reason == "no-charge":
			resource_refused = true
			break
		for _wait: int in range(6):
			_step([], 1.0 / 15.0)
	_check(resource_refused, "charge exhaustion never reached explicit native-owner refusal")


func _body_masks_and_occlusion() -> void:
	_reset(12)
	var enemy: Dictionary = _actor(12, 1, Vector2(120.5, 90.5), 2)
	enemy.parts.append({"body_id": 3, "position": Vector2(120.5, 110.5), "rotation": 0.0,
		"half_extents": Vector2(2, 2)})
	frame.actors.append(enemy)
	_masks()
	var result: Dictionary = _step([_request()])
	var hits: int = 0
	for _tick: int in range(10):
		result = _step()
		hits += result.hits_last.size()
	_check(hits == 0 and result.projectiles.size() == 1,
		"empty gap between articulated enemy parts used an assembly AABB hit")
	_reset(12)
	frame.actors.append(_actor(12, 1, Vector2(124.5, 100.5), 2))
	_masks()
	_emit(Vector2i(116, 100), 1)
	_step([_request()])
	hits = 0
	for _tick: int in range(10):
		result = _step()
		hits += result.hits_last.size()
	_check(hits == 0 and result.projectiles.is_empty(), "projectile hit actor behind nearer native Wall")
	_reset(12)
	frame.actors.append(_actor(12, 1, Vector2(124.5, 100.5), 2))
	_masks()
	_step([_request()])
	var actual_hit: Dictionary = {}
	for _tick: int in range(10):
		result = _step()
		if not result.hits_last.is_empty():
			actual_hit = result.hits_last[0]
	_check(actual_hit.get("target") == 1 and actual_hit.get("target_body_id") == 2,
		"native physical contact lost part/actor ownership")
	_reset(0)
	frame.actors[0].muzzle = Vector2(112.5, 100.5)
	frame.actors.append(_actor(12, 1, Vector2(106.5, 100.5), 2))
	_masks()
	result = _step([_request()])
	_check(result.receipts[0].reason == "source_blocked" and result.write_count_last == 0,
		"source-to-muzzle path tunneled through a foreign physical part")
	_reset(0)
	# The native compositor can name the host body for a pixel also occupied by
	# a small held body. That alias is allowed only inside the held footprint.
	frame.actors[0].body_id = 2
	frame.actors[0].parts = [
		{"body_id": 1, "position": Vector2(99.5, 100.5), "rotation": 0.0, "half_extents": Vector2(2, 2)},
		{"body_id": 2, "position": Vector2(100.5, 100.5), "rotation": 0.0, "half_extents": Vector2(2, 2)}]
	_masks()
	_check(world.rigid_body_id_at(100, 100) == 1, "source-alias fixture did not name overlapping own host")
	result = _step([_request()])
	_check(result.receipts[0].accepted and result.write_count_last > 0,
		"valid held-source overlap was refused solely by native single-part mask precedence")
	_reset(0)
	frame.actors[0].body_id = 2
	frame.actors[0].muzzle = Vector2(112.5, 100.5)
	frame.actors[0].parts = [
		{"body_id": 1, "position": Vector2(103.5, 100.5), "rotation": 0.0, "half_extents": Vector2(4, 2)},
		{"body_id": 2, "position": Vector2(100.5, 100.5), "rotation": 0.0, "half_extents": Vector2(2, 2)}]
	_masks()
	result = _step([_request()])
	_check(result.receipts[0].reason == "source_blocked" and result.write_count_last == 0,
		"contiguous own chassis outside held footprint was wrongly exempted")
	_reset(0)
	frame.actors[0].muzzle = Vector2(112.5, 100.5)
	frame.actors[0].parts.append({"body_id": 2, "position": Vector2(108.5, 100.5),
		"rotation": 0.0, "half_extents": Vector2(2, 2)})
	_masks()
	result = _step([_request()])
	_check(result.receipts[0].reason == "source_blocked" and result.write_count_last == 0,
		"own-part reentry after free muzzle-prefix exit was exempted")


func _payload_lifecycle() -> void:
	for index: int in [13, 14, 15, 16, 17, 18, 19, 20, 21]:
		_reset(index)
		if index != 16:
			for y: int in range(80, 142):
				for x: int in range(128, 132):
					_emit(Vector2i(x, y), 13)
		_step([_request()])
		var observed: Dictionary = {}
		var changed: int = 0
		for _tick: int in range(125):
			var result: Dictionary = _step()
			changed += int(result.write_count_last)
			for projectile: Dictionary in result.projectiles:
				observed[str(projectile.state)] = true
				if index == 13 and int(projectile.penetrations) < 3:
					observed["penetrated"] = true
				if index == 14 and Vector2(projectile.velocity).x < 0.0:
					observed["bounced"] = true
				if index == 21 and str(projectile.state) == "armed":
					_emit(Vector2i(Vector2(projectile.position).floor()) + Vector2i(-1, 0), 3)
			for effect: Dictionary in result.effects:
				observed[str(effect.kind)] = true
		if index == 13:
			_check(observed.has("penetrated") and changed >= 3, "borer did not perform bounded penetration")
		elif index == 14:
			_check(observed.has("bounced"), "ricochet did not react to native terrain")
		elif index == 15:
			_check(observed.has("stuck") and observed.has("burst") and changed > 0, "sticky contact/fuse/excavation incomplete")
		elif index == 16:
			_check(observed.has("airburst"), "timer payload did not split into bounded children")
		elif index == 18:
			_check(observed.has("primed") and observed.has("ignite") and changed > 0, "staged Oil/Fire lifecycle incomplete")
		elif index == 21:
			_check(observed.has("armed") and observed.has("wet-trigger"), "situational Water activation incomplete")
		else:
			_check(changed > 0, "material payload U%02d did not release native material" % (index + 1))
	_reset(16)
	_step([_request()])
	frame.actors[0].generation += 1
	frame.actors[0].active = false
	var committed_age: float = 0.0
	for _tick: int in range(10):
		var result: Dictionary = _step()
		committed_age = float(result.projectiles[0].age)
	_check(committed_age > 0.1, "cancellation deleted or stopped an already committed payload")
	frame.suspended = true
	var frozen: Dictionary = _step()
	for _tick: int in range(10):
		_step()
	_check(runtime.snapshot().projectiles == frozen.projectiles, "paused simulation advanced payloads")


func _processor_pickup_history() -> void:
	_reset(22)
	_device_frame()
	var inputs: Array[Vector2i] = _ports(false)
	_emit(inputs[0], 13)
	_step([_request("deploy")])
	var result: Dictionary = _step()
	_check(result.objects.size() == 1 and int(result.objects[0].stock) == 15, "initial processor stock")
	var old_frame: Dictionary = frame.duplicate(true)
	frame.actors[0].state = "held"
	frame.actors[0].equipment_epoch += 1
	frame.devices = []
	result = _step()
	_check(result.objects.is_empty(), "pickup left a distant logical processor")
	for _tick: int in range(7):
		_step([], 1.0 / 15.0)
	frame.actors[0].equipment_epoch += 1
	_device_frame()
	result = _step([_request("deploy")])
	_check(result.receipts[0].accepted and result.objects.size() == 1 and result.objects[0].stock == 15,
		"physical pickup/redeploy refilled processor stock")
	var age_before: float = float(result.objects[0].age)
	runtime.step(1.0 / 60.0, world, old_frame, [])
	_check(float(runtime.snapshot().objects[0].age) == age_before and runtime.snapshot().objects[0].stock == 15,
		"stale copied deployment resurrected old stock/pose")
	var remote: Dictionary = _step([_request("alternate")])
	_check(not remote.receipts[0].accepted and remote.objects.size() == 1,
		"alternate remotely retrieved a real deployed processor")


func _processor_budget_atomicity() -> void:
	_reset(24)
	_device_frame()
	var inputs: Array[Vector2i] = _ports(false)
	var outputs: Array[Vector2i] = _ports(true)
	for input: Vector2i in inputs:
		_emit(input, 24)
	var result: Dictionary = _step([_request("deploy")])
	_check(result.objects.size() == 1, "budget fixture real processor deployed")
	if result.objects.is_empty():
		return
	# Begin the real recipe with only eight native-owner reads remaining. The
	# complete transaction needs its input/output checks and every write's mask,
	# before-value and post-write verification. Insufficient budget cannot consume
	# intake before discovering that the final output no longer fits.
	var engine = runtime._engine
	engine.active_world = world
	engine._reset_budget()
	engine.read_count_last = 2040
	var status: String = engine._object_cycle(result.objects[0], Catalog.entry(24), world)
	_check(status == "capacity" and engine.write_count_last == 0, "processor partially committed near read ceiling")
	for input: Vector2i in inputs:
		_check(world.material_at(input.x, input.y) == 24, "budget-refused processor consumed Brine intake")
	for output: Vector2i in outputs:
		_check(world.material_at(output.x, output.y) == 0, "budget-refused processor emitted partial output")
	engine._reset_budget()
	engine.read_count_last = 2032
	status = engine._object_cycle(result.objects[0], Catalog.entry(24), world)
	_check(status == "processed" and engine.write_count_last == 4 and engine.read_count_last == 2048,
		"complete recipe did not fit exact native mask/read/write budget")
	engine.active_world = null


func _committed_alternate_admission() -> void:
	for index: int in [15, 16, 18]:
		_reset(index)
		if index != 16:
			for y: int in range(96, 112):
				_emit(Vector2i(128, y), 13)
		_step([_request()])
		var ready: bool = index == 16
		for _tick: int in range(20):
			var observed: Dictionary = _step()
			if index == 16:
				break
			if not observed.projectiles.is_empty() and str(observed.projectiles[0].state) in ["stuck", "primed"]:
				ready = true
				break
		_check(ready, "early-activation native payload did not reach eligible state")
		var old_id: int = int(runtime.snapshot().projectiles[0].entity_id)
		# Force only the resource precondition, independently from the physical
		# input producer. Launch timing already left a real positive cooldown.
		runtime._engine._actors[0].charge = 0.0
		_check(float(runtime.snapshot().actors[0].cooldown) > 0.0, "early-activation fixture missed launch cooldown")
		_emit(Vector2i(Vector2(frame.actors[0].muzzle).floor()), 1)
		var command: Dictionary = _request("alternate")
		command.power = 0.0
		var result: Dictionary = _step([command])
		_check(result.receipts[0].accepted and result.receipts[0].reason == "activated",
			"committed alternate incorrectly required launch charge/cooldown/power/clear muzzle")
		var survived: bool = false
		for projectile: Dictionary in result.projectiles:
			survived = survived or int(projectile.entity_id) == old_id
		_check(not survived, "early activation did not consume the original owned payload")


func _run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld"):
		push_error("USABLE002_NATIVE requires source-matched CyberNativeCellWorld")
		quit(1)
		return
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	_all_catalogue_native()
	_identity_resources_and_copying()
	_body_masks_and_occlusion()
	_payload_lifecycle()
	_processor_pickup_history()
	_processor_budget_atomicity()
	_committed_alternate_admission()
	print("USABLE002_NATIVE checks=%d failures=%d native=executed catalogue=32" % [checks, failures])
	quit(1 if failures > 0 else 0)
