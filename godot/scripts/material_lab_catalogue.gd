class_name CyberMaterialLabCatalogue
extends RefCounted

## Read-only, cold-path material inspection. Native values come from the loaded
## extension; authored candidates are separate and never change this catalogue.
const Appearance = preload("res://scripts/material_appearance_lut.gd")
const FILTERS: Array[String] = ["All", "Powders", "Liquids", "Gases", "Solids", "Agents", "Hard surfaces", "Granular support", "Reactive", "Reserved"]
const SOURCE_COMPILE: String = "Editable in candidate; compile/test only. Production source migration required"
const TEMPLATE_HELD: String = "Read-only in Lab v1; field is held to the selected template"
const WORLD_POLICY: String = "Read-only in Lab v1; use existing Workbench solver controls and World reconstruction"

var materials: Array = []
var profile: Dictionary = {}
var native_available: bool = false
var status: String = "Unavailable"
var error: String = ""
var native_metadata: Dictionary = {}
var _bridge: Object
var _program: Image


func reload() -> bool:
	materials.clear()
	profile.clear()
	native_metadata.clear()
	native_available = false
	status = "Unavailable"
	error = "Native material inspection is unavailable. Rebuild the GDExtension from this source; shadow catalogue data is not live physics."
	if not ClassDB.class_exists(&"CyberDemoBridge"):
		return false
	_bridge = ClassDB.instantiate(&"CyberDemoBridge")
	if not _bridge.has_method(&"inspect_material_catalogue"):
		return false
	var packet: Dictionary = _bridge.call(&"inspect_material_catalogue")
	if int(packet.get("schema_version", 0)) != 1 or not packet.get("materials") is Array:
		error = "The native inspector returned an unsupported catalogue packet. Rebuild matching source and extension."
		return false
	var incoming: Array = packet.materials
	if incoming.size() != int(packet.get("allocated_slots", -1)):
		error = "Native catalogue slot count is inconsistent."
		return false
	for id: int in range(incoming.size()):
		if not incoming[id] is Dictionary or int(incoming[id].get("id", -1)) != id:
			error = "Native catalogue identities are not a complete stable-ID sequence."
			return false
	materials = incoming.duplicate(true)
	native_metadata = packet.duplicate(true)
	native_metadata.erase("materials")
	profile = _bridge.call(&"inspect_interaction_profile")
	_program = Appearance.create_program_image()
	native_available = true
	status = "Compiled native definitions; World settings require owner readback"
	error = ""
	return true


func search(query: String, filter: String = "All") -> Array:
	var results: Array = []
	var normalized: String = query.strip_edges().to_lower()
	# A standalone integer is an exact stable ID, not a substring of a partner
	# ID or a rule name. Text queries still search all partner names and families.
	if normalized.is_valid_int():
		var id: int = normalized.to_int()
		if id >= 0 and id < materials.size() and _matches_filter(materials[id], filter):
			results.append(id)
		return results
	var terms: PackedStringArray = normalized.split(" ", false)
	for d: Dictionary in materials:
		if not _matches_filter(d, filter):
			continue
		var fields: Array = [str(d.id), str(d.name), str(d.state_name), str(d.kernel_name), str(d.lateral_flow_name), str(d.density_motion_name)]
		fields.append_array(d.get("families", []))
		if d.hard_surface: fields.append("hard terrain surface")
		if d.granular_support: fields.append("granular support powder")
		if not d.valid: fields.append("reserved invalid")
		for rule: Dictionary in _reactions(int(d.id)):
			var partner: int = int(rule.second) if int(rule.first) == int(d.id) else int(rule.first)
			fields.append(str(partner))
			fields.append(str(materials[partner].name))
			fields.append(str(rule.rule_id))
		var haystack: String = " ".join(fields).to_lower()
		var matches: bool = true
		for term: String in terms:
			if not haystack.contains(term):
				matches = false
				break
		if matches: results.append(int(d.id))
	return results


func _matches_filter(d: Dictionary, filter: String) -> bool:
	match filter:
		"All": return true
		"Powders": return d.valid and d.state_name == "Powder"
		"Liquids": return d.valid and d.state_name == "Liquid"
		"Gases": return d.valid and d.state_name == "Gas"
		"Solids": return d.valid and d.state_name == "Solid"
		"Agents": return d.valid and d.state_name == "Agent"
		"Hard surfaces": return d.valid and d.hard_surface
		"Granular support": return d.valid and d.granular_support
		"Reactive": return d.valid and d.has_pair_reactions
		"Reserved": return not d.valid
	return false


func _reactions(id: int) -> Array:
	var result: Array = []
	var priority: int = 0
	for rule: Dictionary in profile.get("pair_rules", []):
		if int(rule.first) == id or int(rule.second) == id:
			var item: Dictionary = rule.duplicate(true)
			item["priority"] = priority
			item["probability_numerator"] = int(rule.probability_threshold) + 1
			item["probability_denominator"] = 256
			item["endpoint_effect"] = "replace_with_defaults"
			item["state_consequence"] = "Both products reset to descriptor defaults; Water uses the World maximum. Same-material products do not preserve existing state."
			result.append(item)
		priority += 1
	return result


func _row(property: String, declared: Variant, effective: Variant, consumer: String, applicability: String, editability: String = TEMPLATE_HELD, origin: String = "compiled-native-readback") -> Dictionary:
	return {"property": property, "declared": declared, "effective": effective, "consumer": consumer, "applicability": applicability, "editability": editability, "editable_in_candidate": editability == SOURCE_COMPILE, "origin": origin}


func inspect(id: int, applied_policy: Dictionary = {}) -> Dictionary:
	if not native_available or id < 0 or id >= materials.size():
		return {"ok": false, "error": error if not native_available else "Material ID is outside the compiled catalogue."}
	var d: Dictionary = materials[id].duplicate(true)
	var solver: Dictionary = _solver(d, applied_policy)
	var reactions: Array = _reactions(id)
	var partners: Array = []
	for rule: Dictionary in reactions:
		var partner: int = int(rule.second) if int(rule.first) == id else int(rule.first)
		if not partners.has(partner): partners.append(partner)
	var notes: Array = ["Browse categories and visual flair do not define physical capabilities or semantic families.", "This catalogue reads the loaded native extension. Candidate presets never mutate these compiled definitions.", "Compact reactions are only part of chemistry. Specialized World mechanisms, scheduling, masks and competing contacts require a simulation test."]
	var rows: Array = []
	rows.append(_row("Stable material ID", id, id, "Cell material / saved material identity", "Reserved invalid slot" if not d.valid else "Persistent identity", "Read-only; existing IDs cannot be reassigned"))
	rows.append(_row("Physical type", d.state_name, d.state_name, "MaterialRules descriptor + World kernel", "Broad phase classification; not inheritance"))
	rows.append(_row("Movement kernel", d.kernel_name, solver.label, solver.consumer, solver.applicability, "Kernel held to template; choose another template. Applied solver policy uses Workbench controls."))
	rows.append(_row("Density", d.density, d.density, "MaterialRules::can_density_exchange", "Gameplay density rank; directional, opt-in. Powder/powder swaps are refused; Oil does not displace powders.", SOURCE_COMPILE))
	rows.append(_row("Movable", d.movable, d.movable, "MaterialRules descriptor; World::update_rule_kernel", "Movement still depends on the selected kernel and local opportunities"))
	rows.append(_row("Density motion", d.density_motion_name, d.density_motion_name, "MaterialRules::can_density_exchange", "Directional swap eligibility; this is not a movement command"))
	rows.append(_row("Accepts density exchange", d.accepts_density_exchange, d.accepts_density_exchange, "MaterialRules::can_density_exchange", "Target must also be valid with an available current rule"))
	rows.append(_row("Hard surface", "native predicate", d.hard_surface, "MaterialRules::is_hard_surface", "Rigid terrain capability; independent of broad Solid type", SOURCE_COMPILE))
	rows.append(_row("Granular support", "native predicate", d.granular_support, "MaterialRules::supports_granular_load", "Load-support capability; independent of hard terrain", SOURCE_COMPILE))
	rows.append(_row("Lateral flow", d.lateral_flow_name, solver.label if d.state_name == "Liquid" else "Not applicable", solver.consumer, "Descriptor family is overridden only by an admitted native liquid policy"))
	rows.append(_viscosity_row(d, solver, applied_policy))
	rows.append(_row("Initial state A", d.initial_state_a, "World Water maximum (policy-dependent)" if id == 3 else d.initial_state_a, "World cell creation / pair-product initialization", "Initial state only; existing cell state requires owner readback"))
	rows.append(_row("Initial state B", d.initial_state_b, d.initial_state_b, "World cell creation / pair-product initialization", "Kernel-owned byte; no unrestricted live state editing"))
	rows.append(_row("Kernel write radius", d.maximum_write_radius, d.maximum_write_radius, "World kernel dispatch / owner admission", "Descriptor bound; solver minimum radius and World configuration can be stricter"))
	rows.append(_row("Visual state projection", d.visual_state_name, d.visual_state_name, "project_visual_state → RenderBridge RG8", "Presentation reads selected state; Water mass is normalized by the active policy", SOURCE_COMPILE))
	rows.append(_row("Thermal / lifecycle", "Specialized kernel", _thermal(d), "World::update_rule_kernel", "No generic editable melting-point or temperature law is provided", "Unsupported as arbitrary parameters; use existing admitted kernels"))
	if id == 21:
		rows.append(_row("Fallback density (comparison)", 1100, 1100, "cell_world.gd::_material_density", "Source-derived fallback fact, not native behavior or parity qualification", "Read-only; separate fallback implementation", "GDScript source comparison"))
		notes.append("Slush native density is 1080. The separate GDScript fallback uses 1100; these are intentionally not conflated.")
	if id == 36:
		notes.append("H1: isolated MoltenGlass cooling may lose a future visit at quiet threshold 3. #395 is an unmerged repair candidate. Mutual heating and generic yielding rest remain current behavior.")
	if d.kernel_name in ["YieldingLiquid", "Cement", "MoltenGlass"]:
		notes.append("Generic yielding-liquid movement can rest after a failed stochastic lateral draw. The descriptor does not promise perpetual retries.")
	if id == 33:
		notes.append("A diagnostic World can override Mercury viscosity; a catalogue-only inspection cannot establish that override.")
	if not d.valid:
		notes.append("Reserved ID 10 is invalid, cannot be painted or used as a reaction endpoint, and must not be allocated to a candidate.")
	var appearance: Dictionary = _appearance(d)
	rows.append(_row("Base RGBA8", d.rgba, appearance.godot_rgba, "CyberMaterialAppearanceLut.BASE_RGBA8 → palette shader", "Native descriptor versus Godot presentation table; presentation only", SOURCE_COMPILE, "native + Godot presentation"))
	rows.append(_row("Procedural flair", appearance.flair, appearance.flair, "material_appearance_lut.gd → palette shader", "Appearance category only; does not assign physics", "Existing recipe read-only; arbitrary new recipes unsupported", "Godot presentation"))
	if not d.paintable:
		for entry: Dictionary in rows:
			entry.editability = "Read-only; Empty and reserved slots cannot be candidate templates"
			entry.editable_in_candidate = false
	return {"ok": true, "id": id, "name": d.name, "valid": d.valid, "paintable": d.paintable, "origin": "compiled-native-readback", "descriptor": d, "capabilities": {"hard_surface": d.hard_surface, "granular_support": d.granular_support, "density_exchange_down": d.density_exchange_down, "density_exchange_up": d.density_exchange_up}, "families": d.families.duplicate(), "partners": partners, "reactions": reactions, "rows": rows, "appearance": appearance, "notes": notes, "solver": solver}


func _solver(d: Dictionary, applied_policy: Dictionary) -> Dictionary:
	var is_liquid: bool = d.state_name == "Liquid"
	var result: Dictionary = {"label": d.kernel_name, "family": "material_default", "variant": "reference", "consumer": "World::update_rule_kernel", "applicability": "Compiled kernel; active World context not observed", "observed": false}
	if not is_liquid: return result
	var receipt: Dictionary = applied_policy if not applied_policy.is_empty() else native_metadata.get("default_liquid_policy", {})
	for assignment: Dictionary in receipt.get("assignments", []):
		if int(assignment.get("material", -1)) != int(d.id): continue
		result.family = str(assignment.applied_family)
		result.variant = str(assignment.applied_variant)
		result.label = "%s / %s" % [result.family, result.variant]
		result.observed = not applied_policy.is_empty() and int(receipt.get("session_generation", -1)) >= 0
		result.applicability = "Applied World policy readback" if result.observed else "Compiled default policy; active World assignment not observed"
		match result.family:
			"freemass_v1": result.consumer = "World::update_water"
			"pressure_flow_v1": result.consumer = "World pressure_flow_v1 (world_pressure.inc)"
			"inertial_cellular_v1": result.consumer = "World inertial_cellular_v1 (world_inertial.inc)"
			"cellular_yield_v1": result.consumer = "World::update_water_cellular_yield" if int(d.id) == 3 else "World::update_rule_kernel"
		break
	return result


func _viscosity_row(d: Dictionary, solver: Dictionary, applied_policy: Dictionary) -> Dictionary:
	var value: int = int(d.viscosity_index)
	if solver.family == "inertial_cellular_v1":
		var candidate_edit: bool = d.kernel_name in ["YieldingLiquid", "Cement", "MoltenGlass"]
		return _row("Viscosity index", value, "Ineffective while the inertial family is selected", solver.consumer,
			"IN uses its own damping parameter. Candidate descriptor edits apply only to the template's ordinary CellularYield path, not this IN assignment." if candidate_edit else "IN uses its own validated damping parameter, not descriptor viscosity.",
			SOURCE_COMPILE if candidate_edit else WORLD_POLICY)
	if d.kernel_name in ["Lava", "Acid", "Oil"]:
		return _row("Viscosity index", value, "Ineffective in this specialized kernel", "World::update_rule_kernel::" + str(d.kernel_name), "Specialized movement bypasses the descriptor viscosity gate", "Unsupported edit: this field does not control this kernel")
	if d.state_name != "Liquid":
		return _row("Viscosity index", value, "Not applicable", "No liquid viscosity consumer", "Non-liquid kernel", "Unsupported")
	if int(d.id) == 3 and solver.family == "cellular_yield_v1":
		var water_viscosity: int = int(native_metadata.water_yield_default_viscosity)
		for block: Dictionary in applied_policy.get("material_blocks", []):
			if int(block.get("material", -1)) == 3 and int(block.get("block_version", 0)) == int(native_metadata.water_yield_material_block_version):
				var values: Variant = block.get("values", [])
				if values.size() > 0: water_viscosity = int(values[0])
		return _row("Viscosity index", value, water_viscosity, "World::update_water_cellular_yield", "Separate Water policy parameter; descriptor value is not the controlling value", WORLD_POLICY)
	if int(d.id) == 3:
		return _row("Viscosity index", value, value, "MaterialRules::apply_lateral_viscosity", "Scales FreeMass lateral transfer; PressureFlow uses it only in its fallback lateral path", TEMPLATE_HELD)
	if d.kernel_name in ["YieldingLiquid", "Cement", "MoltenGlass"]:
		return _row("Viscosity index", value, value, "World::update_rule_kernel::flow_as_yielding_liquid", "Lateral attempt probability (256-index)/256 after vertical/diagonal moves; Mercury diagnostic override requires World readback", SOURCE_COMPILE)
	return _row("Viscosity index", value, "Consumer not qualified", solver.consumer, "No Lab v1 editable viscosity contract for this kernel", "Unsupported")


func _thermal(d: Dictionary) -> String:
	match str(d.kernel_name):
		"MoltenGlass": return "state_a cooling countdown; four-tick thermal lane; Fire/Lava/MoltenGlass neighbors reset to 180; zero converts to Glass"
		"Ice": return "Hot-contact melting and bounded Water-freezing mechanism"
		"Lava": return "Specialized hot contact / ignition; no generic cooling parameter"
		"Cement": return "state_a cure countdown; specialized concrete conversion"
		"Combustible", "Oil", "Coal": return "Specialized ignition/burn state; see mechanism and pair rules"
		"Gas", "Fire", "Steam", "Spark": return "Kernel lifetime / phase state; initial state is not a temperature"
	return "Consult specialized mechanism records and sparse pairs; no universal temperature law"


func _appearance(d: Dictionary) -> Dictionary:
	var id: int = int(d.id)
	var tint: Color = _program.get_pixel(0, id)
	var value: Color = _program.get_pixel(1, id)
	var alpha: Color = _program.get_pixel(2, id)
	var emission: Color = _program.get_pixel(3, id)
	var packed: int = Appearance.BASE_RGBA8[id]
	var rgba: Array = [(packed >> 24) & 255, (packed >> 16) & 255, (packed >> 8) & 255, packed & 255]
	return {"origin": "Godot presentation; read from existing material_appearance_lut.gd", "native_rgba": d.rgba.duplicate(), "godot_rgba": rgba, "rgba_agrees": d.rgba == rgba, "visual_state": d.visual_state_name, "flair": int(emission.a), "condition_tint": [tint.r, tint.g, tint.b, tint.a], "condition_range": [value.r, value.g], "value_range": [value.b, value.a], "alpha_range": [alpha.r, alpha.g], "emission_range": [alpha.b, alpha.a], "emission_rgb": [emission.r, emission.g, emission.b]}


func inspect_reaction(source: int, target: int, roll: int) -> Dictionary:
	if not native_available: return {"ok": false, "error": error}
	var result: Dictionary = _bridge.call(&"inspect_interaction", source, target, roll)
	if not result.get("ok", false): return result
	result["outcome"] = "Selected" if result.selected else ("MatchedFailedRoll" if result.matched else "NoRule")
	result["world_eligibility"] = "Not observed: resolver inspection cannot establish scheduling, masks, inactivity or competing mechanisms."
	if result.matched:
		result["probability"] = "%s/256" % (int(result.probability_threshold) + 1)
		result["endpoint_effect"] = "replace_with_defaults"
	return result
