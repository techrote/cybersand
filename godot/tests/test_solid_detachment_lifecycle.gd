extends SceneTree

# Deterministic continuation barriers run AFTER real native replies. No mock
# World, Rapier body, payload, transaction receipt or replacement owner.
const Session = preload("res://scripts/solid_detachment_session.gd")
class ReplyBarrier:
	extends Session
	signal continue_reply
	var stop_at: String = ""
	var reply_blocked: bool = false
	func command(input: Dictionary) -> Dictionary:
		var reply: Dictionary = await super.command(input)
		if str(input.get("action", "")) == stop_at and not reply_blocked:
			reply_blocked = true
			await continue_reply
		return reply
	func _prime_compound_coupling() -> bool:
		var result: bool = await super._prime_compound_coupling()
		if stop_at == "prime" and not reply_blocked:
			reply_blocked = true
			await continue_reply
		return result

var checks: int = 0
var failures: Array[String] = []
var completed: Dictionary = {}
var cycle_count: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL SOL281 LIFECYCLE ", message)

func _init() -> void:
	call_deferred("_run")

func _operation(s: RefCounted, operation: String, ticket: int, workers: int) -> void:
	var result: Variant
	if operation == "configure":
		result = await s.open(root, workers)
	elif operation == "inspect":
		result = await s.inspect_active()
	elif operation in ["rollback", "finish_rollback"]:
		result = await s._rollback_inactive("injected inactive rollback")
	else:
		result = await s.cut_and_release()
	completed[ticket] = result

func _wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + Session.Watchdogs.milliseconds("operation_seconds")
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
		OS.delay_usec(500)
	return predicate.call()

func _staged_commit(s: RefCounted) -> bool:
	var p: Dictionary = await s.command({"action":"cut_prepare", "domain":s.DOMAIN,
		"anchors":s.ANCHORS, "seed":s.SEED, "cut":s.CUT})
	if not p.get("ok", false):
		return false
	s.source_receipt = p
	s.source_payload = p.members
	s.source_rectangles = p.rectangles
	s.source_center = p.center
	if not await s._prepare_body(p):
		return false
	var a: Dictionary = await s.command({"action":"acknowledge", "token":p.token,
		"body_id":1, "body_generation":s.generation, "shape_count":p.shape_count,
		"payload_digest":p.payload_digest, "shape_digest":p.shape_digest})
	if not a.get("ok", false):
		return false
	var c: Dictionary = await s.command({"action":"commit", "token":p.token})
	return c.get("ok", false) and s._install_terrain(c)

func _retire_at(stage: String, workers: int, ticket: int) -> void:
	var s = ReplyBarrier.new()
	if stage != "configure":
		check(await s.open(root, workers), stage + ": old actual owner opens")
		if not failures.is_empty():
			s.close()
			return
	if stage in ["rollback", "finish_rollback"]:
		check(await _staged_commit(s), stage + ": actual inactive committed body")
	if stage == "inspect":
		s.set_paused(false) # The retired continuation must NOT restore this to new owner.
	s.stop_at = "cut_prepare" if stage == "body_yield" else stage
	_operation(s, stage, ticket, workers)
	check(await _wait_for(func(): return s.reply_blocked), stage + ": real reply barrier reached")
	if not s.reply_blocked:
		s.close()
		return
	if stage == "body_yield":
		s.continue_reply.emit()
		check(is_instance_valid(s.body), stage + ": real inactive body exists at frame yield")
		check(not await s.cut_and_release(), stage + ": overlapping release refused")
		check(s.last_error == "", stage + ": overlapping release does not poison first transaction")
	s.close()
	check(await s.open(root, workers), stage + ": replacement actual owner opens")
	var next_generation: int = s.generation
	var next_worker: Object = s.worker
	var next_request: int = s.request_serial
	var next_status: String = s.status
	if stage != "body_yield":
		s.continue_reply.emit()
	check(await _wait_for(func(): return completed.has(ticket)), stage + ": retired continuation returns")
	check(s.generation == next_generation and s.worker == next_worker, stage + ": replacement identity preserved")
	check(s.request_serial == next_request, stage + ": no stale retry/cancel sent to replacement")
	check(s.status == next_status and s.last_error == "", stage + ": stale result cannot poison replacement")
	check(s.physics_paused, stage + ": stale result cannot unpause replacement")
	check(not s.transaction_busy, stage + ": replacement command lock remains consistent")
	check(s.bridge == null and s.body == null, stage + ": no old body or bridge survives")
	check(s.source_receipt.is_empty() and s.commit_receipt.is_empty() and s.final_receipt.is_empty(), stage + ": old payload receipts cleared")
	if stage != "inspect":
		check(completed.get(ticket) == false, stage + ": retired operation does not report success")
	else:
		check(not completed.get(ticket, {}).get("ok", true), stage + ": retired inspection not accepted")
	var current: Dictionary = await s.observe_intact()
	check(current.get("outcome") == "Anchored" and current.get("source_probe") == 43,
		stage + ": replacement native tree remains intact")
	check(current.get("aggregate_owned") == 0 and not current.get("fenced", true)
		and not current.get("worker_failed", true), stage + ": replacement native ownership remains healthy")
	check(await s.cut_and_release(), stage + ": replacement can still complete a real handoff")
	for _i: int in range(3):
		await physics_frame
		s.physics_step()
	var active: Dictionary = await s.inspect_active()
	check(active.get("aggregate_owned") == 520 and active.get("native_source_members") == 0,
		stage + ": replacement preserves exact material ownership after release")
	s.close()
	await process_frame
	cycle_count += 1

func _run() -> void:
	var stages: Array[String] = ["configure", "cut_prepare", "body_yield", "acknowledge", "commit",
		"finalize", "prime", "inspect", "rollback", "finish_rollback"]
	if "--red-only" in OS.get_cmdline_user_args():
		stages = ["inspect"]
	var ticket: int = 0
	for workers: int in [1, 4]:
		for stage: String in stages:
			ticket += 1
			await _retire_at(stage, workers, ticket)
			if not failures.is_empty():
				break
		if not failures.is_empty():
			break
	print("SOL281_LIFECYCLE ", JSON.stringify({"checks":checks, "failures":failures,
		"actual_host_replacement_cycles":cycle_count, "platform":OS.get_name(),
		"scope":"actual native/Rapier owner replacement at awaited replies; not compound material coupling"}))
	quit(0 if failures.is_empty() else 1)
