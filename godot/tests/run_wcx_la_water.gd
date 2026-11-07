extends SceneTree

# WCX-001 (#362 successor): matched LA-mode x Water impact discrimination on the
# owner-accepted #394 workbench host. Evidence-only apparatus: Main, the worker,
# the native World and Rapier are used unchanged. This script builds paired
# recipes that differ only in the granular response (and, separately, in the
# Water family), drops the ordinary passive reference barrel, and records the
# host-visible body, coupling-packet and displayed-Water observations.
#
# Usage: godot --headless --path godot --script res://tests/run_wcx_la_water.gd
#        -- [--out <json>] [--ticks N] [--scenes pool,sandbed,sandbank]
#           [--responses LA-SELECTIVE,LA,LA-EVENT-OFF,RFT] [--families freemass_v1,...]

const Setup = preload("res://scripts/workbench_setup.gd")
const WATCHDOG_MS := 120000
const WATER := 3
const SAND := 2
const WALL := 58
const SURFACE := 344          # first Water row of every scene
const ROI := Rect2i(100, 200, 313, 212)

var host: Control
var ui: Control
var rows: Array = []
var failures: Array[String] = []
var ticks := 240
var scenes := ["pool", "sandbed", "sandbank"]
var responses: Array = Setup.RESPONSES.duplicate()
var families := ["freemass_v1"]
var out_path := ""

func _initialize() -> void:
	run.call_deferred()

func fail(reason: String) -> void:
	failures.append(reason)
	push_error("WCX001: " + reason)

func wait_for(predicate: Callable, timeout: int = WATCHDOG_MS) -> bool:
	var until := Time.get_ticks_msec() + timeout
	while Time.get_ticks_msec() < until:
		if predicate.call(): return true
		if host.simulation_worker.has_failed(): return false
		await process_frame
	return false

func parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i + 1 < args.size():
		match args[i]:
			"--out": out_path = args[i + 1]
			"--ticks": ticks = int(args[i + 1])
			"--scenes": scenes = Array(args[i + 1].split(","))
			"--responses": responses = Array(args[i + 1].split(","))
			"--families": families = Array(args[i + 1].split(","))
		i += 2

func water_policy(bridge: Variant, family: String) -> PackedInt32Array:
	var request: PackedInt32Array = bridge.default_liquid_policy()
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, WATER):
		if str(choice.get("family", "")) == family and str(choice.get("variant", "")) == "reference" and choice.get("accepted", false):
			return choice.request
	return PackedInt32Array()

func recipe(kind: String, response: String, policy: PackedInt32Array, family: String = "") -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(512, 512))
	data.response = response
	if family == "inertial_cellular_v1": data.rule_radius = 3
	var spawn := Vector2(256, 250)
	# Water first: later hard/powder stamps overwrite it, giving exact edges.
	for x: int in range(112, 404, 8):
		for y: int in range(352, 412, 8):
			data.edits.append([x, y, 8, WATER])
	match kind:
		"sandbed":
			for x: int in range(112, 404, 8):
				for y: int in range(376, 412, 8): data.edits.append([x, y, 8, SAND])
		"sandbank":
			for x: int in range(112, 216, 8):
				for y: int in range(330, 412, 8): data.edits.append([x, y, 8, SAND])
			spawn = Vector2(214, 300)
	# Hard basin: floor top at row 410, walls inside x 108..404.
	for x: int in range(96, 420, 12): data.edits.append([x, 430, 20, WALL])
	for y: int in range(240, 431, 12):
		data.edits.append([92, y, 16, WALL])
		data.edits.append([420, y, 16, WALL])
	# Clear the air column above the surface (stamps overlap upward).
	for x: int in range(112, 404, 8):
		for y: int in range(320, SURFACE - 8, 8): data.edits.append([x, y, 8, 0])
	data.actors = [Setup.instance(Setup.BARREL, 1, spawn)]
	data.selected = 0
	data.next_id = 2
	return data

func install(data: Dictionary) -> bool:
	if not host.paused: ui.toggle_pause()
	var epoch: int = host._physical_epoch
	if not ui.apply(data):
		fail("recipe refused: " + str(ui.message))
		return false
	var adopted: bool = await wait_for(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch > epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready)
	if not adopted: fail("adoption: " + str(host.microscenario_error))
	return adopted

func water_census() -> Dictionary:
	var img: Image = host.image
	var channels: int = 2 if img.get_format() == Image.FORMAT_RG8 else 1
	var data: PackedByteArray = img.get_region(ROI).get_data()
	var total := 0
	var spray := 0
	var top := ROI.position.y + ROI.size.y
	for row: int in range(ROI.size.y):
		var base := row * ROI.size.x * channels
		var count := 0
		for col: int in range(ROI.size.x):
			if data[base + col * channels] == WATER: count += 1
		if count == 0: continue
		var y := ROI.position.y + row
		total += count
		if y < SURFACE - 4: spray += count
		top = mini(top, y)
	return {"water_pixels": total, "spray_pixels": spray, "top_row": top}

func run_case(kind: String, response: String, family: String, policy: PackedInt32Array) -> void:
	if not await install(recipe(kind, response, policy, family)): return
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var trace := []
	var peak := {"spray_pixels": 0, "rows_above": 0, "displaced": 0, "unresolved_peak": 0, "events": 0.0,
		"arrivals": 0, "normal": 0.0, "max_speed": 0.0}
	if not ui.toggle_pause():
		fail("unpause " + kind)
		return
	var first: int = session.tick
	var until := Time.get_ticks_msec() + WATCHDOG_MS
	var observed := -1
	var initial := water_census()
	while session.tick < first + ticks and Time.get_ticks_msec() < until and not host.simulation_worker.has_failed():
		await process_frame
		if session.tick == observed: continue
		observed = session.tick
		var state: Dictionary = session.workbench_actor_state(1)
		var packet: Dictionary = host.tower_context.get("workbench_gcr", {})
		var row: Dictionary = {}
		for r: Dictionary in packet.get("rows", []):
			if int(r.get("instance_id", -1)) == 1: row = r
		var sample := {"t": session.tick - first, "x": state.position.x, "y": state.position.y,
			"r": state.rotation, "vx": state.linear_velocity.x, "vy": state.linear_velocity.y,
			"w": state.angular_velocity}
		if not row.is_empty():
			sample.merge({"ix": Vector2(row.impulse).x, "iy": Vector2(row.impulse).y,
				"ev": Vector2(row.event_accepted).length(), "arr": int(row.arrival_count),
				"nrm": float(row.normal_accepted), "dsp": int(row.displaced), "unr": int(row.unresolved),
				"con": int(row.contacts)})
			peak.displaced += int(row.displaced)
			peak.unresolved_peak = maxi(peak.unresolved_peak, int(row.unresolved))
			peak.events += Vector2(row.event_accepted).length()
			peak.arrivals += int(row.arrival_count)
			peak.normal += float(row.normal_accepted)
		if (session.tick - first) % 3 == 0:
			var census := water_census()
			sample.merge(census)
			peak.spray_pixels = maxi(peak.spray_pixels, census.spray_pixels)
			peak.rows_above = maxi(peak.rows_above, SURFACE - census.top_row)
		peak.max_speed = maxf(peak.max_speed, state.linear_velocity.length())
		trace.append(sample)
	ui.toggle_pause()
	var final_census := water_census()
	var end: Dictionary = trace.back() if not trace.is_empty() else {}
	rows.append({"scene": kind, "response": response, "family": family, "ticks": session.tick - first,
		"initial": initial, "final": final_census, "peak": peak, "end": end, "trace": trace})
	print("WCX001 ", kind, " ", family, " ", response, " ticks=", session.tick - first, " end_y=",
		end.get("y", -1), " displaced=", peak.displaced, " spray=", peak.spray_pixels, " rows_above=", peak.rows_above,
		" events=", snappedf(peak.events, 0.001), " arrivals=", peak.arrivals)

func run() -> void:
	parse_args()
	set_meta("cybersand_feature", "shared_workbench")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	var opened: bool = await wait_for(func() -> bool:
		return host.shared_workbench != null and not host.shared_workbench.applied.is_empty())
	if not opened:
		fail("open default workbench: " + str(host.microscenario_error))
	else:
		ui = host.shared_workbench
		for family: String in families:
			var policy := water_policy(bridge, family)
			if policy.is_empty():
				fail("family unavailable: " + family)
				continue
			for kind: String in scenes:
				for response: String in responses:
					await run_case(kind, response, family, policy)
	host.queue_free()
	await process_frame
	var record := {"experiment": "WCX-001 LA x Water matched impacts", "ticks": ticks, "surface_row": SURFACE,
		"roi": [ROI.position.x, ROI.position.y, ROI.size.x, ROI.size.y], "failures": failures, "rows": rows}
	if not out_path.is_empty():
		var handle := FileAccess.open(out_path, FileAccess.WRITE)
		if handle != null: handle.store_string(JSON.stringify(record))
	print("WCX001_DONE failures=", failures.size(), " rows=", rows.size())
	quit(int(not failures.is_empty()))
