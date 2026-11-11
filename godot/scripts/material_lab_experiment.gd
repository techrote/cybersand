class_name CyberMaterialLabExperiment
extends RefCounted

# A small exclusive owner of the existing MicroScenario host. It never borrows
# the Workbench World or installs candidate material IDs into production cells.
const Contract = preload("res://scripts/microscenario_contract.gd")
const Pack = preload("res://scripts/microscenario_reference_pack.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Identity = preload("res://scripts/microscenario_identity.gd")
const Appearance = preload("res://scripts/material_appearance_lut.gd")
const MAX_STEPS: int = 64
const MAX_DURATION: int = 600
const CASE_SCHEMA: String = "cybersand.material-lab.experiment"
const CASE_KEYS: Array[String] = ["schema_id","schema_version","definition","definition_hash","workers",
	"water_family","native_sha256","host_scripts_sha256","lab_script_sha256","digest"]
const DEFAULT_REGION := Rect2i(168, 56, 148, 200)
const WATER_FAMILIES: Array[String] = ["default", "freemass_v1", "cellular_yield_v1"]

var last_error: String = ""
var world: Variant
var _bridge: Variant
var _host: RefCounted
var _definition: Dictionary = {}
var _region: Rect2i = DEFAULT_REGION
var _workers: int = 1
var _water_family: String = "default"
var _readback: Dictionary = {}
var _preview: Image
var _readback_tick: int = -1
var _construction_identity: Dictionary = {}
var _prepared_pair: Dictionary = {}
var _reference: RefCounted
var _reference_target: int = -1
var _reference_current: Dictionary = {}
var _reference_result: Dictionary = {}

static func _valid_material(id: int) -> bool:
	return id >= 0 and id < Contract.MATERIAL_COUNT and id != 10

static func definition_for_pair(first: int, second: int, seed: int = 2,
		duration: int = 120) -> Dictionary:
	if not _valid_material(first) or not _valid_material(second) \
		or seed < 0 or seed > 0x7FFFFFFF or duration < 1 or duration > MAX_DURATION:
		return {}
	# Reuse accepted controlled fixtures where the selected geometry is known.
	# Ordering is retained: selecting Water above Salt is a different experiment.
	if second == 3 and first in [2, 8, 23] and duration == 120:
		return Pack.interaction_fixture({2:"sand-water", 8:"lava-water", 23:"salt-water"}[first], seed, 32)
	var out: Dictionary = Pack.base("materials/authoring-pair", seed,
		"Materials Lab / %d + %d" % [first, second], "bounded-pair/v1", duration,
		"Existing native materials in an enclosed bay. The upper dose is released at tick 12 when the requested window permits it. Read stored native cells and the completed-tick counters. No reaction is guaranteed; the resolver preview does not observe World eligibility.")
	out.camera_origin = [168, 56]
	out.interest = {"policy":"fixed", "region":[168,56,148,200]}
	out.source_recipe = "MAT-AUTH Materials Lab / ordinary schema-2 pair fixture v1"
	out.rectangles = [176,64,4,184,1, 304,64,4,184,1, 176,244,132,4,1, 176,64,132,4,1,
		214,140,56,3,1, 224+seed%5,128,32,12,first]
	if second == 3:
		out.partial_water_fills = [180,192,124,52,255,0]
	else:
		out.rectangles.append_array([180,192,124,52,second])
	if duration > 12: out.events = [Pack.erase(12,214,140,56,3)]
	out.presentation.regions = [Pack.region("contact", "%d + %d / NATIVE" % [first,second], [176,64,132,184])]
	out.observations = [Pack.observe("first-initial",0,"material_cells",[180,68,124,176],first),
		Pack.observe("second-initial",0,"material_cells",[180,68,124,176],second),
		Pack.observe("dose-state",0,"cell_state",[224+seed%5,134,1,1],first),
		Pack.observe("first-final",duration,"material_cells",[180,68,124,176],first),
		Pack.observe("second-final",duration,"material_cells",[180,68,124,176],second),
		Pack.observe("reservoir-state",duration,"cell_state",[182,238,1,1],second),
		Pack.observe("end",duration,"tick",[0,0,1,1])]
	out.conditions = [{"observation":"end","comparison":"eq","value":duration,"outcome":"complete"}]
	return Pack.finish(out)

static func resolver_diagnostic(first: int, second: int, roll: int) -> Dictionary:
	if not _valid_material(first) or not _valid_material(second) or roll < 0 or roll > 255:
		return {"ok":false, "error":"Select allocated native IDs other than reserved 10 and a roll from 0 through 255."}
	if not ClassDB.class_exists(&"CyberDemoBridge"):
		return {"ok":false, "error":"Native interaction inspection is unavailable; no fallback reaction is inferred."}
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.has_method(&"inspect_interaction"):
		return {"ok":false, "error":"Rebuild the current native interaction inspection adapter."}
	var result: Dictionary = bridge.inspect_interaction(first, second, roll)
	if not result.get("ok",false): return result
	result["world_eligibility"] = "unobserved: scheduling, masks, inactivity and specialized competition are not resolver inputs"
	result["diagnostic_scope"] = "native sparse pair resolver only; no World mutation"
	if not result.get("matched",false):
		result["outcome"] = "no_matching_rule"
		result["explanation"] = "No sparse pair rule matches these positional IDs. Specialized kernels and movement may still act."
	else:
		var threshold: int = int(result.probability_threshold)
		result["probability_numerator"] = threshold + 1
		result["probability_denominator"] = 256
		result["outcome"] = "selected_reaction" if result.selected else "failed_probability_roll"
		result["explanation"] = "Roll %d %s threshold %d: %s; exact probability %d/256. Threshold zero remains 1/256." % [
			roll, "≤" if result.selected else ">", threshold,
			"selected" if result.selected else "not selected", threshold+1]
		result["endpoint_effect"] = "replace_with_defaults (legacy World initialization; same-ID products do not imply preservation)"
		result["quantity_scope"] = "Resolver products only. Native World performs target then source writes and its own quantity accounting."
	return result

static func _recognize_pair(checked: Dictionary) -> Dictionary:
	# Imported MicroScenarios may contain arbitrary supported arrangements. Only
	# restore the two-material controls when the complete definition is exactly
	# one of this Lab's generated fixtures, rather than guessing from its title.
	var definition: Dictionary = checked.definition
	var first: int = -1
	var second: int = -1
	if str(definition.id) == "materials/authoring-pair":
		for observation: Dictionary in definition.observations:
			if observation.id == "first-initial": first = int(observation.material)
			if observation.id == "second-initial": second = int(observation.material)
	else:
		first = int({"materials/salt-water":23,"materials/lava-water":8,"materials/sand-water-control":2}.get(str(definition.id),-1))
		second = 3
	if not _valid_material(first) or not _valid_material(second): return {}
	var generated: Dictionary = Contract.validate(definition_for_pair(first,second,int(definition.seed),int(definition.presentation.duration_ticks)))
	if not generated.get("ok",false) or str(generated.hash) != str(checked.hash): return {}
	return {"first":first,"second":second}

func configuration() -> Dictionary:
	if not active(): return {"ok":false,"error":"No native experiment is active."}
	return {"ok":true,"definition_id":str(_definition.id),"title":str(_definition.presentation.title),
		"definition_hash":str(_host.summary().definition_hash),"seed":int(_definition.seed),
		"duration_ticks":int(_definition.presentation.duration_ticks),"workers":int(world.get_worker_threads()),
		"water_family_request":_water_family,"pair":_prepared_pair.duplicate(true)}

func _current_source_identity() -> Dictionary:
	var identity: Dictionary = Identity.current()
	identity["material_lab_experiment_sha256"] = FileAccess.get_sha256("res://scripts/material_lab_experiment.gd")
	identity["material_lab_identity_scope"] = "File fingerprints observed around native construction and rechecked before export/capture; mapped-module identity is not independently measured."
	return identity

static func _same_source_identity(left: Dictionary, right: Dictionary) -> bool:
	for key: String in ["native_sha256", "script_set_sha256", "material_lab_experiment_sha256"]:
		if not left.has(key) or not right.has(key) or left[key] != right[key]: return false
	return true

static func _source_identity_available(identity: Dictionary) -> bool:
	for key: String in ["native_sha256", "script_set_sha256", "material_lab_experiment_sha256"]:
		if not identity.get(key) is String or str(identity[key]).length() != 64: return false
	for fingerprint: Variant in identity.get("script_sha256", {}).values():
		if not fingerprint is String or str(fingerprint).length() != 64: return false
	return not identity.get("script_sha256", {}).is_empty()

func _ensure_source_identity() -> bool:
	if _construction_identity.is_empty() or not _same_source_identity(_construction_identity, _current_source_identity()):
		return _refuse("Source/runtime files changed since this experiment was constructed. Reopen the matching build and prepare a fresh experiment before exporting, capturing or comparing it; the current native run is preserved.")
	last_error = ""
	return true

func start(definition: Dictionary, workers: int = 1, water_family: String = "default") -> bool:
	return _start_with_identity(definition, workers, water_family, {})

func _start_with_identity(definition: Dictionary, workers: int, water_family: String, expected_identity: Dictionary) -> bool:
	# Validate all inputs and finish installation in a fresh owner before swapping
	# our retained experiment. Rejected imports preserve the current run exactly.
	var checked: Dictionary = Contract.validate(definition)
	if not checked.get("ok",false):
		return _refuse(str(checked.get("error","Invalid MicroScenario definition")))
	if workers not in [1,4]: return _refuse("Materials Lab supports explicit 1- or 4-worker experiments.")
	if water_family not in WATER_FAMILIES:
		return _refuse("Unsupported Water family. Choose current defaults, FreeMass or CellularYield; no envelope is guessed.")
	var candidate: Dictionary = checked.definition
	if int(candidate.schema_version) != 2 or candidate.player_enabled or candidate.body_enabled \
		or candidate.execution.policy != "fixed" or candidate.interest.policy != "fixed":
		return _refuse("The Lab requires an actor-free schema-2 fixture with fixed execution and interest.")
	if int(candidate.presentation.duration_ticks) < 1 or int(candidate.presentation.duration_ticks) > MAX_DURATION:
		return _refuse("The Lab test window must be 1 through 600 ticks.")
	if str(candidate.id) == Contract.WORKBENCH_ID:
		return _refuse("Shared Workbench definitions belong to its existing owner; import a bounded MicroScenario fixture.")
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		return _refuse("Current native World and MicroScenario bridge are required. This test does not substitute a fallback.")
	var identity_before: Dictionary = _current_source_identity()
	if not _source_identity_available(identity_before):
		return _refuse("Native artifact or host source fingerprints are unavailable; use the complete matching checkout to construct a reproducible Lab experiment.")
	if not expected_identity.is_empty() and not _same_source_identity(identity_before, expected_identity):
		return _refuse("Saved experiment source/runtime changed before reconstruction; the prior experiment is preserved.")
	var next_bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	for method: StringName in [&"inspect_cell", &"inspect_statistics", &"inspect_interaction"]:
		if not next_bridge.has_method(method): return _refuse("Rebuild the native observation adapter: missing " + str(method))
	var request: Variant = null
	var validation: Dictionary = {}
	if water_family != "default":
		if not next_bridge.has_method(&"liquid_policy_assignment_choices"):
			return _refuse("The native runtime has no supported solver-selection API.")
		var defaults: PackedInt32Array = next_bridge.default_liquid_policy()
		for choice: Dictionary in next_bridge.liquid_policy_assignment_choices(defaults,3):
			if str(choice.family) == water_family and str(choice.variant) == "reference":
				if not choice.accepted:
					return _refuse("Native policy refusal: " + str(choice.refusal))
				request = choice.request
				validation = choice.receipt
				break
		if request == null: return _refuse("This runtime does not expose the requested Water family.")
	var next_world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not next_world.diagnostic_reset({"workers":workers}):
		return _refuse("Native reset rejected the explicit worker count.")
	var next_host: RefCounted = Host.new()
	if not next_host.install(next_world, candidate, "Inspect", true, request):
		return _refuse(str(next_host.last_error))
	if not validation.is_empty() and next_host.liquid_solver_policy().get("policy_hash", "") != validation.get("policy_hash", "missing"):
		return _refuse("Native applied policy did not acknowledge the validated request; prior experiment preserved.")
	if not _same_source_identity(identity_before, _current_source_identity()):
		return _refuse("Source/runtime files changed during native construction; no new experiment was installed. Reopen the matching build and retry.")
	cancel_reference("Prepared a different native experiment.")
	_reference_result.clear()
	world = next_world
	_bridge = next_bridge
	_host = next_host
	_definition = candidate.duplicate(true)
	_workers = workers
	_water_family = water_family
	_construction_identity = identity_before.duplicate(true)
	_prepared_pair = _recognize_pair(checked)
	var interest: Array = candidate.interest.region
	# Rendering/readback stays bounded even for an imported large fixture.
	_region = Rect2i(int(interest[0]), int(interest[1]), mini(320,int(interest[2])), mini(240,int(interest[3])))
	if candidate.source_recipe.begins_with("MS-001 reference-pack/"):
		_region = DEFAULT_REGION
	_readback_tick = -1
	_readback = {}
	_preview = null
	last_error = ""
	return true

func start_json(text: String, workers: int = 1, water_family: String = "default") -> bool:
	var parsed: Dictionary = _parse_unique_json(text)
	if not parsed.get("ok",false): return _refuse(str(parsed.error))
	var checked: Dictionary = Contract.validate(parsed.value)
	if not checked.get("ok",false): return _refuse(str(checked.get("error","Malformed test case")))
	return start(checked.definition, workers, water_family)

static func _parse_unique_json(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > Contract.MAX_JSON_BYTES:
		return {"ok":false,"error":"Test case exceeds the 1 MiB JSON byte budget."}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok":false,"error":"Malformed JSON at line %d: %s" % [parser.get_error_line(),parser.get_error_message()]}
	# Godot JSON deliberately keeps the last duplicate key. An authoring import
	# must instead reject ambiguous source. Scan already-validated JSON tokens;
	# decode quoted keys through the same parser so escaped aliases also collide.
	var containers: Array = []
	var index: int = 0
	while index < text.length():
		var token: String = text[index]
		if token == "{" or token == "[":
			containers.append({} if token == "{" else null)
		elif token == "}" or token == "]":
			containers.pop_back()
		elif token == '"':
			var first: int = index
			index += 1
			while index < text.length():
				if text[index] == "\\": index += 2
				elif text[index] == '"': break
				else: index += 1
			var next: int = index + 1
			while next < text.length() and text[next] in [" ","\t","\r","\n"]: next += 1
			if next < text.length() and text[next] == ":" and not containers.is_empty() and containers.back() is Dictionary:
				var key: String = str(JSON.parse_string(text.substr(first,index-first+1)))
				if containers.back().has(key): return {"ok":false,"error":"Duplicate JSON object key: " + key}
				containers.back()[key] = true
		index += 1
	return {"ok":true,"value":parser.data}

func active() -> bool:
	return _host != null and _host.active()

func completed_tick() -> int:
	return int(world.get_tick_index()) if active() else 0

func completed() -> bool:
	return active() and int(world.get_tick_index()) >= int(_definition.presentation.duration_ticks)

func step(count: int = 1) -> bool:
	if not active(): return _refuse("Create or import a native experiment first.")
	if count < 1 or count > MAX_STEPS:
		return _refuse("One UI step request must contain 1 through 64 native ticks.")
	if world.has_failed(): return _refuse("Native experiment is quarantined; create a fresh experiment.")
	var remaining: int = int(_definition.presentation.duration_ticks) - int(world.get_tick_index())
	if remaining > 0: cancel_reference("The source experiment advanced; repeat from its new completed tick.")
	for index: int in range(mini(count,remaining)):
		if not _host.advance(): return _refuse(str(_host.last_error))
	last_error = ""
	return true

func inspect_cell(point: Vector2i) -> Dictionary:
	if not active(): return {"ok":false,"error":"No native experiment is active."}
	return _bridge.inspect_cell(world, point)

func readback() -> Dictionary:
	if not active(): return {"ok":false,"error":"No native experiment is active."}
	if world.has_failed(): return {"ok":false,"error":"Native experiment is quarantined; partial state is not reported as successful."}
	var tick: int = int(world.get_tick_index())
	if _readback_tick == tick: return _readback.duplicate(true)
	# get_cells() is a copied native material-ID buffer, not GPU colour inference.
	# This owner has no body masks. The detailed point probe uses stored_cell APIs.
	var cells: PackedByteArray = world.get_cells()
	if cells.size() != Contract.SIDE * Contract.SIDE:
		return {"ok":false,"error":"Native material readback has an unexpected extent."}
	var counts: Dictionary = {}
	var pixels := PackedByteArray()
	pixels.resize(_region.size.x * _region.size.y * 4)
	var offset: int = 0
	for y: int in range(_region.position.y, _region.end.y):
		for x: int in range(_region.position.x, _region.end.x):
			var id: int = int(cells[y * Contract.SIDE + x])
			counts[str(id)] = int(counts.get(str(id),0)) + 1
			var rgba: int = Appearance.BASE_RGBA8[id] if id < Appearance.MATERIAL_COUNT else 0xFF00FFFF
			pixels[offset] = (rgba >> 24) & 255
			pixels[offset+1] = (rgba >> 16) & 255
			pixels[offset+2] = (rgba >> 8) & 255
			pixels[offset+3] = 255
			offset += 4
	_preview = Image.create_from_data(_region.size.x,_region.size.y,false,Image.FORMAT_RGBA8,pixels)
	var native: Dictionary = world.water_experiment_observation(Vector2i.ZERO, Vector2i(Contract.SIDE,Contract.SIDE))
	_readback = {"ok":true,"backend":"native World / existing MicroScenario host",
		"definition_id":str(_definition.id),"definition_title":str(_definition.presentation.title),
		"completed_tick":tick,"duration_ticks":int(_definition.presentation.duration_ticks),
		"completed":completed(),"seed":int(_definition.seed),"workers":int(world.get_worker_threads()),
		"water_family_request":_water_family,
		"definition_hash":str(_host.summary().definition_hash),
		"material_counts":counts,"count_region":[_region.position.x,_region.position.y,_region.size.x,_region.size.y],
		"native":native,"statistics":_bridge.inspect_statistics(world),
		"applied_policy":_host.liquid_solver_policy(),
		"stored_probe":inspect_cell(Vector2i(182,238)),
		"preview_scope":"Copied native material IDs with current Godot base palette; image is not the quantitative acceptance oracle.",
		"activity_scope":"Completed-tick/global activity counters only; per-cell sleeping and future deadlines are unavailable.",
		"seed_scope":"Definition seed controls fixture geometry; native deterministic coordinates/tick streams remain the existing engine law.",
		"runtime_scope":"Separate test World only; Workbench and production catalogue are unchanged."}
	_readback_tick = tick
	return _readback.duplicate(true)

func preview_image() -> Image:
	if not readback().get("ok",false): return null
	return _preview.duplicate() as Image

func capture(source_revision: String = "unavailable") -> Dictionary:
	if not active(): return {"ok":false,"error":"No native experiment is active."}
	if not _ensure_source_identity(): return {"ok":false,"error":last_error}
	var identity: Dictionary = _construction_identity.duplicate(true)
	identity["source_revision"] = source_revision
	identity["revision_status"] = "caller-supplied" if source_revision != "unavailable" else "not-embedded"
	var report: Dictionary = _host.capture(identity)
	report["material_lab_schema_version"] = 1
	report["ok"] = not report.get("failed",true)
	report["readback"] = readback()
	report["water_family_request"] = _water_family
	report["reproduction"] = "Reconstruct this complete definition with the recorded worker count, family request and matching source/runtime; this report is not a live-state save."
	return report

func definition_json() -> String:
	if not active(): return ""
	var checked: Dictionary = Contract.validate(_definition)
	return str(checked.canonical_json) if checked.get("ok",false) else ""

static func _case_payload(checked: Dictionary, workers: int, family: String, identity: Dictionary) -> Dictionary:
	return {"schema_id":CASE_SCHEMA,"schema_version":1,"definition":checked.definition,
		"definition_hash":str(checked.hash),"workers":workers,"water_family":family,
		"native_sha256":str(identity.native_sha256),"host_scripts_sha256":str(identity.script_set_sha256),
		"lab_script_sha256":str(identity.material_lab_experiment_sha256)}

func case_json() -> String:
	if not active(): return ""
	if not _ensure_source_identity(): return ""
	var checked: Dictionary = Contract.validate(_definition)
	var payload: Dictionary = _case_payload(checked,_workers,_water_family,_construction_identity)
	payload["digest"] = JSON.stringify(payload,"",true).sha256_text()
	return JSON.stringify(payload,"\t",true) + "\n"

func start_case_json(text: String) -> bool:
	var parsed: Dictionary = _parse_unique_json(text)
	if not parsed.get("ok",false): return _refuse(str(parsed.error))
	var value: Variant = parsed.value
	if not value is Dictionary or value.size() != CASE_KEYS.size(): return _refuse("Missing or unknown Materials Lab test-case field.")
	for key: String in CASE_KEYS:
		if not value.has(key): return _refuse("Missing Materials Lab test-case field: " + key)
	if value.schema_id != CASE_SCHEMA or not Contract._integer(value.schema_version,1,1):
		return _refuse("Unsupported Materials Lab test-case schema.")
	if not Contract._integer(value.workers,1,4) or int(value.workers) not in [1,4] or not value.water_family in WATER_FAMILIES:
		return _refuse("Unsupported saved worker/family configuration.")
	var checked: Dictionary = Contract.validate(value.definition)
	if not checked.get("ok",false): return _refuse(str(checked.get("error","Invalid saved definition")))
	if str(value.definition_hash) != str(checked.hash): return _refuse("Saved definition digest does not match its bytes.")
	var identity: Dictionary = {"native_sha256":value.native_sha256,"script_set_sha256":value.host_scripts_sha256,
		"material_lab_experiment_sha256":value.lab_script_sha256}
	var payload: Dictionary = _case_payload(checked,int(value.workers),str(value.water_family),identity)
	if not value.digest is String or str(value.digest) != JSON.stringify(payload,"",true).sha256_text():
		return _refuse("Saved test-case digest mismatch; the case has been edited or corrupted.")
	if not _same_source_identity(identity, _current_source_identity()):
		return _refuse("Test case belongs to another native artifact or host source. Use its matching build, or explicitly create a new experiment from its definition.")
	return _start_with_identity(checked.definition,int(value.workers),str(value.water_family),identity)

func begin_reference() -> Dictionary:
	# Construct one exclusive reference owner; the UI advances it a tick per
	# frame so Pause, Close and progress rendering remain available.
	if not active(): return {"ok":false,"error":"No native experiment is active."}
	if not _ensure_source_identity(): return {"ok":false,"error":last_error}
	var current: Dictionary = readback()
	if not current.get("ok",false): return current
	var reference: RefCounted = get_script().new()
	if not reference._start_with_identity(_definition,_workers,_water_family,_construction_identity):
		return {"ok":false,"error":reference.last_error}
	cancel_reference("Restarted the reference comparison.")
	_reference = reference
	_reference_target = int(current.completed_tick)
	_reference_current = current
	_reference_result.clear()
	return reference_progress()

func reference_running() -> bool:
	return _reference != null

func reference_progress() -> Dictionary:
	if not reference_running(): return _reference_result.duplicate(true)
	return {"ok":true,"status":"running","completed_tick":int(_reference.world.get_tick_index()),
		"target_tick":_reference_target,"definition_hash":_reference_current.definition_hash,
		"scope":"Fresh native reference; the source run stays paused at its recorded completed tick."}

func _finish_reference(result: Dictionary) -> Dictionary:
	if _reference != null: _reference.close()
	_reference = null
	_reference_current.clear()
	_reference_result = result.duplicate(true)
	return result

func cancel_reference(reason: String = "Reference comparison cancelled.") -> void:
	if not reference_running(): return
	_finish_reference({"ok":false,"status":"cancelled","error":reason,
		"completed_tick":int(_reference.world.get_tick_index()),"target_tick":_reference_target})

func advance_reference(count: int = 1) -> Dictionary:
	if not reference_running(): return reference_progress()
	if count < 1 or count > MAX_STEPS:
		return {"ok":false,"error":"One reference step request must contain 1 through 64 native ticks."}
	if not active() or int(world.get_tick_index()) != _reference_target:
		return _finish_reference({"ok":false,"status":"failed","error":"Source experiment changed during reference replay; repeat from the current run."})
	var remaining: int = _reference_target - int(_reference.world.get_tick_index())
	if remaining > 0 and not _reference.step(mini(count,remaining)):
		return _finish_reference({"ok":false,"status":"failed","error":str(_reference.last_error)})
	if int(_reference.world.get_tick_index()) < _reference_target: return reference_progress()
	# Observe file custody at both ends of the replay. Rehashing the native
	# library on every UI frame would turn a cold-path check into hot-path work.
	if not _ensure_source_identity():
		return _finish_reference({"ok":false,"status":"failed","error":last_error})
	var repeated: Dictionary = _reference.readback()
	if not repeated.get("ok",false): return _finish_reference(repeated)
	var equality: bool = _reference_current.native.content_hash == repeated.native.content_hash \
		and _reference_current.native.water_integer == repeated.native.water_integer \
		and _reference_current.material_counts == repeated.material_counts
	return _finish_reference({"ok":true,"status":"complete","equal":equality,
		"completed_tick":_reference_target,"target_tick":_reference_target,"definition_hash":_reference_current.definition_hash,
		"current_content_hash":_reference_current.native.content_hash,"reference_content_hash":repeated.native.content_hash,
		"current_water_integer":_reference_current.native.water_integer,"reference_water_integer":repeated.native.water_integer,
		"scope":"Fresh reconstruction at the same tick, source, complete definition, family request and worker count; no timing counters compared."}
	)

func repeat_reference() -> Dictionary:
	# Synchronous compatibility helper for CLI/tests. Mounted UI callers use
	# begin_reference/advance_reference and never run the whole window at once.
	var result: Dictionary = begin_reference()
	if not result.get("ok",false): return result
	while reference_running(): result = advance_reference(MAX_STEPS)
	return result

func close() -> void:
	cancel_reference("Native experiment closed.")
	_reference_result.clear()
	if _host != null: _host.clear()
	_host = null
	world = null
	_bridge = null
	_definition.clear()
	_construction_identity.clear()
	_prepared_pair.clear()
	_readback.clear()
	_preview = null
	_readback_tick = -1

func _refuse(message: String) -> bool:
	last_error = message
	return false
