extends SceneTree

const Host = preload("res://scripts/microscenario_host.gd")
const Contract = preload("res://scripts/microscenario_contract.gd")
const Runner = preload("res://tests/lcb_scenario_runner.gd")
const PATH: String = "res://tests/fixtures/lcb/lcb.dam.water.freemass.reference.v1.json"
var assertions: int = 0
var failures: int = 0
var desktop: Control
var web: Control

class ObservationRefusalHost extends CyberMicroScenarioHost:
	var refuse_observation: bool = false
	func _prepare_liquid_host_observation(bridge: Variant, world: Variant, token: int, checked: Dictionary,
			mode: String, instrumentation: bool, options: Dictionary) -> Dictionary:
		if refuse_observation: return {"ok":false,"error":"fixture declared observation capacity refusal"}
		return super._prepare_liquid_host_observation(bridge,world,token,checked,mode,instrumentation,options)

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1;push_error("LIQUID_OWNER_OBSERVATION: "+message)

func wait_for(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if predicate.call(): return true
	return false

func run() -> void:
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	expect(bridge.has_method(&"prepared_liquid_run_capture"),"fresh native token-bound capture is available")
	if not bridge.has_method(&"prepared_liquid_run_capture"): finish();return
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var checked: Dictionary = Contract.parse(Runner.read_text(PATH).text)
	var policy: PackedInt32Array = bridge.default_liquid_policy()
	var host := ObservationRefusalHost.new()
	expect(host.install(world,checked.definition,"Benchmark",true,policy,{"normalization":"water-normalize-v1"}),
		"actual owner prepares and adopts qualified record with native construction")
	var identity: Dictionary = host.liquid_host_observation()
	if identity.is_empty(): expect(false,"owner observation identity is present");finish();return
	var record: Dictionary = host.liquid_host_observation_record()
	var receipt: Dictionary = world.get_applied_liquid_construction_receipt()
	expect(identity.native_receipt_hash == receipt.receipt_hash and identity.session_generation == receipt.session_generation
		and identity.definition_hash == checked.hash,"owner record binds actual installed native receipt, generation and validated definition")
	expect(record.values.native_applied_run.canonical_bytes_hex == receipt.canonical_bytes.hex_encode()
		and record.canonical_bytes_hex.hex_decode().get_string_from_utf8().sha256_text() == identity.digest,
		"full owner capture retains exact native bytes and canonical host digest")
	expect(not identity.host_eligible_for_full_matched_evidence and not identity.publication_matches_current_path_file
		and record.values.host_claims.values.input_owner == "exclusive_scenario_owner"
		and record.values.host_claims.values.definition_hash == checked.hash,
		"actual owner inputs stay explicitly qualified against the stale local publication")
	var retained_hash: String = world.get_physical_state_hash()
	host.refuse_observation = true
	expect(not host.install(world,checked.definition,"Inspect",true,policy,{"normalization":"water-normalize-v1"}),
		"declared evidence preparation failure refuses before native owner commit")
	expect(world.get_physical_state_hash() == retained_hash and world.get_applied_liquid_construction_receipt() == receipt
		and host.liquid_host_observation() == identity and host.liquid_host_observation_record() == record,
		"preparation refusal retains old World, canonical native receipt and full owner record")
	host.refuse_observation = false
	var retired: Callable = func(_bridge: Variant, _token: int) -> bool:
		return false
	expect(not host.install(world,checked.definition,"Inspect",true,policy,{"normalization":"water-normalize-v1"},retired),
		"final owner fence refuses a fully prepared observation")
	expect(host.liquid_host_observation() == identity and world.get_physical_state_hash() == retained_hash,
		"prepared record never replaces accepted owner identity before successful final fence")
	var captured_report: Dictionary = host.capture({"runtime_hash":"caller","host_eligible_for_full_matched_evidence":true})
	expect(captured_report.liquid_host_observation_record == record and not captured_report.liquid_host_observation.host_eligible_for_full_matched_evidence,
		"explicit capture keeps actual owner record separate from legacy caller identity")
	expect(host.install(world,checked.definition,"Inspect",true,policy,{"normalization":"water-normalize-v1"}),"restart creates actual new owner construction")
	var next: Dictionary = host.liquid_host_observation()
	expect(next.session_generation != identity.session_generation and next.digest != identity.digest
		and next.definition_hash == identity.definition_hash,"restart retains setup while recording actual new generation/native receipt")
	expect(host.install(world,checked.definition,"Inspect") and host.liquid_host_observation().is_empty()
		and host.capture().liquid_host_observation_record.is_empty(),"accepted original constructor retires prepared observation identity")
	host.clear()
	expect(host.liquid_host_observation().is_empty(),"cleared owner retains no observation identity")
	await application(checked.definition,policy)
	await synchronous(checked.definition,policy)
	finish()

func application(definition: Dictionary, _policy: PackedInt32Array) -> void:
	root.size = Vector2i(1600,1000)
	desktop = load("res://main.tscn").instantiate();root.add_child(desktop);await process_frame
	desktop.microscenario_panel.open_liquids()
	var panel: CyberLiquidComparisonPanel = desktop.microscenario_panel.liquid_panel
	panel.select_preset(1)
	expect(not panel.requested_policy.is_empty() and panel._validation.get("accepted",false),"actual normal panel selects whole-cell Water")
	panel.normalize_water.button_pressed = true
	expect(panel.load_selected(),"normal user-selected normalized setup queues through actual owner")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"actual owner acknowledges prepared setup")
	var observed: Dictionary = desktop.tower_context.get("liquid_host_observation",{})
	if observed.is_empty(): expect(false,"normal publication carries compact owner observation identity");desktop.queue_free();await process_frame;return
	expect(await wait_for(func() -> bool: return (observed.native_receipt_hash == desktop.tower_context.liquid_construction_receipt.receipt_hash
		and panel.receipt_label.text.contains("Host record"))),"normal readback carries matching receipt/record identity to the user")
	desktop.microscenario_reset()
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty()),"normal restart acknowledges")
	var restarted: Dictionary = desktop.tower_context.liquid_host_observation
	expect(restarted.definition_hash == observed.definition_hash and restarted.session_generation != observed.session_generation
		and restarted.digest != observed.digest and desktop.microscenario_liquid_setup.normalization == "water-normalize-v1",
		"actual restart retains selected setup/normalization and updates its new construction identity")
	var fractional: Dictionary = definition.duplicate(true)
	fractional.partial_water_fills = [50,100,1,1,127,0]
	expect(desktop.microscenario_apply_controlled_liquid(fractional,desktop.microscenario_liquid_policy,false,"Inspect"),
		"invalid whole-cell replacement reaches actual refusal route")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.tower_context.liquid_host_observation == restarted,"actual refused replacement retains previous owner record")
	expect(desktop.microscenario_apply_definition(definition,"Inspect"),"original default constructor queues")
	expect(await wait_for(func() -> bool: return desktop.pending_microscenario_apply.is_empty())
		and desktop.tower_context.liquid_host_observation.is_empty(),"accepted default route retires prior compact record")
	desktop.queue_free();await process_frame

func synchronous(definition: Dictionary, policy: PackedInt32Array) -> void:
	web = load("res://web_main.tscn").instantiate();root.add_child(web);await process_frame
	expect(web.microscenario_apply_controlled_liquid(definition,policy,true,"Inspect"),"synchronous owner adopts prepared observation")
	var observed: Dictionary = web.tower_context.get("liquid_host_observation",{})
	expect(not observed.is_empty() and observed.native_receipt_hash == web.tower_context.liquid_construction_receipt.receipt_hash,
		"synchronous context carries matching native/host identity")
	web.microscenario_reset()
	expect(web.tower_context.liquid_host_observation.definition_hash == observed.definition_hash
		and web.tower_context.liquid_host_observation.session_generation != observed.session_generation,
		"synchronous restart records its actual new native generation")
	expect(web.microscenario_apply_definition(definition,"Inspect") and web.tower_context.liquid_host_observation.is_empty(),
		"synchronous original constructor retires prior observation")
	web.queue_free();await process_frame

func finish() -> void:
	print("LIQUID_OWNER_OBSERVATION: %d assertions; %d failures" % [assertions,failures])
	quit(1 if failures else 0)
