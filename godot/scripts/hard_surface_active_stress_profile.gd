extends SceneTree

# HS-PKT A/B/B/A active-workbench load; replayed unchanged on both source arms.
# Runs the production Main -> CyberSimulationWorker -> native GDExtension ->
# Rapier path. Does not call a synthetic World or substitute packet hashes.
const Setup = preload("res://scripts/workbench_setup.gd")
const Watchdogs = preload("res://tests/support/ci_execution_policy.gd")

const WARMUP_TICKS := 24
const SAMPLE_TICKS := 240
const EDIT_EVERY_TICKS := 2
const MIN_PACKET_SAMPLES := 40
const MIN_OBSERVED_HARD_REVISIONS := 35
const MIN_ACCEPTED_EDITS := 45
const POLICY_FAMILY := "pressure_flow_v1"
const POLICY_VARIANT := "cached_dormant"

var main: Control
var panel
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _require(ok: bool, reason: String) -> bool:
	if ok:
		return true
	failures.append(reason)
	push_error("HS_ACTIVE_PROFILE: " + reason)
	return false


func _until(predicate: Callable, reason: String) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + Watchdogs.milliseconds("complex_fixture_seconds")
	while not predicate.call() and Time.get_ticks_msec() < deadline_ms:
		await process_frame
	return _require(bool(predicate.call()), "timeout: " + reason + "; " + main.microscenario_error)


func _installed() -> bool:
	return (
		panel != null and not panel.applied.is_empty()
		and not panel.busy()
		and main.pending_microscenario_apply.is_empty()
	)


func _pressure_policy() -> Dictionary:
	var bridge: Variant = panel._liquids.bridge
	if bridge == null:
		return {"error": "native liquid policy bridge unavailable"}
	var base: PackedInt32Array = bridge.default_liquid_policy()
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(base, Setup.WATER):
		if str(choice.get("family", "")) != POLICY_FAMILY:
			continue
		if str(choice.get("variant", "")) != POLICY_VARIANT:
			continue
		if not bool(choice.get("accepted", false)):
			return {"error": "PressureFlow cached_dormant refused: " + str(choice.get("refusal", {}))}
		var gas: Dictionary = bridge.liquid_policy_with_pressure_gas(
			PackedInt32Array(choice.request), true
		)
		if not bool(gas.get("accepted", false)):
			return {"error": "PressureFlow gas refused: " + str(gas.get("refusal", {}))}
		var proposed: PackedInt32Array = PackedInt32Array(gas.request)
		var validated: Dictionary = bridge.validate_liquid_policy(proposed)
		if not bool(validated.get("accepted", false)):
			return {"error": "PressureFlow gas policy validation failed: " + str(validated)}
		return {"policy": proposed, "validation": validated}
	return {"error": "PressureFlow cached_dormant is unavailable in this runtime"}


func _anchors(label: String) -> Array[Vector2i]:
	if label == Setup.DEFAULT_LABEL:
		return [
			Vector2i(48, 72), Vector2i(112, 72), Vector2i(176, 72),
			Vector2i(240, 72), Vector2i(304, 72), Vector2i(368, 72),
			Vector2i(432, 72), Vector2i(480, 72)
		]
	return [
		Vector2i(64, 90), Vector2i(256, 90), Vector2i(448, 90),
		Vector2i(640, 90), Vector2i(832, 90), Vector2i(1024, 90),
		Vector2i(1216, 90), Vector2i(1408, 90), Vector2i(1600, 90),
		Vector2i(1792, 90), Vector2i(1984, 90),
		Vector2i(192, 570), Vector2i(576, 570), Vector2i(960, 570),
		Vector2i(1344, 570), Vector2i(1728, 570)
	]


func _percentiles(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"samples": 0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var n: int = sorted.size()
	return {
		"samples": n,
		"mean_ms": total / float(n),
		"p50_ms": sorted[int((n - 1) * 0.50)],
		"p95_ms": sorted[int((n - 1) * 0.95)],
		"max_ms": sorted[n - 1]
	}


func _applied_pressure() -> Dictionary:
	var policy: Dictionary = main.tower_context.get("liquid_solver_policy", {})
	var water: Dictionary = {}
	for item: Dictionary in policy.get("assignments", []):
		if int(item.get("material", -1)) == Setup.WATER:
			water = item
			break
	var parameters: Dictionary = policy.get("family_parameters", {})
	var pressure: Dictionary = parameters.get("pressure_flow_v1", {})
	return {
		"family": str(water.get("applied_family", "")),
		"variant": str(water.get("applied_variant", "")),
		"gas_enabled": bool(pressure.get("gas_enabled", false)),
		"policy_hash": str(policy.get("policy_hash", "")),
		"session_generation": int(policy.get("session_generation", -1)),
		"parameters": pressure
	}


func _native_path() -> String:
	return "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"


func _run_canvas(label: String, policy: PackedInt32Array) -> bool:
	var candidate: Dictionary = Setup.builtin(label, policy)
	candidate.liquid_policy = Array(policy)
	# Both arms use the same built-in live-body fixture, PF gas topology and
	# experimental native ballistic face-release. Refuse unverified settings.
	main.workbench_water_options["workbench_ballistic"] = true
	main.workbench_water_options["workbench_face_release"] = true
	main.workbench_water_options["workbench_face_speed"] = 288
	main.workbench_water_options["workbench_face_period"] = 1
	main.workbench_water_options["workbench_face_min_height"] = 4

	if not _require(panel.apply(candidate), "workbench apply failed: " + label + " " + main.microscenario_error):
		return false
	if not await _until(_installed, label + " application"):
		return false
	if not await _until(func() -> bool: return bool(
		main.tower_context.get("water_spray", {}).get("ballistic_enabled", false)
	), label + " native ballistic readback"):
		return false

	var p: Dictionary = _applied_pressure()
	if not _require(
		p.family == POLICY_FAMILY and p.variant == POLICY_VARIANT and p.gas_enabled,
		"applied Water PF cached_dormant with gas is not verified: " + JSON.stringify(p)
	):
		return false
	var extent: Vector2i = Setup.extent_of(candidate)
	var spray_origin: Vector2i = Vector2i(int(extent.x / 2), int(extent.y * 0.55))
	var settings: Dictionary = {
		"enabled": true,
		"jet_enabled": true,
		"jet_origin": spray_origin
	}
	if not _require(
		panel.water_spray.request(settings),
		"native Water spray/jet request refused: " + label
	):
		return false
	if not _require(
		main.physical_actor_session != null and candidate.actors.size() >= 2,
		"real Rapier actor session missing for " + label
	):
		return false

	var actor_tick_start: int = int(main.physical_actor_session.tick)
	var from_tick: int = int(main.latest_snapshot.tick_index)
	var after_tick: int = from_tick + WARMUP_TICKS + SAMPLE_TICKS
	var next_edit_tick: int = from_tick + WARMUP_TICKS
	var anchors: Array[Vector2i] = _anchors(label)
	var requests: int = 0
	var edits_accepted: int = 0
	var distinct_hard_revisions: int = 0
	var last_hard_revision: int = -1
	var last_serial: int = -1
	var observed_snapshots: int = 0
	var observed_actor_samples: int = 0
	var packet: Array[float] = []
	var simulation: Array[float] = []
	var render: Array[float] = []
	var publication: Array[float] = []
	var wall_started_us: int = Time.get_ticks_usec()
	var run_deadline_ms: int = Time.get_ticks_msec() + Watchdogs.milliseconds("complex_fixture_seconds")

	if not _require(panel.toggle_pause(), "failed to start actual workbench play"):
		return false

	while int(main.latest_snapshot.tick_index) < after_tick:
		await process_frame
		if main.simulation_worker.has_failed():
			_require(false, "native worker failed on " + label + ": " + str(main.latest_snapshot.last_tick_error))
			break
		if Time.get_ticks_msec() >= run_deadline_ms:
			_require(false, "bounded active-run deadline expired on " + label)
			break
		var snapshot: CyberSimulationSnapshot = main.latest_snapshot
		if snapshot == null or snapshot.serial == last_serial:
			continue
		last_serial = snapshot.serial
		if snapshot.tick_index < from_tick + WARMUP_TICKS:
			continue
		observed_snapshots += 1
		simulation.append(snapshot.simulation_time_ms)
		if snapshot.render_exchange_time_ms > 0.0:
			render.append(snapshot.render_exchange_time_ms)
		if snapshot.hard_surface_packet_time_ms > 0.0:
			packet.append(snapshot.hard_surface_packet_time_ms)
		publication.append(snapshot.snapshot_publication_time_ms)
		if snapshot.current_rigid_body_states.size() > 0:
			observed_actor_samples += 1
		var observed_hard: int = int(snapshot.lab_context.get(
			"workbench_hard_surface_revision", snapshot.hard_surface_revision
		))
		if last_hard_revision >= 0 and observed_hard != last_hard_revision:
			distinct_hard_revisions += 1
		last_hard_revision = observed_hard

		if snapshot.tick_index >= next_edit_tick:
			var anchor: Vector2i = anchors[requests % anchors.size()]
			# Each anchor is alternately written hard then erased. Global
			# parity would repeat the same material on the same anchor.
			var phase: int = int(requests / anchors.size()) % 2
			var material: int = CyberCellWorld.WALL if phase == 0 else CyberCellWorld.EMPTY
			if main.simulation_worker.queue_emit_disc(anchor.x, anchor.y, 3, material):
				edits_accepted += 1
			else:
				_require(false, "exclusive worker refused deterministic edit")
				break
			requests += 1
			next_edit_tick = snapshot.tick_index + EDIT_EVERY_TICKS

	if not main.paused:
		_require(panel.toggle_pause(), "failed to stop workbench play")
	var actor_tick_end: int = int(main.physical_actor_session.tick) if main.physical_actor_session != null else -1
	var spray: Dictionary = main.tower_context.get("water_spray", {})
	var ledger: Dictionary = spray.get("ledger", {})
	var applied_spray: Dictionary = spray.get("settings", {})
	var finish_pressure: Dictionary = _applied_pressure()
	var record: Dictionary = {
		"schema": "hs-pkt-active-workbench-v1",
		"source_sha": OS.get_environment("CYBERSAND_SOURCE_SHA"),
		"canvas": label,
		"extent": [extent.x, extent.y],
		"warmup_ticks": WARMUP_TICKS,
		"requested_sample_ticks": SAMPLE_TICKS,
		"observed_snapshots": observed_snapshots,
		"wall_ms": float(Time.get_ticks_usec() - wall_started_us) / 1000.0,
		"edit_requests": requests,
		"accepted_edit_requests": edits_accepted,
		"observed_hard_revision_changes": distinct_hard_revisions,
		"actors_requested": candidate.actors.size(),
		"actual_actor_steps": actor_tick_end - actor_tick_start,
		"observed_actor_samples": observed_actor_samples,
		"pressure": finish_pressure,
		"ballistic_enabled": bool(spray.get("ballistic_enabled", false)),
		"spray_enabled": bool(applied_spray.get("enabled", false)),
		"jet_enabled": bool(applied_spray.get("jet_enabled", false)),
		"ballistic_ledger": ledger,
		"packet": _percentiles(packet),
		"simulation": _percentiles(simulation),
		"render_exchange": _percentiles(render),
		"snapshot_publication": _percentiles(publication),
		"runtime": {
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"godot": Engine.get_version_info().string,
			"native_sha256": FileAccess.get_sha256(_native_path()),
			"rapier_sha256": FileAccess.get_sha256(
				"res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
			),
		}
	}
	print("HS_ACTIVE_PROFILE ", JSON.stringify(record))

	var ok: bool = true
	ok = _require(observed_snapshots >= 100, label + " did not sample enough actual worker frames") and ok
	ok = _require(edits_accepted >= MIN_ACCEPTED_EDITS, label + " insufficient accepted edits") and ok
	ok = _require(distinct_hard_revisions >= MIN_OBSERVED_HARD_REVISIONS,
		label + " hard mask did not actually change often enough") and ok
	ok = _require(packet.size() >= MIN_PACKET_SAMPLES,
		label + " collider packet sampling remained too sparse: " + str(packet.size())) and ok
	ok = _require(observed_actor_samples > 20 and actor_tick_end > actor_tick_start + 20,
		label + " real actor coupling did not advance") and ok
	ok = _require(finish_pressure.gas_enabled and finish_pressure.family == POLICY_FAMILY,
		label + " PressureFlow gas ceased to be enabled") and ok
	ok = _require(bool(spray.get("ballistic_enabled", false))
		and bool(applied_spray.get("enabled", false))
		and bool(applied_spray.get("jet_enabled", false)),
		label + " ballistic Water/impact spray/jet not actually enabled") and ok
	ok = _require(int(ledger.get("launched_parcels", 0)) + int(ledger.get("injected_parcels", 0)) > 0,
		label + " ballistic ledger has no actual live launch/injection") and ok
	return ok


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	main = current_scene
	panel = main.shared_workbench
	if not await _until(_installed, "initial workbench"):
		quit(1)
		return
	var resolved: Dictionary = _pressure_policy()
	if not _require(resolved.has("policy"), str(resolved.get("error", "no accepted pressure policy"))):
		quit(1)
		return
	var policy: PackedInt32Array = resolved.policy
	for label: String in [Setup.DEFAULT_LABEL, Setup.STRESS_LABEL]:
		if not await _run_canvas(label, policy):
			break
	if main != null:
		main.queue_free()
		await process_frame
		await process_frame
	if failures.is_empty():
		print("HS_ACTIVE_PROFILE_COMPLETE", " 2/2 workload canvases qualified")
	else:
		print("HS_ACTIVE_PROFILE_FAILURES ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
