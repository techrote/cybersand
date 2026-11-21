extends RefCounted
## Development experiments. Native execution/readback belongs to the Batch Lab controller.
const ROOT := "res://batch_lab/"
const PROMPT_VERSION := "world-steer-batch-prompts-v1"
const FAMILIES := ["greebles", "pipework", "architecture"]
const VARIANTS := ["P0", "P1", "P2", "P3"]
const CONTROLS := ["procedural", "seeded_random"]
const Metrics = preload("res://scripts/batch_lab/batch_lab_metrics.gd")

static func _document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func reference_card(card_id: String) -> Dictionary:
	for card: Dictionary in _document(ROOT + "references/cards-v1.json").get("cards", []):
		if str(card.get("id", "")) == card_id: return card.duplicate(true)
	return {}

static func prompt_for(family: String, variant: String, extent: Array, seed: int) -> Dictionary:
	var spec := _document(ROOT + "experiments/v1.json")
	if family not in FAMILIES or variant not in VARIANTS or spec.is_empty():
		return {"error": "Unknown family, prompt variant or unavailable experiment manifest."}
	var family_spec: Dictionary = spec.families[family]
	var card := reference_card(str(family_spec.reference_card_id))
	var path := ROOT + "prompts/v1/" + variant + ".txt"
	if not FileAccess.file_exists(path) or card.is_empty():
		return {"error": "Versioned prompt or source-grounded reference card is unavailable."}
	var body := FileAccess.get_file_as_string(path)
	body = body.replace("{task}", str(family_spec.task))
	body = body.replace("{reference_card}", JSON.stringify(card, "  "))
	body += "\nHost context: tile %d by %d cells; integer local coordinates from (0,0); seed %d. " % [extent[0], extent[1], seed]
	body += "Material permission is [0,58]. Preserve all non-Empty/non-Hardwall source cells and the protected top-left marker. "
	body += "Maximum candidate-cell execution budget is 65536; only native-confirmed changes count as applied. "
	body += "The host supplies the actual initial material state separately. Do not invent unseen source geometry.\n"
	return {"text": body, "prompt_version": PROMPT_VERSION, "template_sha256": FileAccess.get_sha256(path),
		"assembled_sha256": body.sha256_text(), "reference_card_id": card.id,
		"reference_delivery": "grounded-card-only" if variant in ["P2", "P3"] else "none",
		"tool_contract": str(spec.tool_contract)}

static func make_grid(family: String, side: int, seed: int, control: String = "procedural") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if side not in [2, 4]: return result
	for index: int in range(side * side):
		# Four variants share one host seed. A 2x2 is one matched block; 4x4 is four.
		var row_seed := seed + (index / 4) * 104729
		result.append(make_attempt(family, VARIANTS[index % 4], row_seed, 128, 128, control))
	return result

static func make_attempt(family: String, variant: String, seed: int, width: int, height: int, control: String = "procedural") -> Dictionary:
	if family not in FAMILIES or variant not in VARIANTS or control not in CONTROLS:
		return {"error": "Choose a registered development family, P0-P3 variant and procedural or seeded_random control."}
	if width < 64 or height < 64 or width > 512 or height > 512:
		return {"error": "Development examples support 64 through 512 cells per axis."}
	var spec := _document(ROOT + "experiments/v1.json")
	if spec.is_empty(): return {"error": "Experiment manifest is unavailable."}
	var prompt := prompt_for(family, variant, [width, height], seed)
	if prompt.has("error"): return prompt
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var operations: Array = []
	match family:
		"greebles": _greebles(operations, rng, width, height)
		"pipework": _pipework(operations, rng, width, height)
		"architecture": _architecture(operations, rng, width, height)
	if control == "seeded_random": operations = _relocate(operations, seed, width, height)
	var source: Array = [[0, height - 4, width, 4, 28], [0, 0, 2, height, 28],
		[width - 2, 0, 2, height, 28], [2, 2, 4, 4, 28]]
	var targets := _targets(family, width, height)
	return {"prompt": prompt.text, "variant": variant, "family": family,
		"provider": "procedural", "model": "deterministic-v1", "seed": seed,
		"extent": [width, height], "source_region": [0, 0, width, height],
		"materials": [0, 58], "protection": [[2, 2, 4, 4]], "budget_cells": 65536,
		"operations": operations, "source_rectangles": source, "control": control,
		"group_id": spec.families[family].group_id, "cohort": "development",
		"prompt_version": PROMPT_VERSION, "prompt_sha256": prompt.assembled_sha256,
		"prompt_template_sha256": prompt.template_sha256, "reference_card_id": prompt.reference_card_id,
		"reference_delivery": prompt.reference_delivery, "tool_contract": prompt.tool_contract,
		"experiment_manifest_sha256": FileAccess.get_sha256(ROOT + "experiments/v1.json"),
		"reference_manifest_sha256": FileAccess.get_sha256(ROOT + "references/cards-v1.json"),
		"metrics_targets": targets, "evidence_kind": "deterministic-procedural-control",
		"model_quality_claim": false}

static func _scale(value: int, extent: int) -> int:
	return clampi(roundi(float(value) * float(extent) / 128.0), 0, extent - 1)

static func _rect(ops: Array, x0: int, y0: int, x1: int, y1: int, width: int, height: int, material: int = 58) -> void:
	ops.append({"shape": "rectangle", "x0": _scale(x0, width), "y0": _scale(y0, height),
		"x1": _scale(x1, width), "y1": _scale(y1, height), "material": material})

static func _greebles(ops: Array, rng: RandomNumberGenerator, width: int, height: int) -> void:
	for bank: int in range(2):
		var left := 12 if bank == 0 else 82
		for row: int in range(3):
			var top := 16 + row * 29 + rng.randi_range(-2, 2)
			_rect(ops, left, top, left + 32, top + 21, width, height)
			_rect(ops, left + 2, top + 2, left + 30, top + 19, width, height, 0)
			var vents := rng.randi_range(3, 5)
			for vent: int in range(vents):
				_rect(ops, left + 5, top + 4 + vent * 3, left + 17, top + 4 + vent * 3, width, height)
			_rect(ops, left + 22, top + 4, left + 27, top + 9, width, height)
			_rect(ops, left + 24, top + 11, left + 25, top + 16, width, height)
			_rect(ops, left + 32, top + 12, left + 37, top + 14, width, height)
	_rect(ops, 12, 109, 114, 111, width, height)
	for x: int in range(18, 114, 12): _rect(ops, x, 105, x + 2, 111, width, height)

static func _pipework(ops: Array, rng: RandomNumberGenerator, width: int, height: int) -> void:
	var spine := 62 + rng.randi_range(-4, 4)
	_rect(ops, 12, spine, 115, spine + 2, width, height)
	for branch: int in range(3):
		var x := 28 + branch * 34 + rng.randi_range(-2, 2)
		var top := 20 + rng.randi_range(0, 7)
		var bottom := 96 - rng.randi_range(0, 7)
		_rect(ops, x, top, x + 2, bottom, width, height)
		_rect(ops, x - 3, top - 2, x + 5, top, width, height)
		_rect(ops, x - 3, bottom, x + 5, bottom + 2, width, height)
		_rect(ops, x - 2, spine - 2, x + 4, spine + 4, width, height)
	_rect(ops, 10, spine - 3, 12, spine + 5, width, height)
	_rect(ops, 115, spine - 3, 117, spine + 5, width, height)

static func _architecture(ops: Array, rng: RandomNumberGenerator, width: int, height: int) -> void:
	_rect(ops, 14, 14, 18, 123, width, height)
	_rect(ops, 109, 14, 113, 123, width, height)
	_rect(ops, 14, 14, 113, 18, width, height)
	_rect(ops, 14, 120, 113, 123, width, height)
	var gallery := 63 + rng.randi_range(-5, 5)
	_rect(ops, 18, gallery, 43, gallery + 3, width, height)
	_rect(ops, 84, gallery, 109, gallery + 3, width, height)
	for step: int in range(5):
		_rect(ops, 18 + step * 4, gallery + 4, 20 + step * 4, gallery + 21 - step * 4, width, height)
		_rect(ops, 107 - step * 4, gallery + 4, 109 - step * 4, gallery + 21 - step * 4, width, height)
	_rect(ops, 18, 29, 109, 31, width, height)
	var crane := 62 + rng.randi_range(-8, 8)
	_rect(ops, crane, 32, crane + 1, 49, width, height)
	_rect(ops, crane - 5, 49, crane + 6, 51, width, height)
	for x: int in range(22, 106, 12):
		_rect(ops, x, 20, x + 1, 28, width, height)
	for y: int in range(gallery + 6, 112, 7):
		_rect(ops, 25, y, 32, y + 1, width, height)
		_rect(ops, 95, y, 102, y + 1, width, height)

static func _relocate(operations: Array, seed: int, width: int, height: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x35a41f29
	var result: Array = []
	for raw: Dictionary in operations:
		var op := raw.duplicate(true)
		var w := int(op.x1) - int(op.x0)
		var h := int(op.y1) - int(op.y0)
		op.x0 = rng.randi_range(2, maxi(2, width - 3 - w))
		op.y0 = rng.randi_range(2, maxi(2, height - 5 - h))
		op.x1 = int(op.x0) + w
		op.y1 = int(op.y0) + h
		result.append(op)
	return result

static func _box(x: int, y: int, w: int, h: int, width: int, height: int) -> Array:
	var x0 := _scale(x, width)
	var y0 := _scale(y, height)
	return [x0, y0, maxi(1, _scale(x + w, width) - x0), maxi(1, _scale(y + h, height) - y0)]

static func _targets(family: String, width: int, height: int) -> Dictionary:
	var result := {"structural_materials": [58], "require_connected": family == "pipework",
		"clearance_radius": maxi(1, _scale(2, mini(width, height))),
		"clearance_scope": "Geometric empty-square connectivity only; no actor dynamics or gameplay-feel claim.",
		"features": [], "route": [], "minimum_empty_fraction": 0.5}
	match family:
		"greebles":
			result.features = [{"name": "left service bank", "rect": _box(12, 12, 33, 86, width, height), "minimum_fraction": 0.1},
				{"name": "right service bank", "rect": _box(82, 12, 33, 86, width, height), "minimum_fraction": 0.1}]
			result.void_rect = _box(54, 12, 20, 86, width, height)
		"pipework":
			result.features = [{"name": "central spine", "rect": _box(12, 58, 104, 10, width, height), "minimum_fraction": 0.1},
				{"name": "upper endpoints", "rect": _box(22, 18, 82, 12, width, height), "minimum_fraction": 0.03}]
			result.route = [[_scale(12, width), _scale(113, height)], [_scale(115, width), _scale(113, height)]]
		"architecture":
			result.features = [{"name": "roof beam", "rect": _box(14, 14, 100, 5, width, height), "minimum_fraction": 0.8},
				{"name": "left support", "rect": _box(14, 14, 5, 106, width, height), "minimum_fraction": 0.8},
				{"name": "right support", "rect": _box(109, 14, 5, 106, width, height), "minimum_fraction": 0.8}]
			result.route = [[_scale(24, width), _scale(116, height)], [_scale(103, width), _scale(116, height)]]
			result.void_rect = _box(46, 58, 36, 50, width, height)
	return result

static func evaluate_materials(config: Dictionary, before: PackedInt32Array, after: PackedInt32Array) -> Dictionary:
	return Metrics.evaluate_materials(config, before, after)
