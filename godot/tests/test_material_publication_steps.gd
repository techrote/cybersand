extends SceneTree

## Synthetic scheduling/authority boundaries only. These clocks and counters
## are explicit test inputs, never evidence of actual Rapier progression.
const Policy = preload("res://scripts/material_publication_steps.gd")
var checks: int = 0
var failures: Array[String] = []

class Packet extends RefCounted:
	var render_world_generation: int = 42
	var render_snapshot_serial: int = 0
	var render_full_refresh: bool = false
	var render_generated_usec: int = 99999
	var simulation_failed: bool = false


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("MATERIAL_STEPS: " + detail)


func packet(serial: int, generated: int = 99999, generation: int = 42, full: bool = false) -> Packet:
	var result := Packet.new()
	result.render_snapshot_serial = serial
	result.render_generated_usec = generated
	result.render_world_generation = generation
	result.render_full_refresh = full
	return result


func witness(step: int, completed: int = 99998, offset: int = 100) -> Dictionary:
	return {"session_step":step, "rapier_step":step + offset, "completed_usec":completed}


func accepted(policy: RefCounted, p: Packet, owner: Array, now: int, w: Dictionary,
		uploaded: int, force: String = "") -> void:
	check(policy.offer(p, owner, now, p.render_world_generation, uploaded), "cumulative offer " + str(p.render_snapshot_serial))
	check(policy.take_due(owner, w, now, force) == p, "exact chosen packet " + str(p.render_snapshot_serial))
	check(policy.complete(p, true, w, now), "actual acceptance " + str(p.render_snapshot_serial))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for value: String in ["", "0", "1", "3", "02", "30", "60", "off"]:
		check(Policy.requested_interval(value) == 0, "unregistered selector remains off: " + value)
	check(Policy.requested_interval("2") == 2, "only explicit count2 admitted")
	var policy = Policy.new()
	var owner := [7, 11, 42, -9001]
	check(not policy.enabled() and policy.status().pending_count == 0 \
		and not policy.status().physical_credit, "default has no retained bytes or physical credit")
	check(not policy.configure(1) and not policy.enabled(), "unsupported count refused")
	check(policy.configure(2, "material_deadline_selected") and not policy.enabled() \
		and policy.status().requested_interval == 2 and policy.status().effective_interval == 0,
		"conflicting time policy does not stack")
	check(policy.configure(2), "explicit count2 enabled")
	var first := packet(20, 99999, 42, true)
	accepted(policy, first, owner, 100000, witness(10), 19)
	check(policy.status().anchor_session_step == 10 and policy.status().anchor_rapier_step == 110,
		"actual upload anchors fixed nonzero counter offset")
	check(not policy.complete(first, true, witness(11), 100001), "repeated completion cannot move anchor")

	var second := packet(21, 100001)
	check(policy.offer(second, owner, 100002, 42, 20), "first held material offer")
	check(policy.take_due(owner, witness(11), 100002) == null, "one real completion does not meet interval")
	var first_deadline: int = 100002 + Policy.ADDED_HOLD_USEC
	check(policy.status().first_offer_usec == 100002 and policy.status().deadline_usec == first_deadline,
		"first offer fixes scheduled hold deadline")
	var replacement := packet(24, 100003)
	check(policy.offer(replacement, owner, 100004, 42, 20), "latest cumulative offer replaces held predecessor")
	check(policy.status().pending_count == 1 and policy.status().pending_serial == 24 \
		and policy.status().deadline_usec == first_deadline and policy.status().anchor_session_step == 10,
		"replacement extends neither deadline nor accepted-step anchor")
	check(not policy.offer(second, owner, 100005, 42, 20), "older serial cannot replace latest")
	check(policy.take_due(owner, witness(12), 100006) == replacement, "two real completions release before clock deadline")
	check(policy.complete(replacement, true, witness(12), 100006), "chosen cumulative upload accepted")
	check(policy.status().accepted_uploads == 2 and policy.status().replaced_offers == 1 \
		and policy.status().last_consumption_reason == "completed_step_interval",
		"superseded material gets no upload credit")

	var stalled := packet(25, 100007)
	check(policy.offer(stalled, owner, 100008, 42, 24), "offer before stalled Main interval")
	check(policy.take_due(owner, witness(12), 100008 + Policy.ADDED_HOLD_USEC - 1) == null,
		"zero completions stay held until scheduled deadline")
	check(policy.take_due(owner, witness(12), 400008) == stalled, "expired material drains at next Main opportunity without any step")
	check(policy.status().last_hold_usec == 300000 \
		and policy.status().last_deadline_overrun_usec == 300000 - Policy.ADDED_HOLD_USEC,
		"late Main exposes actual hold and deadline overrun")
	check(policy.complete(stalled, true, witness(12), 400008), "expired material still requires actual accepted upload")
	check(policy.status().anchor_session_step == 12, "timer expiration creates no step")

	var old := packet(26, 1)
	check(policy.offer(old, owner, 1200000, 42, 25), "already-old packet offered")
	check(policy.take_due(owner, witness(12), 1200000) == old, "already-old source receives no fresh hold budget")
	check(policy.complete(old, true, witness(12), 1200000), "old upload acceptance remains real")
	var future := packet(27, 2000000)
	check(policy.offer(future, owner, 1200001, 42, 26), "future source clock can use original transaction validation")
	check(policy.take_due(owner, witness(12), 1200001) == future, "future clock grants no delay")
	check(policy.complete(future, true, witness(12), 1200001), "policy does not replace original upload validity")

	# One-counter advance/reset cannot fabricate a pair of completed turns.
	for bad: Dictionary in [witness(13, 1200001, 101), witness(1, 1200001, 100), {},
		{"session_step":14, "rapier_step":114, "completed_usec":9999999},
		{"session_step":true, "rapier_step":114, "completed_usec":1200001},
		{"session_step":14.0, "rapier_step":114, "completed_usec":1200001},
		{"session_step":14, "rapier_step":114.0, "completed_usec":1200001}]:
		var next: Packet = packet(28, 1200001)
		check(policy.offer(next, owner, 1200002, 42, 27), "offer with unsupported completed witness")
		check(policy.take_due(owner, bad, 1200002) == next, "invalid or absent witness preserves immediate material progress")
		check(policy.complete(next, true, bad, 1200002) and policy.status().anchor_session_step == -1,
			"invalid witness gives no step anchor")
		policy.cancel("next_adversary")
		accepted(policy, first, owner, 1200003, witness(12, 1200001), 19)

	var retired := packet(29, 1200004)
	check(policy.offer(retired, owner, 1200005, 42, 20), "pending before same-tick bridge recreation")
	check(policy.take_due([7, 11, 42, -9002], witness(12, 1200001), 9999999) == null,
		"same session/tick values on a different bridge retire old bytes")
	check(policy.status().pending_count == 0 and policy.status().anchor_session_step == -1,
		"bridge retirement clears anchor and pending publication")
	var replacement_world := packet(30, 1200006, 43, true)
	check(policy.offer(replacement_world, [7, 11, 43, -9002], 1200007, 42, 20), "new full World offered")
	check(policy.take_due([7, 11, 43, -9002], {}, 1200007) == replacement_world,
		"new World with no active owner progresses immediately")
	check(policy.complete(replacement_world, true, {}, 1200007), "new World needs actual upload acceptance")
	check(not policy.offer(packet(31, 1200008, 44), [7, 11, 44, -9002], 1200009, 43, 30) \
		and policy.status().last_offer_result == "new_world_requires_full", "new World partial has no invented base")

	policy.cancel("paint_fixture")
	accepted(policy, first, owner, 2000000, witness(20, 1999999), 19)
	policy.mark_edit_admitted()
	policy.observe_paint_busy(true, 2000001)
	check(policy.status().paint_force and policy.status().paint_idle_usec == -1,
		"queued soft paint arms forcing without a hard revision")
	policy.observe_paint_busy(true, 2000002)
	check(policy.status().paint_force and policy.status().paint_idle_usec == -1,
		"inflight edit remains busy after queue empties")
	var while_busy := packet(21, 2000000)
	accepted(policy, while_busy, owner, 2000003, witness(20, 1999999), 20)
	check(policy.status().paint_force, "old accepted material cannot complete an inflight paint request")
	policy.observe_paint_busy(false, 2000004)
	check(policy.status().paint_idle_usec == 2000004, "first observed idle records a source-clock floor")
	var before_idle := packet(22, 2000003)
	accepted(policy, before_idle, owner, 2000005, witness(20, 1999999), 21)
	check(policy.status().paint_force, "packet generated before observed idle cannot clear paint priority")
	policy.mark_edit_admitted()
	check(policy.status().paint_idle_usec == -1 and policy.status().edit_requests == 2,
		"second brush before completion re-arms forcing and retires old idle clock")
	policy.observe_paint_busy(true, 2000006)
	policy.observe_paint_busy(false, 2000007)
	var after_idle := packet(23, 2000008)
	accepted(policy, after_idle, owner, 2000009, witness(20, 1999999), 22)
	check(not policy.status().paint_force and policy.status().paint_idle_usec == -1,
		"only actually accepted material generated after the new idle clears priority")

	var paused := packet(24, 2000010)
	accepted(policy, paused, owner, 2000011, witness(20, 1999999), 23, "paused")
	check(policy.status().last_consumption_reason == "paused", "paused edits bypass the count hold")
	var refused := packet(25, 2000012)
	check(policy.offer(refused, owner, 2000013, 42, 24), "offer before actual upload refusal")
	check(policy.take_due(owner, witness(22, 2000012), 2000013) == refused, "two steps select refused candidate")
	var before_count: int = policy.status().accepted_uploads
	check(not policy.complete(refused, false, witness(22, 2000012), 2000013), "refused upload cannot complete")
	check(policy.status().accepted_uploads == before_count and policy.status().anchor_session_step == -1 \
		and policy.status().pending_count == 0, "refusal clears authority without fake upload or step credit")
	accepted(policy, first, owner, 3000000, witness(30, 2999998), 19)
	var slow_main := packet(21, 2999999)
	check(policy.offer(slow_main, owner, 3000001, 42, 20) \
		and policy.take_due(owner, witness(31, 2999998), 3000001) == null,
		"slow-cadence first offer still omits its transaction at delta1")
	check(policy.take_due(owner, witness(32, 2999998), 3083001) == slow_main,
		"next83ms Main opportunity consumes after the second genuine completion")
	check(policy.status().last_count_due and policy.status().last_deadline_due \
		and policy.status().last_deadline_overrun_usec == 83000 - Policy.ADDED_HOLD_USEC,
		"both simultaneous eligibility conditions and actual overrun remain visible")
	check(policy.complete(slow_main, true, witness(32, 2999998), 3083001), "slow-cadence upload still needs actual acceptance")
	check(policy.configure(0) and not policy.enabled(), "explicit off restores original caller behavior")
	print("MATERIAL_STEPS_RESULT ", JSON.stringify({"schema":"pubpres-material-steps-policy-v1",
		"complete":failures.is_empty(), "checks":checks, "failures":failures,
		"synthetic_clocks_and_steps":true, "physical_credit":false,
		"policy_sha256":FileAccess.get_sha256("res://scripts/material_publication_steps.gd")}))
	quit(int(not failures.is_empty()))
