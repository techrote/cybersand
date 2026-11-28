extends SceneTree

const Fixture = preload("res://tests/fixtures/persistent_area_native_fixture.gd")
var failures: Array[String] = []
var workers := 1
var phases := 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--residency-memory-workers="):
			workers = int(argument.get_slice("=",1))
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		push_error("GEN006 residency memory: " + detail)

func identity(fixture: Dictionary, area: String) -> Dictionary:
	return {"session_id":"native-memory-session", "area_id":area, "incarnation":"native-memory-"+area,
		"runtime_sha256":"a".repeat(64), "authored_source_sha256":fixture.checked.hash}

func state(owner: Dictionary) -> Dictionary:
	return owner.bridge.resident_status(owner.world) if not owner.is_empty() else {"entries":[],"native_bytes":0,"active":{}}

func receipt(owner: Dictionary, area: String) -> Dictionary:
	for entry: Dictionary in state(owner).entries:
		if entry.identity.area_id == area: return entry
	return {}

func phase(label: String, owner: Dictionary, warm_bytes: int = 0, extra_native_bytes: int = 0) -> void:
	phases += 1
	print("GEN006_NATIVE_MEMORY_PHASE " + JSON.stringify({"label":label,"monotonic_us":Time.get_ticks_usec(),
		"pid":OS.get_process_id(),"workers":workers,"native":state(owner),"warm_payload_bytes":warm_bytes,
		"extra_private_native_bytes":extra_native_bytes,"host_static_memory_bytes":OS.get_static_memory_usage()}))
	# A sampling dwell, explicitly excluded from productive simulation work.
	await create_timer(0.25).timeout

func prepared(area: String) -> Dictionary:
	var result: Dictionary = Fixture.create(workers)
	if result.has("error"): check(false,str(result.error)); return {}
	result.world.paint_disc(80+area.unicode_at(0),60,1,58)
	for index: int in 10: check(result.world.simulation_tick(),"actual native memory fixture tick")
	var bound: Dictionary = result.bridge.resident_admit(result.world,identity(result,area))
	check(bound.get("ok",false),"native area admitted for memory measurement")
	result["receipt"] = bound.get("receipt",{})
	return result

func warm_restore(owner: Dictionary, capsule: Dictionary, area: String) -> Dictionary:
	var result: Dictionary = Fixture.create(workers)
	var options: Dictionary = Fixture.restore_options(result,capsule,"warm-memory-"+area)
	var token: int = Fixture.prepare(result,options)
	check(token>0 and result.bridge.commit_liquid_world(result.world,token),"warm native continuation restored")
	var bound: Dictionary = result.bridge.resident_admit(result.world,identity(result,area))
	check(bound.get("ok",false),"warm restoration admitted")
	return owner.bridge.resident_import(owner.world,result.world,bound.receipt)

func run() -> void:
	check(workers in [1,4],"memory qualification uses configured1or4workers")
	await phase("before_first_world",{})
	var owner := prepared("A")
	if owner.is_empty(): quit(1); return
	await phase("one_hot_world",owner)
	await phase("before_second_preparation",owner)
	var second := prepared("B")
	await phase("second_private_prepared",owner,0,int(second.receipt.native_bytes))
	check(owner.bridge.resident_import(owner.world,second.world,second.receipt).get("ok",false),"B import")
	second = {}
	await phase("two_hot_worlds",owner)
	await phase("before_third_preparation",owner)
	var third := prepared("C")
	check(owner.bridge.resident_import(owner.world,third.world,third.receipt).get("ok",false),"C import")
	third = {}
	await phase("three_hot_worlds",owner)
	await phase("before_checkpoint_capture",owner)
	var warm_b: Dictionary = owner.bridge.resident_capture(owner.world,receipt(owner,"B")).capsule
	await phase("three_hot_one_checkpoint",owner,warm_b.bytes.size())
	check(owner.bridge.resident_release(owner.world,receipt(owner,"B")).get("ok",false),"B hot-to-warm allocation release")
	await phase("two_hot_one_warm",owner,warm_b.bytes.size())
	var warm_c: Dictionary = owner.bridge.resident_capture(owner.world,receipt(owner,"C")).capsule
	check(owner.bridge.resident_release(owner.world,receipt(owner,"C")).get("ok",false),"C hot-to-warm allocation release")
	await phase("one_hot_two_warm",owner,warm_b.bytes.size()+warm_c.bytes.size())
	await phase("before_warm_restoration",owner,warm_b.bytes.size()+warm_c.bytes.size())
	check(warm_restore(owner,warm_b,"B").get("ok",false),"warm checkpoint promoted to actual hot native World")
	warm_b = {}
	await phase("two_hot_after_warm_restoration",owner,warm_c.bytes.size())
	var before_bytes: int = state(owner).native_bytes
	for index: int in 180:
		var target := receipt(owner,"B" if index%2==0 else "A")
		check(owner.bridge.resident_activate(owner.world,target,state(owner).active,
			"memory-churn-%d"%index).get("ok",false),"hot churn ownership")
	check(state(owner).native_bytes==before_bytes,"180hot switches keep native owned allocations stable")
	await phase("two_hot_after_180_handoffs",owner,warm_c.bytes.size())
	check(owner.bridge.resident_release(owner.world,receipt(owner,"B")).get("ok",false),"final inactive native release")
	warm_c = {}
	await phase("one_hot_buffers_released",owner)
	print("GEN006_NATIVE_MEMORY_DONE " + JSON.stringify({"schema":1,"ok":failures.is_empty(),"failures":failures,
		"phases":phases,"configured_workers":workers,"native":state(owner),"sampling_dwell_ms_per_phase":250,
		"scope":"Native memory ownership fixture; no disk durability or Main rendering claim"}))
	quit(0 if failures.is_empty() else 1)
