extends "res://tests/test_player_vehicle_controls.gd"

const Runtime = preload("res://scripts/player_playground_runtime.gd")
const UsableCatalog = preload("res://scripts/usable_catalog.gd")
var measured: Dictionary={}

func hop_height(model: StringName, multiplier: float) -> float:
	if not setup(model): return 0.0
	rig._profile.player_jump_multiplier=multiplier
	if model==&"trialsbike":
		for tick: int in range(30): step({"primary":true})
	var initial: float=rig.observation().position.y
	var highest: float=initial
	step({} if model==&"trialsbike" else {"primary":true})
	for tick: int in range(100):
		var sample: Dictionary=step({})
		highest=minf(highest,sample.position.y)
	var height: float=initial-highest
	await finish()
	return height

func run() -> void:
	owner=Node2D.new();root.add_child(owner)
	for model: StringName in [&"stuntbuggy",&"trialsbike"]:
		var old: float=await hop_height(model,1.0)
		var tuned: float=await hop_height(model,sqrt(2.0))
		measured[str(model)]={"baseline_height":old,"tuned_height":tuned,"ratio":tuned/old}
		expect(old>2.0 and tuned/old>1.7 and tuned/old<2.35,"actual flat-floor hop height roughly doubles: "+str(model)+str(measured[str(model)]))
		if setup(model,false):
			var start_angle: float=rig.observation().rotation
			for tick: int in range(12): step({"trim":1.0})
			measured[str(model)].lean_angle=rig.observation().rotation-start_angle
			expect(absf(rig.observation().rotation-start_angle)>0.65,"strong lean produces actual rapid rotation "+str(model))
			var rear: int=2
			var front: int=4
			expect(str(rig._part_defs[rear].id)=="wheel_-1" and str(rig._part_defs[front].id)=="wheel_1","pivot names the actual rear wheel")
			# The controlled chassis velocity includes the tangential term around
			# the actual rear axle rather than pure centre-of-mass torque.
			expect(rig._last_impulse.length()>0.1,"rear-axle steering produces a physical linear impulse as well as torque")
		await finish()
	var fall: Array[float]=[]
	for drift: bool in [false,true]:
		setup(&"arcadelander",false);rig._gravity=32.0
		if drift: step({"auxiliary":true})
		for tick: int in range(20): step({})
		fall.append(rig.observation().velocity.y)
		expect(is_equal_approx(rig.bodies()[0].gravity_scale*980.0,32.0 if drift else 96.0),"actual Rapier gravity matches damped/drift mode")
		await finish()
	measured.lander_fall=fall
	expect(fall[0]>fall[1]*1.8,"damped mode falls faster than drift in actual physics")
	setup(&"jetbarrel",false)
	expect(is_equal_approx(rig.bodies()[0].inertia,2.4*225.0/12.0*0.85),"barrel has 15 percent lower actual rotational inertia")
	for tick: int in range(180): step({"primary":true})
	measured.barrel_speed=Vector2(rig.observation().velocity).length()
	expect(measured.barrel_speed>160.0 and measured.barrel_speed<190.0,"actual barrel speed uses higher finite cap")
	await finish()
	var runtime=Runtime.new();owner.add_child(runtime)
	for player: StringName in [&"dryswarm",&"liquidswarm"]:
		expect(runtime.configure(player,&"legacy"),"material idle/usable fixture starts")
		var world: Object=runtime._world
		var count: Dictionary=world.diagnostic_snapshot(Vector2i(128,128),Vector2i(512,256))
		for tick: int in range(12):
			expect(runtime.submit_action({"move":Vector2.ZERO}),"neutral idle pattern requires issued lease: "+runtime.last_error)
			runtime.step()
		var field: Dictionary=runtime.observation().field
		expect(field.radius==60 and field.native_calls==5 and field.idle_pattern and field.moved_cells>0,"larger native field and active idle pattern are actually exercised")
		var after: Dictionary=world.diagnostic_snapshot(Vector2i(128,128),Vector2i(512,256))
		expect(after.counts[2]==count.counts[2] and after.water_mass==count.water_mass,"idle fields preserve native Sand/Water quantity")
		expect(runtime.select_usable(UsableCatalog.index_for(&"impact_slug")),"quick usable tap selection admits")
		runtime.submit_action({"aim":Vector2.RIGHT});runtime.step()
		runtime.submit_action({"aim":Vector2.RIGHT,"tool":true})
		runtime.submit_action({"aim":Vector2.RIGHT,"tool":false})
		runtime.step()
		expect(runtime.usable_snapshot().projectiles.size()==1,"press/release before a tick still launches exactly one material projectile")
		for id: StringName in [&"sand_scatter",&"impact_slug",&"stone_grinder"]:
			expect(runtime.configure(player,&"legacy"),"fresh open usable staging resets previous devices/cooldown")
			expect(runtime.select_usable(UsableCatalog.index_for(id)),"material player selects usable category "+str(id))
			runtime.submit_action({"aim":Vector2.RIGHT});runtime.step()
			runtime.submit_action({"aim":Vector2.RIGHT,"tool":true});runtime.step()
			var tools: Dictionary=runtime.usable_snapshot()
			expect(tools.actors[0].last_result in ["applied","launched","deployed"],"material player actually exercises "+str(id)+str(tools.actors[0]))
			runtime.set_paused(true)
			var paused_hash: String=runtime._world.get_physical_state_hash()
			expect(not runtime.submit_action({"tool":true,"aim":Vector2.RIGHT}) and runtime._world.get_physical_state_hash()==paused_hash,"paused usable command cannot mutate native material")
			runtime.set_paused(false)
		expect(runtime.configure(player),"boundary field fixture starts")
		runtime._centre=Vector2(8,12)
		runtime.submit_action({"move":Vector2.ZERO});runtime.step()
		expect(not runtime.failed and runtime.observation().field.native_calls==5,"wide field centres clamp safely at native edges")
	for player: StringName in [&"stuntbuggy",&"trialsbike",&"acrobat",&"arcadelander",&"jetbarrel"]:
		expect(runtime.configure(player),"mechanical usable fixture starts")
		expect(runtime.select_usable(UsableCatalog.index_for(&"sand_scatter")),"mechanical player selects actual loadout")
		for tick: int in range(12):
			runtime.submit_action({"aim":Vector2.RIGHT,"tool":tick>2});runtime.step()
		var equipment: Dictionary=runtime.observation().equipment
		expect(equipment.usable_index==UsableCatalog.index_for(&"sand_scatter") and equipment.accepted_uses>0,"actual physical mounted tool fires for "+str(player)+str(equipment))
	runtime.close();runtime.free();owner.free();await process_frame
	print("PLAYER_TUNING_METRICS ",JSON.stringify(measured))
	print("PLAYER_TUNING: %d assertions, %d failures"%[assertions,failures])
	quit(0 if failures==0 else 1)
