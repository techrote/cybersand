extends SceneTree

# REM-003 / #82 observation-first Current-source characterization.
# This file deliberately asserts only execution/correctness invariants at the
# preregistration checkpoint. It prints bounded behavior measurements for Current;
# candidate-specific regressions are added only after the mechanism is classified.

const DT: float = 1.0 / 60.0
const BODY_SIZE := Vector2(8.0, 14.0)
const LEFT: int = 64
const RIGHT: int = 256
const FLOOR_Y: int = 260
const SURFACE_Y: int = 200

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("REM-003: " + message)


func _new_world(fallback: bool) -> Object:
	if not fallback:
		var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		_check(world != null, "native world unavailable")
		if world != null:
			_check(world.diagnostic_reset({"workers": 1}), "native diagnostic reset failed")
		return world

	var world := CyberCellWorld.new()
	world.cells.fill(CyberCellWorld.EMPTY)
	world.updated_at.fill(0)
	world.quiet_ticks.fill(0)
	world.flow_budget.fill(0)
	world.flow_direction.fill(CyberCellWorld.FLOW_DIRECTION_NONE)
	world.active_blocks.fill(0)
	world.next_active_blocks.fill(0)
	world.block_movable_counts.fill(0)
	world.rigid_body_occupancy.fill(0)
	world.simulation_window_enabled = false
	return world


func _fill(world: Object, fallback: bool, x: int, y: int, w: int, h: int, material: int) -> void:
	if w <= 0 or h <= 0:
		return
	if not fallback:
		_check(
			world.diagnostic_fill_rect(Vector2i(x, y), Vector2i(w, h), material),
			"native diagnostic fill failed"
		)
		return
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			world.set_cell(xx, yy, material)


func _base_containment(world: Object, fallback: bool) -> void:
	_fill(world, fallback, LEFT - 1, 0, 1, FLOOR_Y + 1, CyberCellWorld.WALL)
	_fill(world, fallback, RIGHT, 0, 1, FLOOR_Y + 1, CyberCellWorld.WALL)
	_fill(world, fallback, LEFT - 1, FLOOR_Y, RIGHT - LEFT + 2, 1, CyberCellWorld.WALL)


func _build_case(world: Object, fallback: bool, spec: Dictionary) -> Vector2:
	_base_containment(world, fallback)
	var material: int = int(spec.get("material", CyberCellWorld.SAND))
	var layout: String = str(spec.get("layout", "flat"))

	match layout:
		"flat":
			_fill(world, fallback, LEFT, SURFACE_Y, RIGHT - LEFT, FLOOR_Y - SURFACE_Y, material)
			return Vector2(float(spec.get("start_x", 104)), SURFACE_Y - BODY_SIZE.y)
		"hardflat":
			_fill(world, fallback, LEFT, SURFACE_Y, RIGHT - LEFT, FLOOR_Y - SURFACE_Y, material)
			return Vector2(float(spec.get("start_x", 104)), SURFACE_Y - BODY_SIZE.y)
		"shallow":
			_fill(world, fallback, LEFT, SURFACE_Y + 3, RIGHT - LEFT, FLOOR_Y - SURFACE_Y - 3, CyberCellWorld.WALL)
			_fill(world, fallback, LEFT, SURFACE_Y, RIGHT - LEFT, 3, material)
			return Vector2(104, SURFACE_Y - BODY_SIZE.y)
		"edge":
			_fill(world, fallback, LEFT, SURFACE_Y, 88, FLOOR_Y - SURFACE_Y, material)
			return Vector2(128, SURFACE_Y - BODY_SIZE.y)
		"film":
			_fill(world, fallback, LEFT, SURFACE_Y, RIGHT - LEFT, 1, material)
			return Vector2(104, SURFACE_Y - 32.0)
		"side":
			_fill(world, fallback, LEFT, 210, RIGHT - LEFT, FLOOR_Y - 210, material)
			_fill(world, fallback, 152, 174, 36, 36, material)
			return Vector2(112, 210.0 - BODY_SIZE.y)
		"slope":
			_fill(world, fallback, LEFT, 214, RIGHT - LEFT, FLOOR_Y - 214, material)
			for x: int in range(120, 205):
				var rise: int = (x - 120) / 4
				var top: int = 214 - rise
				_fill(world, fallback, x, top, 1, 214 - top, material)
			return Vector2(96, 214.0 - BODY_SIZE.y)
		"landing":
			_fill(world, fallback, LEFT, SURFACE_Y, RIGHT - LEFT, FLOOR_Y - SURFACE_Y, material)
			var drop_gap: float = float(spec.get("drop_gap", 12.0))
			return Vector2(104, SURFACE_Y - BODY_SIZE.y - drop_gap)
		"excavate":
			_fill(world, fallback, LEFT, SURFACE_Y, RIGHT - LEFT, FLOOR_Y - SURFACE_Y, material)
			return Vector2(104, SURFACE_Y - BODY_SIZE.y)
		_:
			_check(false, "unknown case layout " + layout)
			return Vector2(104, SURFACE_Y - BODY_SIZE.y)


func _input_for(schedule: String, tick: int) -> float:
	match schedule:
		"walk":
			if tick < 30:
				return 0.0
			if tick < 150:
				return 1.0
			if tick < 210:
				return 0.0
			if tick < 330:
				return -1.0
			return 0.0
		"slow":
			return 0.25 if tick >= 30 else 0.0
		"right":
			return 1.0 if tick >= 30 else 0.0
		"repeat":
			if tick < 30:
				return 0.0
			return 1.0 if ((tick - 30) / 60) as int % 2 == 0 else -1.0
		_:
			return 0.0


func _packing_occupancy(world: Object, player: CyberSampledCharacter) -> int:
	var foot_y: int = floori(player.position.y + BODY_SIZE.y + 0.5)
	var best: int = 0
	for foot_x: int in range(
		floori(player.position.x),
		ceili(player.position.x + BODY_SIZE.x)
	):
		var occupied: int = 0
		for dy: int in range(0, 3):
			for dx: int in range(-1, 2):
				var material: int = int(world.material_at(foot_x + dx, foot_y + dy))
				if CyberInteractionPolicy.supports_load(material):
					occupied += 1
		best = maxi(best, occupied)
	return best


func _overlap_count(world: Object, player: CyberSampledCharacter) -> int:
	var count: int = 0
	for y: int in range(
		floori(player.position.y + 0.001),
		ceili(player.position.y + BODY_SIZE.y - 0.001)
	):
		for x: int in range(
			floori(player.position.x + 0.001),
			ceili(player.position.x + BODY_SIZE.x - 0.001)
		):
			if int(world.material_at(x, y)) != CyberCellWorld.EMPTY:
				count += 1
	return count


func _changed_cells(before: PackedByteArray, after: PackedByteArray) -> int:
	if before.size() != after.size():
		return -1
	var count: int = 0
	for index: int in range(before.size()):
		count += int(before[index] != after[index])
	return count


func _run_case(spec: Dictionary, fallback: bool) -> Dictionary:
	var world: Object = _new_world(fallback)
	if world == null:
		return {"ok": false, "error": "world construction"}
	var start: Vector2 = _build_case(world, fallback, spec)
	var player := CyberSampledCharacter.new()
	player.reset(start)
	if str(spec.get("layout", "")) == "landing":
		player.velocity.y = float(spec.get("initial_vy", 0.0))

	var roi_origin := Vector2i(LEFT - 1, 150)
	var roi_size := Vector2i(RIGHT - LEFT + 2, FLOOR_Y - 149)
	var initial: Dictionary = CyberPhysicsCharacterisation.sample(world, roi_origin, roi_size, false)
	var initial_cells: PackedByteArray = initial.get("cells", PackedByteArray())

	var ticks: int = int(spec.get("ticks", 360))
	var schedule: String = str(spec.get("schedule", "none"))
	var grounded_transitions: int = 0
	var previous_grounded: bool = player.grounded
	var grounded_ticks: int = 0
	var support_ticks: int = 0
	var side_ticks: int = 0
	var peak_overlap: int = 0
	var max_packing: int = 0
	var full_stop_ticks: int = 0
	var probe_queries: int = 0
	var probe_usec: int = 0
	var player_usec: int = 0
	var world_usec: int = 0
	var native_moves_sum: int = 0
	var native_scanned_sum: int = 0
	var native_active_blocks_sum: int = 0
	var native_active_blocks_max: int = 0
	var release_tick: int = -1
	var first_grounded_tick: int = -1
	var first_impact_speed: float = -1.0
	var max_abs_vx: float = 0.0
	var max_abs_vy: float = 0.0
	var min_x: float = player.position.x
	var max_x: float = player.position.x
	var sample_rows: Array = []

	for tick: int in range(ticks):
		if str(spec.get("layout", "")) == "excavate" and tick == 180:
			var shaft_x: int = floori(player.position.x) - 3
			_fill(
				world,
				fallback,
				shaft_x,
				SURFACE_Y,
				14,
				FLOOR_Y - SURFACE_Y,
				CyberCellWorld.EMPTY
			)

		var horizontal: float = _input_for(schedule, tick)
		var jetpack: bool = bool(spec.get("jetpack", false)) and tick >= 90 and tick < 120
		var was_grounded: bool = player.grounded
		var pre_sim_vy: float = player.velocity.y
		var started: int = Time.get_ticks_usec()
		player.simulate(DT, horizontal, jetpack, world)
		player_usec += Time.get_ticks_usec() - started
		if not was_grounded and player.grounded and first_impact_speed < 0.0:
			first_impact_speed = maxf(0.0, pre_sim_vy + CyberSampledCharacter.GRAVITY * DT)

		started = Time.get_ticks_usec()
		var down_support: bool = world.character_box_collides(
			player.position + Vector2(0.0, 0.5), BODY_SIZE, 1
		)
		var side_support: bool = world.character_box_collides(
			player.position + Vector2(0.5 if horizontal >= 0.0 else -0.5, 0.0),
			BODY_SIZE,
			2
		)
		probe_usec += Time.get_ticks_usec() - started
		probe_queries += 2
		support_ticks += int(down_support)
		side_ticks += int(side_support)
		var packing: int = _packing_occupancy(world, player)
		max_packing = maxi(max_packing, packing)
		peak_overlap = maxi(peak_overlap, _overlap_count(world, player))

		if player.grounded != previous_grounded:
			grounded_transitions += 1
			previous_grounded = player.grounded
		if player.grounded:
			grounded_ticks += 1
			if first_grounded_tick < 0:
				first_grounded_tick = tick + 1
		elif str(spec.get("layout", "")) == "excavate" and tick >= 180 and release_tick < 0:
			release_tick = tick + 1

		if absf(horizontal) > 0.01 and tick > 45 and absf(player.velocity.x) < 0.01:
			full_stop_ticks += 1
		max_abs_vx = maxf(max_abs_vx, absf(player.velocity.x))
		max_abs_vy = maxf(max_abs_vy, absf(player.velocity.y))
		min_x = minf(min_x, player.position.x)
		max_x = maxf(max_x, player.position.x)

		started = Time.get_ticks_usec()
		var tick_result: Variant = world.simulation_tick()
		world_usec += Time.get_ticks_usec() - started
		if not fallback and not bool(tick_result):
			return {
				"ok": false,
				"error": "native tick failed",
				"tick": tick + 1,
				"case": spec.get("id", "unknown"),
			}
		if not fallback:
			var active_blocks: int = int(world.get_active_blocks_last_tick())
			native_moves_sum += int(world.get_moves_last_tick())
			native_scanned_sum += int(world.get_scanned_last_tick())
			native_active_blocks_sum += active_blocks
			native_active_blocks_max = maxi(native_active_blocks_max, active_blocks)

		if tick % 60 == 59 or tick == ticks - 1:
			sample_rows.append({
				"tick": tick + 1,
				"x": player.position.x,
				"y": player.position.y,
				"vx": player.velocity.x,
				"vy": player.velocity.y,
				"grounded": player.grounded,
				"down_support": down_support,
				"side_support": side_support,
				"packing": packing,
				"overlap": _overlap_count(world, player),
			})

	var final: Dictionary = CyberPhysicsCharacterisation.sample(world, roi_origin, roi_size, false)
	var final_cells: PackedByteArray = final.get("cells", PackedByteArray())
	var result := {
		"ok": true,
		"id": str(spec.get("id", "unknown")),
		"backend": "fallback" if fallback else "native",
		"material": int(spec.get("material", CyberCellWorld.SAND)),
		"layout": str(spec.get("layout", "flat")),
		"schedule": schedule,
		"ticks": ticks,
		"start": [start.x, start.y],
		"final": [player.position.x, player.position.y],
		"min_x": min_x,
		"max_x": max_x,
		"max_abs_vx": max_abs_vx,
		"max_abs_vy": max_abs_vy,
		"grounded_ticks": grounded_ticks,
		"grounded_transitions": grounded_transitions,
		"first_grounded_tick": first_grounded_tick,
		"first_impact_speed": first_impact_speed,
		"support_ticks": support_ticks,
		"side_support_ticks": side_ticks,
		"peak_overlap": peak_overlap,
		"max_packing_occupancy": max_packing,
		"full_stop_ticks": full_stop_ticks,
		"release_tick": release_tick,
		"observer_probe_queries": probe_queries,
		"observer_probe_usec_total": probe_usec,
		"player_simulate_usec_total": player_usec,
		"world_tick_usec_total": world_usec,
		"native_moves_sum": native_moves_sum if not fallback else -1,
		"native_scanned_sum": native_scanned_sum if not fallback else -1,
		"native_active_blocks_sum": native_active_blocks_sum if not fallback else -1,
		"native_active_blocks_max": native_active_blocks_max if not fallback else -1,
		"changed_cells": _changed_cells(initial_cells, final_cells),
		"samples": sample_rows,
	}
	return result


func _run() -> void:
	var cases: Array = [
		{"id": "C00-hard-stand", "layout": "hardflat", "material": CyberCellWorld.GRANITE_BLOCK, "ticks": 240},
		{"id": "S01-packed-stand", "layout": "flat", "material": CyberCellWorld.SAND, "ticks": 300},
		{"id": "S02-shallow-supported", "layout": "shallow", "material": CyberCellWorld.SAND, "ticks": 240},
		{"id": "S03-film", "layout": "film", "material": CyberCellWorld.SAND, "ticks": 360},
		{"id": "H01-walk-reverse", "layout": "flat", "material": CyberCellWorld.SAND, "schedule": "walk", "ticks": 360},
		{"id": "H03-slope", "layout": "slope", "material": CyberCellWorld.SAND, "schedule": "right", "ticks": 360},
		{"id": "H04-packed-side", "layout": "side", "material": CyberCellWorld.SAND, "schedule": "right", "ticks": 300},
		{"id": "H05-edge", "layout": "edge", "material": CyberCellWorld.SAND, "schedule": "right", "ticks": 300},
		{"id": "H06-repeated", "layout": "flat", "material": CyberCellWorld.SAND, "schedule": "repeat", "ticks": 390},
		{"id": "V01-ordinary-landing", "layout": "landing", "material": CyberCellWorld.SAND, "ticks": 240, "drop_gap": 12.0},
		{"id": "V02-hard-landing", "layout": "landing", "material": CyberCellWorld.SAND, "ticks": 300, "drop_gap": 58.0, "initial_vy": 86.0},
		{"id": "V03-jetpack", "layout": "flat", "material": CyberCellWorld.SAND, "ticks": 300, "jetpack": true},
		{"id": "D03-excavate", "layout": "excavate", "material": CyberCellWorld.SAND, "ticks": 360},
		{"id": "S05-dust", "layout": "flat", "material": CyberCellWorld.DUST, "schedule": "slow", "ticks": 300},
		{"id": "S06-salt", "layout": "flat", "material": CyberCellWorld.SALT, "schedule": "slow", "ticks": 300},
		{"id": "S07-stone-granular", "layout": "flat", "material": CyberCellWorld.STONE, "schedule": "slow", "ticks": 300},
		{"id": "G02-chunk-seam", "layout": "flat", "material": CyberCellWorld.SAND, "schedule": "right", "start_x": 500, "ticks": 180},
	]
	var results: Array = []
	for fallback: bool in [false, true]:
		for spec: Dictionary in cases:
			var result: Dictionary = _run_case(spec, fallback)
			results.append(result)
			_check(bool(result.get("ok", false)), str(result.get("id", "case")) + " failed to execute")
			await process_frame

	# Pre-candidate invariant checks only. These do not declare gameplay quality.
	for result: Dictionary in results:
		if not bool(result.get("ok", false)):
			continue
		var id: String = str(result.id)
		if id == "C00-hard-stand":
			_check(int(result.grounded_ticks) > 190, "hard control failed durable standing support")
			_check(int(result.peak_overlap) == 0, "hard control penetrated hard terrain")
		elif id == "S01-packed-stand":
			_check(int(result.grounded_ticks) > 240, "packed Sand failed durable standing support")
			_check(int(result.peak_overlap) == 0, "packed standing penetrated authoritative material")
		elif id == "S03-film":
			_check(int(result.grounded_ticks) < int(result.ticks), "unsupported film became permanent support")
		elif id == "D03-excavate":
			_check(int(result.release_tick) >= 181, "excavation did not release grounded support")
		elif id == "S05-dust" or id == "S06-salt" or id == "S07-stone-granular":
			_check(int(result.grounded_ticks) > 200, id + " failed representative powder support")

	print("REM003_CURRENT ", JSON.stringify({
		"schema": "rem003-current-v1",
		"source_note": "CI runner identity binds exact source/runtime",
		"platform": OS.get_name(),
		"godot": Engine.get_version_info().string,
		"results": results,
	}))
	if not _failed:
		print("REM-003 Current characterization completed")
	quit(1 if _failed else 0)
