class_name CyberInteractionPolicyProbe
extends RefCounted

# Shared desktop/Web acceptance, with assertions expressed as release-safe data.
static func fresh(fallback: bool, workers: int = 1):
	if not fallback:
		var native = ClassDB.instantiate(&"CyberNativeCellWorld")
		if not native.diagnostic_reset({"workers":workers}):
			return null
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

static func run(fallback: bool = false, workers: int = 1) -> Dictionary:
	var failures: Array[String] = []
	var rows: Array = []
	for material: int in [2,13,14,19,23,25,26,27,29]:
		var world = fresh(fallback, workers)
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
	var loose = fresh(fallback,workers)
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
	return {"ok":failures.is_empty(),"failures":failures,"player":rows,"fallback":fallback,"workers":workers,"policy_version":1}
