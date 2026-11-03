extends SceneTree

const Emitter = preload("res://scripts/gcr_review_fleet_emitter.gd")
const Runtime = preload("res://scripts/player_playground_runtime.gd")
var failures: int = 0
var checks: int = 0

class FakeWorld extends RefCounted:
	var cells: Dictionary = {}
	var masks: Dictionary = {}
	var writes: Array = []
	var failed: bool = false
	var reject_writes: bool = false
	func material_at(x: int,y: int) -> int: return int(cells.get(Vector2i(x,y),0))
	func rigid_body_id_at(x: int,y: int) -> int: return int(masks.get(Vector2i(x,y),0))
	func has_failed() -> bool: return failed
	func emit_disc(x: int,y: int,radius: int,material: int) -> void:
		assert(radius==0)
		writes.append({"point":Vector2i(x,y),"material":material})
		if not reject_writes: cells[Vector2i(x,y)]=material

func _init() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Fleet emissions: "+reason)
func ports(q: bool=false,e: bool=false,s: bool=false) -> Dictionary:
	return {"q":q,"e":e,"s":s}
func view(tick: int=0) -> Dictionary:
	return {"epoch":1,"control_generation":0,"last_sequence":1,"tick":tick,
		"lease_remaining":6,"suspended":false}
func action() -> Dictionary:
	return {"move":Vector2.UP,"aim":Vector2.UP,"trim":0.,"effort":1.,
		"primary":true,"secondary":false,"auxiliary":false}
func world() -> FakeWorld:
	var result := FakeWorld.new()
	for y: int in range(99,102):
		for x: int in range(99,102): result.masks[Vector2i(x,y)]=1
	return result
func source(source_ports: Dictionary) -> RefCounted:
	var result := Emitter.new()
	result.capture(view(),source_ports)
	return result
func emit(emitter, target: Object, index: int=0, tick: int=0,
		pose: Transform2D=Transform2D(0,Vector2(100.5,100.5)),
		controller: Dictionary={},force_cap: float=8.,current: Dictionary={}) -> void:
	var identity: Dictionary = view(tick) if current.is_empty() else current
	emitter.step(target,index,pose,Vector2(4,3),action(),controller,force_cap,identity)
func fake_guards() -> void:
	check(Emitter.valid_ports(ports(true,true,true)),"exact independent port schema")
	for invalid: Dictionary in [{},{"q":true,"e":false},{"q":true,"e":false,"s":false,"material":8},{"q":1,"e":false,"s":false}]:
		check(not Emitter.valid_ports(invalid),"extra/missing/nonboolean port rejected")
	var test_world := world()
	var emitter = source(ports(true,true))
	emit(emitter,test_world)
	check(test_world.writes.size()==2,"Q+E remains two independent nozzles")
	check(test_world.writes[0].material==12 and test_world.writes[1].material==8,"Midge Acid/Lava mapping")
	check(test_world.writes[0].point.x<100 and test_world.writes[1].point.x>100,"mirrored outside-hull ports")
	check(emitter.snapshot().receipts.size()==2 and emitter.snapshot().totals.emitted_cells==2,"bounded receipts and exact cell sources")
	for blocked: int in [1,2,3,8,12,26,56]:
		test_world=world()
		test_world.cells[Vector2i(98,100)]=blocked
		emitter=source(ports(true))
		emit(emitter,test_world)
		check(test_world.writes.is_empty() and test_world.cells[Vector2i(98,100)]==blocked,"hard/powder/liquid cannot be crossed or overwritten "+str(blocked))
	for foreign: Vector2i in [Vector2i(98,100),Vector2i(96,100),Vector2i(100,100)]:
		test_world=world();test_world.masks[foreign]=2
		emitter=source(ports(true));emit(emitter,test_world)
		check(test_world.writes.is_empty(),"foreign body mask blocks source/path/endpoint")
	test_world=world();test_world.masks[Vector2i(97,100)]=1
	emitter=source(ports(true));emit(emitter,test_world)
	check(test_world.writes.is_empty(),"own mask cannot reappear beyond contiguous prefix")
	test_world=world();test_world.cells[Vector2i(96,100)]=26
	emitter=source(ports(true));emit(emitter,test_world)
	check(test_world.writes.is_empty() and test_world.cells[Vector2i(96,100)]==26,"occupied destination never overwritten")
	test_world=world();test_world.failed=true
	emitter=source(ports(true));emit(emitter,test_world)
	check(test_world.writes.is_empty(),"failed native owner refuses source")
	test_world=world();test_world.reject_writes=true
	emitter=source(ports(true));emit(emitter,test_world)
	check(emitter.snapshot().totals.emitted_cells==0 and emitter.snapshot().receipts[0].reason=="write_refused","counts follow actual cell write")
	for boundary: Vector2 in [Vector2(1,100),Vector2(1023,100),Vector2(100,-1),Vector2(1.e20,100)]:
		test_world=FakeWorld.new();emitter=source(ports(true,true))
		emit(emitter,test_world,0,0,Transform2D(0,boundary))
		for write: Dictionary in test_world.writes:
			check(write.point.x>=0 and write.point.x<1024 and write.point.y>=0 and write.point.y<1024,"endpoint remains inside world")
	# A diagonal corner cannot bypass either adjacent occupied cell.
	for side: Vector2i in [Vector2i(100,99),Vector2i(99,100)]:
		test_world=FakeWorld.new();test_world.masks[Vector2i(100,100)]=1;test_world.cells[side]=2
		emitter=source(ports(true));emit(emitter,test_world,0,0,Transform2D(PI/4.,Vector2(100.5,100.5)))
		check(test_world.writes.is_empty(),"corner crossing checks both touched side cells")
	# No duplicate tick, non-cadence burst, delayed backlog, or previous blockade replay.
	test_world=world();emitter=source(ports(true))
	for tick: int in [0,0,1,2,3,4,5]: emit(emitter,test_world,0,tick)
	check(test_world.writes.size()==1,"one emission per due tick without duplicate catchup")
	test_world.cells.clear();emit(emitter,test_world,0,19)
	check(test_world.writes.size()==1,"missing due ticks have no queued backlog")
	emit(emitter,test_world,0,24)
	check(test_world.writes.size()==2,"next due tick permits one source")
	test_world=world();test_world.cells[Vector2i(98,100)]=2;emitter=source(ports(true))
	emit(emitter,test_world);test_world.cells.clear();emit(emitter,test_world,0,1)
	check(test_world.writes.is_empty(),"unblocked nozzle waits until next due boundary")
	# Captured identity and live action are separate requirements.
	for field: String in ["epoch","control_generation","last_sequence"]:
		test_world=world();emitter=source(ports(true));var stale: Dictionary=view();stale[field]=99
		emit(emitter,test_world,0,0,Transform2D(0,Vector2(100.5,100.5)),{},8.,stale)
		check(test_world.writes.is_empty(),"stale "+field+" refuses copied ports")
	test_world=world();emitter=source(ports(true))
	emitter.step(test_world,0,Transform2D(0,Vector2(100.5,100.5)),Vector2(4,3),{}, {},8.,view())
	check(test_world.writes.is_empty(),"no consumed rig command means no source")
	for field: String in ["suspended","lease_remaining"]:
		test_world=world();emitter=source(ports(true));var stale: Dictionary=view();stale[field]=true if field=="suspended" else 0
		emit(emitter,test_world,0,0,Transform2D(0,Vector2(100.5,100.5)),{},8.,stale)
		check(test_world.writes.is_empty(),"pause/expired lease refuses source")
	# Fire uses actual live thrust and cap, independent from dispensers.
	var thrust: Dictionary={"thrust":1.,"side_thrust":-1.,"applied_force":Vector2(1,-1)}
	test_world=world();emitter=source(ports());emit(emitter,test_world,2,0,Transform2D(0,Vector2(100.5,100.5)),thrust)
	check(test_world.writes.is_empty(),"thruster Fire default off")
	test_world=world();emitter=source(ports(false,false,true));emitter.fire_enabled=true
	emit(emitter,test_world,2,0,Transform2D(0,Vector2(100.5,100.5)),thrust)
	check(test_world.writes.size()==3 and emitter.snapshot().receipts.size()==3,"powder/main/side within three-nozzle budget")
	check(test_world.writes[0].material==26 and test_world.writes[1].material==6 and test_world.writes[2].material==6,"Kestrel powder and real Fire")
	check(test_world.writes[2].point.x>100,"left side force exhaust exits opposite right side")
	test_world=world();emitter=source(ports());emitter.fire_enabled=true
	emit(emitter,test_world,2,0,Transform2D(0,Vector2(100.5,100.5)),thrust,0.)
	check(test_world.writes.is_empty(),"zero force ceiling suppresses Fire")
	test_world=world();emitter=source(ports());emitter.fire_enabled=true
	emit(emitter,test_world,2,0,Transform2D(0,Vector2(100.5,100.5)),{"thrust":1.,"applied_force":Vector2.ZERO})
	check(test_world.writes.is_empty(),"no applied live force suppresses Fire")
	test_world=world();emitter=source(ports());emitter.fire_enabled=true
	var descent: Dictionary=action();descent.move=Vector2.DOWN;descent.primary=false
	emitter.step(test_world,3,Transform2D(0,Vector2(100.5,100.5)),Vector2(4,3),descent,thrust,8.,view())
	check(test_world.writes.size()==1 and test_world.writes[0].point.y<100,"hoverboard descent exhaust uses top nozzle")
	test_world=world();emitter=source(ports());emitter.fire_enabled=true
	var idle: Dictionary=action();idle.move=Vector2.ZERO;idle.primary=false
	emitter.step(test_world,3,Transform2D(0,Vector2(100.5,100.5)),Vector2(4,3),idle,thrust,8.,view())
	check(test_world.writes.is_empty(),"hoverboard idle compensation emits no Fire")

func native_sources() -> void:
	var native: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	check(native.diagnostic_reset({"workers":1,"telemetry":false}),"actual native source owner")
	var emitter=source(ports(true,true))
	emit(emitter,native,5)
	var water: Dictionary=native.diagnostic_snapshot(Vector2i(90,90),Vector2i(25,25),false,false)
	check(water.counts[3]==2 and water.water_mass==2*255,"Water source initializes exact native full quantity")
	check(native.material_at(87,100)==0 and native.rigid_body_id_at(96,100)==0,"native emission creates no masks/remote pixels")
	check(native.diagnostic_reset({"workers":1,"telemetry":false}),"reset native fixture")
	check(native.diagnostic_fill_rect(Vector2i(98,100),Vector2i.ONE,2),"native grain blockade")
	emitter=source(ports(true));emit(emitter,native)
	check(native.material_at(98,100)==2 and native.material_at(96,100)==0,"actual native powder is not tunneled through")
	# Real main-thread Session/Rapier route, including expiry and ordinary actions.
	var runtime=Runtime.new();root.add_child(runtime)
	check(runtime.configure_review_fleet(0),"actual review fleet owner")
	var arena=runtime._arena
	var sequence: int=int(runtime.observation().last_sequence)
	check(not runtime.submit_review_action(action(),{"q":true}),"schema rejected before Session sequence admission")
	check(int(runtime.observation().last_sequence)==sequence,"invalid ports preserve accepted sequence")
	check(runtime.submit_review_action(action(),ports(true,true)),"leased dual ports admitted")
	var state: Dictionary=runtime.step()
	check(not state.failed and arena.snapshot().review_emissions.totals.emitted_cells==2,"actual Rapier/native owner applies dual ports")
	for _tick: int in range(12): runtime.step()
	check(arena.snapshot().review_emissions.totals.emitted_cells==2 and arena.snapshot().review_emissions.totals.requested_nozzles==2,"expired real Session lease cannot even request ports")
	check(runtime.configure_review_fleet(0),"fresh cancellation fixture")
	arena=runtime._arena
	check(runtime.submit_review_action(action(),ports(true,true)),"pending cancellable ports")
	runtime.cancel();runtime.step()
	check(arena.snapshot().review_emissions.totals.emitted_cells==0,"focus cancellation revokes pending sources")
	check(runtime.configure_review_fleet(0),"fresh pause fixture")
	arena=runtime._arena
	check(runtime.submit_review_action(action(),ports(true,true)),"ports before pause")
	runtime.set_paused(true);runtime.step();runtime.set_paused(false);runtime.step()
	check(arena.snapshot().review_emissions.totals.emitted_cells==0,"pause/resume cannot revive pending sources")
	check(runtime.configure_review_fleet(0),"fresh ordinary-command fixture")
	arena=runtime._arena
	check(runtime.submit_review_action(action(),ports(true,true)) and runtime.submit_action(action()),"new ordinary command admitted")
	runtime.step()
	check(arena.snapshot().review_emissions.totals.emitted_cells==0,"ordinary submit_action never inherits old review ports")
	check(runtime.configure_review_fleet(2),"fresh Fire owner")
	arena=runtime._arena
	check(runtime.set_review_thruster_fire(true),"live Fire toggle")
	check(runtime.submit_review_action(action(),ports()),"live thrust command")
	runtime.step()
	check(arena.snapshot().review_emissions.totals.emitted_cells==1,"actual commanded live thrust emits Fire")
	check(runtime.set_review_thruster_fire(false),"Fire toggle off")
	for _tick: int in range(6):
		runtime.submit_review_action(action(),ports());runtime.step()
	check(arena.snapshot().review_emissions.totals.emitted_cells==1,"toggle off stops Fire at next boundary")
	check(runtime.configure(&"arcadelander"),"ordinary actor owner")
	check(not runtime.set_review_thruster_fire(true) and not runtime.submit_review_action(action(),ports(true)),"review sources unavailable to ordinary actor route")
	runtime.close();runtime.queue_free()
	await process_frame

func run() -> void:
	fake_guards()
	await native_sources()
	print("GCR_FLEET_EMISSIONS ",JSON.stringify({"checks":checks,"failures":failures,"scope":"bounded review-only sources; fake guards plus native/Rapier ownership"}))
	quit(0 if failures==0 else 1)
