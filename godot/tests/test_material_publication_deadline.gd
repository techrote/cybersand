extends SceneTree

## Native-independent policy test. Synthetic clocks assert scheduling rules;
## these are not physical progression or wall-time performance observations.
const Deadline = preload("res://scripts/material_publication_deadline.gd")
var checks: int = 0
var failures: Array[String] = []

class Packet extends RefCounted:
	var render_world_generation: int = 42
	var render_snapshot_serial: int = 0
	var render_full_refresh: bool = false
	var simulation_failed: bool = false


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("MATERIAL_DEADLINE: " + detail)


func packet(serial: int, generation: int = 42, full: bool = false) -> Packet:
	var result := Packet.new()
	result.render_snapshot_serial = serial
	result.render_world_generation = generation
	result.render_full_refresh = full
	return result


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for value: String in ["", "0", "1", "29", "59", "120", "030", "off"]:
		check(Deadline.requested_hz(value) == 0, "unregistered selector stays off: " + value)
	check(Deadline.requested_hz("30") == 30 and Deadline.requested_hz("60") == 60,
		"only explicit registered rates are admitted")
	var policy = Deadline.new()
	var owner := [7, 11, 42]
	var first := packet(20, 42, true)
	check(not policy.enabled() and not policy.offer(first, owner, 100000, -1, 0),
		"default off retains no offer")
	check(policy.status().pending_count == 0 and not policy.status().physical_credit,
		"default has no queue or physical credit")
	check(not policy.configure(59) and not policy.enabled(), "invalid configuration does not activate")
	check(policy.configure(30) and policy.status().interval_usec == 33334, "30 Hz rounds interval up")
	check(policy.offer(first, owner, 100000, -1, 0), "initial full World offered")
	check(policy.take_due(owner, 99999) == null, "future offer not consumed early")
	check(policy.take_due(owner, 100000) == first, "initial full World bypasses delay")
	check(policy.complete(first, true, 100001), "accepted upload establishes deadline")
	check(not policy.complete(first, true, 100002), "duplicate completion gives no credit")
	check(policy.status().accepted_uploads == 1 and policy.status().next_upload_usec == 133335,
		"exact next admission clock")

	var second := packet(21)
	var third := packet(22)
	check(policy.offer(second, owner, 101000, 42, 20), "next cumulative offer retained")
	check(policy.status().deadline_usec == 133335, "first pending offer fixes deadline")
	check(policy.offer(third, owner, 120000, 42, 20), "newer cumulative offer replaces old")
	check(policy.status().pending_count == 1 and policy.status().pending_serial == 22,
		"replacement has one retained packet")
	check(policy.status().deadline_usec == 133335, "replacement never renews deadline")
	check(not policy.offer(second, owner, 121000, 42, 20), "stale packet cannot replace newest")
	check(policy.take_due(owner, 133334) == null, "one microsecond before deadline stays deferred")
	check(policy.take_due(owner, 133335) == third, "latest packet drains without another offer")
	check(policy.complete(third, true, 133340), "selected upload completes")
	check(policy.status().accepted_uploads == 2 and policy.status().replaced_offers == 1,
		"skipped offer is not an accepted upload")

	var fourth := packet(23)
	check(policy.offer(fourth, owner, 134000, 42, 22), "paused-World pending offer")
	check(policy.take_due(owner, 166674) == fourth, "paused offer drains at deadline without replacement")
	check(not policy.complete(fourth, false, 166674), "refused upload receives no acceptance")
	check(policy.status().pending_count == 0 and policy.status().next_upload_usec == -1,
		"refusal clears pending state and deadline")
	check(policy.status().accepted_uploads == 2, "refusal cannot increment accepted uploads")
	var recovery := packet(24, 42, true)
	check(policy.offer(recovery, owner, 166675, 42, 22), "same-World full recovery offered")
	check(policy.take_due(owner, 166675) == recovery, "recovery is not delayed by rejected upload")
	check(policy.complete(recovery, true, 166680), "recovery accepted")

	check(policy.offer(packet(25), owner, 166681, 42, 24), "offer before World replacement")
	var new_owner := [7, 11, 43]
	var replacement := packet(30, 43, true)
	check(policy.offer(replacement, new_owner, 167000, 42, 24), "same-size new World supersedes old offer")
	check(policy.status().deadline_usec == 167000 and policy.status().pending_generation == 43,
		"new World full frame bypasses old deadline")
	check(policy.take_due(new_owner, 167000) == replacement, "new World packet selected exactly")
	check(policy.complete(replacement, true, 167001), "new World accepted")
	check(policy.offer(packet(31, 43), new_owner, 167002, 43, 30), "new World partial offer")
	check(policy.take_due([8, 12, 43], 999999) == null, "retired session/epoch cannot drain")
	check(policy.status().pending_count == 0 and policy.status().last_cancel == "identity_retired",
		"owner replacement invalidates pending bytes")

	check(not policy.offer(packet(32, 44), [8, 12, 44], 200000, 43, 30),
		"new World delta without complete base refused")
	check(policy.status().last_cancel == "new_world_requires_full", "refusal reason is explicit")
	var failed := packet(33, 44, true)
	failed.simulation_failed = true
	check(not policy.offer(failed, [8, 12, 44], 200001, 43, 30), "failed native offer refused")
	check(policy.status().pending_count == 0, "failure leaves no deferred offer")
	check(not policy.offer(packet(34, 44, true), [8, 12, 43], 200002, 43, 30),
		"packet and authoritative World must agree")
	check(not policy.offer(packet(35, 44, true), [8, 12, 44], 0, 43, 30),
		"invalid scheduling clock cannot admit")
	check(policy.configure(60) and policy.status().interval_usec == 16667, "60 Hz interval")
	check(policy.offer(first, owner, 300000, 42, 19), "60 Hz first offer")
	check(policy.take_due(owner, 300000) == first and policy.complete(first, true, 300000),
		"60 Hz actual acceptance")
	check(policy.offer(second, owner, 300001, 42, 20) and policy.status().deadline_usec == 316667,
		"60 Hz fixed deadline")
	policy.cancel("teardown")
	check(policy.take_due(owner, 400000) == null and policy.status().pending_count == 0,
		"teardown never drains an old packet")
	check(policy.configure(0) and not policy.enabled(), "explicit off restores immediate caller policy")
	print("MATERIAL_DEADLINE_RESULT ", JSON.stringify({"schema":"pubpres-material-deadline-policy-v1",
		"complete":failures.is_empty(), "checks":checks, "failures":failures,
		"synthetic_clocks":true, "physical_credit":false,
		"policy_sha256":FileAccess.get_sha256("res://scripts/material_publication_deadline.gd")}))
	quit(int(not failures.is_empty()))
