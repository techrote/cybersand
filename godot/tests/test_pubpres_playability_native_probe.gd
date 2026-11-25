extends SceneTree

const PROBE := "cybersand/pubpres_wave_column_probe"
const RETIRED := "cybersand/experimental_wave_column_tiles"
var checks := 0
var failures: Array[String] = []
var saved_settings: Dictionary = {}
var observations: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("PUBPRES_NATIVE_PROBE: " + detail)
	return ok

func make_world() -> Variant:
	return ClassDB.instantiate(&"CyberNativeCellWorld")

func configure(world: Variant) -> bool:
	if not require(world.diagnostic_reset({"extent": Vector2i(128, 128),
			"workers": 4, "wave_flow": true, "wave_substeps": 2}), "native Wave construction"):
		return false
	world.set_simulation_window_enabled(false)
	for rect: Array in [[0, 0, 128, 1, 1], [0, 127, 128, 1, 1],
			[0, 0, 1, 128, 1], [127, 0, 1, 128, 1], [1, 80, 70, 47, 3]]:
		if not require(world.diagnostic_fill_rect(Vector2i(rect[0], rect[1]),
				Vector2i(rect[2], rect[3]), int(rect[4])), "closed native basin admitted"):
			return false
	return true

func refusal(setting: String, value: Variant, reason: String) -> void:
	ProjectSettings.set_setting(PROBE, false)
	ProjectSettings.set_setting(RETIRED, false)
	ProjectSettings.set_setting(setting, value)
	var world: Variant = make_world()
	require(world.has_failed() and str(world.get_last_tick_error()).contains(reason),
		"invalid/retired setting explicitly refuses native construction")
	require(not world.simulation_tick(), "refused native World cannot advance")
	var packet: Dictionary = world.take_render_snapshot(true)
	require(packet.get("failed", false) and packet.get("cells", PackedByteArray()).is_empty(),
		"refused native World cannot publish material")
	require(not world.get_wave_flow_status().get("healthy", true),
		"diagnostic read cannot turn failed initialization healthy")
	observations.append({"setting": setting, "type": typeof(value),
		"error": world.get_last_tick_error(), "failed": world.has_failed()})
	ProjectSettings.set_setting(PROBE, false)
	ProjectSettings.set_setting(RETIRED, false)
	require(world.diagnostic_reset({"extent": Vector2i(128, 128)}),
		"explicit fresh reset recovers failed initialization")
	require(world.diagnostic_fill_rect(Vector2i(16, 16), Vector2i.ONE, 3),
		"recovered authority accepts a real material edit")
	require(not world.has_failed() and world.simulation_tick(), "recovered authority really advances")
	var recovered: Dictionary = world.take_render_snapshot(true)
	require(not recovered.get("failed", false) and recovered.get("serial", 0) > 0
		and recovered.get("cells", PackedByteArray()).size() == 128 * 128 * 2,
		"recovered authority publishes complete native RG8, not an empty healthy packet")

func finish() -> void:
	for key: String in saved_settings:
		ProjectSettings.set_setting(key, saved_settings[key])
	var report := {"schema": "pubpres-native-probe-regression-v1", "checks": checks,
		"failures": failures, "complete": failures.is_empty(), "observations": observations,
		"source": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"engine": Engine.get_version_info().string}
	var output := OS.get_environment("CYBERSAND_PUBPRES_NATIVE_PROBE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			failures.append("Could not write regression receipt")
		else:
			file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PUBPRES_NATIVE_PROBE checks=%d failures=%d" % [checks, failures.size()])
	quit(int(not failures.is_empty()))

func run() -> void:
	for key: String in [PROBE, RETIRED]:
		saved_settings[key] = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null
		ProjectSettings.set_setting(key, null)
	if not require(ClassDB.class_exists(&"CyberNativeCellWorld"), "real native runtime loaded"):
		finish()
		return
	var plain: Variant = make_world()
	require(not plain.get_wave_flow_status().has("column_probe"), "probe absent by default")
	ProjectSettings.set_setting(PROBE, true)
	require(not plain.get_wave_flow_status().has("column_probe"), "existing World captures OFF once")
	var probed: Variant = make_world()
	ProjectSettings.set_setting(PROBE, false)
	require(probed.get_wave_flow_status().has("column_probe"), "existing World captures ON once")
	if not configure(plain) or not configure(probed):
		finish()
		return
	var first: Dictionary = probed.get_wave_flow_status().column_probe
	var expected_quantity: int = 70 * 47 * 255
	for tick: int in range(24):
		require(plain.simulation_tick() and probed.simulation_tick(), "real Wave progression")
		require(plain.get_physical_state_hash() == probed.get_physical_state_hash(),
			"probe leaves physical hash unchanged at tick %d" % tick)
		var status: Dictionary = probed.get_wave_flow_status()
		var probe: Dictionary = status.get("column_probe", {})
		require(probe.get("schema", "") == "PUBPRES-WAVE-COLUMNS-V1"
			and probe.get("experimental_column_tiles", true) == false
			and probe.get("column_slots", 0) == 1, "only reference columns admitted")
		require(int(probe.get("ticks", -1)) == int(status.ticks)
			and int(probe.get("storage_bytes", -1)) == int(status.storage_bytes),
			"probe counters identify the observed native World")
		require(status.water_quantity == plain.get_wave_flow_status().water_quantity,
			"probe preserves exact Water ledger")
		require(int(status.water_quantity) == expected_quantity, "closed basin conserves initial Water quantity")
		require(plain.take_render_snapshot(true).cells == probed.take_render_snapshot(true).cells,
			"probe preserves complete real native RG8 material plane")
	var latest: Dictionary = probed.get_wave_flow_status().column_probe
	for key: String in ["prepare_ns", "column_ns", "flux_ns", "apply_ns", "merge_ns", "launch_ns"]:
		require(first.has(key) and latest.has(key) and typeof(first.get(key)) == TYPE_INT
			and typeof(latest.get(key)) == TYPE_INT and int(first.get(key, -1)) >= 0
			and int(latest.get(key, -1)) >= 0, "present nonnegative integer counter " + key)
		require(int(latest.get(key, -1)) >= int(first.get(key, -1)), "existing cumulative counter " + key)
	require(first.ticks == 0 and int(latest.ticks) > 0, "retained readback remains immutable")
	latest.column_ns = -1
	require(int(probed.get_wave_flow_status().column_probe.column_ns) >= 0,
		"readback dictionary does not expose native mutable storage")
	observations.append({"physical_hash": probed.get_physical_state_hash(),
		"water_quantity": probed.get_wave_flow_status().water_quantity,
		"probe": probed.get_wave_flow_status().column_probe})
	refusal(RETIRED, true, "experiment is retired")
	refusal(RETIRED, "true", "must be boolean")
	refusal(PROBE, 1, "must be boolean")
	finish()
