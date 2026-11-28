extends SceneTree
## Synthetic sources exercise the contract only. Native delegation/recovery is
## separately exercised through the live Workflow and StageSession facade.
const Delegation=preload("res://scripts/batch_lab/architecture_delegation.gd")
const Campaign=preload("res://scripts/batch_lab/architecture_campaign.gd")
const Compiler=preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Jobs=preload("res://scripts/batch_lab/native_detail_jobs.gd")
const Fixture=preload("res://tests/test_native_detail_jobs.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value:failures.append(label);push_error(label)
	return value
static func node_for(kind: String) -> Dictionary:
	var fixture:=Fixture.fixture(kind,47017)
	var stage:=Compiler.stage_defaults("delegate-"+kind.replace("_","-"),Rect2i(0,0,64,64))
	stage.intent="Prepare one finite source-grounded "+kind+" task for owner review."
	stage.materials=[0,7,28,58];stage.budget.max_checked_cells=512
	stage.protected=fixture.context.protected.duplicate(true);stage.clearances=fixture.context.clearances.duplicate(true)
	var instance:="observed-part" if kind=="edge_wear" else ""
	var declared:=Delegation.declare(stage,kind,fixture.params,instance)
	return {"id":stage.id,"parent_id":"","title":"Bounded local worker","kind":"detail","executor":"procedural",
		"region":stage.region.duplicate(),"depends_on":[],"stage":stage,"delegation":declared.get("delegation",{}),
		"raster_candidates_limit":1048576,"scopes":{"write":[fixture.params.region.duplicate()],"guards":[],"clearances":[],"connectors":[]}}
static func host_for(kind: String) -> Dictionary:
	var fixture:=Fixture.fixture(kind,47017)
	var instance:="observed-part" if kind=="edge_wear" else ""
	return {"ok":true,"context":fixture.context,"selected_instance":instance,
		"instances":[] if instance.is_empty() else [{"instance_id":instance,"current_geometry_verified":true}],
		"scope":"Synthetic test fixture; this is not native observation evidence."}
static func campaign_for(node: Dictionary) -> Dictionary:
	return {"format":Campaign.FORMAT,"id":"delegation-fixture","title":"Bounded worker campaign","intent":"Delegate one explicitly constrained local detail job.",
		"region":[0,0,64,64],"budget":{"native_checks":512,"raster_candidates":1048576,"max_retries_per_job":2},"nodes":[node]}
func _initialize() -> void:
	for kind: String in Jobs.KINDS:
		var node:=node_for(kind);var host:=host_for(kind)
		if not check(Delegation.validate(node).ok,"planned typed delegation "+kind):continue
		check(Campaign.validate(campaign_for(node)).ok,"planned graph contains no precomputed worker geometry "+kind)
		var original: PackedByteArray=host.context.source_cells.duplicate()
		var prepared:=Delegation.compile(node,host)
		if not check(prepared.ok,"execute code-owned bounded worker "+kind+" "+str(prepared.get("reason",""))):continue
		check(host.context.source_cells==original and node.stage.operations.is_empty(),"preparation mutates neither source nor planned payload "+kind)
		check(prepared.stage.input_snapshot_sha256==host.context.source_sha256 and prepared.stage.input_generation==1,"prepared result pins exact host snapshot "+kind)
		check(prepared.native_cells<=512 and prepared.worker_scan_cells<=Jobs.MAX_SCAN_CELLS,"worker cost remains finite and explicit "+kind)
		var prepared_node:=node.duplicate(true);prepared_node.stage=prepared.stage
		check(Delegation.validate(prepared_node).ok and Campaign.validate(campaign_for(prepared_node)).ok,"prepared shape is valid without granting execution authority "+kind)
		var projection:=Compiler.compile(prepared.stage,Fixture.stage_context(host.context))
		check(projection.ok and projection.budget.checked_cells==prepared.native_cells,"host independently compiles actual generated geometry "+kind)
		var stale:=Fixture.stage_context(host.context);stale.generation=2
		check(not Compiler.compile(prepared.stage,stale).ok,"old prepared worker generation cannot preview "+kind)
		var coordinator:=Campaign.new();coordinator.load_campaign(campaign_for(node))
		check(coordinator.validate_revision(node.id,prepared.stage).ok and coordinator.revise_job(node.id,prepared.stage).ok,"ordinary finite revision accepts prepared output "+kind)
	_test_refusals()
	_test_skip()
	print("ARCHITECTURE_DELEGATION_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}));quit(1 if not failures.is_empty() else 0)
func _test_refusals() -> void:
	var original:=node_for("contextual_ribs");var host:=host_for("contextual_ribs")
	var changed:=original.duplicate(true);changed.delegation.worker="model"
	check(not Delegation.validate(changed).ok,"undeclared model or executable worker refused")
	changed=original.duplicate(true);changed.delegation.params["script"]="World.paint()"
	check(not Delegation.validate(changed).ok,"executable parameter field refused")
	changed=original.duplicate(true);changed.delegation.params.region=[8,8,129,40]
	check(not Delegation.validate(changed).ok,"local job cannot exceed128-cell bound")
	changed=original.duplicate(true);changed.stage.region=[0,0,65,64];changed.region=changed.stage.region
	check(not Delegation.validate(changed).ok,"revision cannot widen original stage region")
	changed=original.duplicate(true);changed.stage.materials.append(13)
	check(not Delegation.validate(changed).ok,"revision cannot widen original material permissions")
	changed=original.duplicate(true);changed.stage.budget.max_checked_cells=513
	check(not Delegation.validate(changed).ok,"revision cannot widen original resource ceiling")
	changed=original.duplicate(true);changed.stage.protected=[]
	check(not Delegation.validate(changed).ok,"revision cannot remove original protected boundary")
	changed=original.duplicate(true);changed.stage.protected.resize(65)
	check(not Delegation.validate(changed).ok,"delegation exposes native64 protection ceiling before worker preparation")
	changed=original.duplicate(true);changed.stage.clearances=[]
	check(not Delegation.validate(changed).ok,"revision cannot remove original clearance")
	changed=original.duplicate(true);changed.delegation.params.seed=0.25
	check(not Delegation.validate(changed).ok,"fractional worker seed refused")
	changed=original.duplicate(true);changed.stage.uncertainty=12
	check(not Delegation.validate(changed).ok,"malformed caveat arrays refuse before handoff")
	changed=original.duplicate(true);changed.stage["module_bindings"]=[{"instance":"hidden-assembly"}]
	check(not Delegation.validate(changed).ok,"local delegated job cannot silently drop assembly binding requirements")
	changed=original.duplicate(true);changed.delegation.params.density=INF
	check(not Delegation.validate(changed).ok,"nonfinite worker control refused")
	changed=original.duplicate(true);changed.stage.operations=[{"shape":"pixels","material":28,"points":[[1,1]]}]
	check(not Delegation.validate(changed).ok,"unmarked arbitrary geometry cannot enter delegated prepared shape")
	var prepared:=Delegation.compile(original,host)
	changed=original.duplicate(true);changed.stage=prepared.stage.duplicate(true);changed.stage.delegation_descriptor_sha256="0".repeat(64)
	check(not Delegation.validate(changed).ok,"prepared payload cannot substitute another worker descriptor")
	var bad_host:=host.duplicate(true);bad_host.context.source_sha256="0".repeat(64)
	check(not Delegation.compile(original,bad_host).ok,"worker requires exact source bytes and digest")
	bad_host=host.duplicate(true);bad_host.context.allowed_materials=[58]
	check(not Delegation.compile(original,bad_host).ok,"declared stage cannot widen current host permission")
	bad_host=host.duplicate(true);bad_host.context.max_cells=16
	check(not Delegation.compile(original,bad_host).ok,"worker cannot widen current host capacity")
	bad_host=host.duplicate(true);bad_host.context.protected.append([8,8,48,40])
	check(not Delegation.compile(original,bad_host).ok,"current host guards can refuse otherwise valid typed work")
	var wear:=node_for("edge_wear");bad_host=host_for("edge_wear");bad_host.instances[0].current_geometry_verified=false
	check(not Delegation.compile(wear,bad_host).ok,"wear cannot inherit unverified imported native-instance claims")
	bad_host=host_for("edge_wear");bad_host.selected_instance="other-part"
	check(not Delegation.compile(wear,bad_host).ok,"host selection must match exact declared native instance")
	check(not Delegation.declare({"region":123},"contextual_ribs",{}).ok,"malformed declaration refuses without dereference error")
func _test_skip() -> void:
	var node:=node_for("contextual_ribs");var coordinator:=Campaign.new();coordinator.load_campaign(campaign_for(node))
	var before:=Compiler.canonical(coordinator.export_history())
	check(coordinator.can_skip(node.id).ok and before==Compiler.canonical(coordinator.export_history()),"skip preflight is pure for atomic host coordination")
	check(coordinator.skip(node.id).ok and not coordinator.can_skip(node.id).ok,"committed skip cannot be repeated")
	check(not coordinator.can_skip("missing").ok,"unknown task cannot pass skip preflight")
	coordinator=Campaign.new();coordinator.load_campaign(campaign_for(node));coordinator._history.resize(Campaign.MAX_HISTORY_RECORDS)
	check(not coordinator.can_skip(node.id).ok,"history capacity refusal precedes host skip mutation")
