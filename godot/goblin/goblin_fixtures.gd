extends RefCounted

# Committed authoring recipes for the developer-only goblin scene. These are
# ordinary Setup-v2 starts, not observations or a replacement material model.
# The adapter supplies the actual application's liquid-policy envelope.
const Setup = preload("res://scripts/workbench_setup.gd")
const IDS := ["material_playground", "actor_workshop", "construction", "liquid_channel", "save_reopen"]
const EXTENT := Vector2i(512, 512)
const VERSION := 1


static func ids() -> Array[String]:
	var result: Array[String] = []
	for fixture_id: String in IDS:
		result.append(fixture_id)
	return result


static func describe(fixture_id: String) -> Dictionary:
	var descriptions := {
		"material_playground": ["Material playground", "Sand, Water and Wood above a hard floor; open space for small experiments."],
		"actor_workshop": ["Actor workshop", "A Kestrel, a passive barrel and a short stepped route in the ordinary physical session."],
		"construction": ["Construction table", "A small Wood frame and open room for painting, selection, copying and authoring history."],
		"liquid_channel": ["Liquid channel", "A bounded Water reservoir and a low channel beside an editable Wood gate."],
		"save_reopen": ["Save and reopen", "An asymmetric authored material pattern and a barrel for exact authored-layout comparisons."],
	}
	if not descriptions.has(fixture_id):
		return {}
	var text: Array = descriptions[fixture_id]
	return {"id":fixture_id, "version":VERSION, "label":text[0], "description":text[1],
		"extent":[EXTENT.x, EXTENT.y], "fill_probe":[380, 44],
		"initial_probes":[{"x":380, "y":44, "material":0},
			{"x":368, "y":32, "material":58}, {"x":12, "y":248, "material":58}],
		"evidence_kind":"committed_authored_recipe"}


static func build(fixture_id: String, policy: PackedInt32Array) -> Dictionary:
	if fixture_id not in IDS or policy.is_empty():
		return {}
	var data: Dictionary = Setup.fresh(policy, EXTENT)
	data.brush = 2
	var edits: Array = data.edits
	# A common floor and a small sealed test pocket leave most of the scene open.
	_box(edits, 8, 246, 496, 6, Setup.WALL)
	_box(edits, 368, 32, 24, 2, Setup.WALL)
	_box(edits, 368, 54, 24, 2, Setup.WALL)
	_box(edits, 368, 34, 2, 20, Setup.WALL)
	_box(edits, 390, 34, 2, 20, Setup.WALL)
	match fixture_id:
		"material_playground":
			_box(edits, 24, 174, 4, 72, Setup.WALL)
			_box(edits, 196, 174, 4, 72, Setup.WALL)
			_box(edits, 72, 170, 64, 4, Setup.WOOD)
			_box(edits, 48, 100, 24, 16, Setup.SAND)
			_box(edits, 140, 192, 40, 48, Setup.WATER)
		"actor_workshop":
			_box(edits, 300, 230, 20, 16, Setup.WALL)
			_box(edits, 320, 214, 20, 32, Setup.WALL)
			_box(edits, 340, 198, 20, 48, Setup.WALL)
			data.actors = [Setup.instance("kestrel", 1, Vector2(96, 160)),
				Setup.instance(Setup.BARREL, 2, Vector2(224, 180))]
			data.next_id = 3
			data.selected = 1
		"construction":
			_box(edits, 72, 162, 6, 84, Setup.WOOD)
			_box(edits, 150, 162, 6, 84, Setup.WOOD)
			_box(edits, 72, 156, 84, 6, Setup.WOOD)
			_box(edits, 90, 132, 24, 12, Setup.SAND)
		"liquid_channel":
			_box(edits, 24, 120, 4, 126, Setup.WALL)
			_box(edits, 28, 238, 252, 8, Setup.WALL)
			_box(edits, 144, 120, 4, 60, Setup.WALL)
			_box(edits, 144, 180, 4, 58, Setup.WOOD)
			_box(edits, 276, 210, 4, 28, Setup.WALL)
			_box(edits, 28, 144, 116, 94, Setup.WATER)
			_box(edits, 200, 198, 20, 10, Setup.SAND)
		"save_reopen":
			_box(edits, 312, 144, 8, 40, Setup.WOOD)
			_box(edits, 320, 168, 24, 8, Setup.WALL)
			_box(edits, 344, 168, 12, 8, Setup.SAND)
			_box(edits, 320, 184, 36, 4, Setup.WALL)
			_box(edits, 320, 176, 4, 8, Setup.WALL)
			_box(edits, 352, 176, 4, 8, Setup.WALL)
			_box(edits, 324, 176, 28, 8, Setup.WATER)
			data.actors = [Setup.instance(Setup.BARREL, 1, Vector2(420, 200))]
			data.next_id = 2
	return data


static func _box(edits: Array, x: int, y: int, width: int, height: int, material: int) -> void:
	edits.append([x, y, width, height, material])
