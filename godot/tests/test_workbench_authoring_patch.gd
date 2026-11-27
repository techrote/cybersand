extends SceneTree

# Real native prepare/commit boundary. Interactive composition history and
# Save/close/reopen have their own Main/Workbench campaign; no fake World here.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const EXTENT := Vector2i(512,512)
var checks := 0
var failures: Array[String] = []
var refused: Array[Dictionary] = []
var bridge: Variant
var world: Variant
var checked: Dictionary
var policy := PackedInt32Array()
var baseline := PackedByteArray()
var build_receipt: Dictionary
var negative_cases_completed := false
var transaction_cases_completed := false
var host_forwarding_completed := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WORKBENCH_AUTHORING_PATCH: " + label)
	return ok

func options(retain: bool = true) -> Dictionary:
	return {"definition_hash":checked.hash,"seed":checked.definition.seed,
		"region":PackedInt32Array([0,0,EXTENT.x,EXTENT.y]),
		"intent":"exploratory","pacing":"host_paced","cadence_lod_enabled":false,
		"liquid_surface_adhesion_enabled":true,"initial_bodies":PackedFloat32Array(),
		"workbench_extent":EXTENT,"workbench_response":"LA-SELECTIVE",
		"workbench_sample":{"session":1,"epoch":1,"states":PackedFloat64Array(),
			"geometry":PackedFloat64Array(),"bodies":[]},
		"workbench_worker_threads":1,"workbench_retain_cells":retain}

func prepare(patch: Dictionary, settings: Dictionary = {}, words := PackedInt32Array()) -> int:
	if settings.is_empty(): settings = options()
	settings["workbench_authoring_patch"] = patch
	return bridge.prepare_liquid_world(world,words,checked.transport.packed,
		PackedInt32Array(checked.definition.water_semantics),PackedInt32Array(),policy,settings)

func capture() -> Dictionary:
	return bridge.capture_material_baseline(world)

func state() -> Dictionary:
	return {"physical_hash":world.get_physical_state_hash(),"generation":world.get_liquid_policy_session_generation(),
		"revision":world.get_revision(),"tick":world.get_tick_index(),
		"receipt":world.get_applied_liquid_construction_receipt(),"material_sha256":capture().sha256}

func proposal(operation: String = "build") -> Dictionary:
	var source := capture()
	return {"schema":1,"operation":operation,"native_generation":source.native_generation,
		"revision":source.revision,"tick":source.tick,"extent":source.extent,
		"cells":PackedInt32Array([80,80,62,81,80,65,82,80,13]),
		"before":PackedInt32Array([0,0,0]),"protected":PackedInt32Array([79,79,79,80,79,81]),
		"proposal_sha256":"1".repeat(64)}

func refusal(label: String, patch: Dictionary, settings: Dictionary = {}, words := PackedInt32Array()) -> void:
	var before := state()
	var token := prepare(patch,settings,words)
	var reason: String = bridge.get_last_error()
	check(token == 0 and not reason.is_empty(),label+" refuses with a native reason")
	if token > 0: bridge.discard_liquid_world(world,token)
	check(state() == before,label+" keeps every old source fence, material and receipt")
	refused.append({"case":label,"reason":reason,"no_live_change":state()==before})

func negative_cases() -> void:
	var original: Dictionary = world.get_material_audition_state()
	var override_profile := {"schema_version":1,"profile_id":"patch-admission","materials":[{"material_id":2,"density":500}],"reactions":[]}
	var activated: Dictionary = world.apply_material_audition({"world_id":original.world_id,"expected_revision":original.revision,"profile":override_profile})
	if not check(activated.get("ok",false) and world.get_material_audition_state().changes_behavior, "live native profile is active before patch admission"): return
	var active: Dictionary = world.get_material_audition_state()
	refusal("patch cannot retire an active material profile",proposal())
	check(world.get_material_audition_state() == active,"refused patch preserves exact configured material authority")
	var restored: Dictionary = world.apply_material_audition({"world_id":active.world_id,"expected_revision":active.revision,"profile":original.profile})
	if not check(restored.get("ok",false) and not world.get_material_audition_state().changes_behavior,"explicit reset admits ordinary default-law patch checks"): return
	var valid := proposal()
	var patch := valid.duplicate(true)
	patch["unexpected"] = 1
	refusal("unknown patch field",patch)
	patch = valid.duplicate(true);patch.erase("protected")
	refusal("missing patch field",patch)
	for field: String in ["schema","native_generation","revision","tick"]:
		patch = valid.duplicate(true);patch[field] = float(patch[field])
		refusal("noninteger "+field,patch)
	for field: String in ["native_generation","revision","tick"]:
		patch = valid.duplicate(true);patch[field] += 1
		refusal("stale "+field,patch)
	patch = valid.duplicate(true);patch.extent = Vector2i(512,576)
	refusal("stale extent",patch)
	patch = valid.duplicate(true);patch.operation = "overwrite"
	refusal("unknown operation",patch)
	patch = valid.duplicate(true);patch.proposal_sha256 = "F".repeat(64)
	refusal("noncanonical proposal identity",patch)
	patch = valid.duplicate(true);patch.cells = PackedFloat64Array([80,80,62])
	refusal("narrowing input array",patch)
	patch = valid.duplicate(true);patch.before = PackedInt32Array([0])
	refusal("unaccounted source cells",patch)
	patch = valid.duplicate(true);patch.cells = PackedInt32Array([80,80,62,80,80,62]);patch.before=PackedInt32Array([0,0])
	refusal("duplicate ownership",patch)
	patch = valid.duplicate(true);patch.cells = PackedInt32Array([81,80,62,80,80,62]);patch.before=PackedInt32Array([0,0])
	refusal("noncanonical order",patch)
	patch = valid.duplicate(true);patch.cells = PackedInt32Array([31,31,62,32,32,62]);patch.before=PackedInt32Array([0,0])
	refusal("foreign collision after an otherwise legal cell",patch)
	patch = valid.duplicate(true);patch.cells = PackedInt32Array([32,32,62]);patch.before=PackedInt32Array([58])
	refusal("foreign replacement even when expected ID matches",patch)
	patch = valid.duplicate(true);patch.protected = PackedInt32Array([80,80])
	refusal("protected passage",patch)
	patch = valid.duplicate(true);patch.protected = PackedInt32Array([80,79,80,79])
	refusal("duplicate protected point",patch)
	patch = valid.duplicate(true);patch.cells[2] = 3
	refusal("nonstructural output",patch)
	patch = valid.duplicate(true);patch.cells[2] = 318
	refusal("material cannot wrap to native ID",patch)
	patch = valid.duplicate(true);patch.cells[0] = -1
	refusal("outside native canvas",patch)
	patch = valid.duplicate(true);patch.operation = "remove"
	refusal("invalid inverse direction",patch)
	var settings := options(false)
	refusal("fresh replacement is not authoring patch",valid,settings)
	settings = options();settings.workbench_convert_liquid_inventory = true
	refusal("conversion cannot accompany authoring",valid,settings)
	settings = options();settings.normalization = "threshold_half_up_v1"
	refusal("normalization cannot accompany authoring",valid,settings)
	for field: String in ["workbench_ballistic","workbench_inertial_signed","workbench_wave_flow","workbench_fine_cores","cadence_lod_enabled"]:
		settings = options();settings[field] = true
		refusal("unchanged physical option "+field,valid,settings)
	settings = options();settings.workbench_worker_threads = 2
	refusal("unchanged worker resource budget",valid,settings)
	settings = options();settings.workbench_response = "RFT"
	refusal("unchanged physical response owner",valid,settings)
	settings = options();settings.maximum_rule_radius = 3
	refusal("unchanged execution radius",valid,settings)
	settings = options();settings.liquid_surface_adhesion_enabled = false
	refusal("unchanged liquid adhesion",valid,settings)
	settings = options();settings.simulation_window_enabled = false
	refusal("unchanged simulation window policy",valid,settings)
	settings = options();settings.region = PackedInt32Array([0,0,256,256])
	refusal("unchanged retained simulation region size",valid,settings)
	settings = options();settings.region = PackedInt32Array([64,64,256,256])
	refusal("unchanged retained simulation region origin",valid,settings)
	var original_transport: PackedInt32Array = checked.transport.packed.duplicate()
	checked.transport.packed[1] = 1
	refusal("unchanged native transport descriptor",valid)
	checked.transport.packed = original_transport
	var original_water: Array = checked.definition.water_semantics.duplicate()
	checked.definition.water_semantics[2] = 11
	refusal("unchanged native Water coherence",valid)
	checked.definition.water_semantics = original_water
	settings = options()
	settings.workbench_sample = {"session":2,"epoch":2,
		"states":PackedFloat64Array([1,80,80,0,8,8,0,0,0,1,1,20,80,80,0.4,1.0/60.0,2]),
		"geometry":PackedFloat64Array([0,0,8,8]),
		"bodies":[{"id":1,"instance_id":42,"generation":2,"first_proxy":1,"count":1,
			"budget":20,"gravity":92,"external_drive":false}]}
	settings.initial_bodies = PackedFloat32Array([1,80,80,0,8,8,0,0,0,1,1])
	refusal("prepared physical owner covers proposed cells",valid,settings)
	refusal("alternate terrain cannot accompany authoring",valid,{},PackedInt32Array([4,4,1,1,58]))
	patch = valid.duplicate(true);patch.cells.resize((262144+1)*3);patch.before.resize(262144+1)
	refusal("one cell above finite patch budget",patch)
	patch = valid.duplicate(true);patch.protected.resize((262144+1)*2)
	refusal("one guard above finite patch budget",patch)
	negative_cases_completed = true

func transaction_cases() -> void:
	var patch := proposal()
	var before := state()
	var token := prepare(patch)
	if not check(token > 0,"finite patch prepares against real paused World: "+bridge.get_last_error()): return
	check(state() == before,"prepared candidate has no live-cell or receipt effect")
	var pending: Dictionary = bridge.prepared_liquid_run_capture(world,token).native_run_encoding
	build_receipt = pending.workbench_authoring_patch
	check(build_receipt.changed_cells == 3 and build_receipt.protected_cells == 3
		and build_receipt.proposal_sha256 == patch.proposal_sha256
		and str(build_receipt.patch_sha256).length() == 64
		and build_receipt.source_native_generation == before.generation,
		"prepared receipt accounts for source identity and every patch cell")
	bridge.discard_liquid_world(world,token)
	check(state() == before and not bridge.commit_liquid_world(world,token),
		"cancel frees candidate and a discarded token can never apply")

	token = prepare(patch)
	if not check(token > 0,"same-core execution-region fence fixture prepares"):return
	world.set_simulation_window(Vector2i.ONE,EXTENT-Vector2i(2,2),0,0)
	check(state() == before,"same-core region change is invisible to material and physical-state fences")
	check(not bridge.commit_liquid_world(world,token) and state() == before \
		and "simulation region" in bridge.get_last_error(),
		"native commit independently refuses a changed exact simulation region")
	check(not bridge.commit_liquid_world(world,token),"region-refused preparation token is retired")
	world.set_simulation_window(Vector2i.ZERO,EXTENT,0,0)

	# A changed material source invalidates the existing native commit token even
	# if its replacement geometry is far from the proposed architecture.
	token = prepare(patch)
	check(token > 0,"stale-commit fixture prepares")
	world.emit_disc(8,8,0,58)
	var changed := state()
	check(not bridge.commit_liquid_world(world,token) and state() == changed,
		"native commit fence rejects a source mutated after preparation")
	bridge.discard_liquid_world(world,token)
	world.emit_disc(8,8,0,0)
	check(capture().cells == baseline,"independent stale-commit fixture restored")
	refusal("preview invalidated by a completed native edit",patch)

	patch = proposal()
	before = state()
	token = prepare(patch)
	if not check(token > 0 and bridge.commit_liquid_world(world,token),"accepted patch commits with one native swap"): return
	check(world.get_liquid_policy_session_generation() == int(before.generation)+1 and world.get_tick_index() == 0,
		"accepted retained transaction creates exactly one tick-zero generation")
	var installed := capture()
	var expected := baseline.duplicate()
	for i: int in range(0,patch.cells.size(),3):
		expected.encode_u16((patch.cells[i+1]*EXTENT.x+patch.cells[i])*2,patch.cells[i+2])
	check(installed.cells == expected,"all 262144 native cells equal baseline plus three approved changes")
	check(world.water_experiment_observation(Vector2i(48,48),Vector2i.ONE).water_visible == 37,
		"unrelated fractional native Water survives authoring")
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	check(receipt.workbench_authoring_patch.patch_sha256 == build_receipt.patch_sha256
		and not receipt.workbench_conversion.requested and receipt.normalization.is_empty(),
		"installed patch identity matches prepared bytes without conversion or normalization")
	check(not bridge.commit_liquid_world(world,token),"accepted token cannot commit twice")
	refusal("accepted preview cannot be reused",patch)
	var inverse := proposal("remove")
	inverse.cells = PackedInt32Array([80,80,0,81,80,0,82,80,0])
	inverse.before = PackedInt32Array([62,65,13])
	before = state()
	token = prepare(inverse)
	if check(token > 0 and bridge.commit_liquid_world(world,token),"exact inverse commits atomically"):
		check(capture().cells == baseline and world.get_liquid_policy_session_generation() == int(before.generation)+1,
			"Undo restores the full original material plane in one generation")
		check(world.water_experiment_observation(Vector2i(48,48),Vector2i.ONE).water_visible == 37,
			"Undo retains existing fractional native Water")
	transaction_cases_completed = true

func commit(native_bridge: Variant, token: int) -> bool:
	return native_bridge.commit_liquid_world(world,token)

func host_forwarding_case() -> void:
	var host := Host.new()
	var definition: Dictionary = checked.definition.duplicate(true)
	definition.rectangles.clear()
	var settings := {"intent":"exploratory","normalization":"","workbench_response":"LA-SELECTIVE",
		"workbench_sample":options().workbench_sample,"workbench_worker_threads":1,"workbench_retain_cells":true,
		"workbench_authoring_patch":proposal(),
		"owner_execution":{"region":[0,0,EXTENT.x,EXTENT.y],"simulation_window_enabled":true,
			"cadence_lod_enabled":false,"liquid_surface_adhesion_enabled":true}}
	var before := state()
	if not check(host.install(world,definition,"Play",false,policy,settings,commit),
		"real host forwards retained patch through prepared owner commit: "+host.last_error): return
	check(world.get_liquid_policy_session_generation() == int(before.generation)+1
		and world.material_at(80,80) == 62,"host acknowledgement installs the exact patch once")
	var record: Dictionary = host.liquid_host_observation_record()
	var applied_receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	check(not record.is_empty() and record.identity.native_receipt_hash == applied_receipt.receipt_hash
		and applied_receipt.workbench_authoring_patch.changed_cells == 3,
		"real host observation binds native acknowledgement with its compact patch readback")
	var inverse := proposal("remove")
	inverse.cells = PackedInt32Array([80,80,0,81,80,0,82,80,0])
	inverse.before = PackedInt32Array([62,65,13])
	settings.workbench_authoring_patch = inverse
	check(host.install(world,definition,"Play",false,policy,settings,commit),
		"real host forwards exact inverse with fresh source fences: "+host.last_error)
	check(capture().cells == baseline,"real host Apply and Undo preserve the complete baseline")
	host_forwarding_completed = true

func run() -> void:
	if not check(ClassDB.class_exists(&"CyberDemoBridge") and ClassDB.class_exists(&"CyberNativeCellWorld"),
		"real freshly built native classes are available"):
		finish();return
	bridge = ClassDB.instantiate(&"CyberDemoBridge")
	world = ClassDB.instantiate(&"CyberNativeCellWorld")
	policy = bridge.default_liquid_policy()
	var definition := Contract.base(Contract.WORKBENCH_ID)
	definition.schema_version = 2
	definition["extent"] = [EXTENT.x,EXTENT.y]
	definition["presentation"] = {"title":"Atomic construction patch","instructions":"Native adapter fixture",
		"duration_ticks":1,"baseline":"workbench","profile":"authoring-patch","regions":[]}
	definition.interest = {"policy":"fixed","region":[0,0,EXTENT.x,EXTENT.y]}
	definition.execution.cadence_lod_enabled = false
	definition.rectangles = [32,32,2,2,58]
	checked = Contract.validate(definition)
	if not check(checked.ok,"authored source validates: "+str(checked.get("error",""))):
		finish();return
	var token: int = bridge.prepare_liquid_world(world,PackedInt32Array(definition.rectangles),checked.transport.packed,
		PackedInt32Array(definition.water_semantics),PackedInt32Array(),policy,options(false))
	if not check(token > 0 and bridge.commit_liquid_world(world,token),"native fixture installs: "+bridge.get_last_error()):
		finish();return
	check(world.water_experiment_fill_rect(Vector2i(48,48),Vector2i.ONE,37,2),"fractional existing native Water fixture")
	baseline = capture().cells
	negative_cases()
	check(negative_cases_completed,"all native refusal cases reached completion")
	transaction_cases()
	check(transaction_cases_completed,"complete native transaction sequence reached its inverse")
	if failures.is_empty(): host_forwarding_case()
	check(host_forwarding_completed,"real host forwarding sequence reached completion")
	finish()

func finish() -> void:
	var report := {"schema":1,"completed":true,"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"platform":OS.get_name(),"engine":Engine.get_version_info().get("string","unknown"),
		"native_runtime":bridge.loaded_native_runtime_values() if bridge != null else {},
		"test_script_sha256":FileAccess.get_sha256("res://tests/test_workbench_authoring_patch.gd"),
		"build_receipt":build_receipt,"refusals":refused,
		"scope":"native prepared retained authoring patch; interactive authoring and Save/reopen are separately qualified"}
	var path := OS.get_environment("WB_AUTHORING_PATCH_REPORT")
	if not path.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if check(file != null,"native authoring report can be written"):
			report.checks = checks
			file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WORKBENCH_AUTHORING_PATCH: %d assertions, %d failures" % [checks,failures.size()])
	quit(1 if not failures.is_empty() else 0)
