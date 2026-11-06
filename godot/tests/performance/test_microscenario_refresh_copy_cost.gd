extends SceneTree

# INV-004 source-level cost discrimination, NOT a gameplay benchmark or a
# production optimization. The two arms simulate (A) the current workbench
# deep-copy-on-refresh and (B) a hypothetical once-per-owner-snapshot copy.
# Scenario contents are synthetic; source/runtime provenance and timings must
# be supplied by the host running this script.
#
# Run with Godot 4.7:
#   godot --headless --path godot --script res://tests/performance/test_microscenario_refresh_copy_cost.gd
#
# Interpret ONLY the cost of this dictionary-copy loop; these measurements do
# not imply any FPS speedup or permission to cache mutable owner state.

const FRAME_COUNT: int = 800
const CASE_REPETITIONS: int = 3
const OBSERVATION_COUNTS: Array[int] = [0, 64, 256]
const SNAPSHOT_STRIDES: Array[int] = [1, 4]


func _init() -> void:
	call_deferred("_run")


func _make_context(observation_count: int) -> Dictionary:
	var observations: Array = []
	for index: int in range(observation_count):
		observations.append({
			"id": "fixture-%d" % index,
			"metric": "observed",
			"value": {
				"material": index % 132,
				"state_a": (index * 3) % 256,
				"state_b": (index * 7) % 256,
				"temperature_raw": (index * 23) % 65536,
			},
			"trace": ["source", "eligible", "selected", "applied"],
		})
	return {
		"micro_active": true,
		"microscenario": {
			"schema_version": 2,
			"definition_hash": "synthetic-inv154",
			"completed_tick": 0,
			"status": {"owner_epoch": 0, "ready": true},
			"presentation": {"instructions": "synthetic", "regions": []},
			"observations": observations,
		},
	}


func _measure(arm: String, observation_count: int, stride: int) -> Dictionary:
	var context: Dictionary = _make_context(observation_count)
	var retained: Dictionary = {}
	var clone_count: int = 0
	var digest: int = 0
	var started_usec: int = Time.get_ticks_usec()
	for frame: int in range(FRAME_COUNT):
		# The synthetic owner publishes on every 'stride' frames; no in-place
		# mutations are made between these declared publication boundaries.
		if frame % stride == 0:
			var tick: int = int(frame / stride)
			context["microscenario"]["completed_tick"] = tick
			context["microscenario"]["status"]["owner_epoch"] = tick
		if arm == "current_every_frame" or frame % stride == 0:
			retained = context.get("microscenario", {}).duplicate(true)
			clone_count += 1
		# Consume the resulting copy on EVERY rendered frame. Both arms must
		# yield identical values or the experiment refuses to report parity.
		digest += int(retained.get("completed_tick", -1)) * (frame % 7 + 1)
		digest += int(retained.get("status", {}).get("owner_epoch", -1))
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	return {
		"arm": arm,
		"observations": observation_count,
		"frames": FRAME_COUNT,
		"snapshot_stride": stride,
		"clones": clone_count,
		"elapsed_usec": elapsed_usec,
		"digest": digest,
	}


func _run() -> void:
	var results: Array = []
	var failures: int = 0
	# Alternating orders reduce monotonic warm-up and background-load bias.
	# Each row is still a synthetic CPU microbenchmark, not a Windows GUI trial.
	for observation_count: int in OBSERVATION_COUNTS:
		for stride: int in SNAPSHOT_STRIDES:
			for repeat: int in range(CASE_REPETITIONS):
				var order: Array[String] = ["current_every_frame", "copy_on_snapshot"]
				if repeat % 2 == 1:
					order.reverse()
				var rows: Dictionary = {}
				for arm: String in order:
					var result: Dictionary = _measure(arm, observation_count, stride)
					result["repeat"] = repeat
					results.append(result)
					rows[arm] = result
				if int(rows["current_every_frame"]["digest"]) != int(rows["copy_on_snapshot"]["digest"]):
					failures += 1
					push_error("INV154 copy probe: readback digest diverged at %d observations, stride %d, repeat %d" % [
						observation_count, stride, repeat
					])
				if int(rows["current_every_frame"]["clones"]) != FRAME_COUNT:
					failures += 1
					push_error("INV154 copy probe: current arm did not clone per frame")
				if int(rows["copy_on_snapshot"]["clones"]) != int(ceili(float(FRAME_COUNT) / float(stride))):
					failures += 1
					push_error("INV154 copy probe: candidate arm clone count differs from synthetic publication contract")

	print("INV154_MICROSCENARIO_COPY_PROBE " + JSON.stringify({
		"schema": "inv154-microscenario-copy-probe-v1",
		"scope": "synthetic-dictionary-copy-only;not-real-frame-rate;not-production-admission",
		"godot_version": Engine.get_version_info(),
		"os_name": OS.get_name(),
		"frame_count": FRAME_COUNT,
		"repetitions": CASE_REPETITIONS,
		"cases": results,
		"failures": failures,
	}, "", false))
	quit(1 if failures > 0 else 0)
