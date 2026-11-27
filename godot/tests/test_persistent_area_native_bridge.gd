extends SceneTree

const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	assertions += 1
	if not ok:
		failures.append(detail)
		push_error("GEN006 native bridge: "+detail)

func run() -> void:
	var reference: Dictionary = Fixture.create()
	var target: Dictionary = Fixture.create()
	if reference.has("error") or target.has("error"):
		check(false,"fixture construction: "+str(reference.get("error",target.get("error",""))))
		quit(1); return
	# The retained source can be a generic native owner at bootstrap. Its live
	# body must still pin replacement even though the target has zero actors.
	var source_body: Dictionary = Fixture.create()
	var tick_zero: Dictionary = source_body.bridge.capture_workbench_continuation(source_body.world)
	source_body.world = ClassDB.instantiate(&"CyberNativeCellWorld")
	source_body.world.prepare_rigid_body_coupling(PackedFloat32Array([1,100,100,0,3,3,0,0,0,1,1]),false)
	check(source_body.world.rigid_body_id_at(100,100)==1,"real retained native body mask exists")
	var body_before: PackedByteArray = source_body.bridge.export_physical_state(source_body.world)
	var body_token: int = Fixture.prepare(source_body,Fixture.restore_options(source_body,tick_zero,"source-body-refusal"))
	check(body_token==0,"a live source body pins replacement by an actor-free continuation")
	if body_token>0: source_body.bridge.discard_liquid_world(source_body.world,body_token)
	check(source_body.world.rigid_body_id_at(100,100)==1 and
		source_body.bridge.export_physical_state(source_body.world)==body_before,"retained body and native state survive refusal")
	source_body.world = ClassDB.instantiate(&"CyberNativeCellWorld")
	var late_token: int = Fixture.prepare(source_body,Fixture.restore_options(source_body,tick_zero,"late-source-body"))
	check(late_token>0,"body-free generic source prepares continuation")
	source_body.world.prepare_rigid_body_coupling(PackedFloat32Array([1,100,100,0,3,3,0,0,0,1,1]),false)
	check(source_body.world.rigid_body_id_at(100,100)==1,"late native body dependency exists")
	check(not source_body.bridge.commit_liquid_world(source_body.world,late_token) and
		source_body.world.rigid_body_id_at(100,100)==1,"late source dependency refuses commit and preserves body")
	check("body" in str(source_body.bridge.get_last_error()).to_lower(),
		"native dependency guard itself refuses late source body before the state fence")
	for i: int in 17: check(reference.world.simulation_tick(),"initial real native tick")
	reference.world.paint_disc(65,60,2,0)
	var saved: Dictionary = reference.bridge.capture_workbench_continuation(reference.world)
	check(not saved.is_empty(),"full native capture: "+str(reference.bridge.get_last_error()))
	if saved.is_empty(): quit(1); return
	check(saved.schema==1 and saved.format_version==2 and saved.physical_hash_version==2 and
		saved.completed_tick==17 and saved.extent==Vector2i(512,512) and
		saved.authored_source_sha256==reference.checked.hash,"complete capsule identity")
	var old: PackedByteArray = target.bridge.export_physical_state(target.world)
	var options: Dictionary = Fixture.restore_options(target,saved,"restore-1")
	var token: int = Fixture.prepare(target,options)
	check(token>0,"private continuation prepare: "+str(target.bridge.get_last_error()))
	if token<=0: quit(1); return
	check(target.bridge.export_physical_state(target.world)==old,"private restore preserves retained World")
	var restored: Dictionary = target.bridge.capture_prepared_workbench_continuation(target.world,token)
	check(restored.bytes==saved.bytes and restored.physical_hash==saved.physical_hash,"complete CYPS identity before private stepping")
	# Returned values are an observation, never mutable authority over the private
	# candidate or its cached receipt. Exercise packed-array detachment explicitly.
	restored.bytes[0] = int(restored.bytes[0]) ^ 1
	restored.execution.maximum_chunk_count = 4096
	var detached: Dictionary = target.bridge.capture_prepared_workbench_continuation(target.world,token)
	check(detached.bytes==saved.bytes and detached.execution.maximum_chunk_count==128,
		"mutating a returned capsule cannot alter cached native continuation authority")
	var advanced: int = 0
	var useful_us: int = 0
	while advanced<65:
		var progress: Dictionary = target.bridge.advance_workbench_continuation(target.world,token,mini(8,65-advanced),100000)
		check(progress.get("ok",false),"private bounded native slice")
		if not progress.get("ok",false): quit(1); return
		advanced += int(progress.completed_ticks)
		useful_us += int(progress.elapsed_us)
	for i: int in 65: check(reference.world.simulation_tick(),"uninterrupted reference native tick")
	var exact: Dictionary = reference.bridge.capture_workbench_continuation(reference.world)
	var candidate: Dictionary = target.bridge.capture_prepared_workbench_continuation(target.world,token)
	check(candidate.bytes==exact.bytes and candidate.physical_hash==exact.physical_hash,
		"private sliced catch-up matches uninterrupted complete native state")
	var run_capture: Dictionary = target.bridge.prepared_liquid_run_capture(target.world,token)
	var receipt: Dictionary = run_capture.native_run_encoding
	check(receipt.kind=="workbench_continuation" and receipt.source_construction_receipt.kind=="applied_run" and
		receipt.source_completed_tick==17 and receipt.completed_tick==82 and receipt.advanced_native_ticks==65 and
		receipt.source_checkpoint_sha256==saved.sha256 and receipt.checkpoint_sha256==candidate.sha256 and
		receipt.continuation_identity.operation_id=="restore-1", "native continuation and authored construction are distinct authority")
	check(target.bridge.commit_liquid_world(target.world,token),"guarded continuation commit")
	check(not target.bridge.commit_liquid_world(target.world,token),"token cannot commit twice")
	check(target.bridge.export_physical_state(target.world)==exact.bytes,"committed native state matches reference")
	check(target.world.stored_material_at(65,60)==0,"destructive Empty mark survives restore and catch-up")
	check(Fixture.prepare(target,options)==0,"committed operation identity cannot be reused")
	var coarse: Dictionary = target.bridge.assess_workbench_coarse_advance(target.world,36000)
	check(not coarse.admitted and coarse.credited_ticks==0 and coarse.remaining_debt_ticks==36000,
		"unsupported coarse skip grants no game-time credit")
	# Capture and construction refusals retain the currently running World.
	var retained: PackedByteArray = target.bridge.export_physical_state(target.world)
	for corruption: String in ["sha","tick","physical","source","schema","policy","execution","extent"]:
		var bad: Dictionary = saved.duplicate(true)
		match corruption:
			"sha": bad.sha256="0".repeat(64)
			"tick": bad.completed_tick+=1
			"physical": bad.physical_hash="0".repeat(16)
			"source": bad.authored_source_sha256="0".repeat(64)
			"schema": bad.schema=2
			"policy": bad.policy_sha256="0".repeat(64)
			"execution": bad.execution.maximum_chunk_count=4096
			"extent": bad.extent=Vector2i(1024,512)
		check(Fixture.prepare(target,Fixture.restore_options(target,bad,"negative-"+corruption))==0,
			"refuses corrupted "+corruption)
		check(target.bridge.export_physical_state(target.world)==retained,"refusal preserves old World: "+corruption)
	var stale_options: Dictionary = Fixture.restore_options(target,saved,"stale-1")
	token=Fixture.prepare(target,stale_options)
	check(token>0,"prepare stale candidate")
	target.world.paint_disc(90,90,2,1)
	var edited: PackedByteArray = target.bridge.export_physical_state(target.world)
	check(not target.bridge.commit_liquid_world(target.world,token),"mutation after preparation refuses stale commit")
	check(target.bridge.export_physical_state(target.world)==edited,"stale refusal retains newer edit")
	token=Fixture.prepare(target,Fixture.restore_options(target,saved,"cancel-1"))
	check(token>0,"prepare cancellation candidate")
	check(target.bridge.advance_workbench_continuation(target.world,token,1,100000).ok,"real private tick before cancellation")
	target.bridge.discard_liquid_world(target.world,token)
	check(not target.bridge.commit_liquid_world(target.world,token) and
		target.bridge.export_physical_state(target.world)==edited,"cancel discards private work and preserves old World")
	token=Fixture.prepare(target,Fixture.restore_options(target,saved,"budget-1"))
	check(token>0,"prepare bounded-work refusal")
	check(not target.bridge.advance_workbench_continuation(target.world,token,33,100000).ok and
		not target.bridge.commit_liquid_world(target.world,token) and
		target.bridge.export_physical_state(target.world)==edited,"invalid budget retires candidate without retained mutation")
	print("GEN006_NATIVE_BRIDGE assertions=%d failures=%d native_catchup_ticks=65 native_step_us=%d checkpoint_bytes=%d final_physical=%s" %
		[assertions,failures.size(),useful_us,saved.bytes.size(),exact.physical_hash])
	quit(0 if failures.is_empty() else 1)
