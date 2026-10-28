extends SceneTree
const Session = preload("res://scripts/solid_detachment_session.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL SOL281 HOST ",message)
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var s = Session.new()
	if not await s.open(root,1):
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
	check(await s.open(root,4),"new async session opens after joined teardown")
	var reset_stale: Dictionary = await s.command({"action":"commit","token":prepared.token})
	check(reset_stale.get("outcome") == "Stale","old session cannot resurrect payload/body")
	s.close()
	await process_frame
	print("SOL281_HOST_FAILURES ",JSON.stringify({"checks":checks,"failures":failures,"platform":OS.get_name(),"actual_rapier":true}))
	quit(0 if failures.is_empty() else 1)
