extends SceneTree
const Session = preload("res://scripts/solid_detachment_session.gd")
const SolidWorker = preload("res://scripts/solid_detachment_worker.gd")

class FailurePublicationWorker:
	extends SolidWorker
	# This adverse control exercises the real worker's failure publisher, with
	# real native payload/masks and Rapier RIDs. It is not a native solver fault;
	# test_tick_failure_regression supplies that independent capacity-fault gate.
	var fail_when_compound: bool = false
	var _fail_next_publication: bool = false
	func request_failure_publication() -> void:
		_mutex.lock()
		_fail_next_publication = true
		_mutex.unlock()
	func _publish_snapshot(step_ms: float, paused: bool, interval: int,
			force_full: bool = false, body_states: PackedFloat32Array = PackedFloat32Array(),
			body_epoch: int = 0) -> void:
		_mutex.lock()
		var inject: bool = _fail_next_publication
		_fail_next_publication = false
		_mutex.unlock()
		if inject or (fail_when_compound and not body_states.is_empty()):
			_simulation_failed = true
		super._publish_snapshot(step_ms, paused, interval, force_full, body_states, body_epoch)

class FailureSession:
	extends Session
	var fail_prime: bool = false
	func _create_worker() -> CyberSimulationWorker:
		var owner := FailurePublicationWorker.new()
		owner.fail_when_compound = fail_prime
		return owner
var checks: int = 0
var workers: int = 4
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL SOL281 HOST ",message)
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = int(argument.trim_prefix("--workers="))
	check(workers in [1, 4], "configured worker fixture is one or four")
	var s = Session.new()
	if not await s.open(root,workers):
		check(false,s.last_error); s.close(); quit(1); return
	var malformed: Dictionary = await s.command({"action":"prepare","domain":"not-a-rect"})
	check(malformed.get("outcome") == "Invalid","malformed typed input refuses before edit")
	var prepared: Dictionary = await s.command({"action":"cut_prepare","domain":s.DOMAIN,"anchors":s.ANCHORS,"seed":s.SEED,"cut":s.CUT})
	check(prepared.get("ok",false),"actual prepared native tree")
	if not prepared.get("ok",false): s.close(); quit(1); return
	var before: int = prepared.actual_native_tick
	# UI attempts to unpause while native transaction is outstanding. The shared
	# owner must publish but cannot execute its ordinary setting/mask writes.
	s.set_paused(false)
	for _i: int in range(8): await physics_frame
	var inspected: Dictionary = await s.command({"action":"inspect"})
	check(inspected.get("actual_native_tick") == before,"unpause cannot tick fenced native World")
	check(inspected.get("source_probe") == 43 and inspected.get("aggregate_owned") == 0,"prepared pixels still sole native authority")
	check(not inspected.get("worker_failed",true),"paused refresh path does not poison World")
	var stale: Dictionary = await s.command({"action":"commit","token":"0:0"})
	check(stale.get("outcome") == "Stale","stale command token refused")
	var pre_ack: Dictionary = await s.command({"action":"commit","token":prepared.token})
	check(pre_ack.get("outcome") == "Stale","no unacknowledged source retirement")
	s.source_receipt = prepared
	s.source_center = prepared.center
	s.source_payload = prepared.members
	s.source_rectangles = prepared.rectangles
	if not await s._prepare_body(prepared):
		check(false,"actual inactive Rapier body construction"); s.close(); quit(1); return
	check(s.body.freeze and s.body.collision_layer == 0,"real body inactive with source still native")
	var ack: Dictionary = await s.command({"action":"acknowledge","token":prepared.token,"body_id":1,"body_generation":s.generation,
		"shape_count":prepared.shape_count,"payload_digest":prepared.payload_digest,"shape_digest":prepared.shape_digest})
	check(ack.get("ok",false),"actual reserved body acknowledges")
	var commit: Dictionary = await s.command({"action":"commit","token":prepared.token})
	check(commit.get("ok",false) and commit.get("source_probe") == 0,"source retired only after ack")
	check(s._install_terrain(commit),"actual post-commit static geometry installed")
	var bad: Dictionary = await s.command({"action":"finalize","token":prepared.token,"body_id":1,"body_generation":s.generation,
		"physics_epoch":1,"terrain_revision":prepared.source_revision})
	check(not bad.get("ok",true),"precommit static terrain cannot release native fence")
	check(s.bridge.manual_step_count() == 0,"no Rapier step during failed receipt")
	var restored: Dictionary = await s.command({"action":"rollback","token":prepared.token})
	check(restored.get("ok",false) and restored.get("source_probe") == 43,"actual native restoration after inactive-body failure")
	check(restored.get("fenced",false) and restored.get("aggregate_owned") == 0,"restored pixels fenced pending real static repair")
	check(s._install_terrain(restored),"actual static original geometry reconstructed")
	var finish: Dictionary = await s.command({"action":"finish_rollback","token":prepared.token,"body_id":1,"body_generation":s.generation,
		"physics_epoch":2,"terrain_revision":restored.commit_revision})
	check(finish.get("ok",false) and not finish.get("fenced",true),"owner release after actual rollback contact repair")
	check(s.bridge.manual_step_count() == 0,"body never moved while rollback staged")
	s.close()
	await process_frame
	# Reset a new native owner and deliver the stale old session token.
	check(await s.open(root,workers),"new async session opens after joined teardown")
	var reset_stale: Dictionary = await s.command({"action":"commit","token":prepared.token})
	check(reset_stale.get("outcome") == "Stale","old session cannot resurrect payload/body")
	check(await s.cut_and_release(), "replacement owner releases its own actual aggregate")
	s.set_paused(true)
	var active_before: Dictionary = await s.inspect_active()
	var body_rid: RID = s.body.get_rid()
	var epoch: int = s.physics_epoch
	var pose: Transform2D = s.body_transform()
	# These ordinary worker interfaces must not replace just native while its
	# detached body is still owned by the main-thread session.
	s.worker.queue_reset(Vector2(400, 400), false, false)
	check(s.worker.queue_actor_prototype_reset([], Vector2(400, 400), false) == 0,
		"actor reset receives an explicit refused admission")
	s.worker.queue_lab({"reset":true})
	s.worker.queue_lab({"solid_detachment":{"action":"inspect","request_id":999999}, "water_reset":true})
	var active_after: Dictionary = await s.inspect_active()
	check(int(active_after.get("refused_replacements", 0)) == 4, "all four unrelated replacement routes refuse")
	check(active_after.get("token") == active_before.get("token") and active_after.get("members") == active_before.get("members"),
		"active token and exact payload survive rejected World replacement")
	check(int(active_after.get("aggregate_owned", 0)) == 520 and int(active_after.get("native_source_members", -1)) == 0,
		"replacement attempts cannot duplicate or lose native ownership")
	check(s.body.get_rid() == body_rid and s.physics_epoch == epoch and s.body_transform() == pose,
		"rejected replacement leaves the actual Rapier body and epoch unchanged")
	check(not active_after.get("worker_failed", true), "replacement refusal does not quarantine the retained owner")
	s.close()
	await process_frame
	await _failure_publication()
	print("SOL281_HOST_FAILURES ",JSON.stringify({"checks":checks,"failures":failures,"platform":OS.get_name(), "workers":workers,
		"actual_rapier":true,"publication_faults":2,"native_solver_failure":"separate ordinary tick-failure regression"}))
	quit(0 if failures.is_empty() else 1)

func _failure_publication() -> void:
	var s := FailureSession.new()
	check(await s.open(root, workers), "failure-publication actual owner opens")
	check(await s.cut_and_release(), "failure-publication actual handoff completes")
	if not s.active:
		s.close()
		return
	s.set_paused(true)
	var before: Dictionary = await s.inspect_active()
	var body_rid: RID = s.body.get_rid()
	(s.worker as FailurePublicationWorker).request_failure_publication()
	var deadline: int = Time.get_ticks_msec() + Session.Watchdogs.milliseconds("operation_seconds")
	while not s.worker.has_failed() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(s.worker.has_failed(), "real worker publishes injected failure status")
	var failed: CyberSimulationSnapshot = s.worker.take_latest_snapshot(-1)
	check(failed != null and failed.simulation_failed and failed.rigid_body_results.is_empty()
		and not failed.current_rigid_body_states.is_empty(), "failed publication retains last mask sample and clears force results")
	var pose: Transform2D = s.body_transform()
	var steps: int = s.bridge.manual_step_count()
	s.set_paused(false)
	s.physics_step()
	check(s.physics_paused and not s.last_error.is_empty(), "observed owner failure latches the entire session paused")
	check(s.bridge.manual_step_count() == steps and s.body_transform() == pose,
		"no Rapier step crosses the observed failed-native boundary")
	s.set_paused(false)
	for _i: int in range(3):
		s.physics_step()
	check(s.physics_paused and s.bridge.manual_step_count() == steps, "unpause cannot revive a failed ownership session")
	var after: Dictionary = await s.inspect_active()
	check(after.get("token") == before.get("token") and after.get("members") == before.get("members")
		and int(after.get("aggregate_owned", 0)) == 520 and s.body.get_rid() == body_rid,
		"failed publication preserves the real retained aggregate and native payload")
	s.close()
	await process_frame
	var prime := FailureSession.new()
	prime.fail_prime = true
	check(await prime.open(root, workers), "priming-failure actual owner opens")
	check(not await prime.cut_and_release(), "failed native publication cannot acknowledge compound priming")
	check(prime.physics_paused and not prime.active and is_instance_valid(prime.body) and prime.body.freeze,
		"failure before priming leaves actual body held and inactive")
	check(prime.bridge != null and prime.bridge.manual_step_count() == 0, "unprimed aggregate never receives a Rapier step")
	prime.close()
	await process_frame
