extends SceneTree

const WorkbenchBridge = preload("res://scripts/workbench_physics_bridge.gd")

# A diagnostic flag can be selected before the owner opens Workbench. Observing
# another legitimate physical owner must not assume Workbench-only identity.
class ObservedHost extends "res://scripts/main.gd":
	var observation: Dictionary = {}
	func _pubpres_transaction_observed(_event: String, evidence: Dictionary) -> void:
		observation = evidence

var failures: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var host := ObservedHost.new()
	host._pubpres_packet_observed("no_owner", Time.get_ticks_usec(), null, {})
	check(host.observation.get("current_session") == -1, "no physical owner has no Workbench session")
	var session := CyberPhysicalActorSession.new()
	session.epoch = 23
	host.physical_actor_session = session
	host._physical_epoch = 23
	# PhysicalSession's ordinary bridge is not the Workbench bridge subtype.
	check(not session.bridge is WorkbenchBridge, "fixture uses ordinary physical owner")
	host.observation.clear()
	host._pubpres_packet_observed("ordinary_owner", Time.get_ticks_usec(), null, {})
	check(not host.observation.is_empty(), "ordinary owner observation completed without script error")
	check(host.observation.get("current_session") == -1, "ordinary owner never fabricates Workbench authority")
	check(host.observation.get("current_epoch") == 23, "known epoch remains available")
	host.physical_actor_session = null
	session.free()
	host.free()
	print("PUBPRES causal host: ", failures, " failures")
	quit(1 if failures else 0)
