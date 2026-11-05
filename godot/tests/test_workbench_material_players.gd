extends SceneTree

const Players = preload("res://scripts/workbench_material_players.gd")
var checks: int = 0
var failures: Array[String] = []

class Probe extends RefCounted:
	var calls: Array = []
	func apply_player_material_field(center: Vector2i, direction: Vector2, material: int, mode: int, phase: int) -> Dictionary:
		calls.append({"center":center,"direction":direction,"material":material,"mode":mode,"phase":phase})
		return {"accepted":true,"observed_cells":256,"centroid":Vector2(center)+Vector2(100,0),"quantity":256}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why); push_error("WORKBENCH_MATERIAL_PLAYERS "+why)
func definition(id: int, model: String, position := Vector2(200,200)) -> Dictionary:
	return {"instance_id":id,"model":model,"position":position,"material_id":2 if model == "dryswarm" else 3,"canvas_extent":Vector2i(1024,1024)}
func command(players, tick: int, action: Dictionary, sequence: int = 0) -> Dictionary:
	return Players.make_command(players.publish(tick).actors[0],sequence,action)

func run() -> void:
	var players := Players.new()
	check(players.configure([definition(1,"dryswarm")],Vector2i(1024,1024),"test",1).is_empty(),"configure copied controller")
	var probe := Probe.new()
	var first := command(players,0,{"move":Vector2.RIGHT,"primary":true})
	check(players.submit(first,0).accepted,"issued observation admitted")
	check(not players.submit(first,0).accepted,"duplicate sequence refused")
	var release := first.duplicate(true); release.sequence=1; release.action.primary=false
	check(players.submit(release,0).accepted,"quick release admitted")
	check(players.advance(probe,0).accepted and probe.calls[0].mode == 1,"quick surge edge survives one native step")
	check(players.publish(1).actors[0].position == Vector2(204,200),"centre follows actual centroid at most four cells")
	players.advance(probe,1)
	check(probe.calls[1].mode == 0,"ordered release applied on following tick")
	var previous_calls := probe.calls.size()
	players.cancel(); players.advance(probe,2)
	check(probe.calls.size() == previous_calls,"cancellation retires field")
	first.sequence=2
	check(not players.submit(first,2).accepted,"retired generation cannot authorize field")
	var ordinary := Players.make_command(players.publish(2).actors[0],2,{"move":Vector2.ZERO})
	check(not players.submit(ordinary,2,false).accepted,"paused owner refuses input")
	check(players.submit(ordinary,2).accepted,"neutral admitted field retains cohesion")
	players.advance(probe,9)
	check(probe.calls.size() == previous_calls,"six-tick lease expires")
	for action: Dictionary in [{"move":Vector2(NAN,0)},{"move":Vector2.ONE},{"move":Vector2.ZERO,"primary":1},{"move":Vector2.ZERO,"aim":Vector2(INF,0)},{"move":Vector2.ZERO,"effort":2.0},{"move":Vector2.ZERO,"unknown":true}]:
		check(not players.submit(command(players,10,action,100),10).accepted,"invalid action refused")
	check(players.reset_player(1,Vector2(300,300)),"explicit field reset admitted")
	check(players.publish(10).actors[0].position == Vector2(300,300),"reset changes centre, not parcels")
	check(not players.reset_player(1,Vector2(-1,0)),"invalid reset refused")
	var replacement := Players.new()
	check(replacement.configure([definition(1,"dryswarm")],Vector2i(1024,1024),"new",2,players.export_state()).is_empty(),"retained control values prepared")
	check(replacement.publish(0).actors[0].position == Vector2(300,300),"peer reconstruction keeps live centre")
	check(not replacement.submit(ordinary,0).accepted,"new owner refuses old authority")
	check(not players.configure([definition(1,"dryswarm"),definition(1,"liquidswarm")],Vector2i(1024,1024),"bad",1).is_empty(),"duplicate stable instance rejected")
	# Actual native API supplies movement, state preservation and occupancy.
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world != null and world.diagnostic_reset({"workers":1}),"real native World")
	players = Players.new()
	check(players.configure([definition(1,"dryswarm"),definition(2,"liquidswarm",Vector2(350,200))],Vector2i(1024,1024),"native",1).is_empty(),"two material players share one World")
	var seed: Dictionary = players.seed_pending(world)
	check(seed.players.size() == 2 and seed.players[0].inserted == 256 and seed.players[1].inserted == 256,"explicit spawn seeds real cells once")
	check(players.seed_pending(world).players.is_empty(),"ordinary repetition cannot refill")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(128,128),Vector2i(320,192))
	var water: Dictionary = world.water_experiment_observation(Vector2i(128,128),Vector2i(320,192))
	for view: Dictionary in players.publish(0).actors:
		check(players.submit(Players.make_command(view,0,{"move":Vector2.RIGHT,"primary":true}),0).accepted,"independent controller admitted")
	check(players.advance(world,0).accepted,"fields apply before ordinary simulation")
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(128,128),Vector2i(320,192))
	var water_after: Dictionary = world.water_experiment_observation(Vector2i(128,128),Vector2i(320,192))
	check(before.counts[2] == after.counts[2] and after.counts[2] == 256,"Sand quantity exact while steering")
	check(water.water_integer == water_after.water_integer and water.water_integer == 256*255,"Water integer quantity exact while steering")
	check(before.hash != after.hash,"authoritative native cells moved")
	var no_refill := Players.new()
	check(no_refill.configure([definition(2,"liquidswarm",Vector2(350,200))],Vector2i(1024,1024),"retained",2,players.export_state()).is_empty(),"material retained across graph")
	check(no_refill.seed_pending(world).players.is_empty(),"retained graph does not reseed")
	players.cancel(); check(world.simulation_tick(),"ordinary native tick remains sole simulation")
	print("WORKBENCH_MATERIAL_PLAYERS "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
