class_name CyberInteractionPolicyProbe
extends RefCounted

# Shared desktop/Web acceptance, with assertions expressed as release-safe data.
static func fresh(fallback: bool, workers: int = 1, host: Node = null):
	if not fallback:
		var native = ClassDB.instantiate(&"CyberNativeCellWorld")
		# The default pool must start before diagnostic_reset joins it during
		# replacement; yielding only after reset is too late on threaded Web.
		if host != null:
			await host.get_tree().process_frame
		if not native.diagnostic_reset({"workers":workers}):
			return null
		if host != null:
			await host.get_tree().process_frame
		return native
	var world: CyberCellWorld = CyberCellWorld.new()
	world.cells.fill(0)
	world.updated_at.fill(0)
	world.quiet_ticks.fill(0)
	world.active_blocks.fill(0)
	world.next_active_blocks.fill(0)
	world.block_movable_counts.fill(0)
	world.tick_index = 0
	world.simulation_window_enabled = false
	return world

static func fill(world, x: int, y: int, w: int, h: int, material: int) -> void:
	CyberPhysicsCharacterisation.fill(world,x,y,w,h,material)

static func run(fallback: bool = false, workers: int = 1, host: Node = null) -> Dictionary:
	var failures: Array[String] = []
	var rows: Array = []
	for material: int in [2,13,14,19,23,25,26,27,29]:
		var world = await fresh(fallback, workers, host)
		if world == null:
			return {"ok":false,"failures":["fixture reset"]}
		fill(world,64,160,160,1,1)
		fill(world,64,100,160,60,material)
		var player: CyberSampledCharacter = CyberSampledCharacter.new()
		player.reset(Vector2(100,72))
		for tick: int in range(180):
			player.simulate(1.0/60.0,0.0 if tick < 90 else 1.0,false,world)
			world.simulation_tick()
		if player.position.y + 14 > 100.01 or not player.grounded or player.position.x < 140:
			failures.append("standing/landing/walking material %d: %s" % [material,player.position])
		player.reset(Vector2(100,112))
		player.simulate(1.0/60.0,0,false,world)
		if player.recovery_blocked or world.box_collides(player.position,player.BODY_SIZE):
			failures.append("enclosed recovery material %d" % material)
		fill(world,90,100,50,61,0)
		player.reset(Vector2(100,86))
		for tick: int in range(30):
			player.simulate(1.0/60.0,0,false,world)
		if player.position.y <= 90 or player.grounded:
			failures.append("excavation material %d" % material)
		rows.append({"material":material,"after_excavation":player.position.y})
		world = null
		if host != null:
			await host.get_tree().process_frame
	var loose = await fresh(fallback,workers,host)
	fill(loose,96,100,20,1,14)
	if loose.character_box_collides(Vector2(100,99),Vector2(8,2),2) or loose.character_box_collides(Vector2(100,87),Vector2(8,14),1):
		failures.append("loose Dust film blocks movement")
	fill(loose,104,94,1,1,1)
	if not loose.box_collides(Vector2(100,86),Vector2(8,14)):
		failures.append("interior hard cell was missed")
	fill(loose,64,64,100,100,1)
	var trapped: CyberSampledCharacter = CyberSampledCharacter.new()
	trapped.reset(Vector2(100,100))
	trapped.simulate(1.0/60.0,1,false,loose)
	if not trapped.recovery_blocked or trapped.position != Vector2(100,100):
		failures.append("bounded enclosure outcome")
	loose = null
	if host != null:
		await host.get_tree().process_frame
	# Sampled player and a moving 8x14 barrel share the copied occupancy field.
	var shared = await fresh(fallback,workers,host)
	fill(shared,80,120,80,4,14)
	var rider: CyberSampledCharacter = CyberSampledCharacter.new()
	rider.reset(Vector2(100,106))
	for step: int in range(12):
		var states: PackedFloat32Array = PackedFloat32Array()
		CyberRigidBodyCoupling.append_input(states,1,Vector2(116-step,113),0,Vector2(8,14),Vector2(-60,0),0,1,step+1)
		shared.prepare_rigid_body_coupling(states,false)
		rider.simulate(1.0/60.0,0,false,shared)
		if rider.recovery_blocked or shared.box_collides(rider.position,rider.BODY_SIZE):
			failures.append("player/moving barrel mask overlap")
	shared = null
	if host != null:
		await host.get_tree().process_frame
	var mercury = await fresh(fallback,workers,host)
	fill(mercury,63,64,1,65,1)
	fill(mercury,96,64,1,65,1)
	fill(mercury,63,128,34,1,1)
	fill(mercury,64,96,32,32,2)
	fill(mercury,64,80,32,16,33)
	var initial: Dictionary = CyberPhysicsCharacterisation.sample(mercury,Vector2i(63,64),Vector2i(34,65),false)
	var trace: Array = []
	for tick: int in range(1,961):
		mercury.simulation_tick()
		if tick == 29 and mercury.material_at(80,96) != 2:
			failures.append("Mercury moved before eligibility")
		if tick % 30 == 0:
			var front: int = 0
			for y: int in range(96,128):
				for x: int in range(64,96):
					if mercury.material_at(x,y) == 33:
						front = maxi(front,y-95)
			trace.append(front)
			if front != tick/30:
				failures.append("Mercury lane/progress at tick %d: %d" % [tick,front])
	var final: Dictionary = CyberPhysicsCharacterisation.sample(mercury,Vector2i(63,64),Vector2i(34,65),false)
	if initial.counts != final.counts:
		failures.append("closed Mercury/powder count conservation")
	mercury = null
	if host != null:
		await host.get_tree().process_frame
	var pair_rows: Array = []
	for pair: Vector2i in [Vector2i(2,14),Vector2i(14,2),Vector2i(3,2),Vector2i(2,3),Vector2i(3,14),Vector2i(14,3),Vector2i(2,33)]:
		var world = await fresh(fallback,workers,host)
		fill(world,59,48,1,33,1)
		fill(world,76,48,1,33,1)
		fill(world,59,80,18,1,1)
		fill(world,60,56,16,8,pair.x)
		fill(world,60,64,16,16,pair.y)
		var before: Dictionary = CyberPhysicsCharacterisation.sample(world,Vector2i(59,48),Vector2i(18,33),false)
		for tick: int in range(120):
			world.simulation_tick()
		var after: Dictionary = CyberPhysicsCharacterisation.sample(world,Vector2i(59,48),Vector2i(18,33),false)
		if not fallback and before.water_mass != after.water_mass:
			failures.append("Water mass in pair %s" % pair)
		for material: int in [2,14,33]:
			if before.counts[material] != after.counts[material]:
				failures.append("pair conservation %s material %d" % [pair,material])
		if CyberInteractionPolicy.supports_load(pair.x) and CyberInteractionPolicy.supports_load(pair.y) and world.material_at(68,63) != pair.x:
			failures.append("resting powder pair reordered %s" % pair)
		pair_rows.append({"top":pair.x,"bottom":pair.y,"hash":after.hash,"water_mass":after.water_mass})
		world = null
		if host != null:
			await host.get_tree().process_frame
	if not fallback:
		var reset = await fresh(false,workers,host)
		if not reset.diagnostic_reset({"workers":workers,"support_cells":1,"mercury_period":1}):
			failures.append("policy override construction")
		if host != null:
			await host.get_tree().process_frame
		fill(reset,120,80,1,1,14)
		if not reset.character_box_collides(Vector2(120,80),Vector2.ONE,1):
			failures.append("support override not applied")
		if reset.diagnostic_reset({"support_cells":0}) or reset.diagnostic_reset({"mercury_period":0}) or reset.material_at(120,80) != 14:
			failures.append("invalid override replaced authority")
		# The fallback declaration returns void; verify reset through observable
		# native support and exchange outcomes instead of a mixed return type.
		reset.reset_demo_world()
		if host != null:
			await host.get_tree().process_frame
		reset.paint_disc(120,80,0,14)
		if reset.character_box_collides(Vector2(120,80),Vector2.ONE,1):
			failures.append("demo reset retained support override")
		for y: int in range(79,83):
			for x: int in range(79,82):
				reset.paint_disc(x,y,0,1)
		reset.paint_disc(80,80,0,33)
		reset.paint_disc(80,81,0,2)
		for tick: int in range(29):
			reset.simulation_tick()
		if reset.material_at(80,80) != 33:
			failures.append("demo reset retained permeability override")
		reset.simulation_tick()
		if reset.material_at(80,81) != 33:
			failures.append("demo reset lost default permeability wake")
		reset = null
		if host != null:
			await host.get_tree().process_frame
	return {"ok":failures.is_empty(),"failures":failures,"player":rows,"pairs":pair_rows,"mercury_front":trace,"cell_hash":final.hash,"fallback":fallback,"workers":workers,"policy_version":1}
