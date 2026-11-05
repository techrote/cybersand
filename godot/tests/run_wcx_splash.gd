extends SceneTree

# WCX-002: graphical/numerical splash characterization on the workbench host.
# Paired rows differ only in the experimental spray controls (control: ballistic
# World with spray disabled). Records body motion, native parcel telemetry,
# displayed Water and the conservation ledger; optional PNG frames when the
# process renders (not --headless).
#
# Usage: godot [--headless] --path godot --script res://tests/run_wcx_splash.gd --
#        [--out <json>] [--frames <dir>] [--ticks N] [--scenes drop,flyer,jet,roof,repeat]
#        [--families freemass_v1,...] [--launch 1.6] [--threshold 0.3] [--bias 0.72]

const Setup = preload("res://scripts/workbench_setup.gd")
const WATCHDOG_MS := 180000
const WATER := 3
const SAND := 2
const WALL := 58
const SURFACE := 344

var host: Control
var ui: Control
var rows: Array = []
var failures: Array[String] = []
var ticks := 260
var scenes := ["drop", "jet", "roof"]
var families := ["freemass_v1"]
var out_path := ""
var frames_dir := ""
var spray := {"enabled": true, "launch_scale": 1.6, "threshold": 0.3, "upward_bias": 0.72}

func _initialize() -> void:
	run.call_deferred()

func fail(reason: String) -> void:
	failures.append(reason)
	push_error("WCX002: " + reason)

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
			"--frames": frames_dir = args[i + 1]
			"--ticks": ticks = int(args[i + 1])
			"--scenes": scenes = Array(args[i + 1].split(","))
			"--families": families = Array(args[i + 1].split(","))
			"--launch": spray.launch_scale = float(args[i + 1])
			"--threshold": spray.threshold = float(args[i + 1])
			"--bias": spray.upward_bias = float(args[i + 1])
		i += 2

func water_policy(bridge: Variant, family: String) -> PackedInt32Array:
	var request: PackedInt32Array = bridge.default_liquid_policy()
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(request, WATER):
		if str(choice.get("family", "")) == family and str(choice.get("variant", "")) == "reference" and choice.get("accepted", false):
			return choice.request
	return PackedInt32Array()

func recipe(kind: String, policy: PackedInt32Array, family: String) -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(512, 512))
	if family == "inertial_cellular_v1": data.rule_radius = 3
	for x: int in range(112, 404, 8):
		for y: int in range(352, 412, 8):
			data.edits.append([x, y, 8, WATER])
	for x: int in range(96, 420, 12): data.edits.append([x, 430, 20, WALL])
	for y: int in range(120, 431, 12):
		data.edits.append([92, y, 16, WALL])
		data.edits.append([420, y, 16, WALL])
	for x: int in range(112, 404, 8):
		for y: int in range(320, SURFACE - 8, 8): data.edits.append([x, y, 8, 0])
	if kind == "roof":
		for x: int in range(150, 362, 12): data.edits.append([x, 268, 6, WALL])
	if kind == "sandbank":
		for x: int in range(112, 216, 8):
			for y: int in range(330, 412, 8): data.edits.append([x, y, 8, SAND])
	data.selected = 0
	data.next_id = 2
	if kind in ["drop", "roof", "repeat"]:
		data.actors = [Setup.instance(Setup.BARREL, 1, Vector2(256, 236 if kind != "roof" else 286))]
	elif kind == "sandbank":
		data.actors = [Setup.instance(Setup.BARREL, 1, Vector2(214, 300))]
	elif kind == "flyer":
		data.actors = [Setup.instance("kestrel", 1, Vector2(256, 230))]
	elif kind == "multi":
		# Staggered heights: four independent bodies strike one native World in turn.
		data.actors = []
		var spots := [[170, 300], [230, 250], [290, 190], [350, 130]]
		for i: int in range(spots.size()):
			data.actors.append(Setup.instance(Setup.BARREL, i + 1, Vector2(spots[i][0], spots[i][1])))
		data.next_id = spots.size() + 1
	else:
		# The physical session needs a body: park the barrel on a shelf outside the basin.
		data.edits.append([40, 490, 10, WALL])
		data.actors = [Setup.instance(Setup.BARREL, 1, Vector2(40, 470))]
	return data

func install(data: Dictionary, ballistic: bool) -> bool:
	if not host.paused: ui.toggle_pause()
	host.workbench_water_options = {"workbench_ballistic": ballistic}
	var epoch: int = host._physical_epoch
	if not ui.apply(data):
		fail("recipe refused: " + str(ui.message))
		return false
	var adopted: bool = await wait_for(func() -> bool:
		return host.pending_microscenario_apply.is_empty() and host._physical_epoch > epoch \
			and host.physical_actor_session != null and host._physical_terrain_ready)
	if not adopted: fail("adoption: " + str(host.microscenario_error))
	return adopted

func water_pixels() -> int:
	var img: Image = host.image
	var channels: int = 2 if img.get_format() == Image.FORMAT_RG8 else 1
	var data: PackedByteArray = img.get_region(Rect2i(100, 100, 313, 312)).get_data()
	var total := 0
	for i: int in range(0, data.size(), channels):
		if data[i] == WATER: total += 1
	return total

func capture(name: String) -> void:
	if frames_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	if shot != null: shot.save_png(frames_dir.path_join(name + ".png"))

func run_case(kind: String, family: String, policy: PackedInt32Array, enabled: bool) -> void:
	if not await install(recipe(kind, policy, family), true): return
	# Frame the basin, its splash band and the jet apex (16:9).
	ui._set_view(Vector2(88, 228), Vector2i(352, 198))
	var worker = host.simulation_worker
	var settings := spray.duplicate()
	settings.enabled = enabled and kind != "jet"
	if kind == "jet":
		settings.merge({"jet_enabled": enabled, "jet_origin": Vector2i(200, 343), "jet_angle": -62.0,
			"jet_speed": 3.4, "jet_rate": 3, "jet_quantity": 96}, true)
	if not worker.queue_water_spray(settings):
		fail("spray request queue refused")
		return
	if not ui.toggle_pause():
		fail("unpause " + kind)
		return
	var session: CyberPhysicalActorSession = host.physical_actor_session
	var first: int = int(host.latest_snapshot.tick_index) if host.latest_snapshot != null else 0
	var trace := []
	var peak := {"live": 0, "in_flight": 0, "top_row": 1e9, "rows_above": 0.0, "width": 0.0, "airborne_ticks": 0,
		"peak_speed": 0.0, "launched": 0, "deposited": 0, "refused": 0, "ledger_breaks": 0,
		"max_total": -1, "min_total": 1 << 62}
	var until := Time.get_ticks_msec() + WATCHDOG_MS
	var observed := -1
	var initial_pixels := water_pixels()
	var captured := {}
	while Time.get_ticks_msec() < until and not host.simulation_worker.has_failed():
		await process_frame
		var snap: CyberSimulationSnapshot = host.latest_snapshot
		if snap == null: continue
		var t: int = int(snap.tick_index) - first
		if t >= ticks: break
		if t == observed: continue
		observed = t
		var context: Dictionary = host.tower_context
		var state: Dictionary = session.workbench_actor_state(1)
		var w: Dictionary = context.get("water_spray", {})
		var parcels: Dictionary = w.get("parcels", {})
		var sample := {"t": t, "live": int(w.get("live", 0)), "in_flight": int(w.get("in_flight_quantity", 0)),
			"tick_ms": float(w.get("native_tick_ms", 0.0))}
		var water: Dictionary = w.get("water", {})
		if not water.is_empty():
			sample.total = int(water.total)
			if int(water.total) != int(water.expected):
				peak.ledger_breaks += 1
			peak.max_total = maxi(peak.max_total, int(water.total))
			peak.min_total = mini(peak.min_total, int(water.total))
		if not state.is_empty():
			sample.merge({"y": state.position.y, "vy": state.linear_velocity.y, "x": state.position.x})
		if not parcels.is_empty():
			sample.merge({"top": float(parcels.top_row), "left": float(parcels.left), "right": float(parcels.right),
				"speed": float(parcels.peak_speed), "rising": int(parcels.rising)})
			peak.top_row = minf(peak.top_row, float(parcels.top_row))
			peak.rows_above = maxf(peak.rows_above, SURFACE - float(parcels.top_row))
			peak.width = maxf(peak.width, float(parcels.right) - float(parcels.left))
			peak.peak_speed = maxf(peak.peak_speed, float(parcels.peak_speed))
		if sample.live > 0: peak.airborne_ticks += 1
		peak.live = maxi(peak.live, sample.live)
		peak.in_flight = maxi(peak.in_flight, sample.in_flight)
		var ledger: Dictionary = w.get("ledger", {})
		peak.launched = int(ledger.get("launched_parcels", 0)) + int(ledger.get("injected_parcels", 0))
		peak.deposited = int(ledger.get("deposited_parcels", 0))
		peak.refused = int(ledger.get("refused_launches", 0))
		if t % 4 == 0: sample.pixels = water_pixels()
		trace.append(sample)
		if not frames_dir.is_empty() and t % 6 == 0 and not captured.has(t) and t >= 70 and t <= 190:
			captured[t] = true
			await capture("%s-%s-%s-t%03d" % [kind, family.trim_suffix("_v1"), "spray" if enabled else "control", t])
	ui.toggle_pause()
	# Let in-flight Water return, then compare the displayed inventory.
	var final_spray: Dictionary = host.tower_context.get("water_spray", {})
	rows.append({"scene": kind, "family": family, "spray": enabled, "ticks": observed, "settings": settings,
		"initial_pixels": initial_pixels, "final_pixels": water_pixels(), "peak": peak,
		"final_live": int(final_spray.get("live", -1)), "final_in_flight": int(final_spray.get("in_flight_quantity", -1)),
		"ledger": final_spray.get("ledger", {}), "totals": final_spray.get("totals", {}),
		"receipt": final_spray.get("receipt", {}), "trace": trace})
	var times := []
	for sample: Dictionary in trace: times.append(float(sample.get("tick_ms", 0.0)))
	times.sort()
	var p50: float = times[times.size() / 2] if not times.is_empty() else 0.0
	var p95: float = times[int(times.size() * 0.95)] if not times.is_empty() else 0.0
	rows.back()["tick_ms_p50"] = p50
	rows.back()["tick_ms_p95"] = p95
	print("WCX002 ", kind, " ", family, " spray=", enabled, " ticks=", observed, " launched=", peak.launched,
		" ledger_breaks=", peak.ledger_breaks, " total[", peak.min_total, ",", peak.max_total, "]",
		" tick_ms p50=", snappedf(p50, 0.001), " p95=", snappedf(p95, 0.001),
		" peak_live=", peak.live, " rows_above=", snappedf(peak.rows_above, 0.1), " width=", snappedf(peak.width, 0.1),
		" airborne=", peak.airborne_ticks, " peak_speed=", snappedf(peak.peak_speed, 0.01), " deposited=", peak.deposited,
		" refused=", peak.refused, " pixels ", initial_pixels, "->", water_pixels())

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
		if not frames_dir.is_empty(): DirAccess.make_dir_recursive_absolute(frames_dir)
		for family: String in families:
			var policy := water_policy(bridge, family)
			if policy.is_empty():
				fail("family unavailable: " + family)
				continue
			for kind: String in scenes:
				await run_case(kind, family, policy, false)
				await run_case(kind, family, policy, true)
	host.queue_free()
	await process_frame
	var record := {"experiment": "WCX-002 ballistic splash characterization", "ticks": ticks, "surface_row": SURFACE,
		"spray": spray, "failures": failures, "rows": rows}
	if not out_path.is_empty():
		var handle := FileAccess.open(out_path, FileAccess.WRITE)
		if handle != null: handle.store_string(JSON.stringify(record))
	print("WCX002_DONE failures=", failures.size(), " rows=", rows.size())
	quit(int(not failures.is_empty()))
