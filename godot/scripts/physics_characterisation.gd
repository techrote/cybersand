class_name CyberPhysicsCharacterisation
extends RefCounted

# Offline, opt-in fixture owner. No main demo changes or real-time guarantee.
# All arrays are bounded by the validated run budget; samples are copied outside
# native ticks. The same fixture runs on desktop and actual Web exports.
const DT: float = 1.0 / 60.0
const MAX_TICKS: int = 7200
const MAX_CASES: int = 512

static func run(host: Node, cases: Array, output_dir: String = "") -> Dictionary:
	var reports: Array = []
	if cases.size() > MAX_CASES:
		return {"ok": false, "error": "case capacity"}
	for spec: Dictionary in cases:
		var report: Dictionary = await run_case(host, spec, output_dir)
		reports.append(report)
		print("PHYSICS_RESULT ", JSON.stringify(report))
		if not report.get("ok", false):
			return {"ok": false, "results": reports}
	return {"ok": true, "results": reports}

static func fill(world, x: int, y: int, w: int, h: int, material: int) -> void:
	if world.has_method(&"diagnostic_fill_rect"):
		var filled: bool = world.diagnostic_fill_rect(Vector2i(x,y), Vector2i(w,h), material)
		if not filled: push_error("Physics fixture rectangle rejected")
	else:
		for yy: int in range(y,y+h):
			for xx: int in range(x,x+w):
				world.set_cell(xx, yy, material)

static func sample(world, origin: Vector2i, size: Vector2i, histogram: bool) -> Dictionary:
	if world.has_method(&"diagnostic_snapshot"):
		return world.diagnostic_snapshot(origin, size, histogram)
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(size.x * size.y)
	var counts: Array = []
	counts.resize(81)
	counts.fill(0)
	for y: int in range(size.y):
		for x: int in range(size.x):
			var m: int = world.cells[(origin.y+y)*1024+origin.x+x]
			cells[y*size.x+x] = m
			counts[m] += 1
	return {"cells": cells, "counts": counts, "completed_ticks": world.tick_index,
		"water_mass": -1, "hash": str(hash(cells)), "overflow": -1}

static func quantiles(values: PackedFloat64Array) -> Array:
	var ordered: PackedFloat64Array = values.duplicate()
	ordered.sort()
	return [ordered[ordered.size()/2], ordered[ordered.size()*95/100], ordered[-1]]

# Optional accounting control, outside tick/coupling timing. Four bounded copies
# cover the finite adapter world, including material ejected outside the bed ROI.
static func global_water_mass(world) -> int:
	var total: int = 0
	for y: int in [0,512]:
		for x: int in [0,512]:
			total += int(world.diagnostic_snapshot(Vector2i(x,y),Vector2i(512,512)).water_mass)
	return total

static func run_case(host: Node, spec: Dictionary, output_dir: String = "") -> Dictionary:
	var ticks: int = int(spec.get("ticks", 1800))
	if ticks < 1 or ticks > MAX_TICKS:
		return {"ok": false, "error": "tick capacity"}
	var seed: int = int(spec.get("seed", 0))
	var left: int = 96 + seed * 3
	var surface: int = 192 + (seed * 7 % 20)
	var width: int = 96
	var floor_y: int = surface + 384
	var material: int = int(spec.get("material", 2))
	var mode: String = spec.get("mode", "barrel")
	var layout: String = spec.get("layout", "flat")
	var fallback: bool = spec.get("fallback", false)
	var world: Variant
	if fallback:
		world = CyberCellWorld.new()
		world.cells.fill(0)
		world.active_blocks.fill(0)
		world.next_active_blocks.fill(0)
		world.block_movable_counts.fill(0)
		world.downward_support_cells = int(spec.get("support_cells", 8))
	else:
		world = ClassDB.instantiate(&"CyberNativeCellWorld")
		if not world.diagnostic_reset(spec):
			return {"ok": false, "error": "diagnostic reset", "spec": spec}
	world.set_simulation_window(Vector2i(left-4,0), Vector2i(width+8,floor_y+4),0,0)
	fill(world,left-1,0,1,floor_y+1,1)
	fill(world,left+width,0,1,floor_y+1,1)
	fill(world,left-1,floor_y,width+2,1,1)
	fill(world,left-1,0,width+2,1,1)
	if material != 0:
		if layout == "slope":
			for x: int in range(width):
				var offset: int = x/4
				fill(world,left+x,surface+offset,1,floor_y-surface-offset,material)
		else:
			fill(world,left,surface,width,1 if layout == "film" else floor_y-surface,material)
	if layout == "mixed":
		for y: int in range(surface,floor_y,4):
			fill(world,left,y,width,1,14)
	if layout == "hard":
		fill(world,left,surface,width,1,1)
	if mode == "cellular":
		fill(world,left,surface-16,width,16,int(spec.get("top",33)))
	var crop_origin: Vector2i = Vector2i(left-1, surface-128)
	var crop_size: Vector2i = Vector2i(width+2, floor_y-crop_origin.y+1)
	var player: CyberSampledCharacter = CyberSampledCharacter.new()
	player.reset(Vector2(left+width/2-4,surface-28))
	if layout == "enclosed":
		player.reset(Vector2(left+width/2-4,surface+12))
	if layout == "interior":
		fill(world,left,surface,width,floor_y-surface,0)
		fill(world,left+width/2,surface-23,1,1,material)
	if layout == "side":
		fill(world,left+64,surface-42,16,42,material)
		player.reset(Vector2(left+40,surface-14))
	if layout == "falling":
		fill(world,left,surface,width,floor_y-surface,0)
		fill(world,left,surface-48,width,8,material)
	var initial: Dictionary = sample(world,crop_origin,crop_size,false)
	if spec.get("conservation",false) and not fallback:
		initial["global_water_mass"] = global_water_mass(world)
	if initial.counts[1] <= 0:
		return {"ok":false,"error":"fixture construction produced no walls","spec":spec}
	var viewport: SubViewport
	var body: RigidBody2D
	var bridge: CyberRapierPhysicsBridge
	var body_size: Vector2 = Vector2(8,14) * float(spec.get("size",1.0))
	var angle: float = float(spec.get("angle",0.0))
	var extent: float = absf(cos(angle))*body_size.y + absf(sin(angle))*body_size.x
	if mode == "barrel":
		viewport = SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.size = Vector2i(128,128)
		host.add_child(viewport)
		body = RigidBody2D.new()
		body.mass = float(spec.get("mass",1.0))
		body.gravity_scale = 0.094
		body.linear_damp = 0.15 * float(spec.get("damping",1.0))
		body.angular_damp = 0.35 * float(spec.get("damping",1.0))
		body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		body.position = Vector2(left+width/2,surface-extent/2-float(spec.get("drop",1.0))*body_size.y)
		body.rotation = angle
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = body_size
		shape.shape = rectangle
		body.add_child(shape)
		viewport.add_child(body)
		await host.get_tree().process_frame
		bridge = CyberRapierPhysicsBridge.new()
		var bodies: Array[RigidBody2D] = [body]
		if bridge.initialize(viewport.world_2d.space,bodies,PackedVector2Array([body_size])) != OK:
			viewport.queue_free()
			return {"ok": false, "error": "Rapier initialize"}
		bridge.enable_diagnostics()
		PhysicsServer2D.body_set_param(body.get_rid(), PhysicsServer2D.BODY_PARAM_FRICTION,float(spec.get("friction",0.78)))
		bridge.reset_body(0,Vector2(left+width/2,surface-extent/2-float(spec.get("drop",1.0))*body_size.y),angle)
		PhysicsServer2D.body_set_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2(0,float(spec.get("speed",0.0))))
		bridge.refresh_all_states()
		var rectangles: PackedInt32Array = world.get_hard_surface_rectangles() if not fallback else PackedInt32Array([left-1,floor_y,width+2,1,left-1,0,1,floor_y,left+width,0,1,floor_y])
		bridge.rebuild_hard_surface_colliders_from_rectangles(rectangles)
	var tick_times: PackedFloat64Array = PackedFloat64Array()
	var coupling_times: PackedFloat64Array = PackedFloat64Array()
	tick_times.resize(ticks)
	coupling_times.resize(ticks)
	var history: Array = []
	history.resize(10) # controlled sample delays 0..9; overwritten ring
	var rows: Array = []
	var frame_records: Array = []
	var peak_depth: float = 0.0
	var late_start: float = 0.0
	var final_depth: float = 0.0
	var floor_contact_tick: int = -1
	var pre_floor: Dictionary = {}
	var caps: int = 0
	var final_caps: int = 0
	var displaced: int = 0
	var unresolved: int = 0
	var raw_displacement: Vector2 = Vector2.ZERO
	var raw_boundary: Vector2 = Vector2.ZERO
	var raw_contact: Vector2 = Vector2.ZERO
	var applied: Vector2 = Vector2.ZERO
	var max_age: int = 0
	var stale: int = 0
	var duplicates: int = 0
	var grounded_ticks: int = 0
	var max_overlap: int = 0
	var face_totals: Array = []
	face_totals.resize(324)
	face_totals.fill(0)
	var delay: int = clampi(int(spec.get("delay",0)),0,9)
	var last_sample: Dictionary = initial
	var frames: Array[int] = [0,59,299,ticks-1]
	for tick: int in range(ticks):
		if layout == "excavate" and tick == 600:
			fill(world,left+width/2-16,surface,32,floor_y-surface,0)
		if layout == "reentry" and tick == 120:
			world.set_simulation_window(Vector2i(768,768),Vector2i(64,64),0,0)
		if layout == "reentry" and tick == 600:
			world.set_simulation_window(Vector2i(left-4,0),Vector2i(width+8,floor_y+4),0,0)
		var start: int = Time.get_ticks_usec()
		if mode == "barrel":
			bridge.step()
			var states: PackedFloat32Array = bridge.pack_body_states()
			history[tick%10] = states
			var selected: PackedFloat32Array = history[maxi(0,tick-delay)%10]
			world.prepare_rigid_body_coupling(selected)
		elif mode == "player":
			var horizontal: float = 0.0
			if layout == "walk" or layout == "slope" or layout == "side":
				horizontal = 1.0 if tick%240 < 120 else -1.0
			player.simulate(DT,horizontal,false,world)
		coupling_times[tick] = Time.get_ticks_usec()-start
		start = Time.get_ticks_usec()
		var succeeded: Variant = world.simulation_tick()
		tick_times[tick] = Time.get_ticks_usec()-start
		if not fallback and not succeeded:
			if bridge != null: bridge.shutdown()
			if viewport != null: viewport.queue_free()
			return {"ok": false, "error": "failed tick", "completed": tick, "spec": spec}
		var center: Vector2 = player.centre()
		var velocity: Vector2 = player.velocity
		var rotation: float = 0.0
		var impulse: Vector2 = Vector2.ZERO
		if mode == "barrel":
			var result: PackedFloat32Array = world.rigid_body_results()
			bridge.apply_cellular_results(tick+1,result)
			var apps: PackedFloat64Array = bridge.diagnostic_applications
			impulse = Vector2(apps[1],apps[2])
			applied += impulse
			max_age = maxi(max_age,int(apps[0]))
			stale += int(apps[4])
			if spec.get("duplicate",false):
				bridge.apply_cellular_results(tick+1,result)
				duplicates += int(bridge.diagnostic_applications[3])
			if not fallback and spec.get("telemetry",true):
				var d: Array = world.diagnostic_body_metrics()[0]
				raw_displacement += Vector2(d[2],d[3])
				raw_boundary += Vector2(d[4],d[5])
				raw_contact += Vector2(d[6],d[7])
				caps += int(d[12])
				final_caps += int(d[13])
				for i: int in range(324): face_totals[i] += int(d[16][i])
			if result.size() >= 9:
				displaced += int(result[6])
				unresolved += int(result[7])
			center = bridge.body_transform(0).origin
			rotation = bridge.body_transform(0).get_rotation()
			velocity = PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
			grounded_ticks += int(PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_SLEEPING))
		else:
			grounded_ticks += int(player.grounded)
		extent = absf(cos(rotation))*body_size.y+absf(sin(rotation))*body_size.x
		final_depth = maxf(0.0,center.y+extent/2-surface)
		if floor_contact_tick < 0 and center.y+extent/2 >= floor_y-1.0:
			floor_contact_tick = tick+1
			pre_floor = {"tick":tick+1,"caps":caps,"unresolved":unresolved,"displaced":displaced,
				"displacement":[raw_displacement.x,raw_displacement.y],"boundary":[raw_boundary.x,raw_boundary.y],
				"contact":[raw_contact.x,raw_contact.y],"applied":[applied.x,applied.y]}
		peak_depth = maxf(peak_depth,final_depth)
		if tick == ticks-601: late_start = final_depth
		if tick%60 == 0 or tick == ticks-1 or frames.has(tick):
			last_sample = sample(world,crop_origin,crop_size,tick==ticks-1)
			var overlap: int = 0
			var contact_materials: Array = []
			var half_width: float = (absf(cos(rotation))*body_size.x+absf(sin(rotation))*body_size.y)/2
			for y: int in range(floori(center.y-extent/2),ceili(center.y+extent/2)):
				for x: int in range(floori(center.x-half_width),ceili(center.x+half_width)):
					var local: Vector2 = (Vector2(x+0.5,y+0.5)-center).rotated(-rotation)
					if absf(local.x)>body_size.x/2 or absf(local.y)>body_size.y/2: continue
					if x>=crop_origin.x and x<crop_origin.x+crop_size.x and y>=crop_origin.y and y<crop_origin.y+crop_size.y:
						var m: int = last_sample.cells[(y-crop_origin.y)*crop_size.x+x-crop_origin.x]
						if m != 0: overlap += 1
						if m != 0 and not contact_materials.has(m): contact_materials.append(m)
			max_overlap = maxi(max_overlap,overlap)
			var foot_materials: Array = []
			for x: int in range(floori(center.x-half_width),ceili(center.x+half_width)):
				var m: int = world.material_at(x,floori(center.y+extent/2+0.5))
				if not foot_materials.has(m): foot_materials.append(m)
			# Deformed bed surface: median first occupied cell in the four columns
			# just outside each projected side. Report separately from initial datum.
			var surfaces: Array = []
			var half_x: float = (absf(cos(rotation))*body_size.x+absf(sin(rotation))*body_size.y)/2
			for dx: int in [-4,-3,-2,-1,1,2,3,4]:
				var x: int = floori(center.x + signi(dx)*(half_x+abs(dx)))
				if x<crop_origin.x or x>=crop_origin.x+crop_size.x: continue
				for y: int in range(maxi(crop_origin.y,surface-16),floor_y+1):
					if last_sample.cells[(y-crop_origin.y)*crop_size.x+x-crop_origin.x] != 0:
						surfaces.append(y)
						break
			surfaces.sort()
			var local_surface: float = surfaces[surfaces.size()/2] if not surfaces.is_empty() else floor_y
			rows.append({"tick":tick+1,"x":center.x,"y":center.y,"vy":velocity.y,"vx":velocity.x,"rotation":rotation,
				"depth":final_depth,"local_depth":maxf(0,center.y+extent/2-local_surface),"local_surface":local_surface,
				"grounded":player.grounded,"overlap":overlap,"materials":contact_materials,"foot_materials":foot_materials,"water_mass":last_sample.water_mass,
				"impulse_x":impulse.x,"impulse_y":impulse.y,"caps":caps,"unresolved":unresolved,"displaced":displaced,
				"raw_displacement":[raw_displacement.x,raw_displacement.y],"raw_boundary":[raw_boundary.x,raw_boundary.y],
				"raw_contact":[raw_contact.x,raw_contact.y],"applied":[applied.x,applied.y],"max_age":max_age})
			if mode == "cellular":
				var front: int = 0
				for index: int in range(last_sample.cells.size()):
					if last_sample.cells[index] == int(spec.get("top",33)):
						front = maxi(front,index/crop_size.x+crop_origin.y-surface+1)
				rows[-1]["front"] = front
			if frames.has(tick) and spec.get("visual",false):
				frame_records.append({"tick":tick+1,"width":crop_size.x,"height":crop_size.y,"origin":[crop_origin.x,crop_origin.y],
					"body":[center.x,center.y,rotation,body_size.x,body_size.y],"surface":surface,"cells":Marshalls.raw_to_base64(last_sample.cells)})
		if tick%120 == 0:
			await host.get_tree().process_frame
	if spec.get("conservation",false) and not fallback:
		last_sample["global_water_mass"] = global_water_mass(world)
		var below: Dictionary = world.diagnostic_snapshot(Vector2i(0,floor_y+1),Vector2i(512,1024-floor_y-1))
		last_sample["water_below_floor"] = below.water_mass
		last_sample["water_above_crop"] = world.diagnostic_snapshot(Vector2i(0,0),Vector2i(512,crop_origin.y)).water_mass
	if bridge != null: bridge.shutdown()
	if viewport != null:
		viewport.queue_free()
		await host.get_tree().process_frame
	last_sample.erase("cells")
	initial.erase("cells")
	var report: Dictionary = {"ok":true,"spec":spec,"platform":OS.get_name(),"godot":Engine.get_version_info().string,
		"completed_ticks":ticks,"surface":surface,"floor":floor_y,"initial":initial,"final":last_sample,
		"peak_depth":peak_depth,"final_depth":final_depth,"late_creep":final_depth-late_start if floor_contact_tick<0 and ticks>=600 else null,
		"floor_contact_tick":floor_contact_tick,"pre_floor":pre_floor,"grounded_ticks":grounded_ticks,
		"max_overlap":max_overlap,"intermediate_caps":caps,"final_caps":final_caps,"displaced":displaced,"unresolved":unresolved,
		"displacement_impulse":[raw_displacement.x,raw_displacement.y],"boundary_impulse":[raw_boundary.x,raw_boundary.y],
		"contact_impulse":[raw_contact.x,raw_contact.y],"applied_impulse":[applied.x,applied.y],"max_sample_age":max_age,
		"stale":stale,"duplicates":duplicates,"faces":face_totals,"tick_us":quantiles(tick_times),"coupling_us":quantiles(coupling_times),
		"rows":rows,"frames":frame_records}
	report.ok = int(last_sample.completed_ticks) == ticks and not last_sample.get("failed",false)
	if layout == "hard" and peak_depth > 2.0:
		report.ok = false
		report["error"] = "hard-floor control exceeded two-cell fixture tolerance"
	if not output_dir.is_empty():
		var path: String = output_dir.path_join(str(spec.get("id","fixture"))+".json")
		var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		if file == null: return {"ok":false,"error":"output file", "path":path}
		file.store_string(JSON.stringify(report))
		file.close()
	# Console/DOM summary remains bounded; detailed traces live in result files.
	report.erase("frames")
	return report
