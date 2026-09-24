extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var spec: Dictionary = {"mode":"barrel","material":2,"ticks":180,"seed":2}
	var baseline: Dictionary = await CyberPhysicsCharacterisation.run_case(root,spec)
	var off: Dictionary = await CyberPhysicsCharacterisation.run_case(root,spec.merged({"telemetry":false}))
	var parallel: Dictionary = await CyberPhysicsCharacterisation.run_case(root,spec.merged({"workers":4}))
	var duplicate: Dictionary = await CyberPhysicsCharacterisation.run_case(root,spec.merged({"duplicate":true}))
	var failed: bool = false
	for other: Dictionary in [off,parallel,duplicate]:
		if not other.ok or other.final.hash != baseline.final.hash:
			push_error("Physics fixture cell state differs with observer/workers/duplicates")
			failed = true
		for index: int in range(baseline.rows.size()):
			for key: String in ["x","y","rotation","vx","vy"]:
				if baseline.rows[index][key] != other.rows[index][key]:
					push_error("Physics fixture trajectory changed: "+key)
					failed = true
	if int(baseline.final.overflow) != 0:
		push_error("Physics fixture telemetry overflow")
		failed = true
	var hard: Dictionary = await CyberPhysicsCharacterisation.run_case(root,{"mode":"barrel","material":0,"layout":"hard","ticks":180})
	if not hard.ok or hard.peak_depth > 2:
		push_error("Physics fixture hard-floor control failed")
		failed = true
	var water: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	assert(water.diagnostic_reset({}))
	assert(water.diagnostic_fill_rect(Vector2i(100,100),Vector2i(8,14),3))
	var states: PackedFloat32Array = PackedFloat32Array([1,104,107,0,8,14,0,0,0,1,1])
	water.prepare_rigid_body_coupling(states,false)
	var before: Dictionary = water.diagnostic_snapshot(Vector2i(90,90),Vector2i(40,40))
	if before.water_mass != 8*14*255:
		push_error("Conservation probe hid Water under the body mask")
		failed = true
	if water.diagnostic_reset({"viscosity":999}):
		push_error("Invalid diagnostic reset succeeded")
		failed = true
	var after: Dictionary = water.diagnostic_snapshot(Vector2i(90,90),Vector2i(40,40))
	if before.hash != after.hash:
		push_error("Rejected diagnostic reset mutated authority")
		failed = true
	# A bounded ejection search may not relocate material through intervening hard
	# terrain. With no reachable destination, stored Water remains unresolved.
	var ejection: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not ejection.diagnostic_reset({}):
		failed = true
	ejection.diagnostic_fill_rect(Vector2i(104,113),Vector2i.ONE,3)
	ejection.diagnostic_fill_rect(Vector2i(90,114),Vector2i(32,1),1)
	ejection.prepare_rigid_body_coupling(states,true)
	var below: Dictionary = ejection.diagnostic_snapshot(Vector2i(90,115),Vector2i(32,16))
	var retained: Dictionary = ejection.diagnostic_snapshot(Vector2i(90,90),Vector2i(32,25))
	var retained_source_index: int = (113 - 90) * 32 + (104 - 90)
	if (
		below.water_mass != 0
		or retained.water_mass != 255
		or retained.cells[retained_source_index] != 3
		or ejection.get_rigid_body_displaced_last_tick() != 0
		or ejection.get_rigid_body_unresolved_last_tick() != 1
	):
		push_error("Thin-floor ejection crossed a barrier or failed conservation")
		failed = true

	# Another body's transient mask is also an intervening collision barrier. The
	# source body's own mask remains traversable during bounded outward ejection.
	var body_barrier: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not body_barrier.diagnostic_reset({}):
		failed = true
	body_barrier.diagnostic_fill_rect(Vector2i(104,113),Vector2i.ONE,3)
	var two_states: PackedFloat32Array = PackedFloat32Array([
		1,104,107,0,8,14,0,0,0,1,1,
		2,104,115,0,32,1,0,0,0,1,1,
	])
	body_barrier.prepare_rigid_body_coupling(two_states,true)
	var body_blocked: Dictionary = body_barrier.diagnostic_snapshot(Vector2i(88,96),Vector2i(33,32))
	var body_source_index: int = (113-96)*33+(104-88)
	if (
		body_blocked.water_mass != 255
		or body_blocked.cells[body_source_index] != 3
		or body_barrier.get_rigid_body_displaced_last_tick() != 0
		or body_barrier.get_rigid_body_unresolved_last_tick() != 1
	):
		push_error("Ejection crossed another body or failed conservation")
		failed = true
	if not failed: print("Physics observer, worker, duplicate, barrier and stored-mass checks passed")
	quit(1 if failed else 0)
