extends SceneTree

const Catalogue = preload("res://scripts/material_lab_catalogue.gd")
const Host = preload("res://scripts/microscenario_host.gd")
const Pack = preload("res://scripts/microscenario_reference_pack.gd")
var assertions: int = 0
var failures: int = 0


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)


func row(view: Dictionary, property: String) -> Dictionary:
	for entry: Dictionary in view.get("rows", []):
		if entry.property == property: return entry
	return {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var catalogue: Variant = Catalogue.new()
	expect(catalogue.reload(), catalogue.error)
	if not catalogue.native_available:
		print("MATERIAL_LAB_CATALOGUE: native acceptance unavailable; refusing a false pass")
		quit(1)
		return
	expect(catalogue.materials.size() == 132, "All allocated slots including reserved ID 10 must be visible")
	expect(catalogue.search("").size() == 132, "Browser silently dropped allocated slots")
	expect(catalogue.search("", "Reserved") == [10], "Reserved ID 10 must remain visibly invalid")
	expect(catalogue.search("3") == [3] and catalogue.search("10") == [10] and catalogue.search("132").is_empty(), "Standalone numeric search must match the exact stable ID")
	expect(catalogue.profile.pair_rules.size() == 56, "Legacy sparse pair roster changed")
	expect(catalogue.search("", "Hard surfaces").size() == 101, "Native hard-surface predicate changed")
	expect(catalogue.search("", "Granular support").size() == 9, "Native granular capability changed")
	var paintable: int = 0
	for id: int in range(132):
		var view: Dictionary = catalogue.inspect(id)
		expect(view.ok and view.id == id and view.origin == "compiled-native-readback", "Inspector identity/origin mismatch: %s" % id)
		if view.paintable: paintable += 1
		for field: String in ["Density", "Viscosity index", "Initial state A", "Kernel write radius"]:
			var entry: Dictionary = row(view, field)
			expect(entry.has("declared") and entry.has("effective") and not str(entry.get("consumer", "")).is_empty() and entry.has("applicability") and entry.has("editability"), "Missing effective parameter contract %s/%s" % [id, field])
		view.descriptor["name"] = "MUTATION PROBE"
		expect(catalogue.materials[id].name != "MUTATION PROBE", "Inspector exposed mutable native-catalogue model storage")
	expect(paintable == 130, "Paintable roster must exclude Empty and invalid 10")
	expect(not catalogue.inspect(-1).ok and not catalogue.inspect(132).ok and not catalogue.inspect(256).ok, "Invalid IDs accepted by inspector")
	var sand: Dictionary = catalogue.inspect(2)
	expect(sand.descriptor.state_name == "Powder" and sand.descriptor.kernel_name == "Sand", "Sand was mislabeled as CellularYield or Solid")
	for held_field: String in ["Stable material ID", "Physical type", "Movement kernel", "Movable", "Density motion", "Accepts density exchange", "Lateral flow", "Initial state A", "Initial state B", "Kernel write radius", "Thermal / lifecycle", "Procedural flair"]:
		expect(not row(sand, held_field).editable_in_candidate, "Inspector advertised a candidate edit that the Lab backend rejects: " + held_field)
	for supported_field: String in ["Density", "Hard surface", "Granular support", "Visual state projection", "Base RGBA8"]:
		expect(row(sand, supported_field).editable_in_candidate, "Supported candidate field was incorrectly presented as immutable: " + supported_field)
	for reserved_id: int in [0, 10]:
		for entry: Dictionary in catalogue.inspect(reserved_id).rows:
			expect(not entry.editable_in_candidate, "Non-template slot exposed a candidate edit: %s/%s" % [reserved_id, entry.property])
	expect(sand.capabilities.granular_support and not sand.capabilities.hard_surface, "Granular support and hard terrain conflated")
	expect(not sand.capabilities.density_exchange_down.has(14), "Powder/powder density exchange was invented")
	expect(catalogue.search("sand", "Powders").has(2), "Name/phase search missed Sand")
	expect(catalogue.search("yieldingliquid", "Liquids").has(21), "Kernel search missed Slush")
	expect(catalogue.search("granular", "Granular support").has(2), "Capability search failed")
	var slush: Dictionary = catalogue.inspect(21)
	expect(row(slush, "Density").effective == 1080, "Native Slush density is not 1080")
	expect(row(slush, "Fallback density (comparison)").effective == 1100 and row(slush, "Fallback density (comparison)").origin != "compiled-native-readback", "Fallback density incorrectly presented as native")
	expect(row(slush, "Viscosity index").effective == 192, "Slush effective descriptor viscosity mismatch")
	expect(row(slush, "Viscosity index").editable_in_candidate, "Slush's supported viscosity edit was not exposed")
	for id: int in [8, 12, 16]:
		var entry: Dictionary = row(catalogue.inspect(id), "Viscosity index")
		expect(str(entry.effective).contains("Ineffective") and str(entry.editability).begins_with("Unsupported"), "Specialized viscosity was exposed as working: %s" % id)
	var glass: Dictionary = catalogue.inspect(36)
	expect(str(row(glass, "Thermal / lifecycle").effective).contains("four-tick"), "MoltenGlass thermal cadence missing")
	expect(" ".join(glass.notes).contains("#395"), "Known pending cooling correction was hidden")
	var water: Dictionary = catalogue.inspect(3)
	expect(not water.solver.observed and str(water.solver.applicability).contains("not observed"), "Compiled default was misrepresented as applied World policy")
	expect(not row(water, "Viscosity index").editable_in_candidate and str(row(water, "Viscosity index").editability).contains("Read-only"), "Water descriptor viscosity must not be advertised as an editable Lab v1 field")
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var actual: Dictionary = world.get_liquid_solver_policy()
	var observed: Dictionary = catalogue.inspect(3, actual)
	expect(observed.solver.observed, "Real applied native World policy was not recognized")
	for assignment: Dictionary in actual.assignments:
		if int(assignment.material) == 3:
			expect(observed.solver.family == assignment.applied_family, "Water solver did not match authoritative readback")
	# Brine is an admitted non-Water IN participant. Use an installed native
	# policy receipt, not a manually assembled family-name dictionary.
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var brine_choice: Dictionary = {}
	for choice: Dictionary in bridge.liquid_policy_assignment_choices(bridge.default_liquid_policy(), 24):
		if choice.family == "inertial_cellular_v1" and choice.variant == "reference":
			brine_choice = choice
	expect(brine_choice.get("accepted", false), "Native Brine IN selection is required for this effective-property regression")
	if brine_choice.get("accepted", false):
		var host: RefCounted = Host.new()
		expect(host.install(world, Pack.interaction_fixture("salt-water", 2, 32), "Inspect", true, brine_choice.request, {"maximum_rule_radius":3}), "Actual native Brine IN World construction failed: " + host.last_error)
		var brine_receipt: Dictionary = world.get_liquid_solver_policy()
		var brine: Dictionary = catalogue.inspect(24, brine_receipt)
		var viscosity: Dictionary = row(brine, "Viscosity index")
		expect(brine.solver.observed and brine.solver.family == "inertial_cellular_v1", "Inspector did not consume the actual Brine IN owner receipt")
		expect(viscosity.declared == 32 and str(viscosity.effective).contains("Ineffective") and str(viscosity.consumer).contains("inertial"), "Brine's descriptor viscosity must not be presented as controlling an IN assignment")
		expect(viscosity.editable_in_candidate and str(viscosity.applicability).contains("ordinary CellularYield"), "Candidate Brine viscosity edit must identify its separate ordinary-CY applicability")
		host.clear()
	# Authored order, probability boundaries, both endpoint orientations, and no
	# matching-rule are actual compiled native resolver calls, not a UI mock.
	for rule: Dictionary in catalogue.profile.pair_rules:
		for reversed: bool in [false, true]:
			var source: int = int(rule.second) if reversed else int(rule.first)
			var target: int = int(rule.first) if reversed else int(rule.second)
			var selected: Dictionary = catalogue.inspect_reaction(source, target, int(rule.probability_threshold))
			expect(selected.ok and selected.outcome == "Selected" and selected.rule_id == rule.rule_id, "Compiled rule/threshold/orientation mismatch: " + str(rule.rule_id))
			expect(selected.probability == "%s/256" % (int(rule.probability_threshold) + 1), "Probability omitted legacy inclusive threshold")
			if int(rule.probability_threshold) < 255:
				var failed: Dictionary = catalogue.inspect_reaction(source, target, int(rule.probability_threshold) + 1)
				expect(failed.outcome == "MatchedFailedRoll", "Failed roll was conflated with absent rule")
			expect(str(selected.world_eligibility).begins_with("Not observed"), "Resolver invented World scheduling eligibility")
		var partner_query: String = str(catalogue.materials[int(rule.second)].name)
		expect(catalogue.search(partner_query).has(int(rule.first)), "Reaction-partner search missed source")
	var none: Dictionary = catalogue.inspect_reaction(1, 1, 0)
	expect(none.ok and none.outcome == "NoRule", "NoRule diagnostic missing")
	for invalid: Array in [[10, 3, 0], [-1, 3, 0], [2, 256, 0], [2, 3, -1], [2, 3, 256]]:
		expect(not catalogue.inspect_reaction(invalid[0], invalid[1], invalid[2]).get("ok", false), "Invalid native reaction input was accepted")
	# A retained view must not change with a subsequent reload.
	var retained: Dictionary = catalogue.inspect(21)
	expect(catalogue.reload() and retained.descriptor.density == 1080, "Catalogue reload mutated retained inspector values")
	print("MATERIAL_LAB_CATALOGUE: %s assertions, %s failures; actual compiled native descriptor and resolver readback" % [assertions, failures])
	quit(0 if failures == 0 else 1)
