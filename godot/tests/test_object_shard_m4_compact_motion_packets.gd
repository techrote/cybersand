extends SceneTree
# Value-only fail-closed transport proof; actual native/Godot motion remains
# under test_object_shard_m4_same_world_physical_chain.gd.
const Worker = preload("res://scripts/object_shard_native_worker.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
		push_error("M4_MOTION_PACKETS: " + why)

func _run() -> void:
	var applied: Dictionary = {"ok": true, "applied": true,
		"semantic_tick": 42, "accepted_pose_serials": [{"id": 9, "pose_serial": 13}]}
	verify(Worker._compact_motion_packet_eligible("motion",
		{"poses": [], "final_segment": false}, applied),
		"accepted intermediate applied-pose receipt may omit presentation")
	verify(not Worker._compact_motion_packet_eligible("motion",
		{"poses": [], "final_segment": true}, applied),
		"final motion requires full native presentation")
	verify(not Worker._compact_motion_packet_eligible("motion",
		{"poses": []}, applied),
		"legacy motion transport requires full native presentation")
	verify(not Worker._compact_motion_packet_eligible("tick",
		{"poses": [], "final_segment": false}, applied),
		"semantic tick never gets compacted")
	var refused: Dictionary = applied.duplicate(true)
	refused["ok"] = false
	verify(not Worker._compact_motion_packet_eligible("motion",
		{"poses": [], "final_segment": false}, refused),
		"rejected motion publishes full diagnostic frame")
	refused = applied.duplicate(true)
	refused["applied"] = false
	verify(not Worker._compact_motion_packet_eligible("motion",
		{"poses": [], "final_segment": false}, refused),
		"not-applied receipt must not be compacted")
	verify(Worker._typed_parameters("motion", {"poses": [],
		"final_segment": true}), "typed final marker admitted")
	verify(Worker._typed_parameters("motion", {"poses": [],
		"final_segment": false}), "typed intermediate marker admitted")
	verify(not Worker._typed_parameters("motion", {"poses": [],
		"final_segment": "false"}), "invalid final marker refused")
	print(JSON.stringify({"schema": "objectshard-m4-compact-motion-packet-v1",
		"checks": checks, "failures": failures,
		"scope": "presentation optimisation only; exact applied-pose acknowledgements remain mandatory"}))
	quit(0 if failures.is_empty() else 1)
