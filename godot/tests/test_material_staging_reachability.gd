extends SceneTree

# PUBPRES-PLAYABILITY-001: actual GPU history and fixed resource-set checks for
# the opt-in removal of unreachable staging pools. No native or Rapier owner
# runs here; storage savings do not establish playable progression or physical
# Windows/NVIDIA acceptance. Test allocation oracles are fixed independently of
# the production class-selection helper. Every readback is outside timing.
const Publisher = preload("res://scripts/blit_material_publisher.gd")
const POLICY_ENV := "CYBERSAND_DIAG_MATERIAL_POOL_POLICY"
const SLOTS_ENV := "CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS"
const COPY_ENV := "CYBERSAND_DIAG_MATERIAL_COPY_MODE"
const FIXTURES: Array[Dictionary] = [
	{"name":"padded-small","extent":Vector2i(317,259),"ordinary":[1,4,16,64],
		"reachable":[1,4,16],"history":[],"reachable_history":[],"full_alias":0,
		"eager_rg8_slots3":3238407,"reachable_rg8_slots3":1665543},
	{"name":"padded-large","extent":Vector2i(2053,1027),"ordinary":[1,4,16,64,128,256],
		"reachable":[1,4,16,64,128],"history":[1,4],"reachable_history":[1,4],"full_alias":0,
		"eager_rg8_slots3":76114135,"reachable_rg8_slots3":50948311},
	{"name":"admitted-rectangle","extent":Vector2i(2048,1536),"ordinary":[1,4,16,64,128,256],
		"reachable":[1,4,16,64,128],"history":[1,4],"reachable_history":[1,4],"full_alias":0,
		"eager_rg8_slots3":90636293,"reachable_rg8_slots3":65470469},
	{"name":"square-no-saving","extent":Vector2i(2048,2048),"ordinary":[1,4,16,64,128,256],
		"reachable":[1,4,16,64,128,256],"history":[1,4],"reachable_history":[1,4],"full_alias":256,
		"eager_rg8_slots3":80150533,"reachable_rg8_slots3":80150533},
	{"name":"landscape-no-saving","extent":Vector2i(2048,1024),"ordinary":[1,4,16,64,128],
		"reachable":[1,4,16,64,128],"history":[1,4],"reachable_history":[1,4],"full_alias":128,
		"eager_rg8_slots3":38207493,"reachable_rg8_slots3":38207493},
	{"name":"maximum-height","extent":Vector2i(1,16383),"ordinary":[1,4,16,64,128,256],
		"reachable":[1],"history":[1,4],"reachable_history":[1],"full_alias":0,
		"eager_rg8_slots3":11878391,"reachable_rg8_slots3":278519},
]
const SUBMISSION_FIELDS: Array[String] = ["submitted_bytes","updated_tiles","candidate_tiles",
	"atlas_capacity","staging_width","staging_height","staging_slot","staging_slots",
	"copy_destinations","history_copy","history_staging","direct_whole","whole_gpu_copy",
	"copy_run_count","gpu_blit_calls","blit_pixels","retirement_blit_calls"]
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var queued_observations: Array[Dictionary] = []
var separate := false


# Same bounded test-only queue gate as run_material_threaded_publication.gd.
# Setup/readback happen before this gate; only publications are retained.
class QueueGate extends RefCounted:
	var entered := Semaphore.new()
	var resume := Semaphore.new()
	var cancel := Semaphore.new()
	var watcher := Thread.new()
	var expired := false
	var was_render_owner := false
	func block_queue() -> void:
		was_render_owner = RenderingServer.is_on_render_thread()
		entered.post()
		resume.wait()
	func watch() -> void:
		var deadline: int = Time.get_ticks_msec()+10000
		while Time.get_ticks_msec() < deadline:
			if cancel.try_wait(): return
			OS.delay_msec(5)
		expired = true
		entered.post()
		resume.post()
	func begin() -> void:
		watcher.start(watch)
		RenderingServer.call_on_render_thread(block_queue)
		entered.wait()
	func end() -> void:
		resume.post()
		cancel.post()
		watcher.wait_to_finish()


func _init() -> void:
	_run.call_deferred()


func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("MATERIAL_STAGING_REACHABILITY: "+detail)


func _keys(values: Dictionary) -> Array:
	var result: Array = values.keys()
	result.sort()
	return result


func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _source(size: Vector2i, channels: int, value: int) -> Image:
	var result := Image.create(size.x,size.y,false,Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8)
	result.fill(Color8(value,197,0))
	result.set_pixel(size.x-1,size.y-1,Color8(value+1,231,0))
	return result


func _histories(owner: Publisher, current: Image, previous: Image, label: String) -> Dictionary:
	var a: Image = owner.current.get_image()
	var b: Image = owner.previous.get_image()
	check(a != null and a.get_size() == current.get_size() and a.get_format() == current.get_format()
		and a.get_data() == current.get_data(),label+" exact current GPU bytes")
	check(b != null and b.get_size() == previous.get_size() and b.get_format() == previous.get_format()
		and b.get_data() == previous.get_data(),label+" exact previous GPU bytes")
	return {"current_sha256":_hash(a.get_data()) if a != null else "",
		"previous_sha256":_hash(b.get_data()) if b != null else ""}


func _expected_bytes(fixture: Dictionary, reachable: bool, channels: int, slots: int) -> int:
	var size: Vector2i = fixture.extent
	var planes: int = size.x*size.y*8+5
	var fixed: int = fixture.reachable_rg8_slots3 if reachable else fixture.eager_rg8_slots3
	return planes+((fixed-planes)/6)*channels*slots


func _same_cursors(owner: Publisher) -> Dictionary:
	var result: Dictionary = {}
	for pool: Publisher.StagingPool in owner._owned_staging_pools(): result[pool.get_instance_id()] = pool.next_slot
	return result


func _refusal_contract(owner: Publisher, source: Image, label: String) -> void:
	var resources: Array[int] = owner.resource_identity()
	var cursors: Dictionary = _same_cursors(owner)
	var pending: PackedByteArray = owner.previous.pending.duplicate()
	# Removing a required class together with its identity entry must still fail
	# closed. Matching dictionary sizes cannot substitute for the required set.
	var first: int = int(_keys(owner.staging)[0])
	var saved: Publisher.StagingPool = owner.staging[first]
	var identity: int = owner._staging_pool_ids[first]
	owner.staging.erase(first)
	owner._staging_pool_ids.erase(first)
	check(not owner.publish(source,[Rect2i(0,0,1,1)]),label+" missing required class refused")
	owner.staging[first] = saved
	owner._staging_pool_ids[first] = identity
	# Same count with a substituted unexpected key cannot trigger an unchecked
	# required-key lookup or admit a differently shaped resource.
	owner.staging.erase(first)
	owner._staging_pool_ids.erase(first)
	owner.staging[999] = saved
	owner._staging_pool_ids[999] = identity
	check(not owner.publish(source,[Rect2i(0,0,1,1)]),label+" forged class key refused")
	owner.staging.erase(999)
	owner._staging_pool_ids.erase(999)
	owner.staging[first] = saved
	owner._staging_pool_ids[first] = identity
	var policy: String = owner.staging_pool_policy
	owner.staging_pool_policy = "unknown"
	check(not owner.publish(source,[Rect2i(0,0,1,1)]),label+" forged policy refused")
	owner.staging_pool_policy = policy
	check(owner.resource_identity() == resources and _same_cursors(owner) == cursors
		and owner.previous.pending == pending,label+" refusals preserve resources, cursors and coverage")


func _case(fixture: Dictionary, channels: int, slots: int, requested: String) -> Dictionary:
	var initial_failures: int = failures.size()
	OS.set_environment(POLICY_ENV,requested)
	OS.set_environment(SLOTS_ENV,str(slots))
	var reachable: bool = requested == "reachable"
	var size: Vector2i = fixture.extent
	var label: String = "%s/%s/R%d/%d" % [fixture.name,"reachable" if reachable else "eager",channels*8,slots]
	var source: Image = _source(size,channels,5)
	var preceding: Image = _source(size,channels,8)
	var owner: Publisher = Publisher.create_pair(source,preceding)
	check(owner != null,label+" owner initializes")
	if owner == null: return {}
	var resources: Array[int] = owner.resource_identity()
	var pair: Array[RID] = [owner.current.get_rid(),owner.previous.get_rid()]
	var initial: Dictionary = owner.last_update.duplicate()
	var expected_bytes: int = _expected_bytes(fixture,reachable,channels,slots)
	check(owner.staging_pool_policy == ("reachable" if reachable else "eager"),label+" explicit policy")
	check(_keys(owner.staging) == (fixture.reachable if reachable else fixture.ordinary),label+" exact ordinary pool set")
	check(_keys(owner._history_staging) == (fixture.reachable_history if reachable else fixture.history),label+" exact history pool set")
	check(owner.gpu_storage_bytes() == expected_bytes and initial.allocated_gpu_bytes == expected_bytes,
		label+" source-bound allocated bytes")
	var shared: bool = int(fixture.full_alias) > 0
	check(owner._owned_staging_pools().size() == owner.staging.size()+owner._history_staging.size()+(0 if shared else 1),
		label+" distinct pool count includes exactly one full-image resource")
	check(resources.size() == 4+owner._owned_staging_pools().size()*slots,label+" bounded texture identity count")
	if shared:
		check(owner.full_staging == owner.staging[int(fixture.full_alias)],label+" exact-shape full alias preserved")
	var gpu_hashes: Dictionary = _histories(owner,source,preceding,label+" setup")
	_refusal_contract(owner,source,label)
	var submissions: Array[Dictionary] = []
	var total: int = owner.columns*owner.rows
	var counts: Array[int] = []
	for count: int in [1,4,16,64,65,128,129,total]:
		if count <= total and not counts.has(count): counts.append(count)
	# Synchronous full and sparse parity. Only fixtures with >=128 tiles reach
	# dedicated history pools here; the queued matrix below covers both history
	# capacities across every ring size and both formats.
	counts.append(0)
	for repeat: int in range(slots*2+1): counts.append(1 if repeat % 2 == 0 else 4)
	for turn: int in range(counts.size()):
		preceding = source
		source = source.duplicate()
		var regions: Array[Rect2i] = []
		var count: int = counts[turn]
		if count == 0:
			source.fill(Color8(40+turn,150+turn,0))
		else:
			for index: int in range(count):
				var origin := Vector2i((index%owner.columns)*owner.tile_side,(index/owner.columns)*owner.tile_side)
				var point := Vector2i(mini(size.x-1,origin.x+owner.tile_side-1),mini(size.y-1,origin.y+owner.tile_side-1))
				source.set_pixelv(point,Color8(40+turn,150+turn,0))
				regions.append(Rect2i(point,Vector2i.ONE))
		check(owner.publish(source,regions),label+" publication%d accepted" % turn)
		var update: Dictionary = owner.last_update
		check(owner.resource_identity() == resources and owner.gpu_storage_bytes() == expected_bytes,
			label+" publication%d preserves fixed logical texture ownership" % turn)
		check(owner.current.get_rid() in pair and owner.previous.get_rid() in pair,
			label+" publication%d preserves both history targets" % turn)
		check(update.staging_pool_policy == owner.staging_pool_policy and update.allocated_gpu_bytes == expected_bytes,
			label+" publication%d reports effective policy and exact ownership" % turn)
		gpu_hashes = _histories(owner,source,preceding,label+" publication%d" % turn)
		var comparable: Dictionary = {}
		for field: String in SUBMISSION_FIELDS: comparable[field] = update.get(field)
		submissions.append(comparable)
	var record: Dictionary = {"fixture":fixture.name,"extent":[size.x,size.y],"channels":channels,"slots":slots,
		"policy":owner.staging_pool_policy,"allocated_gpu_bytes":owner.gpu_storage_bytes(),
		"expected_gpu_bytes":expected_bytes,"ordinary_classes":_keys(owner.staging),
		"history_classes":_keys(owner._history_staging),"resource_count":resources.size(),
		"all_histories_verified":failures.size() == initial_failures,"submissions":submissions,
		"current_sha256":gpu_hashes.current_sha256,"previous_sha256":gpu_hashes.previous_sha256,
		"expected_current_sha256":_hash(source.get_data()),"expected_previous_sha256":_hash(preceding.get_data()),
		"initialization":initial}
	observations.append(record)
	return record


func _queued_history_case(channels: int, slots: int, policy: String) -> Dictionary:
	var initial_failures: int = failures.size()
	OS.set_environment(POLICY_ENV,policy)
	OS.set_environment(SLOTS_ENV,str(slots))
	# 18x12 tiles at side64: both dedicated history pools are reachable while
	# the ordinary 256-tile atlas is provably unreachable in this rectangle.
	var size := Vector2i(1152,768)
	var label := "queued-history/%s/R%d/%d" % [policy,channels*8,slots]
	var source: Image = _source(size,channels,5)
	var owner: Publisher = Publisher.create_pair(source,source)
	check(owner != null,label+" owner initializes")
	if owner == null: return {}
	check(owner.columns*owner.rows == 216 and _keys(owner._history_staging) == [1,4],
		label+" reaches both actual dedicated history classes")
	var resources: Array[int] = owner.resource_identity()
	var resident: int = owner.gpu_storage_bytes()
	_histories(owner,source,source,label+" setup")
	# Prepare owned CPU images before blocking the renderer. The gate contains
	# no readback, await, forced draw, resource construction or test sync.
	var sources: Array[Image] = []
	var areas: Array = []
	var expected_paths: Array[Dictionary] = []
	var turns: int = slots*2+1
	for capacity: int in [1,4]:
		for repeat: int in range(turns):
			for phase: int in range(3):
				source = source.duplicate()
				var regions: Array[Rect2i] = []
				var value: int = 20+sources.size()
				if phase == 0:
					source.fill(Color8(value,240-value,0))
				else:
					for index: int in range(capacity):
						var point := Vector2i(index*64+63,63)
						source.set_pixelv(point,Color8(value,240-value,0))
						regions.append(Rect2i(point,Vector2i.ONE))
				sources.append(source)
				areas.append(regions)
				expected_paths.append({"history":phase == 1,"capacity":capacity if phase != 0 else 256,
					"kind":"history" if phase == 1 else ("full" if phase == 0 else "ordinary")})
	var expected_current: Image = sources[-1].duplicate()
	var expected_previous: Image = sources[-2].duplicate()
	var next_slots := {"full":owner.full_staging.next_slot,
		"history1":owner._history_staging[1].next_slot,"history4":owner._history_staging[4].next_slot,
		"ordinary1":owner.staging[1].next_slot,"ordinary4":owner.staging[4].next_slot}
	var counts := {"history1":0,"history4":0,"ordinary1":0,"ordinary4":0,"full":0}
	var submitted: Array[Dictionary] = []
	var gate: QueueGate = null
	if separate:
		gate = QueueGate.new()
		gate.begin()
	for index: int in range(sources.size()):
		check(owner.publish(sources[index],areas[index]),label+" queued publication%d" % index)
		var update: Dictionary = owner.last_update
		var expected: Dictionary = expected_paths[index]
		var key: String = expected.kind+(str(expected.capacity) if expected.kind != "full" else "")
		check(update.history_copy == expected.history and update.history_staging == expected.history
			and update.atlas_capacity == expected.capacity and update.staging_slot == next_slots[key]
			and update.submitted_bytes > 0,label+" exact class/path/slot%d" % index)
		counts[key] += 1
		next_slots[key] = (int(next_slots[key])+1)%slots
		check(owner.resource_identity() == resources and owner.gpu_storage_bytes() == resident,
			label+" fixed logical resources during queued publication%d" % index)
		var comparable: Dictionary = {}
		for field: String in SUBMISSION_FIELDS: comparable[field] = update.get(field)
		submitted.append(comparable)
	# Queued RenderingServer calls must own immutable bytes independently of
	# these mutable source Images, including after repeated ring wraps.
	for original: Image in sources: original.fill(Color.BLACK)
	sources.clear()
	source = null
	if gate != null:
		gate.end()
		check(gate.was_render_owner and not gate.expired,label+" bounded rendering gate did not synchronize")
	for key: String in ["history1","history4","ordinary1","ordinary4"]:
		check(int(counts[key]) == turns and int(counts[key]) > slots,label+" wraps "+key+" beyond ring depth")
	var gpu: Dictionary = _histories(owner,expected_current,expected_previous,label+" burst completion")
	var result := {"channels":channels,"slots":slots,"policy":policy,"extent":[size.x,size.y],
		"separate":separate,"render_gate_completed":gate != null and not gate.expired,
		"counts":counts,"queued_publications":submitted.size(),"submissions":submitted,
		"resource_count":resources.size(),"allocated_gpu_bytes":resident,
		"current_sha256":gpu.current_sha256,"previous_sha256":gpu.previous_sha256,
		"expected_current_sha256":_hash(expected_current.get_data()),"expected_previous_sha256":_hash(expected_previous.get_data()),
		"verified":failures.size() == initial_failures}
	queued_observations.append(result)
	return result


func _run() -> void:
	var prior_policy: String = OS.get_environment(POLICY_ENV)
	var prior_slots: String = OS.get_environment(SLOTS_ENV)
	var prior_copy: String = OS.get_environment(COPY_ENV)
	OS.set_environment(COPY_ENV,"runs")
	separate = not RenderingServer.is_on_render_thread()
	var requested_thread: String = OS.get_environment("CYBERSAND_MATERIAL_QUEUE_THREAD")
	check(requested_thread in ["safe","separate"] and separate == (requested_thread == "separate"),
		"requested and actual rendering ownership agree")
	if not Publisher.supported_driver():
		check(false,"graphical supported Compatibility renderer required; headless cannot qualify GPU histories")
	else:
		for fixture: Dictionary in FIXTURES:
			var variants: Array[Vector2i] = [Vector2i(2,3)]
			if fixture.name == "padded-small":
				variants = [Vector2i(1,1),Vector2i(1,2),Vector2i(1,3),Vector2i(2,1),Vector2i(2,2),Vector2i(2,3)]
			for variant: Vector2i in variants:
				var eager: Dictionary = _case(fixture,variant.x,variant.y,"")
				await process_frame
				var reachable: Dictionary = _case(fixture,variant.x,variant.y,"reachable")
				if not eager.is_empty() and not reachable.is_empty():
					check(eager.submissions == reachable.submissions,
						fixture.name+" policy preserves every actual submission shape, byte count and slot choice")
					check(eager.current_sha256 == reachable.current_sha256 and eager.previous_sha256 == reachable.previous_sha256,
						fixture.name+" policy preserves both complete final histories")
				await process_frame
		# Unknown launch text must not silently enable the experimental policy.
		var unknown: Dictionary = _case(FIXTURES[0],1,1,"unrecognized")
		check(not unknown.is_empty() and unknown.get("policy") == "eager","unknown selector retains ordinary eager allocation")
		for channels: int in [1,2]:
			for slots: int in [1,2,3]:
				var eager: Dictionary = _queued_history_case(channels,slots,"eager")
				await process_frame
				var reachable: Dictionary = _queued_history_case(channels,slots,"reachable")
				check(not eager.is_empty() and not reachable.is_empty() and eager.submissions == reachable.submissions
					and eager.current_sha256 == reachable.current_sha256 and eager.previous_sha256 == reachable.previous_sha256,
					"queued policies preserve submissions and both complete GPU histories")
				await process_frame
	OS.set_environment(POLICY_ENV,prior_policy)
	OS.set_environment(SLOTS_ENV,prior_slots)
	OS.set_environment(COPY_ENV,prior_copy)
	var report := {"schema":"material-staging-reachability-v1","checks":checks,"failures":failures,
		"source_sha":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"source_files":{"res://scripts/blit_material_publisher.gd":FileAccess.get_sha256("res://scripts/blit_material_publisher.gd"),
			"res://tests/test_material_staging_reachability.gd":FileAccess.get_sha256("res://tests/test_material_staging_reachability.gd")},
		"engine":Engine.get_version_info(),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"platform":OS.get_name(),"display":DisplayServer.get_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"render_thread_inline":RenderingServer.is_on_render_thread(),
		"observations":observations,"queued_observations":queued_observations,
		"scope":"Actual complete GPU histories, bounded queued ring reuse and fixed setup-only logical texture ownership. Texture identity does not establish absence of driver allocations. No native/Rapier progression or timing acceptance. Original square/landscape cases save zero allocation bytes."}
	var output: String = OS.get_environment("CYBERSAND_MATERIAL_STAGING_REACHABILITY_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var writer := FileAccess.open(output,FileAccess.WRITE)
		if writer == null:
			check(false,"could not write source-bound report")
		else:
			writer.store_string(JSON.stringify(report,"  ")+"\n")
	print("MATERIAL_STAGING_REACHABILITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"cases":observations.size()}))
	quit(int(not failures.is_empty()))
